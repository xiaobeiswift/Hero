class_name ShenCareRules
extends RefCounted
## A finite personal story. Draft plans remain reversible until publicly posted.
const CHOICES: Array[String] = ["shore", "mobile"]

static func can_begin(s) -> bool:
	return not s.battle_active and s.shen_care_stage == 0 and s.companion_unlocked \
		and s.quest_stage >= 6 and s.side_stage >= 3 and s.side_choice in ["rescue", "pursuit"] \
		and s.ending in ["秉公", "守望"]

static func begin(s) -> bool:
	if not can_begin(s):
		return false
	s.shen_care_stage = 1
	return true

static func consult(s) -> bool:
	if s.battle_active or s.shen_care_stage != 1:
		return false
	s.shen_care_stage = 2
	return true

static func inspect(s) -> bool:
	if s.battle_active or s.shen_care_stage != 2:
		return false
	s.shen_care_stage = 3
	return true

static func choose(s, choice: String) -> bool:
	if s.battle_active or s.shen_care_stage not in [3, 4] or not CHOICES.has(choice):
		return false
	if s.shen_care_stage == 4 and s.shen_care_choice == choice:
		return false
	s.shen_care_choice = choice
	s.shen_care_stage = 4
	return true

static func post(s) -> bool:
	if s.battle_active or s.shen_care_stage != 4 or not CHOICES.has(s.shen_care_choice):
		return false
	s.shen_care_stage = 5
	s.gain_xp(40)
	return true

static func shore_bonus(s) -> int:
	return 1 if s.shen_care_stage == 5 and s.shen_care_choice == "shore" else 0

static func mobile_heal(s) -> int:
	return 2 if s.shen_care_stage == 5 and s.shen_care_choice == "mobile" else 0

static func restore(s, data: Dictionary) -> void:
	s.shen_care_stage = int(data.get("shen_care_stage", 0))
	s.shen_care_choice = String(data.get("shen_care_choice", ""))

static func valid(data: Dictionary, version: int) -> bool:
	if version >= 7 and (not data.has("shen_care_stage") or not data.has("shen_care_choice")):
		return false
	if data.has("shen_care_stage") != data.has("shen_care_choice"):
		return false
	var stage = data.get("shen_care_stage", 0)
	var choice = data.get("shen_care_choice", "")
	if not (stage is int or stage is float) or not is_finite(float(stage)):
		return false
	if float(stage) != floor(float(stage)) or stage < 0 or stage > 5 or not choice is String:
		return false
	if stage < 4 and not choice.is_empty():
		return false
	if stage >= 4 and not CHOICES.has(choice):
		return false
	if stage > 0:
		if data.get("companion_unlocked", false) != true:
			return false
		var opening_done = float(data.get("quest_stage", 0)) >= 6 or (float(data.get("quest_stage", 0)) == 5 and data.get("sect", "") in ["听潮阁", "照野堂", "问石门"])
		var sluice_done = float(data.get("side_stage", 0)) >= 3 or data.get("side_reward_claimed", false) == true
		if not opening_done or not sluice_done or data.get("ending", "") not in ["秉公", "守望"]:
			return false
		if data.get("side_choice", "") not in ["rescue", "pursuit"]:
			return false
	return true
