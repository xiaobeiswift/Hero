class_name AdvancedMartialRules
extends RefCounted
## Atomic learning, one-time deed receipts, and transient martial effects.
const Arts = preload("res://scripts/martial_catalog.gd")
const DEEDS: Array[String] = ["sluice", "archive"]


static func is_advanced(id: String) -> bool:
	return int(Arts.definition(id).get("required_sect_rank", 0)) >= 2


static func available(state) -> Array[String]:
	var result: Array[String] = []
	for id: String in Arts.available_for(state.sect):
		if not is_advanced(id) or state.learned_arts.has(id):
			result.append(id)
	return result


static func can_learn(state, id: String) -> bool:
	var definition: Dictionary = Arts.definition(id)
	return not state.battle_active and is_advanced(id) \
		and definition.get("sect", "") == state.sect \
		and state.sect_rank >= int(definition.get("required_sect_rank", 2)) \
		and not state.learned_arts.has(id) \
		and state.sect_merit >= int(definition.get("learn_cost", 0))


static func learn(state, id: String) -> bool:
	if not can_learn(state, id):
		return false
	state.sect_merit -= int(Arts.definition(id)["learn_cost"])
	state.learned_arts.append(id)
	state.learned_arts = ordered_arts(state.learned_arts)
	return true


static func can_claim_deed(state, id: String) -> bool:
	if state.battle_active or state.sect_rank < 2 or not state.SECTS.has(state.sect) \
		or state.sect_merit >= 9999 or state.claimed_deeds.has(id):
		return false
	match id:
		"sluice":
			return state.side_stage == 3 and state.side_reward_claimed
		"archive":
			return state.chapter_two_stage == 4 \
				and state.chapter_two_ending in ["open_records", "protect_witness"]
	return false


static func eligible_deeds(state) -> Array[String]:
	var result: Array[String] = []
	for id: String in DEEDS:
		if can_claim_deed(state, id):
			result.append(id)
	return result


static func claim_deed(state, id: String) -> bool:
	if not can_claim_deed(state, id):
		return false
	state.sect_merit += 1
	state.claimed_deeds.append(id)
	state.claimed_deeds = ordered_deeds(state.claimed_deeds)
	return true


static func direct_damage(definition: Dictionary, attack: int, rank: int) -> int:
	return attack * int(definition["attack_multiplier"]) \
		+ int(definition["damage_bonus"]) + 3 * (rank - 1)


static func focus_damage(definition: Dictionary, attack: int) -> int:
	return attack * int(definition.get("focus_attack_multiplier", 0)) \
		+ int(definition.get("focus_bonus", 0))


static func apply_effects(state, definition: Dictionary, messages: Array[String]) -> void:
	var amount: int = int(definition.get("weaken_amount", 0))
	var strikes: int = int(definition.get("weaken_strikes", 0))
	if amount > 0 and strikes > 0:
		state.enemy_weaken_amount = maxi(state.enemy_weaken_amount, amount)
		state.enemy_weaken_strikes = maxi(state.enemy_weaken_strikes, strikes)
		messages.append("施加卸劲：敌方基础伤害 -%d，剩余 %d 次攻击。" % [state.enemy_weaken_amount, state.enemy_weaken_strikes])
	var focus: int = focus_damage(definition, state.attack)
	if focus > 0:
		state.focused_damage = maxi(state.focused_damage, focus)
		messages.append("蓄锋：下一次平击额外 +%d 点伤害。" % state.focused_damage)


static func clear_effects(state) -> void:
	state.enemy_weaken_amount = 0
	state.enemy_weaken_strikes = 0
	state.focused_damage = 0


static func consume_weaken(state) -> void:
	state.enemy_weaken_strikes = maxi(0, state.enemy_weaken_strikes - 1)
	if state.enemy_weaken_strikes == 0:
		state.enemy_weaken_amount = 0


static func valid_save(data: Dictionary, version: int, saved_sect: String, saved_rank: int) -> bool:
	for key: String in ["learned_arts", "claimed_deeds"]:
		if version >= 5 and not data.has(key):
			return false
		if data.has(key) and not data[key] is Array:
			return false
		for id: Variant in data.get(key, []):
			if not id is String:
				return false
	for id: String in data.get("learned_arts", []):
		if not is_advanced(id) or saved_rank < 2 or Arts.definition(id).get("sect", "") != saved_sect:
			return false
	for id: String in data.get("claimed_deeds", []):
		if not DEEDS.has(id):
			return false
	return true


static func ordered_arts(ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in Arts.all_ids():
		if ids.has(id):
			result.append(id)
	return result


static func ordered_deeds(ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id: String in DEEDS:
		if ids.has(id):
			result.append(id)
	return result
