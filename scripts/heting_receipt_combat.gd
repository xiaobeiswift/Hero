class_name HetingReceiptCombat
extends RefCounted
## Detached real combat for 鹤汀余事·复签不撤. Configure once from current
## resources; the owner commits accepted snapshots and settles the outcome.
## Never retains/mutates HeroState, awards rewards, or offers a free retry.
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
## Provisional encounter tuning, pending continuous-play balance review.
const STRIKER_HP: int = 190
const BRACER_HP: int = 110
const ACTIONS: Array[String] = ["attack", "skill", "guard", "item", "flee"]

var units: Array[Dictionary] = []
var hp: int = 0
var max_hp: int = 0
var qi: int = 0
var max_qi: int = 0
var medicine: int = 0
var medicine_heal: int = 45
var skill_cooldown: int = 0
var turn: int = 0
var selected_id: String = ""
var active: bool = false
var outcome: String = ""
var locked: bool = false
var attack: int = 0
var defense: int = 0
var equipped_art: String = Arts.BASE_ART
var art_rank: int = 1
var art_uses: Dictionary = {}
var companion: String = ""
var formation: String = "并肩"
var focused_damage: int = 0
var battle_log: Array[String] = []
var hero_snapshot: Dictionary = {}
var _definition: Dictionary = {}
var _support_count: int = 0
var _token_serial: int = 0
var _pending_token: int = -1


func configure(hero_state) -> bool:
	if hero_state == null or not hero_snapshot.is_empty() or int(hero_state.hp) <= 0:
		return false
	var art: String = String(hero_state.equipped_art)
	if not hero_state.available_arts().has(art) or not Arts.has_art(art):
		art = Arts.BASE_ART
	hero_snapshot = _immutable({
		"player_name": String(hero_state.player_name), "sect": String(hero_state.sect),
		"max_hp": maxi(1, int(hero_state.max_hp)), "max_qi": maxi(0, int(hero_state.max_qi)),
		"source_hp": int(hero_state.hp), "source_qi": int(hero_state.qi),
		"source_medicine": maxi(0, int(hero_state.medicine)),
		"medicine_heal": 55 if String(hero_state.sect) == "照野堂" else 45,
		"attack": maxi(1, int(hero_state.attack)), "defense": maxi(0, int(hero_state.defense)),
		"equipped_art": art, "art_rank": int(hero_state.art_rank(art)),
		"equipment": String(hero_state.equipment), "armor": String(hero_state.armor),
		"art_uses": hero_state.art_uses.duplicate(true),
		"companion": String(hero_state.current_companion()),
		"formation": String(hero_state.formation),
		"shore_bonus": int(hero_state.ShenCare.shore_bonus(hero_state)),
		"mobile_heal": int(hero_state.ShenCare.mobile_heal(hero_state)),
	})
	_definition = Arts.definition(art)
	_token_serial += 1
	_pending_token = -1
	locked = false
	max_hp = int(hero_snapshot.max_hp)
	max_qi = int(hero_snapshot.max_qi)
	hp = clampi(int(hero_snapshot.source_hp), 0, max_hp)
	qi = clampi(int(hero_snapshot.source_qi), 0, max_qi)
	attack = int(hero_snapshot.attack)
	defense = int(hero_snapshot.defense)
	equipped_art = String(hero_snapshot.equipped_art)
	art_uses = hero_snapshot.art_uses.duplicate(true)
	art_rank = _current_art_rank()
	companion = String(hero_snapshot.companion)
	formation = String(hero_snapshot.formation)
	medicine = int(hero_snapshot.source_medicine)
	medicine_heal = int(hero_snapshot.medicine_heal)
	skill_cooldown = 0
	turn = 0
	focused_damage = 0
	_support_count = 0
	active = true
	outcome = ""
	selected_id = "striker"
	units = [_new_unit("striker", "截签刀客", STRIKER_HP), _new_unit("bracer", "架刀护手", BRACER_HP)]
	battle_log.assign(["截签刀客与架刀护手拦住复签去路；当前气血、真气与回春散均按实计入。"])
	_refresh_units()
	return true


func select_target(id: String) -> bool:
	if locked or not active:
		return false
	var unit: Dictionary = _unit(id)
	if unit.is_empty() or int(unit.hp) <= 0:
		return false
	selected_id = id
	return true


func cycle_target() -> bool:
	if locked or not active:
		return false
	var start: int = -1
	for index: int in units.size():
		if units[index].id == selected_id:
			start = index
	for offset: int in range(1, units.size() + 1):
		var unit: Dictionary = units[posmod(start + offset, units.size())]
		if int(unit.hp) > 0:
			return select_target(String(unit.id))
	return false


func selected_unit() -> Dictionary:
	return _immutable(_unit(selected_id))


func skill_definition() -> Dictionary:
	return _definition


func snapshot() -> Dictionary:
	return _immutable({
		"units": units, "hp": hp, "max_hp": max_hp, "qi": qi, "max_qi": max_qi,
		"medicine": medicine, "medicine_heal": medicine_heal,
		"skill_cooldown": skill_cooldown, "turn": turn,
		"selected_id": selected_id, "active": active, "outcome": outcome,
		"locked": locked, "focused_damage": focused_damage, "support_count": _support_count,
		"attack": attack, "defense": defense, "equipped_art": equipped_art,
		"art_rank": art_rank, "art_uses": art_uses,
		"companion": companion, "formation": formation,
	})


func action_unavailable_reason(action: String) -> String:
	if locked:
		return "请待这一招收势。"
	if not active:
		return "当前没有进行中的复签战斗。"
	if not ACTIONS.has(action):
		return "招式无效。"
	if action in ["attack", "skill"]:
		var target: Dictionary = _unit(selected_id)
		if target.is_empty() or int(target.hp) <= 0:
			return "请先选中尚未倒下的对手。"
	if action == "skill":
		if skill_cooldown > 0:
			return "%s尚需调息%d回合。" % [equipped_art, skill_cooldown]
		if qi < int(_definition.cost):
			return "真气不足，需要%d点。" % int(_definition.cost)
	if action == "item":
		if medicine <= 0:
			return "行囊中没有回春散了。"
		if hp >= max_hp:
			return "气血充盈，无需用药。"
	return ""


func action_description(action: String) -> String:
	var target: Dictionary = _unit(selected_id)
	var target_name: String = String(target.get("name", "对手"))
	match action:
		"attack":
			return "对%s造成%d伤害，回复%d真气；平击消耗已有蓄锋。" % [target_name, _outgoing(target, attack + focused_damage), mini(2, max_qi - qi)]
		"skill":
			if _definition.is_empty():
				return "尚未进入复签战斗。"
			var effects: Array[String] = ["对%s造成%d伤害" % [target_name, _outgoing(target, Advanced.direct_damage(_definition, attack, art_rank))]]
			if int(_definition.healing) > 0:
				effects.append("恢复%d气血" % mini(max_hp - hp, int(_definition.healing)))
			if bool(_definition.guard):
				effects.append("本回合来袭伤害乘三成并向上取整，至少1点")
			if int(_definition.weaken_amount) > 0:
				effects.append("仅所选对手基础伤害-%d，持续其%d次攻击" % [int(_definition.weaken_amount), int(_definition.weaken_strikes)])
			var focus: int = Advanced.focus_damage(_definition, attack)
			if focus > 0:
				effects.append("蓄锋：下一次平击额外+%d" % focus)
			return "%s；耗%d真气，调息%d回合。" % ["；".join(effects), int(_definition.cost), int(_definition.cooldown)]
		"guard":
			return "回复%d真气；本回合来袭伤害乘三成并向上取整，至少1点。" % mini(1, max_qi - qi)
		"item":
			return "回春散恢复%d气血（最多%d），余%d份；对手照常行动。" % [mini(max_hp - hp, medicine_heal), medicine_heal, medicine]
		"flee":
			return "立即脱离战斗，不受反击；已消耗的气血、真气与回春散不会返还。"
	return ""


func accept_action(action: String) -> Dictionary:
	var reason: String = action_unavailable_reason(action)
	if not reason.is_empty():
		return _immutable({"ok": false, "accepted": false, "reason": reason, "token": -1})
	var before: Dictionary = snapshot()
	var target: Dictionary = _unit(selected_id)
	# Capture intentions now. A protector cannot unexpectedly attack in the turn
	# its partner falls; its new solo intention is announced for the next turn.
	var intentions: Array[Dictionary] = []
	for unit: Dictionary in units:
		intentions.append(unit.intent_data.duplicate(true))
	_token_serial += 1
	_pending_token = _token_serial
	locked = true
	var tx: Dictionary = {
		"ok": true, "accepted": true, "reason": "", "token": _pending_token,
		"action": action, "target_id": selected_id, "before": before,
		"hero_damage": 0, "support_damage": 0, "counter_damage": 0,
		"heal": 0, "support_heal": 0, "qi_delta": 0, "hero_qi_delta": 0,
		"support_qi": 0, "guarded": false, "counters": [], "events": [], "logs": [],
	}
	if action != "skill":
		skill_cooldown = maxi(0, skill_cooldown - 1)
	var guarded: bool = false
	match action:
		"attack":
			tx.hero_damage = _deal(target, attack + focused_damage)
			focused_damage = 0
			qi = mini(max_qi, qi + 2)
			tx.logs.append("平击命中%s，造成%d伤害，回复%d真气。" % [target.name, tx.hero_damage, qi - int(before.qi)])
		"skill":
			qi -= int(_definition.cost)
			skill_cooldown = int(_definition.cooldown)
			# This use earns proficiency only after its old-rank damage is resolved.
			var rank_before: int = art_rank
			tx.hero_damage = _deal(target, Advanced.direct_damage(_definition, attack, rank_before))
			tx.heal = _heal(int(_definition.healing))
			guarded = bool(_definition.guard)
			tx.logs.append("%s命中%s，造成%d伤害，消耗%d真气。" % [equipped_art, target.name, tx.hero_damage, int(_definition.cost)])
			if int(_definition.healing) > 0:
				tx.logs.append("招式恢复%d气血。" % tx.heal)
			if guarded:
				tx.logs.append("进入守势：本回合来袭伤害乘三成并向上取整，至少1点。")
			if int(target.hp) > 0 and int(_definition.weaken_amount) > 0:
				target.weaken_amount = maxi(int(target.weaken_amount), int(_definition.weaken_amount))
				target.weaken_strikes = maxi(int(target.weaken_strikes), int(_definition.weaken_strikes))
				tx.logs.append("%s卸劲：基础伤害-%d，持续其%d次攻击。" % [target.name, target.weaken_amount, target.weaken_strikes])
			focused_damage = maxi(focused_damage, Advanced.focus_damage(_definition, attack))
			if Advanced.focus_damage(_definition, attack) > 0:
				tx.logs.append("蓄锋：下一次平击额外+%d。" % focused_damage)
			art_uses[equipped_art] = mini(9999, clampi(int(art_uses.get(equipped_art, 0)), 0, 9999) + 1)
			art_rank = _current_art_rank()
			if art_rank > rank_before:
				tx.logs.append("%s熟练精进，已达%s。" % [equipped_art, Arts.rank_name(art_rank)])
		"guard":
			guarded = true
			qi = mini(max_qi, qi + 1)
			tx.logs.append("收势守中，回复%d真气；本回合来袭伤害乘三成并向上取整，至少1点。" % (qi - int(before.qi)))
		"item":
			medicine -= 1
			tx.heal = _heal(medicine_heal)
			tx.logs.append("服下回春散，恢复%d气血；余%d份。" % [tx.heal, medicine])
		"flee":
			active = false
			outcome = "flee"
			tx.logs.append("你收势退开，暂避锋芒；本次已经消耗的资源不会返还。")
	tx.hero_qi_delta = qi - int(before.qi)
	tx.guarded = guarded
	if action in ["attack", "skill"]:
		tx.events.append({"kind": "hero", "target_id": selected_id, "damage": tx.hero_damage, "heal": tx.heal, "qi_delta": tx.hero_qi_delta})
		_assist(target, tx)
	elif action in ["guard", "item"]:
		tx.events.append({"kind": action, "target_id": "hero", "heal": tx.heal, "qi_delta": tx.hero_qi_delta})
	turn += 1
	if active and _all_down():
		active = false
		outcome = "win"
		tx.logs.append("两名拦路者均已倒下，复签去路重开。")
	if active:
		for index: int in units.size():
			var unit: Dictionary = units[index]
			var intent: Dictionary = intentions[index]
			if int(unit.hp) <= 0 or String(intent.kind) != "attack" or hp <= 0:
				continue
			_counter(unit, intent, guarded, tx)
		if hp <= 0:
			active = false
			outcome = "defeat"
			tx.logs.append("你气血耗尽，未能闯过这场拦截。")
	if not active:
		focused_damage = 0
		for unit: Dictionary in units:
			unit.weaken_amount = 0
			unit.weaken_strikes = 0
	_refresh_units()
	tx.qi_delta = qi - int(before.qi)
	tx.after = snapshot()
	for line: String in tx.logs:
		battle_log.append(line)
	while battle_log.size() > 48:
		battle_log.pop_front()
	return _immutable(tx)


func complete_presentation(token: int) -> bool:
	if not locked or token != _pending_token:
		return false
	locked = false
	_pending_token = -1
	if active:
		var selected: Dictionary = _unit(selected_id)
		if selected.is_empty() or int(selected.hp) <= 0:
			cycle_target()
	return true


func _assist(target: Dictionary, tx: Dictionary) -> void:
	if companion.is_empty() or formation != "并肩":
		return
	_support_count += 1
	if _support_count % 2 != 0 or int(target.hp) <= 0:
		return
	tx.support_damage = _deal(target, 4 if companion == "唐栖" else 7)
	if companion == "唐栖":
		var before_qi: int = qi
		qi = mini(max_qi, qi + 1)
		tx.support_qi = qi - before_qi
	elif int(hero_snapshot.mobile_heal) > 0:
		tx.support_heal = _heal(int(hero_snapshot.mobile_heal))
	tx.logs.append("%s协击%s，造成%d伤害，恢复%d气血与%d真气。" % [companion, target.name, tx.support_damage, tx.support_heal, tx.support_qi])
	tx.events.append({"kind": "support", "target_id": selected_id, "damage": tx.support_damage, "heal": tx.support_heal, "qi_delta": tx.support_qi})


func _counter(unit: Dictionary, intent: Dictionary, guarded: bool, tx: Dictionary) -> void:
	var weaken: int = int(unit.weaken_amount) if int(unit.weaken_strikes) > 0 else 0
	var damage: int = maxi(1, int(intent.damage) - defense - weaken)
	var without_guard: int = damage
	if guarded:
		damage = maxi(1, int(ceil(float(damage) * 0.3)))
	var cover: int = 0
	if formation == "护后":
		if companion == "沈青":
			cover = 2 + int(hero_snapshot.shore_bonus)
		elif companion == "唐栖" and bool(intent.heavy):
			cover = 5
	var covered: int = damage - maxi(1, damage - cover)
	damage = mini(hp, maxi(1, damage - cover))
	hp -= damage
	if int(unit.weaken_strikes) > 0:
		unit.weaken_strikes -= 1
		if int(unit.weaken_strikes) == 0:
			unit.weaken_amount = 0
	var counter: Dictionary = {"unit_id": unit.id, "damage": damage, "heavy": intent.heavy, "guarded": guarded, "cover": covered, "unguarded_damage": without_guard}
	tx.counters.append(counter)
	tx.counter_damage += damage
	tx.events.append({"kind": "counter", "unit_id": unit.id, "target_id": "hero", "damage": damage, "heavy": intent.heavy, "cover": covered})
	tx.logs.append("%s使出%s，你受到%d伤害%s。" % [unit.name, intent.name, damage, "（%s护后减伤%d）" % [companion, covered] if covered > 0 else ""])


func _new_unit(id: String, title: String, health: int) -> Dictionary:
	return {"id": id, "name": title, "hp": health, "max_hp": health, "intent": "", "intent_data": {}, "brace": false, "weaken_amount": 0, "weaken_strikes": 0}


func _refresh_units() -> void:
	var striker_alive: bool = not _unit("striker").is_empty() and int(_unit("striker").hp) > 0
	var bracer_alive: bool = not _unit("bracer").is_empty() and int(_unit("bracer").hp) > 0
	for unit: Dictionary in units:
		unit.brace = unit.id == "striker" and striker_alive and bracer_alive
		if int(unit.hp) <= 0 or not active:
			unit.intent = "已停手"
			unit.intent_data = {"kind": "none", "name": "已停手", "damage": 0, "heavy": false}
		elif unit.id == "bracer" and striker_alive:
			unit.intent = "架刀护住截签刀客：其每次所受伤害减半（向上取整）；本轮不攻击"
			unit.intent_data = {"kind": "protect", "name": "架刀护伴", "damage": 0, "heavy": false}
		else:
			var heavy: bool = unit.id == "striker" and turn % 2 == 1
			var raw: int = (34 if heavy else 22) if unit.id == "striker" else 14
			var move_name: String = ("截签重斩" if heavy else "探刃截签") if unit.id == "striker" else "护手短斩"
			unit.intent_data = {"kind": "attack", "name": move_name, "damage": raw, "heavy": heavy}
			unit.intent = "%s · 基础伤害%d（再扣防御与卸劲）" % [move_name, raw]


func _unit(id: String) -> Dictionary:
	for unit: Dictionary in units:
		if unit.id == id:
			return unit
	return {}


func _outgoing(target: Dictionary, amount: int) -> int:
	if target.is_empty() or int(target.hp) <= 0:
		return 0
	var braced: bool = target.id == "striker" and int(_unit("bracer").get("hp", 0)) > 0
	var damage: int = maxi(1, int(ceil(float(amount) * 0.5))) if braced else maxi(0, amount)
	return mini(int(target.hp), damage)


func _deal(target: Dictionary, amount: int) -> int:
	var actual: int = _outgoing(target, amount)
	target.hp -= actual
	return actual


func _heal(amount: int) -> int:
	var actual: int = mini(max_hp - hp, maxi(0, amount))
	hp += actual
	return actual


func _all_down() -> bool:
	for unit: Dictionary in units:
		if int(unit.hp) > 0:
			return false
	return true


func _current_art_rank() -> int:
	var uses: int = clampi(int(art_uses.get(equipped_art, 0)), 0, 9999)
	return 3 if uses >= 15 else (2 if uses >= 5 else 1)


func _immutable(value: Dictionary) -> Dictionary:
	var copy: Dictionary = value.duplicate(true)
	_freeze(copy)
	return copy


func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for entry: Variant in value:
			_freeze(entry)
		value.make_read_only()
