extends "res://tests/companion_folio_behavior_test.gd"
## Genuine Main/HeroState/LocalSaveSlots integration; the inherited owned-profile
## guard runs before loading any game resource. No fake save or Main override.
## May be inherited by an external exact-PCK runner under the same owned guard.
## Prepared fixtures and scripted inputs are not native pixel acceptance.
const ORACLE_PATH = "res://tests/journal_guidance_frozen_oracle.json"
const ORACLE_SHA = "38cb8469799e8169201c06e203cd219901e3d06c159c09998ffc2e577ff0c443"
const MAP_CASES = ["qingwei-mainland", "qingwei-islet", "sluice", "frostbridge-broken", "frostbridge-repaired", "mistwood-manual", "heting-west-meal", "heting-east-sealed", "heting-west-consignee", "heting-east-parking"]
var fixture_helper
var fixture_records: Array[Dictionary] = []

func _run() -> void:
	if not _guard():
		push_error("ERROR: map folio ownership guard rejected before game loads")
		quit(2); return
	guard_passed = true
	create_timer(150.0).timeout.connect(func():
		if not finished:
			_check(false,"Map folio behavior watchdog expired")
			_finish())
	if not await _boot(): _finish(); return
	if not _check(app.save_slots.store.get_script() == load("res://scripts/local_save_slots.gd"),"Real Main owns production LocalSaveSlots without writer overrides"): _finish(); return
	if not _check(FileAccess.get_sha256(ORACLE_PATH) == ORACLE_SHA,"Unchanged independently frozen 117-case guidance corpus"): _finish(); return
	fixture_helper = load("res://tests/journal_guidance_test_fixture.gd")
	if not _check(fixture_helper != null,"Fixture readers load only after owned-profile guard"): _finish(); return
	if not _seed_owned_slots(): _finish(); return
	await _maps_and_preservation()
	if not failures.is_empty(): _finish(); return
	await _close_paths()
	if not failures.is_empty(): _finish(); return
	await _deferred_and_stale()
	if not failures.is_empty(): _finish(); return
	await _live_guidance_refresh()
	if not failures.is_empty(): _finish(); return
	await _bridge_change()
	if not failures.is_empty(): _finish(); return
	await _map_blocking()
	_finish()

func _seed_owned_slots() -> bool:
	_section("genuine_manual_save_and_backup_fixture")
	var seed = _new_state()
	var path: String = app.save_slots.store.path_for(1)
	if not _check(app.save_slots.store.save_slot(seed,1) == OK,"Genuine local store creates an owned manual-save fixture"): return false
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	seed.coins += 1
	if not _check(app.save_slots.store.save_slot(seed,1) == OK,"Genuine local store rotates a differing accepted manual save"): return false
	_check(not original.is_empty() and FileAccess.get_file_as_bytes(path+".bak") == original and FileAccess.get_file_as_bytes(path) != original,"Prepared backup is the exact real previous manual save")
	var restored = model.new()
	_check(restored.load_game(path) == OK and restored.to_dict() == seed.to_dict(),"Production reader validates the prepared current manual save")
	fixture_records.append({"id":"manual-slot-and-backup","prepared_not_earned":true,"preparation":"Two differing production LocalSaveSlots.save_slot writes; real old-byte backup retained","files":_application_files()})
	return failures.is_empty()

func _map_recipe(id: String) -> Dictionary:
	var recipe: Dictionary = {"id":id,"manual_arc":"","route_status":""}
	match id:
		"qingwei-mainland":
			recipe.state = fixture_helper.from_retained("opening_0"); recipe.source = "opening_0"
		"qingwei-islet":
			recipe.state = fixture_helper.from_retained("sluice_0_qingwei"); recipe.source = "sluice_0_qingwei"
			recipe.state.lightness_unlocked = true; recipe.state.position = Vector2(1514,930); recipe.route_status = "via_crossing"
		"sluice":
			recipe.state = fixture_helper.from_retained("sluice_1_sluice"); recipe.source = "sluice_1_sluice"; recipe.state.position = Vector2(190,520)
		"frostbridge-broken":
			recipe.state = fixture_helper.from_retained("frost_clues_[]"); recipe.source = "frost_clues_[]"; recipe.state.position = Vector2(190,500)
		"frostbridge-repaired":
			recipe.state = fixture_helper.from_retained("bounded_qin_tang_fix_1_1"); recipe.source = "bounded_qin_tang_fix_1_1"
			recipe.state.map_id = "frostbridge"; recipe.state.position = Vector2(190,500); recipe.manual_arc = "qin_rope"; recipe.route_status = "via_exit"
		"mistwood-manual":
			recipe.state = fixture_helper.from_retained("capstone_5_mistwood"); recipe.source = "capstone_5_mistwood"
			recipe.state.position = Vector2(350,395); recipe.manual_arc = "capstone"; recipe.route_status = "via_exit"
		_:
			if id in ["heting-west-consignee","heting-east-parking"]:
				recipe.state = fixture_helper.from_retained("harbor_overlap_1_4"); recipe.source = "harbor_overlap_1_4"
				recipe.manual_arc = "qin_rope" if id.ends_with("parking") else "heting_consignee"
				if id.ends_with("parking"): recipe.route_status = "departure_confirmation"
			else:
				recipe.state = fixture_helper.base(4); recipe.source = "explicit base(4) harbor/cargo fixture"
				recipe.state.map_id = "heting"; recipe.state.heting_stage = 1
				recipe.state.heting_cargo = "meal" if "-west-" in id else "sealed"
			recipe.state.heting_bridge = "west" if "-west-" in id else "east"
			recipe.state.position = Vector2(820,665)
	return recipe

func _prepare_map(recipe: Dictionary) -> bool:
	if not await _prepare(recipe.state,recipe.id): return false
	if not recipe.manual_arc.is_empty():
		if not _check(app.journal_session.track(app.state,recipe.manual_arc,app.journal_session.token(app.state)),"Explicit transient tracking fixture accepted"): return false
		app._sync_journal_guidance(true,true)
	# Deliberate saved/physical split, written by the genuine production writer.
	# Start M immediately after return, before any idle process can synchronize it.
	app.state.position = app.world.player_pos + Vector2(0.125,-0.125)
	if not _check(app.state.save_game() == OK,"Real writer persists explicit stored/physical position split"): return false
	_saved(app.state.to_dict(),"Prepared map fixture with distinct canonical position")
	fixture_records.append({"id":recipe.id,"source":recipe.source,"prepared_not_earned":true,"manual_arc":recipe.manual_arc,"canonical":app.state.to_dict(),"physical_position":_json_safe(app.world.player_pos),"stored_position":_json_safe(app.state.position)})
	return _check(app.current_screen == "explore" and not app.active_modal and app.state.position != app.world.player_pos,"Prepared genuine exploration has a stored/physical split")

func _transients() -> Dictionary:
	var result: Dictionary = super()
	result.journal_selection = app.journal_session.tracked_arc_id
	result.journal_token = app.journal_session.token(app.state).duplicate(true)
	result.party_resources = app.state.party_resource_snapshot().duplicate(true)
	result.application_files = _application_files()
	return result

func _application_files(path: String = "", relative: String = "") -> Dictionary:
	var actual = owned_user if path.is_empty() else path
	var result: Dictionary = {}
	if not _check(_tree_unlinked(actual),"Application files remain in an unlinked owned tree"): return result
	var directory = DirAccess.open(actual)
	if not _check(directory != null,"Owned application directory is readable"): return result
	directory.include_hidden = true; directory.include_navigational = false
	for leaf: String in directory.get_files():
		var filename = actual.path_join(leaf)
		var bytes = FileAccess.get_file_as_bytes(filename)
		result[relative.path_join(leaf)] = {"bytes":bytes.size(),"sha256":FileAccess.get_sha256(filename),"base64":Marshalls.raw_to_base64(bytes)}
	for leaf: String in directory.get_directories():
		if relative.is_empty() and leaf in ["logs","shader_cache"]: continue
		result[relative.path_join(leaf)+"/"] = {"directory":true}
		result.merge(_application_files(actual.path_join(leaf),relative.path_join(leaf)))
	return result

func _page():
	return app.overlay.find_child("DialogueSheet",true,false)

func _bounds(control: Control, relative: Control) -> Rect2:
	return (relative.get_global_transform().affine_inverse()*control.get_global_transform())*Rect2(Vector2.ZERO,control.size)

func _map_contract(recipe: Dictionary) -> bool:
	if not _check(app.current_screen == "explore" and app.active_modal and app.overlay.get_meta("journal_map",false),"Actual M owns the current map modal"): return false
	var page = _page()
	if not _check(is_instance_valid(page),"Compatibility root DialogueSheet retained"): return false
	var chart = page.find_child("RegionChart",true,false)
	var caption = page.find_child("MapGuidanceCaption",true,false)
	var close = page.find_child("DialogueChoice1",true,false)
	if not _check(chart != null and caption is Label and close is Button,"Existing chart, full guidance caption and sole close control retained"): return false
	_check(chart.get_script() == load("res://scripts/map_chart.gd"),"Exact production MapChart remains the cartographic renderer")
	_check(app.modal_actions.size() == 1 and page.find_children("DialogueChoice*","Button",true,false).size() == 1,"Exactly one original close action, with no travel choices")
	_check(chart.size == Vector2(780,330) and chart.CHART_SIZE == Vector2(780,330) and chart.MAP_RECT == Rect2(40,20,690,270) and chart.WORLD_SIZE == Vector2(1600,1050),"Local chart dimensions and geographic projection are unchanged")
	for pair: Array in [[Vector2.ZERO,Vector2(40,20)],[Vector2(800,525),Vector2(385,155)],[Vector2(1600,1050),Vector2(730,290)]]:
		_check(chart._point(pair[0]) == pair[1],"Literal world-to-chart projection: "+str(pair[0]))
	_check(is_equal_approx(chart.scale.x,chart.scale.y) and chart.scale.x >= 1.3 and chart.scale.x <= 1.38,"One uniform chart enlargement preserves aspect and projection")
	var guidance: Dictionary = app.journal_guidance_snapshot
	_check(chart.map_id == app.state.map_id and chart.map_id == app.world.map_id and chart.player_position == app.world.player_pos and chart.markers == app.world.interactables,"Chart receives exact region, physical position, markers and exits")
	_check(chart.journal_guidance_snapshot == guidance and app.world.journal_guidance_snapshot == guidance and app.hud.journal_guidance_snapshot == guidance,"Map, world and HUD retain exactly shared guidance")
	_check(chart.current_target == guidance.next_target_id and chart.current_target == app.world._quest_target_id() and chart.cart_route == guidance.cart_route,"No independent map target or route selection")
	_check(chart.heting_bridge == app.state.heting_bridge and chart.heting_cargo == app.state.heting_cargo and chart.consignee_cargo_location == app.state.consignee_cargo_location and chart.bridge_repaired == app.state.bridge_repaired,"Both bridges and both cargo systems remain exact")
	_check(app.journal_session.tracked_arc_id == recipe.manual_arc and guidance.mode == ("auto" if recipe.manual_arc.is_empty() else "manual"),"Prepared auto/manual selection is retained")
	_check(caption.text == app.journal_guidance_caption(guidance),"Entire guidance caption is exact, without truncation or rewritten route notes")
	_check(caption.is_visible_in_tree() and not caption.clip_text and caption.visible_characters == -1 and caption.max_lines_visible == -1 and caption.get_visible_line_count() == caption.get_line_count(),"All settled wrapped guidance lines are visible")
	if not recipe.route_status.is_empty(): _check(guidance.route_status == recipe.route_status,"Literal expected route status: "+recipe.route_status)
	if recipe.id.ends_with("parking"):
		_check("离港须" in guidance.route_note and "北仓" in guidance.route_note and guidance.route_note in caption.text,"Long loaded departure note keeps the full north-warehouse parking requirement")
	if recipe.id == "qingwei-islet": _check(chart.current_target == "reed_return","Islet uses actual return crossing")
	if recipe.id == "frostbridge-broken": _check("南桥待修" in guidance.route_note,"Broken south bridge note remains visible")
	var page_bounds = Rect2(Vector2.ZERO,page.size)
	var chart_bounds = _bounds(chart,page)
	var caption_bounds = _bounds(caption,page)
	var close_bounds = _bounds(close,page)
	var title_bounds = _bounds(page.find_child("DialogueTitle",true,false),page)
	_check(Rect2(Vector2.ZERO,app.overlay.size).encloses(_bounds(page,app.overlay)),"Settled page fits the actual logical overlay")
	for rectangle: Rect2 in [chart_bounds,caption_bounds,close_bounds,title_bounds]:
		_check(page_bounds.encloses(rectangle),"Transformed readable content remains inside the folio")
	_check(not chart_bounds.intersects(caption_bounds) and not chart_bounds.intersects(close_bounds) and not chart_bounds.intersects(title_bounds),"Uniformly enlarged chart never covers guidance, heading or close action")
	_check(not caption_bounds.intersects(close_bounds) and not caption_bounds.intersects(title_bounds),"Full caption never covers heading or close action")
	_check(close.is_visible_in_tree() and not close.disabled and close.size.y >= 38,"Sole close action remains reachable")
	_check(not app.world.active and not app.modal_autosave_on_close and not app._journal_position_hold.is_empty(),"Map retains immediate world freeze, read-only close and canonical position hold")
	return failures.is_empty()

func _maps_and_preservation() -> void:
	for id: String in MAP_CASES:
		_section("map_"+id)
		var recipe = _map_recipe(id)
		root.size = Vector2i(1280,800)
		if not await _prepare_map(recipe): return
		var before = _snapshot("Before actual M with stored/physical split")
		for dimensions: Vector2i in [Vector2i(1280,800),Vector2i(960,600)]:
			root.size = dimensions
			await _key(KEY_M)
			if not _map_contract(recipe): return
			_expect(before,{},"Actual M preserves every canonical field, resource, transient, selection, physical anchor and application byte")
			var page = _page()
			var generation: int = app.modal_generation
			await _key(KEY_M); await _key(KEY_M)
			_check(_page() == page and app.modal_generation == generation,"Repeated actual M cannot replace or stack a live map")
			await _key(KEY_D)
			_check(_page() == page and not app.world.active,"Movement input cannot displace the frozen world behind the map")
			var chart = page.find_child("RegionChart",true,false)
			await _chart_pointer(chart)
			_check(_page() == page and app.active_modal and app.modal_generation == generation,"Actual chart click is a navigation and modal no-op")
			_expect(before,{},"Repeated M and chart click preserve the complete read-only boundary")
			await _key(KEY_ESCAPE); await _frames(3)
			_check(not app.active_modal and app.modal_generation == generation+1,"Escape dismisses exactly once")
			_expect(before,{},"Dismissal and idle frames preserve the original stored/physical split and all bytes")
			if not failures.is_empty(): return

func _chart_pointer(chart: Control) -> void:
	var point: Vector2 = root.get_final_transform()*chart.get_global_transform()*(chart.size*.5)
	inputs.append({"section":current_section,"kind":"queued_native_chart_pointer","pixel_position":[point.x,point.y]})
	var motion = InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); Input.flush_buffered_events()
	for pressed: bool in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await _frames(1)
	await _frames(2)

func _close_paths() -> void:
	_section("every_original_close_once")
	var recipe: Dictionary = {"id":"recruited-resources","source":"explicit recruited four-actor fixture with downed Shen and nontrivial HP/Qi","state":_all_state(),"manual_arc":"","route_status":""}
	if not await _prepare_map(recipe): return
	_check(app.state.hp == 37 and app.state.qi == 1 and app.state.party_resources.shen.hp == 0 and app.state.party_roster.size() == 4,"Close-path fixture retains actual selected/downed and partial party resources")
	var before = _snapshot("Before five original map close inputs")
	for code: int in [KEY_ESCAPE,KEY_ENTER,KEY_SPACE,KEY_1,0]:
		await _key(KEY_M)
		if not _map_contract(recipe): return
		var generation: int = app.modal_generation
		var old_page = _page()
		var close: Callable = app.modal_actions[0]
		if code == 0: await _pointer(old_page.find_child("DialogueChoice1",true,false),"Original map close button")
		else: await _key(code)
		_check(not app.active_modal and not app.overlay.get_meta("journal_map",false) and app.modal_generation == generation+1,"Original close input advances generation exactly once: "+str(code))
		close.call(); close.call(); await _frames(2)
		_check(not app.active_modal and app.modal_generation == generation+1,"Repeated guarded close callback cannot close or save twice")
		_expect(before,{},"Original close and repeated callback preserve all state, selection and bytes")

func _key_now(code: int) -> void:
	inputs.append({"section":current_section,"kind":"queued_native_same_turn_key","key":OS.get_keycode_string(code)})
	for pressed: bool in [true,false]:
		var event = InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()

func _deferred_and_stale() -> void:
	_section("same_turn_close_and_stale_layout")
	if not await _prepare_map(_map_recipe("heting-east-parking")): return
	var before = _snapshot("Before same-turn M/Escape/M without layout frames")
	_key_now(KEY_M)
	if not _check(app.active_modal and _page() != null,"M opens synchronously before deferred layout"): return
	var old_page = _page()
	var old_generation: int = app.modal_generation
	var old_close: Callable = app.modal_actions[0]
	_check(not app.world.active,"World freezes during actual M dispatch, before deferred layout or an idle frame")
	_key_now(KEY_ESCAPE)
	_check(not app.active_modal and app.modal_generation == old_generation+1,"Rapid Escape closes before deferred layout")
	_key_now(KEY_M)
	var replacement = _page()
	var generation: int = app.modal_generation
	if not _check(replacement != null and replacement != old_page,"Same-turn M creates a distinct current page"): return
	var replacement_rect: Rect2 = replacement.get_rect()
	app._layout_journal_map(old_page,old_generation); old_close.call()
	_check(_page() == replacement and replacement.get_rect() == replacement_rect and app.modal_generation == generation,"Detached old layout and close cannot alter the new page before layout")
	await _frames(5)
	if not _map_contract(_map_recipe("heting-east-parking")): return
	old_close.call()
	_check(_page() == replacement and app.modal_generation == generation,"Old close remains inert after both generations' deferred queues drain")
	_expect(before,{},"Rapid close/reopen and stale callbacks retain canonical, transient, resources, selection and application bytes")
	await _key(KEY_ESCAPE)
	# Also let a close-only page's deferred callbacks run with no replacement.
	_key_now(KEY_M); generation = app.modal_generation; _key_now(KEY_ESCAPE); await _frames(4)
	_check(not app.active_modal and _page() == null and app.modal_generation == generation+1,"Deferred layout after rapid close cannot resurrect a page")
	_expect(before,{},"Close-only deferred queue remains entirely read-only")

func _live_guidance_refresh() -> void:
	_section("live_full_caption_reflow")
	var recipe = _map_recipe("heting-east-parking")
	if not await _prepare_map(recipe): return
	var initial = _snapshot("Before loaded manual-tracking map")
	await _key(KEY_M)
	if not _map_contract(recipe): return
	_expect(initial,{},"Initial long parking guidance is read-only")
	var page = _page()
	var generation: int = app.modal_generation
	var caption = page.find_child("MapGuidanceCaption",true,false)
	var previous_text: String = caption.text
	var accepted: Dictionary = {}
	# These are explicit transient selection fixtures through the real session
	# API, not a claim that the read-only map itself offers tracking controls.
	for arc: String in ["","qin_rope"]:
		var token: Dictionary = app.journal_session.token(app.state)
		var changed: bool = app.journal_session.restore_auto(app.state,token) if arc.is_empty() else app.journal_session.track(app.state,arc,token)
		if not _check(changed,"Production session accepts explicit live selection fixture"): return
		accepted = _snapshot("After deliberate transient selection; before real shared-guidance refresh")
		app._sync_journal_guidance(true,true); await _frames(4)
		var current: Dictionary = {"id":"heting-east-parking" if not arc.is_empty() else "live-auto","manual_arc":arc,"route_status":"departure_confirmation" if not arc.is_empty() else ""}
		if not _map_contract(current): return
		_check(_page() == page and app.modal_generation == generation and caption.text != previous_text,"Current page reflows changed full guidance without replacement or stale text")
		_expect(accepted,{},"Shared-guidance refresh and caption relayout preserve every field except the explicitly prepared prior selection")
		previous_text = caption.text
	await _key(KEY_ESCAPE)
	_expect(accepted,{},"Live-refreshed map closes with exact resources, stored/physical position, selection and original files")

func _bridge_change() -> void:
	_section("genuine_free_bridge_change_then_reopen")
	var recipe = _map_recipe("heting-east-sealed")
	recipe.state.heting_cargo = "meal"
	var harbor = load("res://scripts/heting_region.gd")
	recipe.state.position = harbor.points().heting_winch.pos
	if not await _prepare_map(recipe): return
	await _key(KEY_M)
	if not _map_contract(recipe): return
	var chart = _page().find_child("RegionChart",true,false)
	var old_route: PackedVector2Array = chart.cart_route.duplicate()
	var old_close: Callable = app.modal_actions[0]
	await _key(KEY_ESCAPE)
	_check(app.world.nearby_id == "heting_winch","Prepared physical fixture is beside the genuine winch")
	await _key(KEY_E)
	if not _check(app.active_modal and not app.overlay.get_meta("journal_map",false),"Actual E opens the genuine winch dialogue"): return
	var state_before: Dictionary = app.state.to_dict().duplicate(true)
	await _key(KEY_1)
	_check(not app.active_modal and app.state.heting_bridge == "west" and app.world.heting_bridge == "west","Original winch choice changes the actual free bridge")
	var expected: Dictionary = state_before.duplicate(true)
	expected.heting_bridge = "west"; expected.position = app.state.to_dict().position
	_check(app.state.to_dict() == expected,"Free bridge change has only its existing bridge/explicit position-save effects")
	_saved(app.state.to_dict(),"Genuine winch autosave")
	var before = _snapshot("After actual east-to-west bridge change and save")
	await _key(KEY_M)
	if not _map_contract(recipe): return
	chart = _page().find_child("RegionChart",true,false)
	var routes = load("res://scripts/heting_cart_routes.gd")
	_check(chart.heting_bridge == "west" and chart.cart_route == routes.route(app.world.player_pos,harbor.points().heting_relief.pos,"west") and chart.cart_route != old_route,"Reopened chart recomputes changed bridge geometry from real world connectivity")
	for index in range(1,chart.cart_route.size()):
		_check(harbor.can_step(chart.cart_route[index-1],chart.cart_route[index],"west",true),"Reopened loaded cart segment obeys the changed bridge")
	var generation: int = app.modal_generation
	old_close.call()
	_check(app.active_modal and app.modal_generation == generation,"Pre-winch map callback cannot close the reopened current bridge map")
	await _key(KEY_ESCAPE)
	_expect(before,{},"Reopened map preserves the real changed bridge, cargo, resources, selection and saved bytes")

func _map_blocking() -> void:
	_section("owner_quit_pending_and_real_battle_guards")
	if not await _prepare(_all_state(),"Prepared genuine recruited state for entry guards"): return
	var before = _snapshot("Before rejected owner boundary calls")
	var generation: int = app.modal_generation
	# Explicitly prepared ownership metadata probes exercise every existing host
	# gate synchronously, without inventing alternative owner controllers.
	for owner: String in ["weapon_fitting","party_roster","party_roster_direct_info","receipt_battle","party_battle","courtyard_practice","save_transfer","fitting_workshop_readonly","fitting_exit_readonly"]:
		app.overlay.set_meta(owner,true)
		app._show_map(); _key_now(KEY_M)
		_check(not app.active_modal and _page() == null and app.modal_generation == generation,"Existing owner blocks direct and actual M entry: "+owner)
		app.overlay.remove_meta(owner)
	app.quit_pending = true; app._show_map(); await _key(KEY_M)
	_check(not app.active_modal and _page() == null and app.modal_generation == generation,"Quit pending blocks direct and actual M entry")
	app.quit_pending = false
	app.state.battle_active = true; app._show_map(); _key_now(KEY_M)
	_check(not app.active_modal and app.modal_generation == generation,"Existing battle flag blocks map entry")
	app.state.battle_active = false
	var pending: int = app.state._party_pending_token
	app.state._party_pending_token = 42; app._show_map(); _key_now(KEY_M)
	_check(not app.active_modal and app.modal_generation == generation,"Pending party transaction blocks map entry")
	app.state._party_pending_token = pending
	_expect(before,{},"Rejected entry guards preserve canonical/transient/resource/selection and file boundaries")
	await _key(KEY_J)
	var journal = app.overlay.get_meta("journal_ui",null)
	if not _check(journal != null,"Actual journal owns its page"): return
	generation = app.modal_generation; before = _snapshot("Genuine journal owner before M")
	app._show_map(); await _key(KEY_M)
	_check(app.overlay.get_meta("journal_ui",null) == journal and app.modal_generation == generation and app.overlay.find_child("RegionChart",true,false) == null,"Actual journal owner cannot be replaced by a map")
	_expect(before,{},"Blocked map attempt preserves genuine journal selection and all state")
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	var stale: Callable = app.modal_actions[0]
	await _key(KEY_ESCAPE)
	var controller = battle_driver.open_training(app)
	if not _check(app.current_screen == "party_battle" and app.state.battle_active,"Actual unified training battle owns input"): return
	before = _snapshot("Real battle before M and stale map callback"); generation = app.modal_generation
	await _key(KEY_M); app._show_map(); stale.call()
	_expect(before,{},"Real battle rejects map input and stale close without resource, selection, transaction or save changes")
	_check(app.modal_generation == generation and app.overlay.get_meta("party_battle",null) == controller and controller.pending.is_empty(),"Real battle owner and pending transaction remain exact")
	battle_driver.leave(app)
	_check(app.current_screen == "explore" and not app.state.battle_active,"Actual battle controller retreat settles normally")

func _finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(app): app._stop_audio(); app.free()
	if guard_passed:
		if not _no_links(report_path) or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(report_path):
			push_error("ERROR: map folio report path became unsafe before write"); quit(2); return
		var report = {"suite":"map_folio_behavior","status":"pass" if failures.is_empty() and checks > 0 else "fail","checks":checks,"failures":failures,"sections":sections,"fixtures":fixture_records,"checkpoints":checkpoints,"inputs":inputs,"user_dir":owned_user,"limits":["Prepared validator-accepted fixtures are not journey-earned progress","Scripted Input.parse_input_event behavior and transformed geometry are not native pixel acceptance","No save, Main, model or local-store overrides","Exact original application bytes cannot prove absence of same-content writes","Literal projection and map UI checks complement the unchanged 117-case journal consumer suite and loaded-cart route suite","Exact-PCK acceptance requires an independently bound external runner"]}
		var file = FileAccess.open(report_path,FileAccess.WRITE)
		if file == null: push_error("ERROR: map folio report cannot be opened"); quit(2); return
		file.store_string(JSON.stringify(report,"\t")); file.flush()
		var error = file.get_error(); file.close()
		if error != OK: push_error("ERROR: map folio report write failed"); quit(2); return
	if failures.is_empty() and checks > 0: print("PASS: NEW map folio behavior, %d checks" % checks)
	else: push_error("ERROR: map folio behavior failed, %d failures" % failures.size())
	quit(0 if failures.is_empty() and checks > 0 else 1)
