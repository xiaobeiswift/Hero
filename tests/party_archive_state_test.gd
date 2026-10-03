extends SceneTree
## Real earned progression uses only hero/optional Shen. Later 3–4 actor teams
## are explicitly detached catalog fixtures, never early story recruitment.
const State = preload("res://scripts/game_state.gd")
const AutoDriver = preload("res://tests/automatic_state_test_driver.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Rules = preload("res://scripts/party_combat_rules.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String
var eligible_fixture: Dictionary = {}


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME for archive state checks")
		quit(2)
		return
	fixture_root = "user://party-archive-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Create isolated archive fixtures")
	test_natural_progression_and_endings()
	test_entry_gates()
	test_chapter_mutation_guards()
	test_terminal_atomicity()
	test_resource_reward_order()
	test_flee_defeat_retry()
	test_save_failures_and_malformed_loads()
	test_catalog_mechanics()
	test_archive_status_ownership()
	test_archive_barriers_and_guard_arts()
	_remove_tree(fixture_root)
	check(not DirAccess.dir_exists_absolute(fixture_root), "Only this isolated archive fixture directory is removed")
	if failures == 0:
		print("PASS: %d archive party checks (natural solo/Shen/formation/endings/gates/atomic rewards/retry/schema14/capacity mechanics)" % checks)
	else:
		push_error("FAIL: %d / %d archive party checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _earned(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)


func _snapshot(s) -> Dictionary:
	return {"save": s.to_dict(), "party": s.party_battle_snapshot(), "active": s.battle_active,
		"epoch": s.party_battle_epoch, "settlement": s.party_settlement, "kind": s.battle_kind,
		"entry": s._party_archive_entry.duplicate(true)}


func _actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id:
			return actor
	return {}


func _step(s, action: String, target: String = "") -> Dictionary:
	var tx: Dictionary
	if action == "advance": tx = s.advance_party_battle()
	elif action.begins_with("art:"): tx = AutoDriver.queued_next(s, "hero", action, target)
	else: tx = s.party_battle_action(action, target)
	check(tx.accepted, "Legal archive route action is accepted: " + action)
	if tx.accepted:
		check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Exact action presentation token acknowledges")
	return tx


func _fight(s, finish: bool = true) -> Dictionary:
	var last: Dictionary = {}
	for index: int in range(400):
		if not s.battle_active: break
		last = AutoDriver.tactical_next(s)
		check(last.accepted, "Earned natural route chooses a legal action")
		if not last.accepted:
			break
		if not last.after.active and not finish:
			check(last.after.outcome == "win", "Natural route reaches terminal victory")
			return last
		check(s.finish_party_presentation(last.epoch, last.token).accepted, "Natural route presents its actual token")
	check(not s.battle_active and s.party_settlement.get("outcome") == "win", "Natural resources win within 400 scheduler transactions")
	return last


func _natural_archive(with_shen: bool, formation: String, route: String):
	var s = State.new()
	# Opening dialogue effects live in main.gd rather than State APIs. Reproduce
	# those exact earned herb/delivery effects, then use production party fights.
	s.quest_stage = 1
	s.herbs += 1
	s.quest_stage = 2
	s.gain_xp(10)
	s.herbs -= 1
	s.medicine += 2
	s.quest_stage = 3
	s.gain_xp(20)
	if with_shen:
		check(s.recruit_companion(), "Optional Shen joins via the actual invitation API")
	s.formation = formation
	check(s.start_party_battle("story"), "New-game supplies enter the real opening party encounter")
	_fight(s)
	check(s.quest_stage == 4, "Opening win unlocks its dialogue choice")
	s.ending = "守望"
	s.quest_stage = 5
	s.coins += 60
	s.gain_xp(90)
	s.heal_rest()
	s.choose_sect("听潮阁")
	s.quest_stage = 6
	check(s.buy_equipment(), "Earned opening coins buy the ordinary sword")
	s.map_id = "sluice"
	check(s.choose_side_route(route), "Existing first route is chosen normally")
	if route == "rescue":
		check(s.find_side_clue("boatman"), "Free boatman investigation uses the existing clue API")
	check(s.start_party_battle("sluice_scout"), "Natural route enters actual scout encounter")
	_fight(s)
	if route == "pursuit":
		check(s.find_side_clue("boatman"), "Pursuit then free boatman retains reverse clue order")
	s.heal_rest()
	check(s.start_party_battle("sluice_boss"), "Natural route enters actual sluice boss")
	_fight(s)
	check(s.side_stage == 3 and s.side_reward_claimed, "Sluice battle and branch settle before archive")
	s.map_id = "frostbridge"
	s.position = Vector2(1250, 790)
	check(s.begin_chapter_two(), "Completed sluice permits actual archive chapter entry")
	check(s.add_archive_clue("inscription") and s.add_archive_clue("clerk"), "Both archive clues grant their actual rewards")
	check(s.try_seal(0).valid and s.seal_sequence.is_empty(), "Wrong seal resets without progressing")
	for index: int in [2, 0, 1]:
		check(s.try_seal(index).valid, "Actual puzzle input accepts its correct prefix")
	check(s.chapter_two_stage == 2 and s.seal_sequence == [2, 0, 1], "Solved seal unlocks battle only")
	s.heal_rest()
	check(not s.tangqi_unlocked and not s.qin_recruited() and s.party_roster == (["hero", "shen"] if with_shen else ["hero"]), "Natural archive roster never recruits future companions early")
	return s


func _fixture():
	var staged: Dictionary = State.new()._stage_save_data(eligible_fixture, State.SAVE_VERSION)
	check(staged.ok, "Prepared fixture is a canonical earned archive checkpoint")
	return staged.state


func _roundtrip(s, name: String) -> void:
	var path: String = fixture_root.path_join(name + ".json")
	check(s.save_game(path) == OK, "Archive checkpoint saves: " + name)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var document: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	check(document.version == State.SAVE_VERSION and not bytes.get_string_from_utf8().contains("vulnerability") and not bytes.get_string_from_utf8().contains("_party_archive_entry"), "Archive adds no persistent field or new schema")
	var loaded = State.new()
	check(loaded.load_game(path) == OK and loaded.to_dict() == s.to_dict() and FileAccess.get_file_as_bytes(path) == bytes, "All canonical fields roundtrip without normalization or reward")
	check(loaded.party_battle_snapshot().is_empty() and loaded._party_archive_entry.is_empty(), "Loading starts with no encounter or entry snapshot")


func test_natural_progression_and_endings() -> void:
	for formation: String in ["并肩", "护后"]:
		for with_shen: bool in [false, true]:
			for ending: String in ["open_records", "protect_witness"]:
				var s = _natural_archive(with_shen, formation, "rescue" if ending == "open_records" else "pursuit")
				if with_shen and eligible_fixture.is_empty():
					eligible_fixture = s.to_dict()
				var label: String = "%s-%d-%s" % [formation, int(with_shen), ending]
				_roundtrip(s, "before-" + label)
				var earned: int = _earned(s)
				var coins: int = s.coins
				var victories: int = s.victories
				check(s.can_start_archive_party_battle() and s.start_party_battle("archive_boss"), "Earned solved archive enters in both formations")
				var snapshot: Dictionary = s.party_battle_snapshot()
				check(snapshot.enemies.size() == 1 and snapshot.enemies[0].id == "archive_boss" and snapshot.enemies[0].name == "韩砚 · 仓门执事" and snapshot.enemies[0].hp == 205 and snapshot.enemies[0].attack == 17 and snapshot.enemies[0].heavy_attack == 31, "Archive has exactly its unique canonical 205/17/31 enemy")
				var tx: Dictionary = _fight(s, false)
				check(s.chapter_two_stage == 2 and s.chapter_two_ending.is_empty() and _earned(s) == earned and s.coins == coins and s.victories == victories, "Terminal accepted action awards nothing before its presentation")
				check(s.finish_party_presentation(tx.epoch, tx.token).settled, "Archive terminal settlement commits once")
				check(s.chapter_two_stage == 3 and s.chapter_two_ending.is_empty() and _earned(s) == earned + 80 and s.coins == coins + 40 and s.victories == victories + 1, "Archive pays exactly 80XP/40coins/one victory and leaves ending undecided")
				check(s.party_settlement.reward_xp == 80 and s.party_settlement.battle_reward_xp == 80 and s.party_settlement.branch_reward_xp == 0 and not s.party_settlement.branch_reward_claimed and s.party_settlement.chapter_two_stage == 3 and s.party_settlement.chapter_two_ending.is_empty(), "Settlement metadata separates archive combat from later choice")
				var before: Dictionary = _snapshot(s)
				check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and not s.mark_archive_victory() and not s.start_party_battle("archive_boss") and _snapshot(s) == before, "Repeated battle callback and direct victory cannot replay rewards")
				_roundtrip(s, "won-" + label)
				check(s.resolve_chapter_two(ending), "Player explicitly chooses the independent ending")
				check(s.chapter_two_stage == 4 and s.chapter_two_ending == ending and _earned(s) == earned + 180 and s.coins == coins + 105 and s.victories == victories + 1, "Later ending gives its separate 100XP/65coins with no second victory")
				before = _snapshot(s)
				check(not s.resolve_chapter_two(ending) and not s.start_party_battle("archive_boss") and _snapshot(s) == before, "Ending and archive cannot repeat after resolution")
				_roundtrip(s, "ending-" + label)


func _set_value(s, key: String, value: Variant) -> void:
	if value is Array:
		s.get(key).assign(value)
	else:
		s.set(key, value.duplicate(true) if value is Dictionary else value)


func test_entry_gates() -> void:
	var s = _fixture()
	for mutation: Array in [["map_id", "sluice"], ["quest_stage", 5], ["side_stage", 2], ["side_reward_claimed", false], ["side_choice", ""], ["side_choice", "unknown"], ["side_clues", 1], ["side_found", ["boatman", "boatman"]], ["chapter_two_stage", 1], ["chapter_two_stage", 3], ["chapter_two_stage", 4], ["chapter_two_ending", "open_records"], ["archive_clues", ["clerk"]], ["archive_clues", ["clerk", "clerk"]], ["archive_clues", ["clerk", "unknown"]], ["seal_sequence", [2, 0]], ["seal_sequence", [2, 1, 0]], ["hp", 0], ["medicine", -1], ["coins", 1000000], ["party_roster", ["hero", "tang"]]]:
		var valid = s._detached_persistent_state()
		_set_value(s, mutation[0], mutation[1])
		var before: Dictionary = _snapshot(s)
		check(not s.can_start_archive_party_battle() and not s.start_party_battle("archive_boss") and _snapshot(s) == before, "Malformed or ineligible archive start rejects atomically: " + String(mutation[0]))
		s._copy_persistent_from(valid)
	check(not State.new().start_party_battle("archive_boss"), "New game cannot jump to archive")
	check(s.start_party_battle("archive_boss"), "Canonical eligible archive enters")
	var before: Dictionary = _snapshot(s)
	check(not s.can_start_archive_party_battle() and not s.start_party_battle("archive_boss") and _snapshot(s) == before, "Active archive rejects duplicate entry")
	_step(s, "flee")


func test_chapter_mutation_guards() -> void:
	for stage: int in [0, 1, 2, 3]:
		var s = _fixture()
		s.chapter_two_stage = stage
		if stage == 0:
			s.archive_clues.clear()
			s.seal_sequence.clear()
		elif stage == 1:
			s.archive_clues.assign(["clerk"])
			s.seal_sequence.clear()
		s.resources.timber = 2
		s.map_id = "qingwei"
		check(s.start_party_battle("training"), "Chapter mutation fixture opens an unrelated legal party encounter")
		for locked: bool in [false, true]:
			var tx: Dictionary = {}
			if locked:
				tx = s.advance_party_battle()
				check(tx.accepted, "Locked chapter mutation fixture accepts one guard")
			var before: Dictionary = _snapshot(s)
			check(not s.begin_chapter_two() and not s.add_archive_clue("inscription") and not s.try_seal(2).valid and not s.mark_archive_victory() and not s.resolve_chapter_two("open_records") and not s.repair_bridge() and _snapshot(s) == before, "All Chapter wrappers preserve progression, reward and timber during unlocked/locked party combat")
			if locked:
				check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Locked mutation fixture safely acknowledges")
		_step(s, "flee")


func test_terminal_atomicity() -> void:
	for outcome: String in ["win", "flee", "defeat"]:
		var s = _fixture()
		check(s.set_party_roster(["hero"]), "Terminal fixture explicitly selects solo")
		if outcome == "win":
			s.attack = 205 # Mechanical one-action terminal fixture.
		elif outcome == "defeat":
			s.hp = 1
		check(s.start_party_battle("archive_boss"), "Atomic terminal fixture starts")
		var tx: Dictionary = s.party_battle_action("flee") if outcome == "flee" else AutoDriver.terminal_next(s)
		check(tx.accepted and tx.after.outcome == outcome, "Actual model creates the requested locked terminal result")
		var accepted = s._detached_persistent_state()
		var before: Dictionary = _snapshot(s)
		check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 1).accepted and _snapshot(s) == before, "Stale epoch/token leaves terminal result untouched")
		for mutation: Array in [["map_id", "qingwei"], ["quest_stage", 5], ["side_choice", "pursuit"], ["side_found", ["ledger", "boatman"]], ["side_stage", 2], ["side_reward_claimed", false], ["chapter_two_stage", 3], ["archive_clues", ["clerk", "inscription"]], ["seal_sequence", [2, 0]], ["chapter_two_ending", "protect_witness"], ["medicine", -1], ["coins", -1]]:
			_set_value(s, mutation[0], mutation[1])
			before = _snapshot(s)
			check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before and s.battle_active, "All terminal outcomes reject stale context or malformed data without unlocking: " + outcome + "/" + String(mutation[0]))
			s._copy_persistent_from(accepted)
		check(s.finish_party_presentation(tx.epoch, tx.token).settled, "Restored exact entry settles its still-pending token once")
		before = _snapshot(s)
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before, "Successful retry consumes token exactly once")


func test_resource_reward_order() -> void:
	for level_up: bool in [false, true]:
		var s = _fixture()
		s.attack = 205
		s.hp = 13
		s.qi = 0
		s.xp = s.xp_to_next() - 1 if level_up else 0
		s.party_resources.shen = {"hp": 7, "qi": 0}
		check(s.set_party_roster(["hero"]), "Resource-order fixture benches injured Shen")
		var level: int = s.level
		var earned: int = _earned(s)
		check(s.start_party_battle("archive_boss"), "Resource-order fixture enters")
		var tx: Dictionary = s.advance_party_battle()
		check(tx.accepted and s.hp == 13 and s.qi == 2 and s.level == level, "Accepted action mirrors actual HP/qi before XP")
		check(s.finish_party_presentation(tx.epoch, tx.token).settled and _earned(s) == earned + 80, "80XP commits after resource reconciliation")
		check((s.level == level + 1 and s.hp == s.max_hp and s.qi == s.max_qi) if level_up else (s.level == level and s.hp == 13 and s.qi == 2), "Level-up healing follows resources and is never overwritten")
		check(s.party_resources.shen == {"hp": 7, "qi": 0}, "Benched injured actor receives no implicit healing")
	for ending: String in ["open_records", "protect_witness"]:
		var s = _fixture()
		s.attack = 205
		s.coins = 999990
		s.victories = 999999
		check(s.start_party_battle("archive_boss"), "Canonical capped inventory enters")
		_step(s, "advance", "archive_boss")
		check(s.chapter_two_stage == 3 and s.coins == 999999 and s.victories == 999999, "Combat rewards preserve canonical maximum bounds")
		_roundtrip(s, "capped-win-" + ending)
		var won = s._detached_persistent_state()
		for mutation: Array in [["medicine", -1], ["coins", -1], ["seal_sequence", [0]], ["archive_clues", ["clerk"]], ["party_resources", {"shen": {"hp": 1}}]]:
			_set_value(s, mutation[0], mutation[1])
			var before: Dictionary = _snapshot(s)
			check(not s.resolve_chapter_two(ending) and _snapshot(s) == before, "Separate ending rejects malformed data before applying rewards")
			s._copy_persistent_from(won)
		var earned: int = _earned(s)
		check(s.resolve_chapter_two(ending) and s.coins == 999999 and _earned(s) == earned + 100 and s.chapter_two_ending == ending, "Separate ending safely caps coins and preserves its real XP/choice")
		_roundtrip(s, "capped-ending-" + ending)


func test_flee_defeat_retry() -> void:
	var s = _fixture()
	var progress: Dictionary = s._archive_party_progress()
	var earned: int = _earned(s)
	var coins: int = s.coins
	var victories: int = s.victories
	check(s.start_party_battle("archive_boss"), "Flee fixture starts solved archive")
	_step(s, "art:" + s.equipped_art, "archive_boss")
	var spent: Dictionary = s.to_dict()
	var old: Dictionary = _step(s, "flee")
	check(s.to_dict() == spent and s._archive_party_progress() == progress and s.coins == coins and _earned(s) == earned and s.victories == victories, "Flee retains spent qi/proficiency and solved puzzle without rewards")
	_roundtrip(s, "flee")
	check(s.start_party_battle("archive_boss"), "Flee allows an eligible retry")
	var before: Dictionary = _snapshot(s)
	check(not s.finish_party_presentation(old.epoch, old.token).accepted and _snapshot(s) == before, "Previous attempt cannot settle the new epoch")
	_step(s, "flee")
	for purse: int in [5, 21]:
		var defeated = _fixture()
		check(defeated.set_party_roster(["hero"]), "Defeat fixture benches Shen")
		defeated.hp = 1
		defeated.qi = 0
		defeated.party_resources.shen = {"hp": 0, "qi": 0}
		defeated.coins = purse
		check(defeated.start_party_battle("archive_boss"), "Low-resource archive attempt starts")
		var defeated_tx: Dictionary = AutoDriver.terminal_next(defeated)
		check(defeated_tx.get("accepted", false) and defeated.finish_party_presentation(defeated_tx.epoch, defeated_tx.token).settled, "Automatic enemy transaction settles actual defeat")
		check(defeated.party_settlement.outcome == "defeat" and defeated.coins == maxi(0, purse - 8) and defeated.hp == defeated.max_hp and defeated.qi >= 2 and defeated.party_resources.shen.hp > 0 and defeated.party_resources.shen.qi == 2, "Defeat uses existing capped8coin and whole-roster safe recovery")
		check(defeated.map_id == "qingwei" and defeated.position == Vector2(420, 450) and defeated.chapter_two_stage == 2 and defeated.archive_clues == progress.archive_clues and defeated.seal_sequence == [2, 0, 1] and _earned(defeated) == earned and defeated.victories == victories, "Recovery keeps all solved progress and gives no victory reward")
		_roundtrip(defeated, "defeat-" + str(purse))
		check(not defeated.start_party_battle("archive_boss"), "Safe recovery location cannot remotely enter archive")
		defeated.map_id = "frostbridge"
		check(defeated.start_party_battle("archive_boss"), "Returning to actual region allows defeat retry")
		_step(defeated, "flee")


func test_save_failures_and_malformed_loads() -> void:
	var s = _fixture()
	var path: String = fixture_root.path_join("durable.json")
	var bad_path: String = fixture_root.path_join("absent/failure.json")
	check(s.save_game(path) == OK, "Archive pre-entry checkpoint is durable")
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var before: Dictionary = _snapshot(s)
	check(s.save_game(bad_path) != OK and _snapshot(s) == before and FileAccess.get_file_as_bytes(path) == checkpoint, "Failed checkpoint write preserves live and durable state")
	check(s.start_party_battle("archive_boss"), "Save-failure fixture enters")
	var tx: Dictionary = _fight(s, false)
	check(s.save_game(path) == ERR_BUSY and s.load_game(path) == ERR_BUSY and FileAccess.get_file_as_bytes(path) == checkpoint, "Locked terminal cannot overwrite/read the pre-entry checkpoint")
	check(s.finish_party_presentation(tx.epoch, tx.token).settled, "Save-failure fixture settles")
	before = _snapshot(s)
	check(s.save_game(bad_path) != OK and not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == before and FileAccess.get_file_as_bytes(path) == checkpoint, "Failed result save cannot replay rewards or change old save")
	var blocked: String = fixture_root.path_join("blocked")
	check(DirAccess.make_dir_recursive_absolute(blocked) == OK, "Create own atomic-rename failure fixture")
	check(s.save_game(blocked) != OK and not FileAccess.file_exists(blocked + ".tmp") and _snapshot(s) == before, "Failed rename cleans temporary file without settlement mutation")
	check(s.save_game(path) == OK, "Retry saves already-settled result")
	var won: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for mutation: Array in [["archive_clues", ["clerk"]], ["archive_clues", ["clerk", "clerk"]], ["seal_sequence", [2, 0]], ["seal_sequence", [2, 0, 1.5]], ["party_resources", {"shen": {"hp": 1, "qi": 1, "vulnerability_hits": 2}}]]:
		var document: Dictionary = JSON.parse_string(won.get_string_from_utf8())
		document.player[mutation[0]] = mutation[1]
		var malformed: String = fixture_root.path_join("malformed.json")
		var file = FileAccess.open(malformed, FileAccess.WRITE)
		file.store_string(JSON.stringify(document))
		file.close()
		before = _snapshot(s)
		check(s.load_game(malformed) == ERR_FILE_CORRUPT and _snapshot(s) == before and FileAccess.get_file_as_bytes(path) == won, "Malformed schema14 refuses implicit prerequisite repair atomically")
	var loaded = State.new()
	check(loaded.load_game(path) == OK and loaded.to_dict() == s.to_dict() and not loaded.start_party_battle("archive_boss"), "Reloaded stage3 cannot replay archive battle")
	loaded.reset_game()
	check(loaded._party_archive_entry.is_empty(), "Reset clears captured archive entry")


func _rules_step(rules, action: String, target: String = "") -> Dictionary:
	var tx: Dictionary = rules.accept_action(action, target)
	check(tx.accepted, "Detached catalog mechanical action accepts")
	if tx.accepted:
		var counters: Dictionary = {}
		for actor: Dictionary in tx.before.actors:
			counters[actor.id] = int(actor.status.vulnerability_hits)
		for event: Dictionary in tx.events:
			if event.type in ["vulnerability_apply", "vulnerability_consume", "vulnerability_expire"]:
				check(counters.has(event.target_id) and event.remaining >= 0 and event.remaining <= 2, "Archive status event reports a real actor and bounded remaining counter")
				if event.type == "vulnerability_consume":
					check(event.amount == 1 and event.bonus == 3 and event.remaining == int(counters[event.target_id]) - 1, "Archive consumption reports exactly one actual incoming hit")
				elif event.type == "vulnerability_apply":
					check(event.source_id == "archive_boss" and event.amount == 2 and event.remaining == 2 and event.bonus == 3, "Archive application names its unique source and exact two-hit effect")
				else:
					check(event.amount == counters[event.target_id] and event.remaining == 0, "Archive expiry reports the real remaining counter")
				counters[event.target_id] = int(event.remaining)
		for actor: Dictionary in tx.after.actors:
			check(int(actor.status.vulnerability_hits) == counters[actor.id], "Event replay exactly reconstructs each actor's archive vulnerability")
		check(rules.complete_presentation(tx.token), "Detached catalog presentation completes")
	return tx


func test_catalog_mechanics() -> void:
	# Actual later catalog actors only; this source is not eligible story state.
	for formation: String in ["并肩", "护后"]:
		for count: int in range(1, 5):
			var source = State.new()
			source.companion_unlocked = true
			source.tangqi_unlocked = true
			source.qin_stage = 4
			source.qin_unlocked = true
			source.formation = formation
			var ids: Array = ["hero", "shen", "tang", "qin"].slice(0, count)
			var built: Dictionary = Catalog.build_team(source, ids)
			check(built.ok, "Explicit later catalog fixture supports actual actor count " + str(count))
			var rules = Rules.new()
			check(rules.configure(built.team, "archive_boss"), "Archive supports detached capacity1–4 in both formations")
			for round_index: int in range(1, 5):
				var snap: Dictionary = rules.snapshot()
				var intent: Dictionary = snap.enemy_intents[0]
				check(intent.source_id == "archive_boss" and intent.damage == (31 if round_index % 2 == 0 else 17) and intent.heavy == (round_index % 2 == 0), "Archive alternates its exact light/heavy values")
				check(intent.target_id == ids[0 if formation == "护后" else (round_index - 1) % count] and intent.description.contains("破绽2次") == intent.heavy, "Published recipient follows formation and announces heavy vulnerability")
				var last: Dictionary = {}
				for id: String in ids:
					check(rules.select_actor(id), "Each actual actor receives its own turn")
					last = _rules_step(rules, "guard")
				check(_actor(last.after, intent.target_id).status.vulnerability_hits == 0, "Own guard blocks archive heavy application for actual recipient")
			_rules_step(rules, "flee")
	# Two unguarded rounds with low-damage medicine actions avoid killing boss.
	var source = State.new()
	var built: Dictionary = Catalog.build_team(source, ["hero"])
	var rules = Rules.new()
	check(rules.configure(built.team, "archive_boss"), "Solo vulnerability fixture enters")
	_rules_step(rules, "attack", "archive_boss")
	var heavy: Dictionary = _rules_step(rules, "attack", "archive_boss")
	check(_actor(heavy.after, "hero").status.vulnerability_hits == 2 and _actor(heavy.before, "hero").hp - _actor(heavy.after, "hero").hp == 27, "Unguarded archive heavy applies two hits only after actual27HP damage")
	var light: Dictionary = _rules_step(rules, "attack", "archive_boss")
	check(_actor(light.after, "hero").status.vulnerability_hits == 1 and _actor(light.before, "hero").hp - _actor(light.after, "hero").hp == 16, "Next actual light hit consumes one counter and adds exactly3")
	var guarded: Dictionary = _rules_step(rules, "guard")
	check(_actor(guarded.after, "hero").status.vulnerability_hits == 0 and _actor(guarded.before, "hero").hp - _actor(guarded.after, "hero").hp == 9, "Own guard clears prior exposure then rounds heavy damage up")
	var fled: Dictionary = _rules_step(rules, "flee")
	check(fled.after.outcome == "flee" and _actor(fled.after, "hero").status.vulnerability_hits == 0, "Terminal model cleanup leaves no stale vulnerability")


func _mechanical_source(formation: String = "护后", level: int = 1):
	var source = State.new()
	if level > 1:
		source.gain_xp(30 * level * (level - 1))
		check(source.level == level, "Mechanical fixture uses actual level-derived catalog stats")
	# Explicit later catalog capacity only, not story entry or persistence.
	source.companion_unlocked = true
	source.tangqi_unlocked = true
	source.qin_stage = 4
	source.qin_unlocked = true
	source.formation = formation
	return source


func _arena(source, ids: Array = ["hero"], resources: Dictionary = {}):
	var built: Dictionary = Catalog.build_team(source, ids, resources)
	check(built.ok, "Mechanical fixture builds authoritative catalog actors")
	var rules = Rules.new()
	check(rules.configure(built.team, "archive_boss"), "Mechanical fixture configures actual archive encounter")
	return rules


func _events(tx: Dictionary, type: String, phase: String = "") -> Array:
	var result: Array = []
	for event: Dictionary in tx.events:
		if event.type == type and (phase.is_empty() or event.phase == phase):
			result.append(event)
	return result


func _guard_round(rules) -> void:
	var round_number: int = rules.snapshot().round
	for index: int in range(Catalog.MAX_PARTY_SIZE):
		if rules.snapshot().round != round_number:
			return
		_rules_step(rules, "guard")


func test_archive_status_ownership() -> void:
	var source = _mechanical_source("并肩")
	var unchanged: Dictionary = source.to_dict()
	var rules = _arena(source, ["hero", "shen", "tang"])
	_guard_round(rules)
	_rules_step(rules, "guard")
	_rules_step(rules, "attack", "archive_boss")
	var heavy: Dictionary = _rules_step(rules, "guard")
	check(_events(heavy, "vulnerability_apply")[0].target_id == "shen" and _actor(heavy.after, "shen").status.vulnerability_hits == 2 and _actor(heavy.after, "hero").status.vulnerability_hits == 0, "Rotating archive heavy exposes only actual Shen recipient")
	check(not _actor(heavy.after, "shen").exposed and _actor(heavy.after, "tang").exposed, "Persisted vulnerability remains distinct from next announced target")
	var guarded: Dictionary = _rules_step(rules, "guard")
	check(_events(guarded, "vulnerability_expire").is_empty() and _actor(guarded.after, "shen").status.vulnerability_hits == 2, "Hero's guard cannot clear Shen's status")
	var healing: Dictionary = _rules_step(rules, Catalog.SHEN_ART, "shen")
	check(_events(healing, "heal")[0].amount == 28 and _actor(healing.after, "shen").status.vulnerability_hits == 2, "Actual Shen healing restores28 but does not cleanse vulnerability")
	var other: Dictionary = _rules_step(rules, "guard")
	check(_events(other, "damage", "enemy")[0].target_id == "tang" and _actor(other.after, "shen").status.vulnerability_hits == 2, "Another actor's incoming hit never consumes Shen's counter")
	_rules_step(rules, "guard")
	var own_guard: Dictionary = _rules_step(rules, "guard")
	check(_events(own_guard, "vulnerability_expire")[0].target_id == "shen" and _actor(own_guard.after, "shen").status.vulnerability_hits == 0, "Shen's own guard clears her vulnerability immediately")
	check(source.to_dict() == unchanged, "Detached three-actor fixture never changes source save or recruitment")
	var weakened = _arena(_mechanical_source(), ["hero", "tang"])
	_guard_round(weakened)
	_rules_step(weakened, "attack", "archive_boss")
	var weakened_heavy: Dictionary = _rules_step(weakened, Catalog.TANG_ART, "archive_boss")
	check(_events(weakened_heavy, "damage", "enemy")[0].amount == 22 and _actor(weakened_heavy.after, "hero").status.vulnerability_hits == 2, "Tang's existing5point weaken applies before archive heavy vulnerability")
	check(_actor(weakened_heavy.after, "tang").cooldowns[Catalog.TANG_ART] == 2 and weakened_heavy.after.enemies[0].status.weaken_strikes == 1, "Archive preserves actor-owned cooldown and enemy-owned weaken")
	var downed = _arena(_mechanical_source(), ["hero", "shen"], {"hero": {"hp": 34}})
	_guard_round(downed)
	_rules_step(downed, "attack", "archive_boss")
	_rules_step(downed, "guard")
	check(_actor(downed.snapshot(), "hero").hp == 3 and _actor(downed.snapshot(), "hero").status.vulnerability_hits == 2, "Real archive heavy leaves low-health hero at3HP")
	_rules_step(downed, "attack", "archive_boss")
	var down: Dictionary = _rules_step(downed, "guard")
	check(_events(down, "damage", "enemy")[0].amount == 3 and _events(down, "down")[0].target_id == "hero" and _events(down, "vulnerability_expire")[0].reason == "down", "Clipped actual damage and down event expire remaining status")
	check(down.after.active_actor_id == "shen" and down.after.enemy_intents[0].target_id == "shen" and not downed.select_actor("hero"), "Archive retargets survivor and skips downed actor")
	var fallback = _arena(_mechanical_source(), ["hero", "shen"])
	_guard_round(fallback)
	fallback._actor("hero").hp = 0 # Explicit casualty between announcement and execution.
	check(fallback.select_actor("shen"), "Fallback fixture selects its actual survivor")
	var shifted: Dictionary = _rules_step(fallback, "attack", "archive_boss")
	check(_events(shifted, "action", "enemy")[0].announced_target_id == "hero" and _events(shifted, "action", "enemy")[0].target_id == "shen" and _events(shifted, "vulnerability_apply")[0].target_id == "shen", "Archive fallback reports announced hero and actual Shen recipient truthfully")
	var fled = _arena(_mechanical_source())
	_rules_step(fled, "guard")
	_rules_step(fled, "attack", "archive_boss")
	var escape: Dictionary = _rules_step(fled, "flee")
	check(_events(escape, "vulnerability_expire")[0].reason == "battle_end" and _events(escape, "damage", "enemy").is_empty(), "Flee clears active vulnerability without another strike")


func test_archive_barriers_and_guard_arts() -> void:
	for level: int in [1, 10]:
		var rules = _arena(_mechanical_source("护后", level), ["hero", "qin"])
		_guard_round(rules)
		check(rules.select_actor("qin"), "Qin may shield before threatened hero acts")
		var grant: Dictionary = _rules_step(rules, Catalog.QIN_ART, "hero")
		check(_events(grant, "barrier_grant")[0].amount == 18 and _actor(grant.after, "qin").qi == 3, "Existing Qin shield costs3 and grants18")
		var heavy: Dictionary = _rules_step(rules, "attack", "archive_boss")
		check(_events(heavy, "barrier_absorb")[0].amount == 18 and _events(heavy, "damage", "enemy")[0].amount == (9 if level == 1 else 0), "Archive shield absorption uses actual level-derived defense")
		check(_actor(heavy.after, "hero").status.vulnerability_hits == (2 if level == 1 else 0) and _events(heavy, "vulnerability_apply").size() == (1 if level == 1 else 0), "Partial absorption applies vulnerability; full absorption does not")
		check(_actor(heavy.after, "qin").cooldowns[Catalog.QIN_ART] == 2, "Hero/enemy phase do not age Qin's own cooldown")
	var guarded = _arena(_mechanical_source(), ["hero", "qin"])
	_guard_round(guarded)
	guarded.select_actor("qin")
	_rules_step(guarded, Catalog.QIN_ART, "hero")
	var blocked: Dictionary = _rules_step(guarded, "guard")
	check(_events(blocked, "barrier_absorb")[0].amount == 9 and _events(blocked, "barrier_expire")[0].amount == 9 and _events(blocked, "damage", "enemy")[0].amount == 0 and _events(blocked, "vulnerability_apply").is_empty(), "Own guard precedes barrier:9 absorbed,9 expires,0HP damage and no vulnerability")
	var consumed = _arena(_mechanical_source("护后", 14), ["hero", "qin"])
	_guard_round(consumed)
	_rules_step(consumed, "attack", "archive_boss")
	_rules_step(consumed, "guard")
	_rules_step(consumed, "item")
	var light: Dictionary = _rules_step(consumed, "guard")
	check(_events(light, "damage", "enemy")[0].amount == 4 and _actor(light.after, "hero").status.vulnerability_hits == 1, "Defense floors archive light to1 before existing vulnerability adds3")
	consumed.select_actor("qin")
	_rules_step(consumed, Catalog.QIN_ART, "hero")
	var expired: Dictionary = _rules_step(consumed, "attack", "archive_boss")
	check(_events(expired, "barrier_absorb")[0].incoming_after_guard == 17 and _events(expired, "damage", "enemy")[0].amount == 0, "Shield absorbs full archive heavy14 plus vulnerability3")
	check(_events(expired, "vulnerability_consume")[0].remaining == 0 and _events(expired, "vulnerability_apply").is_empty() and _actor(expired.after, "hero").status.vulnerability_hits == 0, "Fully blocked incoming hit still consumes its existing counter and cannot refresh")
	for art: String in ["磐石回锋", "藏锋立岳"]:
		var source = _mechanical_source()
		source.choose_sect("问石门")
		if art == "藏锋立岳":
			source.sect_rank = 2
			source.sect_merit = 3
			check(source.learn_art(art), "Prepared inner disciple spends actual merit to learn guard art")
		check(source.equip_art(art), "Guard-art fixture equips the real eligible art")
		var rules = _arena(source)
		_rules_step(rules, "guard")
		_rules_step(rules, "attack", "archive_boss")
		check(rules.action_description("art:" + art).contains("清除自身破绽"), "Archive guard art describes actual self-cleansing")
		var tx: Dictionary = _rules_step(rules, "art:" + art, "archive_boss")
		check(_events(tx, "vulnerability_expire")[0].reason == "guard" and _events(tx, "vulnerability_consume").is_empty() and _events(tx, "damage", "enemy")[0].amount == 3, "Both actual guard arts cleanse before defense/guard-rounded damage")
		check(_actor(tx.after, "hero").cooldowns["art:" + art] == source.Arts.definition(art).cooldown, "Guard arts retain independent original cooldown")


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
