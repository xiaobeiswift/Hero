class_name AutomaticPartyCombat
extends "res://scripts/party_combat_rules.gd"
## One accepted action per presentation token. Basics are automatic entitlements;
## optional commands are exact-target queues and never replace those basics.
const Skills = preload("res://scripts/combat_skill_catalog.gd")
const Patterns = preload("res://scripts/battle_patterns.gd")
const Sects = preload("res://scripts/sect_rules.gd")
const CATEGORIES: Array[String] = ["martial", "internal", "lightness"]
const ENCOUNTER_IDS: Array[String] = ["story", "training", "sect_trial", "courtyard_practice", "sluice_scout", "sluice_boss", "archive_boss", "mist_scout", "mist_keeper", "heting_receipt"]
const SUPPORTED_ENCOUNTERS: Array[String] = ENCOUNTER_IDS
static var _global_epoch: int = 0
static var _global_token: int = 0
var _epoch: int = 0
var _selected_actor: String = ""
var _acting_actor: String = ""
var _enemy_cursor: int = 0
var _paused: bool = false
var _pause_requested: bool = false
var _queues: Dictionary = {}
var _queue_serial: int = 0
var _trial: Dictionary = {"art_used": false, "healing": 0, "guarded_heavy": false, "required_art": "", "met": false}


func configure(team: Dictionary, encounter_id: String = "story") -> bool:
	# Practice legitimately owns 40-point medicine; all other validation remains
	# shared with the detached actor catalog, and no input object is retained.
	if _configured or not ENCOUNTER_IDS.has(encounter_id):
		return false
	var validation: Dictionary = team.duplicate(true)
	if encounter_id == "courtyard_practice" and validation.get("medicine_heal") == 40:
		validation.medicine_heal = 45
	if not _valid_team(validation):
		return false
	_global_epoch += 1
	_epoch = _global_epoch
	for source: Dictionary in team.actors:
		var actor: Dictionary = Catalog._actor(source.id, source.name, source.max_hp, source.max_qi, source.attack, source.defense)
		for key: String in ["hp", "qi", "sect", "equipment", "armor", "equipped_art", "care_defense_bonus", "care_healing_bonus"]:
			actor[key] = source.get(key, actor[key])
		for key: String in ["internal_unlocked", "lightness_unlocked", "recruited"]:
			actor[key] = source.get(key, false) is bool and source.get(key, false) == true
		actor.learned_flags = {}
		if source.get("learned_flags") is Dictionary:
			for flag: Variant in source.learned_flags:
				if flag is String and source.learned_flags[flag] is bool:
					actor.learned_flags[flag] = source.learned_flags[flag]
		if actor.id == "hero":
			for art: String in Arts.all_ids():
				if source.get("art_uses", {}).has(art):
					actor.art_uses[art] = clampi(int(source.art_uses[art]), 0, 9999)
			actor.art_rank = Catalog.rank_for_uses(int(actor.art_uses.get(actor.equipped_art, 0)))
		actor.actions = Skills.manual_actions(actor).duplicate(true)
		actor.actions.append(Catalog._action("item", "item", "回春散", "self", 0, 0, "在收势间隙服药；每人每轮一次，不替代自动平击。"))
		actor.actions.append(Catalog._action("flee", "flee", "退避", "none", 0, 0, "全队退离；已消耗的资源不返还。"))
		actor.basic_round = 0
		actor.medicine_round = 0
		actor.category_used_round = {}
		actor.cooldown_set_round = {}
		actor.status.vulnerability_hits = 0
		actor.status.next_hit_reduction = 0
		actor.status.guard_action_id = ""
		for action: Dictionary in actor.actions:
			actor.cooldowns[action.id] = 0
			actor.cooldown_set_round[action.id] = 0
		for category: String in CATEGORIES:
			actor.category_used_round[category] = 0
		_queues[actor.id] = {}
		if encounter_id == "courtyard_practice":
			actor.hp = actor.max_hp
			actor.qi = actor.max_qi
		_actors.append(actor)
	_formation = team.formation
	_medicine = 3 if encounter_id == "courtyard_practice" else int(team.medicine)
	_medicine_heal = 40 if encounter_id == "courtyard_practice" else int(team.medicine_heal)
	_encounter = encounter_id
	var specs: Array = []
	if ENCOUNTERS.has(encounter_id):
		specs = ENCOUNTERS[encounter_id]
	elif encounter_id == "sect_trial":
		specs = [{"id": "sect_trial", "name": "岑远 · 门中试招", "hp": maxi(180, int(_actor("hero").attack) * 4 + 30), "attack": 18, "heavy_attack": 30}]
	elif encounter_id == "courtyard_practice":
		specs = [{"id": "striker", "name": "执棍木人", "hp": 96, "attack": 14, "heavy_attack": 24}, {"id": "bracer", "name": "架盾木人", "hp": 64, "attack": 10, "heavy_attack": 10}]
	else:
		specs = [{"id": encounter_id, "name": "雾竹巡哨" if encounter_id == "mist_scout" else "雾竹守关人", "hp": 155 if encounter_id == "mist_scout" else 300, "attack": 14 if encounter_id == "mist_scout" else 10, "heavy_attack": 24 if encounter_id == "mist_scout" else 33}]
	for spec: Dictionary in specs:
		_enemies.append({"id": spec.id, "name": spec.name, "team": "enemy", "hp": spec.hp, "max_hp": spec.hp, "attack": spec.attack, "heavy_attack": spec.heavy_attack, "status": {"weaken_amount": 0, "weaken_strikes": 0}, "brace": false})
	_trial.required_art = String(Sects.TRIALS.get(_actor("hero").sect, {}).get("art", ""))
	_configured = true
	_active = true
	_phase = "ally"
	_selected_actor = _first_living(_actors)
	_actor_id = _selected_actor
	_target_id = _first_living(_enemies)
	_plan_intents()
	return true


func snapshot() -> Dictionary:
	var actors: Array[Dictionary] = _actors.duplicate(true)
	for actor: Dictionary in actors:
		actor.actions = available_actions(actor.id)
		actor.basic_done = int(actor.basic_round) == _round
		actor.acted = actor.basic_done
		actor.categories = {}
		for category: String in CATEGORIES:
			var queued: Dictionary = _queues.get(actor.id, {}).get(category, {})
			actor.categories[category] = {"used": int(actor.category_used_round[category]) == _round, "used_round": actor.category_used_round[category], "queued": not queued.is_empty(), "queue_round": int(queued.get("queue_round", 0)), "action_id": String(queued.get("action_id", "")), "target_id": String(queued.get("target_id", ""))}
		actor.front = actor.hp > 0 and (_formation == "并肩" or actor.id == _first_living(_actors))
		actor.row = "front" if actor.front else "rear"
		actor.exposed = actor.hp > 0 and _exposed_ids().has(actor.id)
	var enemies: Array[Dictionary] = _enemies.duplicate(true)
	var pattern: Dictionary = Patterns.phase(_encounter, _round - 1)
	for enemy: Dictionary in enemies:
		enemy.brace = _is_braced(enemy) or bool(pattern.get("guarded", false))
		enemy.opening_bonus = int(pattern.get("opening", 0))
	return Catalog.immutable({"actors": actors, "enemies": enemies, "enemy_intents": _intents,
		"active_actor_id": _acting_actor, "selected_actor_id": _selected_actor, "selected_target_id": _target_id,
		"next_actor_id": _first_unspent(), "round": _round, "phase": _phase, "formation": _formation,
		"medicine": _medicine, "medicine_heal": _medicine_heal, "encounter_id": _encounter,
		"active": _active, "locked": _locked, "outcome": _outcome, "paused": _paused,
		"pause_requested": _pause_requested, "epoch": _epoch, "pending_token": _pending_token,
		"action_sequence": _serial, "trial_provenance": _trial, "automatic": true})


func select_actor(id: String) -> bool:
	var actor: Dictionary = _actor(id)
	if not _active or actor.is_empty() or actor.hp <= 0:
		return false
	_selected_actor = id
	_actor_id = id
	return true


func select_target(id: String) -> bool:
	var target: Dictionary = _unit(id)
	if not _active or target.is_empty() or target.hp <= 0:
		return false
	_target_id = id
	return true


func set_paused(value: bool) -> bool:
	if not _active:
		return false
	_pause_requested = value
	if not _locked:
		_paused = value
	return true


func queue_skill(actor_id: String, action_id: String, target_id: String = "") -> Dictionary:
	var actor: Dictionary = _actor(actor_id)
	var action: Dictionary = _action(actor, action_id)
	var reason: String = _queue_reason(actor, action)
	var resolved: String = _resolve_target(actor, action, target_id)
	if reason.is_empty() and not _valid_targets(actor, action).has(resolved):
		reason = "请选择仍有效的技能目标；倒下者不能接受技能。"
	if not reason.is_empty():
		return _rejected(reason)
	var queued_round: int = _next_basic_round(actor)
	_queue_serial += 1
	_queues[actor_id][action.category] = {"action_id": action_id, "target_id": resolved, "queue_round": queued_round, "order": _queue_serial}
	return Catalog.immutable({"ok": true, "accepted": false, "queued": true, "actor_id": actor_id, "action_id": action_id, "target_id": resolved, "category": action.category, "queue_round": queued_round, "reason": "", "token": -1})


func cancel_queued(actor_id: String, category: String) -> bool:
	if not _active or not _queues.has(actor_id) or not _queues[actor_id].has(category):
		return false
	_queues[actor_id].erase(category)
	return true


func available_actions(actor_id: String = "") -> Array:
	var actor: Dictionary = _actor(_selected_actor if actor_id.is_empty() else actor_id)
	var result: Array = []
	for definition: Dictionary in actor.get("actions", []):
		var action: Dictionary = definition.duplicate(true)
		var category: String = String(action.category)
		var manual: bool = CATEGORIES.has(category)
		var reason: String = _queue_reason(actor, action) if manual else _utility_reason(actor, action)
		var targets: Array[String] = _valid_targets(actor, action)
		if reason.is_empty() and action.target_team != "none" and targets.is_empty():
			reason = "没有可用目标；治疗不能救起倒下者。"
		var queued: Dictionary = _queues.get(actor.id, {}).get(category, {})
		action.available = reason.is_empty()
		action.reason = reason
		action.valid_target_ids = targets
		action.cooldown_remaining = int(actor.cooldowns.get(action.id, 0))
		action.eligible_round = _eligible_round(actor, action)
		action.used = int(actor.category_used_round.get(category, 0)) == _round
		action.queued = not queued.is_empty()
		action.queue_round = int(queued.get("queue_round", 0))
		action.queued_target_id = String(queued.get("target_id", ""))
		action.description = _describe(actor, action, _resolve_target(actor, action, ""))
		result.append(action)
	return Catalog.immutable({"items": result}).items


func action_unavailable_reason(action_id: String, target_id: String = "") -> String:
	var actor: Dictionary = _actor(_selected_actor)
	var action: Dictionary = _action(actor, action_id)
	var reason: String = _queue_reason(actor, action) if CATEGORIES.has(String(action.get("category", ""))) else _utility_reason(actor, action)
	if reason.is_empty() and action.target_team != "none" and not _valid_targets(actor, action).has(_resolve_target(actor, action, target_id)):
		reason = "请选择仍有效的目标。"
	return reason


func action_description(action_id: String, target_id: String = "") -> String:
	var actor: Dictionary = _actor(_selected_actor)
	var action: Dictionary = _action(actor, action_id)
	return "无此行动。" if action.is_empty() else _describe(actor, action, _resolve_target(actor, action, target_id))


func accept_action(action_id: String, target_id: String = "") -> Dictionary:
	if action_id not in ["item", "flee"]:
		return _rejected("平击由战斗自动推进；手动技能请加入待发队列。")
	var actor: Dictionary = _actor(_selected_actor)
	var action: Dictionary = _action(actor, action_id)
	var reason: String = _utility_reason(actor, action)
	if not reason.is_empty():
		return _rejected(reason)
	if (action_id == "item" and not target_id.is_empty() and target_id != actor.id) or (action_id == "flee" and not target_id.is_empty()):
		return _rejected("此辅助行动的目标无效。")
	var tx: Dictionary = _begin_transaction(actor.id, action_id, actor.id if action_id == "item" else "")
	var events: Array[Dictionary] = []
	_event(events, actor.id, tx.target_id, "action", 0, {"action_id": action_id, "name": action.name, "category": action.category})
	if action_id == "item":
		_medicine -= 1
		actor.medicine_round = _round
		_event(events, actor.id, actor.id, "medicine", -1)
		_heal(actor, actor, _medicine_heal, events)
	else:
		_finish("flee", events, actor.id)
	return _end_transaction(tx, events)


func advance() -> Dictionary:
	if not _active or _locked or _paused:
		return _rejected("当前战斗已结束。" if not _active else ("请待这一招收势。" if _locked else "战斗已暂停。"))
	# Down actors lose all pending commands without charging resources.
	for actor: Dictionary in _actors:
		if actor.hp <= 0:
			_queues[actor.id].clear()
	var next_id: String = _first_unspent()
	if not next_id.is_empty():
		_phase = "ally"
		var actor: Dictionary = _actor(next_id)
		var queued: Dictionary = _next_queue(actor)
		if not queued.is_empty():
			return _execute_queued(actor, queued)
		var target: Dictionary = _enemy(_target_id)
		if target.is_empty() or target.hp <= 0:
			target = _enemy(_first_living(_enemies))
		if target.is_empty():
			return _terminal_transaction("win", actor.id)
		var tx: Dictionary = _begin_transaction(actor.id, "attack", target.id)
		var events: Array[Dictionary] = []
		_event(events, actor.id, target.id, "action", 0, {"action_id": "attack", "name": "自动平击", "category": "attack", "automatic": true})
		actor.basic_round = _round
		actor.acted = true
		_damage(actor, target, int(actor.attack) + int(actor.status.focused_damage), events)
		actor.status.focused_damage = 0
		_qi(actor, 2, events)
		if _first_living(_enemies).is_empty():
			_finish("win", events, actor.id)
		return _end_transaction(tx, events)
	_phase = "enemy"
	while _enemy_cursor < _intents.size():
		var intent: Dictionary = _intents[_enemy_cursor]
		_enemy_cursor += 1
		if int(_enemy(intent.source_id).get("hp", 0)) > 0:
			return _execute_enemy(intent)
	# A round with only skipped intents still has an acknowledged transition.
	var tx: Dictionary = _begin_transaction("", "round_end", "")
	var events: Array[Dictionary] = []
	_complete_round(events)
	return _end_transaction(tx, events)


func complete_presentation(token: int) -> bool:
	if not _locked or token != _pending_token:
		return false
	_locked = false
	_pending_token = -1
	_acting_actor = ""
	_paused = _pause_requested and _active
	return true


func _begin_transaction(source_id: String, action_id: String, target_id: String) -> Dictionary:
	var before: Dictionary = snapshot()
	_global_token += 1
	_serial += 1
	_pending_token = _global_token
	_locked = true
	_acting_actor = source_id
	return {"ok": true, "accepted": true, "reason": "", "epoch": _epoch, "sequence": _serial, "token": _pending_token, "action_id": action_id, "source_id": source_id, "target_id": target_id, "before": before}


func _end_transaction(tx: Dictionary, events: Array[Dictionary]) -> Dictionary:
	if _unit(_target_id).is_empty() or int(_unit(_target_id).get("hp", 0)) <= 0:
		_target_id = _first_living(_enemies)
	if int(_actor(_selected_actor).get("hp", 0)) <= 0:
		_selected_actor = _first_living(_actors)
		_actor_id = _selected_actor
	tx.events = events
	tx.after = snapshot()
	return Catalog.immutable(tx)


func _terminal_transaction(outcome: String, source: String) -> Dictionary:
	var tx: Dictionary = _begin_transaction(source, "outcome", "")
	var events: Array[Dictionary] = []
	_finish(outcome, events, source)
	return _end_transaction(tx, events)


func _execute_queued(actor: Dictionary, queued: Dictionary) -> Dictionary:
	var action: Dictionary = _action(actor, queued.action_id)
	var tx: Dictionary = _begin_transaction(actor.id, queued.action_id, queued.target_id)
	var events: Array[Dictionary] = []
	_queues[actor.id].erase(action.category)
	var reason: String = ""
	if not _valid_targets(actor, action).has(String(queued.target_id)):
		reason = "排定的目标已无效，取消技能且不扣真气。"
	elif int(actor.qi) < int(action.cost):
		reason = "执行时真气不足，取消技能且不扣真气。"
	elif int(actor.category_used_round[action.category]) == _round or _round < _eligible_round(actor, action):
		reason = "本轮技能次数或调息尚未就绪。"
	if not reason.is_empty():
		_event(events, actor.id, queued.target_id, "queue_cancel", 0, {"action_id": action.id, "category": action.category, "reason": reason})
		return _end_transaction(tx, events)
	actor.category_used_round[action.category] = _round
	actor.cooldowns[action.id] = int(action.cooldown)
	actor.cooldown_set_round[action.id] = _round
	_event(events, actor.id, queued.target_id, "action", 0, {"action_id": action.id, "name": action.name, "category": action.category})
	_qi(actor, -int(action.cost), events)
	_perform_skill(actor, _unit(queued.target_id), action, events)
	if _first_living(_enemies).is_empty():
		_finish("win", events, actor.id)
	return _end_transaction(tx, events)


func _perform_skill(actor: Dictionary, target: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var effects: Dictionary = action.effects
	var heal_target: Dictionary = target if action.target_team in ["ally", "self"] else actor
	var required: bool = _encounter == "sect_trial" and actor.id == "hero" and action.id == "art:" + String(_trial.required_art)
	if required:
		_trial.art_used = true
	if action.target_team == "enemy":
		_damage(actor, target, Advanced.direct_damage(effects, int(actor.attack), int(actor.art_rank) if actor.id == "hero" else 1), events)
	if int(effects.get("healing", 0)) > 0:
		var old_hp: int = int(heal_target.hp)
		_heal(actor, heal_target, int(effects.healing), events)
		if required:
			_trial.healing += int(heal_target.hp) - old_hp
	if int(effects.get("barrier", 0)) > 0:
		_grant_barrier(actor, target, int(effects.barrier), events)
	if bool(effects.get("guard", false)):
		_guard(actor, events)
		actor.status.guard_action_id = action.id
	if target.hp > 0 and int(effects.get("weaken_amount", 0)) > 0:
		target.status.weaken_amount = maxi(int(target.status.weaken_amount), int(effects.weaken_amount))
		target.status.weaken_strikes = maxi(int(target.status.weaken_strikes), int(effects.weaken_strikes))
		_event(events, actor.id, target.id, "weaken", int(target.status.weaken_amount), {"strikes": target.status.weaken_strikes})
	var focus: int = Advanced.focus_damage(effects, int(actor.attack))
	if focus > 0:
		actor.status.focused_damage = maxi(int(actor.status.focused_damage), focus)
		_event(events, actor.id, actor.id, "focus", int(actor.status.focused_damage))
	if int(effects.get("next_hit_reduction", 0)) > 0:
		actor.status.next_hit_reduction = maxi(int(actor.status.next_hit_reduction), int(effects.next_hit_reduction))
		_event(events, actor.id, actor.id, "lightness_grant", int(actor.status.next_hit_reduction), {"remaining": actor.status.next_hit_reduction})
	if actor.id == "hero" and action.category == "martial" and _encounter != "courtyard_practice":
		var previous: int = int(actor.art_uses.get(actor.equipped_art, 0))
		actor.art_uses[actor.equipped_art] = mini(9999, previous + 1)
		actor.art_rank = Catalog.rank_for_uses(int(actor.art_uses[actor.equipped_art]))
		_event(events, actor.id, actor.id, "proficiency", int(actor.art_uses[actor.equipped_art]) - previous, {"art_id": actor.equipped_art, "rank": actor.art_rank})
	_update_trial_met()


func _execute_enemy(intent: Dictionary) -> Dictionary:
	var enemy: Dictionary = _enemy(intent.source_id)
	var target: Dictionary = {}
	for id: String in intent.target_order:
		if int(_actor(id).get("hp", 0)) > 0:
			target = _actor(id)
			break
	var tx: Dictionary = _begin_transaction(enemy.id, "enemy:" + String(intent.type), String(intent.target_id) if target.is_empty() else String(target.id))
	var events: Array[Dictionary] = []
	if intent.type == "protect":
		_event(events, enemy.id, intent.target_id, "action", 0, {"action_id": "enemy:protect", "name": intent.name, "announced_target_id": intent.target_id, "heavy": false})
		_event(events, enemy.id, intent.target_id, "protect", 0, {"effective": int(_enemy(intent.target_id).get("hp", 0)) > 0})
	elif not target.is_empty():
		var weakened: int = int(enemy.status.weaken_amount) if int(enemy.status.weaken_strikes) > 0 else 0
		var amount: int = maxi(1, int(intent.damage) - int(target.defense) - weakened)
		var vulnerable: bool = int(target.status.vulnerability_hits) > 0
		if vulnerable:
			amount += 3
		if target.status.guard:
			amount = maxi(1, int(ceil(float(amount) * 0.3)))
		_event(events, enemy.id, target.id, "action", 0, {"action_id": "enemy:attack", "name": intent.name, "heavy": intent.heavy, "announced_target_id": intent.target_id, "damage": intent.damage, "weakened": weakened})
		if _encounter == "sect_trial" and target.id == "hero" and intent.heavy and target.status.guard and target.status.guard_action_id == "art:磐石回锋" and _trial.required_art == "磐石回锋":
			_trial.guarded_heavy = true
			_event(events, target.id, enemy.id, "trial_guarded_heavy", 1, {"action_id": target.status.guard_action_id})
			_update_trial_met()
		if vulnerable:
			target.status.vulnerability_hits -= 1
			_event(events, enemy.id, target.id, "vulnerability_consume", 1, {"remaining": target.status.vulnerability_hits, "bonus": 3})
		var reduction: int = int(target.status.next_hit_reduction)
		if reduction > 0:
			target.status.next_hit_reduction = 0
			_event(events, enemy.id, target.id, "lightness_absorb", mini(reduction, amount), {"remaining": 0, "incoming_after_guard": amount})
			amount = maxi(0, amount - reduction)
		amount = _absorb_barrier(enemy, target, amount, events)
		var actual: int = _damage(enemy, target, amount, events)
		if bool(intent.get("exposes", false)) and not target.status.guard and actual > 0 and target.hp > 0:
			target.status.vulnerability_hits = 2
			_event(events, enemy.id, target.id, "vulnerability_apply", 2, {"remaining": 2, "bonus": 3, "reason": "unguarded_heavy"})
		if int(enemy.status.weaken_strikes) > 0:
			enemy.status.weaken_strikes -= 1
			if int(enemy.status.weaken_strikes) == 0:
				enemy.status.weaken_amount = 0
		if _first_living(_actors).is_empty():
			_finish("defeat", events, enemy.id)
	if _active and not _remaining_enemy_intent():
		_complete_round(events)
	return _end_transaction(tx, events)


func _remaining_enemy_intent() -> bool:
	for index: int in range(_enemy_cursor, _intents.size()):
		if int(_enemy(_intents[index].source_id).get("hp", 0)) > 0:
			return true
	return false


func _complete_round(events: Array[Dictionary]) -> void:
	_expire_barriers(events, "round_end")
	for actor: Dictionary in _actors:
		if int(actor.status.next_hit_reduction) > 0:
			_event(events, actor.id, actor.id, "lightness_expire", int(actor.status.next_hit_reduction), {"remaining": 0, "reason": "round_end"})
			actor.status.next_hit_reduction = 0
		for id: String in actor.cooldowns:
			if int(actor.cooldowns[id]) > 0 and int(actor.cooldown_set_round[id]) < _round:
				actor.cooldowns[id] -= 1
				_event(events, actor.id, actor.id, "cooldown_tick", -1, {"action_id": id, "remaining": actor.cooldowns[id]})
		actor.status.guard = false
		actor.status.guard_action_id = ""
		actor.acted = false
	_event(events, "", "", "round_end", _round)
	_round += 1
	_enemy_cursor = 0
	_phase = "ally"
	_plan_intents()
	_event(events, "", "", "round_start", _round)


func _plan_intents() -> void:
	super._plan_intents()
	var pattern: Dictionary = Patterns.phase(_encounter, _round - 1)
	for intent: Dictionary in _intents:
		if _encounter == "courtyard_practice":
			if intent.type == "protect":
				intent.name = "架盾护伴"
				intent.description = "架盾护住执棍木人：其所受伤害减半并向上取整；本轮不攻击。"
			else:
				intent.name = ("蓄棍重击" if intent.heavy else "探棍轻击") if intent.source_id == "striker" else "短盾轻推"
				intent.description = "%s · 基础伤害%d，攻击%s；目标倒下后依公开顺序转移。" % [intent.name, intent.damage, _actor(intent.target_id).name]
		if intent.type != "attack":
			continue
		intent.exposes = intent.source_id in ["sluice_boss", "archive_boss"] and intent.heavy
		if not pattern.is_empty():
			for key: String in ["name", "damage", "heavy", "guarded", "opening", "exposes"]:
				intent[key] = pattern[key]
			intent.description = "%s · %s（基础%d）攻击%s；目标倒下后依公开顺序转移。" % [intent.name, "重击" if intent.heavy else "轻击", intent.damage, _actor(intent.target_id).name]
			if intent.guarded:
				intent.description += "本轮受到的攻击伤害减半并向上取整。"
			if int(intent.opening) > 0:
				intent.description += "本轮每位独立出手的队员攻击伤害+%d。" % int(intent.opening)
			if intent.exposes:
				intent.description += "未守势且实际损失气血者留下破绽2次（后续每次来袭+3）。"


func _outgoing(target: Dictionary, amount: int) -> int:
	if target.is_empty() or target.hp <= 0:
		return 0
	if target.get("team") == "enemy" and _encounter in ["mist_scout", "mist_keeper"]:
		# Every roster member is an independent actor. All damaging actions gain
		# the published opening bonus; healing/barrier actions never call this.
		amount = Patterns.outgoing(_encounter, _round - 1, amount, false)
	return super._outgoing(target, amount)


func _finish(outcome: String, events: Array[Dictionary], source: String) -> void:
	for actor: Dictionary in _actors:
		_queues[actor.id].clear()
		actor.status.next_hit_reduction = 0
	_paused = false
	_pause_requested = false
	_update_trial_met()
	super._finish(outcome, events, source)


func _update_trial_met() -> void:
	match String(_actor("hero").get("sect", "")):
		"听潮阁": _trial.met = bool(_trial.art_used)
		"照野堂": _trial.met = int(_trial.healing) > 0
		"问石门": _trial.met = bool(_trial.guarded_heavy)


func _first_unspent() -> String:
	for actor: Dictionary in _actors:
		if actor.hp > 0 and int(actor.get("basic_round", 0)) != _round:
			return actor.id
	return ""


func _next_basic_round(actor: Dictionary) -> int:
	return _round + (1 if int(actor.get("basic_round", 0)) == _round else 0)


func _eligible_round(actor: Dictionary, action: Dictionary) -> int:
	var set_round: int = int(actor.get("cooldown_set_round", {}).get(action.get("id", ""), 0))
	return 1 if set_round == 0 else set_round + int(action.get("cooldown", 0)) + 1


func _next_queue(actor: Dictionary) -> Dictionary:
	var chosen: Dictionary = {}
	for queued: Dictionary in _queues[actor.id].values():
		if int(queued.queue_round) <= _round and (chosen.is_empty() or int(queued.order) < int(chosen.order)):
			chosen = queued
	return chosen


func _valid_targets(actor: Dictionary, action: Dictionary) -> Array[String]:
	var result: Array[String] = super._valid_targets(actor, action)
	if not actor.is_empty() and action.get("target_team") == "self" and int(action.get("effects", {}).get("healing", 0)) > 0 and actor.hp >= actor.max_hp:
		var focus: int = Advanced.focus_damage(action.effects, int(actor.attack))
		if focus <= int(actor.status.focused_damage):
			result.clear()
	return result


func _queue_reason(actor: Dictionary, action: Dictionary) -> String:
	if not _active:
		return "当前没有进行中的战斗。"
	if actor.is_empty() or actor.hp <= 0:
		return "倒下的角色不能排定技能。"
	if action.is_empty() or not CATEGORIES.has(String(action.get("category", ""))):
		return "此行动不是可排定的武学、内功或轻功。"
	if not bool(action.get("learned", false)):
		return String(action.get("reason", "尚未习得此类技能。"))
	if _queues.get(actor.id, {}).has(action.category):
		return "这类技能已排定；可先取消后重新选择。"
	var next_round: int = _next_basic_round(actor)
	if int(actor.category_used_round[action.category]) == next_round:
		return "这位角色本轮已使用过这类技能。"
	if next_round < _eligible_round(actor, action):
		return "%s正在调息；第%d轮可再用。" % [action.name, _eligible_round(actor, action)]
	if int(actor.qi) < int(action.cost):
		return "真气不足，需要%d点。" % int(action.cost)
	return ""


func _utility_reason(actor: Dictionary, action: Dictionary) -> String:
	if not _active:
		return "当前没有进行中的战斗。"
	if _locked:
		return "请待这一招收势。"
	if actor.is_empty() or actor.hp <= 0:
		return "请先选择仍站立的角色。"
	if action.is_empty() or action.id not in ["item", "flee"]:
		return "平击自动进行；请选择技能、药品或退避。"
	if action.id == "item":
		if int(actor.medicine_round) == _round:
			return "这位角色本轮已经用过药。"
		if _medicine <= 0:
			return "共享行囊中没有回春散了。"
		if actor.hp >= actor.max_hp:
			return "气血充盈，无需用药。"
	return ""


func _describe(actor: Dictionary, action: Dictionary, target_id: String) -> String:
	if CATEGORIES.has(String(action.get("category", ""))):
		var text: String = String(action.description)
		if not bool(action.get("learned", false)):
			return text
		if action.category == "martial":
			text = super._describe(actor, action, target_id)
			var marker: int = text.rfind("；耗")
			if marker >= 0:
				text = text.left(marker)
		return "%s；耗%d真气，调息%d个完整后续回合；第%d轮可用。排在本人下一次自动平击前，技能不消耗平击次数。" % [text, int(action.cost), int(action.cooldown), _eligible_round(actor, action)]
	return super._describe(actor, action, target_id)


func _rejected(reason: String) -> Dictionary:
	return Catalog.immutable({"ok": false, "accepted": false, "queued": false, "reason": reason, "token": -1})
