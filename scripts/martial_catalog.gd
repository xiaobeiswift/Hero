class_name MartialCatalog
extends RefCounted
## Read-only martial definitions shared by rules, UI, and future content tools.
## Callers receive immutable copies; rank/proficiency belongs to HeroState.

const BASE_ART: String = "照夜一线"
const _ARTS: Dictionary = {
	"照夜一线": {
		"id": "照夜一线", "name": "照夜一线", "sect": "", "style": "破阵",
		"description": "凝气成线，以一往无前之势照破长夜。",
		"cost": 3, "cooldown": 2, "attack_multiplier": 2, "damage_bonus": 8,
		"healing": 0, "guard": false,
	},
	"回潮断浪": {
		"id": "回潮断浪", "name": "回潮断浪", "sect": "听潮阁", "style": "强攻",
		"description": "借回潮之势连斩断浪，以更深的调息换取凌厉一击。",
		"cost": 4, "cooldown": 3, "attack_multiplier": 2, "damage_bonus": 16,
		"healing": 0, "guard": false,
	},
	"青灯续脉": {
		"id": "青灯续脉", "name": "青灯续脉", "sect": "照野堂", "style": "疗伤",
		"description": "青灯引气，续接伤脉；回身一掌，攻守相济。",
		"cost": 3, "cooldown": 3, "attack_multiplier": 1, "damage_bonus": 0,
		"healing": 30, "guard": false,
	},
	"磐石回锋": {
		"id": "磐石回锋", "name": "磐石回锋", "sect": "问石门", "style": "守势",
		"description": "稳如磐石，回锋御敌；出手后守中卸力，收拢破绽。",
		"cost": 3, "cooldown": 2, "attack_multiplier": 1, "damage_bonus": 10,
		"healing": 0, "guard": true,
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
