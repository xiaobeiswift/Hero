extends SceneTree
## Focused read-only model/session tests. Prepared canonical fixtures are not
## native/UI acceptance. The independent driver compares the actual frozen Main.
const State = preload("res://scripts/game_state.gd")
const Objectives = preload("res://scripts/journal_objective_rules.gd")
const Guidance = preload("res://scripts/journal_guidance_rules.gd")
const Session = preload("res://scripts/journal_guidance_session.gd")
const Fixture = preload("res://tests/capstone_world_fixture.gd")
const World = preload("res://scripts/world.gd")
const Lightness = preload("res://scripts/lightness_rules.gd")
const Region = preload("res://scripts/heting_region.gd")
var checks: int = 0
var failures: int = 0
var failure_labels: Array[String] = []
var world

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; failure_labels.append(label); push_error(label)
func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	world = World.new(); world.terrain_cache_enabled = false; root.add_child(world); world.set_process(false)
	_catalog()
	_routes()
	_cart_routes()
	_lifetime()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify({"checks":checks, "failures":failures, "failure_labels":failure_labels, "schema":State.SAVE_VERSION, "scope":"prepared model/session, no UI/native/publication"}, "\t") + "\n")
	world.queue_free(); await process_frame
	print("%s journal guidance model: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _mist():
	var s = Fixture.state(7)
	s.capstone_stage = 0; s.capstone_draft = ""; s.capstone_ending = ""
	s.consignee_stage = 0; s.consignee_observations.clear(); s.consignee_contributions.clear(); s.consignee_draft = ""; s.consignee_cargo_location = ""; s.consignee_ending = ""
	s.heting_stage = 0; s.heting_bridge = ""; s.heting_delivered.clear(); s.heting_cargo = ""; s.heting_draft = ""; s.heting_ending = ""
	s.map_id = "mistwood"; s.position = Vector2(350, 395)
	check(s._stage_save_data(s.to_dict(), 16).ok, "prepared Mist fixture validates schema16")
	return s
func _context(s, position: Vector2 = Vector2(535, 400)) -> Dictionary:
	world.capstone_stage = s.capstone_stage; world.heting_stage = s.heting_stage; world.consignee_stage = s.consignee_stage
	world.heting_bridge = s.heting_bridge; world.heting_cargo = s.heting_cargo; world.consignee_cargo_location = s.consignee_cargo_location
	world.change_map(s.map_id, position)
	var names: Dictionary = {}
	for id: String in world.interactables: names[id] = world.get_npc_name(id)
	return {"map_id":s.map_id, "player_position":position, "markers":world.interactables.duplicate(true), "marker_names":names}
func _catalog() -> void:
	var s = State.new()
	check(Objectives.IDS.size() == 14, "finite14 IDs")
	check(Objectives.catalog(s).size() == 1, "new journey reveals opening only")
	check(Objectives.row(s, "capstone").is_empty() and Objectives.row(s, "unknown").is_empty(), "hidden/unknown IDs yield no row")
	s.companion_unlocked = true
	check(Objectives.row(s, "shen_care").is_empty(), "recruited Shen does not unlock unfinished prerequisite")
	s = _mist()
	check(Objectives.row(s, "qin_rope").status == "available", "Qin stage0 is an available contact")
	var qin: Dictionary = Objectives.row(s, "qin_rope")
	check(not qin.earned_history.contains("尺绳") and not qin.display_title.contains("尺绳"), "available Qin does not reveal personal task")
	s.map_id = "qingwei"; s.battle_active = true; s.hp = 0
	check(Objectives.row(s, "qin_rope").trackable, "available identity survives location, battle and health")
	s.battle_active = false; s.hp = s.max_hp; s.map_id = "mistwood"
	s.bridge_repaired = true; check(s.begin_tangqi_quest(), "ordinary Tang acceptance")
	s.mist_stage = 1; s.mist_ending = ""; s.mist_gauges.clear(); s.mist_approach = ""
	check(Objectives.automatic(s).id == "mistwood", "negative Tang1/Mist1 retains Mist auto")
	check(Objectives.automatic(s).display_title == "三尺问雨", "negative frozen automatic title")
	s.mist_gauges.assign(["rain", "basin"])
	var mist: Dictionary = Objectives.row(s, "mistwood")
	check(mist.destination_site == "mist_scout" and not mist.next_action.contains("援引已公示"), "protected witness manual scout excludes records method")
	check(mist.next_action.contains("材料不足"), "unaffordable repair does not promise usable method")
	check(Objectives.automatic(s).next_action.contains("三种"), "frozen broad automatic summary retained explicitly")
	s.chapter_two_ending = "open_records"; s.resources.timber = 1; s.resources.cloth = 1
	check(Objectives.row(s, "mistwood").next_action.contains("援引已公示"), "earned public records method appears")
	check(Objectives.row(s, "mistwood").next_action.contains("也可交木料"), "affordable repair described truthfully")
	s = _mist(); s.bridge_repaired = true; s.begin_tangqi_quest(); s.begin_qin_quest()
	check(Objectives.automatic(s).id == "qin_rope", "actual Tang1/Mist4/Qin1 gap adopts frozen HUD Qin")
	check(Objectives.row(s, "mistwood").status == "completed" and not Objectives.row(s, "mistwood").trackable, "completed Mist cannot be manually revived by pending Qin")
	check(not Objectives.row(s, "mistwood").earned_history.contains("尺绳"), "Mist history independent of Qin")
	for stage: int in [1, 2, 3]:
		s.qin_stage = stage
		check(Objectives.row(s, "qin_rope").destination_site == ["", "mist_rain_gauge", "mist_camp", "mist_guide"][stage], "Qin current-stage destination")
	for stage: int in [1, 2, 3]:
		s.tangqi_stage = stage
		check(Objectives.row(s, "tang_notes").trackable, "Tang not terminal until explicit recruitment")
	s.tangqi_unlocked = true
	check(not Objectives.row(s, "tang_notes").trackable, "Tang recruitment terminates selection")
	for stage: int in range(8):
		s = Fixture.state(stage)
		var cap: Dictionary = Objectives.row(s, "capstone")
		check(not cap.is_empty(), "earned capstone row stage" + str(stage))
		check(cap.trackable == (stage < 7), "capstone6 still pending;7 terminal")
		if stage < 2: check(not cap.earned_history.contains("承认作者"), "no author before stage2")
		if stage < 3: check(not cap.earned_history.contains("梁缜"), "no responsibility before stage3")
		if stage == 4: check(not cap.earned_history.contains("001复用"), "no classification before stage5")
		if stage < 7: check(not cap.earned_history.contains("160阅历") and not cap.earned_history.contains("80铜钱"), "no numeric terminal reward before stage7")
		var automatic: Dictionary = Objectives.automatic(s)
		check(automatic.id == "capstone" if stage < 7 else automatic.kind == "exploration", "capstone auto precedence/completed fallback")
		if stage == 7: check(automatic.destination_site == "heting_dispatch", "capstone7 retains local Heting landmark")
	s = Fixture.state(0); s.consignee_stage = 0; s.consignee_observations.clear(); s.consignee_draft = ""; s.consignee_cargo_location = ""; s.consignee_ending = ""
	for stage: int in range(4):
		s.receipt_stage = stage
		check(Objectives.row(s, "heting_receipt").trackable == (stage < 3), "receipt terminal only after comparison")
		if stage == 2: check(not Objectives.row(s, "heting_receipt").earned_history.contains("副签已核"), "receipt2 no proven conclusion")
	for stage: int in range(6):
		s.consignee_stage = stage
		if stage > 0: s.consignee_cargo_location = "warehouse"
		if stage >= 2: s.consignee_observations.assign(State.Consignee.OBSERVATIONS)
		if stage >= 3: s.consignee_draft = "return_to_owner"
		if stage == 4: s.consignee_cargo_location = "cart"
		if stage == 5: s.consignee_cargo_location = "grain_boat"; s.consignee_ending = "return_to_owner"
		check(Objectives.row(s, "heting_consignee").trackable == (stage < 5), "consignee victory/cart not completed")
		check(not Objectives.row(s, "heting_delivery").earned_history.contains("未损先收"), "harbor local history does not delegate combined helper")
	var before: Dictionary = s.to_dict().duplicate(true)
	var rows: Array[Dictionary] = Objectives.catalog(s)
	rows[0].earned_history = "changed"; rows.clear()
	check(s.to_dict() == before, "catalog detached/nonmutating")

func _routes() -> void:
	var s = _mist(); s.bridge_repaired = true; s.begin_tangqi_quest(); s.begin_qin_quest()
	for map: String in Guidance.MAPS:
		s.map_id = map
		var context: Dictionary = _context(s)
		var before: Dictionary = s.to_dict().duplicate(true)
		var marker_before: Dictionary = context.markers.duplicate(true)
		var qin: Dictionary = Guidance.resolve(s, "qin_rope", context)
		check(qin.mode == "manual" and qin.arc_id == "qin_rope" and qin.destination_map == "mistwood", "Qin retained across map " + map)
		check(qin.next_target_id == {"qingwei":"exit_sluice", "sluice":"exit_frostbridge", "frostbridge":"exit_mistwood", "mistwood":"mist_rain_gauge", "heting":"return_mistwood"}[map], "Qin adjacent/local target " + map)
		var tang: Dictionary = Guidance.resolve(s, "tang_notes", context)
		check(tang.destination_map == "sluice" and tang.destination_site == "sluice_cache", "Tang final destination independent of map")
		check(tang.next_target_id == {"qingwei":"exit_sluice", "sluice":"sluice_cache", "frostbridge":"return_sluice", "mistwood":"return_frostbridge", "heting":"return_mistwood"}[map], "Tang legal next step " + map)
		check(s.to_dict() == before and context.markers == marker_before, "projection preserves state and marker dictionary")
		qin.cart_route.append(Vector2.ONE); qin.next_action = "changed"
		check(Guidance.resolve(s, "qin_rope", context).next_action != "changed", "fresh detached result")
	for stage: int in range(7):
		s = Fixture.state(stage)
		for map: String in Guidance.MAPS:
			s.map_id = map
			var view: Dictionary = Guidance.resolve(s, "capstone", _context(s))
			check(view.valid_tracked_arc_id == "capstone" and not view.next_target_id.is_empty(), "capstone earned five-map goal stage%d/%s" % [stage, map])
			check(world.interactables.has(view.next_target_id), "capstone actual marker exists")
	s = _mist(); s.qin_stage = 1; s.map_id = "qingwei"
	var island: Dictionary = _context(s, Lightness.LANDING)
	var view: Dictionary = Guidance.resolve(s, "qin_rope", island)
	check(view.next_target_id == "reed_return" and view.route_status == "via_crossing", "unlearned islet recovery before off-map Qin")
	s.sect_trial_won = true; s.sect_rank = 1
	check(Guidance.resolve(s, "mentor_reward", island).next_target_id == "reed_return", "same-map mainland objective returns from islet")
	s.lightness_unlocked = true
	check(Guidance.resolve(s, "lightness_islet", island).next_target_id == "reed_relic", "islet relic objective local")
	check(Guidance.resolve(s, "lightness_islet", _context(s, Vector2(500, 500))).next_target_id == "reed_cross", "shore relic objective first crosses")
	var context: Dictionary = _context(s)
	context.map_id = "mistwood"
	view = Guidance.resolve(s, "qin_rope", context)
	check(view.next_target_id.is_empty() and view.valid_tracked_arc_id == "qin_rope", "state/world map mismatch unavailable without lost identity")
	context = _context(s); context.player_position = Vector2(NAN, 1)
	check(Guidance.resolve(s, "qin_rope", context).next_target_id.is_empty(), "nonfinite live position safe")
	context = _context(s); context.markers.exit_sluice.pos = Vector2(INF, 3)
	check(Guidance.resolve(s, "qin_rope", context).next_target_id.is_empty(), "nonfinite marker safe")
	context = _context(s); context.markers.erase("exit_sluice")
	check(Guidance.resolve(s, "qin_rope", context).next_target_id.is_empty(), "missing marker safe")
	context = _context(s); s.quest_stage = 5
	check(Guidance.resolve(s, "qin_rope", context).next_target_id.is_empty(), "inconsistent forward gate cannot route")
	s = _mist(); s.qin_stage = 1; s.map_id = "frostbridge"; s.bridge_repaired = false
	check(Guidance.resolve(s, "qin_rope", _context(s)).next_target_id == "exit_mistwood", "south bridge is optional, not Mist travel gate")

func _cart_routes() -> void:
	for plan: String in ["short_ferries", "open_scale"]:
		for bridge: String in ["west", "east"]:
			for cargo: String in ["meal", "sealed", "reserve"]:
				var s = _mist(); s.map_id = "heting"; s.heting_stage = 3 if cargo == "reserve" else 1; s.heting_bridge = bridge; s.heting_cargo = cargo; s.heting_draft = plan; s.qin_stage = 1
				var context: Dictionary = _context(s, Vector2(820, 665))
				for id: String in ["heting_delivery", "qin_rope"]:
					var before: Dictionary = s.to_dict().duplicate(true)
					var view: Dictionary = Guidance.resolve(s, id, context)
					check(not view.cart_route.is_empty(), "old cart route resolved " + cargo + "/" + bridge + "/" + id)
					for i: int in range(1, view.cart_route.size()): check(Region.can_step(view.cart_route[i-1], view.cart_route[i], bridge, true), "cart segment obeys loaded collision")
					if id == "qin_rope": check(view.route_status == "departure_confirmation" and view.next_target_id == "return_mistwood", "loaded departure discloses explicit parking")
					check(s.to_dict() == before, "guidance never parks old cargo")
	for plan: String in State.Consignee.PLANS:
		for bridge: String in ["west", "east"]:
			var s = Fixture.state(0); s.consignee_stage = 4; s.consignee_ending = ""; s.consignee_cargo_location = "cart"; s.consignee_draft = plan; s.heting_bridge = bridge; s.qin_stage = 1
			var context: Dictionary = _context(s, Vector2(820, 665))
			var before: Dictionary = s.to_dict().duplicate(true)
			var view: Dictionary = Guidance.resolve(s, "heting_consignee", context)
			check(view.next_target_id == ("heting_scale" if plan == "hold_for_inspection" else "heting_cargo"), "receiver physical boat alias")
			check(not view.cart_route.is_empty(), "new cart route resolves both plans/pontoons")
			view = Guidance.resolve(s, "qin_rope", context)
			check(view.route_status == "departure_confirmation" and view.route_note.contains("北仓"), "new cart departure confirmation")
			check(s.to_dict() == before, "guidance never parks new cargo")
			context.player_position = Vector2(805, 500)
			check(Guidance.resolve(s, "qin_rope", context).next_target_id.is_empty(), "loaded foot-only pier cannot produce optimistic route")

func _lifetime() -> void:
	var s = _mist(); s.qin_stage = 1
	var session = Session.new(); session.reset(s)
	var old: Dictionary = session.token(s)
	check(session.track(s, "qin_rope", old), "explicit track succeeds")
	check(not session.track(s, "south_bridge", old), "older epoch cannot replace tracked choice")
	var context: Dictionary = _context(s)
	check(session.refresh(s, context).arc_id == "qin_rope", "session projects selected arc")
	check(not session.track(s, "qin_rope", session.token(s)), "repeated Track no-op")
	old = session.token(s); session.invalidate_callbacks()
	check(not session.restore_auto(s, old), "close/rebuild invalidates stale Auto")
	old = session.token(s); s.map_id = "qingwei"
	check(not session.restore_auto(s, old), "travel invalidates stale callback before refresh")
	session.refresh(s, _context(s)); s.map_id = "mistwood"; session.refresh(s, _context(s))
	check(not session.restore_auto(s, old), "A-B-A travel cannot revive callback")
	check(session.tracked_arc_id == "qin_rope", "map travel retains earned selection")
	s.battle_active = true
	check(session.refresh(s, _context(s)).valid_tracked_arc_id == "qin_rope", "battle preserves selection")
	check(not session.restore_auto(s, session.token(s)), "battle rejects action callbacks")
	s.battle_active = false; s.qin_stage = 2
	check(session.refresh(s, _context(s)).next_target_id == "mist_camp", "same arc follows normal step transition")
	var before: Dictionary = s.to_dict().duplicate(true)
	var tracked: String = session.tracked_arc_id
	check(s.load_game("user://missing-invalid-slot.json") != OK, "failed load fixture actually fails")
	check(session.tracked_arc_id == tracked and s.to_dict() == before, "failed load retains state/session")
	old = session.token(s); s.qin_stage = 4; s.qin_unlocked = true
	check(not session.track(s, "qin_rope", old), "completion between focus and callback rejected")
	var result: Dictionary = session.refresh(s, _context(s))
	check(result.selection_changed and result.reset_reason == "completed" and session.tracked_arc_id.is_empty(), "completion restores auto once")
	check(not session.refresh(s, _context(s)).selection_changed, "completion notice not repeated")
	s = _mist(); s.qin_stage = 1; session.reset(s); session.track(s, "qin_rope", session.token(s))
	old = session.token(s); session.reset(s)
	check(session.tracked_arc_id.is_empty() and not session.track(s, "qin_rope", old), "same-object successful load/new explicit reset invalidates token")
	session.track(s, "qin_rope", session.token(s)); old = session.token(s)
	var another = _mist(); another.qin_stage = 1
	check(not session.track(another, "qin_rope", old), "replacement identity stale callback rejected")
	result = session.refresh(another, _context(another))
	check(session.tracked_arc_id.is_empty() and result.selection_changed, "replacement refresh restores auto")
	check(not another.to_dict().has("tracked_arc_id") and State.SAVE_VERSION == 16, "selection absent from unchanged save schema")
