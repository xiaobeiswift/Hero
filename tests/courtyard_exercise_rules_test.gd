extends SceneTree
## No load/save methods or filesystem writes. The runner still requires an
## isolated user-data directory so a future fixture cannot touch a real save.
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/courtyard_exercise_rules.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Run courtyard_exercise_rules_test.gd with an isolated XDG_DATA_HOME")
		quit(2)
		return
	_test_snapshot_and_arts()
	_test_target_choice()
	_test_atomic_presentation()
	_test_support_order()
	_test_resources_and_effects()
	_test_companion_cover()
	_test_outcomes_and_no_rewards()
	if failures == 0:
		print("PASS: %d courtyard exercise rule checks (snapshot/targets/transactions/arts/companions/outcomes)" % checks)
	else:
		push_error("FAIL: %d of %d courtyard exercise rule checks" % [failures, checks])
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
	state.hp = 47
	state.max_qi = 8
	state.qi = 1
	state.medicine = 0
	# Transient values must be as untouched as the serialized progression.
	state.turn = 17
	state.skill_cooldown = 2
	state.focused_damage = 51
	state.enemy_weaken_amount = 8
	state.enemy_weaken_strikes = 2
	state._companion_attack_count = 3
	state._trial_art_used = true
	state._trial_healing = 23
	state._trial_guarded_heavy = true
	state.battle_log.assign(["真实行程不可改变"])
	return state


func _arena(state):
	var rules = Rules.new()
	# These legacy exercise fixtures encode selection with old companion
	# fields. Migrate a detached copy before configuring their old model.
	var migrated = state._detached_persistent_state()
	migrated._apply_party_plan(state.PartyRoster.load_plan(migrated, {"active_companion": state.active_companion}, 11))
	rules.configure(migrated)
	return rules


func _source_snapshot(state) -> Dictionary:
	var transient: Dictionary = {}
	for property: Dictionary in state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = state.get(String(property.name))
			transient[String(property.name)] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"save": state.to_dict().duplicate(true), "all_variables": transient}


func _step(rules, action: String) -> Dictionary:
	var transaction: Dictionary = rules.accept_action(action)
	if transaction.ok:
		rules.complete_presentation(int(transaction.token))
	return transaction


func _test_snapshot_and_arts() -> void:
	for id: String in Arts.all_ids():
		var source = _source(id)
		var original: Dictionary = _source_snapshot(source)
		var rules = _arena(source)
		var definition: Dictionary = Arts.definition(id)
		check(rules.hero_snapshot.is_read_only() and rules.hero_snapshot.art_uses.is_read_only() and rules.equipped_art == id and rules.art_rank == 3, "Frozen loadout and proficiency: " + id)
		check(rules.hp == source.max_hp and rules.qi == source.max_qi and rules.medicine == 3 and rules.skill_cooldown == 0 and rules.focused_damage == 0, "Fresh virtual resources ignore injured real hero: " + id)
		rules.hp -= 10
		rules.select_target("bracer")
		var preview: String = rules.action_description("skill")
		var tx: Dictionary = rules.accept_action("skill")
		var expected_damage: int = mini(Rules.BRACER_HP, Advanced.direct_damage(definition, 16, 3))
		check(tx.ok and tx.hero_damage == expected_damage and tx.heal == mini(10, int(definition.healing)) and tx.hero_qi_delta == -int(definition.cost) and rules.skill_cooldown == int(definition.cooldown), "Actual damage/heal/cost/cooldown reuse catalog: " + id)
		check(preview.contains("造成%d伤害" % expected_damage) and preview.contains("耗%d真气" % int(definition.cost)) and preview.contains("调息%d回合" % int(definition.cooldown)) and tx.guarded == bool(definition.guard), "Displayed skill facts agree: " + id)
		check(rules.focused_damage == Advanced.focus_damage(definition, 16) and rules.units[1].weaken_amount == int(definition.weaken_amount) and rules.units[1].weaken_strikes == int(definition.weaken_strikes), "Per-target weaken and focus match catalog: " + id)
		rules.complete_presentation(int(tx.token))
		check(_source_snapshot(source) == original, "All serialized and transient HeroState values unchanged: " + id)
	var source = _source("续灯引锋")
	source.companion_unlocked = true
	source.active_companion = "沈青"
	source.shen_care_stage = 5
	source.shen_care_choice = "mobile"
	var rules = _arena(source)
	var frozen: Dictionary = rules.hero_snapshot.duplicate(true)
	source.attack = 999
	source.max_hp = 999
	source.art_uses["续灯引锋"] = 0
	source.formation = "护后"
	source.shen_care_choice = "shore"
	check(rules.hero_snapshot == frozen and rules.hero_snapshot.art_uses["续灯引锋"] == 15, "Source mutations cannot change the detached deep snapshot")
	rules.reset()
	check(rules.attack == 16 and rules.max_hp == 240 and rules.art_rank == 3 and rules.formation == "并肩" and rules.hero_snapshot.mobile_heal == 2, "Retry restores the captured configuration, including companion branch")
	var unsupported = _source()
	unsupported.equipped_art = "unknown"
	var fallback = _arena(unsupported)
	check(fallback.equipped_art == Arts.BASE_ART and fallback.skill_definition().cost == 3, "Invalid equipped art safely uses the existing base art")


func _test_target_choice() -> void:
	var source = _source()
	var striker = _arena(source)
	var bracer = _arena(source)
	bracer.select_target("bracer")
	var strike: Dictionary = _step(striker, "attack")
	var brace: Dictionary = _step(bracer, "attack")
	check(strike.hero_damage == 8 and brace.hero_damage == 16 and strike.target_id == "striker" and brace.target_id == "bracer", "Target choice changes real damage; bracer never protects itself")
	check(strike.counters.size() == 1 and strike.counters[0].unit_id == "striker" and strike.counter_damage == 10 and not strike.counters[0].heavy, "Only the announced light striker acts in the first turn")
	check(striker.units[0].intent_data.heavy and striker.units[0].intent_data.damage == 24 and striker.units[1].intent_data.kind == "protect", "Next heavy strike and protective role are readable")
	bracer.units[1].hp = 1
	var finish: Dictionary = bracer.accept_action("attack")
	check(finish.hero_damage == 1 and finish.after.units[0].hp == Rules.STRIKER_HP and bracer.selected_id == "bracer" and not bracer.units[0].brace, "Bracer overkill is capped and never spills; current target remains during presentation")
	bracer.complete_presentation(int(finish.token))
	check(bracer.selected_id == "striker" and _step(bracer, "attack").hero_damage == 16, "Finishing bracer removes protection and selects survivor only after presentation")
	striker.units[0].hp = 1
	var striker_finish: Dictionary = striker.accept_action("attack")
	check(striker_finish.counter_damage == 0 and striker_finish.counters.is_empty() and striker.units[1].intent_data.damage == 10, "Fallen striker cannot counter and protector does not invent an unannounced solo attack")
	striker.complete_presentation(int(striker_finish.token))
	var solo: Dictionary = _step(striker, "guard")
	check(solo.counters.size() == 1 and solo.counters[0].unit_id == "bracer" and not solo.counters[0].heavy and solo.counter_damage == 2, "Announced solo bracer attacks weakly on the following action")
	var prior: Dictionary = bracer.snapshot()
	check(not bracer.select_target("missing") and not bracer.select_target("bracer") and bracer.snapshot() == prior, "Unknown and defeated targets are rejected without changes")
	bracer.selected_id = "missing"
	prior = bracer.snapshot()
	check(not bracer.accept_action("attack").ok and not bracer.accept_action("skill").ok and bracer.snapshot() == prior, "Invalid offensive target cannot consume a turn or resource")
	bracer.selected_id = "bracer"
	prior = bracer.snapshot()
	check(not bracer.accept_action("attack").ok and bracer.snapshot() == prior, "A dead target cannot receive a queued hit")
	var cycle = _arena(source)
	check(cycle.cycle_target() and cycle.selected_id == "bracer" and cycle.cycle_target() and cycle.selected_id == "striker", "Cycle selection visits each living opponent")


func _test_atomic_presentation() -> void:
	var source = _source()
	var rules = _arena(source)
	var prior: Dictionary = rules.snapshot()
	check(not rules.accept_action("unknown").ok and rules.snapshot() == prior, "Invalid action is a no-op")
	var tx: Dictionary = rules.accept_action("attack")
	var resolved: Dictionary = rules.snapshot()
	check(tx.before == prior and tx.after == resolved and tx.is_read_only() and tx.before.units.is_read_only() and tx.before.units[0].is_read_only() and tx.events.is_read_only(), "Transaction snapshots and presentation facts are deeply immutable")
	check(not rules.accept_action("flee").ok and not rules.accept_action("attack").ok and not rules.select_target("bracer") and not rules.cycle_target() and rules.snapshot() == resolved, "Presentation lock blocks action, exit and retarget replay atomically")
	check(not rules.complete_presentation(int(tx.token) + 100) and rules.snapshot() == resolved, "A wrong presentation token cannot unlock")
	check(rules.complete_presentation(int(tx.token)) and not rules.complete_presentation(int(tx.token)), "A valid presentation token is consumed once")
	var second: Dictionary = rules.accept_action("guard")
	rules.retry()
	var retry_state: Dictionary = rules.snapshot()
	check(not rules.complete_presentation(int(second.token)) and rules.snapshot() == retry_state, "Retry invalidates callbacks from the previous attempt")
	var third: Dictionary = rules.accept_action("attack")
	check(third.token != tx.token and third.token != second.token and not rules.complete_presentation(int(second.token)) and rules.locked, "Old tokens never unlock a newer accepted action")
	rules.configure(source)
	check(not rules.complete_presentation(int(third.token)) and rules.turn == 0 and not rules.locked, "Reconfigure also invalidates pending presentation")


func _test_support_order() -> void:
	for companion: String in ["沈青", "唐栖"]:
		var source = _source()
		source.companion_unlocked = true
		source.tangqi_unlocked = true
		source.active_companion = companion
		source.shen_care_stage = 5
		source.shen_care_choice = "mobile"
		var original: Dictionary = _source_snapshot(source)
		var rules = _arena(source)
		rules.select_target("bracer")
		var first: Dictionary = _step(rules, "attack")
		rules.qi = 2
		var second: Dictionary = rules.accept_action("attack")
		var expected_support: int = 7 if companion == "沈青" else 4
		check(first.support_damage == 0 and second.support_damage == expected_support and second.events[0].kind == "hero" and second.events[1].kind == "support" and second.events[2].kind == "counter", "Every second offensive action: hero, support, counter in order: " + companion)
		check(second.events[0].target_id == "bracer" and second.events[1].target_id == "bracer" and second.support_qi == (1 if companion == "唐栖" else 0) and second.support_heal == (2 if companion == "沈青" else 0), "Selected target and companion-specific copied benefit: " + companion)
		check(second.after.hp == second.before.hp + second.heal + second.support_heal - second.counter_damage and second.after.qi == second.before.qi + second.qi_delta, "Exact HP/qi amounts reconcile with resolved state: " + companion)
		rules.complete_presentation(int(second.token))
		rules.retry()
		rules.select_target("bracer")
		_step(rules, "attack")
		rules.units[1].hp = 17
		var capped: Dictionary = rules.accept_action("attack")
		check(capped.hero_damage == 16 and capped.support_damage == 1 and capped.after.units[0].hp == Rules.STRIKER_HP and rules.selected_id == "bracer", "Support overkill caps at its same target's last HP: " + companion)
		rules.retry()
		rules.select_target("bracer")
		_step(rules, "attack")
		rules.units[1].hp = 1
		var hero_kill: Dictionary = rules.accept_action("attack")
		check(hero_kill.hero_damage == 1 and hero_kill.support_damage == 0 and hero_kill.support_qi == 0 and hero_kill.support_heal == 0 and hero_kill.after.units[0].hp == Rules.STRIKER_HP, "Hero overkill never redirects companion or grants an absent assist benefit: " + companion)
		check(_source_snapshot(source) == original, "Companion rehearsal never changes real counters, resources or progression: " + companion)
	var source = _source()
	source.companion_unlocked = true
	var rules = _arena(source)
	_step(rules, "attack")
	var braced: Dictionary = _step(rules, "attack")
	check(braced.support_damage == 4 and braced.hero_damage == 8, "Brace independently halves odd companion damage with upward rounding")


func _test_resources_and_effects() -> void:
	var source = _source("伏汐藏锋")
	var rules = _arena(source)
	var before: Dictionary = rules.snapshot()
	check(not rules.accept_action("item").ok and rules.snapshot() == before, "Full-health practice heal is rejected without charge/cooldown/turn changes")
	rules.qi = 0
	before = rules.snapshot()
	check(not rules.accept_action("skill").ok and rules.snapshot() == before, "Insufficient qi is rejected atomically")
	var guard: Dictionary = _step(rules, "guard")
	check(guard.qi_delta == 1 and guard.counter_damage == 3 and guard.guarded, "Guard restores exact virtual qi and rounds incoming 10 × 0.3 to 3")
	var attack_tx: Dictionary = _step(rules, "attack")
	check(attack_tx.qi_delta == 2 and attack_tx.counter_damage == 20, "Attack restores two qi and does not retain prior guard")
	rules.qi = rules.max_qi
	var skill: Dictionary = _step(rules, "skill")
	check(skill.hero_qi_delta == -4 and rules.skill_cooldown == 3 and rules.focused_damage == 34, "Focus skill takes its actual catalog cost and establishes future attack bonus")
	before = rules.snapshot()
	check(not rules.accept_action("skill").ok and rules.snapshot() == before, "Cooldown rejection leaves all arena state untouched")
	var focused: Dictionary = _step(rules, "attack")
	check(focused.hero_damage == 25 and rules.focused_damage == 0 and rules.skill_cooldown == 2, "One following basic attack consumes focus before brace reduction")
	var healed: Dictionary = _step(rules, "item")
	check(healed.heal == mini(Rules.PRACTICE_HEAL, int(healed.before.max_hp) - int(healed.before.hp)) and healed.after.medicine == 2 and rules.skill_cooldown == 1 and healed.counter_damage > 0, "Practice heal restores exact capped HP, uses one virtual charge and still permits announced counter")
	_step(rules, "guard")
	check(rules.skill_cooldown == 0, "Three accepted non-skill actions finish a three-turn cooldown")
	for charge: int in 2:
		rules.hp = rules.max_hp - 50
		_step(rules, "item")
	before = rules.snapshot()
	check(rules.medicine == 0 and not rules.accept_action("item").ok and rules.snapshot() == before, "Exactly three virtual heals; empty charge rejection is atomic")
	rules.retry()
	rules.qi = rules.max_qi
	var capped: Dictionary = _step(rules, "attack")
	check(capped.qi_delta == 0 and capped.logs[0].contains("回复0真气"), "At qi cap both transaction and log report zero gained")
	var weaken = _arena(_source("石隙封腕"))
	var lowered: Dictionary = _step(weaken, "skill")
	check(lowered.counter_damage == 2 and weaken.units[0].weaken_amount == 8 and weaken.units[0].weaken_strikes == 1 and weaken.units[1].weaken_strikes == 0, "Weaken applies only to the selected striker and consumes on its actual attack")
	_step(weaken, "guard")
	check(weaken.units[0].weaken_amount == 0 and weaken.units[0].weaken_strikes == 0, "Weaken expires after exactly the target's two attacks")
	weaken.retry()
	weaken.select_target("bracer")
	_step(weaken, "skill")
	_step(weaken, "guard")
	check(weaken.units[1].weaken_strikes == 2 and weaken.units[0].weaken_strikes == 0, "Protecting bracer preserves its own weaken charges; striker cannot consume them")
	weaken.select_target("striker")
	weaken.units[0].hp = 1
	_step(weaken, "attack")
	var solo: Dictionary = _step(weaken, "guard")
	check(solo.counter_damage == 1 and weaken.units[1].weaken_strikes == 1, "Former protector consumes its stored weaken only once it attacks alone")


func _test_companion_cover() -> void:
	for companion: String in ["沈青", "唐栖"]:
		var source = _source()
		source.companion_unlocked = true
		source.tangqi_unlocked = true
		source.active_companion = companion
		source.formation = "护后"
		source.shen_care_stage = 5
		source.shen_care_choice = "shore"
		var original: Dictionary = _source_snapshot(source)
		var rules = _arena(source)
		var light: Dictionary = _step(rules, "attack")
		var heavy: Dictionary = _step(rules, "attack")
		check(light.counter_damage == (7 if companion == "沈青" else 10) and heavy.counter_damage == (17 if companion == "沈青" else 15) and heavy.support_damage == 0, "Cover honors each companion, heavy intent and Shen's completed shore choice: " + companion)
		_step(rules, "guard")
		var guarded: Dictionary = _step(rules, "guard")
		check(guarded.counter_damage == (3 if companion == "沈青" else 1) and guarded.counters[0].cover == (3 if companion == "沈青" else 5), "Cover applies after guard, with at least one incoming damage: " + companion)
		check(_source_snapshot(source) == original, "Cover has no effect on source state: " + companion)


func _test_outcomes_and_no_rewards() -> void:
	for ending: String in ["win", "defeat", "flee"]:
		var source = _source("青灯息争")
		source.coins = 77
		source.xp = 33
		source.victories = 6
		source.resources.herb = 9
		var original: Dictionary = _source_snapshot(source)
		var rules = _arena(source)
		var result: Dictionary
		if ending == "win":
			# Play ordinary, accepted turns; this route exercises target strategy
			# and healing without directly zeroing enemy HP.
			rules.select_target("bracer")
			for action_index: int in 50:
				if not rules.active:
					break
				var action: String = "attack"
				if rules.hp < 50 and rules.medicine > 0:
					action = "item"
				elif rules.action_unavailable_reason("skill").is_empty():
					action = "skill"
				result = _step(rules, action)
		elif ending == "defeat":
			rules.hp = 2
			result = rules.accept_action("attack")
		else:
			result = rules.accept_action("flee")
		check(not rules.active and rules.outcome == ending and (rules.hp == 0 if ending == "defeat" else true), "Terminal outcome reached: " + ending)
		check(result.ok and result.after.outcome == ending and (result.counter_damage == 2 if ending == "defeat" else true) and (result.counter_damage == 0 if ending == "flee" else true), "Terminal transaction reports actual clamped costs: " + ending)
		if rules.locked:
			rules.complete_presentation(int(result.token))
		var terminal: Dictionary = rules.snapshot()
		check(not rules.accept_action("attack").ok and not rules.select_target("striker") and rules.snapshot() == terminal, "Completed arena refuses further actions: " + ending)
		check(_source_snapshot(source) == original, "Outcome cannot farm rewards or spend real resources, including transient fields: " + ending)
		rules.retry()
		check(rules.active and rules.outcome.is_empty() and rules.hp == rules.max_hp and rules.qi == rules.max_qi and rules.medicine == 3 and rules.turn == 0 and rules.selected_id == "striker" and rules.focused_damage == 0 and rules.units[0].hp == Rules.STRIKER_HP and rules.units[1].hp == Rules.BRACER_HP and _source_snapshot(source) == original, "Free retry restores only arena state: " + ending)
	# Repeat a full victory to catch accidental one-time receipts or art use gain.
	var source = _source()
	source.attack = 200
	var original: Dictionary = _source_snapshot(source)
	var rules = _arena(source)
	for attempt: int in 3:
		_step(rules, "skill")
		_step(rules, "attack")
		check(rules.outcome == "win" and _source_snapshot(source) == original, "Repeated victory has no persistent reward receipt or mastery gain")
		rules.retry()
