class_name ItemCatalog
extends RefCounted
## Economic content. Prices and recipes have one shared authoritative source.
const MATERIALS = {
	"iron": {"name":"铁矿", "buy":8},
	"timber": {"name":"木料", "buy":5},
	"cloth": {"name":"布匹", "buy":6},
	"herb": {"name":"药草", "buy":4},
}
const RECIPES = {
	"refined_blade": {"name":"精锻青钢剑", "needs":{"iron":3,"timber":1}, "coins":25, "level":3, "description":"以青钢剑重锻，攻击额外 +5；仅可锻造一次"},
	"padded_armor": {"name":"轻纱内甲", "needs":{"cloth":3,"herb":1}, "coins":18, "level":1, "description":"防御 +3，气血上限 +10；仅可制作一次"},
	"medicine": {"name":"回春散", "needs":{"herb":2}, "coins":4, "level":1, "description":"制成一包回春散，可重复制作"},
}
const GATHER_NODES = {
	"frost_ore":{"material":"iron","count":3},
	"frost_timber":{"material":"timber","count":3},
	"frost_herb":{"material":"herb","count":3},
}

static func material_ids() -> Array:
	return MATERIALS.keys()

static func material_name(id: String) -> String:
	return String(MATERIALS.get(id,{}).get("name",id))

static func buy_price(id: String) -> int:
	return int(MATERIALS.get(id,{}).get("buy",0))

static func sell_price(id: String) -> int:
	return buy_price(id)/2

static func recipe(id: String) -> Dictionary:
	var result: Dictionary = RECIPES.get(id,{}).duplicate(true)
	if result.has("needs"): result["needs"].make_read_only()
	result.make_read_only()
	return result

static func recipe_ids() -> Array:
	return RECIPES.keys()

static func recipe_description(id: String) -> String:
	var data = recipe(id)
	if data.is_empty(): return ""
	var parts: Array[String] = []
	for material in data["needs"]:
		parts.append("%s ×%d" % [material_name(material),data["needs"][material]])
	return "%s\n材料：%s；%d文；%d级" % [data["description"],"、".join(parts),data["coins"],data["level"]]
