extends SceneTree
## Genuine-State prepared scene/input safety. Not native pixels, an earned walk,
## package/browser acceptance, or proof that all possible writer calls are spied.
const Main = preload("res://scripts/main.gd")
const MainScene = preload("res://scenes/main.tscn")
const State = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const Objectives = preload("res://scripts/journal_objective_rules.gd")
const Region = preload("res://scripts/heting_region.gd")
const ORACLE = "res://tests/journal_guidance_frozen_oracle.json"
const ORACLE_SHA = "38cb8469799e8169201c06e203cd219901e3d06c159c09998ffc2e577ff0c443"
const TUPLE = ["mode","kind","arc_id","step_key","destination_map","destination_site","next_target_id","route_status"]

class MainProbe extends Main:
	var autosave_attempts: int = 0
	var manual_attempts: int = 0
	var observed_notices: Array = []
	func _autosave() -> void:
		autosave_attempts += 1
		super._autosave()
	func _save() -> void:
		manual_attempts += 1
		super._save()
	func _toast(text: String, is_save_notice: bool = false, duration: float = 7.0) -> void:
		observed_notices.append(text)
		super._toast(text,is_save_notice,duration)

var app
var checks: int = 0
var failures: Array = []
var cases: Array = []
var trace: Array = []
var case_id: String = "setup"
var filter: String = ""
var output: String = ""
var user_root: String = ""
var corpus: Dictionary = {}
var use_probe: bool = true

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append({"case":case_id,"label":label})
		push_error("JOURNAL_SCENE [%s] %s" % [case_id,label])
	return ok
func _frame(count: int = 2) -> void:
	for unused: int in count: await process_frame
func _begin(id: String) -> void:
	case_id=id; print("JOURNAL_SCENE_CASE " + id)
func _end() -> void:
	cases.append({"case":case_id,"checks":checks,"failures":failures.size()})
func _tap(key: int, echo: bool = false, shift: bool = false) -> void:
	var event = InputEventKey.new()
	event.keycode=key; event.physical_keycode=key; event.pressed=true; event.echo=echo; event.shift_pressed=shift
	Input.parse_input_event(event); await _frame(1)
	event=InputEventKey.new(); event.keycode=key; event.physical_keycode=key; event.shift_pressed=shift
	Input.parse_input_event(event); await _frame(2)
	trace.append({"case":case_id,"input_key":key,"echo":echo,"shift":shift})
func _click(control: Control, wheel: int = 0) -> void:
	if not check(is_instance_valid(control),"Actual pointer target exists"): return
	var rect: Rect2 = control.get_global_rect()
	if control is Button and control.has_meta("journal_row"):
		_panel()._list_scroll.ensure_control_visible(control); await _frame(2); rect=control.get_global_rect()
	check(rect.has_area() and root.get_visible_rect().encloses(rect),"Actual pointer target in logical viewport: " + str(control.name))
	var point: Vector2 = root.get_final_transform() * rect.get_center()
	var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	Input.parse_input_event(motion); await _frame(1)
	for down: bool in [true,false]:
		var event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT if wheel==0 else wheel; event.pressed=down
		Input.parse_input_event(event); await _frame(1)
	await _frame(2)
func _buttons(node: Node = null) -> Array:
	if node==null: node=app.overlay
	var result: Array=[]
	if node is Button and node.is_visible_in_tree(): result.append(node)
	for child: Node in node.get_children(): result.append_array(_buttons(child))
	return result
func _button(fragment: String):
	for button: Button in _buttons():
		if button.text.contains(fragment): return button
	return null
func _callback(button) -> Callable:
	if not is_instance_valid(button): return Callable()
	for value: Dictionary in button.pressed.get_connections():
		if value.callable.is_valid(): return value.callable
	return Callable()
func _choose(fragment: String) -> bool:
	var button=_button(fragment)
	if not check(button != null,"Real visible button: " + fragment): return false
	await _click(button); return true
func _text(node: Node = null) -> String:
	if node==null: node=app.overlay
	var text: String=node.text+"\n" if node is Label or node is RichTextLabel or node is Button else ""
	for child: Node in node.get_children(): text+=_text(child)
	return text
func _panel(): return app.overlay.get_meta("journal_ui") if app.overlay.has_meta("journal_ui") else null
func _tuple(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key: String in TUPLE: result[key]=snapshot.get(key)
	return result
func _shared(label: String, expected_target: String = "*", expected_arc: String = "*") -> void:
	var value: Dictionary=app.journal_guidance_snapshot
	var tuple: Dictionary=_tuple(value)
	check(_tuple(app.hud.journal_guidance_snapshot)==tuple,label+": HUD shares host semantic tuple")
	check(_tuple(app.world.journal_guidance_snapshot)==tuple,label+": world/compass share host semantic tuple")
	check(app.world._quest_target_id()==value.next_target_id,label+": marker/compass target validates shared snapshot")
	check(app.quest_label.text==value.arc_title,label+": displayed HUD title from shared snapshot")
	if _panel()!=null: check(_tuple(_panel().guidance_copy())==tuple,label+": J current strip shares semantic tuple")
	if app.overlay.get_meta("journal_map",false):
		var chart=app.overlay.find_child("RegionChart",true,false)
		check(chart!=null and _tuple(chart.journal_guidance_snapshot)==tuple,label+": M shares semantic tuple")
		check(chart.current_target==value.next_target_id,label+": M local target equals current snapshot")
		check(chart.cart_route==value.cart_route,label+": M draws supplied route only")
	if expected_target!="*": check(value.next_target_id==expected_target,label+": independent expected target " + expected_target)
	if expected_arc!="*": check(value.arc_id==expected_arc,label+": independent expected arc " + expected_arc)
	trace.append({"case":case_id,"coherence":label,"tuple":tuple})
func _inventory(path: String = "user://", prefix: String = "") -> Dictionary:
	var result: Dictionary={}; var dir=DirAccess.open(path)
	if dir==null: return result
	dir.list_dir_begin(); var name=dir.get_next()
	while not name.is_empty():
		if name not in [".",".."]:
			var relative=prefix+name
			if dir.current_is_dir(): result[relative+"/"]={"directory":true}; result.merge(_inventory(path.path_join(name),relative+"/"))
			else:
				var file=path.path_join(name); var bytes=FileAccess.get_file_as_bytes(file)
				result[relative]={"bytes":bytes,"sha256":FileAccess.get_sha256(file),"size":bytes.size()}
		name=dir.get_next()
	dir.list_dir_end(); return result
func _identities() -> Dictionary:
	var lines: Array=[]
	var code: String="import os,json,sys; r=sys.argv[1]; print(json.dumps({os.path.relpath(os.path.join(p,n),r):[os.lstat(os.path.join(p,n)).st_ino,os.lstat(os.path.join(p,n)).st_mtime_ns,os.lstat(os.path.join(p,n)).st_size] for p,ds,fs in os.walk(r) for n in sorted(ds+fs)},sort_keys=True))"
	var status: int=OS.execute("python3",PackedStringArray(["-c",code,user_root]),lines)
	if not check(status==0 and not lines.is_empty(),"Read-only user-file inode/nanosecond inventory"): return {}
	var parsed=JSON.parse_string(lines[0]); return parsed if parsed is Dictionary else {}
func _transients() -> Dictionary:
	var result: Dictionary={}
	for property: Dictionary in app.state.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0: continue
		var key: String=property.name; var value: Variant=app.state.get(key)
		if value is Object: result[key]={"object_id":value.get_instance_id() if is_instance_valid(value) else 0}
		elif value is Dictionary or value is Array: result[key]=value.duplicate(true)
		else: result[key]=value
	return result
func _snapshot() -> Dictionary:
	return {"state":app.state.to_dict().duplicate(true),"transients":_transients(),"state_id":app.state.get_instance_id(),"world_map":app.world.map_id,"world_position":app.world.player_pos,"files":_inventory(),"identities":_identities(),"auto":app.autosave_attempts if use_probe else -1,"manual":app.manual_attempts if use_probe else -1,"zoom":app.view_zoom}
func _same(before: Dictionary, label: String, files: bool = true) -> void:
	check(app.state.to_dict()==before.state,label+": full canonical State unchanged")
	check(_transients()==before.transients,label+": State transients/resources/gates/counters unchanged")
	check(app.state.get_instance_id()==before.state_id,label+": same exact production State identity")
	check(app.world.map_id==before.world_map and app.world.player_pos==before.world_position,label+": world map/position unchanged")
	check(app.view_zoom==before.zoom,label+": view preference unchanged")
	if files:
		check(_inventory()==before.files,label+": every user-file path and exact byte unchanged")
		check(_identities()==before.identities,label+": no same-byte inode replacement or mtime write")
	if use_probe: check(app.autosave_attempts==before.auto and app.manual_attempts==before.manual,label+": no Main _save/_autosave entry attempted")
	trace.append({"case":case_id,"preservation":label,"canonical":before.state,"user_manifest":_public_files(before.files),"identities":before.identities})
func _public_files(files: Dictionary) -> Dictionary:
	var result=files.duplicate(true)
	for key: String in result: result[key].erase("bytes")
	return result
func _read(data: Dictionary):
	var inspected=State.new().inspect_save_bytes(JSON.stringify({"version":16,"player":data}).to_utf8_buffer())
	if not check(inspected.ok,"Prepared bytes accepted by unchanged production State reader"): return State.new()
	check(inspected.state._same_save_value(inspected.state.to_dict(),data),"Production reader preserves prepared canonical bytes semantically")
	return inspected.state
func _retained(label: String):
	for row: Dictionary in corpus.rows:
		if row.label==label: return _read(row.state)
	check(false,"Pinned oracle input exists: "+label); return State.new()
func _rich(fitting: String = "plain"):
	var state=_retained("bounded_qin_tang_fix_1_1")
	check(state.recruit_companion(),"Prepared actual Shen recruitment helper")
	check(state.recover_craft_notes() and state.resolve_tangqi_quest("teach") and state.recruit_tangqi(),"Prepared actual Tang helper chain")
	check(state.inspect_qin_rope() and state.arrange_qin_handoff() and state.recruit_qin(),"Prepared actual Qin helper chain")
	check(state.set_party_roster(["hero","qin","tang"]),"Prepared non-default order with benched Shen")
	state.party_resources.shen.hp=0; state.party_resources.shen.qi=0
	state.party_resources.tang.hp=9; state.party_resources.tang.qi=1
	state.party_resources.qin.hp=7; state.party_resources.qin.qi=0
	state.hp=17; state.qi=0; state.medicine=0; state.map_id="qingwei"; state.position=Vector2(460,430)
	check(state.set_weapon_fitting(fitting).ok,"Prepared real fitting " + fitting)
	return _read(state.to_dict())
func _create(state = null, wrapped: bool = true) -> void:
	if is_instance_valid(app): app._stop_audio(); app.queue_free(); await _frame(3)
	use_probe=wrapped
	if state==null: state=_retained("bounded_qin_tang_fix_1_1")
	app=MainScene.instantiate()
	if wrapped: app.set_script(MainProbe)
	var prepared_position: Vector2=state.position
	app.state=state; root.add_child(app); app.set_process(false); app.world.set_process(false); await _frame(3)
	app._stop_audio(); app.audio_on=false; app.world.set_process(false)
	app.current_screen="explore"; app.modal_autosave_on_close=false; app._close_modal()
	state.position=prepared_position; app.world.change_map(state.map_id,prepared_position); app._sync_world_state(); app._refresh(); app.set_process(true); app.world.set_process(true); await _frame(2)
	check(app.state.get_script().resource_path=="res://scripts/game_state.gd","Exact production State, no save/reader override")
	check(app.get_script()==MainProbe if wrapped else app.get_script()==Main,"Explicit Main instrumentation scope")
	check(state.save_game()==OK,"Test-owned genuine baseline autosave")
	var slots=Slots.new()
	for slot: int in [1,2]:
		check(slots.save_slot(state,slot)==OK,"Test-owned manual baseline primary")
		state.coins+=1; check(slots.save_slot(state,slot)==OK,"Test-owned manual baseline backup")
	state.coins+=7
	if wrapped: app.autosave_attempts=0; app.manual_attempts=0; app.observed_notices.clear()
	app.save_warning=false; await _frame(2)
func _open() -> bool:
	await _tap(KEY_J)
	return check(_panel()!=null and app.active_modal and not app.modal_autosave_on_close and app.modal_actions.is_empty(),"Actual J enters dedicated read-only input owner")
func _browse(id: String, mouse: bool = true) -> bool:
	if not check(_panel()!=null,"Journal open before row browse"): return false
	if not _panel().row_buttons.has(id) and _panel().action_buttons.has("completed"):
		await _click(_panel().action_buttons.completed)
	if not check(_panel().row_buttons.has(id),"Earned visible row " + id): return false
	if mouse: await _click(_panel().row_buttons[id])
	else: _panel().row_buttons[id].grab_focus(); await _tap(KEY_ENTER)
	return check(_panel()!=null and _panel().browse_arc_id==id,"Native row activation browses " + id)
func _track(id: String) -> bool:
	if not await _browse(id): return false
	if not check(not _panel().action_buttons.track.disabled,"Track explicitly enabled for "+id): return false
	await _click(_panel().action_buttons.track)
	return check(app.journal_session.tracked_arc_id==id and _panel()!=null,"Explicit mouse Track keeps J open and selects "+id)
func _stale(callback: Callable, label: String) -> void:
	var before=_snapshot(); var selected=app.journal_session.tracked_arc_id; var generation=app.modal_generation
	if callback.is_valid(): callback.call()
	_same(before,label)
	check(app.journal_session.tracked_arc_id==selected and app.modal_generation==generation,label+": no session/owner replacement")

func _unwrapped_main() -> void:
	_begin("unwrapped_main"); await _create(State.new(),false)
	var before=_snapshot()
	if not await _open(): return
	check(_panel().row_buttons.keys()==["opening"],"Fresh actual Main reveals only earned opening row")
	_shared("Unwrapped fresh opening","elder","opening")
	await _tap(KEY_ENTER); check(_panel()!=null and app.journal_session.tracked_arc_id.is_empty(),"Initial row Enter neither tracks nor generic-closes")
	await _click(_panel().action_buttons.history); await _tap(KEY_END); await _tap(KEY_ESCAPE)
	check(_panel()!=null and _panel().page=="journal","History Escape returns exactly once")
	await _tap(KEY_ESCAPE); await _tap(KEY_M); _shared("Unwrapped M","elder","opening")
	await _tap(KEY_ENTER); await _frame(4)
	await _click(app.hud.nav_buttons[3]); check(_panel()!=null,"Actual HUD pointer opens J")
	_panel().action_buttons.close.grab_focus(); await _frame(2); await _tap(KEY_ENTER)
	check(_panel()==null and not app.active_modal,"Focused native Close Enter dismisses exactly once")
	_same(before,"Unwrapped actual Main J/history/back/M close/HUD mouse")
	_end()

func _input_files() -> void:
	_begin("input_files")
	for fitting: String in ["plain","edge","guard"]:
		await _create(_rich(fitting)); app.save_warning=true; app._toast("Prepared existing unsaved-journey warning")
		app.world.teleport(app.world.player_pos+Vector2(2,0))
		var before=_snapshot()
		app._show_journal(); await _frame(3)
		if not check(_panel()!=null,"Synchronous J entry before ordinary frame can sync injected divergence"): return
		check(app._journal_position_hold.stored!=app._journal_position_hold.anchor,"J holds deliberately divergent stored/world positions")
		var original=_tuple(app.journal_guidance_snapshot)
		if not await _browse("heting_delivery"): return
		check(_panel()._row("heting_delivery").status=="available" and app.state.heting_stage==0,"Known stage0 row stays available/unaccepted")
		check(_tuple(app.journal_guidance_snapshot)==original and app.journal_session.tracked_arc_id.is_empty(),"Mouse browse never changes current shared guidance")
		var focus=_panel().row_buttons.heting_delivery; focus.grab_focus()
		await _tap(KEY_ENTER); await _tap(KEY_SPACE)
		check(_panel()!=null and app.journal_session.tracked_arc_id.is_empty(),"Native row Enter/Space do not invoke generic first action")
		await _tap(KEY_HOME); await _tap(KEY_END); await _tap(KEY_PAGEUP); await _tap(KEY_PAGEDOWN); await _tap(KEY_UP); await _tap(KEY_DOWN)
		check(app.journal_session.tracked_arc_id.is_empty(),"List navigation only browses")
		if not await _browse("opening"): return
		check(_panel()._row("opening").status=="completed" and _panel().action_buttons.track.disabled,"Completed row readable but cannot Track")
		var focused: Dictionary={}
		for step: int in range(_panel()._focus_order.size()+2):
			await _tap(KEY_TAB); var owner=root.gui_get_focus_owner()
			if owner is Button: check(not owner.disabled,"Tab skips disabled actions")
			if owner!=null: focused[str(owner.name)]=true
		await _tap(KEY_TAB,false,true)
		check(focused.has("JournalAction_close"),"Actual Tab cycle reaches footer Close")
		if not await _track("heting_delivery"): return
		_shared("Manual available harbor","exit_sluice","heting_delivery")
		check(app.state.heting_stage==0 and _panel()._row("heting_delivery").status=="available","Track does not accept story")
		var selected=app.journal_session.tracked_arc_id; var revision=app.journal_guidance_revision
		_panel().track_selected(); _panel().track_selected(); await _frame()
		check(app.journal_guidance_revision==revision and app.journal_session.tracked_arc_id==selected,"Redundant Track is no-op")
		for key: int in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_E,KEY_M,KEY_F5,KEY_F9,KEY_F6,KEY_F10,KEY_B,KEY_I,KEY_K,KEY_EQUAL,KEY_MINUS]:
			await _tap(key)
			check(_panel()!=null and app.journal_session.tracked_arc_id==selected,"J owns blocked global key "+str(key))
		await _tap(KEY_J,true); await _tap(KEY_ESCAPE,true); await _tap(KEY_ENTER,true)
		check(_panel()!=null,"Echo never closes/reopens/activates")
		var owner=_panel(); await _click(app.hud.music_button); await _click(app.hud.nav_buttons[0])
		check(_panel()==owner and not app.audio_on,"Full overlay blocks actual clicks on underlying music/map HUD")
		await _click(_panel().action_buttons.history)
		var browse=_panel().browse_arc_id; _panel().body.grab_focus(); await _tap(KEY_END)
		check(_panel().body.get_v_scroll_bar().value>0,"Earned full-history keyboard scroll reaches later content")
		await _tap(KEY_HOME); await _click(_panel().body,MOUSE_BUTTON_WHEEL_DOWN)
		check(_panel().body.get_v_scroll_bar().value>0 and _panel().browse_arc_id==browse,"Wheel scrolls history without row or selection change")
		await _tap(KEY_ESCAPE); _panel().action_buttons.auto.grab_focus(); await _frame(2); await _tap(KEY_ENTER)
		check(app.journal_session.tracked_arc_id.is_empty() and _panel()!=null,"RestoreAuto native Enter is explicit; J stays open")
		await _browse("heting_delivery"); _panel().action_buttons.track.grab_focus(); await _frame(2); await _tap(KEY_SPACE)
		check(app.journal_session.tracked_arc_id=="heting_delivery" and _panel()!=null,"Native focused Track Space activates once without generic handler")
		await _click(_panel().action_buttons.auto)
		_panel().restore_auto(); _panel().restore_auto(); await _frame(3)
		check(app.save_warning and app.status_label.text.contains("⚠"),"Guidance does not lose pending save warning")
		await _click(_panel().action_buttons.close); await _tap(KEY_M); _shared("M after Auto")
		await _click(app.overlay.find_child("RegionChart",true,false)); await _tap(KEY_1); await _frame(4)
		_same(before,"All read-only real-input paths with fitting "+fitting)
	_end()

func _stale_owners() -> void:
	_begin("stale_owners"); await _create()
	if not await _open(): return
	if not await _browse("tang_notes"): return
	var old_track=_callback(_panel().action_buttons.track)
	await _browse("qin_rope"); await _browse("tang_notes"); _stale(old_track,"Row A→B→A old Track")
	var old_close=_callback(_panel().action_buttons.close); var old_history=_callback(_panel().action_buttons.history)
	await _click(_panel().action_buttons.history); var old_back=_callback(_panel().action_buttons.back)
	await _tap(KEY_ESCAPE); _stale(old_close,"Pre-history Close"); _stale(old_history,"Pre-history History"); _stale(old_back,"Prior history Back")
	old_track=_callback(_panel().action_buttons.track)
	await _tap(KEY_ESCAPE); await _open(); _stale(old_track,"Closed owner cannot act on reopened J")
	if not await _track("tang_notes"): return
	var auto=_callback(_panel().action_buttons.auto); var close=_callback(_panel().action_buttons.close)
	app.journal_session.invalidate_callbacks(); _stale(auto,"Session epoch Auto"); _stale(close,"Session epoch Close")
	app._refresh(); _panel().refresh_guidance(app.journal_guidance_snapshot,app.journal_guidance_revision); await _frame(2)
	for mode: String in ["generation","state","world","session","battle","pending","quit"]:
		var panel=_panel(); var callback=_callback(panel.action_buttons.auto)
		var previous_state=app.state; var previous_world=app.world; var previous_session=app.journal_session; var generation=app.modal_generation
		match mode:
			"generation": app.modal_generation+=1
			"state": app.state=_read(app.state.to_dict())
			"world": app.world=app.world.duplicate()
			"session": app.journal_session=app.JournalSession.new(); app.journal_session.reset(app.state)
			"battle": app.state.battle_active=true
			"pending": app.state._party_pending_token=44
			"quit": app.quit_pending=true
		if callback.is_valid(): callback.call()
		check(app.overlay.get_meta("journal_ui")==panel and app.modal_generation==(generation+1 if mode=="generation" else generation),"Bound callback rejected under "+mode)
		if mode=="world": app.world.free()
		app.state=previous_state; app.world=previous_world; app.journal_session=previous_session; app.modal_generation=generation; app.state.battle_active=false; app.state._party_pending_token=-1; app.quit_pending=false
		app._refresh(); await _frame(2)
	await _tap(KEY_ESCAPE)
	for owner: String in ["weapon_fitting","party_roster","party_roster_direct_info","receipt_battle","party_battle","courtyard_practice","save_transfer","fitting_workshop_readonly","fitting_exit_readonly"]:
		app.overlay.set_meta(owner,true); var generation=app.modal_generation; var before=_snapshot()
		app._show_journal(); check(_panel()==null and app.modal_generation==generation,"J cannot replace protected owner "+owner); _same(before,"Protected owner "+owner)
		app.overlay.remove_meta(owner)
	# Existing generic dialogue remains replaceable explicitly; its guarded action dies.
	app._modal("Existing dialogue","test","Prepared generic owner",[["close",app._close_modal]])
	var story=_callback(_button("close")); app._show_journal(); await _frame(2); _stale(story,"Stale generic story action after explicit J replacement")
	await _tap(KEY_ESCAPE); _end()

func _position_holds() -> void:
	_begin("position_holds")
	for entry: String in ["J","M"]:
		for release: String in ["movement","save","travel","world","state","load","new"]:
			await _create()
			app.world.teleport(app.world.player_pos+Vector2(3,0)); var before=_snapshot()
			if entry=="J": app._show_journal()
			else: app._show_map()
			await _frame(5); _same(before,entry+" synchronous-entry held divergence")
			await _tap(KEY_ESCAPE); await _frame(4); _same(before,entry+" close stays read-only")
			match release:
				"movement":
					app.world.set_process(true); Input.action_press("move_right"); await _frame(8); Input.action_release("move_right"); await _frame(2); app.world.set_process(false)
					check(app.world.player_pos!=before.world_position,"Actual world movement occurs after dismissal")
				"save": await _tap(KEY_F5)
				"travel": app._travel("frostbridge",Vector2(1450,620)); await _frame(3)
				"world":
					var original=app.world; var replacement=original.duplicate(); root.add_child(replacement); replacement.set_process(false); replacement.player_pos+=Vector2(6,0); app.world=replacement; await _frame(3)
					check(app._journal_position_hold.is_empty() and app.state.position==replacement.player_pos,"Replacing World releases old journal hold")
					app.world=original; replacement.queue_free(); await _frame(3)
				"state": app.state=_read(app.state.to_dict()); await _frame(3)
				"load": await _tap(KEY_F9)
				"new": app._new_game(); await _frame(3)
			check(app._journal_position_hold.is_empty() and app.state.position==app.world.player_pos,entry+" hold released by "+release)
	# Fitting's independent hold is neither overwritten nor erased by J/M.
	await _create(_rich()); app.world.teleport(app.world.player_pos+Vector2(2,0))
	app.WeaponFitting.open(app,"plain"); await _frame(3)
	var fitting=app._fitting_position_hold.duplicate(true); var before=_snapshot()
	await _click(app.overlay.find_child("FittingClose",true,false)); await _open(); await _tap(KEY_ESCAPE); await _tap(KEY_M); await _tap(KEY_ESCAPE); await _frame(4)
	check(not app._fitting_position_hold.is_empty() and app._fitting_position_hold.stored==fitting.stored,"J/M preserve existing fitting position-hold ownership")
	_same(before,"Fitting→J→M retains all divergence and real resources")
	_end()

func _load_storage() -> void:
	_begin("load_storage"); await _create(); await _open(); await _track("tang_notes"); await _tap(KEY_ESCAPE)
	var identity=app.state.get_instance_id(); await _tap(KEY_F9)
	check(app.state.get_instance_id()==identity and app.journal_session.tracked_arc_id.is_empty(),"Actual F9 same-State successful load resets selection")
	await _open(); await _track("tang_notes"); await _tap(KEY_ESCAPE)
	# Cancel through the actual manual-load confirmation UI; no load is applied.
	await _tap(KEY_F10); await _choose("手记一"); await _choose("读取当前版本")
	var cancel_state=app.state.to_dict().duplicate(true)
	await _choose("返回详情")
	check(app.state.to_dict()==cancel_state and app.journal_session.tracked_arc_id=="tang_notes","Cancelled actual load retains journey and tracked arc")
	await _choose("读取当前版本"); await _choose("确认读取"); await _frame(3)
	check(app.state.get_instance_id()==identity and app.journal_session.tracked_arc_id.is_empty(),"Actual manual-slot same-State successful load resets selection")
	await _open(); await _track("tang_notes"); await _tap(KEY_ESCAPE)
	# Corrupt only this isolated run's auto slot. Preserve the exact injected file.
	var file=FileAccess.open(State.SAVE_PATH,FileAccess.WRITE); file.store_string("{invalid owned test bytes"); file.close()
	var failed=_snapshot(); await _tap(KEY_F9); _same(failed,"Failed actual quick load")
	check(app.journal_session.tracked_arc_id=="tang_notes","Failed actual quick load retains selection")
	var slot_path=Slots.new().path_for(2); file=FileAccess.open(slot_path,FileAccess.WRITE); file.store_string("{invalid owned manual slot"); file.close()
	failed=_snapshot(); app.save_slots.perform_load(2,false); _same(failed,"Failed actual slot store load")
	check(app.journal_session.tracked_arc_id=="tang_notes","Failed manual load retains selection")
	# Storage-only synthetic scope: neither browser adapter nor transfer UI enabled.
	check(not app.web_save_transfer_enabled,"Browser save transfer still default-off")
	var transfer=Transfer.new(); var before=_snapshot(); var exported=transfer.export_slot(1)
	check(exported.ok,"Underlying-store export reads real prepared manual slot")
	_same(before,"Synthetic underlying-store export")
	check(app.journal_session.tracked_arc_id=="tang_notes","Storage-only export does not reset active selection")
	var destination=Slots.new().path_for(3)
	# Each attempt starts fresh; slot3 intentionally has no existing data.
	check(transfer.target_available(3),"Synthetic import target is empty manual slot3")
	var preview=transfer.preview_import(exported.bytes,3)
	check(preview.ok and transfer.commit_import(preview.token).ok,"Synthetic storage-only import commits exact valid bytes to empty slot")
	_same(before,"Synthetic import does not apply the imported journey",false)
	check(app.journal_session.tracked_arc_id=="tang_notes" and FileAccess.get_file_as_bytes(destination)==exported.bytes,"Import retains active selection and exact destination bytes")
	var after=_inventory()
	for path: String in before.files: check(after.get(path)==before.files[path],"Storage-only import preserves existing user file "+path)
	check(after.size()==before.files.size()+1,"Storage-only import adds only intended empty manual slot")
	trace.append({"case":case_id,"scope":"Underlying LocalSaveTransfer only; feature remains off; not browser-transfer acceptance"})
	_end()

func _save_exit() -> void:
	_begin("save_exit"); await _create(_rich("guard")); await _open(); await _track("heting_delivery"); await _tap(KEY_ESCAPE)
	app.world.teleport(app.world.player_pos+Vector2(2,0)); app.state.coins+=3
	var canonical=app.state.to_dict().duplicate(true); canonical.position={"x":app.world.player_pos.x,"y":app.world.player_pos.y}
	var blocker=State.SAVE_PATH+".tmp"
	check(DirAccess.make_dir_absolute(blocker)==OK,"Owned real atomic-save blocker created")
	var old_files=_inventory(); await _tap(KEY_ESCAPE); await _choose("返回首页"); await _choose("保存并离开")
	check(app.current_screen=="explore" and not app.quit_pending and app.save_warning,"Real explicit save-and-leave fails safely in journey")
	check(app.state._same_save_value(app.state.to_dict(),canonical) and _inventory()==old_files,"Failure preserves disk and exact real journey with explicit position sync only")
	var retry=_callback(_button("重试保存")); await _choose("重试保存")
	check(_inventory()==old_files and app.save_warning,"Second actual failure does not rewrite previous disk")
	await _choose("返回小憩"); var selected=app.journal_session.tracked_arc_id
	if retry.is_valid(): retry.call()
	check(_inventory()==old_files and app.journal_session.tracked_arc_id==selected,"Cancelled stale explicit retry cannot reenter save")
	check(DirAccess.rename_absolute(blocker,blocker+".owned-blocker")==OK,"Recover only this test-owned blocker")
	await _choose("返回首页"); await _choose("保存并离开"); await _frame(3)
	check(app.current_screen=="title" and not app.save_warning,"Actual recovered save-and-leave reaches title")
	var document=JSON.parse_string(FileAccess.get_file_as_string(State.SAVE_PATH))
	check(document.version==16 and app.state._same_save_value(document.player,canonical),"Retry writes actual real journey only, schema16")
	for path: String in old_files:
		if path.begins_with("hero_slot_"): check(_inventory()[path]==old_files[path],"Explicit exit preserves manual slot/backup "+path)
	check(DirAccess.remove_absolute(blocker+".owned-blocker")==OK,"Remove owned empty recovered blocker")
	trace.append({"case":case_id,"save_count_scope":"PauseMenu calls actual State.save_game directly; MainProbe count does not claim to count these writes. Real errors, preserved prior bytes and successful writer bytes are asserted."})
	_end()

func _route_valid(snapshot: Dictionary, label: String) -> void:
	var route: PackedVector2Array=snapshot.cart_route
	if not check(not route.is_empty(),label+": loaded route exists"): return
	check(route[0]==app.world.player_pos,label+": route begins at exact current physical point")
	check(route[-1]==snapshot.next_target_position,label+": route ends at same immediate physical target")
	for index: int in range(1,route.size()): check(Region.can_step(route[index-1],route[index],app.state.heting_bridge,true),label+": every loaded segment legal "+str(index))
func _cart(new: bool, side: String, plan: String = "hold_for_inspection"):
	var state=_retained("harbor_overlap_1_4")
	state.heting_bridge=side; state.position=Vector2(820,665)
	if new: state.consignee_draft=plan
	else:
		state.consignee_stage=0; state.consignee_observations.clear(); state.consignee_draft=""; state.consignee_cargo_location=""; state.receipt_stage=0
		state.heting_stage=1; state.heting_delivered.clear(); state.heting_cargo="meal"; state.heting_draft=""; state.heting_ending=""
	return _read(state.to_dict())
func _physical_cache() -> void:
	_begin("physical_cache"); await _create(); app.set_process(false); app.world.set_process(false)
	var original=app.world.interactables.duplicate(true); var target=app.journal_guidance_snapshot.next_target_id
	app.world.map_id="qingwei"; app._sync_journal_guidance(); _shared("Half-transition physical mismatch","", "qin_rope")
	app.world.map_id="mistwood"; app.world.interactables.erase(target); app._sync_journal_guidance(); _shared("Missing physical target","","qin_rope")
	app.world.interactables=original.duplicate(true); app.world.interactables[target].pos=Vector2.INF; app._sync_journal_guidance(); _shared("Nonfinite physical marker","","qin_rope")
	app.world.interactables=original.duplicate(true); app.world.player_pos=Vector2.INF; app._sync_journal_guidance(); _shared("Nonfinite physical position","","qin_rope")
	app.world.player_pos=app.state.position; app._sync_journal_guidance(); _shared("Coherent recovery","mist_rain_gauge","qin_rope")
	var detached=app.journal_preview("qin_rope"); detached.marker_view.markers.mist_rain_gauge.pos=Vector2.ZERO; detached.arc_title="mutated caller copy"
	var rows=app.journal_catalog(); rows[0].display_title="mutated catalog"
	check(app.journal_preview("qin_rope").arc_title!="mutated caller copy" and app.world.interactables.mist_rain_gauge.pos==original.mist_rain_gauge.pos and app.journal_catalog()[0].display_title!="mutated catalog","Detached published/cache/catalog output mutation is harmless")
	# In-place fact changes must invalidate cache; do not mutate the model sources.
	app.state.resources.timber=1; var fact_metrics=app.journal_view.metrics; app.journal_catalog(); app._sync_journal_guidance()
	check(app.journal_view.metrics.catalog_builds>fact_metrics.catalog_builds,"In-place relevant dictionary fact mutation cannot hide behind cached alias")
	app.set_process(true); app.world.set_process(true)
	var marker_state=_retained("harbor_overlap_1_4")
	marker_state.consignee_stage=0; marker_state.consignee_observations.clear(); marker_state.consignee_draft=""; marker_state.consignee_cargo_location=""; marker_state.position=Vector2(535,350)
	await _create(_read(marker_state.to_dict()))
	check(app.state.begin_consignee(),"Existing state transition reveals consignee first action")
	app._refresh()
	check(app.world.interactables.has("consignee_warehouse"),"Host sync materializes earned marker before publishing guidance")
	await _open(); await _track("heting_consignee"); _shared("State-driven marker sync","consignee_warehouse","heting_consignee"); await _tap(KEY_ESCAPE)
	for learned: bool in [false,true]:
		var state=_retained("bounded_qin_tang_fix_1_1"); state.map_id="qingwei"; state.position=Vector2(1514,930); state.lightness_unlocked=learned
		await _create(_read(state.to_dict())); var before=_snapshot(); await _open(); await _track("tang_notes")
		_shared("Qingwei islet return first skill="+str(learned),"reed_return","tang_notes")
		await _tap(KEY_ESCAPE); await _tap(KEY_M); _shared("Islet M return","reed_return","tang_notes"); await _tap(KEY_ESCAPE)
		_same(before,"Islet guidance never crosses or rewards")
	var learned=_retained("bounded_qin_tang_fix_1_1"); learned.map_id="qingwei"; learned.position=Vector2(1420,930); learned.lightness_unlocked=true
	await _create(_read(learned.to_dict())); await _open(); await _track("lightness_islet"); _shared("Shore crossing before relic","reed_cross","lightness_islet"); await _tap(KEY_ESCAPE)
	for new: bool in [false,true]:
		for side: String in ["west","east"]:
			for plan: String in (["hold_for_inspection","return_to_owner"] if new else [""]):
				await _create(_cart(new,side,plan)); var before=_snapshot(); await _open()
				await _track("heting_consignee" if new else "heting_delivery")
				var expected="heting_relief" if not new else ("heting_scale" if plan=="hold_for_inspection" else "heting_cargo")
				_shared("Loaded active cart","" if expected.is_empty() else expected,"heting_consignee" if new else "heting_delivery")
				if new and plan=="return_to_owner": check(app.journal_guidance_snapshot.destination_receiver=="heting_grain_boat" and app.journal_guidance_snapshot.destination_site=="heting_cargo","Rules receiver alias normalized to actual physical boat")
				_route_valid(app.journal_guidance_snapshot,"Initial "+str(new)+side+plan)
				await _tap(KEY_ESCAPE); var metrics=app.journal_view.metrics
				app.set_process(false); app.world.set_process(false)
				for step: int in range(1,21):
					app.world.player_pos=Vector2(820+step,665); app._sync_journal_guidance(); _route_valid(app.journal_guidance_snapshot,"Reanchor "+str(step))
				check(app.journal_view.metrics.full_resolves==metrics.full_resolves and app.journal_view.metrics.route_reanchors>=metrics.route_reanchors+20,"Moving loaded cart reanchors, without expensive full resolver every frame")
				app.set_process(true); app.world.set_process(true); await _tap(KEY_M); _shared("Exact-start loaded M"); _route_valid(app.journal_guidance_snapshot,"M boundary"); await _tap(KEY_ESCAPE)
				# Return to declared measured point for pure browsing preservation.
				app.world.player_pos=before.world_position; app.state.position=Vector2(before.state.position.x,before.state.position.y); app._journal_position_hold.clear(); app._begin_journal_position_hold()
				await _open(); await _track("qin_rope"); _shared("Loaded remote parking","return_mistwood","qin_rope")
				check(app.journal_guidance_snapshot.route_status=="departure_confirmation" and app.journal_guidance_snapshot.route_note.contains("确认"),"Remote loaded objective explicitly requires parking confirmation")
				await _tap(KEY_ESCAPE); await _frame(3); _same(before,"Loaded browsing leaves cargo/bridge/story/resources/disk intact")
				# Prepared placement near real exit, then actual E and Cancel. This
				# story flow may preserve its historical close autosave semantics.
				app.world.teleport(Vector2(150,355)); app.world._update_nearby(); await _frame(3)
				var cargo=app.state.heting_cargo; var location=app.state.consignee_cargo_location; var selected=app.journal_session.tracked_arc_id
				await _tap(KEY_E); check(_text().contains("退车后离开") or _text().contains("停回北仓后离开"),"Actual loaded exit opens existing parking confirmation")
				await _choose("留在")
				check(app.state.map_id=="heting" and app.state.heting_cargo==cargo and app.state.consignee_cargo_location==location and app.journal_session.tracked_arc_id==selected,"Actual parking Cancel retains loaded cargo and tracked arc")
	_end()

func _session_progress() -> void:
	_begin("session_progress"); await _create(); await _open(); await _track("tang_notes"); await _tap(KEY_ESCAPE)
	for destination: String in ["frostbridge","sluice","qingwei","mistwood"]:
		app._travel(destination,Vector2(460,430)); await _frame(3)
		check(app.journal_session.tracked_arc_id=="tang_notes","Existing real travel retains arc in "+destination)
		_shared("Travel shared "+destination)
	# A nontracked browsed row may change while manual guidance stays identical.
	await _open(); await _browse("qin_rope")
	var stale_qin=_callback(_panel().action_buttons.track); var same_tang=_tuple(app.journal_guidance_snapshot)
	check(app.state.inspect_qin_rope() and app.state.arrange_qin_handoff() and app.state.recruit_qin(),"Prepared unchanged Qin helpers reach completed while Tang stays tracked")
	var qin_complete=_snapshot(); app._refresh(); await _frame(3)
	check(_tuple(app.journal_guidance_snapshot)==same_tang and _panel()._row("qin_rope").status=="completed" and _panel().action_buttons.track.disabled,"Fact revision refreshes completed browsed row even when current tracked tuple unchanged")
	_stale(stale_qin,"Old Track cannot revive newly completed untracked row"); _same(qin_complete,"Untracked row completion UI refresh is read-only")
	await _tap(KEY_ESCAPE)
	# Prepared stage advancement through real unchanged story helper; not earned walk.
	check(app.state.recover_craft_notes(),"Existing Tang stage1→2 helper")
	app._refresh(); check(app.journal_session.tracked_arc_id=="tang_notes","Ordinary same-arc stage retains tracking")
	check(app.state.resolve_tangqi_quest("teach"),"Existing Tang stage2→3 helper")
	app._refresh(); check(app.journal_session.tracked_arc_id=="tang_notes" and not app.state.tangqi_unlocked,"Pending explicit invitation still tracked, never auto-recruited")
	await _open(); var stale=_callback(_panel().action_buttons.auto)
	check(app.state.recruit_tangqi(),"Existing explicit recruitment marks terminal; prepared setup")
	var before=_snapshot(); app.observed_notices.clear(); app._refresh(); await _frame(100)
	var notices=app.observed_notices.filter(func(value): return String(value).contains("已完成，已恢复自动指引"))
	check(app.journal_session.tracked_arc_id.is_empty() and notices.size()==1,"Actual selected completion clears once through 100 idle frames")
	_stale(stale,"Completion invalidates old Auto"); _same(before,"Idle completion projection does not reward/heal/recruit/save")
	await _tap(KEY_ESCAPE)
	# Genuine real fitting and roster controllers return without resetting choice.
	await _create(_rich()); await _open(); await _track("heting_delivery"); await _tap(KEY_ESCAPE)
	app.WeaponFitting.open(app,"plain"); await _frame(3); await _click(app.overlay.find_child("FittingClose",true,false))
	check(app.journal_session.tracked_arc_id=="heting_delivery","Real fitting browse/return retains selected arc")
	app._show_party_roster(true); await _frame(3)
	var roster=app.overlay.get_meta("party_roster",null)
	check(roster!=null,"Real roster controller opens")
	if roster!=null: await _click(roster.return_button)
	check(app.journal_session.tracked_arc_id=="heting_delivery","Real roster return retains selected arc")
	app.world.teleport(Vector2(721,757)); await _frame(3)
	var before_battle=_snapshot()
	app.WeaponFitting.open(app,"edge"); await _frame(2)
	await _click(app.overlay.get_meta("weapon_fitting").action_buttons.trial)
	await _click(app.overlay.get_meta("weapon_fitting").action_buttons.start)
	check(app.current_screen=="party_battle" and app.state.battle_active,"Actual fitting UI starts unchanged borrowed party battle")
	if app.current_screen=="party_battle":
		var controller=app.overlay.get_meta("party_battle"); var generation=app.modal_generation
		app._show_journal()
		check(_panel()==null and app.overlay.get_meta("party_battle")==controller and app.modal_generation==generation,"J cannot replace actual live battle owner")
		check(app.journal_session.tracked_arc_id=="heting_delivery","Selected arc persists during actual party battle")
		for attempt: int in 180:
			if not app.state.battle_active: break
			await _tap(KEY_ESCAPE)
		check(not app.state.battle_active and app.current_screen=="explore","Actual Escape retreats at accepted presentation boundary")
		check(app.journal_session.tracked_arc_id=="heting_delivery","Selected arc persists after actual battle return")
		check(app.state.to_dict()==before_battle.state and _inventory()==before_battle.files and _identities()==before_battle.identities,"Borrowed battle return preserves all actual resources/roster/fitting/disk")
		check(app.autosave_attempts==before_battle.auto and app.manual_attempts==before_battle.manual,"Borrowed battle does not add saves because selection exists")
		if app.overlay.has_meta("weapon_fitting"): await _click(app.overlay.get_meta("weapon_fitting").action_buttons.close)
	_end()

func _run() -> void:
	output=OS.get_environment("HERO_JOURNAL_SCENE_REPORT"); filter=OS.get_environment("HERO_JOURNAL_SCENE_CASE")
	user_root=ProjectSettings.globalize_path("user://")
	if not check(not output.is_empty() and not OS.get_environment("XDG_DATA_HOME").is_empty() and user_root.begins_with(OS.get_environment("XDG_DATA_HOME")) and not output.begins_with(user_root),"Explicit isolated HOME/XDG and external report required"):
		quit(2); return
	check(FileAccess.get_sha256(ORACLE)==ORACLE_SHA,"Retained117 oracle immutable")
	corpus=JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	check(corpus.rows.size()==117 and corpus.reviewed_target_differences.size()==14,"Original117/14 corpus is unchanged")
	root.size=Vector2i(1280,800)
	check(State.SAVE_VERSION==16,"Production schema16 unchanged")
	for id: String in ["unwrapped_main","input_files","stale_owners","position_holds","load_storage","save_exit","physical_cache","session_progress"]:
		if filter.is_empty() or filter==id: await call("_"+id)
	var bindings: Dictionary={}
	for path: String in ["res://scripts/main.gd","res://scripts/game_state.gd","res://scripts/world.gd","res://scripts/game_hud.gd","res://scripts/map_chart.gd","res://scripts/journal_ui.gd","res://scripts/journal_guidance_view.gd","res://scripts/journal_objective_rules.gd","res://scripts/journal_guidance_rules.gd","res://scripts/journal_guidance_session.gd"]:
		var source=load(path); bindings[path]={"source_sha256":source.source_code.sha256_text(),"path":source.resource_path}
	var result={"checks":checks,"failures":failures,"cases":cases,"trace":trace,"source_bindings":bindings,"engine":Engine.get_version_info(),"user_root":user_root,"scope":"Prepared canonical genuine production State; mostly actual Main scene with explicitly scoped MainProbe _save/_autosave/_toast forwarding to super. Separate unwrapped actual Main case. No NoSave/NoPrefs spies. Engine-level synthetic native-control input, not native pixel/earned/browser/package acceptance. Main save-entry counters do not count PauseMenu or store direct State.save_game; full file bytes and identities cover observed read-only windows."}
	var file=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	if is_instance_valid(app): app._stop_audio(); app.queue_free(); await _frame(2)
	print("JOURNAL_SCENE_INDEPENDENT checks=%d failures=%d cases=%d" % [checks,failures.size(),cases.size()])
	quit(0 if failures.is_empty() else 1)
