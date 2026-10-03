class_name HetingConsigneeRules
extends RefCounted
## Phase-one model for 未损先收. No scene, art, travel, save, or combat controller.
## The host must establish actual scene proximity for each observation/source/
## receiver, and confirm departure before park_cargo. Closing a prompt does not
## invoke a mutation. A verified terminal combat transaction calls settle_victory
## on its detached, recovered state; this helper is not itself victory proof.
## Finish state is consumed before reward callbacks. If persistence fails, retry
## saving the settled state, never repeat the award or roll back in memory.
const Heting = preload("res://scripts/heting_rules.gd")
const TITLE: String = "鹤汀续事·未损先收"
const INTRODUCED_VERSION: int = 14
const MAX_SAVE_VERSION: int = 15
# Compatibility alias denotes this bundle's introduction, not host schema.
const SAVE_VERSION: int = INTRODUCED_VERSION
const REWARD_XP: int = 120
const REWARD_COINS: int = 60
const FIELDS: Array[String] = ["consignee_stage", "consignee_observations", "consignee_contributions", "consignee_draft", "consignee_cargo_location", "consignee_ending"]
const OBSERVATIONS: Array[String] = ["lot_seals", "removal_order", "southern_counterfoil"]
const CONTRIBUTIONS: Array[String] = ["tang_teach", "tang_preserve", "qin_timing", "shen_shore", "shen_mobile"]
const PLANS: Array[String] = ["hold_for_inspection", "return_to_owner"]
const LOCATIONS: Array[String] = ["", "warehouse", "cart", "public_scale", "grain_boat"]
const BATCH: String = "disputed_lot"
const SOURCE: String = "consignee_warehouse"
const SCALE: String = "heting_scale"
const GRAIN_BOAT: String = "heting_grain_boat"
const CORRECT_ANSWER: String = "order_before_inspection"
const CONTEXT: Array[String] = ["map_id", "heting_stage", "heting_bridge", "heting_delivered", "heting_cargo", "heting_draft", "heting_ending", "receipt_stage", "mist_stage", "mist_ending", "chapter_two_stage", "chapter_two_ending", "companion_unlocked", "shen_care_stage", "shen_care_choice", "tangqi_unlocked", "tangqi_stage", "tangqi_choice", "qin_stage", "qin_unlocked"]


static func can_begin(s) -> bool:
	return _can_mutate(s) and s.consignee_stage == 0


static func begin(s) -> bool:
	if not can_begin(s):
		return false
	s.consignee_stage = 1
	s.consignee_cargo_location = "warehouse"
	return true


## All methods inspect this actual finite lot/order/counterfoil. Optional party
## methods replace the corresponding solo examination, not a mandatory visit.
## No method grants XP, changes HP/Qi, or fabricates consumed materials.
static func available_methods(s, observation: String) -> Array[String]:
	var result: Array[String] = []
	if not _can_mutate(s) or s.consignee_stage != 1 or not OBSERVATIONS.has(observation) \
			or s.consignee_observations.has(observation):
		return result
	result.append("solo")
	var data: Dictionary = progress(s)
	for method: String in CONTRIBUTIONS:
		if _observation_for(method) == observation and _valid_contribution(data, method) \
				and _standing_deployed(s, _actor_for(method)):
			result.append(method)
	return result


static func observe(s, observation: String, method: String = "solo") -> bool:
	if not available_methods(s, observation).has(method):
		return false
	s.consignee_observations.append(observation)
	if method != "solo":
		s.consignee_contributions.append(method)
	return true


## Wrong answers are explanatory, side-effect free, and never discard clues.
static func resolve_contradiction(s, answer: String) -> Dictionary:
	if not _can_mutate(s) or s.consignee_stage != 1:
		return _answer(false, "当前不能核定这批粮的撤运理由。")
	if s.consignee_observations.size() != OBSERVATIONS.size():
		return _answer(false, "先亲查北仓封粮、撤运单和南驳船收货联；旧副签不能代替这批粮的实查。")
	if answer != CORRECT_ANSWER:
		if answer == "dry_means_whole_ship":
			return _answer(false, "只查过这两篓新封粮，不能据此说整船都未受损；疑点是同批撤运单先写水损，后才准人验粮。")
		if answer == "receipt_required":
			return _answer(false, "复称副签可作旁证，但本批封记、撤运时刻与收货联已经能相互核对，不必追补旧副签。")
		return _answer(false, "收货人姓氏或运费高低都不足以定论；请核对同批货号的验粮先后与预结收货授权。")
	s.consignee_stage = 2
	return _answer(true, "同批粮尚未开验，撤运单已按水损收走；南联又写明平川粮栈预结收货。这一批的撤运理由站不住脚。")


static func choose_plan(s, id: String) -> bool:
	if not _can_mutate(s) or s.consignee_stage not in [2, 3, 4] \
			or not PLANS.has(id) or s.consignee_draft == id:
		return false
	s.consignee_draft = id
	return true


static func can_confront(s) -> bool:
	return _can_mutate(s) and s.consignee_stage == 2 and PLANS.has(s.consignee_draft)


## Host checks encounter identity, entry progress, epoch, terminal token, and real
## win before calling. Flee/defeat never call this and never advance this model.
static func settle_victory(s, expected_plan: String) -> bool:
	if not can_confront(s) or not PLANS.has(expected_plan) or s.consignee_draft != expected_plan:
		return false
	s.consignee_stage = 3
	return true


static func available_cargo(s, source: String) -> Array[String]:
	var result: Array[String] = []
	if _can_mutate(s) and s.consignee_stage == 3 and s.consignee_cargo_location == "warehouse" and source == SOURCE:
		result.append(BATCH)
	return result


static func take_cargo(s, id: String, source: String) -> bool:
	if not available_cargo(s, source).has(id):
		return false
	s.consignee_cargo_location = "cart"
	s.consignee_stage = 4
	return true


static func park_cargo(s) -> bool:
	if not _can_mutate(s) or s.consignee_stage != 4 or s.consignee_cargo_location != "cart":
		return false
	# Return the same batch intact; neither copy it nor discard the intervention.
	s.consignee_cargo_location = "warehouse"
	s.consignee_stage = 3
	return true


static func receiver_for(plan: String) -> String:
	return SCALE if plan == "hold_for_inspection" else (GRAIN_BOAT if plan == "return_to_owner" else "")


static func finish_delivery(s, receiver: String, expected_plan: String) -> bool:
	if not _can_mutate(s) or s.consignee_stage != 4 or not PLANS.has(expected_plan) \
			or s.consignee_draft != expected_plan or receiver != receiver_for(expected_plan):
		return false
	s.consignee_cargo_location = "public_scale" if expected_plan == "hold_for_inspection" else "grain_boat"
	s.consignee_ending = expected_plan
	s.consignee_stage = 5
	# Consume before the first callback, including gain_xp growth reconciliation.
	s.coins = mini(999999, s.coins + REWARD_COINS)
	s.gain_xp(REWARD_XP)
	return true


static func plan_description(plan: String) -> String:
	if plan == "hold_for_inspection":
		return "封粮留验：把同一车两篓封粮送到东岸公秤，共同封存待验；完整封样得以保留，这批粮暂不能取用。交接前可改主意。"
	if plan == "return_to_owner":
		return "撤运还粮：把同一车两篓封粮送回中央粮船原主，解除这次扣运；开篓分用后不再保有整批封样，抄件和已核事实仍保留。交接前可改主意。"
	return "尚未拟定这批粮的去向。"


static func method_description(method: String) -> String:
	match method:
		"tang_teach": return "唐栖按教给船工的卸力次序指导复放两篓，与你当场核查封绳和篓内干粮。"
		"tang_preserve": return "唐栖保留旧机记号，亲自比对吊具受力刻线，与你当场核查封绳和篓内干粮。"
		"qin_timing": return "秦禾与你把撤运单的签发时刻并排对照仓门验放刻线，确认撤运理由写在实查之前。"
		"shen_shore": return "沈青依照岸边照看安排，陪你问接粮船工的暂存需求，并核验南联的本批收货授权。"
		"shen_mobile": return "沈青依照随行照看安排，陪你到待返船边问接粮次序，并核验南联的本批收货授权。"
		"solo": return "自行核验现场封记、票据与时刻；不需要同行人、材料或额外本领。"
	return ""


static func hint(s) -> String:
	if s.heting_stage != 4:
		return "先办妥鹤汀交割，再问北仓的新撤运单。"
	match s.consignee_stage:
		0: return "孟绫的调度牌收到一张新撤运单，可去问明北仓那一批粮。"
		1: return "查北仓两篓封粮、调度牌撤运单、南驳船收货联；三处可按任意次序核验。"
		2: return "拟定可更改的处置，再到北仓阻止杜晦按旧单提粮。"
		3: return "这一批已保住，尚未交付。到北仓取车，送往当前草案的接粮处。"
		4: return "一车两篓仍属同一批；交接前可改草案，离港前须确认把车停回北仓。"
		5: return "本批交接已经记定，北仓、接粮处与行纪留下同一结果。"
	return "新撤运记录尚待核实。"


static func journal(s) -> String:
	if s.consignee_stage == 0:
		return hint(s)
	var lines: Array[String] = [TITLE + "：只查北仓新编号的两篓封粮，与昨夜三批交割分开。"]
	if s.consignee_observations.has("lot_seals"):
		lines.append("封绳与篓内实查：本批两篓封记相合，内粮干燥；不能推作整船无损。")
	if s.consignee_observations.has("removal_order"):
		lines.append("撤运单与仓门验放刻线：同批货号尚未开验，单上已按水损发出撤运令。")
	if s.consignee_observations.has("southern_counterfoil"):
		lines.append("南联载明平川粮栈为本批收货方，杜晦以该栈收货管事身份按预结授权提粮。")
	if s.receipt_stage == 3:
		lines.append("旧复称副签另作旁证；旧副签只关乎原先两担，不代替本批两篓实查。")
	lines.append("沿用公开账页的货号与时刻。" if s.chapter_two_ending == "open_records" else "沿用不署证人姓名的货号与时刻抄件，保护证人的安排不变。")
	lines.append("短渡轮值船工提供这批移交时刻，昨夜短渡分粮照旧。" if s.heting_ending == "short_ferries" else "公秤轮值船工提供这批移交时刻，昨夜开秤分粮照旧。")
	for method: String in s.consignee_contributions:
		lines.append(method_description(method))
	if s.consignee_stage >= 3:
		lines.append("已阻止杜晦与看仓人的这次强提；胜负没有代你选择封存或返还。")
	if s.consignee_stage == 5:
		lines.append(aftermath(s, "receiving_point"))
		lines.append("已确认本批的当地受益方是平川粮栈；上游授权由谁发出仍待追查，未据此断言全案告破。")
	else:
		lines.append(plan_description(s.consignee_draft))
	return "\n".join(lines)


static func aftermath(s, place: String) -> String:
	if s.consignee_stage != 5:
		return ""
	if place == "warehouse":
		return "北仓原提货位已空，杜晦的撤运单被划止；这批粮不能再按旧单提走。"
	if place not in ["receiving_point", SCALE, GRAIN_BOAT]:
		return ""
	if s.consignee_ending == "hold_for_inspection":
		return "东岸公秤留着两篓完整封样与共同留验告示；中央粮船持有暂存回条，待验期间不取用本批粮。"
	return "中央粮船已收回两篓粮并留下返还记录；东岸公秤保留抄件，开篓分用后不再有完整封样。"


## Called only after the whole save has validated, on a detached candidate.
## No clamping, fabricated observations, reordered arrays, or load-time rewards.
static func restore(s, data: Dictionary) -> void:
	s.consignee_stage = int(data.get("consignee_stage", 0))
	s.consignee_observations.assign(data.get("consignee_observations", []))
	s.consignee_contributions.assign(data.get("consignee_contributions", []))
	s.consignee_draft = data.get("consignee_draft", "")
	s.consignee_cargo_location = data.get("consignee_cargo_location", "")
	s.consignee_ending = data.get("consignee_ending", "")


static func valid(data: Dictionary, version: int) -> bool:
	if version < 1 or version > MAX_SAVE_VERSION:
		return false
	var present: int = 0
	for key: String in FIELDS:
		present += int(data.has(key))
	if (version >= INTRODUCED_VERSION and present != FIELDS.size()) or (present > 0 and present != FIELDS.size()):
		return false
	var stage = data.get("consignee_stage", 0)
	if not _integer(stage, 0, 5):
		return false
	var observed = data.get("consignee_observations", [])
	var contributions = data.get("consignee_contributions", [])
	if not _unique_ids(observed, OBSERVATIONS) or not _unique_ids(contributions, CONTRIBUTIONS):
		return false
	var draft = data.get("consignee_draft", "")
	var location = data.get("consignee_cargo_location", "")
	var ending = data.get("consignee_ending", "")
	if not draft is String or not location is String or not ending is String:
		return false
	if (not draft.is_empty() and not PLANS.has(draft)) or not LOCATIONS.has(location) \
			or (not ending.is_empty() and not PLANS.has(ending)):
		return false
	if stage == 0:
		return observed.is_empty() and contributions.is_empty() and draft.is_empty() and location.is_empty() and ending.is_empty()
	if not _valid_prior_story(data):
		return false
	var contributed_observations: Array[String] = []
	for method: String in contributions:
		var observation: String = _observation_for(method)
		if not observed.has(observation) or contributed_observations.has(observation) or not _valid_contribution(data, method):
			return false
		contributed_observations.append(observation)
	if stage == 1:
		return draft.is_empty() and location == "warehouse" and ending.is_empty()
	if observed.size() != OBSERVATIONS.size():
		return false
	if stage == 2:
		return location == "warehouse" and ending.is_empty()
	if not PLANS.has(draft):
		return false
	if stage == 3:
		return location == "warehouse" and ending.is_empty()
	if stage == 4:
		return location == "cart" and ending.is_empty() and data.get("map_id", "") == "heting"
	return ending == draft and location == ("public_scale" if ending == "hold_for_inspection" else "grain_boat")


static func progress(s) -> Dictionary:
	var data: Dictionary = {}
	for key: String in FIELDS + CONTEXT:
		var value = s.get(key)
		data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return data


static func _can_mutate(s) -> bool:
	if s == null or s.battle_active or s.hp < 1 or s.map_id != "heting" \
			or s.get("_party_pending_token") != -1:
		return false
	if s.has_method("_party_gate") and s._party_gate():
		return false
	var data: Dictionary = progress(s)
	return _valid_prior_story(data) and valid(data, MAX_SAVE_VERSION)


static func _valid_prior_story(data: Dictionary) -> bool:
	return _integer(data.get("heting_stage"), 4, 4) and Heting.valid(data, 9) \
		and _integer(data.get("receipt_stage"), 0, 3) \
		and _integer(data.get("chapter_two_stage"), 4, 4) \
		and data.get("chapter_two_ending", "") in ["open_records", "protect_witness"]


static func _valid_contribution(data: Dictionary, method: String) -> bool:
	if method in ["tang_teach", "tang_preserve"]:
		return data.get("tangqi_unlocked") is bool and data.get("tangqi_unlocked") \
			and _integer(data.get("tangqi_stage"), 3, 3) \
			and data.get("tangqi_choice", "") == ("teach" if method == "tang_teach" else "preserve")
	if method == "qin_timing":
		return data.get("qin_unlocked") is bool and data.get("qin_unlocked") and _integer(data.get("qin_stage"), 4, 4)
	if method in ["shen_shore", "shen_mobile"]:
		return data.get("companion_unlocked") is bool and data.get("companion_unlocked") \
			and _integer(data.get("shen_care_stage"), 5, 5) \
			and data.get("shen_care_choice", "") == ("shore" if method == "shen_shore" else "mobile")
	return false


static func _standing_deployed(s, actor: String) -> bool:
	if not s.party_roster is Array or not s.party_roster.has(actor) or not s.party_resources is Dictionary:
		return false
	var resources = s.party_resources.get(actor)
	return resources is Dictionary and _integer(resources.get("hp"), 1, 9999)


static func _actor_for(method: String) -> String:
	if method.begins_with("tang_"): return "tang"
	if method.begins_with("shen_"): return "shen"
	return "qin" if method == "qin_timing" else ""


static func _observation_for(method: String) -> String:
	match _actor_for(method):
		"tang": return "lot_seals"
		"qin": return "removal_order"
		"shen": return "southern_counterfoil"
	return ""


static func _unique_ids(value: Variant, ids: Array[String]) -> bool:
	if not value is Array or value.size() > ids.size():
		return false
	var seen: Array[String] = []
	for id in value:
		if not id is String or not ids.has(id) or seen.has(id):
			return false
		seen.append(id)
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _answer(correct: bool, reason: String) -> Dictionary:
	return {"ok": correct, "correct": correct, "reason": reason}
