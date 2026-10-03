class_name VolumeOneCapstoneRules
extends RefCounted
## Phase-one detached model only. No scene, disk IO, art, travel or combat proof.
## Rules check map/stage/battle eligibility; state wrappers additionally validate
## the whole canonical candidate and exact delta. Scene callbacks MUST establish
## the live site, proximity, modal generation and expected selection. A string or
## a map match is never evidence that real physical input occurred at that site.
## settle_victory is only a model step for the verified terminal transaction, not
## a public state victory shortcut. Completed evidence never depends on whether
## a helper is still selected/standing. No historical helper credit is stored.
const Consignee = preload("res://scripts/heting_consignee_rules.gd")
const TITLE: String = "第一卷终章·截令归灯"
const INTRODUCED_VERSION: int = 15
const MAX_SUPPORTED_VERSION: int = 16
const REWARD_XP: int = 160
const REWARD_COINS: int = 80
const FIELDS: Array[String] = ["capstone_stage", "capstone_draft", "capstone_ending"]
const PLANS: Array[String] = ["pause_batch", "cancel_proven"]
const BATCH: String = "capstone_pending_batch_01"
const ORDER_IDS: Array[String] = ["capstone_pending_001", "capstone_pending_002", "capstone_pending_003", "capstone_pending_004"]
const CORRECT_PARTITION: Dictionary = {
	"capstone_pending_001": "proven_false", "capstone_pending_002": "proven_false",
	"capstone_pending_003": "unverified", "capstone_pending_004": "unverified",
}
const CORRECT_ANSWER: String = "authorized_issued_chain"
const METHODS: Array[String] = ["tang_teach", "tang_preserve", "qin_timing", "shen_shore", "shen_mobile"]
const CONTEXT: Array[String] = [
	"map_id", "quest_stage", "ending", "side_stage", "side_choice", "side_clues", "side_found", "side_reward_claimed",
	"chapter_two_stage", "chapter_two_ending", "archive_clues", "seal_sequence", "bridge_repaired",
	"mist_stage", "mist_gauges", "mist_approach", "mist_ending", "heting_stage", "heting_bridge", "heting_delivered", "heting_cargo", "heting_draft", "heting_ending", "receipt_stage",
	"consignee_stage", "consignee_observations", "consignee_contributions", "consignee_draft", "consignee_cargo_location", "consignee_ending",
	"companion_unlocked", "shen_care_stage", "shen_care_choice", "tangqi_unlocked", "tangqi_stage", "tangqi_choice", "qin_stage", "qin_unlocked", "party_roster", "party_resources",
]


static func can_begin(s) -> bool:
	return _can_mutate(s) and s.map_id == "heting" and s.capstone_stage == 0


static func begin(s) -> bool:
	if not can_begin(s): return false
	s.capstone_stage = 1
	return true


## Wen takes the original from his keeping, compares his retained draft, admits
## authorship and returns the original. No forgiveness or witness disclosure.
static func reveal_letter(s) -> bool:
	if not _can_mutate(s) or s.map_id != "frostbridge" or s.capstone_stage != 1: return false
	s.capstone_stage = 2
	return true


static func available_methods(s, action: String) -> Array[String]:
	var result: Array[String] = []
	if not _can_mutate(s): return result
	if action == "evidence":
		if s.capstone_stage != 2 or s.map_id != "frostbridge": return result
	elif action == "classification":
		if s.capstone_stage != 4 or not _planning_map(s): return result
	else:
		return result
	result.append("solo")
	var data: Dictionary = progress(s)
	for method: String in METHODS:
		# Craft/timing assist issued-record comparison; care history assists the
		# pending classification's consequences. Neither substitutes testimony.
		if (action == "classification") != method.begins_with("shen_"): continue
		if _valid_method_history(data, method) and _standing_deployed(s, _actor_for(method)):
			result.append(method)
	return result


static func resolve_evidence(s, answer: String, method: String = "solo") -> Dictionary:
	if not available_methods(s, "evidence").has(method):
		return _answer(false, "请在霜桥文书房核对已发签令留底册；同行方法须有相应经历、实际出战且仍站立。")
	if answer != CORRECT_ANSWER:
		match answer:
			"watermark_proves_author": return _answer(false, "共用水纹不是私人印记，不能据此把所有令归到同一人名下。")
			"dry_means_whole_ship": return _answer(false, "旧两篓实查不能证明所有粮船无损；要核对具体授权号、时刻和核准动作。")
			"victory_proves_guilt": return _answer(false, "责任由已发留底、独立抄件与实查反证核定，胜负不作证；未发令簿此时尚未取得。")
		return _answer(false, "留底册与分存抄件须逐号对上梁缜的核准、改时与交发动作，不能只凭水纹或职衔定责。")
	s.capstone_stage = 3
	return _answer(true, "纪小砚调出的已发签令留底册与独立抄件相合：梁缜·签令主事须对这一组核准与交发负责。结论限于已核编号链，不由未发令簿或交锋胜负作证。")


static func can_confront(s) -> bool:
	return _can_mutate(s) and s.map_id == "frostbridge" and s.capstone_stage == 3


## Only the state's real accepted terminal snapshot/entry/epoch/token validator
## may invoke this on its detached recovered candidate. This proves no victory.
static func settle_victory(s) -> bool:
	if not can_confront(s): return false
	s.capstone_stage = 4
	return true


static func classify_orders(s, partition: Variant, method: String = "solo") -> Dictionary:
	if not available_methods(s, "classification").has(method):
		return _answer(false, "取得本班未发令簿后，在霜桥印台或旧闸守闸桌核对四号；当前不能分类。")
	if not valid_partition(partition):
		return _answer(false, "请完整核对同一批四号：001引用已证伪的同一雨尺读数，002引用已被推翻的验放先后；003、004尚未核清，不能当作假令或认定无误。")
	s.capstone_stage = 5
	return _answer(true, "四号已明确分类：001、002依据已证伪，003、004尚未核清。四号仍全部待处置；尚未替你拟稿或交发。")


static func valid_partition(partition: Variant) -> bool:
	if not partition is Dictionary or partition.size() != ORDER_IDS.size(): return false
	for id: Variant in partition:
		if not id is String or not ORDER_IDS.has(id) or not partition[id] is String \
				or partition[id] != CORRECT_PARTITION[id]: return false
	return true


## Empty explicitly clears the draft. Same draft is a no-op, not a save-worthy
## mutation. The scene invalidates A→B→A stale callbacks by modal generation.
static func choose_plan(s, plan: String) -> bool:
	if not _can_mutate(s) or not _planning_map(s) or s.capstone_stage != 5 \
			or (not plan.is_empty() and not PLANS.has(plan)) or s.capstone_draft == plan: return false
	s.capstone_draft = plan
	return true


static func confirm_disposition(s, expected_plan: String) -> bool:
	if not _can_mutate(s) or s.map_id != "sluice" or s.capstone_stage != 5 \
			or not PLANS.has(expected_plan) or s.capstone_draft != expected_plan: return false
	s.capstone_ending = expected_plan
	s.capstone_stage = 6
	return true


static func finish_homecoming(s) -> bool:
	if not _can_mutate(s) or s.map_id != "qingwei" or s.capstone_stage != 6: return false
	# Consume the once-only boundary BEFORE growth/reentrant callbacks. A later
	# save failure retries serialization, not this action. Normal gain_xp may
	# level and refill the hero; existing companion growth semantics stay intact.
	s.capstone_stage = 7
	s.coins = mini(999999, s.coins + REWARD_COINS)
	s.gain_xp(REWARD_XP)
	return true


static func plan_description(plan: String) -> String:
	if plan == "pause_batch":
		return "整班暂缓：撤销001、002；尚未核清的003、004留所复核、暂不交发，未证错事项也多等一轮。只限本班四号，不改旧粮、旧令或轮值。"
	if plan == "cancel_proven":
		return "逐号撤销：撤销001、002；尚未核清的003、004循既有核验、签收程序继续交发，不等于自动放行或认定无误。只限本班四号，不改旧粮、旧令或轮值。"
	return "尚未拟稿；本班四号全部待处置，没有倒计时。"


static func method_description(method: String) -> String:
	match method:
		"solo": return "自己逐项核对，不需同伴、材料或额外本领。"
		"tang_teach": return "唐栖沿工册传抄时逐项复核的做法，与你并读已发册和分存抄件；不凭手艺辨认笔迹。"
		"tang_preserve": return "唐栖沿用保留原页的做法，另纸标注改处，与你核对已发册和分存抄件。"
		"qin_timing": return "秦禾依轮值核时经历，与你并看原读数、核收与签发时刻；旧职衔本身不作定责凭据。"
		"shen_shore": return "沈青依留岸照护安排，与你列明未核事项留所等候和循例交发的差别，不添病人姓名或伤情。"
		"shen_mobile": return "沈青依随船照护安排，与你列明未核事项往返交接的差别，不凭医术鉴定公文。"
	return ""


## The single shared destination for future HUD/map/world/journal consumers.
## It is independent of current map and helper availability; no automatic travel.
static func goal(s) -> Dictionary:
	if s == null: return {}
	var data: Dictionary = progress(s)
	if not valid(data, MAX_SUPPORTED_VERSION) or not _valid_prior_story(data): return {}
	match s.capstone_stage:
		0: return {"map_id": "heting", "site_id": "heting_dispatch", "objective": "向孟绫领取上游签令查册引介。"}
		1: return {"map_id": "frostbridge", "site_id": "chapter_host", "objective": "请温行舟取出原信，与留稿核明作者和来意并归还原信。"}
		2: return {"map_id": "frostbridge", "site_id": "chapter_clerk", "objective": "在纪小砚处核对已发签令留底册，逐号核定核准与交发责任。"}
		3: return {"map_id": "frostbridge", "site_id": "chapter_archive", "objective": "到印台保住本班未发令簿；已核责任不以交锋胜负作证。"}
		4: return {"map_id": "sluice", "site_id": "capstone_order_desk", "objective": "到守闸桌逐号分类新簿四令；印台也可先行核对。"}
		5: return {"map_id": "sluice", "site_id": "capstone_order_desk", "objective": "为已分类四号拟稿，并在守闸桌明确确认处置。"}
		6: return {"map_id": "qingwei", "site_id": "elder", "objective": "回青苇渡向陆伯报告四号处置，确认归灯后结算同额回报。"}
	return {}


## Fresh row objects, never a mutable view of the catalog or persistent state.
## Before stage4 the player owns no pending book; stage4 exposes no completed
## classification. A draft changes no execution status at all.
static func order_rows(s) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if s == null or not valid(progress(s), MAX_SUPPORTED_VERSION) or s.capstone_stage < 4: return result
	for index: int in ORDER_IDS.size():
		var id: String = ORDER_IDS[index]
		var evidence: String = "not_yet_classified" if s.capstone_stage == 4 else CORRECT_PARTITION[id]
		var disposition: String = "pending"
		if s.capstone_stage >= 6:
			disposition = "cancelled" if index < 2 else ("held" if s.capstone_ending == "pause_batch" else "continuing")
		var basis: String = "尚待逐号核对；同在一本簿中不代表同真同假。"
		if s.capstone_stage >= 5:
			if index == 0: basis = "引用同一雨次、同一尺位的失实读数，已被此前实查反证推翻；不是由旧粮干燥推断新货无损。"
			elif index == 1: basis = "引用已被对照记录推翻的验放先后，拟据此交发新的按损收货授权；不是过去已经执行的旧令。"
			else: basis = "独立编号事项，本次查据不足；循例仍须核验与签收，不等于无误或自动放行。"
		result.append({"batch_id": BATCH, "id": id, "number": "新待发令·%03d" % (index + 1), "evidence": evidence, "disposition": disposition, "basis": basis})
	return result


static func journal(s) -> String:
	var target: Dictionary = goal(s)
	if s.capstone_stage == 0: return target.get("objective", "先完成既有交割与未损先收的实际交接。")
	var lines: Array[String] = [TITLE + "：旧信、已发留底和本班未发簿分别核记。"]
	if s.capstone_stage >= 2:
		lines.append("温行舟从原有保管处取出旧信，与留稿对照后承认作者并交还原信。信边水纹是可疑旧令的拓样，不是他的私印；当时只知疑点，并不知道后来鹤汀这批粮。隐去带信人不免除其先前未说明的责任，接受查证不等于代你原谅。")
	if s.capstone_stage >= 3:
		lines.append("纪小砚调取的已发签令留底册，将具体授权号、改时、雨录列损和预结交发与独立抄件相校，核定梁缜·签令主事对这一组核准与交发的责任；不推作全水司、全部旧案或未证实的雇刀责任。")
		lines.append("沿用原已公开账页逐号归档，不宣称先前公开已撤回。" if s.chapter_two_ending == "open_records" else "只用货号、时刻和脱敏抄件互校，继续封存证人及带信往来身份。")
		lines.append("鹤汀完整封样仍在当地共同留验，没有移到霜桥。" if s.consignee_ending == "hold_for_inspection" else "鹤汀两篓已返还，使用当时实查、划止及返还记录，不复原封样或重新扣粮。")
		if s.receipt_stage == 3: lines.append("已并看的旧复称副签仅作原先两担的旁证，不替代两篓实查或四号新令核对。")
		lines.append("移交时刻取自短渡轮值记录，此前分粮安排不改。" if s.heting_ending == "short_ferries" else "移交时刻取自公秤轮值记录，此前分粮安排不改。")
	if s.capstone_stage >= 4:
		lines.append("交锋后取得另一件本班未发令簿，只有四号新待发令；此前已发册定责不依赖这本战后取得的簿。胜利未发终章奖励，也未自动分类或处置。")
	if s.capstone_stage >= 5:
		lines.append("四号已完成独立核对：001复用已证伪的同一雨尺记录，002复用已被推翻的验放先后；003、004尚未核清，不判无误。")
	if s.capstone_stage in [4, 5]:
		lines.append(("当前只是草案，四号仍全部待处置：" if not s.capstone_draft.is_empty() else "") + plan_description(s.capstone_draft))
		lines.append("最终处置只在旧闸守闸桌明确确认；离开、休整或等待不使四号自动交发。")
	if s.capstone_stage >= 6:
		lines.append("文书房与守闸轮值已逐号登记：" + plan_description(s.capstone_ending))
	if s.capstone_stage == 6:
		lines.append("尚未向陆伯确认归灯，终章160阅历、80铜钱尚未结算；两案同额。")
	elif s.capstone_stage == 7:
		lines.append("已回青苇渡向陆伯确认归灯，第一卷回报仅结算一次（160阅历、80铜钱，受既有上限约束）；阅历若触发升阶，沿用原有主角恢复规则。未办完的副签、同行机缘与研艺仍可继续。")
		lines.append("回条与当初县衙收账回执一并留档。" if s.ending == "秉公" else "船家仍按原办法分存编号与时刻抄件，不写带信人。")
	if not target.is_empty(): lines.append(target.objective)
	return "\n".join(lines)


## Called only after whole-save validation on a detached candidate. Legacy
## absence gets precisely neutral values; present values are never normalized.
static func restore(s, data: Dictionary) -> void:
	s.capstone_stage = int(data.get("capstone_stage", 0))
	s.capstone_draft = data.get("capstone_draft", "")
	s.capstone_ending = data.get("capstone_ending", "")


static func valid(data: Dictionary, version: int) -> bool:
	if version < 1 or version > MAX_SUPPORTED_VERSION: return false
	for key: Variant in data:
		if key is String and key.begins_with("capstone_") and not FIELDS.has(key): return false
	var present: int = 0
	for key: String in FIELDS: present += int(data.has(key))
	if (version >= INTRODUCED_VERSION and present != FIELDS.size()) or (present > 0 and present != FIELDS.size()): return false
	var stage: Variant = data.get("capstone_stage", 0)
	var draft: Variant = data.get("capstone_draft", "")
	var ending: Variant = data.get("capstone_ending", "")
	if not _integer(stage, 0, 7) or not draft is String or not ending is String: return false
	if (not draft.is_empty() and not PLANS.has(draft)) or (not ending.is_empty() and not PLANS.has(ending)): return false
	if stage == 0: return draft.is_empty() and ending.is_empty()
	if not _valid_prior_story(data): return false
	if stage <= 4: return draft.is_empty() and ending.is_empty()
	if stage == 5: return ending.is_empty()
	return PLANS.has(draft) and draft == ending


static func progress(s) -> Dictionary:
	var data: Dictionary = {}
	for key: String in FIELDS + CONTEXT:
		var value: Variant = s.get(key)
		data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return data


static func _can_mutate(s) -> bool:
	if s == null or s.battle_active or s.hp < 1 or s.get("_party_pending_token") != -1: return false
	if s.has_method("_party_gate") and s._party_gate(): return false
	var data: Dictionary = progress(s)
	return _valid_prior_story(data) and valid(data, MAX_SUPPORTED_VERSION)


static func _planning_map(s) -> bool:
	return s.map_id in ["frostbridge", "sluice"]


static func _valid_prior_story(data: Dictionary) -> bool:
	# Explicit earned-chain consistency; never normalize missing old progress.
	# Neutral stage0 does not call this, so every valid old unfinished save loads.
	return _integer(data.get("quest_stage"), 6, 6) and data.get("ending") in ["秉公", "守望"] \
		and _integer(data.get("side_stage"), 3, 3) and data.get("side_choice") in ["rescue", "pursuit"] \
		and data.get("side_reward_claimed") is bool and data.get("side_reward_claimed") \
		and _integer(data.get("side_clues"), 2, 2) and _exact_ids(data.get("side_found"), ["boatman", "ledger"]) \
		and _integer(data.get("chapter_two_stage"), 4, 4) and data.get("chapter_two_ending") in ["open_records", "protect_witness"] \
		and _exact_ids(data.get("archive_clues"), ["clerk", "inscription"]) and _seal_sequence(data.get("seal_sequence")) \
		and _integer(data.get("mist_stage"), 4, 4) and _exact_ids(data.get("mist_gauges"), ["rain", "stone", "basin"]) \
		and data.get("mist_approach") in ["duel", "repair", "records"] \
		and (data.get("mist_approach") != "records" or data.get("chapter_two_ending") == "open_records") \
		and _integer(data.get("consignee_stage"), 5, 5) and Consignee.valid(data, 14)


static func _valid_method_history(data: Dictionary, method: String) -> bool:
	return Consignee._valid_contribution(data, method)


static func _standing_deployed(s, actor: String) -> bool:
	return Consignee._standing_deployed(s, actor)


static func _actor_for(method: String) -> String:
	return Consignee._actor_for(method)


static func _seal_sequence(value: Variant) -> bool:
	return value is Array and value.size() == 3 and _integer(value[0], 2, 2) \
		and _integer(value[1], 0, 0) and _integer(value[2], 1, 1)


static func _exact_ids(value: Variant, ids: Array) -> bool:
	if not value is Array or value.size() != ids.size(): return false
	var seen: Array = []
	for id: Variant in value:
		if not id is String or not ids.has(id) or seen.has(id): return false
		seen.append(id)
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _answer(correct: bool, reason: String) -> Dictionary:
	return {"ok": correct, "correct": correct, "reason": reason}
