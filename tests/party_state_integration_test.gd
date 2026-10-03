extends SceneTree
## Files are confined to a unique directory under an explicitly isolated XDG.
## The old-reader fixture is byte-exact game_state.gd from commit
## 4e523c44356480ba9722934eb4cbee68c1e315ca (pre-schema12, source-only checkpoint).
const State = preload("res://scripts/game_state.gd")
const AutoDriver = preload("res://tests/automatic_state_test_driver.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const OLD_PATH = "res://tests/fixtures/v020_game_state.gd.txt"
const OLD_SHA256 = "fbd0cef61329356ba3f7fd17bf2fa861ddd149d4d565916711685e0c4c5aac30"
var checks: int = 0
var failures: int = 0
var fixture_root: String


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME for party state checks")
		quit(2)
		return
	fixture_root = "user://party-state-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Create isolated save fixture fixture_root")
	test_roster_resources()
	test_migration_and_reader()
	test_strict_loads()
	test_entry_and_transactions()
	test_outcomes()
	test_receipt_and_persistence()
	test_prepared_four_member_state()
	test_qin_natural_recruitment()
	_remove_tree(fixture_root)
	check(not DirAccess.dir_exists_absolute(fixture_root), "Remove only this isolated test fixture_root")
	if failures == 0:
		print("PASS: %d party state integration checks (schema14/migration/selection/transactions/settlement/save safety)" % checks)
	else:
		push_error("FAIL: %d / %d party state integration checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _write(path: String, data: Dictionary, version: int = State.SAVE_VERSION) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": version, "player": data}))
	file.close()


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _snapshot(s) -> Dictionary:
	return {"save": s.to_dict(), "party": s.party_battle_snapshot(), "active": s.battle_active,
		"epoch": s.party_battle_epoch, "settlement": s.party_settlement, "kind": s.battle_kind}


func _all_recruited():
	var s = State.new()
	check(s.recruit_companion(), "Real Shen invitation creates persistent actor resources")
	s.quest_stage = 6
	s.ending = "守望"
	s.side_stage = 3
	s.side_choice = "rescue"
	s.side_found.assign(["boatman", "ledger"])
	s.side_clues = 2
	s.side_reward_claimed = true
	s.chapter_two_stage = 4
	s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"])
	s.seal_sequence.assign([2, 0, 1])
	s.bridge_repaired = true
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Tang follows actual personal quest and invitation APIs")
	return s


func _port(ending: String = "short_ferries"):
	var s = _all_recruited()
	s.mist_stage = 4
	s.mist_approach = "duel"
	s.mist_gauges.assign(["rain", "stone", "basin"])
	s.mist_ending = "release_water"
	s.heting_stage = 4
	s.heting_bridge = "east"
	s.heting_delivered.assign(["meal", "sealed", "reserve"])
	s.heting_draft = ending
	s.heting_ending = ending
	s.map_id = "heting"
	s.position = Vector2(420, 220)
	check(s.begin_receipt(), "Actual optional receipt quest begins after harbor ending")
	return s


func _actor(s, id: String) -> Dictionary:
	for actor: Dictionary in s.party_resource_snapshot().actors:
		if actor.id == id:
			return actor
	return {}


func _earned(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)


func _step(s, action: String, target: String = "") -> Dictionary:
	var tx: Dictionary
	if action == "advance": tx = s.advance_party_battle()
	elif action.begins_with("art:"): tx = AutoDriver.queued_next(s, "hero", action, target)
	else: tx = s.party_battle_action(action, target)
	check(tx.accepted, "Accepted independent action: " + action)
	if tx.accepted:
		var completed: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
		check(completed.accepted, "Matching presentation completes: " + action)
	return tx


func _win(s) -> Dictionary:
	var last: Dictionary = {}
	for index: int in range(400):
		if not s.battle_active: break
		last = AutoDriver.tactical_next(s)
		check(last.get("accepted", false), "Actual scheduler accepts queued tactics or automatic basic")
		if not last.get("accepted", false): break
		check(s.finish_party_presentation(last.epoch, last.token).accepted, "Actual scheduler transaction acknowledges")
	check(not s.battle_active and s.party_settlement.get("outcome") == "win", "Bounded ordinary actions naturally reach a settled victory")
	return last


func test_roster_resources() -> void:
	var s = State.new()
	check(s.party_roster == ["hero"] and s.party_resources.is_empty() and s.current_companion().is_empty(), "New state has explicit solo selection and no phantom resources")
	check(s.recruit_companion(), "Shen invitation succeeds")
	check(s.party_roster == ["hero", "shen"] and s.party_resources.shen == {"hp": _actor(s, "shen").max_hp, "qi": _actor(s, "shen").max_qi}, "Invited actor joins at authoritative catalog maxima")
	s.party_resources.shen = {"hp": 7, "qi": 0}
	s.hp = 17
	s.qi = 1
	for index: int in range(12):
		check(s.set_party_roster(["hero"]) and s.current_companion().is_empty(), "Explicit hero-only roster has no legacy fallback")
		check(s.select_companion("沈青") and s.party_resources.shen == {"hp": 7, "qi": 0} and s.hp == 17 and s.qi == 1, "Deselect/reselect preserves all damage and spent qi")
	check(not s.set_party_roster(["hero", "tang"]) and not s.set_party_roster(["shen", "hero"]) and not s.set_party_roster(["hero", "shen", "shen"]), "Unknown, unrecruited, unordered and duplicate selections reject")
	s.set_party_roster(["hero"])
	s.quest_stage = 6
	s.chapter_two_stage = 4
	s.bridge_repaired = true
	s.begin_tangqi_quest()
	s.recover_craft_notes()
	s.resolve_tangqi_quest("preserve")
	check(s.recruit_tangqi() and s.party_roster == ["hero", "tang"], "Tang invitation enrolls only the invited actor from explicit solo selection")
	check(s.party_resources.shen == {"hp": 7, "qi": 0}, "Recruiting Tang never heals the benched Shen")
	check(s.set_party_roster(["hero", "tang", "shen"]), "Three-member roster preserves explicit companion order")
	s.party_resources.tang = {"hp": 0, "qi": 1}
	s.set_party_roster(["hero"])
	var prior: Dictionary = s.party_resources.duplicate(true)
	var level_before: int = s.level
	s.gain_xp(s.xp_to_next())
	check(s.level > level_before and s.hp == s.max_hp and s.qi == s.max_qi and s.party_resources == prior, "XP refills hero once while preserving downed and benched companion resources")
	check(s.party_resource_snapshot().is_read_only() and s.party_resource_snapshot().actors.is_read_only(), "Independent readout is deeply immutable")
	s.heal_rest()
	for id: String in ["shen", "tang"]:
		check(s.party_resources[id] == {"hp": _actor(s, id).max_hp, "qi": _actor(s, id).max_qi}, "Explicit rest restores every recruited actor using current maxima: " + id)
	check(s.party_roster == ["hero"], "Rest never changes selected roster")


func test_migration_and_reader() -> void:
	var original = _all_recruited()
	original.gain_xp(900)
	original.hp = 17
	original.qi = 1
	var path: String = fixture_root.path_join("migration.json")
	for version: int in range(1, 12):
		for choice: String in ["沈青", "唐栖", ""]:
			var data: Dictionary = original.to_dict()
			data.erase("party_roster")
			data.erase("party_resources")
			data.active_companion = choice
			_write(path, data, version)
			var bytes_before: PackedByteArray = _bytes(path)
			var loaded = State.new()
			check(loaded.load_game(path) == OK, "Actual schema%d migration accepts recruited historical state" % version)
			var expected: String = "tang" if choice == "唐栖" else "shen"
			check(loaded.party_roster == ["hero", expected] and loaded.hp == 17 and loaded.qi == 1, "Schema%d migration preserves selected companion and hero injury" % version)
			check(loaded.party_resources.size() == 2 and loaded.qin_stage == 0 and not loaded.qin_unlocked and _bytes(path) == bytes_before, "Migration initializes both resources without rewriting source bytes")
			for id: String in ["shen", "tang"]:
				check(loaded.party_resources[id] == {"hp": _actor(loaded, id).max_hp, "qi": _actor(loaded, id).max_qi}, "Legacy initialization uses catalog level maxima: " + id)
	var ignored_qin: Dictionary = original.to_dict()
	ignored_qin.erase("party_roster")
	ignored_qin.erase("party_resources")
	ignored_qin.qin_stage = 4
	ignored_qin.qin_unlocked = true
	_write(path, ignored_qin, 11)
	var legacy_qin = State.new()
	check(legacy_qin.load_game(path) == OK and legacy_qin.qin_stage == 0 and not legacy_qin.qin_unlocked and not legacy_qin.party_resources.has("qin"), "Schema11 cannot acquire the new fourth member from ignored future quest fields")
	var solo: Dictionary = State.new().to_dict()
	solo.erase("party_roster")
	solo.erase("party_resources")
	_write(path, solo, 1)
	var loaded = State.new()
	check(loaded.load_game(path) == OK and loaded.party_roster == ["hero"] and loaded.party_resources.is_empty(), "Legacy unrecruited save stays solo")
	check(FileAccess.get_sha256(OLD_PATH) == OLD_SHA256, "Frozen schema11 reader matches recorded exact source SHA256")
	var old_script = GDScript.new()
	old_script.source_code = FileAccess.get_file_as_string(OLD_PATH).replace("class_name HeroState\n", "")
	check(old_script.reload() == OK, "Exact historical reader compiles after removing only global class registration")
	var old = old_script.new()
	old.coins = 71
	old.hp = 23
	var old_before: Dictionary = old.to_dict()
	check(original.save_game(path) == OK, "Write actual schema14 save for old-reader rejection")
	var current_bytes: PackedByteArray = _bytes(path)
	check(old.load_game(path) == ERR_FILE_UNRECOGNIZED and old.to_dict() == old_before and _bytes(path) == current_bytes, "Exact schema11 reader rejects schema14 without touching state or file")
	var predecessor_path: String = "res://tests/fixtures/v022_game_state.gd.txt"
	check(FileAccess.get_sha256(predecessor_path) == "7872904b27c52b2fe038b6f355a371ca8e9f90d1054c3be24a5dd912bea8a02a", "Frozen schema12 reader matches independently recorded exact SHA256")
	var predecessor = GDScript.new()
	predecessor.source_code = FileAccess.get_file_as_string(predecessor_path).replace("class_name HeroState\n", "")
	check(predecessor.reload() == OK, "Frozen schema12 reader compiles with only class registration removed")
	var old12 = predecessor.new()
	old12.hp = 19; old12.coins = 417; old12.battle_active = true; old12.enemy_hp = 11
	var old12_before: Dictionary = old12.to_dict()
	check(old12.load_game(path) == ERR_FILE_UNRECOGNIZED and old12.to_dict() == old12_before and old12.battle_active and old12.enemy_hp == 11 and _bytes(path) == current_bytes, "Exact schema12 reader rejects14 before changing persistent, transient, or disk state")
	var previous: Dictionary = original.to_dict()
	previous.erase("internal_unlocked")
	for field: String in State.Consignee.FIELDS: previous.erase(field)
	_write(path, previous, 12)
	var previous_bytes: PackedByteArray = _bytes(path)
	var migrated12 = State.new()
	check(migrated12.load_game(path) == OK and not migrated12.internal_unlocked and migrated12.party_roster == original.party_roster and migrated12.party_resources == original.party_resources and migrated12.hp == 17 and migrated12.qi == 1 and _bytes(path) == previous_bytes, "Complete schema12 migrates unchanged resources/roster without fabricating internal lesson or rewriting bytes")


func _reject_load(s, data: Dictionary, label: String, version: int = State.SAVE_VERSION) -> void:
	var path: String = fixture_root.path_join("invalid.json")
	_write(path, data, version)
	var prior: Dictionary = _snapshot(s)
	var bytes_before: PackedByteArray = _bytes(path)
	check(s.load_game(path) == ERR_FILE_CORRUPT, label + " rejects")
	check(_snapshot(s) == prior and _bytes(path) == bytes_before, label + " leaves all live state and bytes unchanged")


func test_strict_loads() -> void:
	var live = _all_recruited()
	live.hp = 13
	live.coins = 812
	var good: Dictionary = live.to_dict()
	for key: String in good:
		var missing: Dictionary = good.duplicate(true)
		missing.erase(key)
		_reject_load(live, missing, "Missing schema14 field " + key)
	for roster: Variant in [[], ["shen", "hero"], ["hero", "hero"], ["hero", "ghost"], ["hero", "shen", "tang", "hero"], "hero", null]:
		var data: Dictionary = good.duplicate(true)
		data.party_roster = roster
		_reject_load(live, data, "Malformed roster " + str(roster))
	for resources: Variant in [{}, {"shen": {"hp": 1, "qi": 2}}, {"shen": {"hp": 1, "qi": 2}, "tang": {"hp": 1, "qi": 2}, "hero": {"hp": 1, "qi": 2}}, [], null]:
		var data: Dictionary = good.duplicate(true)
		data.party_resources = resources
		_reject_load(live, data, "Incomplete or extra companion resources")
	for key: String in ["hp", "qi"]:
		for invalid: Variant in [-1, 0.5, true, "1", 1e50, null]:
			var data: Dictionary = good.duplicate(true)
			data.party_resources.shen[key] = invalid
			_reject_load(live, data, "Invalid companion scalar " + key)
			data = good.duplicate(true)
			data[key] = invalid
			_reject_load(live, data, "Invalid raw hero scalar " + key)
	var zero: Dictionary = good.duplicate(true)
	zero.hp = 0
	_reject_load(live, zero, "Raw schema14 heroHP0 cannot hide behind old loader clamp")
	var extra: Dictionary = good.duplicate(true)
	extra.party_resources.shen.max_hp = 999
	_reject_load(live, extra, "Unknown companion entry field")
	extra = good.duplicate(true)
	extra.party_session = {}
	_reject_load(live, extra, "Transient or unknown persisted field")
	for key: String in ["level", "xp", "coins", "quest_stage"]:
		var data: Dictionary = good.duplicate(true)
		data[key] = 1.25
		_reject_load(live, data, "Fractional current core field " + key)
	var path: String = fixture_root.path_join("roundtrip.json")
	live.party_resources.shen = {"hp": 0, "qi": 0}
	live.party_resources.tang = {"hp": 4, "qi": 1}
	live.set_party_roster(["hero"])
	live.position = Vector2(1406.1234, 42.98765)
	check(live.save_game(path) == OK, "Explicit solo and downed bench serialize")
	var loaded = State.new()
	check(loaded.load_game(path) == OK and loaded.to_dict() == live.to_dict() and loaded.current_companion().is_empty(), "Schema14 roundtrip retains solo roster and every benched injury")


func test_entry_and_transactions() -> void:
	var s = State.new()
	check(not s.start_party_battle("story") and not s.start_party_battle("training") and not s.start_party_battle("heting_receipt") and not s.start_party_battle("unknown"), "Encounter entry enforces actual narrative eligibility")
	s.quest_stage = 3
	s.recruit_companion()
	s.hp = 65
	s.party_resources.shen = {"hp": 17, "qi": 3}
	var path: String = fixture_root.path_join("gate.json")
	check(s.save_game(path) == OK and s.start_party_battle("story"), "Pre-entry checkpoint followed by real party story entry")
	var checkpoint: PackedByteArray = _bytes(path)
	var before: Dictionary = _snapshot(s)
	check(not s.start_party_battle("story") and not s.set_party_roster(["hero"]) and not s.recruit_tangqi() and not s.select_companion(""), "Active session blocks duplicate encounter and roster/recruitment mutations")
	check(s.save_game(path) == ERR_BUSY and s.load_game(path) == ERR_BUSY and _bytes(path) == checkpoint, "Active party save/load preserves checkpoint")
	s.heal_rest()
	s.choose_sect("听潮阁")
	check(not s.buy_equipment() and not s.choose_side_route("rescue"), "Party gate also blocks old out-of-battle resource/progression entry points")
	s.gain_xp(600)
	check(not s.battle_action("attack").valid and _snapshot(s) == before, "Rest/XP/legacy attack cannot bypass independent party transaction")
	check(s.select_party_actor("shen"), "Controller selects a living companion actor")
	var initial: Dictionary = _step(s, "advance")
	check(initial.source_id == "hero" and initial.action_id == "attack" and initial.after.enemies[0].hp == 80 and s._companion_attack_count == 0, "Automatic hero basic applies exact16 damage without legacy assist")
	var tx: Dictionary = AutoDriver.queued_next(s, "shen", Catalog.SHEN_ART, "hero")
	check(tx.accepted and tx.source_id == "shen" and s.party_resources.shen.qi == 0 and s.hp == 93, "Shen action spends only her qi and heals selected living hero")
	check(tx.is_read_only() and tx.after.actors.is_read_only() and tx.epoch == s.party_battle_epoch, "Transaction remains deeply immutable with owner epoch")
	var pending_resources: Dictionary = s.to_dict()
	check(not s.party_battle_action("attack").accepted and not s.advance_party_battle().accepted and s.select_party_actor("hero") and s.select_party_target("puheng") and s.to_dict() == pending_resources and tx.source_id == "shen" and tx.target_id == "hero", "Presentation blocks duplicate execution while next-command selection preserves exact committed actor/target/resources")
	var pending: Dictionary = _snapshot(s)
	check(not s.finish_party_presentation(tx.epoch + 1, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token + 1).accepted and _snapshot(s) == pending, "Bad epoch/token leaves transaction pending and state unchanged")
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted and not s.finish_party_presentation(tx.epoch, tx.token).accepted, "Accepted presentation completes exactly once")
	var attack: Dictionary = _step(s, "advance")
	check(attack.source_id == "shen" and attack.action_id == "attack" and attack.after.actors[1].basic_done, "Shen still receives her automatic basic after her optional queued heal")
	s.select_party_actor("hero")
	var art: Dictionary = _step(s, "art:" + s.equipped_art, "puheng")
	check(art.accepted and s.art_uses[s.equipped_art] == 1 and s.qi == art.after.actors[0].qi, "Hero art proficiency and qi mirror once from accepted actor action")
	_step(s, "flee")
	check(s.party_settlement.outcome == "flee" and s.save_game(path) == OK, "Flee can settle and serialize consumed resources")
	check(s.start_party_battle("story"), "A new attempt gets a fresh session after settlement")
	var fresh: Dictionary = _snapshot(s)
	check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(s) == fresh, "Old epoch cannot settle a later attempt")
	_step(s, "flee")


func test_outcomes() -> void:
	var story = State.new()
	story.quest_stage = 3
	story.recruit_companion()
	story.party_resources.shen = {"hp": 9, "qi": 1}
	story.set_party_roster(["hero"])
	story.attack = 100
	story.hp = 14
	story.qi = 0
	var old_coins: int = story.coins
	check(story.start_party_battle("story"), "Eligible story begins once")
	var tx: Dictionary = story.advance_party_battle()
	check(tx.after.outcome == "win" and story.battle_active and story.quest_stage == 3 and story.coins == old_coins and story.hp == 14, "Accepted terminal win postpones rewards and hero level recovery until presentation")
	var prior: Dictionary = _snapshot(story)
	check(story.save_game(fixture_root.path_join("no-terminal.json")) == ERR_BUSY and story.load_game(fixture_root.path_join("missing.json")) == ERR_BUSY and not story.set_party_roster(["hero", "shen"]) and _snapshot(story) == prior, "Terminal presentation pending blocks save/load/selection")
	story.quest_stage = 4
	var stale_progress: Dictionary = _snapshot(story)
	check(not story.finish_party_presentation(tx.epoch, tx.token).accepted and _snapshot(story) == stale_progress and story.battle_active, "Invalid detached settlement leaves token locked with no partial reward")
	story.quest_stage = 3
	var completed: Dictionary = story.finish_party_presentation(tx.epoch, tx.token)
	check(completed.settled and completed.outcome == "win" and story.quest_stage == 4 and story.victories == 1 and story.coins == old_coins + 26, "Story settlement atomically awards existing rewards and advances main quest to4")
	check(story.level == 2 and story.hp == story.max_hp and story.qi == story.max_qi and story.party_resources.shen == {"hp": 9, "qi": 1}, "Post-XP hero refill survives growth reconciliation while benched damage persists")
	prior = _snapshot(story)
	check(not story.finish_party_presentation(tx.epoch, tx.token).accepted and not story.start_party_battle("story") and _snapshot(story) == prior, "Story reward and presentation cannot be replayed")
	var earned_before: int = _earned(story)
	old_coins = story.coins
	check(story.start_party_battle("training"), "Training unlocks after opening victory")
	_step(story, "advance")
	check(_earned(story) == earned_before + 30 and story.coins == old_coins + 12 and story.quest_stage == 4, "Training preserves existing30XP/12coin reward and main progress")
	var survivor = _all_recruited()
	survivor.xp = 0
	survivor.hp = 1
	survivor.qi = 0
	survivor.attack = 1
	check(survivor.start_party_battle("training"), "Three-member survivor fixture enters an eligible training encounter")
	for index: int in range(12):
		if survivor.hp == 0 or not survivor.battle_active: break
		_step(survivor, "advance")
	check(survivor.hp == 0 and survivor.battle_active and survivor.party_battle_snapshot().active, "Hero stays down while both genuinely recruited companions continue")
	for index: int in range(80):
		if not survivor.battle_active:
			break
		_step(survivor, "advance")
	check(survivor.party_settlement.outcome == "win" and survivor.hp == 1 and survivor.xp == 30 and survivor.level == 1, "Surviving companions win naturally; no-level-up settlement uses only heroHP1 floor")
	for outcome: String in ["flee", "defeat"]:
		var s = State.new()
		s.quest_stage = 3
		s.recruit_companion()
		s.hp = 1
		s.qi = 0
		s.party_resources.shen = {"hp": 30 if outcome == "flee" else 1, "qi": 0}
		s.medicine = 0
		s.attack = 1
		s.coins = 5
		check(s.start_party_battle("story"), "Low-resource party starts " + outcome)
		for index: int in range(12):
			if s.hp == 0 or not s.battle_active: break
			_step(s, "advance")
		if outcome == "flee":
			check(s.hp == 0 and s.battle_active and s.party_battle_snapshot().active, "Hero-down state stays in battle while a companion survives")
			var before_flee: Dictionary = s.to_dict()
			var flee: Dictionary = s.party_battle_action("flee")
			check(flee.accepted and s.hp == 0 and s.to_dict() == before_flee, "Accepted survivor flee does not apply hero survival floor before token")
			check(s.finish_party_presentation(flee.epoch, flee.token).settled and s.hp == 1 and s.qi == before_flee.qi and s.party_resources == before_flee.party_resources and s.medicine == 0 and s.coins == 5 and s.victories == 0, "Survivor flee applies only outside-combat heroHP1 and retains real costs")
		else:
			# Story attacks deterministically target exposed living actors. Continue
			# actual weak attacks until both low-health actors are down.
			for index: int in range(80):
				if not s.battle_active:
					break
				_step(s, "advance", "puheng")
			check(s.party_settlement.get("outcome") == "defeat" and s.coins == 0 and s.hp == s.max_hp and s.qi >= 2 and s.party_resources.shen.hp == _actor(s, "shen").max_hp, "Natural total defeat recovers all actorHP/qi floor and loses no more available5coins")
			check(s.map_id == "qingwei" and s.position == Vector2(420, 450) and s.quest_stage == 3 and s.victories == 0, "Defeat returns to original safe village location without quest reward")


func test_receipt_and_persistence() -> void:
	for ending: String in ["short_ferries", "open_scale"]:
		var s = _port(ending)
		s.gain_xp(2700)
		s.heal_rest()
		s.party_resources.shen = {"hp": 7, "qi": 0}
		s.set_party_roster(["hero", "tang"])
		var store = Slots.new(fixture_root)
		var path: String = store.path_for(1)
		check(store.save_slot(s, 1) == OK, "Real isolated manual slot accepts complete pre-entry receipt state")
		var checkpoint: PackedByteArray = _bytes(path)
		var earned_before: int = _earned(s)
		var coins_before: int = s.coins
		var victories_before: int = s.victories
		check(s.start_party_battle("heting_receipt"), "Independent receipt starts for harbor ending " + ending)
		check(store.save_slot(s, 1) == ERR_BUSY and store.load_slot(s, 1) == ERR_BUSY and store.load_backup(s, 1) == ERR_BUSY and _bytes(path) == checkpoint, "Slot and backup routes respect active party gate")
		var final_tx: Dictionary = _win(s)
		check(s.receipt_stage == 2 and _earned(s) == earned_before + 80 and s.coins == coins_before + 40 and s.victories == victories_before + 1, "Receipt stage2 and once-only80XP/40coins settle atomically")
		check(s.heting_ending == ending and s.heting_draft == ending and s.heting_delivered == ["meal", "sealed", "reserve"] and s.party_resources.shen == {"hp": 7, "qi": 0}, "Receipt keeps original harbor ending, deliveries and benched injuries intact")
		var won: Dictionary = s.to_dict()
		check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Create isolated temporary-file write failure")
		check(s.save_game(path) != OK and _bytes(path) == checkpoint and s.to_dict() == won, "Forced save failure preserves old checkpoint and settled memory")
		check(not s.finish_party_presentation(final_tx.epoch, final_tx.token).accepted and not s.start_party_battle("heting_receipt") and s.to_dict() == won, "Failed persistence cannot replay accepted reward or restart won receipt")
		DirAccess.remove_absolute(path + ".tmp")
		check(store.save_slot(s, 1) == OK and _bytes(path + ".bak") == checkpoint, "Retry saves identical awarded state and preserves exact original backup")
		var loaded = State.new()
		check(store.load_slot(loaded, 1) == OK and loaded.to_dict() == won and loaded.party_session == null, "Reload recovers precisely one award with no transient session")
		var settled_bytes: PackedByteArray = _bytes(path)
		check(store.save_slot(s, 1) == OK and _bytes(path) == settled_bytes and _bytes(path + ".bak") == checkpoint, "Serialization retry neither rewrites nor rotates the recovery checkpoint")
		check(loaded.compare_receipt() and loaded.receipt_stage == 3 and loaded.heting_ending == ending, "Both existing receipt narrative endings retain their final comparison")
		var backup = State.new()
		check(store.load_backup(backup, 1) == OK and backup.receipt_stage == 1 and _earned(backup) == earned_before, "Backup restores original pre-entry progress without reward")
		# Serialization is validated before opening .tmp, so a malformed live
		# resource value cannot replace the last valid save.
		var invalid_before: PackedByteArray = _bytes(path)
		s.party_resources.tang.qi = -1
		check(s.save_game(path) == ERR_FILE_CORRUPT and _bytes(path) == invalid_before and not FileAccess.file_exists(path + ".tmp"), "Serialization failure leaves previous valid primary byte-exact")
		_remove_tree(fixture_root.path_join("hero_slot_1.json.bak"))
	var defeat = _port()
	defeat.set_party_roster(["hero"])
	defeat.hp = 1
	defeat.qi = 0
	defeat.coins = 21
	defeat.party_resources.shen = {"hp": 0, "qi": 0}
	defeat.party_resources.tang = {"hp": 3, "qi": 1}
	check(defeat.start_party_battle("heting_receipt"), "Receipt low-HP defeat attempt begins")
	var defeat_tx: Dictionary = AutoDriver.terminal_next(defeat)
	check(defeat_tx.get("accepted", false) and defeat.finish_party_presentation(defeat_tx.epoch, defeat_tx.token).settled, "Actual automatic enemy attack settles receipt defeat")
	check(defeat.party_settlement.outcome == "defeat" and defeat.receipt_stage == 1 and defeat.coins == 13 and defeat.map_id == "heting" and defeat.position == Vector2(230, 735), "Receipt defeat retains retry stage and recovers at harbor safe location with8coin cap")
	check(defeat.party_resources.shen.hp == _actor(defeat, "shen").max_hp and defeat.party_resources.tang.hp == _actor(defeat, "tang").max_hp and defeat.party_resources.shen.qi == 2, "Explicit defeat recovery includes downed and benched recruited members")
	check(defeat.start_party_battle("heting_receipt"), "Defeated receipt can retry with fresh epoch")
	_step(defeat, "flee")
	check(defeat.receipt_stage == 1 and defeat.party_settlement.outcome == "flee", "Receipt retreat keeps retry eligibility without reward")


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


func test_prepared_four_member_state() -> void:
	# Prepared stage fixtures exercise this state boundary. The independent
	# Qin quest tests own the full natural acceptance/check/handoff route.
	var s = _port()
	var prior: Dictionary = s.to_dict()
	check(not s._recruit_party_companion("qin") and s.to_dict() == prior, "Qin is never granted without explicit stage3 invitation eligibility")
	for stage: int in range(1, 4):
		s.qin_stage = stage
		var offered: String = fixture_root.path_join("qin-stage%d.json" % stage)
		check(s.save_game(offered) == OK, "Unrecruited optional Qin quest stage serializes: %d" % stage)
		var pending_qin = State.new()
		check(pending_qin.load_game(offered) == OK and pending_qin.qin_stage == stage and not pending_qin.qin_unlocked and not pending_qin.party_resources.has("qin") and not pending_qin.select_companion("秦禾"), "Accepting/checking/handoff never silently recruits or selects Qin: %d" % stage)
	s.qin_stage = 3
	s.party_resources.shen = {"hp": 3, "qi": 0}
	s.party_resources.tang = {"hp": 5, "qi": 1}
	s.set_party_roster(["hero", "tang", "shen"])
	check(s._recruit_party_companion("qin") and s.qin_stage == 4 and s.qin_unlocked, "Prepared handoff invitation atomically consumes stage3 and recruits Qin")
	check(s.party_roster == ["hero", "tang", "shen", "qin"] and s.party_resources.size() == 3, "Fourth-member invitation preserves prior order and adds only genuinely recruited Qin")
	check(s.party_resources.qin == {"hp": _actor(s, "qin").max_hp, "qi": _actor(s, "qin").max_qi} and s.party_resources.shen.hp == 3 and s.party_resources.tang.hp == 5, "New fourth member uses real catalog maxima without healing older members")
	prior = s.to_dict()
	check(not s._recruit_party_companion("qin") and s.to_dict() == prior, "Repeated fourth-member invitation cannot duplicate resources")
	var path: String = fixture_root.path_join("prepared-four.json")
	check(s.save_game(path) == OK, "Prepared four-member persistent state serializes")
	var loaded = State.new()
	check(loaded.load_game(path) == OK and loaded.to_dict() == s.to_dict(), "All four actors and Qin quest stage roundtrip")
	for bad: Array in [[-1, false], [0.5, false], [5, true], [3, true], [4, false]]:
		var data: Dictionary = s.to_dict()
		data.qin_stage = bad[0]
		data.qin_unlocked = bad[1]
		_reject_load(s, data, "Inconsistent Qin persistent stage")
	var no_quest: Dictionary = s.to_dict()
	no_quest.qin_stage = 0
	no_quest.qin_unlocked = false
	_reject_load(s, no_quest, "Roster cannot include unearned Qin")
	s.hp = 49
	s.qi = 1
	s.set_party_roster(["hero"])
	check(s.current_companion().is_empty() and s.party_resources.qin.hp == _actor(s, "qin").max_hp, "Explicit solo roster stays solo even after fourth member recruitment")
	s.party_resources.qin = {"hp": 9, "qi": 0}
	check(s.select_companion("秦禾") and s.party_roster == ["hero", "qin"] and s.current_companion() == "秦禾" and s.party_resources.qin == {"hp": 9, "qi": 0}, "Named Qin selection is explicit and cannot heal resources")
	s.set_party_roster(["hero", "shen", "tang", "qin"])
	s.heal_rest()
	check(s.start_party_battle("heting_receipt") and s.party_battle_snapshot().actors.size() == 4, "Prepared recruited four-member party configures the actual model")
	check(s.select_party_actor("qin"), "Controller can explicitly select Qin")
	var tx: Dictionary = AutoDriver.queued_next(s, "qin", "art:qin_shoudu", "qin")
	check(tx.get("accepted", false) and s.finish_party_presentation(tx.epoch, tx.token).accepted, "Explicit queued Qin skill executes through scheduler and acknowledges")
	check(tx.accepted and tx.source_id == "qin" and s.party_resources.qin.qi == tx.after.actors[3].qi and s.hp == s.max_hp, "Qin guard action commits only his actual resources with real four-actor facts")
	_step(s, "flee")
	check(s.party_settlement.outcome == "flee" and s.party_roster.size() == 4 and s.qin_stage == 4, "Four-member retreat settles without discarding Qin recruitment")


func test_qin_natural_recruitment() -> void:
	for ending: String in ["release_water", "warn_ferries"]:
		var s = _all_recruited()
		s.mist_stage = 4
		s.mist_approach = "duel"
		s.mist_gauges.assign(["rain", "stone", "basin"])
		s.mist_ending = ending
		s.map_id = "mistwood"
		s.set_party_roster(["hero"])
		s.hp = 17
		s.qi = 1
		s.party_resources.shen = {"hp": 3, "qi": 0}
		s.party_resources.tang = {"hp": 4, "qi": 1}
		var before_xp: int = _earned(s)
		var before_coins: int = s.coins
		var before_items: Dictionary = s.resources.duplicate(true)
		var before_medicine: int = s.medicine
		var path: String = fixture_root.path_join("qin-natural-" + ending + ".json")
		var sequence: Array[Callable] = [s.begin_qin_quest, s.inspect_qin_rope, s.arrange_qin_handoff, s.recruit_qin]
		for index: int in range(sequence.size()):
			check(sequence[index].call() and s.qin_stage == index + 1, "Real Qin quest method advances exactly one stage after " + ending)
			var progress: Dictionary = s.to_dict()
			check(not sequence[index].call() and s.to_dict() == progress, "Repeated real Qin quest callback is a no-op")
			check(s.save_game(path) == OK, "Real Qin route stage saves without reward")
			var resumed = State.new()
			check(resumed.load_game(path) == OK and resumed.to_dict() == s.to_dict(), "Real Qin route stage roundtrips before next step")
			if index < 3:
				check(not s.qin_unlocked and s.party_roster == ["hero"] and not s.party_resources.has("qin"), "Accept, inspect and handoff keep explicit solo and do not grant Qin")
		check(s.qin_recruited() and s.party_roster == ["hero", "qin"] and s.current_companion() == "秦禾", "Explicit invitation alone enrolls and foregrounds Qin after either ending")
		check(s.party_resources.shen == {"hp": 3, "qi": 0} and s.party_resources.tang == {"hp": 4, "qi": 1} and s.hp == 17 and s.qi == 1, "Natural Qin route preserves unselected allies and existing hero resources")
		check(_earned(s) == before_xp and s.coins == before_coins and s.resources == before_items and s.medicine == before_medicine and s.mist_ending == ending, "Optional invitation grants no extra XP, coins or items and preserves Mistwood choice")
		s.map_id = "qingwei"
		for roster: Array in [["hero"], ["hero", "qin"], ["hero", "shen", "qin"], ["hero", "shen", "tang", "qin"]]:
			var before_resources: Dictionary = s.party_resources.duplicate(true)
			check(s.set_party_roster(roster) and s.party_resources == before_resources, "Naturally recruited party explicitly selects %d actors without healing" % roster.size())
			check(s.start_party_battle("training") and s.party_battle_snapshot().actors.size() == roster.size(), "Actual battle starts with precisely %d naturally recruited selected actors" % roster.size())
			_step(s, "flee")
			check(s.party_settlement.outcome == "flee" and s.party_roster == roster and s.party_resources == before_resources, "Natural%d actor session settles with all benched resources retained" % roster.size())
