class_name CombatSkillCatalog
extends RefCounted
## Three manual skill slots only. Automatic basic attacks and shared utilities
## belong to the scheduler, never to this catalog. Inputs are detached actors;
## learning and recruitment must be validated before constructing those inputs.
const Arts = preload("res://scripts/martial_catalog.gd")
const CATEGORIES: Array[String] = ["martial", "internal", "lightness"]
const ACTOR_IDS: Array[String] = ["hero", "shen", "tang", "qin"]
const HERO_INTERNAL: String = "internal:hero_tiaoxi"
const HERO_LIGHTNESS: String = "lightness:hero_tawei"
const INTERNAL_LESSON_REQUIREMENT: String = "3级且已获门派荐帖后，在练武堂南庭向岑远另行修习调息归元；不收费。"
const LIGHTNESS_LESSON_REQUIREMENT: String = "3级且已获门派荐帖后，向岑远修习踏苇行；同一套落脚法可用于渡水与战斗卸力。"

const _INTERNAL: Dictionary = {
	"hero": {"id": HERO_INTERNAL, "name": "调息归元", "healing": 16,
		"description": "收息归元，为自己恢复16气血，不超过上限；不回复真气、不攻击，也不能救起倒下的角色。",
		"learning_source": INTERNAL_LESSON_REQUIREMENT},
	"shen": {"id": "internal:shen_yangmai", "name": "温灯养脉", "healing": 20,
		"description": "以行医时练成的温息养护自身，恢复20气血，不超过上限；不回复真气、不攻击，也不能救起倒下的角色。",
		"learning_source": "沈青行医时已练成温灯养脉；明确邀她同行后，才能指挥她使用。"},
	"tang": {"id": "internal:tang_dingxi", "name": "定尺息", "healing": 12, "focus_bonus": 6,
		"description": "调匀持尺之息，为自己恢复12气血，并使下一次自动平击额外造成6点基础伤害；蓄力取较高值，不叠加，不回复真气。",
		"learning_source": "唐栖在整理旧尺谱时练成定尺息；完成尺谱交接并明确邀她同行后可用。"},
	"qin": {"id": "internal:qin_guiyuan", "name": "归渡长息", "healing": 18,
		"description": "以撑篙时练成的长息稳住伤处，为自己恢复18气血，不超过上限；不回复真气、不攻击，也不能救起倒下的角色。",
		"learning_source": "秦禾在守渡撑篙时练成归渡长息；完成营地交接并明确邀她同行后可用。"},
}

const _LIGHTNESS: Dictionary = {
	"hero": {"id": HERO_LIGHTNESS, "name": "踏苇行", "next_hit_reduction": 10,
		"description": "借步卸去来势：本轮下一次实际受击在防御、守势后再减少10点伤害，可减至0；护障随后结算。只抵一次，不叠加，轮末失效；不会触发守势考法。",
		"learning_source": LIGHTNESS_LESSON_REQUIREMENT},
	"shen": {"id": "lightness:shen_liuying", "name": "流萤步", "next_hit_reduction": 8,
		"description": "错步收身：本轮下一次实际受击在防御、守势后再减少8点伤害，可减至0；护障随后结算。只抵一次，不叠加，轮末失效；不是概率闪避。",
		"learning_source": "沈青采药行路时已练成流萤步；明确邀她同行后，才能指挥她使用。"},
	"tang": {"id": "lightness:tang_cunbu", "name": "寸步移锋", "next_hit_reduction": 6, "focus_bonus": 8,
		"description": "移步寻隙：本轮下一次实际受击在防御、守势后减少6点伤害，可减至0，护障随后结算；只抵一次且轮末失效。下一次自动平击额外造成8点基础伤害；蓄力取较高值，不叠加。",
		"learning_source": "唐栖随尺法练成寸步移锋；完成尺谱交接并明确邀她同行后可用。"},
	"qin": {"id": "lightness:qin_yanliu", "name": "沿流换位", "next_hit_reduction": 12,
		"description": "沿流势换脚卸劲：本轮下一次实际受击在防御、守势后再减少12点伤害，可减至0；护障随后结算。只抵一次，不叠加，轮末失效；不是概率闪避。",
		"learning_source": "秦禾在湿滑船板上练成沿流换位；完成营地交接并明确邀她同行后可用。"},
}


static func manual_actions(actor: Dictionary) -> Array:
	var result: Array = []
	var id: String = String(actor.get("id", ""))
	var known: bool = ACTOR_IDS.has(id)
	var recruited: bool = id == "hero" or _flag(actor, "recruited")
	var martial: Dictionary = _martial(actor) if known and recruited else {}
	result.append(martial if not martial.is_empty() else _unlearned("martial", "尚未习得并装备可用的主动武学。" if id == "hero" else "须先明确招募这位同行人。"))
	for category: String in ["internal", "lightness"]:
		var learned: bool = known and recruited and (id != "hero" or _flag(actor, category + "_unlocked"))
		if learned:
			result.append(_trained_skill(id, category))
		else:
			var reason: String = INTERNAL_LESSON_REQUIREMENT if category == "internal" else LIGHTNESS_LESSON_REQUIREMENT
			if id != "hero":
				reason = "须先明确招募这位同行人；未招募角色不会获得作战技艺。"
			result.append(_unlearned(category, reason))
	_freeze(result)
	return result


static func _martial(actor: Dictionary) -> Dictionary:
	match String(actor.get("id", "")):
		"hero":
			var art_id: String = String(actor.get("equipped_art", ""))
			if not Arts.has_art(art_id):
				return {}
			var art: Dictionary = Arts.definition(art_id)
			return _action("art:" + art_id, "martial", art.name, "enemy", int(art.cost), int(art.cooldown), art.description, art, "已习得并装备的主动武学；招式所有权由角色建队时校验。")
		"shen":
			var healing: int = 28 + clampi(int(actor.get("care_healing_bonus", 0)), 0, 2)
			return _action("art:shen_xumai", "martial", "青灯渡脉", "ally", 3, 2,
				"为一名仍站立的队友恢复%d气血；不能救起倒下的角色。" % healing,
				{"healing": healing}, "沈青已掌握的行医针法；明确招募后可用。")
		"tang":
			return _action("art:tang_fenjin", "martial", "分劲尺", "enemy", 3, 2,
				"短尺击敌并卸劲：目标基础伤害减5，持续其两次攻击。",
				{"attack_multiplier": 1, "damage_bonus": 2, "weaken_amount": 5, "weaken_strikes": 2}, "唐栖已掌握的尺法；完成尺谱交接并明确招募后可用。")
		"qin":
			return _action("art:qin_shoudu", "martial", "守渡横杖", "ally", 3, 2,
				"为一名仍站立的队友施加18点护障，不叠加；抵消其下一次来袭经防御、守势结算后的伤害，可减至0。该次受击后余量消散，未受击则本轮结束消散；不治疗、不救起倒下者。",
				{"barrier": 18}, "秦禾已掌握的守渡杖法；完成营地交接并明确招募后可用。")
	return {}


static func _trained_skill(actor_id: String, category: String) -> Dictionary:
	var spec: Dictionary = _INTERNAL[actor_id] if category == "internal" else _LIGHTNESS[actor_id]
	var effects: Dictionary = {}
	for key: String in ["healing", "next_hit_reduction", "focus_bonus"]:
		if spec.has(key):
			effects[key] = int(spec[key])
	var cooldown: int = 3 if category == "internal" else 2
	return _action(spec.id, category, spec.name, "self", 2, cooldown, spec.description, effects, spec.learning_source)


static func _unlearned(category: String, reason: String) -> Dictionary:
	var title: String = {"martial": "主动武学", "internal": "内功", "lightness": "轻功"}[category]
	var result: Dictionary = _action("unlearned:" + category, category, title + " · 未习", "none", 0, 0, reason, {}, reason)
	result.learned = false
	result.reason = reason
	return result


static func _action(id: String, category: String, title: String, target_team: String, cost: int, cooldown: int, description: String, effects: Dictionary, learning_source: String) -> Dictionary:
	return {"id": id, "category": category, "name": title, "target_team": target_team,
		"cost": cost, "cooldown": cooldown, "description": description,
		"effects": effects.duplicate(true), "learned": true, "reason": "", "learning_source": learning_source}


static func _flag(actor: Dictionary, key: String) -> bool:
	var value: Variant = actor.get(key, false)
	return value is bool and value


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item: Variant in value:
			_freeze(item)
		value.make_read_only()
