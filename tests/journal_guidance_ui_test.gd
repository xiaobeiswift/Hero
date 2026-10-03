extends SceneTree
## Prepared current-scene integration, native Control input dispatch and genuine
## production HeroState/file preservation. Not earned play, rendered contrast,
## browser, Windows, package or complete regression evidence. Main and World
## processing stay enabled. The first divergent-state open is explicitly a
## synchronous handler-boundary probe; later J entry uses actual queued keys.
const Main = preload("res://scripts/main.gd")
const State = preload("res://scripts/game_state.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const Fitting = preload("res://scripts/weapon_fitting_ui.gd")
const Lightness = preload("res://scripts/lightness_rules.gd")
const Harbor = preload("res://scripts/heting_region.gd")
class ProbeMain extends Main:
	var autosave_calls: int = 0
	var manual_calls: int = 0
	var reset_notices: Array[String] = []
	func _autosave() -> void:
		autosave_calls += 1
		super._autosave()
	func _save() -> void:
		manual_calls += 1
		super._save()
	func _toast(message: String, save_notice: bool = false, duration: float = 7.0) -> void:
		if message.contains("已恢复自动指引"):reset_notices.append(message)
		super._toast(message,save_notice,duration)
var app
var checks: int = 0
var failures: Array[String] = []
var output: String = ""
var case_id: String = "setup"
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(case_id+": "+label);push_error(case_id+": "+label)
func frames(count: int = 2) -> void:
	for i: int in count:await process_frame
func tap(code: int, echo: bool = false) -> void:
	for down: bool in [true,false]:
		var event = InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;event.echo=echo and down
		Input.parse_input_event(event);Input.flush_buffered_events();await frames(1)
	await frames(1)
func click(control: Control) -> void:
	check(is_instance_valid(control),"Real mouse control exists")
	if not is_instance_valid(control):return
	var point: Vector2 = root.get_final_transform()*control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);Input.flush_buffered_events();await frames(1)
	for down: bool in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await frames(1)
	await frames()
func folio():return app.overlay.get_meta("journal_ui",null)
func callback(button: Button) -> Callable:
	for item: Dictionary in button.pressed.get_connections():
		if item.callable.is_valid():return item.callable
	return Callable()
func disk(path: String="user://") -> Dictionary:
	var result: Dictionary = {}
	var directory = DirAccess.open(path)
	if directory == null:return result
	for file: String in directory.get_files():result[path.path_join(file)] = FileAccess.get_sha256(path.path_join(file))
	for folder: String in directory.get_directories():result.merge(disk(path.path_join(folder)))
	return result
func real_state() -> Dictionary:
	return {"canonical":app.state.to_dict().duplicate(true),"battle_active":app.state.battle_active,"battle_kind":app.state.battle_kind,"party_session":app.state.party_session,"party_settlement":app.state.party_settlement.duplicate(true),"pending":app.state._party_pending_token,"party_epoch":app.state.party_battle_epoch,"encounter":app.state._party_encounter,"companion_counter":app.state._companion_attack_count}
func invariant(before: Dictionary, files: Dictionary, anchor: Vector2, saves: int, label: String) -> void:
	if real_state()!=before:
		for key: String in before.canonical:
			if before.canonical[key] != real_state().canonical[key]:print("STATE_DIFF ",key," before=",before.canonical[key]," after=",real_state().canonical[key])
	check(real_state()==before,label+" preserves real state and transient party gates")
	check(disk()==files,label+" preserves every real userdata file byte hash")
	check(app.world.player_pos==anchor,label+" preserves actual World anchor")
	check(app.autosave_calls+app.manual_calls==saves,label+" attempts no Main save")
func from_oracle(label: String) -> void:
	app.current_screen="explore";app.active_modal=false;app._clear_overlay()
	var corpus = JSON.parse_string(FileAccess.get_file_as_string("res://tests/journal_guidance_frozen_oracle.json"))
	var found: Dictionary = {}
	for row: Dictionary in corpus.rows:
		if row.label==label:found=row;break
	check(not found.is_empty(),"Pinned prepared oracle row exists: "+label)
	if found.is_empty():return
	var bytes: PackedByteArray = JSON.stringify({"version":16,"player":found.state}).to_utf8_buffer()
	var inspected: Dictionary = app.state.inspect_save_bytes(bytes)
	check(inspected.ok,"Production reader validates prepared state")
	if not inspected.ok:return
	app.state=inspected.state
	app._apply_loaded_state("测试准备")
	app._refresh()
func agree(target: String) -> void:
	var value: Dictionary=app.journal_guidance_snapshot
	check(value.next_target_id==target and app.world._quest_target_id()==target,"Host and World agree with independently expected local target")
	check(app.hud.journal_guidance_snapshot==value,"HUD receives same detached semantic snapshot")
	if is_instance_valid(folio()):check(folio().guidance_snapshot.next_target_id==target,"J current strip receives effective target")
func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	app=ProbeMain.new();root.add_child(app);await frames();app._stop_audio();app.audio_on=false
	case_id="synchronous_divergent_entry_then_real_input"
	from_oracle("bounded_qin_tang_fix_1_1")
	check(app.state.get_script()==State,"Production State is genuine, not NoSave substitute")
	app.state.position=Vector2(100,100)
	check(app.state.save_game()==OK,"Genuine writer creates divergent stored-position baseline")
	var before: Dictionary=real_state();var files: Dictionary=disk();var anchor: Vector2=app.world.player_pos;var saves: int=app.autosave_calls+app.manual_calls
	# Capture the synchronous opening boundary before another exploration tick;
	# subsequent controls use real input, and held divergence is tested with J keys below.
	app._show_journal();await frames()
	check(is_instance_valid(folio()) and app.active_modal and app.modal_actions.is_empty(),"J has dedicated real owner and no generic modal actions")
	if not is_instance_valid(folio()):finish();return
	check(folio().valid(),"Journal owner validity includes live session/state")
	agree("mist_rain_gauge")
	var tracked: String=app.journal_session.tracked_arc_id
	await tap(KEY_ENTER)
	check(app.active_modal and app.journal_session.tracked_arc_id==tracked,"Enter on initial row only browses, never generic close/track")
	await click(folio().row_buttons.tang_notes)
	check(folio().browse_arc_id=="tang_notes" and app.journal_session.tracked_arc_id.is_empty(),"Pointer browsing Tang leaves Qin automatic guidance")
	var old_track: Callable=callback(folio().action_buttons.track)
	folio().browse("qin_rope");folio().browse("tang_notes")
	old_track.call()
	await frames() # Allow the explicitly rebuilt rowA-B-A fixture to finish native layout.
	check(app.journal_session.tracked_arc_id.is_empty(),"Stale rowA-B-A Track token cannot change selection")
	await click(folio().action_buttons.track)
	check(app.journal_session.tracked_arc_id=="tang_notes" and app.active_modal,"Explicit real Track changes only session and keeps J open")
	agree("return_frostbridge")
	var epoch: Dictionary=app.journal_session.token(app.state)
	folio().track_selected()
	check(app.journal_session.token(app.state)==epoch,"Repeated Track is idempotent")
	for code: int in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_E,KEY_M,KEY_F5,KEY_F9,KEY_F6,KEY_F10,KEY_B,KEY_I,KEY_K,KEY_EQUAL,KEY_MINUS]:await tap(code)
	check(is_instance_valid(folio()) and app.journal_session.tracked_arc_id=="tang_notes","Owned numeric/global keys cannot replace J or change tracking")
	await click(folio().action_buttons.history)
	check(folio().body.text.contains("尺上旧痕") and folio().body.text.contains("尺绳"),"All earned history is available in actual history view")
	var selection: String=folio().browse_arc_id
	folio().body.grab_focus();await tap(KEY_END);await tap(KEY_UP);await tap(KEY_HOME)
	check(folio().browse_arc_id==selection and app.journal_session.tracked_arc_id=="tang_notes","History scrolling never selects/tracks another row")
	await tap(KEY_ESCAPE)
	check(is_instance_valid(folio()),"History Escape returns to same read-only J owner")
	await click(folio().action_buttons.auto)
	check(app.journal_session.tracked_arc_id.is_empty(),"Explicit Restore auto restores exact policy")
	agree("mist_rain_gauge")
	for i: int in 25:
		await tap(KEY_TAB)
		var focus: Control=root.gui_get_focus_owner()
		check(focus!=null and folio().is_ancestor_of(focus),"Tab remains trapped inside actual J controls")
	invariant(before,files,anchor,saves,"J browse/Track/Auto/history/keys")
	var stale_close: Callable=callback(folio().action_buttons.close)
	await tap(KEY_ESCAPE)
	check(not app.active_modal,"J Escape closes once")
	await frames(5)
	invariant(before,files,anchor,saves,"J dismissal and idle ticks")
	await tap(KEY_M)
	var chart=app.overlay.find_child("RegionChart",true,false)
	check(chart!=null and chart.current_target=="mist_rain_gauge" and chart.journal_guidance_snapshot.next_target_id=="mist_rain_gauge","M receives same current target snapshot")
	check(chart.markers==app.world.interactables,"M marker copy has actual synchronized values")
	var first: String=String(chart.markers.keys()[0]);chart.markers[first].name="local detached test"
	check(app.world.interactables[first].name!="local detached test","M markers are detached from World")
	if stale_close.is_valid():stale_close.call()
	check(app.active_modal and app.overlay.get_meta("journal_map",false),"Old J Close cannot dismiss newer M")
	await tap(KEY_1);await frames(5)
	invariant(before,files,anchor,saves,"M browsing and numbered close")
	check(app.is_processing() and app.world.is_processing(),"Main and World processing remained enabled during browsing proofs")
	case_id="cache_and_physical_validation"
	var metrics: Dictionary=app.journal_view.metrics
	for i: int in 100:app._process(0)
	check(app.journal_view.metrics.full_resolves==metrics.full_resolves,"100 idle frames do not rerun resolver")
	app.world.player_pos+=Vector2(1,0);app._process(0)
	check(app._journal_position_hold.is_empty() and app.state.position==app.world.player_pos,"Real position change after dismissal releases only completed browse hold")
	check(app.journal_view.metrics.full_resolves==metrics.full_resolves,"Ordinary movement/stored-position sync does not resolve guidance again")
	var snapshot: Dictionary=app.journal_guidance_snapshot.duplicate(true)
	var target: String=snapshot.next_target_id
	var marker: Dictionary=app.world.interactables[target].duplicate(true)
	app.world.interactables[target].pos=Vector2(INF,0)
	check(app.world._quest_target_id().is_empty(),"World suppresses a stale/nonfinite target immediately")
	app._sync_journal_guidance()
	check(app.journal_guidance_snapshot.next_target_id.is_empty(),"Model returns unavailable after marker invalidation")
	app.world.interactables[target]=marker;app._sync_journal_guidance()
	check(app.world._quest_target_id()==target,"Same model recovers when legal marker returns")
	app.journal_catalog();metrics=app.journal_view.metrics
	app.state.resources.timber+=1;app.journal_catalog()
	check(app.journal_view.metrics.catalog_builds==metrics.catalog_builds+1,"Nested in-place material change invalidates detached catalog signature")
	case_id="load_transfer_and_completion"
	await tap(KEY_J);folio().browse("tang_notes");folio().track_selected();await tap(KEY_ESCAPE)
	check(app.journal_session.tracked_arc_id=="tang_notes","Manual selection retained through close")
	var transfer=Transfer.new();var active: Dictionary=real_state();var exported: Dictionary=transfer.export_slot(0)
	check(exported.ok and app.journal_session.tracked_arc_id=="tang_notes" and real_state()==active,"Storage-only export retains active journey/selection")
	var preview: Dictionary=transfer.preview_import(exported.bytes,3)
	check(preview.ok,"Existing import core previews empty manual slot")
	if preview.ok:
		var imported: Dictionary=transfer.commit_import(preview.token)
		check(imported.ok and real_state()==active and app.journal_session.tracked_arc_id=="tang_notes","Successful storage-only import never applies/reset active journey")
	check(not app.web_save_transfer_enabled,"Web transfer default remains off")
	var original: PackedByteArray=FileAccess.get_file_as_bytes(State.SAVE_PATH)
	var file=FileAccess.open(State.SAVE_PATH,FileAccess.WRITE);file.store_string("broken fixture");file.close()
	app._load()
	check(real_state()==active and app.journal_session.tracked_arc_id=="tang_notes","Actual failed quick load preserves same journey and tracking")
	file=FileAccess.open(State.SAVE_PATH,FileAccess.WRITE);file.store_buffer(original);file.close()
	var identity: int=app.state.get_instance_id();app._load()
	check(app.state.get_instance_id()==identity and app.journal_session.tracked_arc_id.is_empty(),"Successful same-State quick load resets session")
	from_oracle("bounded_qin_tang_fix_1_3")
	await tap(KEY_J);folio().browse("qin_rope");folio().track_selected()
	var stale_token: Dictionary=app.journal_session.token(app.state);var notice_count: int=app.reset_notices.size()
	check(app.state.recruit_qin(),"Actual canonical Qin invitation completes selected arc")
	app._refresh();await frames()
	check(app.journal_session.tracked_arc_id.is_empty() and app.reset_notices.size()==notice_count+1,"Actual completion clears selection with one notice")
	for i: int in 100:app._process(0)
	check(app.reset_notices.size()==notice_count+1 and not app.journal_session.track(app.state,"qin_rope",stale_token),"Idle completion cannot repeat notice or resurrect completed tracking")
	await tap(KEY_ESCAPE)
	case_id="unrelated_browsed_row_completion"
	from_oracle("bounded_qin_tang_fix_1_1")
	check(app.state.learn_lightness(),"Prepared genuine State learns an eligible lesson through its canonical API")
	app.state.map_id="qingwei";app.state.position=Lightness.LANDING
	app._sync_world_state();app.world.change_map("qingwei",Lightness.LANDING);app._refresh()
	app._show_journal();await frames()
	folio().browse("tang_notes");folio().track_selected();folio().browse("lightness_islet");await frames()
	check(not folio().action_buttons.track.disabled and app.journal_session.tracked_arc_id=="tang_notes","Untracked browsed islet arc is active while Tang remains tracked")
	var unchanged_target: String=app.journal_guidance_snapshot.next_target_id
	var stale_completed_track: Callable=callback(folio().action_buttons.track)
	var count_before: int=app.autosave_calls+app.manual_calls
	var files_before_completion: Dictionary=disk()
	# A separately declared canonical external completion, not a Journal action.
	check(app.state.discover_reed_islet(),"Canonical islet discovery completes only the untracked browsed arc")
	var completed_state: Dictionary=real_state()
	app._refresh();await frames()
	check(app.journal_guidance_snapshot.next_target_id==unchanged_target and app.journal_session.tracked_arc_id=="tang_notes","Unrelated completion does not rerank or clear the tracked arc")
	var completed_track_disabled: bool=folio().action_buttons.track.disabled
	await click(folio().action_buttons.earned)
	check(completed_track_disabled and folio().page=="history" and folio().body.text.contains("苇心残碑已拓录"),"Fact-only publication disables Track immediately; real earned-history disclosure shows the exact completed lore")
	await tap(KEY_ESCAPE)
	if stale_completed_track.is_valid():stale_completed_track.call()
	check(real_state()==completed_state and disk()==files_before_completion and app.autosave_calls+app.manual_calls==count_before,"Read-only completion refresh/stale Track leaves canonical completion and every file unchanged")
	var completed_metrics: Dictionary=app.journal_view.metrics
	for i: int in 100:app._process(0)
	check(app.journal_view.metrics.catalog_builds==completed_metrics.catalog_builds and app.journal_view.metrics.full_resolves==completed_metrics.full_resolves,"Fact publication does not introduce per-frame catalog or route reconstruction")
	await tap(KEY_ESCAPE)
	case_id="fitting_owner_and_hold"
	app._new_game();app.state.quest_stage=6;app.state.ending="守望";app.state.choose_sect("听潮阁")
	app.state.position=Vector2(100,100);app.world.change_map("qingwei",Vector2(721,757));app._refresh()
	var fitting=Fitting.open(app)
	check(fitting!=null,"Existing fitting opens with genuine State")
	var generation: int=app.modal_generation;app._show_journal();app._show_map()
	check(app.overlay.get_meta("weapon_fitting",null)==fitting and app.modal_generation==generation,"J/M cannot replace fitting owner")
	fitting.close();var held: Dictionary=app._fitting_position_hold.duplicate()
	await tap(KEY_J);await tap(KEY_ESCAPE);await tap(KEY_M);await tap(KEY_ESCAPE)
	check(not held.is_empty() and app._fitting_position_hold==held and app.state.position==Vector2(100,100),"J/M never erase fitting's independent divergence hold")
	app._save()
	check(app._journal_position_hold.is_empty() and app._fitting_position_hold.is_empty() and app.state.position==app.world.player_pos,"Explicit existing save releases both holds and writes real location")
	case_id="loaded_cart_shared_route"
	from_oracle("harbor_overlap_1_4")
	app._show_map();await frames();chart=app.overlay.find_child("RegionChart",true,false)
	check(chart!=null and not chart.cart_route.is_empty() and chart.cart_route[0]==app.world.player_pos,"M route starts at actual loaded-cart position")
	if chart!=null:
		check(chart.cart_route==app.journal_guidance_snapshot.cart_route,"M consumes exact supplied cart route")
		for i: int in range(1,chart.cart_route.size()):check(Harbor.can_step(chart.cart_route[i-1],chart.cart_route[i],app.state.heting_bridge,true),"Every supplied cart route segment is physically legal")
	await tap(KEY_ESCAPE)
	metrics=app.journal_view.metrics
	var route: PackedVector2Array=app.journal_guidance_snapshot.cart_route
	if route.size()>1:
		app.world.player_pos=route[0].move_toward(route[1],1.0);app._sync_journal_guidance()
		check(app.journal_view.metrics.full_resolves==metrics.full_resolves and app.journal_view.metrics.route_reanchors==metrics.route_reanchors+1,"Loaded movement reanchors legal cached path without full solve")
		check(app.journal_guidance_snapshot.cart_route[0]==app.world.player_pos,"Reanchored path has exact current start")
	case_id="islet_physical_projection"
	from_oracle("bounded_qin_tang_fix_1_1")
	app.state.map_id="qingwei";app._sync_world_state();app.world.change_map("qingwei",Lightness.ISLET_CENTER);app._sync_journal_guidance(true)
	check(app.world._quest_target_id()=="reed_return","Off-islet goal resolves actual return crossing even without learned lightness")
	var manual=app.journal_session.token(app.state)
	check(app.journal_session.track(app.state,"tang_notes",manual),"Earned Tang stays manually valid away from its map")
	app._sync_journal_guidance(true)
	check(app.journal_guidance_snapshot.next_target_id=="reed_return" and app.journal_guidance_snapshot.destination_site=="sluice_cache","Manual final goal and physical first crossing remain separate")
	app._new_game()
	check(app.journal_session.tracked_arc_id.is_empty(),"Successful new journey resets tracking even on same State")
	finish()
func finish() -> void:
	if not output.is_empty():
		var file=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"scope":"Prepared source-scene integration using genuine production HeroState and real userdata files. Main observer delegates production saves. Main/World processing remain enabled. The first divergent-position open is a labeled synchronous handler boundary; later J entry and controls use flushed input events. Native Control dispatch is headless, not rendered/native contrast/earned/browser/Windows/package proof.","metrics":app.journal_view.metrics},"\t"));file.close()
	app._stop_audio();app.queue_free();await process_frame
	print("%s journal_guidance_ui: %d checks, %d failures"%["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
