extends "res://tests/unified_combat_ui_test.gd"
## Native full-main-scene evidence. Old-story fixture only; the new chapter is
## earned through movement, E, visible choices, current PartyUI and real saves.
const Harbor = preload("res://scripts/heting_region.gd")
const STEP := 1.0 / 30.0
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]
var evidence_dir := ""
var manifest_path := ""
var source_identity := ""
var source_hashes: Dictionary = {}
var capture_mode := "stills"
var trace: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var combat_events: Array[Dictionary] = []
var frame_number := 0
var movie_frame := 0
var movie_budget := 0
var movie_segment := ""
var held := ""
var branch := "hold_for_inspection"
var initial_resources: Dictionary = {}
var battle_resources: Dictionary = {}
var branch_results: Dictionary = {}
var previous_scene: String = ""
var victory_path := ""

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): evidence_dir = argument.trim_prefix("--out=")
		if argument.begins_with("--manifest="): manifest_path = argument.trim_prefix("--manifest=")
		if argument.begins_with("--source="): source_identity = argument.trim_prefix("--source=")
		if argument.begins_with("--mode="): capture_mode = argument.trim_prefix("--mode=")
	if evidence_dir.is_empty() or manifest_path.is_empty() or source_identity.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Explicit isolated paths and source identity required"); quit(2); return
	source_hashes = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_verify_source()
	DirAccess.make_dir_recursive_absolute(evidence_dir + "/screenshots")
	DirAccess.make_dir_recursive_absolute(evidence_dir + "/movie-frames")
	fixture = "user://TEST-consignee-%d/hold" % OS.get_process_id(); DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); await process_frame
	app._stop_audio(); app.audio_on = false; app.set_process(false); app.world.set_process(false)
	# The inherited fixture uses normal experience growth and recruitment APIs.
	# This is a prepared completed-harbor/level-six scenario, not a claimed
	# playthrough of earlier chapters or unearned recruitment in this chapter.
	s = _prepared("heting_receipt", 4); s.receipt_stage = 0; s.fixture = fixture
	s.map_id = "heting"; s.position = Vector2(500,365); app.state = s
	app.current_screen = "explore"; app.active_modal = false; app._clear_overlay()
	app._sync_world_state(); app.world.change_map(s.map_id,s.position)
	root.size = Vector2i(1280,800); app._process(0); app._refresh()
	check(s._stage_save_data(s.to_dict(),State.SAVE_VERSION).ok,"Prepared old-chapter state is canonical")
	check(s.consignee_stage == 0 and s.level == 6,"New chapter unstarted; ordinary level-six stats")
	check(app.world.follower_ids() == ["shen","tang","qin"],"All three selected companions are present")
	initial_resources = s.party_resource_snapshot().duplicate(true)
	inputs.append({"kind":"explicit_old_story_fixture","scope":"Prepared completed harbor, level6 from normal gain_xp(900), actual companion invitation APIs; no new-chapter progress; no attack/HP inflation","state":s.to_dict()})
	await _idle(3)
	await _interact("heting_dispatch")
	await _choice("问北仓新撤运单"); await _choice("接下本批核查")
	await _choice("请秦禾并看验放时刻")
	await _choice("收好本批记录")
	await _route([Vector2(630,365),Vector2(700,365)],"north_warehouse_approach")
	await _capture("01-north-warehouse-duhui-party", "Actual walk to original stationary DuHui and the one paired-hamper lot")
	await _interact("consignee_warehouse")
	await _capture("02-warehouse-investigation", "Physical north-warehouse clue; selected Tang alternative available")
	await _choice("请唐栖按卸力法核封"); await _choice("收好本批记录")
	await _route([Vector2(805,365),Vector2(805,620),Vector2(970,620),Vector2(970,765)],"unloaded_foot_pier_to_counterfoil")
	await _interact("heting_lighter"); await _choice("核验南联"); await _choice("亲自核验")
	await _choice("核对三处矛盾"); await _choice("未验先撤，理由倒置"); await _choice("拟作封粮留验")
	await _choice("去北仓阻止提粮")
	check(s.consignee_stage == 2 and s.consignee_observations.size() == 3,"All three new observations and deduction earned via visible UI")
	check(s.party_resource_snapshot() == initial_resources,"Investigation leaves real party resources unchanged")
	await _route([Vector2(970,620),Vector2(805,620),Vector2(805,365)],"return_via_foot_pier")
	movie_budget = 60; movie_segment = "walking_to_north_warehouse"
	await _route([Vector2(700,365)],"walk_to_actual_confrontation")
	await _idle(maxi(0,movie_budget)); movie_budget = 0
	await _interact("consignee_warehouse"); await _choice("保存后阻止强提")
	var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
	check(panel != null and s.battle_active and panel.encounter == "heting_consignee","Visible saved entry starts current two-opponent PartyUI")
	if panel == null: await _finish_evidence(); return
	panel.set_process(false); panel.art.set_process(false)
	panel.art.event_presented.connect(func(event): combat_events.append(event.duplicate(true)))
	battle_resources = s.party_resource_snapshot().duplicate(true)
	await _capture("03-battle-full-guard", "Actual initial HP/Qi, both opponents, all four party and separate guard previews")
	movie_budget = 390; movie_segment = "actual_automatic_consignee_battle"
	var compact_done := false
	for _step in range(7200):
		if not s.battle_active: break
		await _frame("actual_consignee_combat")
		if not compact_done and is_instance_valid(panel) and panel.valid() and not panel.art.is_presenting():
			var snap: Dictionary = s.party_battle_snapshot()
			var visible_opening := false
			for opponent: Dictionary in snap.enemies:
				if opponent.hp > 0 and int(opponent.get("opening_bonus",0)) > 0: visible_opening = true
			if visible_opening:
				var retained_budget := movie_budget; movie_budget = 0
				root.size = Vector2i(1179,737); await _idle(2)
				await _capture("04-battle-compact-opening", "Actual compact native framebuffer, live HP/Qi, independent opening and telegraphs")
				root.size = Vector2i(1280,800); await _idle(2); movie_budget = retained_budget
				compact_done = true
	movie_budget = 0
	check(compact_done,"New opponent opening captured at genuine safe boundary")
	check(not s.battle_active and s.consignee_stage == 3 and s.party_settlement.get("outcome") == "win","Unboosted actual automatic party wins and secures the finite lot")
	check(s.party_settlement.get("reward_xp",-1) == 0 and s.party_settlement.get("coin_change",-1) == 0,"Battle itself awards no experience or coins")
	if failures > 0: await _finish_evidence(); return
	victory_path = fixture + "/secured-checkpoint.json"
	check(s.save_game(victory_path) == OK,"Actual post-victory state retained as isolated branch checkpoint")
	await _choice("查看北仓这一车"); await _choice("押本批两篓封粮"); await _choice("继续押送")
	await _deliver_hold()
	await _restore_branch("return_to_owner")
	await _interact("consignee_warehouse"); await _choice("更改本批草案"); await _choice("拟作撤运还粮")
	await _choice("押本批两篓封粮"); await _choice("继续押送")
	await _deliver_return()
	await _finish_evidence()

func _verify_source() -> void:
	for path: String in source_hashes:
		check(FileAccess.get_sha256("res://" + path) == source_hashes[path],"Exact source bytes: " + path)

func _hold(action: String) -> void:
	for item: String in MOVE_ACTIONS: Input.action_release(item)
	held = action
	if not held.is_empty(): Input.action_press(held)

func _frame(label: String) -> void:
	var prior: Vector2 = app.world.player_pos
	var followers: Dictionary = {}
	for id: String in app.world.follower_ids(): followers[id] = app.world.follower_view(id).position
	app._process(0)
	if app.current_screen == "party_battle":
		var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
		if panel != null and is_instance_valid(panel):
			panel.set_process(false); panel.art.set_process(false)
			panel._process(STEP)
			if is_instance_valid(panel) and panel.art.is_presenting(): panel.art._process(STEP)
	else: app.world._process(STEP)
	app._process(STEP); frame_number += 1
	check(Harbor.walkable(app.world.player_pos,s.heting_bridge,app.world.heting_cart_loaded()),label+": hero legal terrain")
	if app.current_screen == "explore" and not app.active_modal:
		check(Harbor.can_step(prior,app.world.player_pos,s.heting_bridge,app.world.heting_cart_loaded()),label+": accepted collision-safe step")
	for id: String in app.world.follower_ids():
		var actor: Dictionary = app.world.follower_view(id)
		check(app.world._follower_can_walk(actor.position),label+": follower on legal terrain "+id)
		if followers.has(id): check(app.world._follower_can_step(followers[id],actor.position),label+": swept follower movement "+id)
	if frame_number % 15 == 0 or previous_scene != app.current_screen: _record(label)
	previous_scene = app.current_screen
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if movie_budget > 0 and capture_mode != "validate":
			var pixels: Image = root.get_texture().get_image()
			check(pixels.save_png(evidence_dir + "/movie-frames/frame-%05d.png" % movie_frame) == OK,"Native silent clip frame write")
	if movie_budget > 0:
		movie_budget -= 1; movie_frame += 1

func _idle(frames: int) -> void:
	_hold("")
	for _i in range(frames): await _frame("idle")

func _route(points: Array, label: String) -> void:
	for target: Vector2 in points:
		for _i in range(400):
			var delta: Vector2 = target - app.world.player_pos
			if absf(delta.x) <= 3.2 and absf(delta.y) <= 3.2: break
			_hold(("move_right" if delta.x > 0 else "move_left") if absf(delta.x) > 3.2 else ("move_down" if delta.y > 0 else "move_up"))
			await _frame(label)
		_hold("")
		check(app.world.player_pos.distance_to(target) < 5,"Actual input reaches waypoint: "+str(target))
		if failures > 0: return
	await _idle(2)

func _interact(site: String) -> void:
	await _idle(2)
	check(app.world.nearby_id == site,"Actual nearby E target: "+site+" (observed "+app.world.nearby_id+")")
	inputs.append({"kind":"actual_E_key","site":site,"position":[app.world.player_pos.x,app.world.player_pos.y],"branch":branch})
	root.gui_release_focus(); await _key(KEY_E); await _idle(2)
	check(app.active_modal,"E opens actual scene dialogue: "+site)

func _choice(label: String) -> void:
	await _idle(2)
	var control = _button(app.overlay,label)
	check(control != null,"Visible choice exists: "+label)
	if control == null: return
	inputs.append({"kind":"actual_mouse_press_release","label":label,"branch":branch,"rect":_rect(control.get_global_rect())})
	await _click(control)
	# Block autonomous combat stepping before the next controlled frame.
	var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
	if panel != null and is_instance_valid(panel): panel.set_process(false); panel.art.set_process(false)
	await _idle(2)

func _deliver_hold() -> void:
	await _route([Vector2(1530,365),Vector2(1530,730),Vector2(1120,730)],"loaded_legal_east_pontoon")
	check(s.consignee_cargo_location == "cart" and s.heting_cargo.is_empty(),"Only finite new lot is on the moving cart")
	await _capture("05-new-cart-east-pontoon", "One paired-hamper sprite on real cargo-legal east pontoon; all three companions follow")
	await _route([Vector2(1300,730),Vector2(1390,730),Vector2(1390,610)],"loaded_to_public_scale")
	await _interact("heting_scale"); await _choice("交接本批封粮")
	await _capture("06-hold-explicit-handover", "Real final confirmation before any ending/reward is committed")
	await _choice("确认交下本批"); await _choice("收好交接记录")
	await _route([Vector2(1390,790)],"hold_durable_world_aftermath")
	await _reload_completed()
	await _capture("07-hold-reloaded-aftermath", "Reloaded canonical save; exactly one paired-hamper lot remains at the scale")
	branch_results[branch] = _branch_snapshot()

func _deliver_return() -> void:
	await _route([Vector2(1530,365),Vector2(1530,730),Vector2(820,730),Vector2(665,730),Vector2(665,630)],"loaded_legal_east_pontoon_to_grain_boat")
	await _interact("heting_cargo"); await _choice("交接本批封粮")
	await _capture("08-return-explicit-handover", "Second isolated branch: explicit grain-owner confirmation before reward")
	await _choice("确认交下本批"); await _choice("收好交接记录")
	await _route([Vector2(715,675)],"return_durable_world_aftermath")
	await _reload_completed()
	await _capture("09-return-reloaded-aftermath", "Reloaded alternate canonical save; returned grain is opened/distributed, original lot not duplicated")
	branch_results[branch] = _branch_snapshot()

func _restore_branch(plan: String) -> void:
	_hold(""); branch = plan
	app.modal_autosave_on_close = false; app._close_modal()
	fixture = "user://TEST-consignee-%d/return" % OS.get_process_id(); DirAccess.make_dir_recursive_absolute(fixture)
	var restored = State.new(); restored.fixture = fixture
	check(restored.load_game(victory_path) == OK,"Restore second isolated branch from the actual post-victory checkpoint")
	s = restored; app.state = s
	app._sync_world_state(); app.world.change_map(s.map_id,s.position); app._process(0); app._refresh()
	check(s.consignee_stage == 3 and not s.battle_active,"Branch fork retains genuine secured lot, no fake victory")
	inputs.append({"kind":"explicit_isolated_branch_restore","path":ProjectSettings.globalize_path(victory_path),"sha256":FileAccess.get_sha256(victory_path),"branch":branch,"state":s.to_dict()})
	await _idle(3)

func _reload_completed() -> void:
	check(s.consignee_stage == 5 and s.consignee_ending == branch,"Ending requires explicit visible handover")
	check(s.save_game() == OK,"Save completed isolated branch")
	var prior: Dictionary = s.to_dict().duplicate(true)
	check(s.load_game() == OK and s.to_dict() == prior,"Canonical completed branch reload retains exact state")
	app._sync_world_state(); app.world.change_map(s.map_id,s.position); app._process(0); app._refresh(); await _idle(3)

func _branch_snapshot() -> Dictionary:
	return {"state":s.to_dict(),"resources":s.party_resource_snapshot(),"save_path":ProjectSettings.globalize_path(fixture+"/save.json"),"save_sha256":FileAccess.get_sha256(fixture+"/save.json"),"visual":Harbor.consignee_visual_state(true,s.consignee_stage,s.consignee_cargo_location,s.consignee_ending)}

func _rect(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _record(label: String) -> void:
	var actors: Array = [{"id":"hero","position":[app.world.player_pos.x,app.world.player_pos.y]}]
	for id: String in app.world.follower_ids():
		var actor: Dictionary = app.world.follower_view(id)
		actors.append({"id":id,"position":[actor.position.x,actor.position.y],"moving":actor.moving})
	trace.append({"frame":frame_number,"label":label,"input":held,"screen":app.current_screen,"branch":branch,"stage":s.consignee_stage,"cargo":s.consignee_cargo_location,"actors":actors,"battle":s.party_battle_snapshot() if s.battle_active else {},"clip_segment":movie_segment if movie_budget>0 else ""})

func _capture(name: String, note: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var geometry: Dictionary = {}
	if app.current_screen == "party_battle":
		var panel = app.overlay.get_meta("party_battle")
		for id: String in panel.unit_plates:
			geometry[id] = {"plate":_rect(panel.unit_plates[id].get_global_rect()),"status":panel.unit_plates[id].status_caption(),"intent":panel.unit_plates[id].intent,"facts":panel.unit_plates[id].facts}
	_record("capture:"+name)
	var capture: Dictionary = {"name":name,"note":note,"frame":frame_number,"native_rendered":DisplayServer.get_name()!="headless","state":trace.back(),"geometry":geometry,"resources":s.party_resource_snapshot(),"visual":Harbor.consignee_visual_state(true,s.consignee_stage,s.consignee_cargo_location,s.consignee_ending)}
	if DisplayServer.get_name() != "headless":
		var pixels: Image = root.get_texture().get_image()
		check(pixels.save_png(evidence_dir+"/screenshots/"+name+".png") == OK,"Actual native framebuffer written: "+name)
		capture.width=pixels.get_width();capture.height=pixels.get_height()
	captures.append(capture); print("CAPTURE ",name)

func _finish_evidence() -> void:
	_hold(""); _verify_source()
	var result: Dictionary = {"scope":"Prepared canonical completed-harbor level6 fixture with actual invitation APIs and normal stats. New chapter runs via held movement, E, real visible choices and current full-main-scene PartyUI. Actual earned post-victory save forks two isolated handover branches. Native silent fixed-step framebuffer evidence; no browser, manual play, audio, realtime-performance or release claim.","source_identity":source_identity,"source_binding":"Exact runtime/tool SHA256 manifest; clean final commit binding pending separately","mode":capture_mode,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"fixed_step_seconds":STEP,"frames":frame_number,"clip_frames":movie_frame,"checks":checks,"failures":failures,"initial_resources":initial_resources,"battle_entry_resources":battle_resources,"captures":captures,"inputs":inputs,"combat_events":combat_events,"branch_results":branch_results,"source_sha256":source_hashes,"trace":trace}
	var output = FileAccess.open(evidence_dir+"/consignee-evidence.json",FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(result,"\t")); output.close()
	print("%s: consignee playable native evidence; %d checks; %d captures; %d clip frames" % ["PASS" if failures==0 else "FAIL",checks,captures.size(),movie_frame])
	app._stop_audio();app.queue_free();await process_frame;quit(0 if failures==0 else 1)
