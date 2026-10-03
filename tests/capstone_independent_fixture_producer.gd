extends SceneTree
## Portable independent fixtures. Synthetic mechanics, never earned gameplay.
## Static factory methods do not run _init; CLI invocation produces a genuine
## pinned genuine15 default document for the separate-process old14 pack probe.
const State = preload("res://scripts/game_state.gd")
const Frozen15 = preload("res://tests/weapon_fitting_fixture_producer.gd")
const OLD_PATH = "res://tests/fixtures/v028_game_state.gd.txt"
const OLD_SHA = "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5"
static func old_reader() -> GDScript:
	var raw := FileAccess.get_file_as_bytes(OLD_PATH)
	if raw.size() != 72931 or FileAccess.get_sha256(OLD_PATH) != OLD_SHA: return null
	var script := GDScript.new()
	script.source_code = raw.get_string_from_utf8().replace("class_name HeroState\n", "")
	if script.reload() != OK: return null
	return script
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		push_error("Pass exactly one absolute, unused isolated fixture output path."); quit(2); return
	var path: String = args[0]
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path + ".tmp") or DirAccess.dir_exists_absolute(path + ".tmp"):
		push_error("Fixture output or staging path already exists; refusing overwrite."); quit(2); return
	var producer := Frozen15.old_reader()
	if producer == null: quit(1); return
	var current = producer.new()
	if current.SAVE_VERSION != 15 or current.save_game(path) != OK:
		push_error("Could not write pinned15 fixture."); quit(1); return
	print("PASS: actual pinned15 source/current-dependency producer wrote isolated old-reader subject ", path)
	quit(0)

static func apply_progress(s, plan: String = "hold_for_inspection", stage: int = 5) -> Array[bool]:
	var checks: Array[bool] = []
	s.quest_stage = 6; s.ending = "守望"; s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"; s.bridge_repaired = true
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_ending = "release_water"; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"])
	s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal", "sealed", "reserve"])
	s.heting_draft = "short_ferries"; s.heting_ending = "short_ferries"; s.map_id = "heting"
	checks.append(s.recruit_companion())
	checks.append(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("preserve") and s.recruit_tangqi())
	s.map_id = "mistwood"
	checks.append(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin())
	s.map_id = "heting"; s.hp = 47; s.qi = 0; s.medicine = 1; s.coins = 251
	s.party_roster.assign(["hero", "shen", "qin"])
	s.party_resources.shen = {"hp": 0, "qi": 0}
	s.party_resources.tang = {"hp": 1, "qi": 1}
	s.party_resources.qin = {"hp": 2, "qi": 0}
	s.consignee_stage = stage
	if stage >= 1: s.consignee_cargo_location = "warehouse"
	if stage >= 2:
		s.consignee_observations.assign(["southern_counterfoil", "lot_seals", "removal_order"])
		s.consignee_draft = plan
	if stage == 4: s.consignee_cargo_location = "cart"
	if stage == 5:
		s.consignee_ending = plan
		s.consignee_cargo_location = "public_scale" if plan == "hold_for_inspection" else "grain_boat"
	return checks
