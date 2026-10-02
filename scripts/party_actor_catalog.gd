class_name PartyActorCatalog
extends RefCounted
## Detached inputs for the first actor-based battle model. No HeroState reference
## escapes build_team. Companion tuning is provisional; recruitment remains real.
const Arts = preload("res://scripts/martial_catalog.gd")
const ShenCare = preload("res://scripts/shen_care_rules.gd")
const MAX_PARTY_SIZE: int = 4
const IDS: Array[String] = ["hero", "shen", "tang", "qin"]
const SHEN_ART: String = "art:shen_xumai"
const TANG_ART: String = "art:tang_fenjin"
const QIN_ART: String = "art:qin_shoudu"
const COMPANIONS: Dictionary = {
	"shen": {"name": "沈青", "max_hp": 82, "max_qi": 6, "attack": 13, "defense": 3,
		"hp_per_level": 8, "attack_per_level": 2, "defense_per_level": 1},
	"tang": {"name": "唐栖", "max_hp": 94, "max_qi": 6, "attack": 14, "defense": 5,
		"hp_per_level": 9, "attack_per_level": 2, "defense_per_level": 1},
	# Prepared combat tuning only. Qin still requires explicit story recruitment.
	"qin": {"name": "秦禾", "max_hp": 110, "max_qi": 6, "attack": 12, "defense": 6,
		"hp_per_level": 10, "attack_per_level": 2, "defense_per_level": 1},
}


static func build_team(state, roster_ids: Array, persisted_resources: Dictionary = {}) -> Dictionary:
	if state == null:
		return _error("缺少角色状态。")
	if not roster_ids.has("hero") or roster_ids.size() > MAX_PARTY_SIZE:
		return _error("出战名单必须包含主角，最多四人。")
	var seen: Array[String] = []
	for id: Variant in roster_ids:
		if not id is String or not IDS.has(id) or seen.has(id):
			return _error("出战名单含未知或重复角色。")
		seen.append(id)
		if (id == "shen" and not state.companion_unlocked) or (id == "tang" and not state.tangqi_unlocked):
			return _error("尚未结识并招募这位同行人。")
		if id == "qin" and (not state.has_method("qin_recruited") or not state.qin_recruited()):
			return _error("尚未结识并招募秦禾。")
	if not ["并肩", "护后"].has(String(state.formation)):
		return _error("阵法无效。")
	for id: Variant in persisted_resources:
		if not id is String or not roster_ids.has(id) or not persisted_resources[id] is Dictionary:
			return _error("续用资源必须对应本次出战角色。")
		for key: Variant in persisted_resources[id]:
			if not key in ["hp", "qi"] or not persisted_resources[id][key] is int:
				return _error("续用资源仅支持整数气血与真气。")
	var actors: Array[Dictionary] = []
	# Hero is always the front of 护后; companions preserve explicit roster order.
	var ordered: Array[String] = ["hero"]
	for id: String in seen:
		if id != "hero":
			ordered.append(id)
	for id: String in ordered:
		var actor: Dictionary = _hero(state) if id == "hero" else _companion(id, int(state.level))
		if id == "shen":
			actor.care_defense_bonus = ShenCare.shore_bonus(state)
			actor.care_healing_bonus = ShenCare.mobile_heal(state)
			actor.defense += int(actor.care_defense_bonus)
			actor.actions = action_definitions(id, "", int(actor.care_healing_bonus))
		var resources: Dictionary = persisted_resources.get(id, {})
		for key: String in ["hp", "qi"]:
			if resources.has(key):
				var amount: int = int(resources[key])
				if amount < 0 or amount > int(actor["max_" + key]):
					return _error("续用气血或真气超出角色上限。")
				actor[key] = amount
		actors.append(actor)
	return immutable({"ok": true, "reason": "", "team": {
		"actors": actors, "formation": String(state.formation),
		"medicine": maxi(0, int(state.medicine)),
		"medicine_heal": 55 if String(state.sect) == "照野堂" else 45,
	}})


static func _hero(state) -> Dictionary:
	var art: String = String(state.equipped_art)
	if not Arts.has_art(art) or not state.available_arts().has(art):
		art = Arts.BASE_ART
	var actor: Dictionary = _actor("hero", String(state.player_name), maxi(1, int(state.max_hp)), maxi(0, int(state.max_qi)), maxi(1, int(state.attack)), maxi(0, int(state.defense)))
	actor.hp = clampi(int(state.hp), 0, int(actor.max_hp))
	actor.qi = clampi(int(state.qi), 0, int(actor.max_qi))
	actor.sect = String(state.sect)
	actor.equipment = String(state.equipment)
	actor.armor = String(state.armor)
	actor.equipped_art = art
	for key: String in Arts.all_ids():
		if state.art_uses.has(key):
			actor.art_uses[key] = clampi(int(state.art_uses[key]), 0, 9999)
	actor.art_rank = rank_for_uses(int(actor.art_uses.get(art, 0)))
	actor.internal_unlocked = bool(state.internal_unlocked)
	actor.lightness_unlocked = bool(state.lightness_unlocked)
	actor.recruited = true
	actor.actions = action_definitions("hero", art)
	actor.cooldowns["art:" + art] = 0
	return actor


static func _companion(id: String, level: int) -> Dictionary:
	var spec: Dictionary = COMPANIONS[id]
	var growth: int = clampi(level - 1, 0, 98)
	var actor: Dictionary = _actor(id, spec.name, int(spec.max_hp) + growth * int(spec.hp_per_level), int(spec.max_qi), int(spec.attack) + growth * int(spec.attack_per_level), int(spec.defense) + growth * int(spec.defense_per_level))
	actor.recruited = true
	actor.actions = action_definitions(id)
	for action: Dictionary in actor.actions:
		if action.category == "martial":
			actor.cooldowns[action.id] = 0
	return actor


static func _actor(id: String, title: String, health: int, energy: int, power: int, protection: int) -> Dictionary:
	return {"id": id, "name": title, "team": "ally", "sect": "", "equipment": "", "armor": "",
		"hp": health, "max_hp": health, "qi": energy, "max_qi": energy,
		"attack": power, "defense": protection, "acted": false, "cooldowns": {},
		"status": {"guard": false, "focused_damage": 0, "weaken_amount": 0, "weaken_strikes": 0, "barrier": 0},
		"equipped_art": "", "art_rank": 1, "art_uses": {}, "actions": [],
		"care_defense_bonus": 0, "care_healing_bonus": 0}


static func action_definitions(actor_id: String, hero_art: String = "", care_healing_bonus: int = 0) -> Array:
	if not IDS.has(actor_id) or (actor_id == "hero" and not Arts.has_art(hero_art)):
		return immutable({"items": []}).items
	var basic_name: String = "平击" if actor_id == "hero" else ("银针点穴" if actor_id == "shen" else "短尺平击")
	if actor_id == "qin":
		basic_name = "杖击"
	var result: Array = [_action("attack", "attack", basic_name, "enemy", 0, 0, "攻击一名敌人，回复2真气；消耗已有蓄锋。")]
	if actor_id == "hero":
		var art: Dictionary = Arts.definition(hero_art)
		var move: Dictionary = _action("art:" + hero_art, "martial", art.name, "enemy", int(art.cost), int(art.cooldown), art.description)
		move.effects = art.duplicate(true)
		result.append(move)
	elif actor_id == "shen":
		var healing: int = 28 + clampi(care_healing_bonus, 0, 2)
		var move: Dictionary = _action(SHEN_ART, "martial", "青灯渡脉", "ally", 3, 2, "为一名仍站立的队友恢复%d气血；不能救起倒下的角色。" % healing)
		move.effects = {"healing": healing}
		result.append(move)
	elif actor_id == "tang":
		var move: Dictionary = _action(TANG_ART, "martial", "分劲尺", "enemy", 3, 2, "短尺击敌并卸劲：目标基础伤害减5，持续其两次攻击。")
		move.effects = {"attack_multiplier": 1, "damage_bonus": 2, "weaken_amount": 5, "weaken_strikes": 2}
		result.append(move)
	else:
		var move: Dictionary = _action(QIN_ART, "martial", "守渡横杖", "ally", 3, 2, "为一名仍站立的队友施加18点护障，不叠加；抵消其下一次来袭经防御、守势结算后的伤害，可减至0。该次受击后余量消散，未受击则本轮结束消散；不治疗、不救起倒下者。")
		move.effects = {"barrier": 18}
		result.append(move)
	result.append(_action("guard", "guard", "守势", "self", 0, 0, "回复1真气；本轮守势将来袭伤害乘三成，向上取整且至少1点；护障随后抵消，可降至0。"))
	result.append(_action("item", "item", "回春散", "self", 0, 0, "消耗共享行囊的一份回春散，治疗当前行动角色；不能救起倒下的角色。"))
	result.append(_action("flee", "flee", "退避", "none", 0, 0, "全队立即退离，不再受本轮反击；已使用资源不返还，无战胜奖励。"))
	return immutable({"items": result}).items


static func _action(id: String, category: String, title: String, target_team: String, cost: int, cooldown: int, description: String) -> Dictionary:
	return {"id": id, "category": category, "name": title, "target_team": target_team,
		"cost": cost, "cooldown": cooldown, "description": description, "effects": {}}


static func rank_for_uses(uses: int) -> int:
	return 3 if uses >= 15 else (2 if uses >= 5 else 1)


static func _error(reason: String) -> Dictionary:
	return immutable({"ok": false, "reason": reason, "team": {}})


static func immutable(value: Dictionary) -> Dictionary:
	var copy: Dictionary = value.duplicate(true)
	freeze(copy)
	return copy


static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for entry: Variant in value:
			freeze(entry)
		value.make_read_only()
