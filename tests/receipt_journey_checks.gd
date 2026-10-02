extends RefCounted
## This helper is called only after full_journey_test has earned its character.
## Every diagnostic starts from a deep copy of that character. No level, gear,
## proficiency, medicine, currency, quest unlock, or combat resource is granted.
const State = preload("res://scripts/game_state.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
const REPORT_PATH = "user://hero-receipt-natural-balance.json"
var _check: Callable
var rows: Array[Dictionary] = []


func run(source, before_harbor: Dictionary, checker: Callable) -> void:
	_check = checker
	var original: Dictionary = source.to_dict().duplicate(true)
	_check.call(source.heting_stage == 4 and source.receipt_stage == 0,
		"Receipt audit starts only after the actual fresh-start harbor journey")
	_check.call(source.available_companions().size() == 2 and source.available_arts().size() == 4,
		"Receipt audit uses the two earned companions and four genuinely available arts")
	var start_index: int = rows.size()
	for ending: String in State.Heting.PLANS:
		var earned = _clone(original) if ending == source.heting_ending else _finish_other_harbor(before_harbor, ending)
		_check.call(earned.heting_ending == ending and earned.hp == source.hp and earned.qi == source.qi
			and earned.medicine == source.medicine and earned.level == source.level
			and earned.xp == source.xp and earned.coins == source.coins,
			"Both legally completed harbor plans retain the same organic resource budget: " + ending)
		for rest: bool in [false, true]:
			for companion: String in earned.available_companions():
				for formation: String in ["并肩", "护后"]:
					for art: String in earned.available_arts():
						for first_target: String in ["bracer", "striker"]:
							var probe = _clone(earned.to_dict())
							_check.call(probe.select_companion(companion) and probe.set_formation(formation)
								and probe.equip_art(art), "Organic learned build can be selected before combat")
							if rest:
								_shelter_rest(probe)
							var result: Dictionary = _fight(probe, first_target)
							result["preparation"] = "free existing harbor shelter" if rest else "straight from actual harbor ending"
							rows.append(result)
							if rest:
								_check.call(result.outcome == "win", "Free shelter plus legal earned build wins: " + _label(result))
							_check.call(source.to_dict() == original, "Diagnostic combat never mutates the original journey")
			_print_summary(start_index, source.sect, ending, rest)
		_depleted_retry_and_defeat(earned)
		_exhaustion_and_recovery(earned)
	_check.call(source.to_dict() == original and not source.battle_active,
		"All receipt probes preserve the actual journey, harbor ending, resources and unlocks")
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_check.call(file != null, "Organic receipt balance evidence can be written")
	if file != null:
		file.store_string(JSON.stringify(rows, "\t"))
		file.close()


func _clone(data: Dictionary):
	var copy = State.new()
	for key: String in data:
		var value: Variant = data[key]
		if key == "position":
			copy.position = Vector2(float(value.x), float(value.y))
		elif value is Array or value is Dictionary:
			copy.set(key, value.duplicate(true))
		else:
			copy.set(key, value)
	_check.call(copy.to_dict() == data, "Diagnostic clone exactly copies the earned character")
	return copy


func _finish_other_harbor(data: Dictionary, ending: String):
	var copy = _clone(data)
	_check.call(copy.begin_heting(), "Alternate diagnostic branch enters harbor through its real prerequisite")
	# Location is travel, not progression; all cargo, XP and payment use the real rules.
	copy.map_id = "heting"
	for cargo: String in ["meal", "sealed"]:
		_check.call(copy.take_heting_cargo(cargo), "Alternate branch takes finite earned cargo")
		_check.call(copy.deliver_heting_base("heting_relief" if cargo == "meal" else "heting_scale"),
			"Alternate branch delivers the actual base cargo")
	_check.call(copy.choose_heting_plan(ending) and copy.take_heting_cargo("reserve"),
		"Alternate branch chooses its real plan and reserve cargo")
	_check.call(copy.finish_heting_delivery("heting_relief" if ending == "short_ferries" else "heting_scale", ending),
		"Alternate branch earns its harbor ending through real delivery")
	return copy


func _shelter_rest(probe) -> void:
	var before: Dictionary = probe.to_dict()
	_check.call(probe.map_id == "heting" and not probe.battle_active and probe.heting_cargo.is_empty(),
		"Free shelter rest remains available to the finished-harbor character")
	# HetingStory.rest uses this existing operation after checking the west shelter.
	probe.heal_rest()
	_check.call(probe.hp == probe.max_hp and probe.qi == probe.max_qi
		and probe.medicine == before.medicine and probe.coins == before.coins
		and probe.resources == before.resources and probe.art_uses == before.art_uses,
		"Explicit existing shelter rest restores HP/qi without buying or granting medicine")


func _start(probe, first_target: String) -> Dictionary:
	var before: Dictionary = probe.to_dict()
	_check.call(probe.begin_receipt() and probe.start_receipt_battle(), "Organic harbor character starts optional receipt combat")
	_check.call(probe.hp == before.hp and probe.qi == before.qi and probe.medicine == before.medicine,
		"Receipt entry grants no initial full heal, qi refill or medicine")
	_check.call(probe.receipt_session.hp == before.hp and probe.receipt_session.qi == before.qi
		and probe.receipt_session.medicine == before.medicine,
		"Detached combat receives exact current organic resources")
	_check.call(probe.select_receipt_target(first_target), "Either legal first target can be selected")
	return before


func _take(probe, action: String) -> Dictionary:
	var coins_before: int = probe.coins
	var stage_before: int = probe.receipt_stage
	var tx: Dictionary = probe.receipt_battle_action(action)
	_check.call(bool(tx.get("accepted", false)), "Receipt policy only chooses legal action: " + action)
	if not bool(tx.get("accepted", false)):
		return tx
	_check.call(probe.battle_active and probe.coins == coins_before and probe.receipt_stage == stage_before,
		"Accepted receipt action cannot settle before its presentation token")
	_check.call(probe.medicine == int(tx.before.medicine) - (1 if action == "item" else 0)
		and probe.hp == int(tx.after.hp) and probe.qi == int(tx.after.qi),
		"Receipt action commits real spent medicine, health and qi immediately")
	if action == "skill":
		_check.call(int(tx.hero_qi_delta) == -probe.active_art_cost()
			and int(probe.art_uses.get(probe.equipped_art, 0)) == mini(9999, int(tx.before.art_uses.get(probe.equipped_art, 0)) + 1),
			"Real learned skill pays its full qi price and earns one actual use")
	elif action == "attack":
		_check.call(int(tx.hero_qi_delta) == mini(2, probe.max_qi - int(tx.before.qi)),
			"Basic attack restores qi without requiring supplies")
	elif action == "guard":
		_check.call(int(tx.hero_qi_delta) == mini(1, probe.max_qi - int(tx.before.qi)),
			"Guard restores qi without requiring supplies")
	var epoch: int = int(tx.epoch)
	var token: int = int(tx.token)
	_check.call(probe.finish_receipt_presentation(epoch, token), "Accepted receipt action completes with its own presentation token")
	var settled: Dictionary = probe.to_dict()
	_check.call(not probe.finish_receipt_presentation(epoch, token) and probe.to_dict() == settled,
		"Duplicate receipt presentation never repeats costs, rewards or settlement")
	return tx


func _fight(probe, first_target: String, supplies: bool = true, allow_skill: bool = true) -> Dictionary:
	var before: Dictionary = _start(probe, first_target)
	var actions: Array[String] = []
	var damage_received: int = 0
	var hp_at_finish: int = probe.hp
	var lowest_hp: int = probe.hp
	var skill_uses: int = 0
	for step: int in range(160):
		if not probe.battle_active:
			break
		var action: String = _choose_action(probe, supplies, allow_skill)
		var tx: Dictionary = _take(probe, action)
		if not bool(tx.get("accepted", false)):
			break
		actions.append(action)
		damage_received += int(tx.counter_damage)
		hp_at_finish = int(tx.after.hp)
		lowest_hp = mini(lowest_hp, hp_at_finish)
		if action == "skill":
			skill_uses += 1
	_check.call(not probe.battle_active, "Sane legal receipt strategy reaches a terminal result within 160 actions")
	var outcome: String = String(probe.receipt_settlement.get("outcome", "stalled"))
	if outcome == "win":
		_check.call(probe.receipt_stage == 2 and probe.coins == int(before.coins) + State.Receipt.REWARD_COINS
			and _total_xp(probe) == _total_xp_dict(before) + State.Receipt.REWARD_XP,
			"Receipt victory grants exactly its finite coins and XP once")
		_check.call(probe.compare_receipt() and not probe.compare_receipt(), "Recovered receipt is compared exactly once")
		_check.call(not probe.begin_receipt() and not probe.start_receipt_battle(), "Completed receipt cannot be farmed")
	var result: Dictionary = {
		"school": before.sect, "ending": before.heting_ending, "level": before.level,
		"attack": before.attack, "defense": before.defense, "equipment": before.equipment, "armor": before.armor,
		"art": before.equipped_art, "art_rank_start": _rank(int(before.art_uses.get(before.equipped_art, 0))),
		"companion": before.active_companion, "formation": before.formation, "first_target": first_target,
		"hp_start": before.hp, "max_hp": before.max_hp, "qi_start": before.qi,
		"medicine_start": before.medicine, "medicine_spent": int(before.medicine) - probe.medicine,
		"qi_end": probe.qi, "hp_before_reward": hp_at_finish, "lowest_hp": lowest_hp,
		"counter_damage": damage_received, "skill_uses": skill_uses, "turns": actions.size(),
		"outcome": outcome, "actions": actions, "art_uses_start": before.art_uses,
	}
	if outcome != "win":
		print("RECEIPT NATURAL NONWIN: ", JSON.stringify(result))
	return result


func _choose_action(probe, supplies: bool, allow_skill: bool) -> String:
	var combat = probe.receipt_session
	var snapshot: Dictionary = combat.snapshot()
	var target: Dictionary = combat.selected_unit()
	var definition: Dictionary = combat.skill_definition()
	var heavy: bool = false
	var incoming: int = 0
	for enemy: Dictionary in snapshot.units:
		if int(enemy.hp) > 0 and enemy.intent_data.kind == "attack":
			heavy = heavy or bool(enemy.intent_data.heavy)
			incoming += maxi(1, int(enemy.intent_data.damage) - probe.defense)
	var skill_damage: int = Advanced.direct_damage(definition, probe.attack, combat.art_rank)
	if bool(target.brace):
		skill_damage = int(ceil(float(skill_damage) * 0.5))
	var can_skill: bool = combat.action_unavailable_reason("skill").is_empty()
	var skill_stops_attacker: bool = target.id == "striker" and skill_damage >= int(target.hp)
	if supplies and probe.medicine > 0 and probe.hp <= incoming + 24 and probe.hp < probe.max_hp:
		return "item"
	if allow_skill and can_skill and (not heavy or bool(definition.guard) or skill_stops_attacker):
		return "skill"
	if heavy:
		return "guard"
	return "attack"


func _depleted_retry_and_defeat(earned) -> void:
	var probe = _clone(earned.to_dict())
	_start(probe, "striker")
	_take(probe, "skill")
	_take(probe, "flee")
	_check.call(probe.hp < probe.max_hp and probe.qi < probe.max_qi,
		"A genuine first attempt creates injured, qi-depleted resources without fixture injection")
	var before_retry: Dictionary = probe.to_dict()
	_start(probe, "striker")
	_check.call(probe.hp == before_retry.hp and probe.qi == before_retry.qi
		and probe.hp < probe.max_hp and probe.qi < probe.max_qi,
		"Immediate retry preserves genuine injury and qi depletion instead of granting a full heal")
	var spent_medicine: bool = false
	for step: int in range(400):
		if not probe.battle_active:
			break
		if not spent_medicine and probe.medicine > 0 and probe.max_hp - probe.hp >= probe.receipt_session.medicine_heal:
			_take(probe, "item")
			spent_medicine = true
		else:
			_take(probe, "guard")
	_check.call(not probe.battle_active and probe.receipt_settlement.get("outcome") == "defeat"
		and probe.receipt_stage == 1 and probe.medicine == int(before_retry.medicine) - (1 if spent_medicine else 0)
		and probe.art_uses == before_retry.art_uses
		and probe.coins == maxi(0, int(before_retry.coins) - 8),
		"Defeat after a real medicine use retains that cost and previously earned art use")
	print("RECEIPT DEPLETED RETRY: school=%s ending=%s hp=%d/%d qi=%d/%d medicine_spent_before_defeat=%d" % [
		earned.sect, earned.heting_ending, before_retry.hp, before_retry.max_hp,
		before_retry.qi, before_retry.max_qi, int(spent_medicine)])


func _exhaustion_and_recovery(earned) -> void:
	var probe = _clone(earned.to_dict())
	var original_medicine: int = probe.medicine
	var flee_uses_seen: bool = false
	# Spend only real earned medicines. Guard until one full dose is useful,
	# use it in a genuine attempt, then flee; no zero-resource fixture injection.
	for dose: int in range(original_medicine):
		_shelter_rest(probe)
		_start(probe, "bracer")
		var uses_before: int = int(probe.art_uses.get(probe.equipped_art, 0))
		if dose == 0:
			_take(probe, "skill")
		for step: int in range(100):
			if not probe.battle_active or probe.max_hp - probe.hp >= probe.receipt_session.medicine_heal:
				break
			_take(probe, "guard")
		_check.call(probe.battle_active and probe.hp > 0, "Natural character can spend an earned medicine before retreating")
		var medicine_before: int = probe.medicine
		_take(probe, "item")
		var resources_before_flee: Dictionary = probe.to_dict()
		_take(probe, "flee")
		_check.call(probe.receipt_settlement.outcome == "flee" and probe.receipt_stage == 1
			and probe.hp == resources_before_flee.hp and probe.qi == resources_before_flee.qi
			and probe.medicine == medicine_before - 1 and probe.coins == resources_before_flee.coins
			and int(probe.art_uses.get(probe.equipped_art, 0)) == uses_before + (1 if dose == 0 else 0),
			"Retreat retains actual medicine and qi costs, health loss and earned art use")
		flee_uses_seen = true
	_check.call(probe.medicine == 0, "Only real combat use exhausts all naturally earned medicine")
	if original_medicine > 0:
		_check.call(flee_uses_seen, "Earned supply exhaustion verifies a real skill and medicine before fleeing")
	# A later defeat must retain proficiency and cannot reward or consume the quest.
	_shelter_rest(probe)
	_start(probe, "striker")
	_take(probe, "skill")
	var coins_before_defeat: int = probe.coins
	var uses_before_defeat: Dictionary = probe.art_uses.duplicate(true)
	for step: int in range(400):
		if not probe.battle_active:
			break
		_take(probe, "guard")
	_check.call(not probe.battle_active and probe.receipt_settlement.get("outcome") == "defeat"
		and probe.receipt_stage == 1 and probe.medicine == 0 and probe.art_uses == uses_before_defeat
		and probe.coins == maxi(0, coins_before_defeat - 8),
		"A real zero-medicine defeat retains learned use and permits an unpaid retry")
	for companion: String in probe.available_companions():
		for formation: String in ["并肩", "护后"]:
			var retry = _clone(probe.to_dict())
			_check.call(retry.select_companion(companion) and retry.set_formation(formation),
				"Resource recovery only selects genuinely available companion/formation")
			_shelter_rest(retry)
			var recovery: Dictionary = _fight(retry, "bracer", false, false)
			_check.call(recovery.outcome == "win" and recovery.medicine_spent == 0 and recovery.skill_uses == 0,
				"Existing free shelter plus basic attack/guard clears receipt without medicine, skill or purchase")
			print("RECEIPT RECOVERY: school=%s ending=%s companion=%s formation=%s exhausted=%d defeat_cost=8 attack_guard_turns=%d hp=%d/%d medicines=%d" % [
				earned.sect, earned.heting_ending, companion, formation, original_medicine, recovery.turns,
				recovery.hp_before_reward, recovery.max_hp, retry.medicine])


func _print_summary(start: int, school: String, ending: String, rest: bool) -> void:
	var wins: int = 0
	var count: int = 0
	var minimum_hp: int = 9999
	var maximum_medicine: int = 0
	var minimum_turns: int = 9999
	var maximum_turns: int = 0
	for index: int in range(start, rows.size()):
		var row: Dictionary = rows[index]
		if row.ending != ending or (row.preparation == "free existing harbor shelter") != rest:
			continue
		count += 1
		if row.outcome == "win":
			wins += 1
		minimum_hp = mini(minimum_hp, int(row.hp_before_reward))
		maximum_medicine = maxi(maximum_medicine, int(row.medicine_spent))
		minimum_turns = mini(minimum_turns, int(row.turns))
		maximum_turns = maxi(maximum_turns, int(row.turns))
	print("RECEIPT NATURAL: school=%s ending=%s shelter_rest=%s wins=%d/%d turns=%d..%d hp_before_reward_min=%d max_medicine_spent=%d" % [
		school, ending, rest, wins, count, minimum_turns, maximum_turns, minimum_hp, maximum_medicine])


func _label(row: Dictionary) -> String:
	return "%s/%s/%s/%s/%s/%s-first hp=%d/%d qi=%d medicine=%d outcome=%s" % [
		row.school, row.ending, row.companion, row.formation, row.art, row.first_target,
		row.hp_start, row.max_hp, row.qi_start, row.medicine_start, row.outcome]


func _rank(uses: int) -> int:
	return 3 if uses >= 15 else (2 if uses >= 5 else 1)


func _total_xp(probe) -> int:
	return probe.xp + 30 * probe.level * (probe.level - 1)


func _total_xp_dict(data: Dictionary) -> int:
	return int(data.xp) + 30 * int(data.level) * (int(data.level) - 1)
