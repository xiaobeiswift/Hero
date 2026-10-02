class_name PartyCombatRules
extends RefCounted
## Detached, deterministic transactions. Presentation acknowledges a token; it
## never applies damage/costs. No save, quest, recruitment, or reward writes.
## Cooldown N means N other actions by that same actor before reuse.
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
const ENCOUNTERS: Dictionary = {
	"story": [{"id": "puheng", "name": "蒲横 · 河帮执事", "hp": 96, "attack": 9, "heavy_attack": 19}],
	"training": [{"id": "puheng", "name": "蒲横 · 切磋", "hp": 64, "attack": 9, "heavy_attack": 19}],
	"heting_receipt": [
		{"id": "striker", "name": "截签刀客", "hp": 190, "attack": 22, "heavy_attack": 34},
		{"id": "bracer", "name": "架刀护手", "hp": 110, "attack": 14, "heavy_attack": 14}],
}

var _actors: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _intents: Array[Dictionary] = []
var _configured: bool = false
var _active: bool = false
var _locked: bool = false
var _serial: int = 0
var _pending_token: int = -1
var _round: int = 1
var _phase: String = "unconfigured"
var _outcome: String = ""
var _encounter: String = ""
var _formation: String = "并肩"
var _medicine: int = 0
var _medicine_heal: int = 45
var _actor_id: String = ""
var _target_id: String = ""


func configure(team: Dictionary, encounter_id: String = "story") -> bool:
	if _configured or not ENCOUNTERS.has(encounter_id) or not _valid_team(team):
		return false
	# Whitelisted fields only: even an extra Object on the supplied dictionary
	# cannot retain a source model. Catalog inputs may be freed immediately.
	for source: Dictionary in team.actors:
		var actor: Dictionary = Catalog._actor(source.id, source.name, source.max_hp, source.max_qi, source.attack, source.defense)
		for key: String in ["hp", "qi", "sect", "equipment", "armor", "equipped_art"]:
			actor[key] = source.get(key, actor[key])
		actor.care_defense_bonus = int(source.get("care_defense_bonus", 0))
		actor.care_healing_bonus = int(source.get("care_healing_bonus", 0))
		if actor.id == "hero":
			for art: String in Arts.all_ids():
				if source.get("art_uses", {}).has(art):
					actor.art_uses[art] = clampi(int(source.art_uses[art]), 0, 9999)
			actor.art_rank = Catalog.rank_for_uses(int(actor.art_uses.get(actor.equipped_art, 0)))
		actor.actions = Catalog.action_definitions(actor.id, actor.equipped_art, actor.care_healing_bonus).duplicate(true)
		for action: Dictionary in actor.actions:
			if action.category == "martial":
				actor.cooldowns[action.id] = 0
		_actors.append(actor)
	_formation = team.formation
	_medicine = team.medicine
	_medicine_heal = team.medicine_heal
	_encounter = encounter_id
	for spec: Dictionary in ENCOUNTERS[encounter_id]:
		_enemies.append({"id": spec.id, "name": spec.name, "team": "enemy", "hp": spec.hp,
			"max_hp": spec.hp, "attack": spec.attack, "heavy_attack": spec.heavy_attack,
			"status": {"weaken_amount": 0, "weaken_strikes": 0}, "brace": false})
	_configured = true
	_active = true
	_phase = "ally"
	_actor_id = _first_unspent()
	_target_id = _first_living(_enemies)
	_plan_intents()
	return true


func _valid_team(team: Dictionary) -> bool:
	if not team.get("actors") is Array or team.actors.is_empty() or team.actors.size() > 3:
		return false
	if not team.get("formation") in ["并肩", "护后"] or not team.get("medicine") is int or int(team.medicine) < 0:
		return false
	if not team.get("medicine_heal") in [45, 55]:
		return false
	var seen: Array[String] = []
	var living: bool = false
	for actor: Variant in team.actors:
		if not actor is Dictionary or not actor.get("id") is String or not Catalog.IDS.has(actor.id) or seen.has(actor.id):
			return false
		seen.append(actor.id)
		if not actor.get("name") is String:
			return false
		for key: String in ["hp", "max_hp", "qi", "max_qi", "attack", "defense"]:
			if not actor.get(key) is int or int(actor[key]) < 0:
				return false
		if actor.max_hp < 1 or actor.attack < 1 or actor.hp > actor.max_hp or actor.qi > actor.max_qi:
			return false
		for key: String in ["sect", "equipment", "armor", "equipped_art"]:
			if not actor.get(key, "") is String:
				return false
		if not actor.get("care_defense_bonus", 0) is int or not actor.get("care_healing_bonus", 0) is int:
			return false
		if int(actor.get("care_defense_bonus", 0)) not in [0, 1] or int(actor.get("care_healing_bonus", 0)) not in [0, 2]:
			return false
		if actor.id == "hero" and not Arts.has_art(actor.get("equipped_art", "")):
			return false
		if not actor.get("art_uses", {}) is Dictionary:
			return false
		for art: Variant in actor.get("art_uses", {}):
			if not art is String or not Arts.has_art(art) or not actor.art_uses[art] is int:
				return false
		living = living or actor.hp > 0
	return seen[0] == "hero" and living


func snapshot() -> Dictionary:
	var actors: Array[Dictionary] = _actors.duplicate(true)
	for actor: Dictionary in actors:
		actor.actions = available_actions(actor.id)
		actor.front = actor.hp > 0 and (_formation == "并肩" or actor.id == _first_living(_actors))
		actor.row = "front" if actor.front else "rear"
		actor.exposed = actor.hp > 0 and _exposed_ids().has(actor.id)
	var enemies: Array[Dictionary] = _enemies.duplicate(true)
	for enemy: Dictionary in enemies:
		enemy.brace = _is_braced(enemy)
	return Catalog.immutable({"actors": actors, "enemies": enemies, "enemy_intents": _intents,
		"active_actor_id": _actor_id, "selected_target_id": _target_id,
		"round": _round, "phase": _phase, "formation": _formation,
		"medicine": _medicine, "medicine_heal": _medicine_heal, "encounter_id": _encounter,
		"active": _active, "locked": _locked, "outcome": _outcome})


func select_actor(id: String) -> bool:
	var actor: Dictionary = _actor(id)
	if _locked or not _active or actor.is_empty() or actor.hp <= 0 or actor.acted:
		return false
	_actor_id = id
	return true


func select_target(id: String) -> bool:
	var target: Dictionary = _unit(id)
	if _locked or not _active or target.is_empty() or target.hp <= 0:
		return false
	_target_id = id
	return true


func available_actions(actor_id: String = "") -> Array:
	var actor: Dictionary = _actor(_actor_id if actor_id.is_empty() else actor_id)
	var result: Array = []
	if actor.is_empty():
		return Catalog.immutable({"items": result}).items
	for definition: Dictionary in actor.actions:
		var action: Dictionary = definition.duplicate(true)
		var targets: Array[String] = _valid_targets(actor, action)
		var reason: String = _actor_action_reason(actor, action)
		if reason.is_empty() and action.target_team != "none" and targets.is_empty():
			reason = "没有可用目标；治疗不能救起倒下的角色。" if action.target_team == "ally" else "没有可用目标。"
		action.available = reason.is_empty()
		action.reason = reason
		action.valid_target_ids = targets
		action.cooldown_remaining = int(actor.cooldowns.get(action.id, 0))
		action.description = _describe(actor, action, _resolve_target(actor, action, ""))
		result.append(action)
	return Catalog.immutable({"items": result}).items


func action_unavailable_reason(action_id: String, target_id: String = "") -> String:
	var actor: Dictionary = _actor(_actor_id)
	var action: Dictionary = _action(actor, action_id)
	var reason: String = _actor_action_reason(actor, action)
	if not reason.is_empty():
		return reason
	if action.target_team == "none":
		return "此行动无需目标。" if not target_id.is_empty() else ""
	var resolved: String = _resolve_target(actor, action, target_id)
	var target: Dictionary = _unit(resolved)
	if target.is_empty():
		return "请先选择有效目标。"
	if target.hp <= 0:
		return "治疗不能救起倒下的角色。" if action.target_team == "ally" else "目标已经倒下。"
	if not _valid_targets(actor, action).has(resolved):
		if action.target_team == "ally" and target.team == "ally":
			return "目标气血充盈，无需治疗。"
		return "此行动不能用于该目标。"
	return ""


func action_description(action_id: String, target_id: String = "") -> String:
	var actor: Dictionary = _actor(_actor_id)
	var action: Dictionary = _action(actor, action_id)
	if actor.is_empty() or action.is_empty():
		return "无此行动。"
	return _describe(actor, action, _resolve_target(actor, action, target_id))


func accept_action(action_id: String, target_id: String = "") -> Dictionary:
	var reason: String = action_unavailable_reason(action_id, target_id)
	if not reason.is_empty():
		return Catalog.immutable({"ok": false, "accepted": false, "reason": reason, "token": -1})
	var before: Dictionary = snapshot()
	var actor: Dictionary = _actor(_actor_id)
	var action: Dictionary = _action(actor, action_id)
	var resolved: String = _resolve_target(actor, action, target_id)
	var target: Dictionary = _unit(resolved)
	_serial += 1
	_pending_token = _serial
	_locked = true
	var events: Array[Dictionary] = []
	var tx: Dictionary = {"ok": true, "accepted": true, "reason": "", "token": _pending_token,
		"action_id": action_id, "source_id": actor.id, "target_id": resolved, "before": before}
	_event(events, actor.id, resolved, "action", 0, {"action_id": action_id, "name": action.name})
	for id: String in actor.cooldowns:
		if id != action_id:
			actor.cooldowns[id] = maxi(0, int(actor.cooldowns[id]) - 1)
	actor.acted = true
	match action.category:
		"attack":
			_damage(actor, target, int(actor.attack) + int(actor.status.focused_damage), events)
			actor.status.focused_damage = 0
			_qi(actor, 2, events)
		"martial":
			_qi(actor, -int(action.cost), events)
			actor.cooldowns[action_id] = int(action.cooldown)
			_perform_art(actor, target, action, events)
		"guard":
			actor.status.guard = true
			_event(events, actor.id, actor.id, "guard", 1)
			_qi(actor, 1, events)
		"item":
			_medicine -= 1
			_event(events, actor.id, actor.id, "medicine", -1)
			_heal(actor, actor, _medicine_heal, events)
		"flee":
			_finish("flee", events, actor.id)
	if _active and _first_living(_enemies).is_empty():
		_finish("win", events, actor.id)
	if _active:
		_actor_id = _first_unspent()
		if _actor_id.is_empty():
			_enemy_phase(events)
	if not _active:
		_actor_id = ""
	if _unit(_target_id).is_empty() or int(_unit(_target_id).get("hp", 0)) <= 0:
		_target_id = _first_living(_enemies)
	tx.events = events
	tx.after = snapshot()
	return Catalog.immutable(tx)


func complete_presentation(token: int) -> bool:
	if not _locked or token != _pending_token:
		return false
	_locked = false
	_pending_token = -1
	return true


func _perform_art(actor: Dictionary, target: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var effects: Dictionary = action.effects
	if action.target_team == "ally":
		_heal(actor, target, int(effects.healing), events)
		return
	var rank: int = int(actor.art_rank) if actor.id == "hero" else 1
	_damage(actor, target, Advanced.direct_damage(effects, int(actor.attack), rank), events)
	if int(effects.get("healing", 0)) > 0:
		_heal(actor, actor, int(effects.healing), events)
	if bool(effects.get("guard", false)):
		actor.status.guard = true
		_event(events, actor.id, actor.id, "guard", 1)
	if target.hp > 0 and int(effects.get("weaken_amount", 0)) > 0:
		target.status.weaken_amount = maxi(int(target.status.weaken_amount), int(effects.weaken_amount))
		target.status.weaken_strikes = maxi(int(target.status.weaken_strikes), int(effects.weaken_strikes))
		_event(events, actor.id, target.id, "weaken", int(target.status.weaken_amount), {"strikes": target.status.weaken_strikes})
	var focus: int = Advanced.focus_damage(effects, int(actor.attack))
	if focus > 0:
		actor.status.focused_damage = maxi(int(actor.status.focused_damage), focus)
		_event(events, actor.id, actor.id, "focus", int(actor.status.focused_damage))
	if actor.id == "hero":
		var previous_uses: int = int(actor.art_uses.get(actor.equipped_art, 0))
		actor.art_uses[actor.equipped_art] = mini(9999, previous_uses + 1)
		actor.art_rank = Catalog.rank_for_uses(int(actor.art_uses[actor.equipped_art]))
		_event(events, actor.id, actor.id, "proficiency", int(actor.art_uses[actor.equipped_art]) - previous_uses, {"art_id": actor.equipped_art, "rank": actor.art_rank})


func _enemy_phase(events: Array[Dictionary]) -> void:
	_phase = "enemy"
	for intent: Dictionary in _intents:
		var enemy: Dictionary = _enemy(intent.source_id)
		if enemy.hp <= 0:
			continue
		if intent.type == "protect":
			if _enemy("striker").get("hp", 0) > 0:
				_event(events, enemy.id, "striker", "protect", 0)
			continue
		var target: Dictionary = {}
		for id: String in intent.target_order:
			if int(_actor(id).get("hp", 0)) > 0:
				target = _actor(id)
				break
		if target.is_empty():
			break
		var weakened: int = int(enemy.status.weaken_amount) if int(enemy.status.weaken_strikes) > 0 else 0
		var amount: int = maxi(1, int(intent.damage) - int(target.defense) - weakened)
		if target.status.guard:
			amount = maxi(1, int(ceil(float(amount) * 0.3)))
		_event(events, enemy.id, target.id, "action", 0, {"name": intent.name, "heavy": intent.heavy, "announced_target_id": intent.target_id})
		_damage(enemy, target, amount, events)
		if int(enemy.status.weaken_strikes) > 0:
			enemy.status.weaken_strikes -= 1
			if int(enemy.status.weaken_strikes) == 0:
				enemy.status.weaken_amount = 0
		if _first_living(_actors).is_empty():
			_finish("defeat", events, enemy.id)
			break
	if not _active:
		return
	_round += 1
	_phase = "ally"
	for actor: Dictionary in _actors:
		actor.acted = false
		actor.status.guard = false
	_actor_id = _first_unspent()
	_plan_intents()
	_event(events, "", "", "round_start", _round)


func _plan_intents() -> void:
	_intents.clear()
	var alive: Array[String] = []
	for actor: Dictionary in _actors:
		if actor.hp > 0:
			alive.append(actor.id)
	var attack_index: int = 0
	for enemy: Dictionary in _enemies:
		if enemy.hp <= 0:
			continue
		if enemy.id == "bracer" and _enemy("striker").get("hp", 0) > 0:
			_intents.append({"source_id": enemy.id, "target_id": "striker", "target_order": [], "type": "protect", "name": "架刀护伴", "damage": 0, "heavy": false, "order": _intents.size(), "round": _round, "target_policy": "protect_striker", "description": "截签刀客所受伤害减半并向上取整；本轮不攻击。"})
			continue
		var order: Array[String] = []
		var start: int = 0 if _formation == "护后" else posmod(_round - 1 + attack_index, alive.size())
		for offset: int in alive.size():
			order.append(alive[posmod(start + offset, alive.size())])
		var heavy: bool = _round % 2 == 0 and enemy.id != "bracer"
		var title: String = "护手短斩" if enemy.id == "bracer" else ("蓄势重斩" if heavy else "疾刃")
		if enemy.id == "striker":
			title = "截签重斩" if heavy else "探刃截签"
		_intents.append({"source_id": enemy.id, "target_id": order[0], "target_order": order,
			"type": "attack", "name": title, "damage": int(enemy.heavy_attack) if heavy else int(enemy.attack),
			"heavy": heavy, "order": _intents.size(), "round": _round, "range": "melee",
			"target_policy": "front_living" if _formation == "护后" else "rotate_front",
			"description": "%s攻击%s；目标倒下后依公开顺序转移。" % [title, _actor(order[0]).name]})
		attack_index += 1


func _actor_action_reason(actor: Dictionary, action: Dictionary) -> String:
	if _locked:
		return "请待这一招收势。"
	if not _active:
		return "当前没有进行中的战斗。"
	if actor.is_empty() or actor.hp <= 0:
		return "倒下的角色不能行动。"
	if actor.acted:
		return "这位角色本轮已经行动。"
	if action.is_empty():
		return "无此行动。"
	if int(actor.cooldowns.get(action.id, 0)) > 0:
		return "%s尚需调息%d次自身行动。" % [action.name, actor.cooldowns[action.id]]
	if int(actor.qi) < int(action.cost):
		return "真气不足，需要%d点。" % int(action.cost)
	if action.id == "item":
		if _medicine <= 0:
			return "共享行囊中没有回春散了。"
		if actor.hp >= actor.max_hp:
			return "气血充盈，无需用药。"
	return ""


func _valid_targets(actor: Dictionary, action: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if actor.is_empty() or action.is_empty():
		return ids
	match action.target_team:
		"enemy", "ally":
			var candidates: Array[Dictionary] = _enemies if action.target_team == "enemy" else _actors
			for target: Dictionary in candidates:
				if target.hp > 0 and (action.target_team == "enemy" or target.hp < target.max_hp):
					ids.append(target.id)
		"self":
			if actor.hp > 0:
				ids.append(actor.id)
	return ids


func _resolve_target(actor: Dictionary, action: Dictionary, supplied: String) -> String:
	if action.is_empty() or actor.is_empty() or action.target_team == "none":
		return ""
	if not supplied.is_empty():
		return supplied
	return String(actor.id) if action.target_team == "self" else _target_id


func _describe(actor: Dictionary, action: Dictionary, target_id: String) -> String:
	var target: Dictionary = _unit(target_id)
	if action.id == "guard":
		return "回复%d真气；本轮受到的每次伤害乘三成，向上取整且至少1点。" % mini(1, int(actor.max_qi) - int(actor.qi))
	if action.id == "item":
		return "为%s恢复%d气血（最多%d）；消耗共享回春散1份，余%d份。不能救起倒下的角色。" % [actor.name, mini(int(actor.max_hp) - int(actor.hp), _medicine_heal), _medicine_heal, _medicine]
	if action.category == "martial":
		var effects: Dictionary = action.effects
		var details: Array[String] = []
		if action.target_team == "ally":
			var maximum: int = int(effects.healing)
			if target.get("team") == "ally" and int(target.get("hp", 0)) > 0:
				var actual: int = mini(int(target.max_hp) - int(target.hp), maximum)
				details.append("为%s恢复%d气血（最多%d）%s；不能救起倒下的角色" % [target.name, actual, maximum, "；目标气血充盈，无需治疗" if actual == 0 else ""])
			else:
				details.append("请先选择仍站立的队友，最多恢复%d气血；不能救起倒下的角色" % maximum)
		else:
			var raw: int = Advanced.direct_damage(effects, actor.attack, actor.art_rank if actor.id == "hero" else 1)
			details.append("对%s造成%d伤害" % [target.get("name", "所选敌人"), _outgoing(target, raw) if target.get("team") == "enemy" else raw])
			if int(effects.get("healing", 0)) > 0:
				details.append("自身恢复%d气血" % mini(int(actor.max_hp) - int(actor.hp), int(effects.healing)))
			if bool(effects.get("guard", false)):
				details.append("本轮来袭伤害乘三成，向上取整且至少1点")
			if int(effects.get("weaken_amount", 0)) > 0:
				details.append("仅目标基础伤害减%d，持续其%d次攻击" % [effects.weaken_amount, effects.weaken_strikes])
			var focus: int = Advanced.focus_damage(effects, actor.attack)
			if focus > 0:
				details.append("下一次平击蓄锋+%d" % focus)
		return "%s；耗%d真气，需%d次其他自身行动调息。" % ["；".join(details), action.cost, action.cooldown]
	if action.id == "attack":
		var raw: int = int(actor.attack) + int(actor.status.focused_damage)
		return "对%s造成%d伤害，回复%d真气；消耗已有蓄锋。" % [target.get("name", "所选敌人"), _outgoing(target, raw) if target.get("team") == "enemy" else raw, mini(2, int(actor.max_qi) - int(actor.qi))]
	return String(action.description)


func _outgoing(target: Dictionary, amount: int) -> int:
	if target.is_empty() or target.hp <= 0:
		return 0
	var adjusted: int = maxi(1, int(ceil(float(amount) * 0.5))) if _is_braced(target) else maxi(0, amount)
	return mini(int(target.hp), adjusted)


func _is_braced(target: Dictionary) -> bool:
	return target.get("id") == "striker" and target.get("hp", 0) > 0 and _enemy("bracer").get("hp", 0) > 0


func _damage(source: Dictionary, target: Dictionary, amount: int, events: Array[Dictionary]) -> void:
	var actual: int = _outgoing(target, amount)
	target.hp -= actual
	_event(events, source.id, target.id, "damage", actual)
	if target.hp == 0:
		_event(events, source.id, target.id, "down", 0)


func _heal(source: Dictionary, target: Dictionary, amount: int, events: Array[Dictionary]) -> void:
	var actual: int = mini(int(target.max_hp) - int(target.hp), maxi(0, amount))
	target.hp += actual
	_event(events, source.id, target.id, "heal", actual)


func _qi(actor: Dictionary, amount: int, events: Array[Dictionary]) -> void:
	var before: int = actor.qi
	actor.qi = clampi(int(actor.qi) + amount, 0, int(actor.max_qi))
	_event(events, actor.id, actor.id, "qi", int(actor.qi) - before)


func _event(events: Array[Dictionary], source: String, target: String, type: String, amount: int, extras: Dictionary = {}) -> void:
	var event: Dictionary = {"source_id": source, "target_id": target, "type": type, "amount": amount, "phase": _phase, "round": _round}
	event.merge(extras)
	events.append(event)


func _finish(outcome: String, events: Array[Dictionary], source: String) -> void:
	_active = false
	_outcome = outcome
	_event(events, source, "", "outcome", 0, {"outcome": outcome})
	_phase = "ended"


func _exposed_ids() -> Array[String]:
	var result: Array[String] = []
	if not _active:
		return result
	for intent: Dictionary in _intents:
		if intent.type == "attack" and int(_enemy(intent.source_id).get("hp", 0)) > 0:
			for id: String in intent.target_order:
				if _actor(id).get("hp", 0) > 0:
					if not result.has(id):
						result.append(id)
					break
	return result


func _first_unspent() -> String:
	for actor: Dictionary in _actors:
		if actor.hp > 0 and not actor.acted:
			return actor.id
	return ""


func _first_living(units: Array[Dictionary]) -> String:
	for unit: Dictionary in units:
		if unit.hp > 0:
			return unit.id
	return ""


func _actor(id: String) -> Dictionary:
	for actor: Dictionary in _actors:
		if actor.id == id:
			return actor
	return {}


func _enemy(id: String) -> Dictionary:
	for enemy: Dictionary in _enemies:
		if enemy.id == id:
			return enemy
	return {}


func _unit(id: String) -> Dictionary:
	var actor: Dictionary = _actor(id)
	return _enemy(id) if actor.is_empty() else actor


func _action(actor: Dictionary, id: String) -> Dictionary:
	for action: Dictionary in actor.get("actions", []):
		if action.id == id:
			return action
	return {}
