extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/heting_rules.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const ROOT = "user://heting-rules"
const PATH = ROOT + "/fixture.json"
var checks: int = 0
var failures: int = 0
var snapshots: Array[Dictionary] = []


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func ready_state(mist: String = "release_water", sect: String = "听潮阁", party: String = "", frost: String = "protect_witness"):
	var s = State.new()
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect(sect)
	s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = frost
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_gauges.assign(s.Mist.GAUGES); s.mist_approach = "duel"; s.mist_ending = mist
	s.map_id = "mistwood"; s.position = Vector2(1440, 505)
	if party == "沈青": s.companion_unlocked = true
	if party == "唐栖":
		s.bridge_repaired = true; s.tangqi_stage = 3; s.tangqi_choice = "preserve"; s.tangqi_unlocked = true
	s.active_companion = party
	# Normalize the prepared legacy ownership/selection before current XP/save APIs.
	s._apply_party_plan(s.PartyRoster.load_plan(s, {"active_companion": party}, 11))
	return s


func entered(mist: String = "release_water"):
	var s = ready_state(mist)
	check(s.begin_heting(), "Eligible chapter begins")
	s.map_id = "heting"; s.position = Vector2(820, 665)
	return s


func receiver(id: String) -> String:
	return Rules.RELIEF if id in ["meal", "short_ferries"] else Rules.SCALE


func earned_xp(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)


func deliver(s, id: String) -> void:
	check(s.take_heting_cargo(id), "Take base cargo " + id)
	check(s.deliver_heting_base(receiver(id)), "Deliver base cargo " + id)


func drafted(plan: String = "short_ferries"):
	var s = entered()
	deliver(s, "meal"); deliver(s, "sealed")
	check(s.choose_heting_plan(plan), "Draft selected")
	return s


func rejected(s, action: Callable, label: String) -> void:
	var before = s.to_dict()
	var battle = [s.battle_active, s.enemy_hp, s.turn, s.focused_damage, s.skill_cooldown]
	check(not action.call(), label + " rejects")
	check(s.to_dict() == before and battle == [s.battle_active, s.enemy_hp, s.turn, s.focused_damage, s.skill_cooldown], label + " preserves all state")


func write_document(data: Dictionary, version: int = State.SAVE_VERSION, path: String = PATH) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": version, "player": data})); f.close()


func test_routes() -> void:
	var route_count: int = 0
	for sect in State.SECTS:
		for mist in Rules.MIST_ENDINGS:
			for frost in ["open_records", "protect_witness"]:
				for party in ["", "沈青", "唐栖"]:
					for first in Rules.BASE_CARGO:
						for plan in Rules.PLANS:
							var s = ready_state(mist, sect, party, frost)
							# The chapter is possible with no cash, healing, materials, or lightness.
							s.coins = 0; s.medicine = 0; s.hp = 1; s.qi = 0
							var before = s.to_dict()
							check(s.begin_heting() and s.heting_stage == 1, "Route starts")
							check(s.heting_bridge == ("east" if mist == "release_water" else "west"), "Prior choice sets only initial bridge")
							check(s.hp == 1 and s.qi == 0 and earned_xp(s) == 0 and s.coins == 0, "Beginning grants nothing")
							s.map_id = "heting"; s.position = Vector2(820, 665)
							deliver(s, first)
							check(s.heting_stage == 1 and s.heting_delivered == [first] and earned_xp(s) == 10, "First exact ten XP preserves delivery order")
							var second: String = "sealed" if first == "meal" else "meal"
							check(s.available_heting_cargo(Rules.MAIN_SOURCE) == [second], "Only remaining base batch is available")
							deliver(s, second)
							check(s.heting_stage == 2 and earned_xp(s) == 20, "Second exact ten XP opens discussion")
							check(s.choose_heting_plan(plan) and s.take_heting_cargo("reserve"), "Both final plans are reachable")
							check(s.finish_heting_delivery(receiver(plan), plan), "Matching receiver and current draft finish")
							check(s.heting_stage == 4 and s.heting_ending == plan and s.heting_draft == plan and s.heting_delivered == [first, second, "reserve"] and s.heting_cargo.is_empty(), "Final finite state is exact")
							check(earned_xp(s) == 120 and s.coins == 60 and s.level == 2 and s.xp == 60, "Exact total rewards include natural level-up")
							check(s.hp == s.max_hp and s.qi == s.max_qi, "Normal XP level-up restores HP and Qi")
							for key in ["mist_ending", "chapter_two_ending", "sect", "resources", "medicine", "lightness_unlocked", "art_uses", "active_companion", "tangqi_choice"]:
								check(s.to_dict()[key] == before[key], "Route preserves unrelated state: " + key)
							check(State.new()._valid_save_data(s.to_dict()), "Completed route is valid schema")
							route_count += 1
	check(route_count == 144, "All sect/old endings/order/new ending/party combinations covered")


func test_gates_and_reversibility() -> void:
	for stage in range(4):
		var gated = ready_state(); gated.mist_stage = stage
		rejected(gated, func(): return gated.begin_heting(), "Prior stage " + str(stage))
	for ending in ["", "unknown", "open_records"]:
		var gated = ready_state(ending)
		rejected(gated, func(): return gated.begin_heting(), "Invalid prior ending " + ending)
	var fresh = State.new()
	rejected(fresh, func(): return fresh.begin_heting(), "Fresh story gate")
	var s = entered()
	rejected(s, func(): return s.begin_heting(), "Repeated begin")
	check(s.available_heting_cargo(Rules.MAIN_SOURCE) == ["meal", "sealed"], "Both base batches initially available")
	var offered = s.available_heting_cargo(Rules.MAIN_SOURCE); offered.clear()
	check(s.available_heting_cargo(Rules.MAIN_SOURCE).size() == 2, "Availability is a detached read-only result")
	check(s.available_heting_cargo("unknown").is_empty() and s.available_heting_cargo(Rules.RESERVE_SOURCE).is_empty(), "Source and stage filter availability")
	for id in ["reserve", "unknown", ""]:
		rejected(s, func(): return s.take_heting_cargo(id), "Wrong-stage or unknown batch " + id)
	rejected(s, func(): return s.choose_heting_plan("short_ferries"), "Premature draft")
	rejected(s, func(): return s.park_heting_cargo(), "Empty cart parking")
	rejected(s, func(): return s.deliver_heting_base(Rules.RELIEF), "Empty base delivery")
	rejected(s, func(): return s.finish_heting_delivery(Rules.RELIEF, "short_ferries"), "Premature finale")
	rejected(s, func(): return s.set_heting_bridge("north"), "Unknown bridge")
	rejected(s, func(): return s.set_heting_bridge(s.heting_bridge), "Identical bridge")
	check(s.take_heting_cargo("sealed"), "Load sealed first")
	check(s.available_heting_cargo(Rules.MAIN_SOURCE).is_empty(), "Loaded cart cannot claim another batch")
	for id in ["sealed", "meal", "reserve"]:
		rejected(s, func(): return s.take_heting_cargo(id), "Duplicate loaded take " + id)
	rejected(s, func(): return s.deliver_heting_base(Rules.RELIEF), "Wrong base receiver")
	var before = s.to_dict(); before.heting_bridge = "west"
	check(s.set_heting_bridge("west") and s.to_dict() == before, "Loaded bridge change touches bridge only")
	before = s.to_dict(); before.heting_cargo = ""
	check(s.park_heting_cargo() and s.to_dict() == before, "Parking returns intact batch with no reward")
	rejected(s, func(): return s.park_heting_cargo(), "Repeated parking")
	deliver(s, "sealed")
	rejected(s, func(): return s.take_heting_cargo("sealed"), "Delivered base cannot be reloaded")
	rejected(s, func(): return s.deliver_heting_base(Rules.SCALE), "Repeated base delivery")
	deliver(s, "meal")
	rejected(s, func(): return s.take_heting_cargo("reserve"), "Reserve requires an actual draft")
	rejected(s, func(): return s.choose_heting_plan("unknown"), "Unknown plan")
	check(s.choose_heting_plan("short_ferries"), "Select reversible draft")
	rejected(s, func(): return s.choose_heting_plan("short_ferries"), "Identical draft")
	rejected(s, func(): return s.finish_heting_delivery(Rules.RELIEF, "short_ferries"), "Final delivery needs actual reserve cargo")
	check(s.available_heting_cargo(Rules.RESERVE_SOURCE) == ["reserve"] and s.available_heting_cargo(Rules.MAIN_SOURCE).is_empty(), "Final source exclusively offers reserve")
	check(s.take_heting_cargo("reserve"), "Load final cart")
	before = s.to_dict(); before.heting_draft = "open_scale"
	check(s.choose_heting_plan("open_scale") and s.to_dict() == before, "Changing plan while loaded touches only draft")
	rejected(s, func(): return s.finish_heting_delivery(Rules.RELIEF, "short_ferries"), "Stale confirmation cannot finish prior plan")
	rejected(s, func(): return s.finish_heting_delivery(Rules.RELIEF, "open_scale"), "Current draft cannot finish at wrong receiver")
	rejected(s, func(): return s.finish_heting_delivery(Rules.SCALE, "unknown"), "Unknown expected plan")
	before = s.to_dict()
	# Cancelling UI does not call a mutator; getters/serialization never commit.
	s.available_heting_cargo(Rules.RESERVE_SOURCE); Rules.can_begin(s); s.to_dict()
	check(s.to_dict() == before, "Inspection and cancelled confirmation preserve loaded draft")
	check(s.park_heting_cargo() and s.heting_draft == "open_scale" and s.available_heting_cargo(Rules.RESERVE_SOURCE) == ["reserve"], "Final parking keeps draft and returns exactly one reserve batch")
	check(s.take_heting_cargo("reserve") and s.choose_heting_plan("short_ferries") and s.choose_heting_plan("open_scale"), "Retry and repeated revision remain possible")
	check(s.finish_heting_delivery(Rules.SCALE, "open_scale"), "Revised final cart delivers once")
	before = s.to_dict()
	for id in Rules.CARGO:
		rejected(s, func(): return s.take_heting_cargo(id), "Completed cargo remains finite " + id)
	rejected(s, func(): return s.finish_heting_delivery(Rules.SCALE, "open_scale"), "Completed reward is deduplicated")
	rejected(s, func(): return s.choose_heting_plan("short_ferries"), "Completed ending is locked")
	rejected(s, func(): return s.deliver_heting_base(Rules.RELIEF), "Completed base reward is deduplicated")
	before.heting_bridge = "east"
	check(s.set_heting_bridge("east") and s.to_dict() == before, "Post-completion bridge remains usable without other changes")
	s.reset_game()
	check(s.heting_stage == 0 and s.heting_bridge.is_empty() and s.heting_delivered.is_empty() and s.heting_cargo.is_empty() and s.heting_draft.is_empty() and s.heting_ending.is_empty(), "Reset clears all six fields")


func all_actions(s) -> Array[Callable]:
	return [func(): return s.begin_heting(), func(): return s.set_heting_bridge("west" if s.heting_bridge == "east" else "east"),
		func(): return s.take_heting_cargo("meal"), func(): return s.take_heting_cargo("sealed"), func(): return s.take_heting_cargo("reserve"),
		func(): return s.park_heting_cargo(), func(): return s.deliver_heting_base(Rules.RELIEF), func(): return s.deliver_heting_base(Rules.SCALE),
		func(): return s.choose_heting_plan("short_ferries"), func(): return s.choose_heting_plan("open_scale"),
		func(): return s.finish_heting_delivery(Rules.RELIEF, "short_ferries"), func(): return s.finish_heting_delivery(Rules.SCALE, "open_scale")]


func snapshot(s) -> void:
	check(State.new()._valid_save_data(s.to_dict()), "Reachable state passes full validation")
	snapshots.append(s.to_dict())


func collect_snapshots() -> void:
	snapshot(ready_state())
	for bridge in Rules.BRIDGES:
		var empty = entered(); empty.set_heting_bridge(bridge); snapshot(empty)
		for first in Rules.BASE_CARGO:
			var s = entered(); s.set_heting_bridge(bridge)
			s.take_heting_cargo(first); snapshot(s)
			s.deliver_heting_base(receiver(first)); snapshot(s)
			var second: String = "sealed" if first == "meal" else "meal"
			s.take_heting_cargo(second); snapshot(s)
			s.deliver_heting_base(receiver(second)); snapshot(s)
			for plan in Rules.PLANS:
				var fork = State.new(); write_document(s.to_dict()); check(fork.load_game(PATH) == OK, "Fork stage two")
				fork.choose_heting_plan(plan); snapshot(fork)
				fork.take_heting_cargo("reserve"); snapshot(fork)
				fork.finish_heting_delivery(receiver(plan), plan); snapshot(fork)
	check(snapshots.size() == 43, "Every valid stage/bridge/order/cargo/draft combination covered")


func test_context_gates_and_saves() -> void:
	var slots = Slots.new(ROOT)
	for data in snapshots:
		var s = State.new(); write_document(data)
		check(s.load_game(PATH) == OK and s.to_dict() == data, "Fixture restore is exact and grants no reward")
		check(s.save_game(slots.path_for(0)) == OK, "Autosave writes current state")
		var auto_bytes = FileAccess.get_file_as_bytes(slots.path_for(0))
		var copied = State.new()
		check(slots.load_slot(copied, 0) == OK and copied.to_dict() == data, "Autosave restores stage, order, cart, draft, bridge and position")
		for slot in range(1, 4):
			var previous = State.new()
			var had_previous: bool = previous.load_game(slots.path_for(slot)) == OK
			check(slots.save_slot(s, slot) == OK and slots.describe(slot).status == "valid", "Manual slot accepts each valid state")
			check(slots.load_slot(copied, slot) == OK and copied.to_dict() == data, "Every manual slot round-trips without rewards")
			check(slots.describe(slot).location == s.map_id, "Manual save description retains real region")
			if had_previous:
				check(slots.load_backup(copied, slot) == OK and copied.to_dict() == previous.to_dict(), "Backup restores exact prior cargo/draft/order")
		check(FileAccess.get_file_as_bytes(slots.path_for(0)) == auto_bytes, "Manual reads and writes do not overwrite autosave")
		var before = s.to_dict()
		s.battle_active = true; s.enemy_hp = 78; s.turn = 3; s.focused_damage = 17
		for action in all_actions(s): rejected(s, action, "Every mutation is blocked in battle")
		s.available_heting_cargo(Rules.MAIN_SOURCE); s.available_heting_cargo(Rules.RESERVE_SOURCE)
		check(s.to_dict() == before, "Battle getters stay read-only")
		s.battle_active = false
		if s.heting_stage > 0:
			s.map_id = "mistwood"
			for action in all_actions(s): rejected(s, action, "Port tasks cannot be invoked remotely")
			if s.heting_cargo.is_empty():
				write_document(s.to_dict()); check(copied.load_game(PATH) == OK and copied.map_id == "mistwood", "Unloaded chapter may travel and reload elsewhere")
			else:
				check(not Rules.valid(s.to_dict(), 9), "Loaded cart cannot be saved on another map")


func invalid_load(data: Dictionary, label: String, version: int = State.SAVE_VERSION) -> void:
	var live = drafted("open_scale"); live.take_heting_cargo("reserve")
	live.battle_active = true; live.enemy_hp = 45; live.turn = 8; live.focused_damage = 29
	var original = live.to_dict()
	var autosave = ROOT + "/hero_save.json"
	var auto_bytes = FileAccess.get_file_as_bytes(autosave)
	write_document(data, version)
	check(live.load_game(PATH) == ERR_FILE_CORRUPT, label + " is rejected")
	check(live.to_dict() == original and live.battle_active and live.enemy_hp == 45 and live.turn == 8 and live.focused_damage == 29, label + " does not reset live progress or battle")
	check(FileAccess.get_file_as_bytes(autosave) == auto_bytes, label + " does not overwrite autosave")


func test_invalid_and_legacy() -> void:
	var base = drafted(); base.take_heting_cargo("reserve")
	for key in Rules.FIELDS:
		var missing = base.to_dict(); missing.erase(key)
		invalid_load(missing, "Required field " + key)
	for bad in [-1, 5, 1.5, 4.8, 1e99, "3", true, null, [], {}]:
		var data = base.to_dict(); data.heting_stage = bad
		invalid_load(data, "Bad stage " + str(bad))
	for key in ["heting_bridge", "heting_cargo", "heting_draft", "heting_ending"]:
		for bad in [0, true, null, [], {}, "unknown"]:
			var data = base.to_dict(); data[key] = bad
			invalid_load(data, "Malformed field " + key + ": " + str(bad))
	for bad in [null, {}, "meal", [1], [true], [null], ["unknown"], ["meal", "meal"], ["reserve", "meal", "sealed"], ["meal", "reserve", "sealed"], ["meal", "sealed", "reserve", "meal"]]:
		var data = base.to_dict(); data.heting_delivered = bad
		invalid_load(data, "Malformed delivery list " + str(bad))
	for change in [
		{"heting_stage": 0}, {"heting_stage": 1}, {"heting_stage": 2}, {"heting_stage": 4},
		{"heting_bridge": ""}, {"heting_draft": ""}, {"heting_ending": "short_ferries"},
		{"heting_cargo": "meal"}, {"heting_delivered": ["meal"]}, {"heting_delivered": ["meal", "sealed", "reserve"]},
		{"mist_stage": 3}, {"mist_stage": 4.8}, {"mist_stage": 5}, {"mist_stage": "4"}, {"mist_ending": "unknown"},
		{"map_id": "mistwood"}, {"map_id": "qingwei"}, {"map_id": "unknown"}]:
		var data = base.to_dict(); data.merge(change, true)
		invalid_load(data, "Impossible loaded stage: " + str(change))
	for stage in [0, 1, 2]:
		var s = ready_state() if stage == 0 else entered()
		if stage == 2: deliver(s, "meal"); deliver(s, "sealed")
		for change in [{"heting_cargo": "reserve"}, {"heting_draft": "short_ferries"}, {"heting_ending": "open_scale"}]:
			var data = s.to_dict(); data.merge(change, true)
			invalid_load(data, "Premature cargo/plan/ending at stage " + str(stage))
	var final_state = drafted("open_scale"); final_state.take_heting_cargo("reserve"); final_state.finish_heting_delivery(Rules.SCALE, "open_scale")
	for change in [{"heting_draft": "short_ferries"}, {"heting_ending": ""}, {"heting_cargo": "reserve"}, {"heting_delivered": ["meal", "sealed"]}]:
		var data = final_state.to_dict(); data.merge(change, true)
		invalid_load(data, "Impossible final state " + str(change))
	for bad in [INF, -INF, NAN]:
		var data = base.to_dict(); data.heting_stage = bad
		check(not Rules.valid(data, 9) and not State.new()._valid_save_data(data), "Nonfinite stage rejected before JSON serialization")
	for version in range(1, 9):
		var old = ready_state().to_dict()
		for key in Rules.FIELDS: old.erase(key)
		write_document(old, version)
		var migrated = State.new()
		check(migrated.load_game(PATH) == OK and migrated.heting_stage == 0 and migrated.heting_bridge.is_empty() and migrated.heting_delivered.is_empty() and migrated.heting_cargo.is_empty() and migrated.heting_draft.is_empty() and migrated.heting_ending.is_empty(), "Legacy version loads without invented chapter: " + str(version))
		var unchanged = migrated.to_dict()
		for key in Rules.FIELDS: unchanged.erase(key)
		check(unchanged == old, "Legacy migration has no reward or unrelated mutations")
		old.map_id = "heting"
		invalid_load(old, "Legacy unknown port cannot silently fall back", version)
		write_document(final_state.to_dict(), version)
		check(migrated.load_game(PATH) == OK and migrated.to_dict() == final_state.to_dict(), "Legacy complete new-field bundle is validated and preserved")
		for key in Rules.FIELDS:
			var partial = final_state.to_dict(); partial.erase(key)
			invalid_load(partial, "Legacy partial field bundle " + key, version)
		var forged = final_state.to_dict(); forged.heting_delivered = ["reserve", "sealed", "meal"]
		invalid_load(forged, "Legacy inconsistent new-field bundle", version)
	# An actual version-one-shaped payload omits every later system, not just Heting.
	var original = State.new().to_dict()
	for key in original.keys():
		if key not in ["player_name", "level", "xp", "coins", "hp", "max_hp", "qi", "max_qi", "attack", "defense", "medicine", "herbs", "quest_stage", "sect", "ending", "position", "victories"]: original.erase(key)
	write_document(original, 1)
	var oldest = State.new()
	check(oldest.load_game(PATH) == OK and oldest.heting_stage == 0 and oldest.map_id == "qingwei", "Literal original save still loads")
	write_document(final_state.to_dict(), State.SAVE_VERSION+1)
	check(oldest.load_game(PATH) == ERR_FILE_UNRECOGNIZED, "Future schema remains incompatible")
	check(State.SAVE_VERSION >= 10, "Playable harbor requires a save schema beyond older executables")


func test_caps_and_restore() -> void:
	var s = entered()
	s.level = 99; s.xp = s.xp_to_next() - 5; s.coins = 999990; s.hp = 7; s.qi = 0
	deliver(s, "meal"); deliver(s, "sealed")
	s.choose_heting_plan("short_ferries"); s.take_heting_cargo("reserve")
	check(s.finish_heting_delivery(Rules.RELIEF, "short_ferries") and s.coins == 999999 and s.xp == s.xp_to_next() - 1 and s.level == 99, "Coin/XP/level caps preserved")
	check(s.hp == 7 and s.qi == 0, "Capped reward never fabricates a level-up heal")
	write_document(s.to_dict())
	var copy = State.new()
	check(copy.load_game(PATH) == OK and copy.to_dict() == s.to_dict(), "Capped completion loads without rewards or healing")
	rejected(copy, func(): return copy.finish_heting_delivery(Rules.RELIEF, "short_ferries"), "Loaded completion cannot reward again")
	var exported = s.to_dict(); exported.heting_delivered.clear()
	check(s.heting_delivered.size() == 3, "Serialization returns independent delivery list")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	# Reset only this test's own files so assertion counts and backup fixtures are repeatable.
	var slots = Slots.new(ROOT)
	for slot in range(4):
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = slots.path_for(slot) + suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	test_routes()
	test_gates_and_reversibility()
	collect_snapshots()
	test_context_gates_and_saves()
	test_invalid_and_legacy()
	test_caps_and_restore()
	if failures == 0: print("PASS: %d Heting finite-cargo rules/save checks; 144 routes and 43 reachable save states" % checks)
	else: push_error("FAIL: %d of %d Heting checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
