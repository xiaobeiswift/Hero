extends SceneTree
## Run: godot --headless --path . --script tests/state_test.gd

const State = preload("res://scripts/game_state.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const TEST_SAVE: String = "user://hero_state_test.json"
const BAD_SAVE: String = "user://hero_state_bad_test.json"
var failures: int = 0
var checks: int = 0


func _init() -> void:
	_test_defaults_and_reset()
	_test_leveling_and_recovery()
	_test_sects()
	_test_save_roundtrip()
	_test_corrupt_and_bounded_load()
	_test_invalid_actions()
	_test_qi_cooldowns_and_guard()
	_test_victory_defeat_and_flee()
	_test_companion_and_equipment()
	_test_expanded_save_compatibility()
	_test_side_quest_routes()
	_test_side_save_coherence()
	_test_sluice_encounters()
	_test_martial_catalog_and_equipping()
	_test_sect_martial_effects()
	_test_art_proficiency()
	_test_martial_saves()
	for path: String in [TEST_SAVE, BAD_SAVE, TEST_SAVE + ".tmp", BAD_SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures == 0:
		print("PASS: %d HeroState checks" % checks)
	else:
		push_error("FAIL: %d of %d HeroState checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _test_defaults_and_reset() -> void:
	var state = State.new()
	_check(state.hp == 100 and state.qi == 2 and state.coins == 24, "Initial resources")
	_check(state.level == 1 and state.quest_stage == 0, "Initial progress")
	_check(state.position == Vector2(460, 430), "Initial position")
	state.coins = 999
	state.quest_stage = 6
	state.start_battle()
	state.reset_game()
	_check(state.coins == 24 and state.quest_stage == 0, "Reset persistent state")
	_check(not state.battle_active and state.battle_log.is_empty(), "Reset transient state")
	for stage in range(7):
		state.quest_stage = stage
		_check(not state.quest_title().is_empty() and not state.quest_hint().is_empty(), "Quest stage %d has guidance" % stage)


func _test_leveling_and_recovery() -> void:
	var state = State.new()
	state.hp = 5
	state.qi = 0
	var messages: Array[String] = state.gain_xp(190)
	_check(state.level == 3 and state.xp == 10 and messages.size() == 2, "Multiple level thresholds")
	_check(state.max_hp == 124 and state.attack == 22 and state.defense == 6, "Level stat growth")
	_check(state.hp == state.max_hp and state.qi == state.max_qi, "Level restores resources")
	state.gain_xp(-20)
	_check(state.xp == 10, "Negative XP ignored")
	_check(not state.use_medicine() and state.medicine == 3, "Full-health medicine rejected")
	state.hp = 10
	_check(state.use_medicine() and state.hp == 55 and state.medicine == 2, "Medicine heals and is consumed")
	state.hp = state.max_hp - 2
	state.use_medicine()
	_check(state.hp == state.max_hp, "Healing capped to maximum")
	state.medicine = 0
	state.hp = 1
	_check(not state.use_medicine() and state.hp == 1, "No medicine cannot heal")
	state.qi = 0
	state.skill_cooldown = 2
	state.heal_rest()
	_check(state.hp == state.max_hp and state.qi == state.max_qi and state.skill_cooldown == 0, "Rest restores all resources")


func _test_sects() -> void:
	var tide = State.new()
	tide.choose_sect("unknown")
	_check(tide.sect == "未入门", "Unknown sect ignored")
	tide.choose_sect("听潮阁")
	tide.choose_sect("听潮阁")
	tide.choose_sect("问石门")
	_check(tide.attack == 20 and tide.defense == 4 and tide.sect == "听潮阁", "Sect cannot stack or change")
	var healer = State.new()
	healer.choose_sect("照野堂")
	_check(healer.max_hp == 124 and healer.hp == 124, "Healer sect health bonus")
	healer.hp = 1
	healer.use_medicine()
	_check(healer.hp == 56, "Healer sect medicine bonus")
	var stone = State.new()
	stone.choose_sect("问石门")
	_check(stone.defense == 7, "Stone sect defense bonus")


func _test_save_roundtrip() -> void:
	var original = State.new()
	original.player_name = "青苇客"
	original.gain_xp(75)
	original.choose_sect("听潮阁")
	original.coins = 88
	original.hp = 51
	original.qi = 4
	original.herbs = 1
	original.medicine = 2
	original.quest_stage = 6
	original.ending = "公示账册"
	original.position = Vector2(704.5, 233.25)
	original.victories = 3
	_check(original.save_game(TEST_SAVE) == OK, "Save succeeds")
	_check(FileAccess.file_exists(TEST_SAVE) and not FileAccess.file_exists(TEST_SAVE + ".tmp"), "Atomic save leaves final file only")
	var loaded = State.new()
	loaded.start_battle()
	_check(loaded.load_game(TEST_SAVE) == OK, "Load succeeds")
	_check(loaded.to_dict() == original.to_dict(), "All persistent fields round-trip")
	_check(not loaded.battle_active and loaded.turn == 0, "Transient combat not restored")
	original.coins = 99
	_check(original.save_game(TEST_SAVE) == OK and loaded.load_game(TEST_SAVE) == OK and loaded.coins == 99, "Existing save is replaceable")
	_check(loaded.save_game("") == ERR_INVALID_PARAMETER, "Empty save path rejected")


func _test_corrupt_and_bounded_load() -> void:
	var state = State.new()
	state.coins = 77
	_check(state.load_game("user://hero_missing_state_test.json") == ERR_FILE_NOT_FOUND, "Missing save handled")
	for content: String in ["{truncated", "[]", "{}", '{"version":1,"player":{}}', '{"version":1,"player":{"level":"bad","quest_stage":0}}', '{"version":true,"player":{"level":1,"quest_stage":0}}', '{"version":1,"player":{"level":1,"quest_stage":2}}']:
		_write(BAD_SAVE, content)
		_check(state.load_game(BAD_SAVE) == ERR_FILE_CORRUPT, "Corrupt save rejected: " + content)
		_check(state.coins == 77, "Failed load does not mutate current progress")
	_write(BAD_SAVE, JSON.stringify({"version": 99, "player": state.to_dict()}))
	_check(state.load_game(BAD_SAVE) == ERR_FILE_UNRECOGNIZED, "Unsupported version rejected")
	var extreme: Dictionary = state.to_dict()
	extreme["hp"] = -500
	extreme["max_hp"] = 120
	extreme["qi"] = 9999
	extreme["max_qi"] = 6
	extreme["coins"] = -99
	extreme["medicine"] = 1.0e100
	extreme["level"] = -10
	extreme["xp"] = 900
	extreme["quest_stage"] = 500
	extreme["position"] = {"x": -30, "y": 1.0e30}
	extreme["sect"] = "forged sect"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": extreme}))
	_check(state.load_game(BAD_SAVE) == OK, "Numeric outliers can be loaded safely")
	_check(state.hp == 1 and state.max_hp == 120 and state.qi == 6, "Health and qi clamped")
	_check(state.coins == 0 and state.medicine == 999 and state.level == 1 and state.xp == 59, "Economy and progression clamped without overflow")
	_check(state.quest_stage == 6 and state.position == Vector2(0, 10000), "Quest and position clamped")
	_check(state.sect == "未入门", "Invalid sect sanitized")
	var stranded: Dictionary = state.to_dict()
	stranded["quest_stage"] = 2
	stranded["herbs"] = 0
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": stranded}))
	var before: Dictionary = state.to_dict()
	_check(state.load_game(BAD_SAVE) == ERR_FILE_CORRUPT and state.to_dict() == before, "Missing delivery herb cannot strand the quest on load")


func _test_invalid_actions() -> void:
	var state = State.new()
	_check(not state.battle_action("attack")["valid"], "No combat action outside battle")
	state.start_battle()
	var before: Dictionary = state.to_dict()
	_check(not state.battle_action("skill")["valid"], "Insufficient qi rejected")
	_check(not state.battle_action("item")["valid"], "Full hp item rejected")
	_check(not state.battle_action("bad")["valid"], "Unknown combat action rejected")
	_check(state.turn == 0 and state.enemy_hp == state.enemy_max_hp and state.to_dict() == before, "Invalid actions do not spend turn or resources")
	state.medicine = 0
	state.hp = 80
	_check(not state.battle_action("item")["valid"] and state.turn == 0 and state.hp == 80, "Empty inventory action rejected safely")
	state.start_battle("training")
	_check(state.enemy_name == "蒲横 · 河帮执事" and state.hp == 80, "Cannot reset an active encounter")


func _test_qi_cooldowns_and_guard() -> void:
	var state = State.new()
	state.start_battle()
	state.enemy_hp = 1000
	var action: Dictionary = state.battle_action("attack")
	_check(action["valid"] and state.turn == 1 and state.qi == 4 and state.hp == 95, "Basic attack generates qi and quick strike deals five")
	_check(state.enemy_intent.contains("19"), "Next heavy attack telegraphed")
	state.battle_action("skill")
	_check(state.qi == 1 and state.skill_cooldown == 2 and state.hp == 80, "Skill cost, cooldown, heavy damage")
	var hp_before: int = state.hp
	_check(not state.battle_action("skill")["valid"] and state.turn == 2 and state.hp == hp_before and state.skill_cooldown == 2, "Cooldown rejection is free")
	state.battle_action("attack")
	_check(state.skill_cooldown == 1 and state.qi == 3, "First other action ticks cooldown")
	hp_before = state.hp
	state.battle_action("guard")
	_check(state.skill_cooldown == 0 and state.qi == 4 and state.hp == hp_before - 5, "Guard ticks cooldown and reduces heavy attack to five")
	_check(state.battle_action("skill")["valid"] and state.skill_cooldown == 2, "Skill ready after two other actions")
	state.qi = state.max_qi
	state.battle_action("attack")
	_check(state.qi == state.max_qi, "Generated qi capped")
	state.hp = 10
	state.medicine = 1
	action = state.battle_action("item")
	_check(action["valid"] and state.medicine == 0 and state.hp < 55, "Battle medicine spends an enemy turn")


func _test_victory_defeat_and_flee() -> void:
	var state = State.new()
	state.start_battle()
	var result: Dictionary = {}
	for action: String in ["attack", "skill", "attack", "guard", "skill"]:
		result = state.battle_action(action)
		if result["finished"]:
			break
	_check(result.get("won", false) and not state.battle_active and state.enemy_hp == 0, "Tactical sequence wins story fight")
	_check(state.victories == 1 and state.coins == 50 and state.level == 2, "Victory rewards coins, XP, victory count")
	_check(state.quest_stage == 0, "State does not advance narrative without caller")
	state.battle_action("attack")
	_check(state.victories == 1 and state.coins == 50, "Repeated completion cannot duplicate rewards")
	state.reset_game()
	state.hp = 1
	state.start_battle()
	result = state.battle_action("attack")
	_check(result["finished"] and not result["won"] and not state.battle_active, "Defeat ends combat")
	_check(state.hp == state.max_hp and state.coins == 16 and state.victories == 0, "Defeat recovers health and loses at most eight coins")
	state.coins = 3
	state.hp = 1
	state.start_battle()
	state.battle_action("attack")
	_check(state.coins == 0, "Defeat cannot create negative coins")
	state.reset_game()
	state.start_battle()
	var before: Dictionary = state.to_dict()
	result = state.battle_action("flee")
	_check(result["valid"] and result["finished"] and not result["won"] and not state.battle_active, "Flee ends encounter")
	_check(state.to_dict() == before, "Flee has no health or resource penalty")
	state.start_battle("training")
	state.attack = 100
	result = state.battle_action("attack")
	_check(result["won"] and state.xp == 30 and state.coins == 36, "Training has smaller rewards")


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Test fixture can be written")
		return
	file.store_string(content)
	file.close()


func _test_companion_and_equipment() -> void:
	var state = State.new()
	_check(not state.companion_unlocked and state.formation == "并肩" and state.equipment == "旧铁剑", "Companion and equipment defaults")
	_check(not state.set_formation("护后"), "Cannot select formation without companion")
	_check(not state.buy_equipment() and state.coins == 24 and state.attack == 16, "Insufficient coins leave equipment unchanged")
	state.coins = 45
	_check(state.buy_equipment() and state.coins == 0 and state.attack == 20 and state.equipment == "青钢剑", "Equipment purchase costs forty-five and adds four attack")
	state.coins = 99
	_check(not state.buy_equipment() and state.coins == 99 and state.attack == 20, "Equipment cannot be bought or applied twice")
	_check(state.recruit_companion() and state.companion_unlocked, "Companion can be recruited")
	_check(not state.recruit_companion(), "Recruitment is one-time")
	_check(not state.set_formation("unknown") and state.formation == "并肩", "Unknown formation rejected")
	_check(state.set_formation("并肩"), "Valid unchanged formation succeeds")
	state.start_battle()
	state.enemy_hp = 1000
	state.battle_action("attack")
	_check(state.enemy_hp == 980, "First parallel offense has no companion strike")
	state.battle_action("guard")
	_check(state.enemy_hp == 980, "Guard does not cause companion strike")
	state.battle_action("bad")
	state.battle_action("skill")
	_check(state.enemy_hp == 925, "Second offensive action adds seven companion damage after skill")
	state.battle_action("attack")
	_check(state.enemy_hp == 905, "Third offensive action does not assist")
	state.battle_action("attack")
	_check(state.enemy_hp == 878, "Fourth offensive action assists again")
	_check(state.set_formation("护后"), "Rear formation can be selected")
	var hp_before: int = state.hp
	state.battle_action("attack")
	_check(state.enemy_hp == 858 and state.hp == hp_before - 13, "Rear formation prevents two damage without offensive assist")
	hp_before = state.hp
	state.battle_action("guard")
	_check(state.hp == hp_before - 1, "Rear formation stacks with guard but damage stays at least one")
	state.battle_action("flee")
	state.set_formation("并肩")
	state.start_battle()
	state.enemy_hp = 1000
	state.battle_action("attack")
	_check(state.enemy_hp == 980, "New battle resets companion attack cadence")
	state.reset_game()
	_check(not state.companion_unlocked and state.formation == "并肩" and state.equipment == "旧铁剑" and state.attack == 16, "New game resets all expanded state")
	state.recruit_companion()
	state.start_battle()
	state.battle_action("attack")
	state.enemy_hp = 47
	var result: Dictionary = state.battle_action("skill")
	_check(result["won"] and state.enemy_hp == 0 and state.victories == 1, "Companion can deal winning blow before retaliation")
	state.reset_game()
	state.start_battle("spar")
	_check(state.enemy_name == "蒲横 · 切磋" and state.enemy_max_hp == 64 and state.battle_kind == "training", "Spar aliases training encounter")
	state.attack = 100
	state.battle_action("attack")
	_check(state.xp == 30 and state.coins == 36, "Spar uses training rewards")


func _test_expanded_save_compatibility() -> void:
	var original = State.new()
	original.coins = 100
	original.buy_equipment()
	original.recruit_companion()
	original.set_formation("护后")
	_check(original.save_game(TEST_SAVE) == OK, "Expanded save succeeds")
	var loaded = State.new()
	_check(loaded.load_game(TEST_SAVE) == OK and loaded.to_dict() == original.to_dict(), "Companion, formation and equipment persist")
	_check(loaded.attack == 20 and not loaded.buy_equipment(), "Loading equipment never reapplies its attack bonus")
	var legacy: Dictionary = State.new().to_dict()
	legacy.erase("companion_unlocked")
	legacy.erase("formation")
	legacy.erase("equipment")
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": legacy}))
	_check(loaded.load_game(BAD_SAVE) == OK, "Original version-one saves remain compatible")
	_check(not loaded.companion_unlocked and loaded.formation == "并肩" and loaded.equipment == "旧铁剑", "Legacy saves receive safe feature defaults")
	var malformed: Dictionary = original.to_dict()
	malformed["companion_unlocked"] = "true"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": malformed}))
	_check(loaded.load_game(BAD_SAVE) == ERR_FILE_CORRUPT, "Companion flag must be a boolean")
	malformed["companion_unlocked"] = true
	malformed["formation"] = "forged formation"
	malformed["equipment"] = "forged sword"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": malformed}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.formation == "并肩" and loaded.equipment == "旧铁剑", "Unknown feature enums sanitized")


func _test_side_quest_routes() -> void:
	for route: String in ["rescue", "pursuit"]:
		var state = State.new()
		var before: Dictionary = state.to_dict()
		_check(not state.find_side_clue("boatman") and not state.finish_side_quest(), "Side clues and rewards require route selection")
		_check(not state.choose_side_route("invalid") and state.to_dict() == before, "Invalid route changes nothing")
		_check(state.choose_side_route(route) and state.side_stage == 1 and state.side_choice == route, "First interaction selects " + route)
		_check(state.coins == 24 and state.xp == 0 and state.medicine == 3, "Route choice grants no resources")
		before = state.to_dict()
		_check(not state.choose_side_route("pursuit" if route == "rescue" else "rescue") and state.to_dict() == before, "Later route interaction cannot overwrite first choice")
		_check(not state.find_side_clue("invalid") and state.to_dict() == before, "Invalid clue changes nothing")
		var first: String = "boatman" if route == "rescue" else "ledger"
		var second: String = "ledger" if route == "rescue" else "boatman"
		_check(state.find_side_clue(first) and state.side_clues == 1 and state.side_stage == 1, "First clue progresses " + route)
		before = state.to_dict()
		_check(not state.find_side_clue(first) and not state.finish_side_quest() and state.to_dict() == before, "Duplicate clue and premature finish do not mutate")
		_check(state.find_side_clue(second) and state.side_clues == 2 and state.side_stage == 2, "Both clue orders unlock turn-in")
		_check(state.finish_side_quest() and state.side_stage == 3 and state.side_reward_claimed, "Side quest finishes once")
		_check(state.coins == (69 if route == "rescue" else 89) and state.medicine == (5 if route == "rescue" else 3), "Branch-specific resources for " + route)
		_check(state.level == 2 and state.xp == 20, "Side quest awards exactly eighty XP")
		before = state.to_dict()
		_check(not state.finish_side_quest() and not state.find_side_clue(second) and not state.choose_side_route(route) and state.to_dict() == before, "Completed side quest cannot duplicate rewards")
		_check(state.save_game(TEST_SAVE) == OK, "Completed side route saves")
		var loaded = State.new()
		_check(loaded.load_game(TEST_SAVE) == OK and loaded.to_dict() == before, "Completed side route round-trips in either clue order")
		_check(not loaded.finish_side_quest() and loaded.to_dict() == before, "Reload cannot duplicate side rewards")


func _test_side_save_coherence() -> void:
	var state = State.new()
	state.map_id = "sluice"
	state.choose_side_route("pursuit")
	state.find_side_clue("ledger")
	_check(state.current_region_name() == "旧闸", "Region helper names sluice")
	_check(state.save_game(TEST_SAVE) == OK, "Partial side progression saves")
	var loaded = State.new()
	_check(loaded.load_game(TEST_SAVE) == OK and loaded.to_dict() == state.to_dict(), "Partial side progression and region persist")
	var copy: Dictionary = state.to_dict()
	copy["side_found"].append("boatman")
	_check(state.side_found.size() == 1, "Serialization does not expose mutable clue-array alias")
	copy["side_found"] = ["ledger", "ledger", "unrecognized"]
	copy["side_clues"] = 999
	copy["side_stage"] = 2
	copy["map_id"] = "unrecognized"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.side_found == ["ledger"] and loaded.side_clues == 1 and loaded.side_stage == 1, "Load deduplicates clues and repairs inflated stage/count")
	_check(loaded.map_id == "qingwei" and loaded.current_region_name() == "青苇渡", "Unknown region falls back safely")
	copy["side_choice"] = "unrecognized"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.side_choice.is_empty() and loaded.side_stage == 0 and loaded.side_found.is_empty(), "Unknown incomplete branch resets side progress coherently")
	copy["side_choice"] = "pursuit"
	copy["side_stage"] = 3
	copy["side_reward_claimed"] = false
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.side_stage == 3 and loaded.side_reward_claimed and loaded.side_clues == 2, "Completion marker prevents reward replay despite mismatched flag")
	_check(not loaded.finish_side_quest() and loaded.coins == 24 and loaded.xp == 0, "Repairing completion does not grant resources")
	copy["side_choice"] = "invalid"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	var before: Dictionary = loaded.to_dict()
	_check(loaded.load_game(BAD_SAVE) == ERR_FILE_CORRUPT and loaded.to_dict() == before, "Completed save with unknown branch is rejected without inventing a choice")
	copy = State.new().to_dict()
	for key: String in ["map_id", "side_stage", "side_choice", "side_clues", "side_reward_claimed", "side_found"]:
		copy.erase(key)
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.map_id == "qingwei" and loaded.side_stage == 0 and loaded.side_found.is_empty(), "Saves from before side quests remain compatible")
	copy = state.to_dict()
	copy["side_found"] = [5]
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == ERR_FILE_CORRUPT, "Malformed clue collection rejected")
	state.reset_game()
	_check(state.map_id == "qingwei" and state.side_stage == 0 and state.side_choice.is_empty() and state.side_clues == 0 and not state.side_reward_claimed and state.side_found.is_empty(), "New game resets side progression")


func _test_sluice_encounters() -> void:
	var state = State.new()
	state.start_battle("sluice_scout")
	_check(state.enemy_max_hp == 85 and state.enemy_base_attack == 11 and state.enemy_strong_attack == 22 and state.enemy_intent.contains("11"), "Scout stats and first-turn intent")
	state.battle_action("attack")
	_check(state.hp == 93 and state.enemy_intent.contains("22"), "Scout quick damage and next heavy intent")
	state.battle_action("attack")
	_check(state.hp == 75 and state.exposed_turns == 0, "Scout heavy has no boss-only exposure")
	state.reset_game()
	state.start_battle("sluice_boss")
	_check(state.enemy_max_hp == 150 and state.enemy_base_attack == 16 and state.enemy_strong_attack == 28, "Boss stats")
	state.battle_action("attack")
	_check(state.hp == 88 and state.enemy_intent.contains("破绽"), "Boss heavy status is telegraphed")
	state.battle_action("attack")
	_check(state.hp == 64 and state.exposed_turns == 2, "Unguarded boss heavy applies two-turn exposure")
	state.battle_action("attack")
	_check(state.hp == 49 and state.exposed_turns == 1, "Exposure adds three to incoming damage and ticks down")
	var before_hp: int = state.hp
	state.battle_action("skill")
	_check(state.hp == before_hp - 27 and state.exposed_turns == 2, "Exposure refreshes after another unguarded heavy")
	before_hp = state.hp
	state.battle_action("guard")
	_check(state.hp == before_hp - 4 and state.exposed_turns == 0, "Guard clears exposure before incoming damage")
	state.hp = 100
	state.battle_action("guard")
	_check(state.hp == 92 and state.exposed_turns == 0, "Guarded boss heavy cannot reapply exposure")
	state.exposed_turns = 2
	var before_turn: int = state.turn
	state.battle_action("unknown")
	_check(state.exposed_turns == 2 and state.turn == before_turn, "Invalid action does not tick exposure")
	state.battle_action("flee")
	_check(state.exposed_turns == 0, "Flee clears transient exposure")
	state.start_battle("story")
	_check(state.enemy_base_attack == 9 and state.enemy_strong_attack == 19 and state.exposed_turns == 0, "New encounter restores original enemy defaults")
	for kind: String in ["sluice_scout", "sluice_boss"]:
		state.reset_game()
		state.recruit_companion()
		state.start_battle(kind)
		var result: Dictionary = {}
		for attempt in range(40):
			if not state.battle_active:
				break
			var action: String = "attack"
			if state.hp <= 45 and state.medicine > 0:
				action = "item"
			elif state.qi >= 3 and state.skill_cooldown == 0:
				action = "skill"
			result = state.battle_action(action)
		_check(result.get("won", false) and not state.battle_active and state.victories == 1, "Companion and available healing can defeat " + kind)
		_check(state.coins == (38 if kind == "sluice_scout" else 59), "Encounter coin reward: " + kind)
		_check((state.level == 1 and state.xp == 25) if kind == "sluice_scout" else (state.level == 2 and state.xp == 10), "Encounter XP reward: " + kind)
		_check(state.quest_stage == 0 and state.side_stage == 0, "Combat leaves narrative progression caller-controlled")
	state.reset_game()
	state.start_battle("sluice_boss")
	state.battle_action("attack")
	state.battle_action("attack")
	_check(state.exposed_turns == 2 and state.save_game(TEST_SAVE) == OK, "Save during exposed combat succeeds")
	var loaded = State.new()
	_check(loaded.load_game(TEST_SAVE) == OK and not loaded.battle_active and loaded.exposed_turns == 0 and loaded.enemy_base_attack == 9, "Enemy variant and exposure are never persisted")


func _test_martial_catalog_and_equipping() -> void:
	var state = State.new()
	_check(state.available_arts() == ["照夜一线"] and state.equipped_art == "照夜一线", "Base art available and equipped by default")
	_check(state.active_art_cost() == 3 and state.active_art_cooldown() == 2 and state.art_rank("照夜一线") == 1, "Base costs and initial rank preserved")
	_check(Arts.all_ids().size() == 10 and Arts.definition("照夜一线").is_read_only(), "Catalog contains ten immutable art definitions")
	var art_list: Array[String] = Arts.all_ids()
	art_list.clear()
	_check(Arts.all_ids().size() == 10, "Catalog ID lists are detached copies")
	_check(Arts.definition("unknown").is_empty() and state.art_description("unknown").is_empty() and state.art_rank("unknown") == 0, "Unknown art helpers are safe")
	_check(state.art_description("照夜一线").contains("40") and state.art_description("照夜一线").contains("初窥"), "Art description derives current damage and rank")
	var before: Dictionary = state.to_dict()
	_check(not state.equip_art("unknown") and not state.equip_art("回潮断浪") and state.to_dict() == before, "Unknown or unavailable equip leaves all state unchanged")
	state.choose_sect("听潮阁")
	_check(state.available_arts() == ["照夜一线", "回潮断浪"], "Joining sect unlocks only its art")
	_check(state.equip_art("回潮断浪") and state.active_art_cost() == 4 and state.active_art_cooldown() == 3, "Sect art equips with catalog costs")
	state.equip_art("照夜一线")
	state.equip_art("回潮断浪")
	state.equip_art("回潮断浪")
	_check(state.attack == 20 and state.defense == 4 and state.qi == 2 and state.art_uses == {"照夜一线": 0}, "Repeated swapping has no stat, qi or proficiency bonuses")
	before = state.to_dict()
	_check(not state.equip_art("青灯续脉") and not state.equip_art("磐石回锋") and state.to_dict() == before, "Other sect arts cannot be equipped")
	state.qi = 6
	state.start_battle()
	state.enemy_hp = 1000
	state.battle_action("skill")
	_check(not state.equip_art("照夜一线") and state.equipped_art == "回潮断浪", "Battle-time equipping is rejected")
	_check(state.skill_cooldown == 3 and not state.battle_action("skill")["valid"] and state.art_uses["照夜一线"] == 0, "Swapping cannot bypass an existing cooldown")
	state.reset_game()
	_check(state.equipped_art == "照夜一线" and state.art_uses == {"照夜一线": 0} and state.available_arts().size() == 1, "Reset removes sect art and proficiency progress")


func _test_sect_martial_effects() -> void:
	var tide = State.new()
	tide.choose_sect("听潮阁")
	tide.equip_art("回潮断浪")
	tide.qi = 6
	tide.start_battle()
	tide.enemy_hp = 1000
	var result: Dictionary = tide.battle_action("skill")
	_check(result["valid"] and tide.enemy_hp == 944 and tide.qi == 2 and tide.skill_cooldown == 3, "Tide art deals attack twice plus sixteen and uses four qi")
	_check(result["message"].contains("回潮断浪") and tide.art_uses["回潮断浪"] == 1, "Tide cast names its effect and earns proficiency")
	var healer = State.new()
	healer.choose_sect("照野堂")
	healer.equip_art("青灯续脉")
	healer.hp = 50
	healer.qi = 6
	healer.start_battle()
	healer.enemy_hp = 1000
	result = healer.battle_action("skill")
	_check(healer.enemy_hp == 984 and healer.hp == 75 and healer.qi == 3 and healer.skill_cooldown == 3, "Healer art deals attack and heals thirty before retaliation")
	_check(result["message"].contains("青灯续脉") and result["message"].contains("恢复 30"), "Healer art explicitly logs healing")
	healer.skill_cooldown = 0
	healer.hp = healer.max_hp - 5
	healer.qi = 6
	result = healer.battle_action("skill")
	_check(healer.hp == healer.max_hp - 15 and result["message"].contains("恢复 5"), "Healer art caps healing and logs actual amount")
	var stone = State.new()
	stone.choose_sect("问石门")
	stone.equip_art("磐石回锋")
	stone.qi = 6
	stone.start_battle()
	stone.enemy_hp = 1000
	result = stone.battle_action("skill")
	_check(stone.enemy_hp == 974 and stone.hp == 99 and stone.qi == 3 and stone.skill_cooldown == 2, "Stone art deals attack plus ten and guards retaliation")
	_check(result["message"].contains("磐石回锋") and result["message"].contains("进入守势"), "Stone art explicitly logs defensive effect")
	stone.battle_action("flee")
	stone.start_battle("sluice_boss")
	stone.enemy_hp = 1000
	stone.turn = 1
	stone.exposed_turns = 2
	stone.hp = 100
	stone.qi = 6
	stone.battle_action("skill")
	_check(stone.hp == 93 and stone.exposed_turns == 0, "Stone art clears existing exposure and blocks its reapplication")


func _test_art_proficiency() -> void:
	var state = State.new()
	state.start_battle()
	state.enemy_hp = 1000
	var before: Dictionary = state.to_dict()
	_check(not state.battle_action("skill")["valid"] and state.to_dict() == before, "Insufficient qi cannot train proficiency")
	state.qi = 6
	state.art_uses["照夜一线"] = 4
	_check(state.art_rank("照夜一线") == 1, "Four uses remains first rank")
	state.battle_action("skill")
	_check(state.enemy_hp == 960 and state.art_uses["照夜一线"] == 5 and state.art_rank("照夜一线") == 2, "Fifth accepted cast unlocks rank two after using old-rank damage")
	before = state.to_dict()
	_check(not state.battle_action("skill")["valid"] and state.to_dict() == before, "Cooldown rejection cannot train proficiency")
	state.skill_cooldown = 0
	state.qi = 6
	state.battle_action("skill")
	_check(state.enemy_hp == 917, "Rank two adds three damage")
	state.skill_cooldown = 0
	state.qi = 6
	state.art_uses["照夜一线"] = 14
	_check(state.art_rank("照夜一线") == 2, "Fourteen uses remains rank two")
	state.battle_action("skill")
	_check(state.enemy_hp == 874 and state.art_uses["照夜一线"] == 15 and state.art_rank("照夜一线") == 3, "Fifteenth accepted cast unlocks rank three")
	state.skill_cooldown = 0
	state.qi = 6
	state.battle_action("skill")
	_check(state.enemy_hp == 828 and state.art_description("照夜一线").contains("46") and state.art_description("照夜一线").contains("通明"), "Rank three damage and description add six")
	state.skill_cooldown = 0
	state.qi = 6
	state.hp = 100
	state.art_uses["照夜一线"] = 9999
	state.battle_action("skill")
	_check(state.art_uses["照夜一线"] == 9999, "Proficiency count saturates safely")


func _test_martial_saves() -> void:
	var state = State.new()
	state.choose_sect("照野堂")
	state.equip_art("青灯续脉")
	state.art_uses = {"照夜一线": 5, "青灯续脉": 15}
	_check(state.save_game(TEST_SAVE) == OK, "Martial progression saves")
	var loaded = State.new()
	_check(loaded.load_game(TEST_SAVE) == OK and loaded.to_dict() == state.to_dict() and loaded.art_rank("青灯续脉") == 3, "Equipped sect art and proficiency round-trip")
	var copy: Dictionary = state.to_dict()
	copy["art_uses"]["青灯续脉"] = 50
	_check(state.art_uses["青灯续脉"] == 15, "Serialization proficiency dictionary is detached")
	copy["equipped_art"] = "回潮断浪"
	copy["art_uses"] = {"照夜一线": -20, "青灯续脉": 1.0e100, "unknown": 50}
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.equipped_art == "照夜一线", "Unavailable saved art falls back to base")
	_check(loaded.art_uses == {"照夜一线": 0, "青灯续脉": 9999}, "Proficiency clamps counts and discards unknown arts")
	copy["equipped_art"] = "unknown"
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.equipped_art == "照夜一线", "Unknown saved art falls back to base")
	copy["art_uses"] = {"照夜一线": "many"}
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	var before: Dictionary = loaded.to_dict()
	_check(loaded.load_game(BAD_SAVE) == ERR_FILE_CORRUPT and loaded.to_dict() == before, "Malformed proficiency rejects unchanged")
	copy = state.to_dict()
	copy.erase("equipped_art")
	copy.erase("art_uses")
	_write(BAD_SAVE, JSON.stringify({"version": 1, "player": copy}))
	_check(loaded.load_game(BAD_SAVE) == OK and loaded.equipped_art == "照夜一线" and loaded.art_uses == {"照夜一线": 0}, "Pre-martial saves get compatible base defaults")
	_check(loaded.available_arts() == ["照夜一线", "青灯续脉"], "Older sect membership still unlocks its new art")
