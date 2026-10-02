extends SceneTree
## Use isolated XDG directories. --pure-rules runs before HeroState is wired;
## the normal invocation also tests actual schema-11 load/reset/save behavior.
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/heting_receipt_rules.gd")
const Harbor = preload("res://scripts/heting_rules.gd")
const ROOT: String = "user://heting-receipt-rules"
const SAVE: String = ROOT + "/fixture.json"
const FROZEN_V019_PATH: String = "res://tests/fixtures/v019_game_state.gd.txt"
const FROZEN_V019_SHA256: String = "e20c24c3cf7ac0cfc83f4a3ab453cad6f9e8c61e116f13d12b22576bd4d1b0a5"
var checks: int = 0
var failures: int = 0


class ReceiptStub:
	extends RefCounted
	const Base = preload("res://scripts/game_state.gd")
	const Receipt = preload("res://scripts/heting_receipt_rules.gd")
	var source = Base.new()
	var receipt_stage: int = 0
	var fail_save: bool = false
	var persisted: Dictionary = {}
	var stages_at_reward: Array[int] = []
	var try_reentry: bool = false
	var reentry_rejected: bool = false

	func _get(property: StringName) -> Variant:
		return source.get(property)

	func _set(property: StringName, value: Variant) -> bool:
		source.set(property, value)
		return true

	func gain_xp(amount: int) -> Array[String]:
		stages_at_reward.append(receipt_stage)
		if try_reentry:
			reentry_rejected = not Receipt.settle_victory(self)
		return source.gain_xp(amount)

	func to_dict() -> Dictionary:
		var data: Dictionary = source.to_dict()
		data.receipt_stage = receipt_stage
		return data

	func persist() -> Error:
		if fail_save:
			return ERR_CANT_CREATE
		persisted = to_dict().duplicate(true)
		return OK

	func reset_game() -> void:
		source.reset_game()
		receipt_stage = 0


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME for receipt rule checks")
		quit(2)
		return
	_test_routes_and_rewards()
	_test_context_guards()
	_test_validation()
	_test_retry_accounting()
	_test_text_is_read_only()
	if not OS.get_cmdline_user_args().has("--pure-rules"):
		_test_state_integration()
	var scope: String = "pure rules" if OS.get_cmdline_user_args().has("--pure-rules") else "rules and schema-11 integration"
	if failures == 0:
		print("PASS: %d Heting receipt checks (%s)" % [checks, scope])
	else:
		push_error("FAIL: %d of %d Heting receipt checks (%s)" % [failures, checks, scope])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _complete_harbor(s, ending: String = "short_ferries", mist: String = "release_water", reverse: bool = false) -> void:
	s.quest_stage = 6
	s.ending = "守望"
	s.side_stage = 3
	s.side_choice = "rescue"
	s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"])
	s.side_clues = 2
	s.chapter_two_stage = 4
	s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"])
	s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4
	s.mist_gauges.assign(["rain", "stone", "basin"])
	s.mist_approach = "duel"
	s.mist_ending = mist
	s.heting_stage = 4
	s.heting_bridge = "east" if mist == "release_water" else "west"
	s.heting_delivered.assign(["sealed", "meal", "reserve"] if reverse else ["meal", "sealed", "reserve"])
	s.heting_cargo = ""
	s.heting_draft = ending
	s.heting_ending = ending
	s.map_id = "heting"
	s.position = Vector2(420, 220)


func _ready(ending: String = "short_ferries", mist: String = "release_water", reverse: bool = false):
	var s = ReceiptStub.new()
	_complete_harbor(s, ending, mist, reverse)
	return s


func _earned_xp(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)


func _snapshot(s) -> Dictionary:
	return {"save": s.to_dict().duplicate(true), "battle": [s.battle_active, s.battle_kind,
		s.enemy_hp, s.turn, s.focused_damage, s.skill_cooldown, s.battle_log.duplicate()]}


func _rejected(s, action: Callable, label: String) -> void:
	var before: Dictionary = _snapshot(s)
	check(not action.call(), label + " rejects")
	check(_snapshot(s) == before, label + " changes no progress, resources, or old battle fields")


func _test_routes_and_rewards() -> void:
	for ending: String in Harbor.PLANS:
		for mist: String in Harbor.MIST_ENDINGS:
			for reverse: bool in [false, true]:
				var s = _ready(ending, mist, reverse)
				s.coins = 0
				s.medicine = 0
				s.hp = 1
				s.qi = 0
				var before: Dictionary = s.to_dict()
				check(Rules.can_begin(s) and Rules.begin(s), "Either ending, mist route and base order can begin without purchases")
				var accepted: Dictionary = before.duplicate(true)
				accepted.receipt_stage = 1
				check(s.to_dict() == accepted, "Acceptance only sets the optional stage")
				check(Rules.begin(s) and s.to_dict() == accepted, "Accepted encounter remains retryable without new rewards")
				_rejected(s, func(): return Rules.compare(s), "Premature evidence comparison")
				s.try_reentry = true
				check(Rules.settle_victory(s) and s.receipt_stage == 2, "Verified accepted victory recovers the slip")
				check(s.stages_at_reward == [2] and s.reentry_rejected, "Stage is consumed before reward callbacks can re-enter")
				check(_earned_xp(s) == 80 and s.level == 2 and s.xp == 20 and s.coins == 40 and s.victories == 1, "Victory grants exactly 80 XP, 40 coins and one victory")
				check(s.hp == s.max_hp and s.qi == s.max_qi, "Natural XP level-up retains existing healing semantics")
				for key in before:
					if key not in ["receipt_stage", "coins", "victories", "level", "xp", "hp", "max_hp", "qi", "attack", "defense"]:
						check(s.to_dict()[key] == before[key], "Settlement preserves unrelated field " + str(key))
				_rejected(s, func(): return Rules.settle_victory(s), "Duplicate victory callback")
				_rejected(s, func(): return Rules.begin(s), "Recovered slip cannot restart the encounter")
				var recovered: Dictionary = s.to_dict()
				check(Rules.compare(s), "Recovered evidence can be compared")
				recovered.receipt_stage = 3
				check(s.to_dict() == recovered, "Comparison only changes narrative progress and grants no currency or XP")
				_rejected(s, func(): return Rules.compare(s), "Duplicate comparison callback")
				_rejected(s, func(): return Rules.settle_victory(s), "Completed comparison cannot pay victory again")
				_rejected(s, func(): return Rules.begin(s), "Completed optional story cannot restart")
	var capped = _ready()
	capped.coins = 999990
	capped.victories = 999999
	capped.level = 99
	capped.xp = 5935
	Rules.begin(capped)
	check(Rules.settle_victory(capped) and capped.coins == 999999 and capped.victories == 999999 and capped.xp == 5939, "Rewards respect existing persisted counter and maximum-level limits")
	capped.reset_game()
	check(capped.receipt_stage == 0 and capped.heting_stage == 0 and capped.coins == 24 and capped.victories == 0 and capped.xp == 0, "Reset returns new progress and rewards to natural defaults")


func _test_context_guards() -> void:
	var fresh = ReceiptStub.new()
	check(not Rules.can_begin(fresh), "Fresh hero has no optional encounter")
	_rejected(fresh, func(): return Rules.begin(fresh), "Fresh story gate")
	for stage: int in range(4):
		var s = _ready()
		s.heting_stage = stage
		check(not Rules.can_begin(s), "Unfinished harbor stage cannot enter")
		_rejected(s, func(): return Rules.begin(s), "Harbor stage " + str(stage))
	for receipt: int in range(4):
		for guard_kind: String in ["map", "cargo", "battle", "harbor_ending", "mist_ending", "delivery"]:
			var s = _ready()
			s.receipt_stage = receipt
			match guard_kind:
				"map": s.map_id = "mistwood"
				"cargo": s.heting_cargo = "reserve"
				"battle":
					s.battle_active = true
					s.enemy_hp = 23
					s.turn = 7
					s.focused_damage = 19
				"harbor_ending": s.heting_ending = "unknown"
				"mist_ending": s.mist_ending = "unknown"
				"delivery": s.heting_delivered.assign(["meal", "sealed"])
			check(not Rules.can_begin(s), "Entry rejects invalid context " + guard_kind)
			_rejected(s, func(): return Rules.begin(s), guard_kind + " begin")
			_rejected(s, func(): return Rules.settle_victory(s), guard_kind + " settlement")
			_rejected(s, func(): return Rules.compare(s), guard_kind + " comparison")
	var unseen = _ready()
	_rejected(unseen, func(): return Rules.settle_victory(unseen), "Victory without acceptance")
	_rejected(unseen, func(): return Rules.compare(unseen), "Comparison without recovered slip")


func _test_validation() -> void:
	for version: int in range(1, 11):
		check(Rules.valid({}, version), "Missing receipt field defaults to zero in schema " + str(version))
		var legacy: Dictionary = _ready().to_dict()
		legacy.erase("receipt_stage")
		check(Rules.valid(legacy, version), "Completed legacy harbor may omit new field")
	check(not Rules.valid({}, 11), "Schema 11 requires receipt_stage")
	check(Rules.valid({"receipt_stage": 0}, 11), "Stage zero needs no new harbor prerequisite")
	for ending: String in Harbor.PLANS:
		for stage: int in range(4):
			var data: Dictionary = _ready(ending).to_dict()
			data.receipt_stage = stage
			for version: int in range(1, 12):
				check(Rules.valid(data, version), "Bounded integral stage accepted with completed harbor")
			var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
			check(Rules.valid(parsed, 11), "JSON integral floats validate without truncation")
			data.map_id = "qingwei"
			check(Rules.valid(data, 11), "An unloaded completed harbor permits saving optional progress on another map")
	for bad in [-1, 4, 1.5, 2.999, 1e99, INF, -INF, NAN, "1", true, false, null, [], {}]:
		var data: Dictionary = _ready().to_dict()
		data.receipt_stage = bad
		check(not Rules.valid(data, 11) and not Rules.valid(data, 10), "Reject malformed receipt stage " + str(bad))
	for stage: int in [1, 2, 3]:
		for key: String in Harbor.FIELDS + ["mist_stage", "mist_ending"]:
			var data: Dictionary = _ready().to_dict()
			data.receipt_stage = stage
			data.erase(key)
			check(not Rules.valid(data, 11) and not Rules.valid(data, 1), "Nonzero stage rejects absent prerequisite field " + key)
		for harbor_stage: int in range(4):
			var data: Dictionary = _ready().to_dict()
			data.receipt_stage = stage
			data.heting_stage = harbor_stage
			check(not Rules.valid(data, 11), "Nonzero optional stage needs completed harbor")
		for patch: Dictionary in [{"heting_draft": "open_scale"}, {"heting_ending": "bad"}, {"heting_cargo": "reserve"}, {"heting_delivered": ["meal", "sealed"]}, {"mist_stage": 3}, {"mist_ending": "bad"}]:
			var data: Dictionary = _ready().to_dict()
			data.receipt_stage = stage
			data.merge(patch, true)
			check(not Rules.valid(data, 11), "Nonzero stage rejects contradictory harbor prerequisite")


func _test_retry_accounting() -> void:
	var s = _ready()
	check(Rules.begin(s) and s.persist() == OK, "Accepted retry point can be persisted")
	var accepted_save: Dictionary = s.persisted.duplicate(true)
	var accepted_live: Dictionary = s.to_dict()
	# Flee/defeat belongs to the caller and never invokes the victory mutator.
	for outcome: String in ["fled", "defeated", "interrupted"]:
		check(Rules.begin(s) and s.to_dict() == accepted_live, "A " + outcome + " attempt remains retryable without rewards")
	s.fail_save = true
	check(Rules.settle_victory(s) and s.persist() == ERR_CANT_CREATE, "Persistence can fail after a successful settlement")
	var won: Dictionary = s.to_dict()
	check(s.persisted == accepted_save and s.receipt_stage == 2, "Failed save preserves previous disk record and rewarded live state")
	_rejected(s, func(): return Rules.settle_victory(s), "Save-failure duplicate victory callback")
	s.fail_save = false
	check(s.persist() == OK and s.persisted == won and s.to_dict() == won, "Retry saves the awarded state without paying again")
	s.fail_save = true
	check(Rules.compare(s) and s.persist() == ERR_CANT_CREATE and s.persisted == won, "Comparison can also await persistence without replaying rewards")
	var complete: Dictionary = s.to_dict()
	_rejected(s, func(): return Rules.compare(s), "Save-failure duplicate comparison")
	s.fail_save = false
	check(s.persist() == OK and s.persisted == complete and s.coins == 64 and s.victories == 1 and _earned_xp(s) == 80, "Comparison persistence retry preserves exact one-time accounting")
	# Restoring the earlier disk record restores its earlier rewards too. The next
	# victory is one award in that restored timeline, never an additive replay.
	var restored = _ready()
	restored.receipt_stage = int(accepted_save.receipt_stage)
	check(Rules.settle_victory(restored) and restored.to_dict() == won, "Returning to accepted snapshot does not carry rewards from the discarded live state")


func _test_text_is_read_only() -> void:
	var s = _ready()
	for stage: int in range(4):
		s.receipt_stage = stage
		var before: Dictionary = _snapshot(s)
		check(not Rules.hint(s).is_empty() and not Rules.journal(s).is_empty(), "Each stage has a hint and journal narrative")
		check(_snapshot(s) == before, "Narrative getters cannot award, compare, or alter the harbor ending")
	check(Rules.journal(s).contains("水损票") and Rules.journal(s).contains("预结粮钱") and Rules.journal(s).contains("不添船工姓名"), "Complete evidence connects existing tickets without exposing witness names")


func _write_document(data: Dictionary, version: int = 11) -> void:
	var file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": version, "player": data}))
	file.close()


func _invalid_load(live, data: Dictionary, version: int, label: String) -> void:
	var before: Dictionary = _snapshot(live)
	_write_document(data, version)
	check(live.load_game(SAVE) == ERR_FILE_CORRUPT, label + " rejects full document")
	check(_snapshot(live) == before, label + " validates before resetting any live field")


func _test_state_integration() -> void:
	var probe = State.new()
	if probe.get("receipt_stage") == null or State.SAVE_VERSION != 11:
		check(false, "HeroState must expose receipt_stage and schema 11 before normal integration checks")
		return
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT)) == OK, "Create isolated save fixture directory")
	check(probe.receipt_stage == 0 and probe.to_dict().receipt_stage == 0, "Natural HeroState creation and serialization use stage zero")
	for ending: String in Harbor.PLANS:
		for stage: int in range(4):
			var s = State.new()
			_complete_harbor(s, ending)
			if stage >= 1: Rules.begin(s)
			if stage >= 2: Rules.settle_victory(s)
			if stage == 3: Rules.compare(s)
			check(s._valid_save_data(s.to_dict(), 11), "Reachable actual receipt state passes full schema")
			check(s.save_game(SAVE) == OK, "Actual receipt state saves atomically")
			var loaded = State.new()
			check(loaded.load_game(SAVE) == OK and loaded.to_dict() == s.to_dict(), "Actual receipt round-trip neither advances nor rewards")
			loaded.reset_game()
			check(loaded.to_dict() == State.new().to_dict(), "Actual reset clears receipt and returns every natural default")
	var legacy: Dictionary = State.new().to_dict()
	legacy.erase("receipt_stage")
	for version: int in range(1, 11):
		_write_document(legacy, version)
		check(probe.load_game(SAVE) == OK and probe.receipt_stage == 0, "Actual loader accepts schema " + str(version) + " without receipt stage")
	var live = State.new()
	_complete_harbor(live)
	Rules.begin(live)
	live.battle_active = true
	live.enemy_hp = 45
	live.turn = 8
	live.focused_damage = 29
	var valid_data: Dictionary = live.to_dict()
	for bad in [-1, 4, 1.5, "2", true, null, [], {}]:
		var data: Dictionary = valid_data.duplicate(true)
		data.receipt_stage = bad
		_invalid_load(live, data, 11, "Malformed new field " + str(bad))
	var missing: Dictionary = valid_data.duplicate(true)
	missing.erase("receipt_stage")
	_invalid_load(live, missing, 11, "Missing required schema-11 field")
	for key: String in ["player_name", "level", "xp", "coins", "hp", "max_hp", "qi", "max_qi", "attack", "defense", "medicine", "herbs", "quest_stage", "sect", "ending", "position", "victories"]:
		var data: Dictionary = valid_data.duplicate(true)
		data.erase(key)
		_invalid_load(live, data, 11, "Missing original field " + key)
		data.erase("receipt_stage")
		_invalid_load(live, data, 1, "Truncated legacy original field " + key)
	for key: String in Harbor.FIELDS:
		var data: Dictionary = valid_data.duplicate(true)
		data.erase(key)
		_invalid_load(live, data, 11, "Missing completed-harbor prerequisite " + key)
	# A directory at the destination reliably forces atomic rename failure in
	# this isolated fixture; the live receipt state must remain awarded once.
	live.battle_active = false
	check(Rules.settle_victory(live), "Actual state settles before failing save")
	var won: Dictionary = live.to_dict()
	var blocked_path: String = ROOT + "/blocked.json"
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path)) == OK, "Create isolated rename-failure target")
	check(live.save_game(blocked_path) != OK and live.to_dict() == won, "Actual failed save preserves awarded progress")
	check(not Rules.settle_victory(live) and live.to_dict() == won, "Actual duplicate callback after save failure cannot repay")
	check(live.save_game(SAVE) == OK, "Actual retry persists the same awarded state")
	check(probe.load_game(SAVE) == OK and probe.to_dict() == won, "Actual retry reload has exactly one award")
	_test_wrapper_entry_and_costs()
	_test_wrapper_stale_callbacks()
	_test_wrapper_victory_persistence()
	_test_wrapper_flee_and_defeat()
	_test_historical_reader_rejection()


func _wrapper_ready(ending: String = "short_ferries", experienced: bool = true):
	var s = State.new()
	_complete_harbor(s, ending)
	s.choose_sect("听潮阁")
	if experienced:
		s.gain_xp(2700) # Natural level 10: enough health for a full ordinary fight.
	s.heal_rest()
	s.art_uses[s.equipped_art] = 4
	s.medicine = 2
	check(s._valid_save_data(s.to_dict(), 11), "Combat-wrapper fixture has complete legitimate harbor and original prerequisites")
	return s


func _wrapper_snapshot(s) -> Dictionary:
	return {"hero": _snapshot(s), "session": s.receipt_battle_snapshot().duplicate(true),
		"epoch": s.receipt_battle_epoch, "settlement": s.receipt_settlement.duplicate(true)}


func _wrapper_rejected(s, action: Callable, label: String) -> void:
	var before: Dictionary = _wrapper_snapshot(s)
	check(not action.call(), label + " rejects")
	check(_wrapper_snapshot(s) == before, label + " leaves all live values and the presentation lock unchanged")


func _accept_wrapper(s, action: String) -> Dictionary:
	var tx: Dictionary = s.receipt_battle_action(action)
	check(bool(tx.get("accepted", false)), "HeroState accepts actual receipt action " + action)
	if not bool(tx.get("accepted", false)):
		return tx
	check(tx.is_read_only() and tx.epoch == s.receipt_battle_epoch and tx.after.locked, "Wrapper preserves immutable facts and attaches its current epoch")
	check(s.hp == tx.after.hp and s.qi == tx.after.qi and s.medicine == tx.after.medicine and s.art_uses == tx.after.art_uses, "Accepted HP, qi, medicine and proficiency commit immediately before presentation")
	check(s.turn == tx.after.turn and s.skill_cooldown == tx.after.skill_cooldown, "Accepted turn and cooldown commit immediately")
	return tx


func _wrapper_step(s, action: String) -> Dictionary:
	var tx: Dictionary = _accept_wrapper(s, action)
	if bool(tx.get("accepted", false)):
		check(s.finish_receipt_presentation(int(tx.epoch), int(tx.token)), "Current wrapper presentation finishes exactly once")
	return tx


func _busy_save(s, path: String, checkpoint: PackedByteArray, label: String) -> void:
	var before: Dictionary = _wrapper_snapshot(s)
	check(s.save_game(path) == ERR_BUSY, label + " blocks persistence of transient combat")
	check(FileAccess.get_file_as_bytes(path) == checkpoint and not FileAccess.file_exists(path + ".tmp"), label + " preserves exact pre-entry bytes without a temporary overwrite")
	check(_wrapper_snapshot(s) == before, label + " does not change live combat")


func _test_wrapper_entry_and_costs() -> void:
	for ending: String in Harbor.PLANS:
		var s = _wrapper_ready(ending)
		var path: String = ROOT + "/entry-" + ending + ".json"
		_wrapper_rejected(s, func(): return s.start_receipt_battle(), "Fight start before explicit acceptance")
		check(s.begin_receipt() and s.receipt_stage == 1, "Wrapper accepts either completed harbor ending")
		s.hp = 100
		s.qi = 3
		var accepted: Dictionary = s.to_dict()
		check(s.save_game(path) == OK, "Accepted story writes a pre-entry checkpoint")
		var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(path)
		check(s.start_receipt_battle() and s.battle_active and s.battle_kind == "heting_receipt", "Accepted and saved story enters group combat")
		check(s.to_dict() == accepted and s.receipt_battle_snapshot().hp == 100 and s.receipt_battle_snapshot().qi == 3 and s.receipt_battle_snapshot().medicine == 2, "Entry copies current resources without free healing or spending")
		_busy_save(s, path, checkpoint, "Unlocked active encounter")
		_wrapper_rejected(s, func(): return s.start_receipt_battle(), "Repeated active start")
		_wrapper_rejected(s, func(): return s.begin_receipt(), "Acceptance during active fight")
		_wrapper_rejected(s, func(): return s.compare_receipt(), "Evidence comparison during fight")
		for action: String in ["attack", "skill", "guard", "item", "flee"]:
			_wrapper_rejected(s, func(): return s.battle_action(action).valid, "Old single-enemy action " + action)
		var medicine: Dictionary = _accept_wrapper(s, "item")
		check(s.medicine == 1 and s.hp == 136 and s.qi == 3 and s.art_uses[s.equipped_art] == 4, "Real medicine heals before the first counter and consumes exactly one dose")
		_busy_save(s, path, checkpoint, "Locked accepted medicine")
		_wrapper_rejected(s, func(): return s.receipt_battle_action("item").accepted, "Duplicate medicine while locked")
		_wrapper_rejected(s, func(): return s.select_receipt_target("bracer"), "Retarget while locked")
		_wrapper_rejected(s, func(): return s.cycle_receipt_target(), "Cycle while locked")
		_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(medicine.epoch), int(medicine.token) + 99), "Wrong current-attempt token")
		check(s.finish_receipt_presentation(int(medicine.epoch), int(medicine.token)), "Medicine presentation releases the current turn")
		_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(medicine.epoch), int(medicine.token)), "Repeated finished nonterminal token")
		check(s.select_receipt_target("bracer"), "Target can change after presentation")
		var skill: Dictionary = _accept_wrapper(s, "skill")
		check(s.qi == 0 and s.hp == 115 and s.medicine == 1 and s.art_uses[s.equipped_art] == 5, "Skill cost, heavy counter and threshold-crossing proficiency persist immediately")
		check(int(skill.after.art_rank) == 2 and int(skill.before.art_rank) == 1, "Wrapper keeps the earned rank transition from the model")
		_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(medicine.epoch), int(medicine.token)), "Previous turn cannot unlock a newer action")
		_busy_save(s, path, checkpoint, "Locked accepted skill")
		check(s.finish_receipt_presentation(int(skill.epoch), int(skill.token)), "Skill presentation completes")
		_busy_save(s, path, checkpoint, "Unlocked damaged ongoing encounter")
		var recovered = State.new()
		check(recovered.load_game(path) == OK and recovered.to_dict() == accepted and not recovered.battle_active and recovered.receipt_session == null, "Pre-entry checkpoint restores accepted story without persisting half a battle")


func _test_wrapper_stale_callbacks() -> void:
	var s = _wrapper_ready()
	check(s.begin_receipt() and s.start_receipt_battle(), "First epoch begins")
	var old: Dictionary = _accept_wrapper(s, "guard")
	var prior_epoch: int = int(old.epoch)
	s.reset_game()
	_wrapper_rejected(s, func(): return s.finish_receipt_presentation(prior_epoch, int(old.token)), "Callback after reset")
	_complete_harbor(s, "open_scale")
	s.choose_sect("听潮阁")
	s.gain_xp(2700)
	s.heal_rest()
	check(s.begin_receipt() and s.start_receipt_battle(), "A fresh accepted story can start after reset")
	var current: Dictionary = _accept_wrapper(s, "guard")
	check(current.token == old.token and current.epoch != prior_epoch, "Different attempts deliberately reuse a numeric token while epochs differ")
	_wrapper_rejected(s, func(): return s.finish_receipt_presentation(prior_epoch, int(old.token)), "Old epoch with the same numeric token")
	_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(current.epoch), int(current.token) + 1), "Current epoch with an unissued token")
	check(s.finish_receipt_presentation(int(current.epoch), int(current.token)), "Only the current epoch and token unlock")
	var flee: Dictionary = _wrapper_step(s, "flee")
	check(not s.battle_active and s.receipt_stage == 1 and not s.receipt_settlement.awarded, "Flee finishes the attempt without awarding")
	check(s.start_receipt_battle(), "Same accepted story can start another attempt")
	var newer: Dictionary = _accept_wrapper(s, "guard")
	check(newer.epoch != current.epoch and newer.token == current.token, "Retry also receives a new epoch for a reused first-turn token")
	_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(current.epoch), int(current.token)), "Old nonterminal callback after retry")
	_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(flee.epoch), int(flee.token)), "Old terminal callback after retry")
	check(s.finish_receipt_presentation(int(newer.epoch), int(newer.token)) and s.victories == 0 and s.receipt_stage == 1, "Current retry remains playable with no stale settlement")


func _play_wrapper_to_terminal(s) -> Dictionary:
	check(s.select_receipt_target("bracer"), "Natural victory route first removes the protecting target")
	for turn_index: int in range(80):
		var action: String = "attack"
		if s.hp < 50 and s.medicine > 0:
			action = "item"
		elif s.receipt_session.action_unavailable_reason("skill").is_empty():
			action = "skill"
		var tx: Dictionary = _accept_wrapper(s, action)
		if not bool(tx.get("accepted", false)):
			return {}
		if not tx.after.active:
			return tx
		check(s.finish_receipt_presentation(int(tx.epoch), int(tx.token)), "Natural route presents its nonterminal turn")
	check(false, "Natural wrapper encounter must reach a terminal outcome within the bounded test route")
	return {}


func _test_wrapper_victory_persistence() -> void:
	for ending: String in Harbor.PLANS:
		var s = _wrapper_ready(ending)
		var path: String = ROOT + "/victory-" + ending + ".json"
		check(s.begin_receipt() and s.save_game(path) == OK and s.start_receipt_battle(), "Victory route accepts, checkpoints, and starts in order")
		var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var coins_before: int = s.coins
		var xp_before: int = _earned_xp(s)
		var wins_before: int = s.victories
		var terminal: Dictionary = _play_wrapper_to_terminal(s)
		if terminal.is_empty():
			continue
		check(terminal.after.outcome == "win" and s.battle_active and s.receipt_stage == 1, "Both targets fall through normal actions; settlement waits for terminal presentation")
		check(s.coins == coins_before and s.victories == wins_before and _earned_xp(s) == xp_before, "No rewards are paid at action acceptance")
		_busy_save(s, path, checkpoint, "Locked terminal victory")
		_wrapper_rejected(s, func(): return Rules.settle_victory(s), "Direct premature settlement before terminal presentation")
		_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(terminal.epoch) - 1, int(terminal.token)), "Stale epoch cannot settle victory")
		check(s.finish_receipt_presentation(int(terminal.epoch), int(terminal.token)), "Current terminal presentation settles actual victory")
		check(not s.battle_active and s.receipt_stage == 2 and s.receipt_settlement.outcome == "win" and s.receipt_settlement.awarded, "Actual wrapper reports a recovered slip and paid outcome")
		check(s.coins == coins_before + 40 and s.victories == wins_before + 1 and _earned_xp(s) == xp_before + 80, "Actual wrapper pays exactly one 80-XP/40-coin/victory award")
		check(s.receipt_settlement.is_read_only() and s.receipt_settlement.coin_change == 40 and s.receipt_settlement.stage == 2, "Settlement facts are immutable and describe the real change")
		var won: Dictionary = s.to_dict()
		var blocked: String = ROOT + "/victory-blocked-" + ending + ".json"
		check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked)) == OK, "Create isolated victory rename-failure target")
		check(s.save_game(blocked) != OK and s.to_dict() == won and FileAccess.get_file_as_bytes(path) == checkpoint, "Post-victory save failure preserves awarded live state and prior checkpoint")
		_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(terminal.epoch), int(terminal.token)), "Duplicate terminal callback after failed save")
		_wrapper_rejected(s, func(): return Rules.settle_victory(s), "Duplicate rules settlement after failed save")
		_wrapper_rejected(s, func(): return s.start_receipt_battle(), "Recovered slip cannot start another rewarded attempt")
		check(s.save_game(path) == OK and s.to_dict() == won, "Save retry writes the existing settled state")
		var loaded = State.new()
		check(loaded.load_game(path) == OK and loaded.to_dict() == won and not loaded.battle_active and loaded.receipt_session == null, "Saved victory reloads with one payout and no transient session")
		_wrapper_rejected(loaded, func(): return loaded.finish_receipt_presentation(int(terminal.epoch), int(terminal.token)), "Terminal callback after a clean load")
		_wrapper_rejected(loaded, func(): return Rules.settle_victory(loaded), "Reloaded victory cannot settle again")
		check(loaded.compare_receipt(), "Loaded victory permits evidence comparison")
		won.receipt_stage = 3
		check(loaded.to_dict() == won, "Actual comparison adds evidence without money, XP, medicine, or proficiency changes")
		check(loaded.save_game(path) == OK and s.load_game(path) == OK and s.to_dict() == won, "Compared story round-trips without another payout")
		_wrapper_rejected(s, func(): return s.compare_receipt(), "Repeated loaded comparison")


func _test_wrapper_flee_and_defeat() -> void:
	for ending: String in Harbor.PLANS:
		var s = _wrapper_ready(ending)
		s.hp = 100
		s.qi = 3
		check(s.begin_receipt() and s.start_receipt_battle(), "Flee-cost route starts")
		_wrapper_step(s, "item")
		_wrapper_step(s, "skill")
		var spent: Dictionary = s.to_dict()
		var flee: Dictionary = _accept_wrapper(s, "flee")
		check(flee.after.outcome == "flee" and s.battle_active and s.to_dict() == spent, "Flee commits no refund or counter before presentation")
		check(s.finish_receipt_presentation(int(flee.epoch), int(flee.token)), "Flee terminal presentation finishes")
		check(s.to_dict() == spent and not s.battle_active and s.receipt_stage == 1 and s.skill_cooldown == 0 and not s.receipt_settlement.awarded, "Flee retains real HP/qi/medicine/proficiency costs and accepted story without rewards")
		_wrapper_rejected(s, func(): return s.finish_receipt_presentation(int(flee.epoch), int(flee.token)), "Repeated flee callback")
		var path: String = ROOT + "/flee-" + ending + ".json"
		check(s.save_game(path) == OK, "Flee costs can be saved")
		var loaded = State.new()
		check(loaded.load_game(path) == OK and loaded.to_dict() == spent, "Flee costs survive save/load")
		check(loaded.start_receipt_battle(), "Flee leaves the encounter retryable")
		check(loaded.receipt_battle_snapshot().hp == spent.hp and loaded.receipt_battle_snapshot().qi == spent.qi and loaded.receipt_battle_snapshot().medicine == spent.medicine and loaded.receipt_battle_snapshot().art_uses == spent.art_uses, "Retry copies the spent resources rather than the first-attempt snapshot")
		for starting_coins: int in [0, 3, 8, 77]:
			var defeated = _wrapper_ready(ending, false)
			defeated.hp = 1
			defeated.qi = 3
			defeated.medicine = 1
			defeated.coins = starting_coins
			check(defeated.begin_receipt() and defeated.start_receipt_battle(), "Low-health defeat route starts from actual resources")
			_wrapper_step(defeated, "item")
			check(defeated.hp == 28 and defeated.medicine == 0, "Medicine is consumed before the later defeat")
			var terminal: Dictionary = _accept_wrapper(defeated, "skill")
			check(terminal.after.outcome == "defeat" and defeated.hp == 0 and defeated.qi == 0 and defeated.art_uses[defeated.equipped_art] == 5, "Natural heavy counter defeats hero after a real skill cost and proficiency gain")
			var before_recovery: Dictionary = defeated.to_dict()
			check(defeated.finish_receipt_presentation(int(terminal.epoch), int(terminal.token)), "Defeat recovery occurs on terminal presentation")
			check(defeated.hp == defeated.max_hp and defeated.qi == 2 and defeated.coins == maxi(0, starting_coins - 8), "Defeat restores HP/minimum qi and loses at most eight available coins")
			check(defeated.receipt_stage == 1 and defeated.victories == 0 and defeated.xp == 0 and defeated.medicine == 0 and defeated.art_uses[defeated.equipped_art] == 5, "Defeat keeps accepted story, spent medicine and earned proficiency without victory rewards")
			check(defeated.map_id == "heting" and defeated.position == Vector2(230, 735) and not defeated.battle_active and defeated.skill_cooldown == 0, "Defeat returns to the harbor rest point and clears the active gate")
			check(defeated.receipt_settlement.outcome == "defeat" and not defeated.receipt_settlement.awarded and defeated.receipt_settlement.coin_change == -mini(starting_coins, 8), "Defeat settlement reports the actual bounded coin loss")
			for key in before_recovery:
				if key not in ["hp", "qi", "coins", "position"]:
					check(defeated.to_dict()[key] == before_recovery[key], "Defeat recovery preserves unrelated field " + str(key))
			_wrapper_rejected(defeated, func(): return defeated.finish_receipt_presentation(int(terminal.epoch), int(terminal.token)), "Repeated defeat cannot charge twice")
			path = ROOT + "/defeat-" + ending + "-" + str(starting_coins) + ".json"
			check(defeated.save_game(path) == OK, "Recovered defeat saves valid live state")
			check(loaded.load_game(path) == OK and loaded.to_dict() == defeated.to_dict() and loaded.start_receipt_battle(), "Reloaded defeat preserves costs and remains retryable")


func _test_historical_reader_rejection() -> void:
	# Verify the exact bundled source before compiling. Only its global class
	# declaration is removed; the historical version gate itself stays intact.
	var frozen: PackedByteArray = FileAccess.get_file_as_bytes(FROZEN_V019_PATH)
	check(not frozen.is_empty(), "Bundled v0.0.19 reader is available without Git")
	var hashing = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(frozen)
	var digest: String = hashing.finish().hex_encode()
	check(digest == FROZEN_V019_SHA256, "Historical v0.0.19 bytes match the pinned SHA-256 before compilation")
	if digest != FROZEN_V019_SHA256:
		return
	var old_script = GDScript.new()
	old_script.source_code = frozen.get_string_from_utf8().replace("class_name HeroState\n", "")
	var parsed: Error = old_script.reload()
	check(parsed == OK, "Verified historical v0.0.19 reader compiles independently")
	if parsed != OK:
		return
	var old_reader = old_script.new()
	check(old_reader.SAVE_VERSION == 10, "Pinned reader declares the actual preceding schema version")
	var compatible: Dictionary = _wrapper_ready().to_dict()
	compatible.erase("receipt_stage")
	_write_document(compatible, 10)
	check(old_reader.load_game(SAVE) == OK and old_reader.to_dict() == compatible, "Historical-reader control accepts its own schema-10 document")
	old_reader.coins = 4242
	old_reader.battle_active = true
	old_reader.enemy_hp = 37
	old_reader.turn = 6
	old_reader.focused_damage = 23
	var before: Dictionary = _snapshot(old_reader)
	for ending: String in Harbor.PLANS:
		for stage: int in [0, 1, 2, 3]:
			var current = _wrapper_ready(ending)
			if stage >= 1: current.begin_receipt()
			if stage >= 2: Rules.settle_victory(current)
			if stage == 3: current.compare_receipt()
			var path: String = ROOT + "/v019-rejection-" + ending + "-" + str(stage) + ".json"
			check(current.save_game(path) == OK, "Create an actual schema-11 document for the historical-reader test")
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			check(old_reader.load_game(path) == ERR_FILE_UNRECOGNIZED, "Actual v0.0.19 reader refuses schema 11 before mutation")
			check(_snapshot(old_reader) == before, "Historical rejection preserves all live old progress and active battle fields")
			check(FileAccess.get_file_as_bytes(path) == bytes and not FileAccess.file_exists(path + ".tmp"), "Historical rejection preserves the new save bytes without a replacement file")
