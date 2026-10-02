extends SceneTree
## Independent detached-model audit. No scenes, UI, save I/O, or publication.
## The settlement example checks the schema12 state integration order. Actual
## save migration and exact schema11-reader rejection live in party_state_integration_test.
const State = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Combat = preload("res://scripts/party_combat_rules.gd")
const Roster = preload("res://scripts/party_roster_rules.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME")
		quit(2)
		return
	_test_exact_events_and_descriptions()
	_test_exposure_after_attacker_falls()
	_test_rejected_configuration()
	_test_turn_permutations_and_stale_callbacks()
	_test_detachment_and_dead_healing()
	_test_settlement_then_level_gain()
	if failures == 0:
		print("PASS: %d independent party-model audit checks (amounts/exposure/setup/transactions/detachment/settlement ordering)" % checks)
	else:
		push_error("FAIL: %d of %d independent party-model audit checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _state():
	var state = State.new()
	state.companion_unlocked = true
	state.tangqi_unlocked = true
	state.active_companion = "唐栖"
	state.hp = 73
	state.qi = 6
	return state


func _model(state, ids: Array = ["hero", "shen", "tang"], resources: Dictionary = {}, encounter: String = "heting_receipt"):
	var built: Dictionary = Catalog.build_team(state, ids, resources)
	var combat = Combat.new()
	check(built.ok and combat.configure(built.team, encounter), "Independent fixture configures")
	return combat


func _actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id:
			return actor
	return {}


func _events(tx: Dictionary, kind: String, phase: String = "") -> Array:
	var result: Array = []
	for event: Dictionary in tx.get("events", []):
		if event.type == kind and (phase.is_empty() or event.phase == phase):
			result.append(event)
	return result


func _frozen(value: Variant) -> bool:
	if value is Dictionary:
		if not value.is_read_only():
			return false
		for key: Variant in value:
			if not _frozen(value[key]):
				return false
	elif value is Array:
		if not value.is_read_only():
			return false
		for entry: Variant in value:
			if not _frozen(entry):
				return false
	return not value is Object


func _test_exact_events_and_descriptions() -> void:
	for care: int in [0, 2]:
		for missing: int in [1, 27, 28, 29, 30, 31]:
			var state = _state()
			state.hp = state.max_hp - missing
			if care == 2:
				state.shen_care_stage = 5
				state.shen_care_choice = "mobile"
			var combat = _model(state)
			check(combat.select_actor("shen") and combat.select_target("hero"), "Select injured living recipient")
			var expected: int = mini(missing, 28 + care)
			var description: String = combat.action_description(Catalog.SHEN_ART, "hero")
			var tx: Dictionary = combat.accept_action(Catalog.SHEN_ART, "hero")
			check(tx.ok and description.contains("恢复%d气血" % expected), "Shen description reports accepted capped heal: missing=%d care=%d description=%s" % [missing, care, description])
			check(_events(tx, "heal")[0].amount == expected and _actor(tx.after, "hero").hp - state.hp == expected, "Heal event agrees with resource delta")
	for uses: int in [4, 14, 9998, 9999]:
		var state = _state()
		state.art_uses[Arts.BASE_ART] = uses
		var combat = _model(state)
		var tx: Dictionary = combat.accept_action("art:" + Arts.BASE_ART, "bracer")
		var earned: int = _actor(tx.after, "hero").art_uses[Arts.BASE_ART] - uses
		var advertised: int = 0
		for event: Dictionary in _events(tx, "proficiency"):
			advertised += int(event.amount)
		check(tx.ok and advertised == earned, "Proficiency events report actual earned delta at %d uses" % uses)


func _test_exposure_after_attacker_falls() -> void:
	for formation: String in ["并肩", "护后"]:
		var state = _state()
		state.formation = formation
		state.attack = 400
		var combat = _model(state, ["hero", "shen"])
		check(_actor(combat.snapshot(), "hero").exposed, "Live announced attacker exposes its recipient")
		var tx: Dictionary = combat.accept_action("attack", "striker")
		check(tx.ok and tx.after.active and tx.after.enemy_intents[1].type == "protect", "Defeated attacker leaves its surviving protector's announced role intact")
		check(_actor(tx.after, "hero").front and not _actor(tx.after, "hero").exposed and not _actor(tx.after, "shen").exposed, "Defeated attack source exposes nobody; formation row remains stable")
		check(combat.complete_presentation(tx.token), "Complete killing action presentation")
		var next: Dictionary = combat.accept_action("guard")
		check(_events(next, "damage", "enemy").is_empty(), "No unannounced attack from surviving protector this round")


func _test_rejected_configuration() -> void:
	var state = _state()
	var valid: Dictionary = Catalog.build_team(state, ["hero", "shen"]).team
	var patches: Array = [
		{"actors": []}, {"actors": [null]}, {"formation": "unknown"},
		{"medicine": -1}, {"medicine": 1.5}, {"medicine_heal": 46},
	]
	for patch: Dictionary in patches:
		var bad: Dictionary = valid.duplicate(true)
		bad.merge(patch, true)
		_rejected_then_valid(bad, valid)
	for patch: Dictionary in [{"id": "shen"}, {"hp": -1}, {"hp": 101}, {"max_hp": 0}, {"qi": 7}, {"attack": 0}, {"defense": -1}, {"name": 1}, {"equipped_art": "unknown"}, {"art_uses": {Arts.BASE_ART: 1.5}}, {"care_healing_bonus": 1}]:
		var bad: Dictionary = valid.duplicate(true)
		bad.actors[0].merge(patch, true)
		_rejected_then_valid(bad, valid)
	var all_down: Dictionary = valid.duplicate(true)
	for actor: Dictionary in all_down.actors:
		actor.hp = 0
	_rejected_then_valid(all_down, valid)


func _rejected_then_valid(bad: Dictionary, valid: Dictionary) -> void:
	var combat = Combat.new()
	var pristine: Dictionary = combat.snapshot()
	var input_copy: Dictionary = bad.duplicate(true)
	check(not combat.configure(bad) and combat.snapshot() == pristine and bad == input_copy, "Invalid setup preserves exact unconfigured state and caller input")
	check(combat.configure(valid) and combat.snapshot().actors.size() == 2, "Invalid setup neither consumes configuration nor leaves partial actors")


func _test_turn_permutations_and_stale_callbacks() -> void:
	for order: Array in [["hero", "shen", "tang"], ["hero", "tang", "shen"], ["shen", "hero", "tang"], ["shen", "tang", "hero"], ["tang", "hero", "shen"], ["tang", "shen", "hero"]]:
		var state = _state()
		var original: Dictionary = state.to_dict()
		var combat = _model(state)
		var old_token: int = -1
		for index: int in range(3):
			var id: String = order[index]
			check(combat.select_actor(id), "Every chosen unspent ally can act in any order")
			var tx: Dictionary = combat.accept_action("attack", "bracer")
			check(tx.ok and _events(tx, "damage", "ally").size() == 1 and _events(tx, "damage", "ally")[0].source_id == id, "Exactly chosen actor attacks with no legacy automatic assist")
			check(_events(tx, "damage", "enemy").size() == (1 if index == 2 else 0), "Enemy phase waits for every living selected actor")
			var locked: Dictionary = combat.snapshot()
			check(not combat.accept_action("guard").ok and not combat.select_actor(id) and not combat.select_target("hero") and combat.snapshot() == locked, "Repeated action and selection cannot alter a pending transaction")
			check(not combat.complete_presentation(old_token) and combat.snapshot() == locked, "Earlier presentation token cannot release a later transaction")
			check(combat.complete_presentation(tx.token) and not combat.complete_presentation(tx.token), "Only current token completes once")
			old_token = tx.token
			if index < 2:
				check(not combat.select_actor(id), "Spent actor cannot be selected again before enemy phase")
		check(state.to_dict() == original, "Permutation never mutates source counters or resources")
		var before_bad: Dictionary = combat.snapshot()
		for pair: Array in [["attack", "hero"], ["guard", "shen"], ["flee", "bracer"], ["missing", "bracer"], ["attack", "missing"]]:
			check(not combat.accept_action(pair[0], pair[1]).ok and combat.snapshot() == before_bad, "Invalid action/target cannot spend a turn, resource, or cooldown")


func _test_detachment_and_dead_healing() -> void:
	var state = _state()
	var team: Dictionary = Catalog.build_team(state, ["hero", "shen", "tang"], {"hero": {"hp": 0}}).team.duplicate(true)
	team.ignored_source = state
	team.actors[1].ignored_source = state
	var combat = Combat.new()
	check(combat.configure(team), "Ignored extra model references do not prevent detached setup")
	var reference: WeakRef = weakref(state)
	team.clear()
	state = null
	check(reference.get_ref() == null, "Configured model retains no source object from extra input fields")
	check(_frozen(combat.snapshot()), "Every nested snapshot container is frozen and contains no Object")
	var prior: Dictionary = combat.snapshot()
	check(prior.active_actor_id == "shen" and not combat.select_actor("hero"), "Downed hero neither acts nor blocks living companion")
	check(not combat.accept_action(Catalog.SHEN_ART, "hero").ok and combat.snapshot() == prior, "Healing downed hero cannot spend qi, cooldown, or turn")
	check(not combat.accept_action(Catalog.SHEN_ART, "striker").ok and combat.snapshot() == prior, "Healing wrong team rejects atomically")
	check(not combat.accept_action(Catalog.SHEN_ART, "tang").ok and combat.snapshot() == prior, "Healing full-health teammate rejects atomically")
	var tx: Dictionary = combat.accept_action("flee")
	check(tx.ok and _frozen(tx) and _actor(tx.after, "hero").hp == 0, "Retreat transaction is immutable and never silently revives hero")
	check(combat.complete_presentation(tx.token), "Terminal presentation may finish once")
	var terminal: Dictionary = combat.snapshot()
	check(not combat.accept_action("guard").ok and not combat.select_actor("shen") and combat.snapshot() == terminal, "Terminal actions cannot alter spent resources")


func _test_settlement_then_level_gain() -> void:
	var before = _state()
	before.hp = 7
	before.qi = 0
	before.xp = 59
	before.attack = 400
	var payload: Dictionary = Roster.load_plan(before, {"active_companion": "唐栖"}, 11).payload.duplicate(true)
	check(payload.party_roster == ["hero", "tang"], "Migration preserves legacy Tang choice")
	payload.party_roster = ["hero", "shen"]
	payload.party_resources.shen = {"hp": 12, "qi": 1}
	payload.party_resources.tang = {"hp": 0, "qi": 0}
	var projection: Dictionary = Roster.battle_resources(before, payload)
	var combat = _model(before, payload.party_roster, projection.resources, "training")
	var win: Dictionary = combat.accept_action("attack", "puheng")
	var terminal: Dictionary = {}
	for actor: Dictionary in win.after.actors:
		terminal[actor.id] = {"hp": actor.hp, "qi": actor.qi}
	check(win.after.outcome == "win" and terminal.size() == 2, "Actual terminal model yields every selected actor's resources")
	var settled: Dictionary = Roster.settle_plan(before, payload, terminal, "win")
	check(settled.ok and settled.hero_resources == terminal.hero and settled.payload.party_resources.shen == terminal.shen and settled.payload.party_resources.tang == payload.party_resources.tang, "Settlement conserves terminal selected and prior benched resources")
	# Integration order: accept terminal/epoch, clear battle gate, settle
	# resource plan, then award XP, then reconcile companion maxima. This does not
	# replace the independent state/save transaction tests.
	before.hp = settled.hero_resources.hp
	before.qi = settled.hero_resources.qi
	var after = _state()
	after.hp = before.hp
	after.qi = before.qi
	after.xp = before.xp
	after.attack = before.attack
	# The actual XP API now requires complete persistent party resources.
	after._apply_party_plan(Roster.load_plan(after, {"active_companion": after.active_companion}, 11))
	after.gain_xp(1)
	var grown: Dictionary = Roster.reconcile_growth(before, after, settled.payload)
	check(grown.ok and after.level == 2 and grown.hero_resources == {"hp": after.max_hp, "qi": after.max_qi}, "Settlement before earned XP preserves existing explicit level-up hero recovery")
	check(grown.payload.party_resources == settled.payload.party_resources, "Subsequent growth adds no companion healing, including benched HP0")
	check(Roster.select_roster(after, grown.payload, ["hero", "tang"]).payload.party_resources.tang.hp == 0, "Selection after growth cannot revive benched companion")
	var raw: Dictionary = grown.payload.duplicate(true)
	raw.hp = 0
	check(not Roster.load_plan(after, raw, 12).ok, "Schema12 raw hero HP0 cannot hide behind leveled normalized state")
	var incomplete: Dictionary = terminal.duplicate(true)
	incomplete.erase("shen")
	check(not Roster.settle_plan(before, payload, incomplete, "win").ok, "Terminal resources must include all selected actors")
	var extra: Dictionary = terminal.duplicate(true)
	extra.tang = {"hp": 1, "qi": 0}
	check(not Roster.settle_plan(before, payload, extra, "win").ok, "Benched actor cannot enter terminal roster")
	var living: Dictionary = {"hero": {"hp": 0, "qi": 0}, "shen": {"hp": 1, "qi": 0}}
	check(not Roster.settle_plan(before, payload, living, "defeat").ok, "Any living selected actor forbids defeat recovery")
	for outcome: String in ["win", "flee"]:
		var survivor: Dictionary = Roster.settle_plan(before, payload, living, outcome)
		check(survivor.ok and survivor.hero_resources == {"hp": 1, "qi": 0} and survivor.payload.party_resources.shen == living.shen and survivor.payload.party_resources.tang.hp == 0, "Only outside-battle win/flee applies hero HP1 with no companion resurrection")
	living.shen.hp = 0
	check(not Roster.settle_plan(before, payload, living, "win").ok and not Roster.settle_plan(before, payload, living, "flee").ok, "All selected down cannot claim win or flee")
	check(Roster.settle_plan(before, payload, living, "defeat").ok, "All-selected-down explicitly permits safe defeat recovery")
	check(State.SAVE_VERSION == 13 and before.to_dict().has("party_roster") and before.has_method("start_party_battle"), "Production schema13 exposes integrated party state; exact historical-reader rejection is checked by the filesystem integration suite")
