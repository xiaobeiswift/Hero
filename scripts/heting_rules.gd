class_name HetingRules
extends RefCounted
## Three finite cargo batches. A loaded final cart never locks the draft plan.
## The scene owns distance/modal guards, travel, and saving successful changes.
const FIELDS: Array[String] = ["heting_stage", "heting_bridge", "heting_delivered", "heting_cargo", "heting_draft", "heting_ending"]
const BRIDGES: Array[String] = ["west", "east"]
const BASE_CARGO: Array[String] = ["meal", "sealed"]
const CARGO: Array[String] = ["meal", "sealed", "reserve"]
const PLANS: Array[String] = ["short_ferries", "open_scale"]
const MIST_ENDINGS: Array[String] = ["release_water", "warn_ferries"]
const MAIN_SOURCE: String = "heting_cargo"
const RESERVE_SOURCE: String = "heting_lighter"
const RELIEF: String = "heting_relief"
const SCALE: String = "heting_scale"


static func can_begin(s) -> bool:
	return not s.battle_active and s.heting_stage == 0 and s.mist_stage == 4 \
		and MIST_ENDINGS.has(s.mist_ending) and valid(_progress(s), 9)


static func begin(s) -> bool:
	if not can_begin(s):
		return false
	s.heting_bridge = "east" if s.mist_ending == "release_water" else "west"
	s.heting_stage = 1
	return true


static func set_bridge(s, side: String) -> bool:
	if not _can_mutate(s) or not BRIDGES.has(side) or s.heting_bridge == side:
		return false
	s.heting_bridge = side
	return true


static func available_cargo(s, source: String) -> Array[String]:
	var result: Array[String] = []
	if not _at_port(s) or not s.heting_cargo.is_empty():
		return result
	if s.heting_stage == 1 and source == MAIN_SOURCE:
		for id: String in BASE_CARGO:
			if not s.heting_delivered.has(id):
				result.append(id)
	elif s.heting_stage == 3 and source == RESERVE_SOURCE:
		result.append("reserve")
	return result


static func take_cargo(s, id: String) -> bool:
	if not _can_mutate(s):
		return false
	var source: String = RESERVE_SOURCE if id == "reserve" else MAIN_SOURCE
	if not available_cargo(s, source).has(id):
		return false
	s.heting_cargo = id
	return true


static func park_cargo(s) -> bool:
	if not _can_mutate(s) or s.heting_cargo.is_empty():
		return false
	# Inventory is derived from delivered + cargo; returning needs no extra stock.
	s.heting_cargo = ""
	return true


static func deliver_base(s, receiver: String) -> bool:
	if not _can_mutate(s) or s.heting_stage != 1 or not BASE_CARGO.has(s.heting_cargo):
		return false
	var expected: String = RELIEF if s.heting_cargo == "meal" else SCALE
	if receiver != expected:
		return false
	s.heting_delivered.append(s.heting_cargo)
	s.heting_cargo = ""
	if s.heting_delivered.size() == 2:
		s.heting_stage = 2
	s.gain_xp(10)
	return true


static func choose_plan(s, id: String) -> bool:
	if not _can_mutate(s) or s.heting_stage not in [2, 3] or not PLANS.has(id) or s.heting_draft == id:
		return false
	s.heting_draft = id
	s.heting_stage = 3
	return true


static func finish_delivery(s, receiver: String, expected_plan: String) -> bool:
	if not _can_mutate(s) or s.heting_stage != 3 or s.heting_cargo != "reserve" \
		or not PLANS.has(expected_plan) or s.heting_draft != expected_plan:
		return false
	var expected: String = RELIEF if expected_plan == "short_ferries" else SCALE
	if receiver != expected:
		return false
	# Mark completion before rewards. Neither a stale callback nor restore can pay twice.
	s.heting_delivered.append("reserve")
	s.heting_cargo = ""
	s.heting_ending = s.heting_draft
	s.heting_stage = 4
	s.coins = mini(999999, s.coins + 60)
	s.gain_xp(100)
	return true


static func restore(s, data: Dictionary) -> void:
	# HeroState validates the entire document before reset/restore. Preserve order
	# verbatim: loading is never a delivery, stage advance, or reward event.
	s.heting_stage = int(data.get("heting_stage", 0))
	s.heting_bridge = data.get("heting_bridge", "")
	s.heting_delivered.assign(data.get("heting_delivered", []))
	s.heting_cargo = data.get("heting_cargo", "")
	s.heting_draft = data.get("heting_draft", "")
	s.heting_ending = data.get("heting_ending", "")


static func valid(data: Dictionary, version: int) -> bool:
	var present: int = 0
	for key: String in FIELDS:
		if data.has(key):
			present += 1
	# Old versions may omit the whole feature, never an incomplete field bundle.
	if (version >= 9 and present != FIELDS.size()) or (present > 0 and present != FIELDS.size()):
		return false
	var stage = data.get("heting_stage", 0)
	if not (stage is int or stage is float) or not is_finite(float(stage)):
		return false
	if float(stage) != floor(float(stage)) or stage < 0 or stage > 4:
		return false
	var bridge = data.get("heting_bridge", "")
	var cargo = data.get("heting_cargo", "")
	var draft = data.get("heting_draft", "")
	var ending = data.get("heting_ending", "")
	for value in [bridge, cargo, draft, ending]:
		if not value is String:
			return false
	if (not bridge.is_empty() and not BRIDGES.has(bridge)) or (not cargo.is_empty() and not CARGO.has(cargo)):
		return false
	if (not draft.is_empty() and not PLANS.has(draft)) or (not ending.is_empty() and not PLANS.has(ending)):
		return false
	var delivered = data.get("heting_delivered", [])
	if not delivered is Array or delivered.size() > 3:
		return false
	var seen: Array[String] = []
	for id in delivered:
		if not id is String or not CARGO.has(id) or seen.has(id):
			return false
		seen.append(id)
	if delivered.has(cargo):
		return false
	if stage == 0:
		return bridge.is_empty() and delivered.is_empty() and cargo.is_empty() \
			and draft.is_empty() and ending.is_empty() and data.get("map_id", "") != "heting"
	var mist_stage = data.get("mist_stage", 0)
	if not (mist_stage is int or mist_stage is float) or not is_finite(float(mist_stage)) \
		or mist_stage != 4 or not MIST_ENDINGS.has(data.get("mist_ending", "")):
		return false
	if not BRIDGES.has(bridge) or (not cargo.is_empty() and data.get("map_id", "") != "heting"):
		return false
	if stage == 1:
		return delivered.size() <= 1 and not delivered.has("reserve") \
			and cargo in ["", "meal", "sealed"] and draft.is_empty() and ending.is_empty()
	# Every later stage requires both base batches, in the actual delivery order.
	if delivered.size() < 2 or delivered[0] not in BASE_CARGO or delivered[1] not in BASE_CARGO:
		return false
	if stage == 2:
		return delivered.size() == 2 and cargo.is_empty() and draft.is_empty() and ending.is_empty()
	if stage == 3:
		return delivered.size() == 2 and cargo in ["", "reserve"] and PLANS.has(draft) and ending.is_empty()
	return delivered.size() == 3 and delivered[2] == "reserve" and cargo.is_empty() \
		and PLANS.has(draft) and draft == ending


static func _progress(s) -> Dictionary:
	return {
		"heting_stage": s.heting_stage, "heting_bridge": s.heting_bridge,
		"heting_delivered": s.heting_delivered, "heting_cargo": s.heting_cargo,
		"heting_draft": s.heting_draft, "heting_ending": s.heting_ending,
		"mist_stage": s.mist_stage, "mist_ending": s.mist_ending, "map_id": s.map_id,
	}


static func _at_port(s) -> bool:
	return s.map_id == "heting" and s.heting_stage in [1, 2, 3, 4] and valid(_progress(s), 9)


static func _can_mutate(s) -> bool:
	return not s.battle_active and _at_port(s)
