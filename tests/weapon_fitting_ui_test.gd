extends SceneTree
## Focused actual Main/State fitting scene lifecycle; broader adversarial and
## earned/native coverage lives in independent suites. Main processing stays on.
const Main = preload("res://scripts/main.gd")
const State = preload("res://scripts/game_state.gd")
const Fitting = preload("res://scripts/weapon_fitting_ui.gd")
class ProbeMain extends Main:
	var saves: int = 0
	var exits: int = 0
	func _autosave() -> void:
		saves += 1
		super._autosave()
	func _quit_cleanly(_save_progress: bool = true) -> void:
		exits += 1
		quit_pending = true
var app
var checks: int = 0
var failures: int = 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(description)
func _initialize() -> void: _run.call_deferred()
func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event = InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		Input.parse_input_event(event);await process_frame
func _click(button: Control) -> void:
	check(button != null,"Requested named native button exists")
	if button==null:return
	var point = root.get_final_transform()*button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event);await process_frame
func _panel(): return app.overlay.get_meta("weapon_fitting",null)
func _button(id: String): return _panel().action_buttons.get(id)
func _prepare(fitting: String="plain") -> void:
	app.quit_pending=false;app.save_warning=false;app.current_screen="explore";app.active_modal=false;app._clear_overlay();app._fitting_position_hold.clear()
	app.state=State.new();app.state.quest_stage=6;app.state.ending="守望";app.state.choose_sect("听潮阁")
	app.state.hp=17;app.state.qi=1;app.state.medicine=0;app.state.position=Vector2(100,100)
	app.state.set_weapon_fitting(fitting)
	app.world.change_map("qingwei",app.world.interactables.courtyard_practice.pos+Vector2(0,24));app.world.set_process(false)
	check(app.state.save_game()==OK,"Genuine State writes isolated baseline")
	Fitting.open(app)
func _finish(panel) -> void:
	if is_instance_valid(panel) and panel.art.is_presenting():panel.art._process(panel.art.get_presentation_duration()+.2)
func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	app=ProbeMain.new();root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false
	_prepare();await process_frame
	var before=app.state.to_dict();var position=app.world.player_pos;var bytes=FileAccess.get_file_as_bytes(State.SAVE_PATH);var saves=app.saves
	check(_panel()!=null and _panel().valid(),"Real fitting panel valid with genuine State and divergent stored position")
	check(_panel().body.text.contains("预览与当前已装配相同") and not _panel().body.text.contains("尚未装配"),"Installed candidate preview does not claim uninstalled")
	app.world.player_pos+=Vector2(2,0);position=app.world.player_pos
	await process_frame;await _key(KEY_2)
	check(_panel().candidate=="edge" and _panel().page=="preview","Native key2 selects preview only")
	check(_panel().body.text.contains("仅预览 · 尚未装配"),"Different candidate explicitly remains uninstalled")
	await _key(KEY_4);check(_panel().page=="confirm","Native key4 opens explicit confirmation")
	var stale=_panel().confirm_equip
	await _key(KEY_ESCAPE)
	check(not stale.is_valid(),"Retired native callback becomes invalid after disposal")
	check(_panel().page=="preview" and app.state.to_dict()==before and app.saves==saves,"Cancel and stale confirm preserve whole state and zero saves")
	await _click(_button("workshop"));await process_frame
	check(app.overlay.get_meta("fitting_workshop_readonly",false),"Return old workshop enters explicit read-only mode")
	await _key(KEY_4);await _key(KEY_3);await _key(KEY_ESCAPE);await process_frame
	check(app.state.to_dict()==before and app.world.player_pos==position and FileAccess.get_file_as_bytes(State.SAVE_PATH)==bytes and app.saves==saves,"Read-only workshop/market return and idle close preserve state/world/files")
	app.world.player_pos+=Vector2(1,0);await process_frame
	check(app.state.position==app.world.player_pos and app._fitting_position_hold.is_empty(),"Subsequent actual movement releases transient hold")
	Fitting.open(app);await _key(KEY_2);await _key(KEY_4);await _key(KEY_1)
	check(app.state.weapon_fitting=="edge" and app.saves==saves+1 and _panel().candidate=="edge","Explicit edge confirms and saves exactly once")
	var equipped=app.state.to_dict();_panel().confirm_equip();await process_frame
	check(app.state.to_dict()==equipped and app.saves==saves+1,"Repeated confirm outside confirmation page is no-op")
	await _click(_button("revert"));await _click(_button("confirm"))
	check(app.state.weapon_fitting=="plain" and app.saves==saves+2,"Explicit free restore persists original without drift")
	bytes=FileAccess.get_file_as_bytes(State.SAVE_PATH)
	check(DirAccess.make_dir_absolute(State.SAVE_PATH+".tmp")==OK,"Inject real filesystem save failure")
	await _key(KEY_3);await _key(KEY_4);await _key(KEY_1)
	check(app.state.weapon_fitting=="guard" and app.save_warning and FileAccess.get_file_as_bytes(State.SAVE_PATH)==bytes,"Failed explicit save keeps selection in memory and prior bytes")
	var failed=app.state.to_dict();saves=app.saves
	await _click(_button("workshop"));await _key(KEY_ESCAPE)
	check(app.state.to_dict()==failed and app.saves==saves,"Failed-choice return and Esc cannot retry implicitly")
	check(DirAccess.remove_absolute(State.SAVE_PATH+".tmp")==OK,"Remove only injected empty failure directory")
	Fitting.open(app);await _click(_button("retry_save"))
	check(not app.save_warning and app.state.weapon_fitting=="guard" and app.saves==saves+1,"Explicit retry saves current installed value once")
	for profile: String in ["ordinary","pressure"]:
		_prepare("guard");await _key(KEY_2);await _key(KEY_5)
		if profile=="pressure":await _click(_button("pressure"))
		before=app.state.to_dict();position=app.world.player_pos;bytes=FileAccess.get_file_as_bytes(State.SAVE_PATH);saves=app.saves
		check(_panel().trial_entry_ready("edge",profile),"Real site permits guarded borrowed trial "+profile)
		await _click(_button("start"))
		var battle=app.overlay.get_meta("party_battle",null)
		check(battle!=null and app.state.weapon_fitting=="guard" and battle.fitting_metadata.borrowed_fitting=="edge","Battle labels metadata keep borrowed and installed distinct")
		if battle!=null:
			battle.set_process(false);battle.art.set_process(false);await process_frame
			var badge = battle.find_child("FittingBattleBadge",true,false)
			check(badge!=null,"Battle shows visible installed/borrowed badge")
			check(badge.get_rect().end.y<=20 and not badge.get_rect().intersects(Rect2(487,20,306,65)),"Borrowed badge occupies reserved strip above existing round header "+str(badge.get_rect())+" min="+str(badge.get_combined_minimum_size()))
			var labels_clear:bool=true
			for actor_id:String in battle.unit_plates:
				if battle.art.unit_label_alpha(actor_id)>0 and badge.get_rect().intersects(battle.art.unit_label_rect(actor_id)):labels_clear=false
			check(labels_clear,"Borrowed badge does not cover visible actor labels")
			var controls_clear:bool=not badge.get_rect().intersects(battle.commands.pause_button.get_rect())
			for rect:Rect2 in battle.commands.command_rects.values():
				if badge.get_rect().intersects(rect):controls_clear=false
			check(controls_clear,"Borrowed badge avoids actual laid-out header and command rectangles")
			battle.leave();_finish(battle);await process_frame
			check(_panel()!=null and _panel().page=="results" and _panel().result_rows.size()==1,"Accepted terminal displays exact once-only result")
			check(_panel().result_rows[0].metrics.outcome=="flee","Incomplete trial truthfully labeled flee")
			check(app.state.to_dict()==before and app.world.player_pos==position and FileAccess.get_file_as_bytes(State.SAVE_PATH)==bytes and app.saves==saves,"Borrowed enter/flee/result remain entirely write-free "+profile)
			await _click(_button("start"));battle=app.overlay.get_meta("party_battle",null);battle.set_process(false);battle.art.set_process(false);battle.leave();_finish(battle);await process_frame
			check(_panel().result_rows.size()==2,"Same-group retry shows latest two results")
			await _key(KEY_ESCAPE);await process_frame
			check(app.state.to_dict()==before and app.world.player_pos==position and app.saves==saves,"Results Esc and idle exploration remain read-only")
	for outcome: String in ["win","defeat"]:
		_prepare("guard")
		if outcome=="win":
			app.state.attack=100;app.state.defense=100
			Fitting.open(app)
		await _key(KEY_2);await _key(KEY_5)
		if outcome=="defeat":await _click(_button("pressure"))
		before=app.state.to_dict();position=app.world.player_pos;bytes=FileAccess.get_file_as_bytes(State.SAVE_PATH);saves=app.saves
		await _click(_button("start"))
		var running=app.overlay.get_meta("party_battle",null);running.set_process(false);running.art.set_process(false)
		var steps:int=0
		while app.current_screen=="party_battle" and steps<300:
			running._process(1.0);_finish(running);await process_frame;steps+=1
		check(_panel()!=null and _panel().page=="results" and _panel().result_rows[-1].metrics.outcome==outcome,"Natural automatic UI reaches "+outcome)
		check(app.state.to_dict()==before and app.world.player_pos==position and app.saves==saves and FileAccess.get_file_as_bytes(State.SAVE_PATH)==bytes,"Natural "+outcome+" does not teleport, synchronize position, or mutate real files/state")
	_prepare()
	await _key(KEY_TAB)
	check(root.gui_get_focus_owner()!=null,"Native Tab reaches fitting controls")
	_panel().candidate_buttons.edge.grab_focus();await _key(KEY_ENTER)
	check(_panel().candidate=="edge" and _panel().page=="preview" and app.state.weapon_fitting=="plain","Native Enter chooses preview; key release cannot confirm next page")
	_panel().action_buttons.equip.grab_focus();await _key(KEY_ENTER)
	check(_panel().page=="confirm" and app.state.weapon_fitting=="plain","Native focused Enter opens confirmation without equipping on release")
	var prose:RichTextLabel=_panel().body
	prose.grab_focus();await _key(KEY_END)
	check(prose.get_v_scroll_bar().value>0,"Focused confirmation End reaches overflowing lower copy")
	await _key(KEY_HOME)
	check(prose.get_v_scroll_bar().value==0,"Focused confirmation Home returns to top")
	await _key(KEY_ESCAPE)
	_prepare();await _key(KEY_5)
	var location=app.world.interactables.courtyard_practice.pos
	for bad: Vector2 in [location+Vector2(85,0),location+Vector2(86,0),Vector2(INF,0)]:
		app.world.player_pos=bad
		check(not _panel().trial_entry_ready(_panel().candidate,_panel().profile),"Strict boundary/finite physical gate")
	app.world.player_pos=location+Vector2(84.9,0)
	check(_panel().trial_entry_ready("plain","ordinary"),"Inside85 physical gate accepted")
	_prepare("edge");await _key(KEY_3);await _key(KEY_5);await _click(_button("start"))
	var battle=app.overlay.get_meta("party_battle",null);battle.set_process(false);battle.art.set_process(false)
	before=app.state.to_dict();bytes=FileAccess.get_file_as_bytes(State.SAVE_PATH)
	check(DirAccess.make_dir_absolute(State.SAVE_PATH+".tmp")==OK,"Inject borrowed exit write failure")
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST);_finish(battle);await process_frame
	check(app.exits==0 and app.save_warning and not app.state.battle_active and not app.modal_autosave_on_close,"Explicit failed borrowed exit uses no-close-save protected dialog")
	check(app.state.weapon_fitting=="edge" and FileAccess.get_file_as_bytes(State.SAVE_PATH)==bytes,"Explicit exit never equips borrowed guard")
	await _key(KEY_3);await _key(KEY_1)
	var cancel_bytes=FileAccess.get_file_as_bytes(State.SAVE_PATH)
	await _key(KEY_2);await _key(KEY_ESCAPE)
	check(FileAccess.get_file_as_bytes(State.SAVE_PATH)==cancel_bytes and not app.active_modal,"Failed-exit pause save-slot browse and Esc cannot retry autosave")
	app.PauseMenu.show(app,true);await _key(KEY_3);await _key(KEY_1);await _key(KEY_ESCAPE)
	check(FileAccess.get_file_as_bytes(State.SAVE_PATH)==cancel_bytes and not app.active_modal,"Failed-exit load-slot detail browse and Esc cannot retry autosave")
	app.PauseMenu.show(app,true);await _key(KEY_ESCAPE)
	check(app.exits==0 and FileAccess.get_file_as_bytes(State.SAVE_PATH)==bytes and not app.active_modal,"Discard cancel/back/Esc preserves prior disk and remains open")
	check(DirAccess.remove_absolute(State.SAVE_PATH+".tmp")==OK,"Clean own empty failure directory")
	for invalid: String in ["attack","defense","max_hp","unowned","duplicate","unknown"]:
		_prepare();app.current_screen="explore";app.active_modal=false;app._clear_overlay()
		match invalid:
			"attack":app.state.attack=0
			"defense":app.state.defense=-1
			"max_hp":app.state.max_hp=0
			"unowned":app.state.party_roster.assign(["hero","qin"])
			"duplicate":app.state.party_roster.assign(["hero","hero"])
			"unknown":app.state.weapon_fitting="unknown"
		before=app.state.to_dict();saves=app.saves
		check(Fitting.open(app,"plain")==null and app.state.to_dict()==before and app.saves==saves and not app.overlay.has_meta("weapon_fitting"),"Malformed genuine State rejected before panel construction: "+invalid)
	_prepare();await _key(KEY_5);await _click(_button("pressure"))
	var fixed_warning:Label=_panel().find_child("FittingPressureWarning",true,false)
	check(fixed_warning!=null and fixed_warning.text.contains("初入门派") and fixed_warning.get_rect().end.y<=542,"Essential pressure warning is fixed outside scrolling body")
	app.state=State.new();app.current_screen="explore";app.active_modal=false;app._clear_overlay()
	check(Fitting.open(app)!=null and _panel().candidate=="plain","Canonical presect original still admits locked overview")
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d focused real fitting UI checks" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
