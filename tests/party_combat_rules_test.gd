extends SceneTree
## Pure transaction checks plus a real, earned opening→Tang recruitment route.
## The journey adapter suppresses saves; the detached model performs no I/O.
const State = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Rules = preload("res://scripts/party_combat_rules.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const Advanced = preload("res://scripts/advanced_martial_rules.gd")
class JourneyState extends State:
	func save_game(_path: String = SAVE_PATH) -> Error: return OK
	func load_game(_path: String = SAVE_PATH) -> Error: return ERR_FILE_NOT_FOUND
	func has_save() -> bool: return false
var checks: int = 0
var failures: int = 0
var app


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	_test_catalog_and_detachment()
	_test_actor_rounds_and_transactions()
	_test_all_arts()
	_test_healing_and_shared_medicine()
	_test_formation_and_death()
	_test_protector_and_effects()
	_test_natural_opening()
	await _test_earned_three_party()
	if failures == 0:
		print("PASS: %d actor party combat checks (catalog/ten arts/rounds/targets/resources/transactions/formation/death/earned journeys)" % checks)
	else:
		push_error("FAIL: %d of %d party combat checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _source(art: String = Arts.BASE_ART):
	var source = State.new()
	if not String(Arts.definition(art).sect).is_empty():
		source.choose_sect(String(Arts.definition(art).sect))
	source.sect_rank = 2
	if Advanced.is_advanced(art):
		source.learned_arts.append(art)
	source.equip_art(art)
	source.companion_unlocked = true
	source.tangqi_unlocked = true
	source.max_hp = 240
	source.hp = 150
	source.max_qi = 8
	source.qi = 8
	source.attack = 16
	source.defense = 4
	return source


func _arena(source, roster: Array = ["hero", "shen", "tang"], encounter: String = "heting_receipt", resources: Dictionary = {}):
	var built: Dictionary = Catalog.build_team(source, roster, resources)
	check(built.ok, "Valid explicit roster builds detached team")
	var rules = Rules.new()
	check(rules.configure(built.team, encounter), "Detached team configures encounter")
	return rules


func _actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id:
			return actor
	return {}


func _enemy(snapshot: Dictionary, id: String) -> Dictionary:
	for enemy: Dictionary in snapshot.enemies:
		if enemy.id == id:
			return enemy
	return {}


func _step(rules, action: String, target: String = "") -> Dictionary:
	var tx: Dictionary = rules.accept_action(action, target)
	check(tx.ok, "Legal action accepted: " + action + " / " + target + " / " + String(tx.get("reason", "")))
	if tx.ok:
		check(rules.complete_presentation(tx.token), "Matching presentation unlocks once")
	return tx


func _events(tx: Dictionary, type: String, phase: String = "", source: String = "") -> Array:
	var found: Array = []
	for event: Dictionary in tx.get("events", []):
		if event.type == type and (phase.is_empty() or event.phase == phase) and (source.is_empty() or event.source_id == source):
			found.append(event)
	return found


func _test_catalog_and_detachment() -> void:
	var source = State.new()
	for roster: Array in [[], ["shen"], ["hero", "hero"], ["hero", "unknown"], ["hero", "shen"], ["hero", "tang"], ["hero", 42]]:
		check(not Catalog.build_team(source, roster).ok, "Invalid/unrecruited roster rejects: " + str(roster))
	check(source.recruit_companion(), "Shen recruited through real state rule")
	check(Catalog.build_team(source, ["hero", "shen"]).ok, "Recruited Shen may be explicitly selected")
	check(Catalog.build_team(source, ["hero"]).team.actors.size() == 1, "No automatic addition of recruited companion")
	for resources: Dictionary in [{"tang": {"hp": 1}}, {"hero": {"hp": -1}}, {"hero": {"qi": 100}}, {"hero": {"hp": 1.5}}, {"hero": {"attack": 999}}, {"hero": []}]:
		check(not Catalog.build_team(source, ["hero"], resources).ok, "Invalid persisted resources reject: " + str(resources))
	var original: Dictionary = source.to_dict().duplicate(true)
	var built: Dictionary = Catalog.build_team(source, ["shen", "hero"], {"shen": {"hp": 40, "qi": 1}})
	check(built.is_read_only() and built.team.is_read_only() and built.team.actors.is_read_only() and built.team.actors[1].status.is_read_only(), "Catalog snapshot is deeply read-only")
	check(built.team.actors[0].id == "hero" and built.team.actors[1].hp == 40 and built.team.actors[1].qi == 1, "Roster canonicalizes front hero and uses persisted companion resources")
	var rules = Rules.new()
	check(rules.configure(built.team, "story"), "Model accepts detached catalog output")
	check(not rules.configure(built.team, "story"), "Configured session cannot be reset for free resources")
	for actor: Dictionary in rules.snapshot().actors:
		check(actor.actions.size() == 5 and actor.actions[1].category == "martial", "Each actor exposes five genuine actions and one martial art")
		for action: Dictionary in actor.actions:
			for key: String in ["id", "category", "name", "cost", "cooldown", "target_team", "description", "available", "reason", "valid_target_ids"]:
				check(action.has(key), "Authoritative action descriptor contains " + key)
	var reference: WeakRef = weakref(source)
	check(source.to_dict() == original, "Building/configuring never mutates source")
	source = null
	check(reference.get_ref() == null, "Catalog and engine retain no source HeroState")
	_step(rules, "attack", "puheng")
	check(_actor(rules.snapshot(), "shen").hp == 40, "Detached model remains usable after source freed")
	var invalid = Rules.new()
	check(not invalid.configure({}, "story") and not invalid.configure(built.team, "unknown"), "Malformed team/encounter rejects before configuring")
	check(invalid.configure(built.team, "training"), "Failed configure does not consume session")
	var mutable: Dictionary = built.team.duplicate(true)
	var copy = Rules.new()
	check(copy.configure(mutable), "Writable dictionary input configures by copying")
	mutable.actors[0].hp = 1
	mutable.actors[0].actions.clear()
	check(_actor(copy.snapshot(), "hero").hp == 100 and _actor(copy.snapshot(), "hero").actions.size() == 5, "Later input mutation cannot alter model or its actions")


func _test_actor_rounds_and_transactions() -> void:
	var source = _source()
	var original: Dictionary = source.to_dict().duplicate(true)
	var rules = _arena(source)
	check(rules.select_actor("tang"), "Player can choose another living unspent actor")
	var first: Dictionary = rules.accept_action(Catalog.TANG_ART, "striker")
	check(first.ok and first.after.active_actor_id == "hero" and first.after.round == 1, "Accepted choice advances to first remaining ally")
	check(_events(first, "damage", "enemy").is_empty() and _events(first, "damage", "ally").size() == 1, "Only chosen actor acts before team completes round; no automatic assist")
	check(first.is_read_only() and first.before.is_read_only() and first.after.actors[0].actions.is_read_only() and first.events.is_read_only() and first.events[0].is_read_only(), "Transaction snapshots/events deeply immutable")
	var locked: Dictionary = rules.snapshot()
	check(not rules.accept_action("attack", "striker").ok and not rules.select_actor("shen") and not rules.select_target("bracer"), "Presentation lock rejects repeated action/selection")
	check(not rules.complete_presentation(first.token + 100) and rules.snapshot() == locked, "Stale callback cannot release lock or replay costs")
	check(rules.complete_presentation(first.token) and not rules.complete_presentation(first.token), "Exactly matching token completes once")
	check(not rules.select_actor("tang"), "Already-acted ally cannot act twice")
	var before: Dictionary = rules.snapshot()
	for pair: Array in [["unknown", "striker"], ["attack", "hero"], ["guard", "shen"], ["item", "shen"], ["flee", "striker"], ["attack", "missing"], [Catalog.TANG_ART, "striker"]]:
		check(not rules.accept_action(pair[0], pair[1]).ok and rules.snapshot() == before, "Invalid action/target preserves all resources and round: " + str(pair))
	_step(rules, "art:" + Arts.BASE_ART, "bracer")
	check(_actor(rules.snapshot(), "tang").cooldowns[Catalog.TANG_ART] == 2, "Other ally actions do not tick Tang cooldown")
	var final_ally: Dictionary = _step(rules, "guard")
	check(_events(final_ally, "damage", "enemy").size() == 1 and final_ally.after.round == 2, "Only final ally triggers living enemies, then new round")
	check(final_ally.after.active_actor_id == "hero" and not _actor(final_ally.after, "hero").acted, "Next round resets actions and selects first survivor")
	check(_actor(final_ally.after, "hero").cooldowns["art:" + Arts.BASE_ART] == 2 and _actor(final_ally.after, "tang").cooldowns[Catalog.TANG_ART] == 2, "Round boundary never grants a free cooldown tick")
	check(not rules.complete_presentation(first.token), "Earlier completed token cannot replay during later state")
	_step(rules, "guard")
	check(_actor(rules.snapshot(), "hero").cooldowns["art:" + Arts.BASE_ART] == 1, "Own other action ticks own cooldown once")
	check(_actor(rules.snapshot(), "shen").qi == 6 and _actor(rules.snapshot(), "tang").qi == 3, "Actor qi remains independent")
	check(source.to_dict() == original, "Every accepted transaction preserves source state and legacy companion counters")
	var escaped: Dictionary = _step(rules, "flee")
	check(escaped.after.outcome == "flee" and _events(escaped, "damage", "enemy").is_empty(), "Any active ally may retreat whole team without counter")
	check(not _actor(escaped.after, "hero").exposed and not _actor(escaped.after, "shen").exposed and not _actor(escaped.after, "tang").exposed, "Retreat ends exposure even when old announced enemies remain alive")
	check(escaped.before.medicine == escaped.after.medicine and escaped.before.actors[0].hp == escaped.after.actors[0].hp, "Retreat preserves resources already used")
	var terminal: Dictionary = rules.snapshot()
	check(not rules.accept_action("guard").ok and not rules.select_actor("hero") and not rules.select_target("striker") and rules.snapshot() == terminal, "Terminal encounter cannot act or be revived")


func _test_all_arts() -> void:
	for art: String in Arts.all_ids():
		for uses: int in [0, 4, 14, 9999]:
			var source = _source(art)
			source.art_uses[art] = uses
			var rules = _arena(source, ["hero", "shen"])
			var definition: Dictionary = Arts.definition(art)
			var before: Dictionary = rules.snapshot()
			var move: Dictionary = before.actors[0].actions[1]
			check(move.id == "art:" + art and move.effects == definition and move.cost == definition.cost and move.cooldown == definition.cooldown, "Hero action preserves exact existing art: " + art)
			var tx: Dictionary = _step(rules, move.id, "bracer")
			var hero: Dictionary = _actor(tx.after, "hero")
			check(_events(tx, "damage", "ally", "hero")[0].amount == Advanced.direct_damage(definition, source.attack, Catalog.rank_for_uses(uses)), "Damage resolves at rank before this use: " + art)
			check(hero.qi == source.qi - int(definition.cost) and hero.cooldowns[move.id] == definition.cooldown, "Exact art cost and own cooldown: " + art)
			check(hero.hp == source.hp + int(definition.healing) and hero.status.guard == definition.guard and hero.status.focused_damage == Advanced.focus_damage(definition, source.attack), "Exact heal/guard/focus effects: " + art)
			check(_enemy(tx.after, "bracer").status.weaken_amount == definition.weaken_amount and _enemy(tx.after, "striker").status.weaken_amount == 0, "Weakening is target-local: " + art)
			check(hero.art_uses[art] == mini(9999, uses + 1) and hero.art_rank == Catalog.rank_for_uses(mini(9999, uses + 1)), "Only accepted use earns capped proficiency: " + art)
			check(_events(tx, "proficiency")[0].amount == mini(9999, uses + 1) - uses, "Proficiency event reports actual earned delta, including zero at cap: " + art)
			check(source.art_uses[art] == uses, "Source proficiency untouched: " + art)
	var low = State.new()
	var exhausted = _arena(low, ["hero"], "training")
	var saved: Dictionary = exhausted.snapshot()
	check(not exhausted.accept_action("art:" + Arts.BASE_ART, "puheng").ok and exhausted.snapshot() == saved, "Natural initial qi cannot pay martial cost; rejection is atomic")
	_step(exhausted, "guard")
	check(exhausted.action_unavailable_reason("art:" + Arts.BASE_ART, "puheng").is_empty(), "Genuine guard restores enough initial qi")


func _test_healing_and_shared_medicine() -> void:
	var source = _source()
	var rules = _arena(source, ["hero", "shen", "tang"], "heting_receipt", {"shen": {"hp": 30}})
	check(rules.select_actor("shen"), "Select own healer turn")
	check(rules.available_actions()[1].available and rules.available_actions()[1].valid_target_ids.has("hero"), "Heal can be selected while an enemy is selected")
	var before: Dictionary = rules.snapshot()
	check(not rules.accept_action(Catalog.SHEN_ART, "striker").ok and not rules.accept_action(Catalog.SHEN_ART, "tang").ok and rules.snapshot() == before, "Healing rejects enemies and full-health allies atomically")
	var tx: Dictionary = _step(rules, Catalog.SHEN_ART, "hero")
	check(_actor(tx.after, "hero").hp == 178 and _actor(tx.after, "shen").hp == 30 and _actor(tx.after, "shen").qi == 3, "Chosen heal uses Shen qi and heals requested living ally only")
	check(_events(tx, "heal")[0].source_id == "shen" and _events(tx, "heal")[0].target_id == "hero", "Heal animation event identifies both actors")
	var medicine: Dictionary = _step(rules, "item")
	check(medicine.after.medicine == source.medicine - 1 and _actor(medicine.after, "hero").hp == 223, "Hero uses one shared medicine at normal sect strength")
	check(rules.select_actor("tang"), "Other unspent ally remains selectable")
	_step(rules, "guard")
	rules.select_actor("shen")
	var shen_medicine: Dictionary = _step(rules, "item")
	check(shen_medicine.after.medicine == source.medicine - 2 and _actor(shen_medicine.after, "shen").hp == 75, "Companion medicine heals active companion from same shared supply")
	var care = _source("青灯续脉")
	care.shen_care_stage = 5
	care.shen_care_choice = "mobile"
	var mobile = _arena(care)
	mobile.select_actor("shen")
	check(mobile.action_description(Catalog.SHEN_ART).contains("30"), "Earned mobile healing amount is exposed truthfully")
	var healed: Dictionary = _step(mobile, Catalog.SHEN_ART, "hero")
	check(_actor(healed.after, "hero").hp == 180, "Earned mobile benefit adds 2 to selected heal, without auto-assist")
	var sect_medicine: Dictionary = _step(mobile, "item")
	check(_actor(sect_medicine.after, "hero").hp == 235 and sect_medicine.after.medicine_heal == 55, "Existing 照野堂 medicine effect is preserved")
	care.shen_care_choice = "shore"
	var shore: Dictionary = Catalog.build_team(care, ["hero", "shen"]).team
	check(shore.actors[1].defense == 4 and shore.actors[1].care_defense_bonus == 1, "Earned shore care adds Shen personal defense exactly once")
	var empty = _source()
	empty.medicine = 0
	var no_medicine = _arena(empty)
	check(not no_medicine.accept_action("item").ok, "Empty shared supply rejects medicine without acting")
	for bonus: int in [0, 2]:
		var capped_source = _source()
		capped_source.hp = capped_source.max_hp - 1
		capped_source.shen_care_stage = 5 if bonus == 2 else 0
		capped_source.shen_care_choice = "mobile" if bonus == 2 else ""
		var capped = _arena(capped_source)
		capped.select_actor("shen")
		var maximum: int = 28 + bonus
		var one: String = capped.action_description(Catalog.SHEN_ART, "hero")
		check(one.contains("恢复1气血（最多%d）" % maximum), "Explicit living ally description caps healing to actual missing HP")
		capped.select_target("hero")
		check(capped.action_description(Catalog.SHEN_ART) == one and capped.available_actions()[1].description == one, "Selected target and authoritative descriptor expose identical capped healing")
		var full: String = capped.action_description(Catalog.SHEN_ART, "tang")
		check(full.contains("恢复0气血（最多%d）" % maximum) and full.contains("气血充盈"), "Full-health ally description truthfully reports zero and reason")
		for target: String in ["striker", "missing"]:
			var unavailable: String = capped.action_description(Catalog.SHEN_ART, target)
			check(unavailable.contains("最多恢复%d" % maximum) and unavailable.contains("请先选择仍站立的队友"), "Wrong-team/missing target description states maximum and requires living ally selection")
		var actual_heal: Dictionary = _step(capped, Catalog.SHEN_ART, "hero")
		check(_events(actual_heal, "heal")[0].amount == 1, "Capped healing preview matches accepted event amount")
		var down = _arena(capped_source, ["hero", "shen"], "story", {"hero": {"hp": 0}})
		var dead_description: String = down.action_description(Catalog.SHEN_ART, "hero")
		check(dead_description.contains("最多恢复%d" % maximum) and dead_description.contains("请先选择仍站立的队友") and dead_description.contains("不能救起"), "Downed ally description states selection requirement and no revival")


func _test_formation_and_death() -> void:
	for formation: String in ["并肩", "护后"]:
		var source = _source()
		source.formation = formation
		var rules = _arena(source, ["hero", "shen"], "story")
		check(rules.snapshot().enemy_intents[0].target_id == "hero", "First announced front is hero: " + formation)
		check(_actor(rules.snapshot(), "hero").front and _actor(rules.snapshot(), "shen").front == (formation == "并肩"), "Stable formation row is distinct from next exposed receiver: " + formation)
		_step(rules, "guard")
		var first: Dictionary = _step(rules, "guard")
		check(_events(first, "damage", "enemy")[0].target_id == "hero" and _events(first, "damage", "enemy")[0].amount == 2, "Guard receives actual first-round damage at ceil30percent")
		check(first.after.enemy_intents[0].target_id == ("shen" if formation == "并肩" else "hero"), "Formation changes announced receiver for next round: " + formation)
		check(_actor(first.after, "hero").front and _actor(first.after, "shen").front == (formation == "并肩") and _actor(first.after, "shen").exposed == (formation == "并肩"), "Target rotation changes exposure without moving formation rows: " + formation)
		_step(rules, "guard")
		var second: Dictionary = _step(rules, "guard")
		check(_events(second, "damage", "enemy")[0].target_id == ("shen" if formation == "并肩" else "hero"), "Execution matches announced formation target: " + formation)
	var source = _source()
	source.formation = "护后"
	var rules = _arena(source, ["hero", "shen"], "heting_receipt", {"hero": {"hp": 1}, "shen": {"hp": 1}})
	_step(rules, "attack", "bracer")
	var fell: Dictionary = _step(rules, "attack", "bracer")
	check(fell.after.active and _actor(fell.after, "hero").hp == 0 and fell.after.active_actor_id == "shen", "Hero down does not end battle; first living unspent companion continues")
	check(not rules.select_actor("hero") and not rules.select_target("hero"), "Downed actor cannot act or be selected as live target")
	var before: Dictionary = rules.snapshot()
	check(rules.action_description(Catalog.SHEN_ART).contains("不能救起") and not rules.accept_action(Catalog.SHEN_ART, "hero").ok and rules.snapshot() == before, "No in-battle revival; rejected heal explains and preserves resources")
	var defeated: Dictionary = _step(rules, "attack", "bracer")
	check(defeated.after.outcome == "defeat" and _actor(defeated.after, "shen").hp == 0 and _events(defeated, "damage", "enemy")[0].amount == 1, "Only all-down causes defeat; overkill reports real HP removed")
	var survivors = _arena(source, ["hero", "shen"], "training", {"hero": {"hp": 0}})
	check(survivors.snapshot().active_actor_id == "shen", "Previously downed hero is skipped at configure if companion lives")
	var won: Dictionary = _play(survivors)
	check(won.outcome == "win" and _actor(won, "hero").hp == 0, "Companion can win while hero remains down; no hidden recovery")
	var all_down: Dictionary = Catalog.build_team(source, ["hero", "shen"], {"hero": {"hp": 0}, "shen": {"hp": 0}})
	check(not Rules.new().configure(all_down.team, "story"), "All-down team cannot start a fresh battle")


func _test_protector_and_effects() -> void:
	var source = _source("伏汐藏锋")
	var rules = _arena(source, ["hero", "shen"])
	var focus: Dictionary = _step(rules, "art:伏汐藏锋", "striker")
	check(_events(focus, "damage", "ally")[0].amount == 11 and _actor(focus.after, "hero").status.focused_damage == 34, "Protector halves focus art direct hit, preserving earned focus")
	_step(rules, "guard")
	var strike: Dictionary = _step(rules, "attack", "striker")
	check(_events(strike, "damage", "ally")[0].amount == 25 and _actor(strike.after, "hero").status.focused_damage == 0, "Next own basic attack consumes focus then halves per-hit damage")
	var weak = _arena(_source(), ["hero", "tang"])
	weak.select_actor("tang")
	_step(weak, Catalog.TANG_ART, "striker")
	var reply: Dictionary = _step(weak, "guard")
	check(_events(reply, "damage", "enemy")[0].amount == 4 and _enemy(reply.after, "striker").status.weaken_strikes == 1, "Target weaken applies before guard rounding and consumes actual enemy attack")
	_step(weak, "guard")
	var second: Dictionary = _step(weak, "guard")
	check(_enemy(second.after, "striker").status.weaken_strikes == 0 and _enemy(second.after, "striker").status.weaken_amount == 0, "Target weakening expires after its second executed attack")
	var strong = _source()
	strong.attack = 400
	var protector = _arena(strong, ["hero", "shen"])
	var kill: Dictionary = _step(protector, "attack", "striker")
	check(_enemy(kill.after, "striker").hp == 0 and kill.after.enemy_intents[1].type == "protect", "Defeated striker does not invent unannounced protector attack")
	check(_actor(kill.after, "hero").front and _actor(kill.after, "shen").front and not _actor(kill.after, "hero").exposed and not _actor(kill.after, "shen").exposed, "Dead striker cannot expose allies; protect-only bracer leaves stable front row without threatened targets")
	var pause: Dictionary = _step(protector, "guard")
	check(_events(pause, "damage", "enemy").is_empty() and pause.after.enemy_intents[0].source_id == "bracer" and pause.after.enemy_intents[0].type == "attack", "Protector's first attack is announced only next round")
	var brace = _arena(_source(), ["hero", "shen", "tang"])
	var initial: Dictionary = _step(brace, "attack", "striker")
	check(_events(initial, "damage", "ally")[0].amount == 8, "Live protector halves hero basic attack")
	var rounds: int = 0
	while brace.snapshot().active and _enemy(brace.snapshot(), "bracer").hp > 0 and rounds < 30:
		_step(brace, "attack", "bracer")
		rounds += 1
	check(_enemy(brace.snapshot(), "bracer").hp == 0 and not _enemy(brace.snapshot(), "striker").brace, "Protection ends immediately when protector falls")
	var chosen: Dictionary = _actor(brace.snapshot(), brace.snapshot().active_actor_id)
	var uncovered: Dictionary = _step(brace, "attack", "striker")
	check(_events(uncovered, "damage", "ally")[0].amount == chosen.attack, "Next attack receives no stale protection")


func _play(rules) -> Dictionary:
	for action_index: int in 160:
		var state: Dictionary = rules.snapshot()
		if not state.active:
			return state
		var actor: Dictionary = _actor(state, state.active_actor_id)
		var target: String = ""
		for enemy: Dictionary in state.enemies:
			if enemy.hp > 0 and (target.is_empty() or enemy.id == "bracer"):
				target = enemy.id
		var chosen: String = "attack"
		var selected_target: String = target
		if actor.hp < mini(45, int(actor.max_hp / 2)) and state.medicine > 0:
			chosen = "item"
			selected_target = ""
		else:
			for action: Dictionary in actor.actions:
				if action.category != "martial" or not action.available:
					continue
				if action.target_team == "ally":
					for candidate: String in action.valid_target_ids:
						var friend: Dictionary = _actor(state, candidate)
						if int(friend.max_hp) - int(friend.hp) >= 28:
							chosen = action.id
							selected_target = candidate
				else:
					chosen = action.id
		_step(rules, chosen, selected_target)
	check(false, "Natural combat reaches terminal outcome within 160 accepted actions")
	return rules.snapshot()


func _test_natural_opening() -> void:
	for roster: Array in [["hero"], ["hero", "shen"]]:
		for encounter: String in ["story", "training"]:
			var source = State.new()
			if roster.size() == 2:
				source.recruit_companion()
			var before: Dictionary = source.to_dict().duplicate(true)
			var result: Dictionary = _play(_arena(source, roster, encounter))
			check(result.outcome == "win", "Unboosted early loadout wins via legal actions: " + str(roster) + " / " + encounter)
			check(source.to_dict() == before, "Natural fight does not settle rewards/source resources itself")


func _choose(index: int = 0) -> void:
	check(index < app.modal_actions.size(), "Earned journey exposes requested real dialogue choice")
	if index < app.modal_actions.size():
		app.modal_actions[index].call()


func _interact(id: String) -> void:
	if app.active_modal:
		app._close_modal()
	app._interact(id)


func _legacy_fight() -> void:
	check(app.state.battle_active, "Earned journey starts real prerequisite combat")
	for index: int in 120:
		if not app.state.battle_active:
			break
		if app.state.hp < 45 and app.state.medicine > 0:
			app._battle_action("item")
		elif app.state.turn % 2 == 1:
			app._battle_action("skill" if app.state.qi >= app.state.active_art_cost() and app.state.skill_cooldown == 0 else "guard")
		else:
			app._battle_action("attack")
	check(not app.state.battle_active and app.state.enemy_hp == 0, "Natural prerequisite fight won without injected resources")
	if app.active_modal:
		app._close_modal()


func _test_earned_three_party() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.state = JourneyState.new()
	root.add_child(app)
	await process_frame
	app._new_game()
	_interact("elder"); _choose()
	_interact("herb"); _choose()
	_interact("healer"); _choose()
	_interact("healer"); _choose()
	_interact("bandit"); _choose(); _legacy_fight()
	_interact("elder"); _choose(); _choose(0)
	app._show_inventory(); _choose(2); app._close_modal()
	_interact("mentor"); _choose(); _legacy_fight()
	_interact("mentor"); _choose()
	_interact("exit_sluice"); _choose()
	_interact("stranded_boatman"); _choose(); app._close_modal()
	_interact("ledger_runner"); _choose(); _legacy_fight()
	_interact("sluice_cache"); _choose()
	_interact("sluice_boss"); _choose(); _legacy_fight()
	_interact("exit_frostbridge"); _choose()
	_interact("chapter_clerk"); _choose()
	_interact("chapter_inscription"); _choose()
	_interact("chapter_host"); _choose()
	_interact("chapter_archive"); _choose(2); _choose(0); _choose(1)
	_choose(); _legacy_fight()
	_interact("chapter_host"); _choose(0)
	_interact("frost_timber"); _choose()
	_interact("bridge_worker"); _choose()
	_interact("bridge_worker"); _choose()
	_interact("return_sluice")
	_interact("sluice_cache"); _choose()
	_interact("exit_frostbridge"); _choose()
	_interact("bridge_worker"); _choose(0); _choose()
	check(app.state.tangqi_unlocked and app.state.companion_unlocked and app.state.level >= 3, "Actual opening, archive and Tang quest earn both companions and later stats")
	var original: Dictionary = app.state.to_dict().duplicate(true)
	for formation: String in ["并肩", "护后"]:
		app.state.set_formation(formation)
		var source: Dictionary = app.state.to_dict().duplicate(true)
		var built: Dictionary = Catalog.build_team(app.state, ["hero", "shen", "tang"])
		check(built.ok, "Earned selected three-person roster builds exact detached team")
		var rules = Rules.new()
		check(rules.configure(built.team, "heting_receipt"), "Exact earned team configures receipt encounter")
		var result: Dictionary = _play(rules)
		check(result.outcome == "win", "Earned later three-party loadout wins real two-enemy receipt: " + formation)
		if result.outcome == "win":
			_capture_demo_team(built.team, app.state.level, result)
		check(app.state.to_dict() == source, "Earned journey resources, rewards and progression remain untouched")
		print("PARTY JOURNEY: level=%d formation=%s hp=%d/%d rounds=%d medicines=%d outcome=%s" % [app.state.level, formation, app.state.hp, app.state.max_hp, result.round, result.medicine, result.outcome])
	app.state.set_formation(original.formation)
	check(app.state.to_dict() == original, "All natural party probes preserve exact earned source")
	app._stop_audio()
	await create_timer(0.25).timeout
	app.queue_free()
	await process_frame


func _capture_demo_team(team: Dictionary, level: int, result: Dictionary) -> void:
	# Optional reproducible study fixture, never a player save. Default tests write
	# no fixture. JSON readers must restore integral numeric fields to int before
	# configure(), whose strict validation deliberately rejects parsed floats.
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--party-demo-output="):
			directory = argument.trim_prefix("--party-demo-output=")
	if directory.is_empty():
		return
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	check(error == OK, "Optional generated test-team fixture directory is writable")
	if error != OK:
		return
	var suffix: String = "side_by_side" if team.formation == "并肩" else "protect_rear"
	var filename: String = "earned_level5_" + suffix + ".json"
	var file: FileAccess = FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	check(file != null, "Optional exact team fixture can be opened")
	if file == null:
		return
	file.store_string(JSON.stringify(team, "\t"))
	file.close()
	var hashes: Dictionary = {}
	for path: String in ["scripts/party_actor_catalog.gd", "scripts/party_combat_rules.gd", "scripts/game_state.gd", "scripts/main.gd", "tests/party_combat_rules_test.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var provenance: Dictionary = {
		"fixture": filename, "fixture_sha256": FileAccess.get_sha256(directory.path_join(filename)),
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source": "Generated JourneyState from a fresh game; no player save/profile data",
		"level": level, "formation": team.formation, "selected_actor_ids": ["hero", "shen", "tang"],
		"earned_route": "Actual opening elder/herb/healer recruitment and battle; 听潮阁 choice; earned sword purchase and sect trial; sluice route; archive clues/seals/boss/resolution; timber bridge repair; Tang notes/teach/recruit dialogue",
		"proof": {"encounter_id": "heting_receipt", "outcome": result.outcome, "rounds": result.round, "medicine_remaining": result.medicine},
		"source_sha256": hashes,
		"reload_note": "Godot JSON parses numbers as float. Recursively convert finite integral numeric values to int before PartyCombatRules.configure(team, 'heting_receipt'). Do not change stats or resources.",
	}
	var manifest: FileAccess = FileAccess.open(directory.path_join("provenance_" + suffix + ".json"), FileAccess.WRITE)
	check(manifest != null, "Optional fixture provenance can be opened")
	if manifest != null:
		manifest.store_string(JSON.stringify(provenance, "\t"))
		manifest.close()
