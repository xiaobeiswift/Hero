class_name MartialCatalog
extends RefCounted
## Read-only martial definitions shared by rules, UI, and future content tools.
## Callers receive immutable copies; rank/proficiency belongs to HeroState.
## available_for is the browsable school catalog, not proof of learning.

const BASE_ART: String = "照夜一线"
const _ARTS: Dictionary = {
	"照夜一线": {
		"id": "照夜一线", "name": "照夜一线", "sect": "", "style": "破阵",
		"description": "凝气成线，以一往无前之势照破长夜。",
		"required_sect_rank": 0, "learn_cost": 0,
		"cost": 3, "cooldown": 2, "attack_multiplier": 2, "damage_bonus": 8,
		"healing": 0, "guard": false,
		"weaken_amount": 0, "weaken_strikes": 0,
		"focus_attack_multiplier": 0, "focus_bonus": 0,
	},
	"回潮断浪": {
		"id": "回潮断浪", "name": "回潮断浪", "sect": "听潮阁", "style": "强攻",
		"description": "借回潮之势连斩断浪，以更深的调息换取凌厉一击。",
		"required_sect_rank": 1, "learn_cost": 0,
		"cost": 4, "cooldown": 3, "attack_multiplier": 2, "damage_bonus": 16,
		"healing": 0, "guard": false,
		"weaken_amount": 0, "weaken_strikes": 0,
		"focus_attack_multiplier": 0, "focus_bonus": 0,
	},
	"青灯续脉": {
		"id": "青灯续脉", "name": "青灯续脉", "sect": "照野堂", "style": "疗伤",
		"description": "青灯引气，续接伤脉；回身一掌，攻守相济。",
		"required_sect_rank": 1, "learn_cost": 0,
		"cost": 3, "cooldown": 3, "attack_multiplier": 1, "damage_bonus": 0,
		"healing": 30, "guard": false,
		"weaken_amount": 0, "weaken_strikes": 0,
		"focus_attack_multiplier": 0, "focus_bonus": 0,
	},
	"磐石回锋": {
		"id": "磐石回锋", "name": "磐石回锋", "sect": "问石门", "style": "守势",
		"description": "稳如磐石，回锋御敌；出手后守中卸力，收拢破绽。",
		"required_sect_rank": 1, "learn_cost": 0,
		"cost": 3, "cooldown": 2, "attack_multiplier": 1, "damage_bonus": 10,
		"healing": 0, "guard": true,
		"weaken_amount": 0, "weaken_strikes": 0,
		"focus_attack_multiplier": 0, "focus_bonus": 0,
	},
	"束潮削势": {
		"id": "束潮削势",
		"name": "束潮削势",
		"sect": "听潮阁",
		"style": "拆势",
		"description": "回刃束住来势，以短促潮声拆散对手的劲路。",
		"required_sect_rank": 2,
		"learn_cost": 2,
		"cost": 3,
		"cooldown": 2,
		"attack_multiplier": 1,
		"damage_bonus": 8,
		"healing": 0,
		"guard": false,
		"weaken_amount": 5,
		"weaken_strikes": 2,
		"focus_attack_multiplier": 0,
		"focus_bonus": 0
	},
	"伏汐藏锋": {
		"id": "伏汐藏锋",
		"name": "伏汐藏锋",
		"sect": "听潮阁",
		"style": "蓄锋",
		"description": "将长锋藏进退潮的空隙，待下一次平击引汐而出。",
		"required_sect_rank": 2,
		"learn_cost": 3,
		"cost": 4,
		"cooldown": 3,
		"attack_multiplier": 1,
		"damage_bonus": 6,
		"healing": 0,
		"guard": false,
		"weaken_amount": 0,
		"weaken_strikes": 0,
		"focus_attack_multiplier": 1,
		"focus_bonus": 18
	},
	"青灯息争": {
		"id": "青灯息争",
		"name": "青灯息争",
		"sect": "照野堂",
		"style": "护生",
		"description": "一掌缓住争势，一息照拂伤处，使来刃难以尽力。",
		"required_sect_rank": 2,
		"learn_cost": 2,
		"cost": 3,
		"cooldown": 3,
		"attack_multiplier": 1,
		"damage_bonus": 0,
		"healing": 18,
		"guard": false,
		"weaken_amount": 6,
		"weaken_strikes": 2,
		"focus_attack_multiplier": 0,
		"focus_bonus": 0
	},
	"续灯引锋": {
		"id": "续灯引锋",
		"name": "续灯引锋",
		"sect": "照野堂",
		"style": "续战",
		"description": "以短息续灯，把余劲留在掌锋，待下一招收束争斗。",
		"required_sect_rank": 2,
		"learn_cost": 3,
		"cost": 4,
		"cooldown": 3,
		"attack_multiplier": 1,
		"damage_bonus": 0,
		"healing": 14,
		"guard": false,
		"weaken_amount": 0,
		"weaken_strikes": 0,
		"focus_attack_multiplier": 1,
		"focus_bonus": 6
	},
	"石隙封腕": {
		"id": "石隙封腕",
		"name": "石隙封腕",
		"sect": "问石门",
		"style": "封劲",
		"description": "循石隙点向发力之处，以轻触封住两段劲路。",
		"required_sect_rank": 2,
		"learn_cost": 2,
		"cost": 3,
		"cooldown": 2,
		"attack_multiplier": 1,
		"damage_bonus": 4,
		"healing": 0,
		"guard": false,
		"weaken_amount": 8,
		"weaken_strikes": 2,
		"focus_attack_multiplier": 0,
		"focus_bonus": 0
	},
	"藏锋立岳": {
		"id": "藏锋立岳",
		"name": "藏锋立岳",
		"sect": "问石门",
		"style": "守中蓄锋",
		"description": "立身承势，藏锋于静；护住这一击，再向空隙递出余力。",
		"required_sect_rank": 2,
		"learn_cost": 3,
		"cost": 4,
		"cooldown": 3,
		"attack_multiplier": 1,
		"damage_bonus": 0,
		"healing": 0,
		"guard": true,
		"weaken_amount": 0,
		"weaken_strikes": 0,
		"focus_attack_multiplier": 1,
		"focus_bonus": 10
	},
}


static func has_art(id: String) -> bool:
	return _ARTS.has(id)


static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _ARTS:
		result.append(id)
	return result


static func definition(id: String) -> Dictionary:
	var result: Dictionary = _ARTS.get(id, {}).duplicate(true)
	result.make_read_only()
	return result


static func available_for(sect: String) -> Array[String]:
	var result: Array[String] = [BASE_ART]
	for id: String in _ARTS:
		if id != BASE_ART and String(_ARTS[id]["sect"]) == sect:
			result.append(id)
	return result


static func rank_name(rank: int) -> String:
	match rank:
		1: return "初窥"
		2: return "熟习"
		3: return "通明"
		_: return "未习"
