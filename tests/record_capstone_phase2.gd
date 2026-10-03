extends "res://tests/unified_combat_ui_test.gd"
## Native capstone evidence. Prepared canonical old history and legal per-site
## placement; the new chapter uses actual E/mouse UI, current PartyUI, real
## accepted combat tokens and isolated saves. This is not earned travel/manual
## play/browser/performance evidence. All PNG bytes are direct Godot frames.
const Rules = preload("res://scripts/volume_one_capstone_rules.gd")
const Story = preload("res://scripts/volume_one_capstone_story.gd")
const STEP = 1.0 / 30.0
var out_dir = ""
var manifest_path = ""
var source_identity = ""
var mode = "stills"
var hashes: Dictionary = {}
var captures: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var combat_events: Array[Dictionary] = []
var transactions: Array[Dictionary] = []
var before_resources: Dictionary = {}
var movie_frame = 0
var battle_frame = 0
var found = {"idle":false,"heavy":false,"contact":false,"recovery":false,"down":false}
var evidence_gate = ""
var capture_clip = true

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--manifest="): manifest_path = arg.trim_prefix("--manifest=")
		if arg.begins_with("--source="): source_identity = arg.trim_prefix("--source=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg == "--no-clip": capture_clip = false
	if out_dir.is_empty() or manifest_path.is_empty() or source_identity.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	hashes = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_verify_source("before")
	DirAccess.make_dir_recursive_absolute(out_dir + "/screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir + "/movie-frames")
	fixture = "user://capstone-native-%d" % OS.get_process_id(); DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); await process_frame
	app._stop_audio(); app.audio_on = false; app.set_process(false); app.world.set_process(false)
	root.size = Vector2i(1280,800)
	s = _prepared("capstone_authorizer",4); s.capstone_stage = 0; s.fixture = fixture; app.state = s
	app.current_screen = "explore"; app.active_modal = false; app._clear_overlay()
	app.view_preferences.full_resolution = true; app.view_preferences.zoom_index = 0; app._apply_view_zoom()
	check(s._stage_save_data(s.to_dict(),State.SAVE_VERSION).ok,"Old-history initial fixture is canonical")
	before_resources = s.party_resource_snapshot().duplicate(true)
	inputs.append({"kind":"explicit_prepared_old_history","state":s.to_dict(),"note":"Completed prior stories, level6 via normal growth, selected four-person roster. No capstone progress, awards or resource edits."})
	await _place("heting_dispatch"); await _interact("heting_dispatch"); await _action("begin")
	check(s.capstone_stage == 1,"Actual begin UI advances only to1")
	await _place("chapter_host")
	if mode == "interactive":
		evidence_gate = "wen_native_E"; _progress()
		while not app.active_modal: await process_frame
		inputs.append({"kind":"external_native_CUA_E","site":"chapter_host","page":app.capstone_story._page})
	else: await _interact("chapter_host")
	if mode == "interactive":
		evidence_gate = "wen_native_original_choice"; _progress()
		while app.capstone_story._page != "B1": await process_frame
		inputs.append({"kind":"external_native_CUA_mouse","page":"B1"})
	else: await _action("B1")
	await _capture("01-wen-original-letter","Actual original letter and retained draft page; no reveal committed")
	await _action("B2"); await _action("B4")
	await _capture("02-wen-return-letter","Explicit author explanation and return choice; no implicit healing")
	await _action("reveal")
	check(s.capstone_stage == 2 and s.party_resource_snapshot() == before_resources,"Letter reveal advances without healing or award")
	await _place("chapter_clerk"); await _interact("chapter_clerk"); await _action("C2")
	await _capture("03-clerk-issued-register","Issued-register evidence separates prior two-load and current paired-hamper authorization")
	await _action("C3"); await _action("method:solo:C6"); await _action("evidence:authorized_issued_chain")
	check(s.capstone_stage == 3,"Correct concrete issued chain accepted by actual choice")
	await _place("chapter_archive")
	await _capture("04-archive-liang-72px","Actual archive world occupant: Liang replaces Han at stage3, with full party")
	await _interact("chapter_archive"); await _action("D2"); await _action("start_real_capstone_battle")
	var panel = _panel()
	check(panel != null and s.battle_active,"Actual prepared-dialogue save starts capstone PartyUI")
	if panel == null: await _finish_report(); return
	panel.set_process(false); panel.art.set_process(false)
	panel.art.event_presented.connect(func(event): combat_events.append(event.duplicate(true)))
	check(panel.art.display_snapshot.actors.size() == 4 and panel.art.display_snapshot.enemies.size() == 1 and panel.art.display_snapshot.enemies[0].id == "liang_zhen","Actual battle has four actors and one original Liang")
	for _index in range(9000):
		if not s.battle_active or not is_instance_valid(panel): break
		var previous_token: int = int(panel.pending.get("token",-1))
		panel._process(STEP)
		if not is_instance_valid(panel): break
		if not panel.pending.is_empty() and int(panel.pending.token) != previous_token:
			transactions.append(panel.pending.duplicate(true))
		if panel.art.is_presenting(): panel.art._process(STEP)
		if not is_instance_valid(panel): break
		panel.art._clock = .375; panel.refresh(); app._process(0)
		battle_frame += 1
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if capture_clip and movie_frame < 450:
			if DisplayServer.get_name() != "headless": check(root.get_texture().get_image().save_png(out_dir+"/movie-frames/frame-%05d.png"%movie_frame)==OK,"Native fixed-step movie frame")
			movie_frame += 1
		if not is_instance_valid(panel): break
		if not found.idle and not panel.art.is_presenting() and int(panel.art.display_snapshot.round)>=2 and panel.art.actor_visual_pose("liang_zhen")=="idle":
			await _capture_pair("idle","Real safe boundary in round2; standing idle Liang, ordinary unchanged620HP entry cap")
			found.idle=true
		if panel.art.is_presenting():
			var snap: Dictionary = panel.art.display_snapshot
			var phase: String = panel.art.presentation_phase
			var unit = _enemy(snap)
			if panel.art.acting_unit_id == "liang_zhen" and int(snap.round) == 2:
				if not found.heavy and phase == "windup" and panel.art.action_time >= .17:
					await _capture_pair("heavy","Accepted Liang round2 heavy action, real windup before contact"); found.heavy = true
				if not found.contact and phase == "contact":
					await _capture_pair("contact","Accepted Liang heavy action at real contact, displayed damage/status events"); found.contact = true
			if not found.recovery and panel.art.acting_unit_id == "liang_zhen" and int(snap.round) == 3 and phase == "return" and panel.art.action_time >= .64:
				await _capture_pair("recovery","Accepted round3 recovery action at return, genuine opening phase"); found.recovery = true
			if not found.down and int(unit.get("hp",1)) == 0 and panel.art.actor_visual_pose("liang_zhen") == "kneel":
				await _capture_pair("down","Real lethal transaction displayed; Liang down before one-time token settlement"); found.down = true
	for key: String in found: check(found[key],"Captured genuine phase "+key)
	check(not capture_clip or movie_frame==450,"Silent clip has450 genuine fixed-step30fps battle frames")
	check(not s.battle_active and s.capstone_stage == 4 and s.party_settlement.get("outcome") == "win","Normal actual combat wins and earns unissued ledger")
	check(s.party_settlement.get("reward_xp",-1)==0 and s.party_settlement.get("coin_change",-1)==0,"Combat has no capstone award")
	if s.capstone_stage != 4: await _finish_report(); return
	await _place("capstone_order_desk")
	await _capture("15-desk-four-pending","Finite four-sheet desk before classification or disposition")
	check(Rules.order_rows(s).size()==4,"Exactly four real model-derived order rows")
	await _interact("capstone_order_desk"); await _action("method:solo:E6"); await _action("classify:CORRECT_PARTITION")
	check(s.capstone_stage==5 and s.capstone_draft.is_empty(),"Real classification leaves no automatic draft")
	var classified = fixture+"/classified.json"
	check(s.save_game(classified)==OK,"Isolated fork checkpoint saved after actual earned battle and classification")
	await _disposition("pause_batch","16-desk-pause-batch")
	await _place("elder"); await _interact("elder"); await _action("homecoming")
	check(s.capstone_stage==7,"Explicit homecoming completes volume")
	await _capture("18-qingwei-homecoming","Actual homecoming after four-order disposition; exactly-once normal capstone reward")
	var finished = s.to_dict().duplicate(true)
	app.capstone_story._close()
	var restored = State.new(); restored.fixture = fixture
	check(restored.load_game(classified)==OK,"Restore actual classified checkpoint for isolated alternate disposition")
	s = restored; app.state = s
	inputs.append({"kind":"isolated_branch_restore","state":s.to_dict(),"checkpoint_sha256":FileAccess.get_sha256(classified),"first_completed_branch":finished})
	await _place("capstone_order_desk"); await _interact("capstone_order_desk"); await _action("F0")
	await _disposition("cancel_proven","17-desk-cancel-proven")
	await _finish_report()

func _panel():
	return app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null

func _enemy(snapshot: Dictionary) -> Dictionary:
	for enemy: Dictionary in snapshot.get("enemies",[]):
		if enemy.id == "liang_zhen": return enemy
	return {}

func _place(site: String) -> void:
	if app.active_modal: app.capstone_story._close()
	app.current_screen="explore"; app.active_modal=false; app._clear_overlay()
	s.map_id=Story.SITES[site]; app._sync_world_state(); app.world.change_map(s.map_id,Vector2(500,450)); app._sync_world_state()
	var destination: Vector2=app.world.interactables[site].pos + Vector2(0,68)
	check(app.world._can_walk(destination),"Declared lawful prepared observation position "+site)
	app.world.facing=Vector2.UP # Declared initial approach: companions seed behind, clear of the target.
	app.world.teleport(destination); s.position=app.world.player_pos
	app.world.camera_pos=app.world._camera_target(); app.world._update_nearby(); app._process(0); app._refresh()
	inputs.append({"kind":"explicit_lawful_per_site_placement","site":site,"map":s.map_id,"position":[s.position.x,s.position.y],"not_earned_travel":true,"initial_facing":[0,-1]})
	await _settle()

func _interact(site: String) -> void:
	check(app.world.nearby_id==site,"Real nearby E target "+site+" observed="+app.world.nearby_id)
	root.gui_release_focus(); await _key(KEY_E)
	inputs.append({"kind":"scripted_actual_E_key","site":site,"page":app.capstone_story._page})
	check(app.active_modal,"Actual E opens scene "+site)
	await _settle()

func _action(action: String) -> void:
	var page: String=app.capstone_story._page
	var label = ""
	for entry: Array in Story.PAGES.get(page,{}).get("choices",[]):
		if String(entry[1])==action and _button(app.overlay,String(entry[0]))!=null: label=String(entry[0]); break
	check(not label.is_empty(),"Current visible action "+page+" -> "+action)
	if label.is_empty(): return
	var control = _button(app.overlay,label)
	inputs.append({"kind":"scripted_actual_mouse_press_release","page":page,"action":action,"label":label,"rect":_area(control.get_global_rect())})
	await _click(control)
	var panel = _panel()
	if panel != null: panel.set_process(false); panel.art.set_process(false)
	await _settle()

func _disposition(plan: String,name: String) -> void:
	await _action("plan:"+plan); await _action("selected_confirmation"); await _action("confirm:"+plan)
	check(s.capstone_stage==6 and s.capstone_ending==plan,"Actual explicit disposition "+plan)
	await _action("close")
	await _capture(name,"Four actual order-sheet outcomes after explicit "+plan+"; no reward until homecoming")

func _settle() -> void:
	app._process(0); app.world.time_passed=.375; app.world.queue_redraw()
	for _i in range(3): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func _capture_pair(pose: String,note: String) -> void:
	var index = {"idle":5,"heavy":7,"contact":9,"recovery":11,"down":13}[pose]
	for compact: bool in [false,true]:
		root.size=Vector2i(1179,737) if compact else Vector2i(1280,800)
		await _settle()
		await _capture("%02d-battle-%s-%s"%[index+(1 if compact else 0),pose,"compact" if compact else "full"],note)
	root.size=Vector2i(1280,800); await _settle()

func _capture(name: String,note: String) -> void:
	if app.current_screen == "explore" and not app.active_modal:
		var before_wait: Dictionary=s.to_dict().duplicate(true)
		app._process(8.0) # Normal HUD expiry only; no walking or story shortcut.
		check(s.to_dict()==before_wait,"Waiting for HUD expiry cannot mutate progress or resources")
	await _settle()
	var frame: Dictionary={"name":name,"note":note,"screen":app.current_screen,"page":app.capstone_story._page,"stage":s.capstone_stage,"draft":s.capstone_draft,"ending":s.capstone_ending,"resources":s.party_resource_snapshot(),"state":s.to_dict(),"movie_frame":movie_frame,"battle_frame":battle_frame,"clock":.375}
	var panel=_panel()
	if panel!=null:
		frame.snapshot=panel.art.display_snapshot; frame.pending=panel.pending.duplicate(true); frame.presentation_phase=panel.art.presentation_phase; frame.action_time=panel.art.action_time; frame.actors={}
		for unit: Dictionary in panel.art.display_snapshot.actors+panel.art.display_snapshot.enemies:
			frame.actors[unit.id]={"pose":panel.art.actor_visual_pose(unit.id),"foot":[panel.art.actor_foot(unit.id).x,panel.art.actor_foot(unit.id).y],"opaque_rect":_area(panel.art.actor_alpha_rect(unit.id)),"label":_area(panel.art.unit_label_rect(unit.id))}
	else:
		frame.followers={}
		for id: String in app.world.follower_ids():
			var actor: Dictionary=app.world.follower_view(id)
			frame.followers[id]={"position":[actor.position.x,actor.position.y],"moving":actor.moving}
		frame.archive_presentation=app.world.capstone_archive_presentation()
		frame.camera=[app.world.camera_pos.x,app.world.camera_pos.y]; frame.order_rows=Rules.order_rows(s); frame.archive_name=app.world.get_npc_name("chapter_archive") if app.world.map_id=="frostbridge" else ""
	if DisplayServer.get_name()!="headless":
		var pixels: Image=root.get_texture().get_image()
		check(pixels.save_png(out_dir+"/screenshots/"+name+".png")==OK,"Direct native PNG "+name)
		frame.width=pixels.get_width();frame.height=pixels.get_height()
	captures.append(frame); _progress()

func _area(rect: Rect2) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func _progress() -> void:
	var file=FileAccess.open(out_dir+"/capture-progress.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"gate":evidence_gate,"captures":captures,"inputs":inputs},"\t")); file.close()
func _verify_source(when: String) -> void:
	for path: String in hashes: check(FileAccess.get_sha256("res://"+path)==hashes[path],"Exact source "+when+": "+path)
func _finish_report() -> void:
	_verify_source("after")
	var file=FileAccess.open(out_dir+"/capture-trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Native Godot full-main frames. Prepared canonical old history and lawful per-site initial placements. New chapter actual E/mouse story callbacks, accepted current combat transactions and isolated saves. Scripted inputs except explicitly logged CUA. No earned travel, manual play, browser, audio, realtime or FPS claims.","source_identity":source_identity,"runtime_and_driver_sha256":hashes,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"checks":checks,"failures":failures,"captures":captures,"inputs":inputs,"combat_events":combat_events,"transactions":transactions,"movie":{"captured":capture_clip,"frame_count":movie_frame,"fps":30,"duration_seconds":float(movie_frame)/30.0,"silent":true,"timing":"fixed-step .033333s; native frames, not realtime"},"found":found},"\t")); file.close()
	print("%s capstone native: %d checks; %d frames; %d failures"%["PASS" if failures==0 else "FAIL",checks,captures.size(),failures])
	app._stop_audio();app.queue_free();await process_frame;quit(0 if failures==0 else 1)
