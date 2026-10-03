extends SceneTree
## Independent prepared-state scene/input safety. Not an earned journey, native
## pixel, browser, package or universal balance claim. Genuine HeroState only.
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")
const MainScene = preload("res://scenes/main.tscn")
const PartyUI = preload("res://scripts/party_battle_ui.gd")
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
const Trial = preload("res://scripts/weapon_fitting_trial_rules.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Prefs = preload("res://scripts/view_preferences.gd")

class MainProbe extends Main:
	var autosave_attempts: int = 0
	var manual_attempts: int = 0
	var exits: int = 0
	var save_observations: Array = []
	func _autosave() -> void:
		autosave_attempts += 1
		save_observations.append({"entry":"autosave", "before":state.to_dict().duplicate(true)})
		super._autosave()
	func _save() -> void:
		manual_attempts += 1
		save_observations.append({"entry":"manual", "before":state.to_dict().duplicate(true)})
		super._save()
	func _quit_cleanly(_save_progress: bool = true) -> void:
		if quit_pending:return
		exits += 1;quit_pending = true;world.active = false

var checks: int = 0
var failures: Array = []
var case_id: String = "setup"
var cases: Array = []
var trace: Array = []
var comparisons: Array = []
var output: String = ""
var app
var user_root: String
var case_filter: String = ""
var current_metrics: Dictionary = {}
var transaction_ids: Dictionary = {}
var transaction_trace: Array = []

func _initialize() -> void:_run.call_deferred()
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append({"case":case_id,"label":label})
		push_error("Independent fitting UI [%s]: %s" % [case_id,label])
	return ok
func _selected(id: String) -> bool:return case_filter.is_empty() or case_filter == id
func _begin(id: String) -> void:
	case_id = id;print("FITTING_UI_CASE " + id)
func _end() -> void:
	cases.append({"case":case_id,"checks_total":checks,"failures_total":failures.size()})
func _frame(count: int = 2) -> void:
	for i: int in count:await process_frame
func _tap(code: int, echo: bool = false) -> void:
	var down = InputEventKey.new();down.keycode=code;down.physical_keycode=code;down.pressed=true;down.echo=echo
	Input.parse_input_event(down);await _frame(1)
	var up = InputEventKey.new();up.keycode=code;up.physical_keycode=code;up.pressed=false
	Input.parse_input_event(up);await _frame(2)
	trace.append({"case":case_id,"key":code,"echo":echo,"screen":app.current_screen,"modal":app.modal_generation})
func _buttons(node: Node = null) -> Array:
	if node == null:node = app.overlay
	var found: Array = []
	if node is Button and node.is_visible_in_tree():found.append(node)
	for child: Node in node.get_children():found.append_array(_buttons(child))
	return found
func _button(fragment: String, exact: bool = false):
	for button: Button in _buttons():
		if (button.text == fragment if exact else button.text.contains(fragment)):return button
	return null
func _text(node: Node = null) -> String:
	if node == null:node = app.overlay
	var value: String = ""
	if node is Label or node is RichTextLabel or node is Button:value = node.text + "\n"
	for child: Node in node.get_children():value += _text(child)
	return value
func _callback(button: Button) -> Callable:
	if button == null:return Callable()
	for entry: Dictionary in button.pressed.get_connections():
		if entry.callable.is_valid():return entry.callable
	return Callable()
func _click(button: Control) -> void:
	if not check(button != null and is_instance_valid(button),"Requested actual mouse target exists"):return
	var rect: Rect2 = button.get_global_rect()
	check(rect.has_area() and root.get_visible_rect().encloses(rect),"Actual mouse target lies in logical viewport: " + button.name)
	var center: Vector2 = root.get_final_transform() * rect.get_center()
	var move = InputEventMouseMotion.new();move.position=center;move.global_position=center;Input.parse_input_event(move)
	await _frame(1)
	for pressed: bool in [true,false]:
		var event = InputEventMouseButton.new();event.position=center;event.global_position=center;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event);await _frame(1)
	await _frame(2)
func _choose(fragment: String, mouse: bool = false) -> bool:
	var button = _button(fragment)
	if not check(button != null,"Visible action exists: " + fragment + "; actual=" + str(_buttons().map(func(b):return b.text))):return false
	if not check(not button.disabled,"Action enabled: " + fragment):return false
	if mouse:await _click(button)
	else:
		var callback: Callable = _callback(button)
		var index: int = app.modal_actions.find(callback)
		if not check(index >= 0 and index <= 4,"Visible action has actual1–5 key mapping: " + fragment):return false
		await _tap(KEY_1 + index)
	trace.append({"case":case_id,"choice":fragment,"mouse":mouse,"screen":app.current_screen})
	return true
func _inventory() -> Dictionary:
	var result: Dictionary = {}
	_collect_files("user://", "", result)
	return result
func _collect_files(path: String, prefix: String, result: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if dir == null:return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var relative: String = prefix + name
			if dir.current_is_dir():
				result[relative + "/"] = {"directory":true};_collect_files(path.path_join(name),relative+"/",result)
			else:
				var file_path: String = path.path_join(name)
				var bytes = FileAccess.get_file_as_bytes(file_path)
				result[relative] = {"bytes":bytes,"sha256":FileAccess.get_sha256(file_path),"size":bytes.size()}
		name = dir.get_next()
	dir.list_dir_end()
func _file_identity() -> Dictionary:
	# The actual atomic writer replaces the inode even for identical JSON.
	# This read-only stat complements exact bytes and Main entry observations.
	var lines: Array = []
	var code: String = "import os,json,sys; r=sys.argv[1]; print(json.dumps({os.path.relpath(os.path.join(p,n),r):[os.lstat(os.path.join(p,n)).st_ino,os.lstat(os.path.join(p,n)).st_mtime_ns,os.lstat(os.path.join(p,n)).st_size] for p,ds,fs in os.walk(r) for n in sorted(ds+fs)},sort_keys=True))"
	var status: int = OS.execute("python3",PackedStringArray(["-c",code,user_root]),lines)
	if not check(status == 0 and not lines.is_empty(),"Read-only nanosecond/inode filesystem inventory"):return {}
	var parsed = JSON.parse_string(lines[0])
	return parsed if parsed is Dictionary else {}
func _snapshot() -> Dictionary:
	return {"state":app.state.to_dict().duplicate(true),"state_id":app.state.get_instance_id(),"world_map":app.world.map_id,"world_position":app.world.player_pos,"files":_inventory(),"file_identity":_file_identity(),"autosaves":app.autosave_attempts,"manual_saves":app.manual_attempts,"exits":app.exits}
func _same(before: Dictionary, label: String, include_position: bool = true) -> void:
	check(app.state.to_dict() == before.state,label + ": entire persistent State unchanged")
	check(app.state.get_instance_id() == before.state_id,label + ": same genuine State")
	if include_position:check(app.world.map_id == before.world_map and app.world.player_pos == before.world_position,label + ": no world teleport/map change")
	check(_inventory() == before.files,label + ": every user file byte/path unchanged")
	check(_file_identity() == before.file_identity,label + ": no same-byte rewrite/replace")
	check(app.autosave_attempts == before.autosaves and app.manual_attempts == before.manual_saves,label + ": no Main save entry attempted")
	check(app.exits == before.exits,label + ": no unrequested exit")
	trace.append({"case":case_id,"preservation":label,"before":_public_snapshot(before),"after":_public_snapshot(_snapshot())})
func _public_snapshot(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for path: String in result.files:result.files[path].erase("bytes")
	result.world_position = [value.world_position.x if is_finite(value.world_position.x) else "nonfinite",value.world_position.y if is_finite(value.world_position.y) else "nonfinite"]
	return result
func _stale(callback: Callable, label: String) -> void:
	var before: Dictionary = _snapshot()
	var available: bool = callback.is_valid()
	if available:callback.call()
	_same(before,"Stale callback: " + label)
	trace.append({"case":case_id,"stale":label,"callable_available":available})
func _prepared(school: String = "听潮阁", full: bool = false):
	var s = Model.new();s.quest_stage=6;s.ending="守望"
	s.choose_sect(school);check(s.sect == school,"Prepared canonical selected real school " + school)
	if full:
		s.gain_xp(900)
		s.side_stage=3;s.side_choice="rescue";s.side_clues=2;s.side_found.assign(["boatman","ledger"]);s.side_reward_claimed=true
		s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1]);s.bridge_repaired=true
		check(s.recruit_companion(),"Prepared history explicitly recruits Shen")
		check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(),"Prepared history explicitly recruits Tang")
		s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water";s.map_id="mistwood"
		check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Prepared history explicitly recruits Qin")
		check(s.set_party_roster(["hero","qin","tang","shen"]),"Prepared full selected non-default order")
		s.party_resources.shen.hp=0;s.party_resources.shen.qi=0;s.party_resources.tang.hp=9;s.party_resources.tang.qi=1;s.party_resources.qin.hp=7;s.party_resources.qin.qi=0
		s.learn_internal_skill();s.learn_lightness()
	s.hp=17;s.qi=1;s.medicine=0;s.map_id="qingwei";s.position=Vector2(460,430)
	check(s._stage_save_data(s.to_dict(),Model.SAVE_VERSION).ok,"Prepared State canonical; not earned-journey evidence")
	return s
func _create(s = null, near: bool = false) -> void:
	if is_instance_valid(app):
		app._stop_audio();app.queue_free();await _frame(3)
	if s == null:s = _prepared()
	app = MainScene.instantiate();app.set_script(MainProbe);app.state=s
	root.add_child(app);await _frame(3)
	check(_text().contains("16") and _text().contains("旧版"),"General title discloses one-way current writer even without fitting")
	app._stop_audio();app.audio_on=false
	app.world.set_process(false)
	app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal()
	app.world.change_map(s.map_id,Vector2(721,757) if near else s.position)
	app._sync_world_state();app.world._update_nearby();app._refresh();app._process(0)
	check(app.state.get_script().resource_path == "res://scripts/game_state.gd","Factory sees exact genuine HeroState")
	check(s.save_game() == OK,"Prepared isolated baseline auto save")
	var slots = Slots.new()
	for id: int in [1,2,3]:
		check(slots.save_slot(s,id) == OK,"Prepared manual slot primary " + str(id))
		s.coins += 1
		check(slots.save_slot(s,id) == OK,"Prepared manual slot real backup " + str(id))
	# Keep a real, canonical, deliberately unsaved difference from disk.
	s.coins += 7
	app.autosave_attempts=0;app.manual_attempts=0;app.save_observations.clear();app.save_warning=false
	await _frame(2)
func _panel():return app.overlay.get_meta("weapon_fitting") if app.overlay.has_meta("weapon_fitting") else null
func _battle():return app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
func _open_workshop() -> bool:
	await _tap(KEY_B)
	if not await _choose("剑上配件"):return false
	return check(_panel() != null,"Actual B→workshop→fitting controller")
func _open_court() -> bool:
	app.world._update_nearby();app._process(0)
	if not check(app.world.nearby_id == "courtyard_practice","Actual near court at world position"):return false
	await _tap(KEY_E)
	if not await _choose("借用配件试招"):return false
	return check(_panel() != null,"Actual court E→fitting controller")
func _fit(action: String, mouse: bool = false) -> bool:
	var panel = _panel()
	if not check(panel != null and panel.action_buttons.has(action),"Live fitting action exists: " + action):return false
	var button: Button = panel.action_buttons[action]
	if not check(not button.disabled,"Fitting action enabled: " + action):return false
	if mouse:await _click(button)
	else:
		var codes: Dictionary = {}
		match panel.page:
			"preview":codes={"equip":KEY_4,"trial":KEY_5,"retry_save":KEY_F5}
			"trial":codes={"equip":KEY_4,"start":KEY_5}
			"confirm":codes={"confirm":KEY_1,"cancel":KEY_2}
			"results":codes={"start":KEY_1,"trial":KEY_2,"preview":KEY_3}
		if not check(codes.has(action),"Explicit fitting keyboard mapping: " + action):return false
		await _tap(codes[action])
	return true
func _candidate(id: String, mouse: bool = false) -> bool:
	var panel = _panel()
	if not check(panel != null and panel.candidate_buttons.has(id),"Live candidate exists: " + id):return false
	if mouse:await _click(panel.candidate_buttons[id])
	else:await _tap(KEY_1+Fittings.IDS.find(id))
	return check(_panel() != null and _panel().candidate == id,"Input selects preview only: " + id)
func _prepare_trial(id: String = "plain", pressure: bool = false) -> bool:
	if _panel().page == "results" and not await _fit("trial"):return false
	if not await _candidate(id,true):return false
	if _panel().page == "preview" and not await _fit("trial"):return false
	if pressure and _panel().profile != "pressure" and not await _fit("pressure",true):return false
	if not pressure and _panel().profile != "ordinary" and not await _fit("ordinary",true):return false
	return true
func _start_trial(id: String = "plain", pressure: bool = false):
	if not await _prepare_trial(id,pressure):return null
	if not await _fit("start"):return null
	var panel = _battle()
	if not check(panel != null and app.current_screen == "party_battle","Actual UI enters unified fitting battle"):return null
	panel.set_process(false);panel.art.set_process(false)
	return panel
func _confirm(id: String, mouse: bool = false) -> bool:
	if not await _candidate(id,mouse):return false
	if not await _fit("equip",mouse):return false
	return await _fit("confirm",not mouse)
func _diverge() -> Dictionary:
	var before: Vector2 = app.state.position
	app.world.teleport(app.world.player_pos+Vector2(2,0))
	check(app.state.position == before and app.state.position != app.world.player_pos,"Adversarial setup separates stored position from live world without State mutation")
	return _snapshot()
func _audit_start(panel) -> void:
	current_metrics={"losses":{},"loss":0,"medicine":0,"attacks":0,"rounds":0,"accepted":0};transaction_ids={};transaction_trace=[]
	for actor: Dictionary in app.state.party_battle_snapshot().actors:current_metrics.losses[actor.id]=0
	if not panel.pending.is_empty():_audit_pending(panel)
func _audit_pending(panel) -> void:
	if not is_instance_valid(panel) or panel.pending.is_empty():return
	var tx: Dictionary = panel.pending
	var identity: String = "%d:%d" % [int(tx.epoch),int(tx.token)]
	if transaction_ids.has(identity):return
	transaction_ids[identity]=true;current_metrics.accepted+=1
	for actor: Dictionary in tx.before.actors:
		var after: Dictionary = _actor(tx.after,actor.id)
		var loss: int = maxi(0,int(actor.hp)-int(after.hp));current_metrics.losses[actor.id]+=loss;current_metrics.loss+=loss
	current_metrics.medicine += int(tx.before.medicine)-int(tx.after.medicine)
	for event: Dictionary in tx.events:
		if event.type == "action" and event.get("action_id") == "enemy:attack":current_metrics.attacks+=1
		if event.type == "round_end":current_metrics.rounds+=1
	transaction_trace.append({"epoch":tx.epoch,"token":tx.token,"source":tx.source_id,"action":tx.action_id,"before_round":tx.before.round,"after_round":tx.after.round,"events":tx.events.duplicate(true)})
func _actor(snapshot: Dictionary,id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id:return actor
	return {}
func _finish(panel) -> void:
	if not is_instance_valid(panel):return
	_audit_pending(panel)
	if panel.art.is_presenting():panel.art._process(panel.art.get_presentation_duration()+0.1)
func _tick(panel) -> void:
	if not is_instance_valid(panel):return
	if panel.art.is_presenting():_finish(panel)
	elif panel.valid():panel._process(0.5);_audit_pending(panel)
func _terminal(panel, flee: bool = false) -> void:
	_audit_start(panel)
	if flee:
		if panel.art.is_presenting():_finish(panel)
		await _tap(KEY_ESCAPE);_audit_pending(panel);_finish(panel)
	else:
		for step: int in range(1800):
			if not app.state.battle_active:break
			_tick(panel)
		check(not app.state.battle_active,"Actual automatic model reaches terminal, without forged HP/outcome")
	await _frame(3)
func _assert_metrics(label: String) -> void:
	var history: Dictionary = app.state.fitting_comparison_snapshot()
	if not check(not history.results.is_empty(),label+": accepted result exists"):return
	var result: Dictionary = history.results[-1];var m: Dictionary=result.metrics
	check(m.actual_hp_lost_by_actor == current_metrics.losses and m.total_actual_hp_lost == current_metrics.loss,label+": actual capped HP losses independently reconstructed")
	check(m.medicine_used == current_metrics.medicine and m.enemy_attacks_executed == current_metrics.attacks,label+": accepted medicine and executed attacks, excluding protection")
	check(m.completed_rounds == current_metrics.rounds and m.accepted_transactions == current_metrics.accepted,label+": complete rounds and once-only accepted tokens")
	check(m.terminal_round >= m.completed_rounds,label+": terminal round distinct")
	var text: String = _text()
	var rendered: RichTextLabel = app.overlay.find_child("FittingResult" + str(history.results.size()),true,false)
	var rendered_text: String = rendered.get_parsed_text() if rendered != null else ""
	check(rendered_text.contains("借用气血累计损失 %d  ·  借药用去 %d / 3" % [m.total_actual_hp_lost,m.medicine_used]),label+": visible latest-row HP and medicine exact with correct labels")
	check(rendered_text.contains("敌方实际攻击 %d 次（不含护势）" % m.enemy_attacks_executed),label+": visible actual attack count excludes protection")
	check(rendered_text.contains("完整经过 %d 轮  ·  结束于第 %d 轮" % [m.completed_rounds,m.terminal_round]),label+": visible completed/terminal round labels exact")
	comparisons.append({"case":case_id,"history":history,"independent_metrics":current_metrics.duplicate(true),"transactions":transaction_trace.duplicate(true),"visible_text":text})

# Case implementations follow after the production controller interface settles.
func _run() -> void:
	var root_path: String = OS.get_environment("XDG_DATA_HOME")
	user_root = ProjectSettings.globalize_path("user://").simplify_path()
	if not root_path.is_absolute_path() or not user_root.begins_with(root_path.simplify_path()+"/"):
		push_error("Require fresh isolated XDG_DATA_HOME");quit(2);return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--case="):case_filter=argument.trim_prefix("--case=")
	if output.is_empty() or not output.is_absolute_path():push_error("Require absolute unused --output outside user://");quit(2);return
	if FileAccess.file_exists(output) or FileAccess.file_exists(Model.SAVE_PATH):push_error("Refuse existing test evidence/player autosave");quit(2);return
	root.size=Vector2i(1280,800)
	var prefs=Prefs.new();prefs.sound_enabled=false;check(prefs.save_settings()==OK,"Muted isolated test preferences")
	await _cases()
	if is_instance_valid(app):app._stop_audio();app.queue_free();await _frame(3)
	var report: Dictionary={"scope":"Independent prepared canonical/adversarial State fixtures through actual Main keyboard/mouse and automatic PartyUI; no earned journey, native pixels, browser, exported package or universal balance claim. Genuine State only; test-only Main observes saves/exits. Exact bytes plus inode/mtime observed; failed writes before filesystem access outside Main are not syscall-instrumented.","checks":checks,"failures":failures,"cases":cases,"trace":trace,"comparisons":comparisons,"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"driver_sha256":FileAccess.get_sha256(get_script().resource_path),"user_root":user_root}
	var file=FileAccess.open(output,FileAccess.WRITE)
	if file == null:push_error("Cannot save independent evidence");quit(2);return
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("INDEPENDENT_FITTING_UI %d checks %d failures %d cases" % [checks,failures.size(),cases.size()])
	quit(0 if failures.is_empty() else 1)
func _cases() -> void:
	if _selected("navigation"):await _navigation()
	if _selected("locks"):await _locks()
	if _selected("malformed_entry"):await _malformed_entry()
	if _selected("stale"):await _stale_guards()
	if _selected("locations"):await _locations()
	if _selected("position_release"):await _position_release()
	if _selected("rosters_inputs"):await _rosters_inputs()
	if _selected("terminals"):await _terminals()
	if _selected("history"):await _history()
	if _selected("save_failure"):await _save_failure()
	if _selected("application_close"):await _application_close()
	if _selected("writer_load"):await _writer_load()
	if _selected("wording"):await _wording()

func _navigation() -> void:
	_begin("navigation");await _create(_prepared(),true)
	if not await _open_workshop():return
	var before: Dictionary = _diverge();await _frame(4)
	_same(before,"Open fitting frame preserves deliberately stale stored position")
	check(_text().contains("当前已装配") and _text().contains("仅预览") and _text().contains("格式16") and _text().contains("不会额外备份"),"Overview distinctly labels installed/preview and true writer/backups")
	for id: String in ["edge","guard","plain"]:
		await _candidate(id,id == "guard");await _frame(3)
		_same(before,"Candidate navigation " + id)
		check(_panel().valid() and app.state.weapon_fitting == "plain","Candidate remains optional uninstalled " + id)
	var panel = _panel();var saved: Callable=_callback(panel.candidate_buttons.edge)
	await _candidate("guard");_stale(saved,"candidate from replaced panel")
	await _tap(KEY_2,true);check(_panel().candidate == "guard","Key echo cannot change candidate")
	await _fit("equip");check(_panel().page == "confirm","Key4 opens explicit confirm, not a save")
	var confirmation: Callable = _callback(_panel().action_buttons.confirm)
	await _tap(KEY_ESCAPE);_same(before,"Escape cancels explicit confirmation")
	_stale(confirmation,"cancelled confirmation")
	await _fit("equip",true);await _fit("cancel");_same(before,"Mouse confirmation then keyboard cancel")
	await _fit("workshop",true)
	check(not app.modal_autosave_on_close,"Return workshop carries read-only dismissal")
	await _choose("材料买卖");await _choose("买入材料")
	await _choose("返回货担");await _choose("返回工艺")
	await _tap(KEY_ESCAPE);await _frame(4)
	_same(before,"Return via workshop/market detour and Escape")
	check(not app.active_modal,"Escape actually dismissed read-only workshop")
	if not await _open_workshop():return
	await _click(app.overlay.find_child("FittingClose",true,false));await _frame(4)
	_same(before,"Actual X close never equips/saves/synchronizes stored position")
	if not await _open_workshop():return
	check(_panel().candidate == "plain" and app.state.weapon_fitting == "plain","Reopen shows installed original, not abandoned candidate")
	await _candidate("edge")
	var button: Button = _panel().action_buttons.equip
	await _focus_by_tab(button);await _tap(KEY_ENTER)
	check(_panel().page == "confirm","Native focused Enter opens confirmation once")
	await _tap(KEY_ENTER);await _tap(KEY_SPACE)
	check(app.state.weapon_fitting == "plain" and _panel().page == "confirm","Replacement page cannot inherit Enter/Space as implicit commit")
	var exact_before: Dictionary = app.state.to_dict().duplicate(true)
	var equip_callback: Callable = _callback(_panel().action_buttons.confirm)
	await _fit("confirm")
	exact_before.weapon_fitting="edge"
	check(app.save_observations[-1].before == exact_before,"Before existing explicit-save position sync, confirmation changes only enum")
	check(app.state.weapon_fitting == "edge" and app.autosave_attempts == before.autosaves+1,"Explicit input commits and saves once")
	_stale(equip_callback,"duplicate accepted confirmation")
	var accepted: Dictionary = _snapshot();await _tap(KEY_4)
	_same(accepted,"Same-choice shortcut is no-op")
	for id: String in ["guard","plain"]:
		var base_a: int=app.state.attack;var base_d: int=app.state.defense
		await _confirm(id,true)
		check(app.state.weapon_fitting == id and app.state.attack == base_a and app.state.defense == base_d,"Explicit loop preserves cumulative bases " + id)
	_end()

func _locks() -> void:
	_begin("locks")
	for school: String in Model.SECTS:
		await _create(_prepared(school))
		if not await _open_workshop():return
		check(app.state.capstone_stage == 0,"Early fitting does not require capstone")
		for id: String in ["edge","guard"]:
			await _candidate(id);check(not _panel().action_buttons.equip.disabled,"Real school unlocked choice " + school+id)
		await _tap(KEY_ESCAPE)
	await _create(Model.new())
	if not await _open_workshop():return
	var before: Dictionary=_snapshot()
	for id: String in ["plain","edge","guard"]:
		await _candidate(id)
		check(_panel().action_buttons.equip.disabled,"No optional equip before opening/school " + id)
		await _fit("trial")
		check(_panel().action_buttons.start.disabled,"Borrowing locked including plain before opening/school")
		await _tap(KEY_5);check(not app.state.battle_active,"Disabled keyboard start cannot bypass lock")
		await _tap(KEY_ESCAPE)
	_same(before,"Locked navigation no effects")
	var presect = Model.new();presect.quest_stage=5;presect.ending="守望"
	await _create(presect)
	if not await _open_workshop():return
	await _candidate("edge");check(_panel().action_buttons.equip.disabled,"Valid actual quest5 unjoined State retains locked preview")
	await _tap(KEY_ESCAPE)
	for mode: String in ["quest5","unjoined","unknown_sect","edge_floor","guard_floor"]:
		await _create(_prepared(),true)
		match mode:
			"quest5":app.state.quest_stage=5
			"unjoined":app.state.sect="未入门"
			"unknown_sect":app.state.sect="无此门派"
			"edge_floor":app.state.defense=1
			"guard_floor":app.state.attack=3
		var canonical: bool=app.state._stage_save_data(app.state.to_dict(),Model.SAVE_VERSION).ok
		var entry_before: Dictionary=_snapshot()
		await _tap(KEY_B);await _choose("剑上配件")
		if not canonical:
			check(_panel() == null,"Malformed eligibility fixture rejected before UI: " + mode)
			_same(entry_before,"Malformed eligibility admission no effect: " + mode)
			continue
		if not check(_panel() != null,"Canonical boundary fixture opens fitting: " + mode):return
		before=_snapshot();await _candidate("guard" if mode == "guard_floor" else "edge")
		check(_panel().action_buttons.equip.disabled,"Full eligibility/cost lock visible: " + mode)
		await _tap(KEY_4);check(_panel().page == "preview","Forbidden choice cannot become confirmation: " + mode)
		_same(before,"Forbidden preview " + mode)
	_end()

func _stale_guards() -> void:
	_begin("stale")
	for mode: String in ["state_instance","installed","attack","defense","max_hp","max_qi","coins","roster","formation","art_rank","modal_generation","metadata","quit","pending","battle","title"]:
		await _create(_prepared("听潮阁",true),true)
		if not await _open_workshop():return
		await _candidate("edge");await _fit("equip")
		var panel = _panel();var callback: Callable = _callback(panel.action_buttons.confirm)
		match mode:
			"state_instance":app.state=app.state._detached_persistent_state()
			"installed":app.state.set_weapon_fitting("guard")
			"attack":app.state.attack+=1
			"defense":app.state.defense+=1
			"max_hp":app.state.max_hp+=1
			"max_qi":app.state.max_qi+=1
			"coins":app.state.coins+=1
			"roster":app.state.set_party_roster(["hero"])
			"formation":app.state.set_formation("护后")
			"art_rank":app.state.art_uses[app.state.equipped_art]+=15
			"modal_generation":app.modal_generation+=1
			"metadata":app.overlay.set_meta("weapon_fitting",Control.new())
			"quit":app.quit_pending=true
			"pending":app.state._party_pending_token=811
			"battle":app.state.battle_active=true
			"title":app.current_screen="title"
		check(not panel.valid(),"Changed determinant/gate invalidates live controller: " + mode)
		_stale(callback,mode)
		# Test-only cleanup of synthetic gates; never represent it as user flow.
		if mode == "metadata":app.overlay.get_meta("weapon_fitting").free();app.overlay.set_meta("weapon_fitting",panel)
		app.quit_pending=false;app.state._party_pending_token=-1;app.state.battle_active=false;app.current_screen="explore"
	_end()

func _locations() -> void:
	_begin("locations")
	for map_id: String in ["qingwei","sluice","frostbridge","mistwood","heting"]:
		var s = _prepared("听潮阁",true)
		if map_id == "heting":check(s.begin_heting(),"Prepared remote Heting has its required actual entry prerequisite")
		s.map_id=map_id
		await _create(s)
		if not await _open_workshop():return
		var before: Dictionary = _snapshot()
		await _fit("trial");check(_panel().action_buttons.start.disabled,"Remote workshop cannot trial: " + map_id)
		await _tap(KEY_5);_same(before,"Remote start no teleport/write " + map_id)
	for mode: String in ["state_map","world_map","missing_site","site_nan","player_nan","distance85","distance85_1","controller","candidate","profile"]:
		await _create(_prepared(),true)
		if not await _open_court():return
		await _prepare_trial("edge")
		var panel = _panel();var original_point: Dictionary = app.world.interactables.courtyard_practice.duplicate(true)
		var point: Vector2 = original_point.pos
		match mode:
			"state_map":app.state.map_id="sluice"
			"world_map":app.world.map_id="sluice"
			"missing_site":app.world.interactables.erase("courtyard_practice")
			"site_nan":app.world.interactables.courtyard_practice.pos=Vector2(NAN,733)
			"player_nan":app.world.player_pos=Vector2(NAN,733)
			"distance85":app.world.player_pos=point+Vector2(85,0)
			"distance85_1":app.world.player_pos=point+Vector2(85.1,0)
		var before: Dictionary = _snapshot();var history: Dictionary = app.state.fitting_comparison_snapshot()
		var result = PartyUI.open_fitting(app,null if mode == "controller" else panel,"guard" if mode == "candidate" else "edge","pressure" if mode == "profile" else "ordinary")
		check(result == null and not app.state.battle_active,"Direct adapter rechecks actual gate: " + mode)
		_same(before,"Rejected actual gate " + mode,mode != "player_nan")
		check(app.state.fitting_comparison_snapshot() == history,"Rejected entry retains comparison history " + mode)
		app.state.map_id="qingwei";app.world.map_id="qingwei";app.world.interactables.courtyard_practice=original_point;app.world.player_pos=point+Vector2(0,24)
	await _create(_prepared(),true)
	if not await _open_court():return
	await _prepare_trial("edge");app.world.player_pos=app.world.interactables.courtyard_practice.pos+Vector2(84.9,0)
	var before: Dictionary=_snapshot()
	await _fit("start");var panel=_battle()
	if check(panel != null,"Strictly-inside84.9 actual adapter allows trial"):
		panel.set_process(false);panel.art.set_process(false);await _terminal(panel,true);_same(before,"84.9 accepted fitting flee")
	_end()

func _terminals() -> void:
	_begin("terminals")
	for outcome: String in ["win","defeat","flee"]:
		var s = _prepared("听潮阁",outcome == "win")
		if outcome == "win":s.attack=90;s.defense=90
		check(s.set_weapon_fitting("guard").ok,"Prepared installed guard distinct from borrowed edge")
		await _create(s,true)
		if not await _open_court():return
		var before: Dictionary = _diverge();await _frame(4);_same(before,"Pretrial Main frame sync suppressed " + outcome)
		var panel = await _start_trial("edge",outcome == "defeat")
		if panel == null:return
		var view: Dictionary=app.state.party_battle_snapshot()
		check(view.actors.map(func(a):return a.id) == s.party_roster,"Full selected authentic roster and order copied")
		for actor: Dictionary in view.actors:check(actor.hp == actor.max_hp and actor.qi == actor.max_qi,"Every selected actor receives only borrowed full resources")
		check(view.medicine == 3 and s.medicine == 0 and view.actors[0].attack == s.attack+3 and view.actors[0].defense == s.defense-2,"Borrowed candidate stats/resources distinct from installed guard")
		check(_text().contains("本次借用") and _text().contains("真实已装配"),"Battle presents installed and borrowed distinction")
		await _terminal(panel,outcome == "flee")
		check(s.party_settlement.outcome == outcome,"Genuine automatic terminal path: " + outcome)
		_same(before,"Trial terminal preserves unsaved real state/files/positions " + outcome)
		_assert_metrics(outcome)
		check(_panel() != null and _panel().page == "results","Terminal enters guarded result page")
		var result_callback: Callable = _callback(_panel().action_buttons.start)
		await _fit("start");var retry = _battle()
		if retry == null:check(false,"Actual result keyboard retry starts");return
		retry.set_process(false);retry.art.set_process(false)
		_stale(result_callback,"Prior result retry during newer session")
		await _terminal(retry,true);_same(before,"Retry/flee also preserves original divergence")
		await _fit("close",true);await _frame(4);_same(before,"Result return/dismiss preserves stored/live positions")
	_end()

func _history() -> void:
	_begin("history");var named = _prepared("问石门",true);named.player_name="[b]客[/b]";await _create(named,true)
	if not await _open_court():return
	var before: Dictionary=_diverge();var key: String=""
	for id: String in ["plain","edge","guard"]:
		var panel = await _start_trial(id)
		if panel == null:return
		await _terminal(panel,true);_assert_metrics("history " + id);_same(before,"Same-key result history " + id)
		var history: Dictionary=app.state.fitting_comparison_snapshot()
		if key.is_empty():key=history.comparison_key
		check(history.comparison_key == key,"Candidates share frozen key/specs")
		check(_panel().result_rows == history.results,"Visible result rows equal accepted immutable latest-two")
		var rich: RichTextLabel=app.overlay.find_child("FittingResult1",true,false)
		check(rich != null and rich.get_parsed_text().contains(named.player_name+"："),"Canonical bracketed player name is rendered literally, not BBCode")
	var history: Dictionary=app.state.fitting_comparison_snapshot()
	check(history.results.size() == 2 and history.results[0].metadata.borrowed_fitting == "edge" and history.results[1].metadata.borrowed_fitting == "guard","Third same-key run retains only latest two in chronological order")
	check(_text().contains("主动退开（未打完）") and _text().contains("不含护势") and _text().contains("完整经过") and _text().contains("结束于第") and _text().contains("不会保证普遍优势"),"Visible comparison truthfully distinguishes sampled flee/attacks/rounds")
	var panel = await _start_trial("plain",true)
	if panel == null:return
	check(app.state.fitting_comparison_snapshot().results.is_empty(),"New profile clears earlier comparable group at entry")
	await _terminal(panel,true)
	check(app.state.fitting_comparison_snapshot().comparison_key != key and _panel().result_rows.size() == 1,"Pressure result never mixed with ordinary")
	await _fit("close",true)
	check(app.state.set_party_roster(["hero","tang"]),"Prepared changed actual selected roster")
	if not await _open_court():return
	await _fit("results",true)
	check(_panel().result_rows.is_empty() and _text().contains("尚无可并列"),"Changed roster cannot show stale results as currently comparable")
	_end()

func _save_failure() -> void:
	_begin("save_failure");await _create(_prepared(),true)
	if not await _open_workshop():return
	var before: Dictionary=_diverge();await _frame(3);_same(before,"Preview before real save failure")
	var blocker: String=Model.SAVE_PATH+".tmp"
	check(DirAccess.make_dir_absolute(blocker) == OK,"Inject real owned atomic-save blocker without touching prior files")
	var disk: Dictionary=_inventory();var state_before: Dictionary=app.state.to_dict().duplicate(true)
	await _confirm("edge")
	state_before.weapon_fitting="edge"
	check(app.save_observations[-1].before == state_before,"Failed explicit choice changed only enum before existing save sync")
	check(app.state.weapon_fitting == "edge" and app.save_warning and _inventory() == disk,"Failed explicit equip retains installed choice/old files")
	check(_text().contains("未保存") and _text().contains("重试保存"),"Visible failed-equip unsaved/retry warning")
	var accepted: Dictionary=_snapshot();var retry_callback: Callable=_callback(_panel().action_buttons.retry_save)
	await _fit("retry_save");check(app.state.weapon_fitting == "edge" and app.save_warning and _inventory() == disk,"Repeated actual failure does not reapply or alter disk")
	var after_failure: Dictionary=_snapshot()
	await _candidate("guard");await _tap(KEY_ESCAPE);await _frame(3)
	_same(after_failure,"Cancel failed save and abandoned new preview")
	_stale(retry_callback,"Old retry after cancellation")
	# Explicitly retain current later real progress; a new controller may save it.
	app.state.coins+=5
	if not await _open_workshop():return
	var current: Dictionary=app.state.to_dict().duplicate(true)
	check(DirAccess.rename_absolute(blocker,blocker+".owned-blocker") == OK,"Recover test storage by moving only owned blocker")
	await _fit("retry_save",true)
	check(not app.save_warning and app.state.to_dict() == current,"Retry saves current real state, not preview-era copy")
	var document=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
	check(document.version == 16 and app.state._same_save_value(document.player,current),"Successful retry serializes exact current16 real state")
	for path: String in before.files:
		if path.begins_with("hero_slot_"):check(_inventory()[path] == before.files[path],"Fitting autosave leaves manual slot/backup unchanged " + path)
	check(DirAccess.remove_absolute(blocker+".owned-blocker") == OK,"Remove only test-owned empty recovered blocker")
	var loaded=Model.new();check(loaded.load_game() == OK and loaded.to_dict() == current,"Current writer16 reader roundtrip after failure")
	_end()

func _application_close() -> void:
	_begin("application_close")
	for branch: String in ["retry","discard"]:
		await _create(_prepared("照野堂",true),true)
		if not await _open_court():return
		var unchanged: Dictionary=_diverge()
		var panel=await _start_trial("edge",true)
		if panel == null:return
		_audit_start(panel);panel._process(0.5);_audit_pending(panel)
		check(not panel.pending.is_empty(),"Window close fixture has accepted presenting transaction")
		var baseline_files: Dictionary=_inventory()
		var blocker: String=Model.SAVE_PATH+".tmp"
		check(DirAccess.make_dir_absolute(blocker) == OK,"Inject owned failure for explicit exit")
		app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		check(app.exits == 0 and panel.close_pending,"Repeated window close waits for accepted presentation")
		_finish(panel);_finish(panel);await _frame(4)
		check(not app.state.battle_active and app.exits == 0 and app.save_warning,"Failed post-settlement exit remains in actual game")
		var expected: Dictionary=unchanged.state.duplicate(true);expected.position={"x":unchanged.world_position.x,"y":unchanged.world_position.y}
		check(app.state._same_save_value(app.state.to_dict(),expected) and app.state.weapon_fitting == "plain","Explicit exit exception syncs only real position; borrowed edge/resources never leak")
		for path: String in baseline_files:check(_inventory()[path] == baseline_files[path],"Exit failure retains existing file " + path)
		var cancelled: Dictionary=_snapshot();var stale: Callable=_callback(_button("重试保存"))
		await _choose("返回小憩");await _choose("存一卷手记");await _tap(KEY_ESCAPE);await _frame(4)
		_same(cancelled,"Failed fitting exit→pause→save-slot browse→Escape is write-free")
		app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);await _frame(2)
		await _choose("返回小憩");await _choose("查阅手记");await _choose("自动续写");await _choose("返回列表");await _choose("返回");await _frame(4)
		_same(cancelled,"Failed fitting exit→pause→load-slot detail/back remains write-free")
		_stale(stale,"Exit retry invalidated by cancel")
		app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);await _frame(3)
		if branch == "retry":
			check(DirAccess.rename_absolute(blocker,blocker+".owned-blocker") == OK,"Recover exit storage")
			await _choose("重试保存",true)
			check(app.exits == 1 and not app.save_warning,"Explicit recovered exit requests one clean exit")
			var data=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
			check(data.version == 16 and app.state._same_save_value(data.player,expected),"Explicit exit stores only real current16 fields")
			check(DirAccess.remove_absolute(blocker+".owned-blocker") == OK,"Remove owned exit blocker")
		else:
			await _choose("不保存离开");check(app.exits == 0,"Discard requires second confirmation")
			await _choose("继续留在江湖");check(app.exits == 0,"Cancel discard keeps game")
			app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);await _frame(2)
			await _choose("不保存离开");await _choose("确认不保存离开")
			check(app.exits == 1,"Only explicit second discard confirmation exits")
			for path: String in baseline_files:check(_inventory()[path] == baseline_files[path],"Confirmed discard retains old file " + path)
			check(DirAccess.remove_absolute(blocker) == OK,"Remove only owned empty discard blocker")
	_end()

func _writer_load() -> void:
	_begin("writer_load");await _create(_prepared(),true)
	if not await _open_court():return
	var panel=await _start_trial("guard")
	if panel == null:return
	await _terminal(panel,true)
	check(app.state.fitting_comparison_snapshot().results.size() == 1,"Result available before actual load")
	await _fit("close",true);await _tap(KEY_F5)
	var saved=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
	check(saved.version == 16 and saved.player.weapon_fitting == "plain","Normal F5 writes16 even without installing optional fitting")
	check(not saved.player.has("trial_candidate") and not saved.player.has("fitting_comparisons"),"No borrowed/result persistent fields")
	await _tap(KEY_F9)
	check(app.state.fitting_comparison_snapshot().results.is_empty(),"Actual F9 clears session history")
	check(not app.web_save_transfer_enabled,"Existing web transfer remains default off")
	var loaded: Dictionary=app.state.to_dict().duplicate(true)
	await _tap(KEY_F6);await _choose("手记一",true)
	if _button("确认重写") != null:await _choose("确认重写",true)
	var manual=JSON.parse_string(FileAccess.get_file_as_string(Slots.new().path_for(1)))
	check(manual != null and manual.version == 16 and app.state._same_save_value(manual.player,loaded),"Actual manual slot UI uses same writer16 without fitting history")
	_end()

func _focus_by_tab(target: Control) -> void:
	root.gui_release_focus()
	for i: int in range(25):
		await _tap(KEY_TAB)
		if root.gui_get_focus_owner() == target:
			check(target.focus_mode == Control.FOCUS_ALL,"Actual Tab reaches announced interactive control")
			return
	check(false,"Tab failed to reach " + target.name)

func _position_release() -> void:
	_begin("position_release")
	for mode: String in ["movement","state_replacement","world_replacement","stored_position_change","map_change","explicit_save","load","new_journey","title"]:
		await _create(_prepared(),true)
		if not await _open_workshop():return
		var original: Dictionary=_diverge();await _frame(3)
		await _click(app.overlay.find_child("FittingClose",true,false));await _frame(4)
		_same(original,"Idle dismissal holds position before release: " + mode)
		match mode:
			"movement":
				app.world.set_process(true);Input.action_press("move_right");await _frame(5);Input.action_release("move_right");await _frame(2);app.world.set_process(false)
				check(app.world.player_pos != original.world_position,"Actual held movement resumes world walking")
			"state_replacement":app.state=app.state._detached_persistent_state();await _frame(3)
			"world_replacement":
				var original_world=app.world;var replacement=original_world.duplicate()
				root.add_child(replacement);replacement.set_process(false);replacement.player_pos=original_world.player_pos+Vector2(6,0)
				app.world=replacement;await _frame(3)
				check(app.state.position == replacement.player_pos and app._fitting_position_hold.is_empty(),"Replacing live world reference releases old fitting position hold")
				app.world=original_world;replacement.queue_free();await _frame(3)
			"stored_position_change":app.state.position+=Vector2(10,0);await _frame(3)
			"map_change":app.state.map_id="sluice";app.world.change_map("sluice",Vector2(300,520));await _frame(3)
			"explicit_save":await _tap(KEY_F5)
			"load":await _tap(KEY_F9)
			"new_journey":
				await _tap(KEY_ESCAPE);await _choose("返回首页");await _choose("保存并离开");await _choose("踏入江湖");await _choose("确认新旅程")
			"title":await _tap(KEY_ESCAPE);await _choose("返回首页");await _choose("保存并离开")
		check(app.state.position == app.world.player_pos,"Ordinary position synchronization resumes on intended boundary: " + mode)
		check(app._fitting_position_hold.is_empty(),"Only transient fitting hold released: " + mode)
	_end()

func _rosters_inputs() -> void:
	_begin("rosters_inputs")
	for roster: Array in [["hero"],["hero","shen"],["hero","tang"],["hero","qin"],["hero","shen","tang"],["hero","shen","qin"],["hero","tang","qin"],["hero","qin","tang","shen"]]:
		var s=_prepared("听潮阁",true);check(s.set_party_roster(roster),"Actual prepared selected roster subset")
		await _create(s,true)
		if not await _open_court():return
		var before: Dictionary=_diverge();var panel=await _start_trial("guard")
		if panel == null:return
		check(app.state.party_battle_snapshot().actors.map(func(a):return a.id) == roster,"Exact selected subset, no filled empty slots")
		if roster.size() == 4:
			_audit_start(panel)
			await _tap(KEY_P);check(app.state.party_battle_snapshot().paused,"Actual P pauses at idle safe boundary")
			await _tap(KEY_E);check(app.state.party_battle_snapshot().selected_actor_id == "qin","Actual actor-cycle selects Qin without changing order")
			await _tap(KEY_1);check(not panel.pending_action.is_empty(),"Qin real martial opens ally-target choice")
			await _click(panel.unit_plates.hero)
			check(_actor(app.state.party_battle_snapshot(),"qin").categories.martial.queued,"Pointer queues actual protective martial for hero")
			await _tap(KEY_1);check(not _actor(app.state.party_battle_snapshot(),"qin").categories.martial.queued,"Repeated skill key cancels queued category")
			await _tap(KEY_Q);await _tap(KEY_2);await _tap(KEY_3)
			await _tap(KEY_P);panel._process(0.5);_audit_pending(panel)
			var persisted: Dictionary=app.state.to_dict().duplicate(true);var pending: Dictionary=panel.pending.duplicate(true)
			for key: int in [KEY_F5,KEY_F6,KEY_F9,KEY_F10,KEY_B,KEY_I]:await _tap(key)
			await _tap(KEY_1,true)
			check(app.state.to_dict() == persisted and panel.pending == pending,"Busy battle blocks saves/load/equip/repeated accepted action")
			_finish(panel);var metrics: Dictionary=panel.session.fitting_trial_snapshot().metrics
			panel._finished();check(panel.session.fitting_trial_snapshot().metrics == metrics,"Duplicate renderer completion cannot recount metrics")
			# The remainder remains actual automatic combat, not fabricated results.
			for i: int in range(16):
				if not app.state.battle_active:break
				_tick(panel)
			if app.state.battle_active:
				if panel.art.is_presenting():_finish(panel)
				await _tap(KEY_4);_audit_pending(panel);_finish(panel)
				await _tap(KEY_ESCAPE);_audit_pending(panel);_finish(panel)
			await _frame(3)
			check(not app.state.battle_active,"Input scenario exits through accepted actual retreat")
		else:await _terminal(panel,true)
		_same(before,"Selected roster and real downed/benched resources retained")
	_end()

func _malformed_entry() -> void:
	_begin("malformed_entry")
	for mode: String in ["unknown_fitting","attack_zero","defense_negative","max_hp_zero","unowned_roster","duplicate_roster"]:
		await _create(_prepared(),true)
		match mode:
			"unknown_fitting":app.state.weapon_fitting="unknown"
			"attack_zero":app.state.attack=0
			"defense_negative":app.state.defense=-1
			"max_hp_zero":app.state.max_hp=0
			"unowned_roster":app.state.party_roster.assign(["hero","qin"])
			"duplicate_roster":app.state.party_roster.assign(["hero","hero"])
		var before: Dictionary=_snapshot();var generation: int=app.modal_generation
		var result=app.WeaponFitting.open(app,"plain")
		check(result == null and _panel() == null and not app.active_modal and app.modal_generation == generation,"Malformed genuine State rejected before UI construction: " + mode)
		_same(before,"Malformed entry fails without persistent/file effects: " + mode)
	_end()

func _wording() -> void:
	_begin("wording");await _create(_prepared(),true)
	# A generic unsaved-journey flag is deliberately independent of fitting.
	app.save_warning=true
	if not await _open_workshop():return
	var notice: Label=app.overlay.find_child("FittingSaveNotice",true,false)
	check(notice != null and notice.text.contains("旅程") and not notice.text.contains("已装配选择尚未保存"),"Pre-existing generic save warning does not falsely blame fitting")
	check(_panel().body.get_parsed_text().contains("已装配") and not _panel().body.get_parsed_text().contains("尚未装配：原装"),"Same installed candidate is described as matching installed, not uninstalled")
	await _candidate("edge")
	check(_panel().body.get_parsed_text().contains("尚未装配"),"Different optional candidate remains clearly uninstalled preview")
	_end()
