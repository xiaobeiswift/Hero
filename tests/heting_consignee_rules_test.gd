extends SceneTree
## Focused phase-one rules/model checks. No claim of playable scene integration,
## verified combat outcomes, visual coverage, or browser persistence.
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/heting_consignee_rules.gd")
var checks: int = 0
var failures: int = 0


class Stub:
	extends RefCounted
	const Base = preload("res://scripts/game_state.gd")
	const Quest = preload("res://scripts/heting_consignee_rules.gd")
	var source = Base.new()
	var transaction_gate: bool = false
	var fail_save: bool = false
	var persisted: Dictionary = {}
	var callbacks: Array[Dictionary] = []
	var reentry_rejected: bool = false
	var try_reentry: bool = false

	func _get(property: StringName) -> Variant:
		return source.get(property)

	func _set(property: StringName, value: Variant) -> bool:
		source.set(property, value)
		return true

	func _party_gate() -> bool:
		return transaction_gate or source._party_gate()

	func gain_xp(amount: int) -> Array[String]:
		callbacks.append(Quest.progress(self))
		if try_reentry:
			reentry_rejected = not Quest.finish_delivery(self, Quest.receiver_for(source.consignee_draft), source.consignee_draft)
		return source.gain_xp(amount)

	func to_dict() -> Dictionary:
		return source.to_dict()

	func persist() -> Error:
		if fail_save: return ERR_CANT_CREATE
		persisted = to_dict().duplicate(true)
		return OK


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME for consignee rule checks")
		quit(2)
		return
	_test_routes()
	_test_reversible_cargo()
	_test_guards()
	_test_companion_alternatives()
	_test_stage_matrix()
	_test_malformed_data()
	_test_restore_and_save_interruption()
	_test_read_only_story()
	if failures == 0:
		print("PASS: %d Heting consignee phase-one rule checks" % checks)
	else:
		push_error("FAIL: %d of %d consignee rule checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready(harbor: String = "short_ferries", receipt: int = 0, archive: String = "protect_witness", mist: String = "release_water"):
	var s = Stub.new()
	s.quest_stage = 6; s.ending = "守望"
	s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = archive
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_ending = mist; s.mist_approach = "duel"
	s.mist_gauges.assign(["rain", "stone", "basin"])
	s.heting_stage = 4; s.heting_bridge = "west" if mist == "warn_ferries" else "east"
	s.heting_delivered.assign(["sealed", "meal", "reserve"])
	s.heting_draft = harbor; s.heting_ending = harbor; s.receipt_stage = receipt
	s.map_id = "heting"
	return s


func _investigated(s, order: Array = Rules.OBSERVATIONS) -> void:
	check(Rules.begin(s), "Begin distinct finite chapter")
	for id: String in order:
		check(Rules.observe(s, id), "Solo physical observation " + id)
	check(Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER).correct, "Earn contradiction from all three observations")


func _secured(plan: String = "hold_for_inspection"):
	var s = _ready()
	_investigated(s)
	check(Rules.choose_plan(s, plan), "Choose provisional disposition")
	check(Rules.settle_victory(s, plan), "Model accepts host-verified matching victory")
	return s


func _snapshot(s) -> Dictionary:
	return {"data": s.to_dict().duplicate(true), "battle": [s.battle_active, s._party_pending_token, s.transaction_gate], "callbacks": s.callbacks.duplicate(true)}


func _rejected(s, call: Callable, label: String) -> void:
	var before: Dictionary = _snapshot(s)
	check(not call.call(), label + " rejects")
	check(before == _snapshot(s), label + " changes no state")


func _xp(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)


func _test_routes() -> void:
	var permutations: Array = [
		["lot_seals", "removal_order", "southern_counterfoil"],
		["lot_seals", "southern_counterfoil", "removal_order"],
		["removal_order", "lot_seals", "southern_counterfoil"],
		["removal_order", "southern_counterfoil", "lot_seals"],
		["southern_counterfoil", "lot_seals", "removal_order"],
		["southern_counterfoil", "removal_order", "lot_seals"],
	]
	var routes: int = 0
	for harbor: String in ["short_ferries", "open_scale"]:
		for receipt: int in range(4):
			for archive: String in ["open_records", "protect_witness"]:
				for mist: String in ["release_water", "warn_ferries"]:
					for plan: String in Rules.PLANS:
						for order: Array in permutations:
							var s = _ready(harbor, receipt, archive, mist)
							s.hp = 1; s.qi = 0; s.coins = 0; s.medicine = 0
							var before: Dictionary = s.to_dict()
							_investigated(s, order)
							check(Rules.choose_plan(s, plan) and Rules.can_confront(s), "Both plans permit solo confrontation")
							check(Rules.settle_victory(s, plan), "Single secured-lot transition")
							check(s.consignee_stage == 3 and s.consignee_ending.is_empty() and s.hp == 1 and s.qi == 0 and s.coins == 0 and _xp(s) == 0, "Investigation and victory give no resources or automatic ending")
							check(Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE), "One distinct batch loads")
							s.try_reentry = true
							check(Rules.finish_delivery(s, Rules.receiver_for(plan), plan), "Explicit correct-destination handover")
							check(s.consignee_stage == 5 and s.consignee_ending == plan and s.consignee_draft == plan, "Handover locks exact ending")
							check(_xp(s) == 120 and s.coins == 60 and s.victories == 0, "Equal finite 120 XP / 60 coins; host owns combat victory count")
							check(s.callbacks.size() == 1 and s.callbacks[0].consignee_stage == 5 and s.reentry_rejected, "Consume finite cargo/ending before reward callback reentry")
							check(Rules.valid(s.to_dict(), 14), "Completed route validates")
							for key: String in ["heting_stage", "heting_bridge", "heting_delivered", "heting_cargo", "heting_draft", "heting_ending", "receipt_stage", "mist_stage", "mist_ending", "chapter_two_ending", "medicine", "claimed_deeds", "gathered_nodes", "resources", "party_roster"]:
								check(s.to_dict()[key] == before[key], "Preserve existing " + key)
							_rejected(s, func(): return Rules.finish_delivery(s, Rules.receiver_for(plan), plan), "Duplicate final handover")
							_rejected(s, func(): return Rules.settle_victory(s, plan), "Completed battle replay")
							routes += 1
	check(routes == 384, "384 old ending/receipt/mist/new ending/clue order routes")
	var capped = _secured()
	capped.level = 99; capped.xp = 5935; capped.coins = 999990; capped.victories = 999999
	check(Rules.take_cargo(capped, Rules.BATCH, Rules.SOURCE) and Rules.finish_delivery(capped, Rules.SCALE, "hold_for_inspection"), "Capped terminal reward")
	check(capped.coins == 999999 and capped.xp == 5939 and capped.victories == 999999 and capped.level == 99, "Existing XP/coin bounds preserved")


func _test_reversible_cargo() -> void:
	var s = _ready()
	check(Rules.begin(s), "Begin reversible route")
	_rejected(s, func(): return Rules.choose_plan(s, "hold_for_inspection"), "Unearned draft")
	var before: Dictionary = _snapshot(s)
	check(not Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER).correct, "Correct words do not bypass missing evidence")
	check(before == _snapshot(s), "Unearned answer consumes nothing")
	for id: String in Rules.OBSERVATIONS:
		check(Rules.observe(s, id), "Inspect before draft")
		_rejected(s, func(): return Rules.observe(s, id), "Repeated clue " + id)
	for answer: String in ["dry_means_whole_ship", "receipt_required", "unknown", ""]:
		before = _snapshot(s)
		var result: Dictionary = Rules.resolve_contradiction(s, answer)
		check(not result.correct and not result.reason.is_empty() and _snapshot(s) == before, "Wrong answer explains without penalty " + answer)
	check(Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER).correct, "Retry earned correct answer")
	_rejected(s, func(): return Rules.settle_victory(s, "hold_for_inspection"), "No implicit battle draft")
	check(Rules.choose_plan(s, "hold_for_inspection") and Rules.choose_plan(s, "return_to_owner"), "Draft changes before battle")
	_rejected(s, func(): return Rules.settle_victory(s, "hold_for_inspection"), "Stale entry plan")
	check(Rules.settle_victory(s, "return_to_owner"), "Current entry plan settles")
	_rejected(s, func(): return Rules.settle_victory(s, "return_to_owner"), "Duplicate secured transition")
	check(Rules.available_cargo(s, Rules.SOURCE) == [Rules.BATCH], "Only one new batch at exact source")
	var offered: Array[String] = Rules.available_cargo(s, Rules.SOURCE); offered.clear()
	check(Rules.available_cargo(s, Rules.SOURCE) == [Rules.BATCH], "Detached stock view")
	for id: String in ["meal", "sealed", "reserve", "", "unknown"]:
		_rejected(s, func(): return Rules.take_cargo(s, id, Rules.SOURCE), "Old/unknown goods " + id)
	for source: String in ["heting_cargo", "heting_lighter", "", "unknown"]:
		_rejected(s, func(): return Rules.take_cargo(s, Rules.BATCH, source), "Wrong source " + source)
	check(Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE), "Load distinct cart")
	_rejected(s, func(): return Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE), "Cart cannot duplicate batch")
	check(Rules.choose_plan(s, "hold_for_inspection"), "Draft still changes while carrying")
	_rejected(s, func(): return Rules.finish_delivery(s, Rules.GRAIN_BOAT, "return_to_owner"), "Stale delivery choice")
	_rejected(s, func(): return Rules.finish_delivery(s, Rules.GRAIN_BOAT, "hold_for_inspection"), "Stale receiver")
	var loaded: Dictionary = Rules.progress(s)
	s.map_id = "mistwood"
	check(not Rules.valid(Rules.progress(s), 14), "Carrying cannot be saved outside Heting")
	_rejected(s, func(): return Rules.park_cargo(s), "Travel cannot silently park after leaving")
	s.map_id = "heting"
	check(Rules.progress(s) == loaded and Rules.park_cargo(s), "Confirmed parking before departure")
	check(s.consignee_stage == 3 and s.consignee_draft == "hold_for_inspection", "Parking retains secured progress/draft")
	_rejected(s, func(): return Rules.park_cargo(s), "Repeated park")
	s.map_id = "mistwood"
	check(Rules.valid(s.to_dict(), 14), "Parked travel pause is valid")
	s.map_id = "heting"
	check(Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE) and Rules.finish_delivery(s, Rules.SCALE, "hold_for_inspection"), "Return resumes the same finite batch")
	_rejected(s, func(): return Rules.choose_plan(s, "return_to_owner"), "Ending cannot change after handover")
	check(Rules.available_cargo(s, Rules.SOURCE).is_empty(), "Completed source remains empty")


func _test_guards() -> void:
	for guard: String in ["battle", "pending", "transaction", "hp0", "map", "old_cargo", "harbor", "prior_ending", "receipt"]:
		for stage: int in range(5):
			var s = _ready()
			if stage >= 1: Rules.begin(s)
			if stage >= 2:
				for id: String in Rules.OBSERVATIONS: Rules.observe(s, id)
				Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER); Rules.choose_plan(s, "hold_for_inspection")
			if stage >= 3: Rules.settle_victory(s, "hold_for_inspection")
			if stage >= 4: Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE)
			match guard:
				"battle": s.battle_active = true
				"pending": s._party_pending_token = 7
				"transaction": s.transaction_gate = true
				"hp0": s.hp = 0
				"map": s.map_id = "mistwood"
				"old_cargo": s.heting_cargo = "reserve"
				"harbor": s.heting_stage = 3
				"prior_ending": s.chapter_two_ending = "unknown"
				"receipt": s.receipt_stage = 4
			for action: Callable in [func(): return Rules.begin(s), func(): return Rules.observe(s, "lot_seals"), func(): return Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER).correct, func(): return Rules.choose_plan(s, "return_to_owner"), func(): return Rules.settle_victory(s, "hold_for_inspection"), func(): return Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE), func(): return Rules.park_cargo(s), func(): return Rules.finish_delivery(s, Rules.SCALE, "hold_for_inspection")]:
				_rejected(s, action, "Guard %s stage %d" % [guard, stage])


func _recruit(s, method: String) -> void:
	var actor: String = Rules._actor_for(method)
	match actor:
		"tang":
			s.bridge_repaired = true; s.tangqi_stage = 3; s.tangqi_unlocked = true
			s.tangqi_choice = "teach" if method == "tang_teach" else "preserve"
		"shen":
			s.companion_unlocked = true; s.shen_care_stage = 5
			s.shen_care_choice = "shore" if method == "shen_shore" else "mobile"
		"qin": s.qin_stage = 4; s.qin_unlocked = true
	var plan: Dictionary = s.source.PartyRoster.load_plan(s.source, {}, 11)
	check(plan.ok, "Prepare genuine recruited party resources")
	s.source._apply_party_plan(plan)
	check(s.source.set_party_roster(["hero", actor]), "Deploy optional actor")


func _test_companion_alternatives() -> void:
	for method: String in Rules.CONTRIBUTIONS:
		var s = _ready()
		var clue: String = Rules._observation_for(method)
		var actor: String = Rules._actor_for(method)
		check(Rules.begin(s), "Begin companion route")
		check(Rules.available_methods(s, clue) == ["solo"], "Unrecruited solo path always available")
		_rejected(s, func(): return Rules.observe(s, clue, method), "Unrecruited contribution")
		_recruit(s, method)
		check(Rules.available_methods(s, clue) == ["solo", method], "Only matching completed quest method offered")
		s.party_resources[actor].hp = 0
		_rejected(s, func(): return Rules.observe(s, clue, method), "Downed actor cannot contribute")
		check(Rules.available_methods(s, clue) == ["solo"], "Downed optional actor does not block solo")
		s.party_resources[actor].hp = 1
		s.party_roster.assign(["hero"])
		_rejected(s, func(): return Rules.observe(s, clue, method), "Benched actor cannot contribute")
		s.party_roster.append(actor)
		var before: Dictionary = s.to_dict()
		check(Rules.observe(s, clue, method), "Standing deployed optional action " + method)
		check(s.consignee_contributions == [method] and s.consignee_observations == [clue], "Record actual method and physical observation")
		check(s.hp == before.hp and s.qi == before.qi and s.party_resources == before.party_resources and s.coins == before.coins and s.xp == before.xp, "Investigation never heals or pays")
		s.party_resources[actor].hp = 0; s.party_roster.assign(["hero"])
		check(Rules.valid(s.to_dict(), 14), "Historical contribution survives HP0 and roster removal")
		for id: String in Rules.OBSERVATIONS:
			if id != clue: check(Rules.observe(s, id), "Remaining investigation completes solo")
		check(Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER).correct, "Optional path earns same bounded contradiction")
		_rejected(s, func(): return Rules.observe(s, clue, method), "Cannot farm historical contribution")
		var bad: Dictionary = s.to_dict()
		if actor == "tang": bad.tangqi_choice = "preserve" if method == "tang_teach" else "teach"
		elif actor == "shen": bad.shen_care_choice = "mobile" if method == "shen_shore" else "shore"
		else: bad.qin_unlocked = false
		check(not Rules.valid(bad, 14), "Historical provenance cannot be forged " + method)


func _test_stage_matrix() -> void:
	var data: Dictionary = _ready().to_dict()
	for stage: int in range(6):
		for bits: int in range(8):
			var observations: Array[String] = []
			for i: int in range(3):
				if bits & (1 << i): observations.append(Rules.OBSERVATIONS[i])
			for draft: String in ["", "hold_for_inspection", "return_to_owner"]:
				for ending: String in ["", "hold_for_inspection", "return_to_owner"]:
					for location: String in Rules.LOCATIONS:
						for map_id: String in ["heting", "mistwood"]:
							data.consignee_stage = stage; data.consignee_observations = observations
							data.consignee_draft = draft; data.consignee_ending = ending
							data.consignee_cargo_location = location; data.map_id = map_id
							var expected: bool = false
							match stage:
								0: expected = bits == 0 and draft == "" and ending == "" and location == ""
								1: expected = draft == "" and ending == "" and location == "warehouse"
								2: expected = bits == 7 and ending == "" and location == "warehouse"
								3: expected = bits == 7 and draft != "" and ending == "" and location == "warehouse"
								4: expected = bits == 7 and draft != "" and ending == "" and location == "cart" and map_id == "heting"
								5: expected = bits == 7 and draft != "" and ending == draft and location == ("public_scale" if ending == "hold_for_inspection" else "grain_boat")
							check(Rules.valid(data, 14) == expected, "Exact cross-field stage matrix %s" % str([stage, bits, draft, ending, location, map_id]))


func _test_malformed_data() -> void:
	var neutral: Dictionary = _ready().to_dict()
	for version: int in range(1, 14):
		var legacy: Dictionary = neutral.duplicate(true)
		for key: String in Rules.FIELDS: legacy.erase(key)
		check(Rules.valid(legacy, version), "Legacy omitted chapter defaults neutral " + str(version))
		check(Rules.valid(neutral, version), "Complete present neutral legacy bundle validates " + str(version))
		for key: String in Rules.FIELDS:
			var partial: Dictionary = legacy.duplicate(true); partial[key] = neutral[key]
			check(not Rules.valid(partial, version), "Partial legacy bundle rejected")
	check(not Rules.valid({}, 14) and not Rules.valid(neutral, 0) and not Rules.valid(neutral, 17), "Future17 rejects while schema14 bundle remains mandatory")
	var valid: Dictionary = _secured().to_dict()
	for stage: Variant in [null, false, true, "3", -1, 6, 1.5, NAN, INF, -INF, [], {}]:
		var bad: Dictionary = valid.duplicate(true); bad.consignee_stage = stage
		check(not Rules.valid(bad, 14), "Reject malformed stage " + str(stage))
	var json: Dictionary = JSON.parse_string(JSON.stringify(valid))
	check(Rules.valid(json, 14), "Integral JSON floats validate")
	for key: String in Rules.FIELDS:
		var missing: Dictionary = valid.duplicate(true); missing.erase(key)
		check(not Rules.valid(missing, 14), "Required field " + key)
	for key: String in ["consignee_draft", "consignee_ending", "consignee_cargo_location"]:
		for value: Variant in [false, true, 1, null, [], {}, "unknown", "meal", "reserve"]:
			var bad: Dictionary = valid.duplicate(true); bad[key] = value
			check(not Rules.valid(bad, 14), "Reject malformed field " + key)
	for key: String in ["consignee_observations", "consignee_contributions"]:
		for value: Variant in [null, {}, "lot_seals", true, 1, ["unknown"], [false], ["lot_seals", "lot_seals"], ["qin_timing", "qin_timing"]]:
			var bad: Dictionary = valid.duplicate(true); bad[key] = value
			check(not Rules.valid(bad, 14), "Reject malformed list " + key)
	for key: String in ["heting_stage", "receipt_stage", "chapter_two_stage"]:
		for value: Variant in [null, true, "4", -1, 4.5, NAN, INF]:
			var bad: Dictionary = valid.duplicate(true); bad[key] = value
			check(not Rules.valid(bad, 14), "Reject malformed prerequisite " + key)
	for key: String in ["heting_ending", "heting_draft", "mist_ending", "chapter_two_ending"]:
		var bad: Dictionary = valid.duplicate(true); bad[key] = "unknown"
		check(not Rules.valid(bad, 14), "Reject invalid previous ending " + key)
	var contribution = _ready(); _recruit(contribution, "tang_teach")
	Rules.begin(contribution); Rules.observe(contribution, "lot_seals", "tang_teach")
	var bad: Dictionary = contribution.to_dict(); bad.consignee_observations = []
	check(not Rules.valid(bad, 14), "Contribution requires actual corresponding observation")
	bad = contribution.to_dict(); bad.consignee_contributions = ["tang_teach", "tang_preserve"]
	check(not Rules.valid(bad, 14), "One observation cannot claim both incompatible methods")


func _test_restore_and_save_interruption() -> void:
	var s = _ready()
	for stage: int in range(6):
		if stage == 1: Rules.begin(s)
		if stage == 2:
			for id: String in ["southern_counterfoil", "lot_seals", "removal_order"]: Rules.observe(s, id)
			Rules.resolve_contradiction(s, Rules.CORRECT_ANSWER); Rules.choose_plan(s, "return_to_owner")
		if stage == 3: Rules.settle_victory(s, "return_to_owner")
		if stage == 4: Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE)
		if stage == 5: Rules.finish_delivery(s, Rules.GRAIN_BOAT, "return_to_owner")
		var copy = _ready(); var data: Dictionary = s.to_dict()
		check(Rules.valid(data, 14), "Stage valid before JSON restore")
		Rules.restore(copy, JSON.parse_string(JSON.stringify(data)))
		for key: String in Rules.FIELDS:
			check(copy.to_dict()[key] == data[key], "Round-trip field/order " + key)
		check(copy.callbacks.is_empty() and _xp(copy) == 0 and copy.coins == 24, "Restore never rewards or repairs resources")
		var returned: Dictionary = Rules.progress(copy); returned.consignee_observations.clear()
		check(copy.to_dict() == _ready().to_dict() if stage == 0 else copy.consignee_observations == data.consignee_observations, "Progress arrays detached")
	var prior = _secured(); Rules.take_cargo(prior, Rules.BATCH, Rules.SOURCE)
	check(prior.persist() == OK, "Persist pre-handover model snapshot")
	var stored: Dictionary = prior.persisted.duplicate(true)
	prior.fail_save = true
	check(Rules.finish_delivery(prior, Rules.SCALE, "hold_for_inspection"), "Handover settles once before persistence")
	var settled: Dictionary = prior.to_dict()
	check(prior.persist() != OK and prior.persisted == stored and prior.to_dict() == settled, "Failed persistence retains settled memory and previous disk model")
	_rejected(prior, func(): return Rules.finish_delivery(prior, Rules.SCALE, "hold_for_inspection"), "Save retry cannot rerun reward")
	prior.fail_save = false
	check(prior.persist() == OK and prior.persisted == settled and prior.callbacks.size() == 1, "Persistence retry writes already-settled result once")
	for version: int in range(1, 14):
		var old = _secured(); Rules.restore(old, {})
		check(old.consignee_stage == 0 and old.consignee_observations.is_empty() and old.consignee_draft.is_empty() and old.consignee_cargo_location.is_empty(), "Validated missing legacy bundle restores neutral")


func _test_read_only_story() -> void:
	for archive: String in ["open_records", "protect_witness"]:
		for harbor: String in ["short_ferries", "open_scale"]:
			for receipt: int in range(4):
				var s = _ready(harbor, receipt, archive)
				_investigated(s); Rules.choose_plan(s, "return_to_owner")
				Rules.settle_victory(s, "return_to_owner"); Rules.take_cargo(s, Rules.BATCH, Rules.SOURCE)
				Rules.finish_delivery(s, Rules.GRAIN_BOAT, "return_to_owner")
				var before: Dictionary = _snapshot(s)
				var journal: String = Rules.journal(s)
				check(journal.contains("平川粮栈") and journal.contains("杜晦") and journal.contains("仍待追查"), "Bounded named local beneficiary, not solved conspiracy")
				check(journal.contains("不署证人姓名") == (archive == "protect_witness"), "Prior archive privacy preserved")
				check(journal.contains("短渡分粮照旧") == (harbor == "short_ferries"), "Prior harbor allocation retained")
				check(journal.contains("旧复称副签另作旁证") == (receipt == 3), "Only genuinely completed optional receipt corroborates")
				check(not Rules.hint(s).is_empty() and Rules.aftermath(s, "warehouse").contains("划止") and Rules.aftermath(s, "receiving_point").contains("返还记录"), "Persistent warehouse and receiver consequences described")
				check(Rules.plan_description("hold_for_inspection").contains("暂不能取用") and Rules.plan_description("return_to_owner").contains("不再保有整批封样"), "Both irreversible consequences disclosed")
				check(Rules.aftermath(s, "unknown").is_empty() and Rules.receiver_for("unknown").is_empty(), "Unknown presentation context fails closed")
				check(before == _snapshot(s), "Journal/hints/aftermath/cancel-reopen reads never mutate")
