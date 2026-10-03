extends SceneTree
## Prepared chapter-boundary fixtures use only hero/Shen, who can actually be
## present here. Scene traversal owns earning the opening chapter and map travel.
const State = preload("res://scripts/game_state.gd")
const AutoDriver = preload("res://tests/automatic_state_test_driver.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME for sluice state checks")
		quit(2)
		return
	fixture_root = "user://party-sluice-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Create isolated fixture directory")
	test_entry_gates()
	test_routes_and_roundtrips()
	test_terminal_atomicity()
	test_resource_and_reward_order()
	test_flee_defeat_retry()
	test_failed_saves()
	_remove_tree(fixture_root)
	check(not DirAccess.dir_exists_absolute(fixture_root), "Only this isolated fixture directory is removed")
	if failures == 0:
		print("PASS: %d sluice party state checks (gates/routes/atomic rewards/resources/retry/schema14/save failures)" % checks)
	else:
		push_error("FAIL: %d / %d sluice party state checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _chapter(route: String = "rescue", boss: bool = false, with_shen: bool = true):
	var s = State.new()
	s.quest_stage = 6
	s.ending = "守望"
	s.gain_xp(180)
	s.map_id = "sluice"
	s.position = Vector2(570, 360)
	if with_shen:
		check(s.recruit_companion(), "Real Shen invitation initializes her own resources")
	check(s.choose_side_route(route), "Prepared chapter chooses its actual first route")
	if route == "rescue" or boss:
		check(s.find_side_clue("boatman"), "Boatman evidence is a free existing investigation action")
	if boss:
		check(s.find_side_clue("ledger"), "Prepared boss starts after both existing clues")
	return s


func _earned(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)


func _snapshot(s) -> Dictionary:
	return {"save": s.to_dict(), "party": s.party_battle_snapshot(), "active": s.battle_active,
		"epoch": s.party_battle_epoch, "settlement": s.party_settlement, "kind": s.battle_kind,
		"entry": s._party_sluice_entry.duplicate(true)}


func _step(s, action: String, target: String = "") -> Dictionary:
	var tx: Dictionary
	if action == "advance": tx = s.advance_party_battle()
	elif action.begins_with("art:"): tx = AutoDriver.queued_next(s, "hero", action, target)
	else: tx = s.party_battle_action(action, target)
	check(tx.accepted, "Accepted real party action: " + action)
	if tx.accepted:
		check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Accepted action acknowledges its exact presentation token")
	return tx


func _fight(s, finish: bool = true) -> Dictionary:
	var last: Dictionary = {}
	for index: int in range(400):
		if not s.battle_active: break
		last = AutoDriver.tactical_next(s)
		check(last.accepted, "Bounded route uses available actions from the selected actor")
		if not last.accepted:
			break
		if not last.after.active and not finish:
			return last
		check(s.finish_party_presentation(last.epoch, last.token).accepted, "Bounded route acknowledges actual presentation")
	check(not s.battle_active and s.party_settlement.get("outcome") == "win", "Ordinary actor actions reach victory without stat injection")
	return last


func _roundtrip(s, name: String) -> void:
	var path: String = fixture_root.path_join(name + ".json")
	check(s.save_game(path) == OK, "Complete schema14 save succeeds: " + name)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var document: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	check(document.version == State.SAVE_VERSION and not bytes.get_string_from_utf8().contains("vulnerability") and not bytes.get_string_from_utf8().contains("_party_sluice_entry"), "Battle-only state adds no field or schema version")
	var loaded = State.new()
	check(loaded.load_game(path) == OK and loaded.to_dict() == s.to_dict() and FileAccess.get_file_as_bytes(path) == bytes, "Every canonical persistent field and clue order roundtrips unchanged")
	check(loaded.party_battle_snapshot().is_empty() and loaded._party_sluice_entry.is_empty(), "Loaded state has no transient encounter or captured entry")


func _reject_start(s, encounter: String, key: String, value: Variant) -> void:
	var original = s._detached_persistent_state()
	s.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	var before: Dictionary = _snapshot(s)
	check(not s.can_start_sluice_party_battle(encounter) and not s.start_party_battle(encounter) and _snapshot(s) == before, "Invalid " + encounter + " prerequisite rejects without mutation: " + key)
	s._copy_persistent_from(original)


func test_entry_gates() -> void:
	for encounter: String in ["sluice_scout", "sluice_boss"]:
		var s = _chapter("rescue", encounter == "sluice_boss")
		for mutation: Array in [["quest_stage", 5], ["map_id", "qingwei"], ["side_choice", ""], ["side_choice", "unknown"], ["side_reward_claimed", true], ["side_clues", 7], ["side_stage", 0], ["side_stage", 3], ["hp", 0]]:
			_reject_start(s, encounter, mutation[0], mutation[1])
		var found: Array[String] = []
		found.assign(["ledger"] if encounter == "sluice_scout" else ["boatman", "boatman"])
		_reject_start(s, encounter, "side_found", found)
		if encounter == "sluice_boss":
			found.assign(["ledger", "ledger"])
			_reject_start(s, encounter, "side_found", found)
		check(s.can_start_sluice_party_battle(encounter) and s.start_party_battle(encounter), "Valid chapter-specific entry succeeds")
		var before: Dictionary = _snapshot(s)
		check(not s.can_start_sluice_party_battle(encounter) and not s.start_party_battle(encounter) and not s.choose_side_route("pursuit") and not s.find_side_clue("ledger") and not s.finish_side_quest() and _snapshot(s) == before, "Active sluice fight rejects all duplicate entry and side progression mutations")
		_step(s, "flee")
	check(not State.new().start_party_battle("sluice_scout") and not State.new().start_party_battle("sluice_boss"), "Opening cannot jump into either sluice encounter")


func test_routes_and_roundtrips() -> void:
	for route: String in ["rescue", "pursuit"]:
		for formation: String in ["并肩", "护后"]:
			for with_shen: bool in [false, true]:
				var s = _chapter(route, false, with_shen)
				s.formation = formation
				var earned: int = _earned(s)
				var coins: int = s.coins
				var victories: int = s.victories
				var label: String = "%s-%s-%d" % [route, formation, int(with_shen)]
				_roundtrip(s, "before-" + label)
				check(s.start_party_battle("sluice_scout"), "Scout enters in both legal chapter rosters/formations")
				check(s.party_battle_snapshot().actors.size() == (2 if with_shen else 1) and not s.tangqi_unlocked and not s.qin_recruited(), "Natural chapter roster contains only hero and optional Shen")
				var scout: Dictionary = _fight(s)
				check(_earned(s) == earned + 25 and s.coins == coins + 14 and s.victories == victories + 1, "Scout awards exactly25XP/14coins/one victory with no clue XP")
				check(s.side_found == (["boatman", "ledger"] if route == "rescue" else ["ledger"]) and s.side_stage == (2 if route == "rescue" else 1), "Scout preserves first-route clue order and grants ledger exactly once")
				check(not s.finish_party_presentation(scout.epoch, scout.token).accepted and not s.start_party_battle("sluice_scout"), "Repeated scout callback or fresh entry cannot award again")
				_roundtrip(s, "ledger-" + label)
				if route == "pursuit":
					check(not s.start_party_battle("sluice_boss"), "Ledger alone cannot enter boss")
					var xp_before_clue: int = _earned(s)
					check(s.find_side_clue("boatman") and _earned(s) == xp_before_clue and s.side_found == ["ledger", "boatman"], "Pursuit then boatman remains free and retains its reverse clue order")
				s.heal_rest()
				var medicine: int = s.medicine
				check(s.start_party_battle("sluice_boss"), "Both actual clues unlock boss")
				var boss: Dictionary = _fight(s, false)
				check(boss.after.outcome == "win" and s.side_stage == 2 and not s.side_reward_claimed and s.coins == coins + 14, "Terminal boss transaction does not apply branch rewards ahead of its presentation")
				var consumed: int = medicine - s.medicine
				check(s.finish_party_presentation(boss.epoch, boss.token).settled, "Boss rewards and branch completion commit together")
				check(_earned(s) == earned + 175 and s.coins == coins + (94 if route == "rescue" else 114) and s.victories == victories + 2, "Entire route preserves scout25 + boss70 + branch80XP and existing coin totals")
				check(s.side_stage == 3 and s.side_reward_claimed and s.medicine == medicine - consumed + (2 if route == "rescue" else 0), "Existing rescue medicine or pursuit bonus settles exactly once")
				check(s.party_settlement.reward_xp == 150 and s.party_settlement.battle_reward_xp == 70 and s.party_settlement.branch_reward_xp == 80 and s.party_settlement.branch_reward_claimed, "Renderer receives explicit combined and separate battle/branch reward facts")
				var settled: Dictionary = _snapshot(s)
				check(not s.finish_side_quest() and not s.finish_party_presentation(boss.epoch, boss.token).accepted and not s.start_party_battle("sluice_boss") and _snapshot(s) == settled, "Legacy turn-in and duplicated terminal callback cannot replay completed branch")
				_roundtrip(s, "completed-" + label)


func test_terminal_atomicity() -> void:
	for encounter: String in ["sluice_scout", "sluice_boss"]:
		var s = _chapter("rescue", encounter == "sluice_boss")
		s.attack = 200 # Explicit mechanical fixture isolates one terminal action.
		check(s.start_party_battle(encounter), "Atomicity fixture enters eligible encounter")
		var tx: Dictionary = s.advance_party_battle()
		check(tx.accepted and tx.after.outcome == "win", "Real lethal action creates a locked terminal transaction")
		var accepted = s._detached_persistent_state()
		var before: Dictionary = _snapshot(s)
		check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 1).accepted and _snapshot(s) == before, "Stale epoch/token never changes terminal state")
		for mutation: Array in [["map_id", "qingwei"], ["quest_stage", 5], ["side_stage", 3], ["side_choice", "pursuit"], ["side_clues", 0], ["side_reward_claimed", true], ["medicine", -1]]:
			s.set(mutation[0], mutation[1])
			before = _snapshot(s)
			check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before and s.battle_active, "Detached settlement rejects changed prerequisite or malformed full save atomically: " + String(mutation[0]))
			s._copy_persistent_from(accepted)
		if encounter == "sluice_boss":
			s.side_found.assign(["ledger", "boatman"])
			before = _snapshot(s)
			check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before, "Even another valid clue order cannot replace the captured route during presentation")
			s._copy_persistent_from(accepted)
		check(s.finish_party_presentation(tx.epoch, tx.token).settled, "Restored valid entry can acknowledge the same still-pending token once")
		before = _snapshot(s)
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before, "Successful atomic retry consumes its token exactly once")


func test_resource_and_reward_order() -> void:
	for encounter: String in ["sluice_scout", "sluice_boss"]:
		for level_up: bool in [false, true]:
			var s = _chapter("rescue", encounter == "sluice_boss")
			s.attack = 200
			s.xp = s.xp_to_next() - 1 if level_up else 0
			s.hp = 13
			s.qi = 0
			s.party_resources.shen = {"hp": 7, "qi": 0}
			check(s.set_party_roster(["hero"]), "Order fixture explicitly benches injured Shen")
			var level: int = s.level
			var earned: int = _earned(s)
			check(s.start_party_battle(encounter), "Resource order fixture starts")
			var tx: Dictionary = s.advance_party_battle()
			check(tx.accepted and s.hp == 13 and s.qi == 2 and s.level == level, "Terminal accepted action mirrors real resources before awarding XP")
			check(s.finish_party_presentation(tx.epoch, tx.token).settled, "Resource order terminal commits")
			check(_earned(s) == earned + (150 if encounter == "sluice_boss" else 25), "Resource reconciliation does not erase earned XP")
			check((s.level == level + 1 and s.hp == s.max_hp and s.qi == s.max_qi) if level_up else (s.level == level and s.hp == 13 and s.qi == 2), "Resource settlement precedes both reward XP steps and preserves exactly the resulting hero recovery")
			check(s.party_resources.shen == {"hp": 7, "qi": 0}, "Reward levels never heal a benched actor")
	# A level gained only by the second, branch XP step must also retain recovery.
	var branch = _chapter("pursuit", true)
	branch.attack = 200
	branch.xp = 31
	branch.hp = 11
	branch.qi = 0
	check(branch.start_party_battle("sluice_boss"), "Branch-only level-up fixture starts")
	_step(branch, "advance", "sluice_boss")
	check(branch.level == 4 and branch.xp == 1 and branch.hp == branch.max_hp and branch.qi == branch.max_qi, "70XP alone cannot level; following80XP does, with final HP/qi refill intact")
	check(branch.party_settlement.messages.size() == 1, "Second XP step reports its one level-up once")
	for route: String in ["rescue", "pursuit"]:
		var capped = _chapter(route, true)
		capped.attack = 200
		capped.coins = 999990
		capped.medicine = 998
		capped.victories = 999999
		check(capped.start_party_battle("sluice_boss"), "Valid maximum-range inventory can enter boss")
		_step(capped, "advance", "sluice_boss")
		check(capped.side_reward_claimed and capped.coins == 999999 and capped.victories == 999999 and capped.medicine == (999 if route == "rescue" else 998), "Combined branch rewards respect save bounds without blocking legal maximum-range state")
		_roundtrip(capped, "capped-" + route)


func test_flee_defeat_retry() -> void:
	for encounter: String in ["sluice_scout", "sluice_boss"]:
		for route: String in ["rescue", "pursuit"]:
			var s = _chapter(route, encounter == "sluice_boss")
			var progress: Dictionary = s._sluice_party_progress()
			var earned: int = _earned(s)
			var coins: int = s.coins
			var victories: int = s.victories
			check(s.start_party_battle(encounter), "Retry fixture starts current route stage")
			_step(s, "art:" + s.equipped_art, encounter)
			var spent: Dictionary = s.to_dict()
			var old: Dictionary = _step(s, "flee")
			check(s.to_dict() == spent and s._sluice_party_progress() == progress and _earned(s) == earned and s.coins == coins and s.victories == victories, "Flee preserves accepted qi/proficiency and all branch progress without reward")
			_roundtrip(s, "retreat-" + encounter + route)
			check(s.start_party_battle(encounter), "Retreat permits a fresh eligible attempt")
			var before: Dictionary = _snapshot(s)
			check(not s.finish_party_presentation(old.epoch, old.token).accepted and _snapshot(s) == before, "Old attempt token cannot settle a retry even when serial token repeats")
			_step(s, "flee")
			for purse: int in [5, 21]:
				var defeated = _chapter(route, encounter == "sluice_boss")
				check(defeated.set_party_roster(["hero"]), "Defeat fixture leaves injured Shen benched")
				defeated.party_resources.shen = {"hp": 0, "qi": 0}
				defeated.hp = 1
				defeated.qi = 0
				defeated.coins = purse
				check(defeated.start_party_battle(encounter), "Actual low-health defeat enters")
				var defeated_tx: Dictionary = AutoDriver.terminal_next(defeated)
				check(defeated_tx.get("accepted", false) and defeated.finish_party_presentation(defeated_tx.epoch, defeated_tx.token).settled, "Automatic enemy transaction settles actual defeat")
				check(defeated.party_settlement.get("outcome") == "defeat" and defeated.coins == maxi(0, purse - 8) and defeated.hp == defeated.max_hp and defeated.qi >= 2 and defeated.party_resources.shen.hp > 0 and defeated.party_resources.shen.qi == 2, "Defeat loses at most8coins and explicitly recovers hero and benched companion")
				check(defeated.map_id == "qingwei" and defeated.position == Vector2(420, 450) and defeated.side_found == progress.side_found and defeated.side_choice == route and defeated.side_stage == progress.side_stage and not defeated.side_reward_claimed and defeated.victories == victories and _earned(defeated) == earned, "Defeat uses existing Qingwei recovery while preserving every investigation prerequisite")
				check(not defeated.start_party_battle(encounter), "Recovery village requires traveling back before retry")
				defeated.map_id = "sluice"
				check(defeated.start_party_battle(encounter), "Returning to sluice permits legitimate retry")
				_step(defeated, "flee")


func test_failed_saves() -> void:
	for encounter: String in ["sluice_scout", "sluice_boss"]:
		var s = _chapter("rescue", encounter == "sluice_boss")
		var path: String = fixture_root.path_join("failure-" + encounter + ".json")
		check(s.save_game(path) == OK, "Pre-entry complete checkpoint saves")
		var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var bad_path: String = fixture_root.path_join("absent/" + encounter + ".json")
		var before: Dictionary = _snapshot(s)
		check(s.save_game(bad_path) != OK and _snapshot(s) == before and FileAccess.get_file_as_bytes(path) == checkpoint, "Failed checkpoint creation changes neither live state nor last valid save")
		check(s.start_party_battle(encounter), "Existing durable checkpoint admits state-level test fight")
		var tx: Dictionary = _fight(s, false)
		check(s.save_game(path) == ERR_BUSY and s.load_game(path) == ERR_BUSY and FileAccess.get_file_as_bytes(path) == checkpoint, "Terminal presentation protects pre-entry checkpoint")
		check(s.finish_party_presentation(tx.epoch, tx.token).settled, "Terminal commits after presentation")
		before = _snapshot(s)
		check(s.save_game(bad_path) != OK and not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before and FileAccess.get_file_as_bytes(path) == checkpoint, "Post-settlement write failure cannot replay reward and preserves old durable checkpoint")
		var blocked_path: String = fixture_root.path_join("blocked-" + encounter)
		check(DirAccess.make_dir_recursive_absolute(blocked_path) == OK, "Prepare isolated non-file destination")
		check(s.save_game(blocked_path) != OK and not FileAccess.file_exists(blocked_path + ".tmp") and _snapshot(s) == before, "Failed atomic rename cleans temporary file without changing settled state")
		check(s.save_game(path) == OK, "Retry writes the already-settled result once")
		var completed_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var loaded = State.new()
		check(loaded.load_game(path) == OK and loaded.to_dict() == s.to_dict() and not loaded.start_party_battle(encounter), "Reloaded settled save cannot replay rewarded encounter")
		s.party_resources.shen["vulnerability_hits"] = 2
		check(s.save_game(path) == ERR_FILE_CORRUPT and FileAccess.get_file_as_bytes(path) == completed_bytes, "Battle vulnerability cannot enter persistent companion resources or overwrite valid schema14")


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var directory = DirAccess.open(path)
	for file: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for child: String in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
