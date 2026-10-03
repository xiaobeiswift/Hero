extends SceneTree
## Prepared model fixtures, not earned combat, physical-input, native visual or
## browser acceptance. Scene site/proximity/generation and real victory proof
## belong to separate state/combat/scene gates. No fixture is an old producer.
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/volume_one_capstone_rules.gd")
const Consignee = preload("res://scripts/heting_consignee_rules.gd")
var checks: int = 0
var failures: int = 0
var routes: int = 0


class Stub:
	extends RefCounted
	const Base = preload("res://scripts/game_state.gd")
	const Quest = preload("res://scripts/volume_one_capstone_rules.gd")
	var source = Base.new()
	# Own the model bundle so this suite also isolates rule behavior from State
	# settlement. Its source still uses real XP/cap/growth implementation.
	var capstone_stage: int = 0
	var capstone_draft: String = ""
	var capstone_ending: String = ""
	var transaction_gate: bool = false
	var fail_save: bool = false
	var persisted: Dictionary = {}
	var callbacks: Array[Dictionary] = []
	var reentry_rejected: bool = false
	var try_reentry: bool = false

	func _get(property: StringName) -> Variant: return source.get(property)
	func _set(property: StringName, value: Variant) -> bool:
		source.set(property, value)
		return true
	func _party_gate() -> bool: return transaction_gate or source._party_gate()
	func gain_xp(amount: int) -> Array[String]:
		callbacks.append(Quest.progress(self))
		if try_reentry: reentry_rejected = not Quest.finish_homecoming(self)
		return source.gain_xp(amount)
	func to_dict() -> Dictionary:
		var result: Dictionary = source.to_dict()
		result.capstone_stage = capstone_stage
		result.capstone_draft = capstone_draft
		result.capstone_ending = capstone_ending
		return result
	func persist() -> Error:
		if fail_save: return ERR_CANT_CREATE
		persisted = to_dict().duplicate(true)
		return OK


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use isolated XDG_DATA_HOME for capstone rule checks")
		quit(2)
		return
	_test_old_branch_routes()
	_test_stage_matrix()
	_test_malformed_bundle()
	_test_prior_chain()
	_test_partitions()
	_test_guards()
	_test_plans_and_boundaries()
	_test_optional_methods()
	_test_optional_matrix()
	_test_reward_callbacks()
	_test_restore_and_save_retry()
	_test_detached_projections()
	if failures == 0: print("PASS: %d capstone pure-rule checks; %d prepared branch routes (not earned scene/combat acceptance)" % [checks, routes])
	else: push_error("FAIL: %d of %d capstone rule checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready(opening: String = "守望", sluice: String = "rescue", archive: String = "protect_witness", mist: String = "release_water", approach: String = "duel", harbor: String = "short_ferries", consignee: String = "hold_for_inspection", receipt: int = 0):
	var s = Stub.new()
	s.quest_stage = 6; s.ending = opening
	s.side_stage = 3; s.side_choice = sluice; s.side_reward_claimed = true
	s.side_found.assign(["ledger", "boatman"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = archive
	s.archive_clues.assign(["inscription", "clerk"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_ending = mist; s.mist_approach = approach
	s.mist_gauges.assign(["rain", "stone", "basin"])
	s.heting_stage = 4; s.heting_bridge = "west" if mist == "warn_ferries" else "east"
	s.heting_delivered.assign(["sealed", "meal", "reserve"])
	s.heting_draft = harbor; s.heting_ending = harbor; s.receipt_stage = receipt
	s.consignee_stage = 5; s.consignee_observations.assign(Consignee.OBSERVATIONS)
	s.consignee_draft = consignee; s.consignee_ending = consignee
	s.consignee_cargo_location = "public_scale" if consignee == "hold_for_inspection" else "grain_boat"
	s.map_id = "heting"; s.hp = 17; s.qi = 1; s.medicine = 2
	return s


func _at_stage(stage: int, plan: String = "pause_batch"):
	var s = _ready()
	s.capstone_stage = stage
	if stage >= 6: s.capstone_draft = plan; s.capstone_ending = plan
	if stage in [1, 2, 3, 4]: s.map_id = "frostbridge"
	elif stage == 5: s.map_id = "sluice"
	elif stage >= 6: s.map_id = "qingwei"
	return s


func _snapshot(s) -> Dictionary:
	return {"data": s.to_dict().duplicate(true), "battle": [s.battle_active, s._party_pending_token, s.transaction_gate], "callbacks": s.callbacks.duplicate(true)}


func _rejected(s, action: Callable, label: String) -> void:
	var before: Dictionary = _snapshot(s)
	check(not action.call(), label + " rejects")
	check(_snapshot(s) == before, label + " exact unchanged state/callbacks")


func _delta(s, action: Callable, changes: Dictionary, label: String) -> void:
	var before: Dictionary = _snapshot(s)
	var expected: Dictionary = before.duplicate(true)
	for key: String in changes: expected.data[key] = changes[key]
	check(action.call(), label + " accepts")
	check(_snapshot(s) == expected, label + " exact allowed delta")


func _test_old_branch_routes() -> void:
	for opening: String in ["秉公", "守望"]:
		for side: String in ["rescue", "pursuit"]:
			for archive: String in ["open_records", "protect_witness"]:
				for approach: String in ["duel", "repair", "records"]:
					if approach == "records" and archive != "open_records": continue
					for mist: String in ["release_water", "warn_ferries"]:
						for harbor: String in ["short_ferries", "open_scale"]:
							for old_plan: String in Consignee.PLANS:
								for receipt: int in range(4):
									for plan: String in Rules.PLANS:
										var s = _ready(opening, side, archive, mist, approach, harbor, old_plan, receipt)
										_run_route(s, plan)


func _run_route(s, plan: String) -> void:
	routes += 1
	check(Rules.valid(s.to_dict(), 15) and Rules.can_begin(s), "All old valid branch combinations eligible")
	_delta(s, func(): return Rules.begin(s), {"capstone_stage": 1}, "Referral")
	s.map_id = "frostbridge"
	_delta(s, func(): return Rules.reveal_letter(s), {"capstone_stage": 2}, "Original letter returned")
	_delta(s, func(): return Rules.resolve_evidence(s, Rules.CORRECT_ANSWER).ok, {"capstone_stage": 3}, "Issued responsibility")
	_delta(s, func(): return Rules.settle_victory(s), {"capstone_stage": 4}, "Detached victory-model boundary")
	check(s.callbacks.is_empty(), "Victory has no reward callback")
	check(Rules.order_rows(s).size() == 4 and Rules.order_rows(s)[0].evidence == "not_yet_classified", "Win does not classify")
	_delta(s, func(): return Rules.classify_orders(s, Rules.CORRECT_PARTITION).ok, {"capstone_stage": 5}, "Separate persistent classification")
	check(s.capstone_draft.is_empty() and Rules.valid(s.to_dict(), 15), "Classified empty-draft valid")
	_delta(s, func(): return Rules.choose_plan(s, plan), {"capstone_draft": plan}, "Draft")
	for row: Dictionary in Rules.order_rows(s): check(row.disposition == "pending", "Draft has no operational effect")
	check(Rules.journal(s).contains("当前只是草案，四号仍全部待处置"), "Journal never claims draft already executed")
	s.map_id = "sluice"
	_delta(s, func(): return Rules.confirm_disposition(s, plan), {"capstone_stage": 6, "capstone_ending": plan}, "Explicit local disposition")
	check(s.callbacks.is_empty(), "Disposition has no reward callback")
	_check_rows(s, plan)
	s.map_id = "qingwei"
	_reward_delta(s, "Equal homecoming reward")
	check(Rules.goal(s).is_empty(), "Completed goal empty")
	check(Rules.valid(s.to_dict(), 15), "Completed old branches canonical")
	_rejected(s, func(): return Rules.finish_homecoming(s), "Homecoming once only")


func _test_stage_matrix() -> void:
	for stage: int in range(-2, 10):
		for draft: String in ["", "pause_batch", "cancel_proven", "unknown"]:
			for ending: String in ["", "pause_batch", "cancel_proven", "unknown"]:
				var s = _ready()
				var data: Dictionary = s.to_dict()
				data.capstone_stage = stage; data.capstone_draft = draft; data.capstone_ending = ending
				var expected: bool = stage >= 0 and stage <= 7 and draft in ["", "pause_batch", "cancel_proven"] and ending in ["", "pause_batch", "cancel_proven"]
				if stage <= 4: expected = expected and draft.is_empty() and ending.is_empty()
				elif stage == 5: expected = expected and ending.is_empty()
				else: expected = expected and Rules.PLANS.has(draft) and draft == ending
				check(Rules.valid(data, 15) == expected, "Complete stage/draft/ending matrix %s" % [str([stage, draft, ending])])
	for stage: int in range(8):
		for map: String in ["qingwei", "sluice", "frostbridge", "mistwood", "heting"]:
			var s = _at_stage(stage); s.map_id = map
			check(Rules.valid(s.to_dict(), 15), "Every unfinished/finished stage portable across old maps")
			check(Rules.valid(JSON.parse_string(JSON.stringify(s.to_dict())), 15), "Every stage/map roundtrips JSON integral numbers")


func _test_malformed_bundle() -> void:
	var canonical: Dictionary = _ready().to_dict()
	for key: String in Rules.FIELDS:
		for bad: Variant in [null, true, false, [], {}, 0.5, NAN, INF, -INF, "0", "5", Vector2.ZERO]:
			var data: Dictionary = canonical.duplicate(true); data[key] = bad
			check(not Rules.valid(data, 15), "Reject bundle type " + key + " " + str(bad))
	for stage: int in range(8):
		var data: Dictionary = _at_stage(stage).to_dict(); data.capstone_stage = float(stage)
		check(Rules.valid(data, 15), "Integral JSON stage accepted")
	for version: int in range(1, 16):
		for mask: int in range(8):
			var data: Dictionary = canonical.duplicate(true)
			for index: int in 3:
				if mask & (1 << index) == 0: data.erase(Rules.FIELDS[index])
			check(Rules.valid(data, version) == (mask == 7 or (mask == 0 and version < 15)), "All legacy/current bundle masks")
		var data: Dictionary = _at_stage(5).to_dict()
		check(Rules.valid(data, version), "Present full bundle retained in older version")
		data.capstone_draft = "unknown"
		check(not Rules.valid(data, version), "Present malformed legacy bundle never erased")
	for extra: String in ["capstone_reward_claimed", "capstone_book", "capstone_right", "capstone_orders", "capstone_contributions"]:
		var data: Dictionary = canonical.duplicate(true); data[extra] = false
		check(not Rules.valid(data, 15), "No hidden saved capstone field " + extra)
	for version: int in [-2, 0, 16, 99]: check(not Rules.valid(canonical, version), "Unsupported model schema")


func _test_prior_chain() -> void:
	var bad_prior: Dictionary = {
		"quest_stage": 5, "ending": "", "side_stage": 2, "side_choice": "", "side_clues": 1, "side_found": ["boatman"], "side_reward_claimed": false,
		"chapter_two_stage": 3, "chapter_two_ending": "", "archive_clues": ["clerk"], "seal_sequence": [0, 2, 1],
		"mist_stage": 3, "mist_gauges": ["rain", "stone"], "mist_approach": "", "mist_ending": "",
		"heting_stage": 3, "heting_bridge": "", "heting_delivered": ["meal", "sealed"], "heting_cargo": "reserve", "heting_draft": "", "heting_ending": "",
		"receipt_stage": 4, "consignee_stage": 4, "consignee_observations": [], "consignee_contributions": ["invented"], "consignee_draft": "", "consignee_cargo_location": "cart", "consignee_ending": "",
	}
	for key: String in bad_prior:
		for stage: int in range(1, 8):
			var data: Dictionary = _at_stage(stage).to_dict(); data[key] = bad_prior[key]
			check(not Rules.valid(data, 15), "Active progress requires genuine prior " + key)
			data.erase(key)
			check(not Rules.valid(data, 15), "Active progress cannot fabricate missing " + key)
		var s = _ready()
		if bad_prior[key] is Array: s.get(key).assign(bad_prior[key])
		else: s.set(key, bad_prior[key])
		check(Rules.valid(s.to_dict(), 15), "Neutral model does not force completed old story")
		_rejected(s, func(): return Rules.begin(s), "Cannot begin with incomplete " + key)
		check(Rules.goal(s).is_empty(), "Ineligible neutral goal empty")
	for sequence: Variant in [null, true, "2,0,1", [2, 0], [2, 0, 1, 0], [true, 0, 1], [2, false, 1], [2, 0, "1"], [2.5, 0, 1], [2, NAN, 1], [2, 0, INF]]:
		var malformed: Dictionary = _at_stage(1).to_dict(); malformed.seal_sequence = sequence
		check(not Rules.valid(malformed, 15), "Exact typed seal sequence rejects malformed input")
	var data: Dictionary = _at_stage(1).to_dict()
	data.mist_approach = "records"
	check(not Rules.valid(data, 15), "Protected records path cannot be fabricated")
	for key: String in ["quest_stage", "side_stage", "side_clues", "chapter_two_stage", "mist_stage", "heting_stage", "receipt_stage", "consignee_stage"]:
		for bad: Variant in [true, "4", 3.5, NAN, INF]:
			data = _at_stage(1).to_dict(); data[key] = bad
			check(not Rules.valid(data, 15), "Raw prerequisite numeric type " + key)


func _test_partitions() -> void:
	var s = _at_stage(4)
	for bad: Variant in [null, true, false, 4, 4.0, "all", [], Rules.ORDER_IDS.duplicate(), [{"capstone_pending_001": "proven_false"}]]:
		_rejected(s, func(): return Rules.classify_orders(s, bad).ok, "Non-dictionary partition")
	for id: String in Rules.ORDER_IDS:
		var missing: Dictionary = Rules.CORRECT_PARTITION.duplicate(); missing.erase(id)
		_rejected(s, func(): return Rules.classify_orders(s, missing).ok, "Missing order " + id)
		for bad: Variant in [null, true, false, 1, [], {}, "", "verified_valid", "cancelled", "pending", "proven_false" if Rules.CORRECT_PARTITION[id] == "unverified" else "unverified"]:
			var changed: Dictionary = Rules.CORRECT_PARTITION.duplicate(); changed[id] = bad
			_rejected(s, func(): return Rules.classify_orders(s, changed).ok, "Bad row classification " + id)
	for extra: Variant in ["meal", "sealed", "reserve", "disputed_lot", "capstone_pending_005", "", 1]:
		var changed: Dictionary = Rules.CORRECT_PARTITION.duplicate(); changed[extra] = "unverified"
		_rejected(s, func(): return Rules.classify_orders(s, changed).ok, "Extra/old order key")
	# A dictionary cannot contain duplicate keys; duplicate-bearing sequence is
	# rejected as the wrong input type, never silently collapsed into four rows.
	var duplicate_rows: Array = Rules.ORDER_IDS.duplicate(); duplicate_rows.append(Rules.ORDER_IDS[0])
	_rejected(s, func(): return Rules.classify_orders(s, duplicate_rows).ok, "Duplicate-bearing row input")
	var reversed: Dictionary = {}
	for index: int in range(3, -1, -1): reversed[Rules.ORDER_IDS[index]] = Rules.CORRECT_PARTITION[Rules.ORDER_IDS[index]]
	_delta(s, func(): return Rules.classify_orders(s, reversed).ok, {"capstone_stage": 5}, "Exact partition order-independent")
	_rejected(s, func(): return Rules.classify_orders(s, reversed).ok, "Classification cannot repeat")


func _test_guards() -> void:
	for stage: int in range(8):
		for guard: String in ["battle", "pending", "transaction", "hp0", "wrong_map"]:
			var s = _at_stage(stage)
			if stage == 5: s.capstone_draft = "pause_batch"
			match guard:
				"battle": s.battle_active = true
				"pending": s._party_pending_token = 8
				"transaction": s.transaction_gate = true
				"hp0": s.hp = 0
				"wrong_map": s.map_id = "mistwood"
			for action: Callable in _actions(s): _rejected(s, action, "Mutation guard %s stage%d" % [guard, stage])
	# Each API can advance only its exact stage, even if the map is suitable.
	for target_stage: int in range(7):
		for stage: int in range(8):
			if target_stage == stage: continue
			var s = _at_stage(stage)
			s.map_id = ["heting", "frostbridge", "frostbridge", "frostbridge", "sluice", "sluice", "qingwei"][target_stage]
			if stage == 5: s.capstone_draft = "pause_batch"
			_rejected(s, _actions(s)[target_stage], "No skipped/repeated stage")


func _actions(s) -> Array[Callable]:
	return [func(): return Rules.begin(s), func(): return Rules.reveal_letter(s), func(): return Rules.resolve_evidence(s, Rules.CORRECT_ANSWER).ok, func(): return Rules.settle_victory(s), func(): return Rules.classify_orders(s, Rules.CORRECT_PARTITION).ok, func(): return Rules.confirm_disposition(s, "pause_batch"), func(): return Rules.finish_homecoming(s), func(): return Rules.choose_plan(s, "cancel_proven")]


func _test_plans_and_boundaries() -> void:
	var s = _at_stage(2)
	for answer: String in ["watermark_proves_author", "dry_means_whole_ship", "victory_proves_guilt", "", "liang_zhen"]:
		_rejected(s, func(): return Rules.resolve_evidence(s, answer).ok, "Wrong evidence answer")
	s = _at_stage(4)
	for plan: String in Rules.PLANS: _rejected(s, func(): return Rules.choose_plan(s, plan), "No draft before classification")
	for map: String in ["frostbridge", "sluice"]:
		s = _at_stage(4); s.map_id = map
		_delta(s, func(): return Rules.classify_orders(s, Rules.CORRECT_PARTITION).ok, {"capstone_stage": 5}, "Classification allowed map")
		_delta(s, func(): return Rules.choose_plan(s, "pause_batch"), {"capstone_draft": "pause_batch"}, "Draft A")
		_rejected(s, func(): return Rules.choose_plan(s, "pause_batch"), "Identical draft is no-op")
		_delta(s, func(): return Rules.choose_plan(s, "cancel_proven"), {"capstone_draft": "cancel_proven"}, "Draft B")
		_rejected(s, func(): return Rules.confirm_disposition(s, "pause_batch"), "Stale expected A cannot confirm B")
		_delta(s, func(): return Rules.choose_plan(s, "pause_batch"), {"capstone_draft": "pause_batch"}, "Draft A again")
		# Pure rules cannot distinguish old A callback from new A. This is an
		# explicit layer boundary; real callback invalidation is the scene gate.
		for row: Dictionary in Rules.order_rows(s): check(row.disposition == "pending", "A-B-A never executes orders")
		_delta(s, func(): return Rules.choose_plan(s, ""), {"capstone_draft": ""}, "Explicit draft clear")
		_rejected(s, func(): return Rules.confirm_disposition(s, ""), "Empty draft cannot confirm")
		_rejected(s, func(): return Rules.choose_plan(s, "pause_everything"), "Unknown plan")
		_delta(s, func(): return Rules.choose_plan(s, "cancel_proven"), {"capstone_draft": "cancel_proven"}, "Draft for final confirm")
		if map == "frostbridge": _rejected(s, func(): return Rules.confirm_disposition(s, "cancel_proven"), "Archive cannot issue final disposition")
		s.map_id = "sluice"
		_delta(s, func(): return Rules.confirm_disposition(s, "cancel_proven"), {"capstone_stage": 6, "capstone_ending": "cancel_proven"}, "Desk-map disposition")
		_rejected(s, func(): return Rules.confirm_disposition(s, "cancel_proven"), "Disposition once")
		_rejected(s, func(): return Rules.choose_plan(s, "pause_batch"), "Historical ending immutable")
		_rejected(s, func(): return Rules.finish_homecoming(s), "Disposition is not homecoming")


func _recruit(s, method: String) -> void:
	var actor: String = Rules._actor_for(method)
	match actor:
		"tang": s.bridge_repaired = true; s.tangqi_stage = 3; s.tangqi_unlocked = true; s.tangqi_choice = "teach" if method == "tang_teach" else "preserve"
		"shen": s.companion_unlocked = true; s.shen_care_stage = 5; s.shen_care_choice = "shore" if method == "shen_shore" else "mobile"
		"qin": s.qin_stage = 4; s.qin_unlocked = true
	var plan: Dictionary = s.source.PartyRoster.load_plan(s.source, {}, 11)
	check(plan.ok, "Prepare valid recruited-resource model fixture")
	s.source._apply_party_plan(plan)
	check(s.source.set_party_roster(["hero", actor]), "Select prepared eligible helper")


func _test_optional_methods() -> void:
	for method: String in Rules.METHODS:
		var action: String = "classification" if method.begins_with("shen_") else "evidence"
		var s = _at_stage(4 if action == "classification" else 2)
		var actor: String = Rules._actor_for(method)
		var attempt: Callable = func(): return Rules.classify_orders(s, Rules.CORRECT_PARTITION, method).ok if action == "classification" else Rules.resolve_evidence(s, Rules.CORRECT_ANSWER, method).ok
		check(Rules.available_methods(s, action) == ["solo"], "Unrecruited solo always available")
		_rejected(s, attempt, "Unrecruited helper")
		_recruit(s, method)
		check(Rules.available_methods(s, action) == ["solo", method], "Exact completed personal history method")
		s.party_resources[actor].hp = 0
		_rejected(s, attempt, "Downed helper")
		check(Rules.available_methods(s, action) == ["solo"], "Downed helper does not block solo")
		s.party_resources[actor].hp = 1; s.party_roster.assign(["hero"])
		_rejected(s, attempt, "Benched helper")
		s.party_roster.append(actor)
		var history_key: String = "tangqi_stage" if actor == "tang" else ("shen_care_stage" if actor == "shen" else "qin_stage")
		var history: int = s.get(history_key); s.set(history_key, history - 1)
		_rejected(s, attempt, "Incomplete helper history")
		s.set(history_key, history)
		var wrong_action: String = "evidence" if action == "classification" else "classification"
		check(not Rules.available_methods(s, wrong_action).has(method), "No invented helper role")
		_delta(s, attempt, {"capstone_stage": s.capstone_stage + 1}, "Genuine selected standing alternative")
		s.party_resources[actor].hp = 0; s.party_roster.assign(["hero"])
		check(Rules.valid(s.to_dict(), 15), "Completed evidence persists after helper leaves/falls")
		check(not Rules.journal(s).contains(method) and not Rules.journal(s).contains(Rules.method_description(method)), "Journal invents no saved contributor history")
		check(Rules.FIELDS.size() == 3, "No helper/reward/book/right history fields")
		check(not Rules.method_description(method).is_empty(), "Live optional method has honest description")
	var s = _at_stage(2)
	for method: String in ["unknown", "tang", "qin", "shen"]:
		_rejected(s, func(): return Rules.resolve_evidence(s, Rules.CORRECT_ANSWER, method).ok, "Unknown method rejected")
	check(Rules.available_methods(s, "invented").is_empty(), "Unknown action offers no methods")


func _test_optional_matrix() -> void:
	var actors: Array[String] = ["tang", "qin", "shen"]
	for recruit_mask: int in range(8):
		for selected_mask: int in range(8):
			if selected_mask & recruit_mask != selected_mask: continue
			for standing_mask: int in range(8):
				var s = _at_stage(2)
				for index: int in 3:
					if recruit_mask & (1 << index): _recruit(s, ["tang_teach", "qin_timing", "shen_mobile"][index])
				s.party_roster.assign(["hero"])
				for index: int in 3:
					if recruit_mask & (1 << index):
						s.party_resources[actors[index]].hp = 1 if standing_mask & (1 << index) else 0
						s.party_resources[actors[index]].qi = 0
					if selected_mask & (1 << index): s.party_roster.append(actors[index])
				var before: Dictionary = s.to_dict()
				var methods: Array[String] = Rules.available_methods(s, "evidence")
				check(methods.has("solo"), "All recruited/selected/downed combinations preserve solo")
				for index: int in 2:
					var expected: bool = bool(recruit_mask & selected_mask & standing_mask & (1 << index))
					check(methods.has(["tang_teach", "qin_timing"][index]) == expected, "Exact live evidence helper matrix")
				check(not methods.has("shen_mobile"), "Care is not document authorship expertise")
				_delta(s, func(): return Rules.resolve_evidence(s, Rules.CORRECT_ANSWER).ok, {"capstone_stage": 3}, "Solo evidence with any optional roster")
				s.capstone_stage = 4
				methods = Rules.available_methods(s, "classification")
				check(methods.has("shen_mobile") == bool(recruit_mask & selected_mask & standing_mask & 4), "Exact live classification helper matrix")
				_delta(s, func(): return Rules.classify_orders(s, Rules.CORRECT_PARTITION).ok, {"capstone_stage": 5}, "Solo classification with any optional roster")
				check(s.party_resources == before.party_resources and s.party_roster == before.party_roster, "All optional resources/selection preserved")
				check(Rules.valid(s.to_dict(), 15), "Completed classification independent of optional roster condition")
	var s = _at_stage(2)
	_recruit(s, "shen_shore")
	s.shen_care_stage = 0; s.shen_care_choice = ""
	check(Rules.resolve_evidence(s, Rules.CORRECT_ANSWER).ok, "Unfinished optional care never blocks mandatory evidence")
	s.capstone_stage = 4
	check(Rules.available_methods(s, "classification") == ["solo"], "Unfinished care adds no invented method")
	check(Rules.classify_orders(s, Rules.CORRECT_PARTITION).ok and s.shen_care_stage == 0, "Unfinished optional care remains unfinished")


func _reward_delta(s, label: String) -> void:
	var expected = State.new(); expected._copy_persistent_from(s.source)
	expected.coins = mini(999999, expected.coins + Rules.REWARD_COINS)
	expected.gain_xp(Rules.REWARD_XP)
	var expected_data: Dictionary = expected.to_dict()
	expected_data.capstone_stage = 7; expected_data.capstone_draft = s.capstone_draft; expected_data.capstone_ending = s.capstone_ending
	check(Rules.finish_homecoming(s), label + " accepts")
	check(s.to_dict() == expected_data, label + " matches exact existing XP/cap/growth delta")
	check(s.callbacks.size() == 1 and s.callbacks[0].capstone_stage == 7, label + " consumed before callback")


func _test_reward_callbacks() -> void:
	for scenario: String in ["no_level", "cross_level", "multi_level", "level99", "coin_cap"]:
		var branch_results: Array[Dictionary] = []
		for plan: String in Rules.PLANS:
			var s = _at_stage(6, plan)
			_recruit(s, "shen_shore"); _recruit(s, "tang_preserve"); _recruit(s, "qin_timing")
			s.party_resources.shen = {"hp": 0, "qi": 0}
			s.party_resources.tang = {"hp": 3, "qi": 1}
			s.party_resources.qin = {"hp": 2, "qi": 0}
			s.party_roster.assign(["hero", "qin"])
			match scenario:
				"no_level": s.level = 20; s.xp = 0
				"cross_level": s.level = 5; s.xp = s.source.xp_to_next() - 1
				"multi_level": s.level = 1; s.xp = s.source.xp_to_next() - 1
				"level99": s.level = 99; s.xp = s.source.xp_to_next() - 1
				"coin_cap": s.level = 20; s.coins = 999998
			var resources: Dictionary = s.party_resources.duplicate(true)
			var old_hp: int = s.hp; var old_qi: int = s.qi; var old_level: int = s.level
			s.try_reentry = true
			_reward_delta(s, "Reward " + scenario)
			check(s.reentry_rejected, "Reentrant reward blocked after consume")
			check(s.party_resources == resources and s.party_roster == ["hero", "qin"], "Growth preserves wounded/downed/benched absolute resources")
			if scenario in ["no_level", "level99", "coin_cap"]: check(s.hp == old_hp and s.qi == old_qi, "No unexplained recovery without level-up")
			else: check(s.level > old_level and s.hp == s.max_hp and s.qi == s.max_qi, "Actual level-up follows explicit existing recovery policy")
			if scenario == "multi_level": check(s.level >= old_level + 2, "160XP exercises permitted multiple growth")
			if scenario == "coin_cap": check(s.coins == 999999, "Coin reward saturates existing cap")
			var result: Dictionary = s.to_dict(); result.erase("capstone_draft"); result.erase("capstone_ending")
			branch_results.append(result)
			_rejected(s, func(): return Rules.finish_homecoming(s), "Duplicate reward")
		check(branch_results[0] == branch_results[1], "Both endings exactly equal reward effects " + scenario)


func _test_restore_and_save_retry() -> void:
	for stage: int in range(8):
		var s = _at_stage(stage)
		var before: Dictionary = s.to_dict()
		var target = _ready()
		Rules.restore(target, before)
		check(target.capstone_stage == stage and target.capstone_draft == s.capstone_draft and target.capstone_ending == s.capstone_ending, "Restore exact bundle")
		check(target.callbacks.is_empty(), "Restore cannot reward")
		var old: Dictionary = s.source.to_dict()
		for key: String in Rules.FIELDS: old.erase(key)
		Rules.restore(target, old)
		check(target.capstone_stage == 0 and target.capstone_draft.is_empty() and target.capstone_ending.is_empty(), "Wholly absent legacy restores neutral only")
	for boundary: int in range(7):
		var s = _at_stage(boundary)
		if boundary == 5: s.capstone_draft = "pause_batch"
		check(s.persist() == OK, "Persist pre-boundary model snapshot")
		var disk_before: Dictionary = s.persisted.duplicate(true)
		check(_actions(s)[boundary].call(), "Accept boundary before failed save")
		var accepted: Dictionary = s.to_dict()
		s.fail_save = true
		check(s.persist() == ERR_CANT_CREATE and s.persisted == disk_before and s.to_dict() == accepted, "Failed persistence keeps old bytes model and accepted memory")
		_rejected(s, _actions(s)[boundary], "Stale action after accepted boundary")
		s.map_id = "mistwood" # Ordinary later movement is serialized on retry.
		s.fail_save = false
		check(s.persist() == OK and s.persisted == s.to_dict(), "Retry stores current accepted result without rerunning action")
		check(s.callbacks.size() == (1 if boundary == 6 else 0), "No retry callback reward")
	# Classification explicitly persists without draft; portable pause/reload.
	var s = _at_stage(4)
	check(Rules.classify_orders(s, Rules.CORRECT_PARTITION).ok and s.persist() == OK, "Persist empty-draft classification")
	var target = _ready(); Rules.restore(target, s.persisted); target.map_id = "heting"
	check(target.capstone_stage == 5 and target.capstone_draft.is_empty() and Rules.valid(target.to_dict(), 15), "Classified save reload/travel never rolls back")


func _check_rows(s, plan: String) -> void:
	var rows: Array[Dictionary] = Rules.order_rows(s)
	check(rows.size() == 4, "Exactly finite four order rows")
	for index: int in rows.size():
		var expected: String = "cancelled" if index < 2 else ("held" if plan == "pause_batch" else "continuing")
		check(rows[index].id == Rules.ORDER_IDS[index] and rows[index].batch_id == Rules.BATCH, "Stable new order identity")
		check(rows[index].evidence == Rules.CORRECT_PARTITION[Rules.ORDER_IDS[index]] and rows[index].disposition == expected, "Evidence and execution remain separate")


func _test_detached_projections() -> void:
	check(Rules.ORDER_IDS.is_read_only() and Rules.CORRECT_PARTITION.is_read_only(), "Authored catalog constants immutable")
	var sites: Array[String] = ["heting_dispatch", "chapter_host", "chapter_clerk", "chapter_archive", "capstone_order_desk", "capstone_order_desk", "elder", ""]
	for stage: int in range(8):
		var s = _at_stage(stage)
		var snapshot: Dictionary = _snapshot(s)
		var target: Dictionary = Rules.goal(s)
		check(target.get("site_id", "") == sites[stage], "Shared goal corrected for each stage")
		var journal: String = Rules.journal(s)
		if stage < 7: check(journal.contains(target.objective), "Journal consumes identical pure goal")
		var rows: Array[Dictionary] = Rules.order_rows(s)
		check(rows.is_empty() == (stage < 4), "Book only after actual modeled victory boundary")
		if stage == 4:
			for row: Dictionary in rows: check(row.evidence == "not_yet_classified" and row.disposition == "pending", "Preclassification rows honest")
		if stage == 5:
			for row: Dictionary in rows: check(row.evidence == Rules.CORRECT_PARTITION[row.id] and row.disposition == "pending", "Classification alone no execution")
		if stage >= 2: check(journal.contains("交还原信") and journal.contains("不是他的私印") and journal.contains("不知道后来鹤汀"), "Letter reveal/custody/source scope honest")
		if stage >= 3: check(journal.contains("已发签令留底册") and journal.contains("梁缜") and journal.contains("封存证人"), "Responsibility source and privacy honest")
		if stage == 3: check(not journal.contains("取得另一件"), "Prebattle evidence does not claim won pending book")
		if stage >= 4: check(journal.contains("取得另一件本班未发令簿"), "Distinct postbattle book")
		if stage == 6: check(journal.contains("尚未结算"), "Disposition is unpaid")
		if stage == 7: check(journal.contains("仅结算一次") and journal.contains("仍可继续"), "Completed reward and optional exploration honest")
		var projection: Dictionary = Rules.progress(s)
		projection.side_found.clear(); projection.consignee_observations.clear(); projection.party_resources["invented"] = {"hp": 999}
		projection.capstone_stage = 0
		if not target.is_empty(): target.site_id = "invented"
		if not rows.is_empty(): rows[0].id = "meal"; rows[0].evidence = "verified_valid"; rows.clear()
		check(_snapshot(s) == snapshot, "All nested progress/goal/rows read-only detached")
		check(Rules.goal(s).get("site_id", "") == sites[stage], "Mutated goal view cannot poison later consumers")
		if stage >= 4: check(Rules.order_rows(s)[0].id == "capstone_pending_001", "Mutated rows cannot alter catalog")
	for old_id: String in ["meal", "sealed", "reserve", "disputed_lot", "receipt", "old_two_loads"]:
		check(not Rules.ORDER_IDS.has(old_id) and Rules.BATCH != old_id, "No old cargo identity reuse")
	for plan: String in Rules.PLANS: check(Rules.plan_description(plan).contains("003、004") and Rules.plan_description(plan).contains("只限本班四号"), "Finite plan descriptions")
	check(Rules.plan_description("cancel_proven").contains("核验、签收") and Rules.plan_description("cancel_proven").contains("不等于自动放行"), "Continuing is normal verification, not innocence")
	var s = _at_stage(3); s.receipt_stage = 2
	check(not Rules.journal(s).contains("已并看的旧复称副签"), "Optional receipt2 never claims verification")
	s.receipt_stage = 3
	check(Rules.journal(s).contains("已并看的旧复称副签"), "Optional receipt3 contribution accurately limited")
