extends SceneTree
## Independent review; synthetic bounded mechanics states, not earned balance.
const State = preload("res://scripts/game_state.gd")
const Q = preload("res://scripts/heting_consignee_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	_terminal_mutations()
	_reward_mutations()
	_serialized_progress()
	print("%s: %d independent whole-state, terminal-provenance and reward adversarial checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
func _port():
	var s := State.new()
	s.level = 6; s.max_hp = 160; s.hp = 91; s.attack = 99; s.defense = 99
	s.quest_stage = 6; s.ending = "守望"; s.sect = "听潮阁"; s.sect_rank = 1
	s.map_id = "heting"; s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"]); s.mist_ending = "warn_ferries"
	s.heting_stage = 4; s.heting_bridge = "west"; s.heting_delivered.assign(["sealed", "meal", "reserve"]); s.heting_draft = "open_scale"; s.heting_ending = "open_scale"
	check(s._stage_save_data(s.to_dict(), 14).ok, "Synthetic baseline whole state validates")
	return s
func _ready():
	var s = _port()
	check(s.begin_consignee(), "Begin independent public transition")
	for observation: String in ["southern_counterfoil", "lot_seals", "removal_order"]: check(s.observe_consignee(observation), "Out-of-order independent solo evidence")
	check(s.resolve_consignee_contradiction(Q.CORRECT_ANSWER).ok, "Independent earned contradiction")
	check(s.choose_consignee_plan(Q.PLANS[0]), "Independent reversible draft")
	return s
func _terminal(s, outcome: String) -> Dictionary:
	check(s.start_party_battle("heting_consignee"), "New verified session")
	if outcome == "flee":
		return s.party_battle_action("flee")
	var tx: Dictionary = {}
	for iteration: int in range(100):
		tx = s.advance_party_battle()
		check(tx.get("accepted", false), "Real model accepts next action")
		if not tx.get("accepted", false): break
		if not tx.after.active: return tx
		check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Nonterminal exact token")
	check(false, "Bounded terminal achieved")
	return tx
func _mutated(value: Variant) -> Variant:
	if value is bool: return not value
	if value is int or value is float: return value + 1
	if value is String: return value + ".changed"
	if value is Array:
		var a: Array = value.duplicate(true)
		if not a.is_empty(): a.append(a[0])
		elif a.get_typed_builtin() == TYPE_INT: a.append(99)
		elif a.get_typed_builtin() == TYPE_DICTIONARY: a.append({})
		else: a.append("changed")
		return a
	if value is Dictionary: var d: Dictionary = value.duplicate(true); d["changed"] = 1; return d
	return null
func _terminal_mutations() -> void:
	for outcome: String in ["flee", "win"]:
		var s = _ready()
		var tx: Dictionary = _terminal(s, outcome)
		var stable = s._detached_persistent_state()
		var snapshot: Dictionary = s.party_session.snapshot()
		check(snapshot.outcome == outcome, "Actual intended terminal")
		for key: String in stable.to_dict():
			# active_companion is a derived serialization projection, not the
			# compatibility alias field; its direct mutation changes no payload.
			if key == "active_companion": continue
			if key == "position": s.position += Vector2(1, 1)
			else:
				var value: Variant = _mutated(s.get(key))
				if value is Array: s.get(key).assign(value)
				else: s.set(key, value)
			var before: Dictionary = s.to_dict()
			check(not s.finish_party_presentation(tx.epoch, tx.token).accepted, "Mutation of every persistent field rejects terminal: " + key)
			check(s.to_dict() == before and s.battle_active and s._party_pending_token == tx.token and s.party_session.snapshot() == snapshot, "Rejected terminal is nondestructive: " + key)
			s._copy_persistent_from(stable)
		for key: String in snapshot:
			var forged: Dictionary = snapshot.duplicate(true)
			forged[key] = _mutated(forged[key])
			check(not s._party_terminal_plan(forged).ok, "Any detached terminal snapshot field forgery rejects: " + key)
			check(s.to_dict() == stable.to_dict() and s._party_pending_token == tx.token, "Detached proof rejection leaves accepted transaction intact")
		check(s.finish_party_presentation(tx.epoch, tx.token).accepted, "Corrected same actual token settles exactly once")
		var after: Dictionary = s.to_dict()
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and s.to_dict() == after, "Replay cannot pay or mutate")
		check(s.consignee_stage == (3 if outcome == "win" else 2) and s.coins == stable.coins and s.xp == stable.xp, "Win secures, flee retains; neither pays")
func _reward_mutations() -> void:
	var s = _ready()
	var tx: Dictionary = _terminal(s, "win")
	check(s.finish_party_presentation(tx.epoch, tx.token).accepted and s.take_consignee_cargo(Q.BATCH, Q.SOURCE), "One secured lot on cart")
	var stable = s._detached_persistent_state()
	for key: String in ["coins", "medicine", "xp", "hp", "qi"]:
		s.set(key, -1)
		var before: Dictionary = s.to_dict()
		check(not s.finish_consignee_delivery(Q.SCALE, Q.PLANS[0]) and s.to_dict() == before, "Reward cannot repair invalid lower resource: " + key)
		s._copy_persistent_from(stable)
	for blocker: String in ["battle", "pending"]:
		if blocker == "battle": s.battle_active = true
		else: s._party_pending_token = 999
		var before: Dictionary = s.to_dict()
		check(not s.finish_consignee_delivery(Q.SCALE, Q.PLANS[0]) and s.to_dict() == before, "Cannot pay through stale transient blocker: " + blocker)
		s.battle_active = false; s._party_pending_token = -1
	check(s.park_consignee_cargo() and s.choose_consignee_plan(Q.PLANS[1]) and s.take_consignee_cargo(Q.BATCH, Q.SOURCE), "Park/change/retake keeps finite original lot")
	check(not s.finish_consignee_delivery(Q.SCALE, Q.PLANS[0]), "Stale handover callback fails")
	check(s.finish_consignee_delivery(Q.GRAIN_BOAT, Q.PLANS[1]), "Actual last choice pays")
	check(s.coins == stable.coins + 60 and s.xp == stable.xp + 120 and s.hp == stable.hp, "Exact no-level-up reward leaves wounds")
func _serialized_progress() -> void:
	var s = _ready()
	var data: Dictionary = s.to_dict()
	var neutral = _port().to_dict()
	for version: int in range(1, 14):
		var legacy: Dictionary = neutral.duplicate(true)
		for key: String in Q.FIELDS: legacy.erase(key)
		# Use real fixtures for full old layout. Here test new schema bundle's
		# all-or-none rule independently for every legacy version.
		for mask: int in range(1, 63):
			var partial: Dictionary = legacy.duplicate(true)
			for index: int in range(Q.FIELDS.size()):
				if mask & (1 << index): partial[Q.FIELDS[index]] = neutral[Q.FIELDS[index]]
			check(not Q.valid(partial, version), "Every partial legacy chapter combination rejects")
	var raw: Dictionary = data.duplicate(true)
	for key: String in ["consignee_stage", "receipt_stage", "heting_stage"]: raw[key] = float(raw[key])
	var inspected: Dictionary = s.inspect_save_bytes(JSON.stringify({"version":14,"player":raw}).to_utf8_buffer())
	check(inspected.ok and s._same_save_value(inspected.state.to_dict(), data), "Valid JSON integer-valued floats retain canonical exact state")
	var before: Dictionary = s.to_dict()
	for bytes: PackedByteArray in [PackedByteArray(), "null".to_utf8_buffer(), "[]".to_utf8_buffer(), "{\"version\":14,\"player\":null}".to_utf8_buffer()]:
		check(not s.inspect_save_bytes(bytes).ok and s.to_dict() == before, "Malformed envelope is detached")
