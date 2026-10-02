extends SceneTree
## Pure rule checks: no load/save calls and no real player save directory.
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/heting_receipt_combat.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Run heting_receipt_combat_test.gd with an isolated XDG_DATA_HOME")
		quit(2)
		return
	_test_configuration_and_arts()
	_test_target_roles()
	_test_atomic_transactions()
	_test_resources_and_proficiency()
	_test_target_local_effects()
	_test_companions()
	_test_natural_outcomes()
	if failures == 0:
		print("PASS: %d Heting receipt combat checks (real resources/ten arts/targets/transactions/proficiency/companions/outcomes)" % checks)
	else:
		push_error("FAIL: %d of %d Heting receipt combat checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _source(id: String = Arts.BASE_ART):
	var state = State.new()
	var school: String = String(Arts.definition(id).sect)
	if not school.is_empty():
		state.choose_sect(school)
	state.sect_rank = 2
	for candidate: String in Arts.available_for(school):
		if Advanced.is_advanced(candidate):
			state.learned_arts.append(candidate)
	state.equip_art(id)
	state.art_uses[id] = 15
	state.attack = 16
	state.defense = 4
	state.max_hp = 240
	state.hp = 230
	state.max_qi = 8
	state.qi = 8
	state.medicine = 2
	# Existing single-enemy transients must neither leak into this encounter nor
	# be rewritten by this detached module.
	state.turn = 17
	state.skill_cooldown = 2
	state.focused_damage = 51
	state.enemy_weaken_amount = 8
	state.enemy_weaken_strikes = 2
	state._companion_attack_count = 3
	state.battle_log.assign(["真实行程不可被模型直接改变"])
	return state


func _arena(state):
	var rules = Rules.new()
	check(rules.configure(state), "Living source configures a fresh real encounter")
	return rules


func _source_snapshot(state) -> Dictionary:
	var variables: Dictionary = {}
	for property: Dictionary in state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = state.get(String(property.name))
			variables[String(property.name)] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"save": state.to_dict().duplicate(true), "variables": variables}


func _step(rules, action: String) -> Dictionary:
	var transaction: Dictionary = rules.accept_action(action)
	check(transaction.ok, "Legal fixture action accepted: " + action)
	if transaction.ok:
		check(rules.complete_presentation(int(transaction.token)), "Accepted presentation completes once")
	return transaction


func _test_configuration_and_arts() -> void:
	for id: String in Arts.all_ids():
		var source = _source(id)
		var original: Dictionary = _source_snapshot(source)
		var rules = _arena(source)
		var definition: Dictionary = Arts.definition(id)
		check(rules.hp == 230 and rules.qi == 8 and rules.medicine == 2 and rules.skill_cooldown == 0 and rules.focused_damage == 0, "Uses actual resources and fresh encounter transients: " + id)
		check(rules.hero_snapshot.is_read_only() and rules.hero_snapshot.art_uses.is_read_only() and rules.skill_definition().is_read_only() and rules.art_rank == 3, "Captured loadout and definition are immutable: " + id)
		check(rules.hero_snapshot.equipment == source.equipment and rules.hero_snapshot.armor == source.armor and rules.attack == source.attack and rules.defense == source.defense, "Copies equipped stats without recomputing or stacking gear: " + id)
		rules.select_target("bracer")
		var preview: String = rules.action_description("skill")
		var tx: Dictionary = _step(rules, "skill")
		var expected: int = Advanced.direct_damage(definition, 16, 3)
		check(tx.hero_damage == expected and tx.heal == mini(10, int(definition.healing)) and tx.hero_qi_delta == -int(definition.cost) and rules.skill_cooldown == int(definition.cooldown), "Actual art damage/heal/cost/cooldown: " + id)
		check(preview.contains("造成%d伤害" % expected) and preview.contains("耗%d真气" % int(definition.cost)) and tx.guarded == bool(definition.guard), "Preview agrees with accepted art: " + id)
		check(rules.focused_damage == Advanced.focus_damage(definition, 16) and rules.units[1].weaken_amount == int(definition.weaken_amount) and rules.units[1].weaken_strikes == int(definition.weaken_strikes), "Catalog focus and target-local weaken: " + id)
		check(tx.before.art_uses[id] == 15 and tx.after.art_uses[id] == 16 and rules.snapshot().art_uses[id] == 16, "Accepted art use appears in immutable snapshots: " + id)
		check(_source_snapshot(source) == original, "No HeroState mutation, including resources/proficiency/transients: " + id)
	var source = _source("续灯引锋")
	source.hp = 47
	source.qi = 1
	source.medicine = 0
	source.companion_unlocked = true
	source.active_companion = "沈青"
	source.shen_care_stage = 5
	source.shen_care_choice = "mobile"
	var rules = _arena(source)
	var captured: Dictionary = rules.snapshot()
	source.attack = 999
	source.max_hp = 999
	source.art_uses["续灯引锋"] = 0
	source.formation = "护后"
	source.shen_care_choice = "shore"
	check(rules.snapshot() == captured and rules.hp == 47 and rules.qi == 1 and rules.medicine == 0 and rules.hero_snapshot.mobile_heal == 2, "Injuries, low qi, no medicine, and later source edits remain detached")
	check(not rules.configure(source) and rules.snapshot() == captured and not rules.has_method("reset") and not rules.has_method("retry"), "No repeated configure reset or free retry API")
	var reference: WeakRef = weakref(source)
	source = null
	check(reference.get_ref() == null, "Model retains no HeroState reference")
	var empty = Rules.new()
	var prior: Dictionary = empty.snapshot()
	check(not empty.configure(null) and empty.snapshot() == prior and not empty.accept_action("attack").ok, "Null configuration and unconfigured action are atomic no-ops")
	var downed = _source()
	downed.hp = 0
	check(not empty.configure(downed) and empty.snapshot() == prior, "Zero real HP cannot start a free revived encounter")
	var fallback_source = _source()
	fallback_source.equipped_art = "unknown"
	check(_arena(fallback_source).equipped_art == Arts.BASE_ART, "Unknown equipped art uses legal base art")
	var unlearned = _source("回潮断浪")
	unlearned.equipped_art = "伏汐藏锋"
	unlearned.learned_arts.clear()
	check(_arena(unlearned).equipped_art == Arts.BASE_ART, "Unlearned equipped art cannot bypass availability")


func _test_target_roles() -> void:
	var striker = _arena(_source())
	var bracer = _arena(_source())
	check(striker.units[0].name == "截签刀客" and striker.units[1].name == "架刀护手" and striker.units[0].hp == 190 and striker.units[1].hp == 110, "Provisional named opponents and HP are explicit")
	bracer.select_target("bracer")
	var strike: Dictionary = _step(striker, "attack")
	var brace: Dictionary = _step(bracer, "attack")
	check(strike.hero_damage == 8 and brace.hero_damage == 16 and strike.target_id == "striker" and brace.target_id == "bracer", "Protector halves each striker hit, never its own hits")
	check(strike.counters.size() == 1 and strike.counters[0].unit_id == "striker" and strike.counter_damage == 18 and not strike.counters[0].heavy, "First announced base-22 strike is the only counter")
	check(striker.units[0].intent_data.damage == 34 and striker.units[0].intent_data.heavy and striker.units[1].intent_data.kind == "protect", "Next heavy base-34 strike and protected role are announced")
	bracer.units[1].hp = 1
	var finish: Dictionary = bracer.accept_action("attack")
	check(finish.hero_damage == 1 and finish.after.units[0].hp == Rules.STRIKER_HP and bracer.selected_id == "bracer" and not bracer.units[0].brace, "Overkill does not spill or move presentation target")
	bracer.complete_presentation(int(finish.token))
	check(bracer.selected_id == "striker" and _step(bracer, "attack").hero_damage == 16, "Survivor selected after presentation with brace removed")
	striker.units[0].hp = 1
	var striker_finish: Dictionary = striker.accept_action("attack")
	check(striker_finish.counter_damage == 0 and striker_finish.counters.is_empty() and striker.units[1].intent_data.damage == 14, "Fallen striker cannot counter; protector never invents a same-turn solo attack")
	striker.complete_presentation(int(striker_finish.token))
	var solo: Dictionary = _step(striker, "guard")
	check(solo.counters.size() == 1 and solo.counters[0].unit_id == "bracer" and not solo.counters[0].heavy and solo.counter_damage == 3, "Previously announced solo base-14 attack follows next turn")
	var prior: Dictionary = bracer.snapshot()
	check(not bracer.select_target("missing") and not bracer.select_target("bracer") and bracer.snapshot() == prior, "Unknown/downed target selection changes nothing")
	bracer.selected_id = "missing"
	prior = bracer.snapshot()
	check(not bracer.accept_action("attack").ok and not bracer.accept_action("skill").ok and bracer.snapshot() == prior, "Invalid offensive target consumes no resource/turn")
	bracer.selected_id = "bracer"
	prior = bracer.snapshot()
	check(not bracer.accept_action("attack").ok and bracer.snapshot() == prior, "Dead offensive target is a no-op")
	var cycle = _arena(_source())
	check(cycle.cycle_target() and cycle.selected_id == "bracer" and cycle.cycle_target() and cycle.selected_id == "striker", "Cycle visits each living opponent")
	check(cycle.selected_unit().is_read_only(), "Selected unit is a detached immutable view")


func _test_atomic_transactions() -> void:
	var rules = _arena(_source())
	var prior: Dictionary = rules.snapshot()
	check(not rules.accept_action("unknown").ok and rules.snapshot() == prior, "Unknown action is atomic")
	var tx: Dictionary = rules.accept_action("attack")
	var resolved: Dictionary = rules.snapshot()
	check(tx.before == prior and tx.after == resolved and tx.is_read_only() and tx.before.units.is_read_only() and tx.before.units[0].is_read_only() and tx.after.art_uses.is_read_only() and tx.events.is_read_only() and tx.counters.is_read_only() and tx.counters[0].is_read_only(), "Transaction deeply freezes before/after/events/counters/proficiency")
	for key: String in ["ok", "accepted", "reason", "token", "action", "target_id", "before", "after", "hero_damage", "support_damage", "counter_damage", "heal", "support_heal", "qi_delta", "hero_qi_delta", "support_qi", "guarded", "counters", "events", "logs"]:
		check(tx.has(key), "Courtyard animation transaction key retained: " + key)
	check(tx.events[0].kind == "hero" and tx.events[0].target_id == "striker" and tx.events[1].kind == "counter" and tx.events[1].target_id == "hero", "Hero/counter animation contract and order retained")
	check(not rules.accept_action("flee").ok and not rules.accept_action("attack").ok and not rules.select_target("bracer") and not rules.cycle_target() and not rules.configure(_source()) and rules.snapshot() == resolved, "Pending presentation blocks reentry, exit, target changes, and reconfiguration")
	check(not rules.complete_presentation(int(tx.token) + 100) and rules.snapshot() == resolved, "Wrong token does not unlock or change state")
	check(rules.complete_presentation(int(tx.token)) and not rules.complete_presentation(int(tx.token)), "Valid token completes exactly once")
	var second: Dictionary = rules.accept_action("guard")
	resolved = rules.snapshot()
	check(second.token != tx.token and not rules.complete_presentation(int(tx.token)) and rules.snapshot() == resolved, "Stale token cannot complete a newer turn")
	check(tx.after.turn == 1 and tx.after.units[0].hp == 182 and second.after.turn == 2, "Previously returned facts stay detached across later turns")
	rules.complete_presentation(int(second.token))


func _test_resources_and_proficiency() -> void:
	for school: String in ["未入门", "照野堂"]:
		var source = _source("青灯续脉" if school == "照野堂" else Arts.BASE_ART)
		source.hp = 100
		source.qi = 1
		source.medicine = 1
		var rules = _arena(source)
		var prior: Dictionary = rules.snapshot()
		check(not rules.accept_action("skill").ok and rules.snapshot() == prior, "Insufficient real qi is atomic: " + school)
		var healing: int = 55 if school == "照野堂" else 45
		check(rules.action_description("item").contains("恢复%d气血" % healing), "Medicine preview reflects school bonus: " + school)
		var used: Dictionary = _step(rules, "item")
		check(used.heal == healing and used.after.medicine == 0 and used.counter_damage == 18 and used.after.hp == 100 + healing - 18 and used.after.qi == 1, "One real medicine heals before announced counter: " + school)
		prior = rules.snapshot()
		check(not rules.accept_action("item").ok and rules.snapshot() == prior, "No free medicine when bag is empty: " + school)
		check(source.medicine == 1 and source.hp == 100 and source.qi == 1, "Owner, not detached model, commits medicine/resource changes: " + school)
	var full_source = _source()
	full_source.hp = full_source.max_hp
	var full = _arena(full_source)
	var prior: Dictionary = full.snapshot()
	check(not full.accept_action("item").ok and full.snapshot() == prior, "Full-health medicine is rejected without spending anything")
	var capped: Dictionary = _step(full, "attack")
	check(capped.hero_qi_delta == 0 and capped.qi_delta == 0 and capped.logs[0].contains("回复0真气"), "At qi cap transaction and log report zero gain")
	for start_uses: int in [4, 14, 9999]:
		var source = _source()
		source.art_uses[Arts.BASE_ART] = start_uses
		source.art_uses["回潮断浪"] = 8
		var rules = _arena(source)
		rules.select_target("bracer")
		var old_rank: int = 1 if start_uses == 4 else (2 if start_uses == 14 else 3)
		var next_rank: int = mini(3, old_rank + 1)
		var skill: Dictionary = _step(rules, "skill")
		check(skill.hero_damage == Advanced.direct_damage(Arts.definition(Arts.BASE_ART), 16, old_rank) and skill.before.art_rank == old_rank and skill.after.art_rank == next_rank, "Threshold-crossing skill uses pre-use rank: %d" % start_uses)
		check(skill.after.art_uses[Arts.BASE_ART] == mini(9999, start_uses + 1) and skill.after.art_uses["回潮断浪"] == 8, "Only accepted equipped skill gains one capped use: %d" % start_uses)
		prior = rules.snapshot()
		check(not rules.accept_action("skill").ok and rules.snapshot() == prior, "Cooldown rejection cannot grant proficiency")
		_step(rules, "guard")
		_step(rules, "guard")
		check(rules.skill_cooldown == 0 and rules.art_uses[Arts.BASE_ART] == mini(9999, start_uses + 1), "Only accepted non-skills reduce cooldown; they grant no uses")
		var next: Dictionary = _step(rules, "skill")
		check(next.hero_damage == Advanced.direct_damage(Arts.definition(Arts.BASE_ART), 16, next_rank), "Next skill sees newly earned rank: %d" % start_uses)
		check(source.art_uses[Arts.BASE_ART] == start_uses, "Detached proficiency never mutates source")


func _test_target_local_effects() -> void:
	var focus = _arena(_source("伏汐藏锋"))
	var skill: Dictionary = _step(focus, "skill")
	check(skill.hero_qi_delta == -4 and focus.skill_cooldown == 3 and focus.focused_damage == 34, "Focus skill spends real catalog cost and establishes bonus")
	var next: Dictionary = _step(focus, "attack")
	check(next.hero_damage == 25 and focus.focused_damage == 0 and focus.skill_cooldown == 2 and next.hero_qi_delta == 2, "Next attack consumes focus before per-hit brace rounding")
	var weaken = _arena(_source("石隙封腕"))
	var lowered: Dictionary = _step(weaken, "skill")
	check(lowered.counter_damage == 10 and weaken.units[0].weaken_amount == 8 and weaken.units[0].weaken_strikes == 1 and weaken.units[1].weaken_strikes == 0, "Selected striker alone weakens, consuming one actual strike")
	var guarded: Dictionary = _step(weaken, "guard")
	check(guarded.counter_damage == 7 and weaken.units[0].weaken_amount == 0 and weaken.units[0].weaken_strikes == 0, "Weaken precedes guard rounding and expires on its second attack")
	var stored = _arena(_source("石隙封腕"))
	stored.select_target("bracer")
	_step(stored, "skill")
	_step(stored, "guard")
	check(stored.units[1].weaken_strikes == 2 and stored.units[0].weaken_strikes == 0, "Protected unit retains its own weaken while striker acts")
	stored.select_target("striker")
	stored.units[0].hp = 1
	var kill: Dictionary = _step(stored, "attack")
	check(kill.counter_damage == 0 and stored.units[1].weaken_strikes == 2, "Killing striker neither triggers nor consumes protector's unannounced attack")
	var solo: Dictionary = _step(stored, "guard")
	check(solo.counter_damage == 1 and stored.units[1].weaken_strikes == 1, "Solo protector consumes stored weaken on its actual attack")
	var escape: Dictionary = _step(stored, "flee")
	check(escape.counter_damage == 0 and stored.focused_damage == 0 and stored.units[1].weaken_strikes == 0 and stored.units[1].weaken_amount == 0, "Terminal flee clears transient effects without counter")


func _test_companions() -> void:
	for companion: String in ["", "沈青", "唐栖"]:
		for formation: String in ["并肩", "护后"]:
			var source = _source()
			source.qi = 1
			source.companion_unlocked = companion == "沈青"
			source.tangqi_unlocked = companion == "唐栖"
			source.active_companion = companion
			source.formation = formation
			source.shen_care_stage = 5
			source.shen_care_choice = "mobile"
			var original: Dictionary = _source_snapshot(source)
			var rules = _arena(source)
			rules.select_target("bracer")
			var first: Dictionary = _step(rules, "attack")
			_step(rules, "guard")
			_step(rules, "item")
			var second: Dictionary = _step(rules, "attack")
			var assisting: bool = not companion.is_empty() and formation == "并肩"
			var support: int = (4 if companion == "唐栖" else 7) if assisting else 0
			check(first.support_damage == 0 and second.support_damage == support and rules.snapshot().support_count == (2 if assisting else 0), "Only offensive actions advance every-second assist: %s/%s" % [companion, formation])
			check(second.support_qi == (1 if assisting and companion == "唐栖" else 0) and second.support_heal == (2 if assisting and companion == "沈青" else 0), "Companion-specific actual heal/qi benefits: %s/%s" % [companion, formation])
			if assisting:
				check(second.events.size() == 3 and second.events[0].kind == "hero" and second.events[1].kind == "support" and second.events[2].kind == "counter" and second.events[1].target_id == "bracer", "Hero/support/counter order and chosen-target lock: " + companion)
			check(_source_snapshot(source) == original, "Companion effects do not mutate source: %s/%s" % [companion, formation])
	for companion: String in ["沈青", "唐栖"]:
		var source = _source()
		source.companion_unlocked = true
		source.tangqi_unlocked = true
		source.active_companion = companion
		source.shen_care_stage = 5
		source.shen_care_choice = "mobile"
		var rules = _arena(source)
		rules.select_target("bracer")
		_step(rules, "attack")
		rules.units[1].hp = 1
		var hero_kill: Dictionary = _step(rules, "attack")
		check(hero_kill.hero_damage == 1 and hero_kill.support_damage == 0 and hero_kill.support_qi == 0 and hero_kill.support_heal == 0 and hero_kill.after.units[0].hp == Rules.STRIKER_HP and hero_kill.events.size() == 2, "Hero target kill suppresses assist and its benefits without spill: " + companion)
		var support_kill = _arena(source)
		support_kill.select_target("bracer")
		_step(support_kill, "attack")
		support_kill.units[1].hp = 18
		var assist: Dictionary = _step(support_kill, "attack")
		check(assist.support_damage == 2 and assist.after.units[1].hp == 0 and assist.after.units[0].hp == Rules.STRIKER_HP, "Assist overkill caps at selected HP without spill: " + companion)
		source.formation = "护后"
		source.shen_care_choice = "shore"
		var cover = _arena(source)
		var light: Dictionary = _step(cover, "attack")
		var heavy: Dictionary = _step(cover, "attack")
		check(light.counter_damage == (15 if companion == "沈青" else 18) and heavy.counter_damage == (27 if companion == "沈青" else 25) and heavy.support_damage == 0, "Shore/companion cover applies to appropriate light/heavy strikes: " + companion)
		_step(cover, "guard")
		var guarded: Dictionary = _step(cover, "guard")
		check(guarded.counter_damage == (6 if companion == "沈青" else 4) and guarded.counters[0].unguarded_damage == 30 and guarded.counters[0].cover == (3 if companion == "沈青" else 5), "Guard rounds before cover reduction: " + companion)
		source.defense = 100
		var floor_rules = _arena(source)
		_step(floor_rules, "guard")
		var floor_hit: Dictionary = _step(floor_rules, "guard")
		check(floor_hit.counter_damage == 1 and floor_hit.counters[0].cover == 0, "Guard and cover preserve one-damage minimum and report actual cover: " + companion)
	var odd_source = _source()
	odd_source.attack = 15
	odd_source.companion_unlocked = true
	var odd = _arena(odd_source)
	_step(odd, "attack")
	var rounded: Dictionary = _step(odd, "attack")
	check(rounded.hero_damage == 8 and rounded.support_damage == 4, "Brace independently rounds each odd player/companion hit upward")


func _test_natural_outcomes() -> void:
	for ending: String in ["win", "defeat", "flee"]:
		var source = _source("青灯息争")
		source.coins = 77
		source.xp = 33
		source.victories = 6
		source.resources.herb = 9
		if ending == "defeat":
			source.hp = 2
		var original: Dictionary = _source_snapshot(source)
		var rules = _arena(source)
		var result: Dictionary = {}
		if ending == "win":
			# Ordinary accepted actions only; do not inject enemy HP, qi, medicine,
			# rank, damage, or battle transients during the route.
			rules.select_target("bracer")
			for action_index: int in 80:
				if not rules.active:
					break
				var action: String = "attack"
				if rules.hp < 65 and rules.medicine > 0:
					action = "item"
				elif rules.action_unavailable_reason("skill").is_empty():
					action = "skill"
				result = _step(rules, action)
		elif ending == "defeat":
			result = _step(rules, "attack")
		else:
			_step(rules, "skill")
			_step(rules, "item")
			var spent: Dictionary = rules.snapshot()
			result = _step(rules, "flee")
			check(result.after.hp == spent.hp and result.after.qi == spent.qi and result.after.medicine == spent.medicine and result.after.art_uses == spent.art_uses, "Flee preserves previously spent real resources and earned uses")
		check(not rules.active and rules.outcome == ending and result.after.outcome == ending, "Legal terminal route reached: " + ending)
		check((rules.hp == 0 and result.counter_damage == 2) if ending == "defeat" else true, "Defeat counter reports clamped actual HP damage")
		check(result.counter_damage == 0 if ending == "flee" else true, "Flee never receives a counter")
		var terminal: Dictionary = rules.snapshot()
		check(not rules.accept_action("attack").ok and not rules.select_target("striker") and not rules.configure(source) and rules.snapshot() == terminal, "Terminal model cannot act, reselect, or revive itself: " + ending)
		check(rules.focused_damage == 0 and rules.units[0].weaken_strikes == 0 and rules.units[1].weaken_strikes == 0, "Terminal cleanup removes encounter effects: " + ending)
		check(_source_snapshot(source) == original, "Model never settles XP/coins/victories/resources/progression itself: " + ending)
