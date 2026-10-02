extends SceneTree
const Rules = preload("res://scripts/automatic_party_combat.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_all_encounters_without_input()
	_test_round_entitlement_and_tokens()
	_test_queues_and_cooldowns()
	_test_exact_target_and_death()
	_test_revalidation_and_enemy_fallback()
	_test_utilities_and_pause()
	_test_support_and_patterns()
	_test_trial_provenance()
	_test_practice_isolation()
	print("%s: %d automatic party scheduler checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _team(count: int = 1, power: int = 10, health: int = 500, art: String = Arts.BASE_ART, formation: String = "并肩") -> Dictionary:
	var actors: Array[Dictionary] = []
	for index: int in count:
		var id: String = Catalog.IDS[index]
		var actor: Dictionary = Catalog._actor(id, id, health, 12, power, 4)
		actor.equipped_art = art if id == "hero" else ""
		actor.sect = String(Arts.definition(art).sect) if id == "hero" else ""
		actor.recruited = id != "hero"
		actor.internal_unlocked = true
		actor.lightness_unlocked = true
		actors.append(actor)
	return {"actors": actors, "formation": formation, "medicine": 3, "medicine_heal": 45}

func _rules(team: Dictionary = {}, encounter: String = "story"):
	var model = Rules.new()
	check(model.configure(_team() if team.is_empty() else team, encounter), "Valid team configures %s" % encounter)
	return model

func _unit(view: Dictionary, id: String) -> Dictionary:
	for unit: Dictionary in view.actors + view.enemies:
		if unit.id == id:
			return unit
	return {}

func _action(view: Dictionary, actor_id: String, category: String) -> Dictionary:
	for action: Dictionary in _unit(view, actor_id).actions:
		if action.category == category:
			return action
	return {}

func _step(model) -> Dictionary:
	var tx: Dictionary = model.advance()
	check(tx.ok, "Automatic step accepted")
	if tx.ok:
		check(model.complete_presentation(tx.token), "Exact presentation token acknowledged")
	return tx

func _to_round(model, target: int) -> void:
	var limit: int = 300
	while model.snapshot().active and int(model.snapshot().round) < target and limit > 0:
		_step(model)
		limit -= 1
	check(model.snapshot().round == target, "Reached round %d" % target)

func _event(tx: Dictionary, type: String, source: String = "", target: String = "") -> Dictionary:
	for event: Dictionary in tx.get("events", []):
		if event.type == type and (source.is_empty() or event.source_id == source) and (target.is_empty() or event.target_id == target):
			return event
	return {}

func _test_all_encounters_without_input() -> void:
	for encounter: String in Rules.SUPPORTED_ENCOUNTERS:
		for count: int in range(1, 5):
			var model = _rules(_team(count, 20, 1000), encounter)
			var basics: Dictionary = {}
			var limit: int = 400
			while model.snapshot().active and limit > 0:
				var tx: Dictionary = model.advance()
				check(tx.ok, "%s/%d no-input progresses" % [encounter, count])
				if not tx.ok:
					break
				if tx.action_id == "attack":
					var key: String = "%d:%s" % [tx.before.round, tx.source_id]
					check(not basics.has(key), "No actor receives a duplicate basic in one round")
					basics[key] = true
				check(model.complete_presentation(tx.token), "No-input ack succeeds")
				limit -= 1
			check(model.snapshot().outcome == "win", "%s/%d completes without any manual input" % [encounter, count])
			check(not model.advance().ok, "Terminal advance rejected")

func _test_round_entitlement_and_tokens() -> void:
	var model = _rules(_team(4, 1), "heting_receipt")
	var initial: Dictionary = model.snapshot()
	check(initial.is_read_only() and initial.actors.is_read_only() and initial.actors[0].status.is_read_only(), "Snapshot is recursively immutable")
	var expected: Array[String] = ["hero", "shen", "tang", "qin", "striker", "bracer"]
	var seen: Array[String] = []
	var previous: int = -1
	for id: String in expected:
		var tx: Dictionary = model.advance()
		check(tx.ok and tx.source_id == id, "Actor order exactly %s" % id)
		seen.append(tx.source_id)
		check(tx.before.is_read_only() and tx.after.is_read_only() and tx.events.is_read_only(), "Transaction is recursively immutable")
		var locked: Dictionary = model.snapshot()
		check(locked.active_actor_id == id and locked.locked, "Actual actor highlighted during presentation")
		check(not model.advance().ok and model.snapshot() == locked, "Duplicate advance cannot mutate accepted action")
		check(not model.complete_presentation(previous), "Wrong/stale token rejected")
		check(model.complete_presentation(tx.token), "Matching token releases presentation")
		check(not model.complete_presentation(tx.token), "Duplicate acknowledgement rejected")
		previous = tx.token
	check(model.snapshot().round == 2 and seen == expected, "Every eligible ally basic then truthful enemy intent once")
	for actor: Dictionary in model.snapshot().actors:
		check(not actor.basic_done and actor.basic_round == 1, "Round2 entitlement restored; provenance keeps last basic round")
		check(actor.actions.size() == 5, "Exactly3 skills and2 utilities")
		for index: int in 3:
			check(actor.actions[index].category == Rules.CATEGORIES[index], "Fixed semantic skill slot")
	var other = _rules()
	var other_tx: Dictionary = other.advance()
	check(not other.complete_presentation(previous), "Different session token cannot unlock new session")
	check(other_tx.epoch != model.snapshot().epoch and other_tx.token != previous, "Epoch and token identify distinct sessions")

func _test_queues_and_cooldowns() -> void:
	var model = _rules(_team(2, 1), "sect_trial")
	var start: Dictionary = model.snapshot()
	var martial: String = _action(start, "hero", "martial").id
	check(model.queue_skill("hero", martial, "sect_trial").ok, "Queue current-round martial")
	check(_unit(model.snapshot(), "hero").qi == 12 and not _unit(model.snapshot(), "hero").basic_done, "Queue charges no cost and no basic")
	check(not model.queue_skill("hero", martial, "sect_trial").ok, "Duplicate category queue rejected")
	var skill: Dictionary = model.advance()
	check(skill.action_id == martial and _unit(skill.after, "hero").qi == 9, "Skill executes before its actor basic and then charges")
	check(not _unit(skill.after, "hero").basic_done and _unit(skill.after, "hero").categories.martial.used, "Skill only spends category entitlement")
	check(model.select_actor("shen") and model.snapshot().active_actor_id == "hero", "Selected actor never changes actual acting actor")
	check(model.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Can queue another category during presentation")
	check(model.cancel_queued("hero", "lightness"), "Can cancel queued category during presentation")
	check(model.complete_presentation(skill.token), "Skill acknowledged")
	var basic: Dictionary = model.advance()
	check(basic.action_id == "attack" and basic.source_id == "hero", "Automatic basic follows optional skill")
	var queued: Dictionary = model.queue_skill("hero", "lightness:hero_tawei", "hero")
	check(queued.ok and queued.queue_round == 2, "Queue after basic targets next round even during presentation")
	check(model.snapshot().actors[0].categories.lightness.queue_round == 2, "Snapshot exposes exact next-round queue")
	check(model.complete_presentation(basic.token), "Basic acknowledged")
	_to_round(model, 2)
	check(_action(model.snapshot(), "hero", "martial").cooldown_remaining == 2, "Freshly set CD does not tick cast round end")
	check(_action(model.snapshot(), "hero", "martial").eligible_round == 4, "CD2 usedR1 earliestR4")
	var future: Dictionary = _step(model)
	check(future.action_id == "lightness:hero_tawei", "Queued next-round skill executes at next basic boundary")
	check(not model.queue_skill("hero", martial, "sect_trial").ok, "Cooldown blocks early next basic")
	_to_round(model, 3)
	check(_action(model.snapshot(), "hero", "martial").cooldown_remaining == 1, "One full subsequent round decrements once")
	_to_round(model, 4)
	check(_action(model.snapshot(), "hero", "martial").cooldown_remaining == 0 and model.queue_skill("hero", martial, "sect_trial").ok, "ExactlyN subsequent rounds restore skill")
	var multi = _rules(_team(1, 1), "sect_trial")
	multi._actors[0].hp = 400
	check(multi.queue_skill("hero", martial, "sect_trial").ok and multi.queue_skill("hero", "internal:hero_tiaoxi", "hero").ok and multi.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Three independent category queues coexist")
	var action_order: Array[String] = []
	for index: int in 4:
		action_order.append(_step(multi).action_id)
	check(action_order == [martial, "internal:hero_tiaoxi", "lightness:hero_tawei", "attack"], "FIFO skills then exactly one basic")
	check(_unit(multi.snapshot(), "hero").qi == 7, "Three actual costs charged once plus basic2 qi")
	var poor = _rules(_team(1, 1), "sect_trial")
	poor._actors[0].qi = 3
	check(poor.queue_skill("hero", martial, "sect_trial").ok and poor.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Queues reserve no resources; each validates current eligibility")
	_step(poor)
	var cancelled: Dictionary = _step(poor)
	check(not _event(cancelled, "queue_cancel").is_empty() and _unit(cancelled.after, "hero").qi == 0, "Execution-time qi shortage cancels without double charge")
	check(_step(poor).action_id == "attack", "Cancelled optional skill cannot stall automatic basic")

func _test_exact_target_and_death() -> void:
	var team: Dictionary = _team(3, 1)
	team.actors[0].attack = 380
	var model = _rules(team, "heting_receipt")
	check(model.queue_skill("tang", "art:tang_fenjin", "striker").ok, "Queue exact living target")
	_step(model)
	check(_unit(model.snapshot(), "striker").hp == 0, "Earlier actor kills queued target")
	_step(model)
	var cancelled: Dictionary = _step(model)
	check(cancelled.source_id == "tang" and not _event(cancelled, "queue_cancel").is_empty(), "Dead exact target cancels skill instead of retargeting")
	check(_unit(cancelled.after, "tang").qi == 12 and _action(cancelled.after, "tang", "martial").cooldown_remaining == 0, "Invalid queued target charges no cost/CD/category")
	var basic: Dictionary = _step(model)
	check(basic.action_id == "attack" and basic.target_id == "bracer", "Automatic basic retargets living enemy")
	var dead_team: Dictionary = _team(4, 1)
	dead_team.actors[1].hp = 0
	var dead = _rules(dead_team, "heting_receipt")
	check(not dead.queue_skill("shen", "art:shen_xumai", "hero").ok, "Dead actor cannot queue")
	var actors: Array[String] = []
	for index: int in 3:
		actors.append(_step(dead).source_id)
	check(actors == ["hero", "tang", "qin"], "Automatic roster skips dead actor")
	var lethal_team: Dictionary = _team(4, 1000)
	var lethal = _rules(lethal_team)
	lethal._actors[1].hp = 400
	check(lethal.queue_skill("shen", "art:shen_xumai", "shen").ok, "Later actor skill is queued")
	var win: Dictionary = _step(lethal)
	check(win.after.outcome == "win" and not _unit(win.after, "shen").categories.martial.queued, "Terminal victory discards pending commands")
	check(_unit(win.after, "shen").qi == 12 and not lethal.advance().ok, "No queued action or enemy counter after victory")

func _test_utilities_and_pause() -> void:
	var model = _rules(_team(2, 1))
	model._actors[0].hp = 300
	var item: Dictionary = model.accept_action("item")
	check(item.ok and _unit(item.after, "hero").hp == 345 and item.after.medicine == 2, "Item is a safe-boundary45 heal")
	check(not _unit(item.after, "hero").basic_done and not model.accept_action("item").ok, "Item does not consume basic; locked repeated item rejects")
	check(model.complete_presentation(item.token), "Item ack")
	check(not model.accept_action("item").ok, "Actor medicine once per round")
	check(not model.accept_action("attack").ok and not model.accept_action("guard").ok, "No manual basic or guard dispatch")
	var attack: Dictionary = model.advance()
	check(model.set_paused(true) and model.snapshot().pause_requested and not model.snapshot().paused, "Pause during animation waits for safe boundary")
	check(model.complete_presentation(attack.token) and model.snapshot().paused, "Accepted action finishes before pause")
	check(not model.advance().ok, "Pause prevents next automatic transaction")
	check(model.select_actor("shen") and model.queue_skill("shen", "lightness:shen_liuying", "shen").ok, "Paused boundary permits planning")
	check(model.set_paused(false), "Resume supported")
	check(_step(model).source_id == "shen", "Resume continues queued next actor without replay")
	var flee: Dictionary = model.accept_action("flee")
	check(flee.ok and flee.after.outcome == "flee" and not model.advance().ok, "Explicit safe-boundary flee ends all further actions")

func _test_revalidation_and_enemy_fallback() -> void:
	var heal_team: Dictionary = _team(2, 1)
	heal_team.actors[0].hp = 490
	var healing = _rules(heal_team, "sect_trial")
	check(healing.queue_skill("hero", "internal:hero_tiaoxi", "hero").ok and healing.queue_skill("shen", "art:shen_xumai", "hero").ok, "Two healers may initially queue the same wounded target")
	_step(healing)
	_step(healing)
	var cancelled: Dictionary = _step(healing)
	check(not _event(cancelled, "queue_cancel").is_empty() and _unit(cancelled.after, "shen").qi == 12, "Earlier heal makes fullHP exact target invalid without charging later healer")
	check(_step(healing).action_id == "attack", "Cancelled heal leaves basic entitlement intact")
	var fallback_team: Dictionary = _team(4, 1, 500, Arts.BASE_ART, "护后")
	fallback_team.actors[0].hp = 1
	var fallback = _rules(fallback_team, "heting_receipt")
	# Killing the striker after planning must leave the bracer's already
	# announced protect action unchanged for this round.
	var protect_before: Dictionary = fallback.snapshot().enemy_intents[1]
	fallback._enemies[0].hp = 0
	for index: int in 4:
		_step(fallback)
	var protection: Dictionary = _step(fallback)
	check(protect_before.type == "protect" and protection.action_id == "enemy:protect" and _event(protection, "damage").is_empty(), "Preannounced protection does not secretly turn into attack")
	check(fallback.snapshot().enemy_intents[0].source_id == "bracer" and fallback.snapshot().enemy_intents[0].type == "attack", "Orphaned bracer announces attack starting following round")
	var sequential = _rules(_team(2, 1, 500, Arts.BASE_ART, "护后"), "heting_receipt")
	# Model a legitimate second attacking enemy intent after striker is already
	# absent at a planning boundary; inspect its published fallback order.
	sequential._enemies[0].hp = 0
	sequential._plan_intents()
	sequential._actors[0].hp = 0
	var next_actor: Dictionary = _step(sequential)
	check(next_actor.source_id == "shen", "Actor killed before its boundary is skipped")
	var transferred: Dictionary = _step(sequential)
	check(transferred.source_id == "bracer" and transferred.target_id == "shen" and _event(transferred, "action").announced_target_id == "hero", "Enemy retargets through published fallback order and preserves announced target provenance")

func _test_support_and_patterns() -> void:
	var team: Dictionary = _team(4, 1, 500, Arts.BASE_ART, "护后")
	team.actors[0].hp = 300
	var support = _rules(team, "heting_receipt")
	check(support.queue_skill("shen", "art:shen_xumai", "hero").ok and support.queue_skill("qin", "art:qin_shoudu", "hero").ok, "Healer and barrier exact targets queue")
	var heal_amount: int = 0
	var absorbed: int = 0
	while support.snapshot().round == 1:
		var tx: Dictionary = _step(support)
		heal_amount += int(_event(tx, "heal", "shen", "hero").get("amount", 0))
		absorbed += int(_event(tx, "barrier_absorb", "striker", "hero").get("amount", 0))
	check(heal_amount == 28 and absorbed == 18, "Healing and Qin18 barrier retain independent provenance")
	check(_unit(support.snapshot(), "hero").hp == 328, "Barrier protects actual incoming target after defense; no hidden heal")
	var weak = _rules(_team(3, 1, 500, Arts.BASE_ART, "护后"), "sluice_boss")
	check(weak.queue_skill("tang", "art:tang_fenjin", "sluice_boss").ok, "Tang weakening queues")
	var damage: Array[int] = []
	while weak.snapshot().round < 4:
		var tx: Dictionary = _step(weak)
		if tx.source_id == "sluice_boss":
			damage.append(int(_event(tx, "damage", "sluice_boss", "hero").get("amount", 0)))
	check(damage == [7, 19, 15], "Weaken consumed by2 actual strikes, then vulnerability adds3")
	var mist = _rules(_team(1, 10), "mist_keeper")
	var outgoing: Array[int] = []
	var intents: Array[int] = []
	while mist.snapshot().round < 4:
		var tx: Dictionary = _step(mist)
		if tx.action_id == "attack":
			outgoing.append(_event(tx, "damage", "hero", "mist_keeper").amount)
		else:
			intents.append(_event(tx, "action", "mist_keeper").damage)
	check(outgoing == [5, 10, 18] and intents == [10, 33, 8], "Mist guardian preserves3-phase guard/heavy/opening and truthful intents")
	var light = _rules(_team(1, 1), "story")
	check(light.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Lightness queues")
	_step(light)
	_step(light)
	var hit: Dictionary = _step(light)
	check(_event(hit, "lightness_absorb").amount == 5 and _event(hit, "damage").amount == 0, "Lightness follows defense and can reduce hit to0")
	check(not _unit(hit.after, "hero").status.guard and _unit(hit.after, "hero").status.next_hit_reduction == 0, "Lightness is consumed and never masquerades as guard")
	var noheal = _rules(_team())
	check(not noheal.queue_skill("hero", "internal:hero_tiaoxi", "hero").ok, "Pure internal heal at fullHP rejects without cost")

func _test_trial_provenance() -> void:
	var guarded = _rules(_team(1, 1, 500, "磐石回锋"), "sect_trial")
	_to_round(guarded, 2)
	check(guarded.queue_skill("hero", "art:磐石回锋", "sect_trial").ok, "Trial martial guard queued for heavy round")
	_step(guarded)
	check(not guarded.snapshot().trial_provenance.guarded_heavy, "Announced heavy alone does not satisfy trial")
	_step(guarded)
	var heavy: Dictionary = _step(guarded)
	check(heavy.after.trial_provenance.guarded_heavy and heavy.after.trial_provenance.met, "Actual incoming heavy against exact martial guard satisfies trial")
	check(not _event(heavy, "trial_guarded_heavy").is_empty(), "Guarded-heavy event records martial provenance")
	var lethal = _rules(_team(1, 1, 500, "磐石回锋"), "sect_trial")
	_to_round(lethal, 2)
	lethal._enemies[0].hp = 1
	check(lethal.queue_skill("hero", "art:磐石回锋", "sect_trial").ok, "Lethal trial skill queues")
	_step(lethal)
	check(lethal.snapshot().outcome == "win" and not lethal.snapshot().trial_provenance.guarded_heavy, "Lethal skill skips nonexistent heavy and cannot qualify trial")
	var lighting = _rules(_team(1, 1, 500, "磐石回锋"), "sect_trial")
	_to_round(lighting, 2)
	check(lighting.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Lightness can be used on trial heavy")
	_to_round(lighting, 3)
	check(not lighting.snapshot().trial_provenance.met, "Lightness reduction cannot satisfy martial guarded-heavy requirement")
	var healer = _rules(_team(1, 1, 500, "青灯续脉"), "sect_trial")
	check(healer.queue_skill("hero", "art:青灯续脉", "sect_trial").ok, "Healing martial can attack at fullHP")
	_step(healer)
	check(healer.snapshot().trial_provenance.art_used and not healer.snapshot().trial_provenance.met and healer.snapshot().trial_provenance.healing == 0, "FullHP cast has no false positive-healing provenance")
	var wounded_team: Dictionary = _team(1, 1, 500, "青灯续脉")
	wounded_team.actors[0].hp = 480
	var wounded = _rules(wounded_team, "sect_trial")
	check(wounded.queue_skill("hero", "art:青灯续脉", "sect_trial").ok, "Wounded healing martial queues")
	_step(wounded)
	check(wounded.snapshot().trial_provenance.healing == 20 and wounded.snapshot().trial_provenance.met, "Actual capped healing establishes trial provenance")

func _test_practice_isolation() -> void:
	var team: Dictionary = _team(4, 1)
	team.actors[0].hp = 1
	team.actors[0].qi = 0
	team.medicine = 0
	team.medicine_heal = 40
	var original: Dictionary = team.duplicate(true)
	var practice = _rules(team, "courtyard_practice")
	check(_unit(practice.snapshot(), "hero").hp == 500 and _unit(practice.snapshot(), "hero").qi == 12 and practice.snapshot().medicine == 3 and practice.snapshot().medicine_heal == 40, "Practice restores private resources and3x40 medicine")
	check(_unit(practice.snapshot(), "striker").max_hp == 96 and _unit(practice.snapshot(), "bracer").max_hp == 64, "Practice96/64 wooden targets preserved")
	check(practice.queue_skill("hero", "art:" + Arts.BASE_ART, "striker").ok, "Practice martial queues")
	var tx: Dictionary = _step(practice)
	check(_event(tx, "proficiency").is_empty() and _unit(tx.after, "hero").art_uses.is_empty(), "Practice does not grant proficiency")
	check(team == original, "Practice cannot mutate source team/resources")
	var frozen: Dictionary = practice.snapshot()
	team.actors[0].max_hp = 10000
	team.actors[0].name = "changed"
	check(practice.snapshot() == frozen, "Detached model does not retain mutable source inputs")
	var invalid = Rules.new()
	check(not invalid.configure(_team(), "unknown"), "Unknown encounter cannot construct runtime")
