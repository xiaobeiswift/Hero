extends SceneTree
## Pure adapter checks: no save/load calls, FileAccess, user profile, or exports.
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/party_roster_rules.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
var checks: int = 0
var failures: int = 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func ready_state(shen: bool = true, tang: bool = true):
	var state = State.new()
	state.companion_unlocked = shen
	state.tangqi_unlocked = tang
	state.active_companion = "唐栖" if tang else ("沈青" if shen else "")
	state.hp = 17
	state.qi = 1
	return state


func actors_for(state) -> Dictionary:
	var roster: Array = ["hero"]
	if state.companion_unlocked:
		roster.append("shen")
	if state.tangqi_unlocked:
		roster.append("tang")
	var actors: Dictionary = {}
	for actor: Dictionary in Catalog.build_team(state, roster).team.actors:
		actors[actor.id] = actor
	return actors


func initial_payload(state) -> Dictionary:
	return Rules.load_plan(state, {}, 11).payload.duplicate(true)


func damaged_payload(state) -> Dictionary:
	var payload: Dictionary = initial_payload(state)
	payload.party_roster = ["hero", "shen"]
	payload.party_resources.shen = {"hp": 12, "qi": 0}
	payload.party_resources.tang = {"hp": 5, "qi": 1}
	return payload


func rejected(state, payload: Variant, label: String) -> void:
	var state_before: Dictionary = state.to_dict().duplicate(true)
	var payload_before: String = var_to_str(payload)
	var choice_before: String = state.active_companion
	var result: Dictionary = Rules.validate_payload(state, payload)
	check(not result.ok and not result.reason.is_empty(), label + " rejects with a reason")
	check(state.to_dict() == state_before and state.active_companion == choice_before and var_to_str(payload) == payload_before, label + " leaves caller input unchanged")
	check(result.payload.is_empty() and result.hero_resources.is_empty(), label + " returns no partial commit")


func _init() -> void:
	test_legacy_migration()
	test_strict_payloads()
	test_selection_and_projection()
	test_growth_and_recruitment()
	test_rest_and_settlement()
	if failures == 0:
		print("PASS: %d party roster/resource plan checks" % checks)
	else:
		push_error("FAIL: %d / %d party roster/resource plan checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func test_legacy_migration() -> void:
	for version: int in range(1, 12):
		for choice: String in ["沈青", "唐栖"]:
			var state = ready_state()
			state.active_companion = choice
			state.level = 7
			var before: Dictionary = state.to_dict()
			var data: Dictionary = {"active_companion": choice}
			var result: Dictionary = Rules.load_plan(state, data, version)
			var expected: String = "shen" if choice == "沈青" else "tang"
			check(result.ok and result.payload.party_roster == ["hero", expected], "Legacy%d preserves chosen %s without enrolling both" % [version, choice])
			check(result.payload.party_resources.size() == 2, "Legacy%d initializes selected and unselected recruited resources" % version)
			var actual: Dictionary = actors_for(state)
			for id: String in ["shen", "tang"]:
				check(result.payload.party_resources[id] == {"hp": actual[id].max_hp, "qi": actual[id].max_qi}, "Migration uses actual catalog maxima for " + id)
			check(result.hero_resources == {"hp": 17, "qi": 1} and not result.payload.party_resources.has("hero"), "Migration never heals or duplicates hero resources")
			check(state.to_dict() == before and data == {"active_companion": choice}, "Migration does not mutate source data or state")
	var fresh = ready_state(false, false)
	check(Rules.load_plan(fresh, {}, 1).payload == {"party_roster": ["hero"], "party_resources": {}}, "Unrecruited legacy save has no phantom companion")
	var tang_only = ready_state(false, true)
	tang_only.active_companion = ""
	check(Rules.load_plan(tang_only, {}, 3).payload.party_roster == ["hero", "tang"], "Legacy first-available fallback uses the actual recruited companion")
	var both = ready_state()
	both.active_companion = ""
	check(Rules.load_plan(both, {}, 11).payload.party_roster == ["hero", "shen"], "Legacy empty active choice keeps the old normalized fallback")
	check(Rules.load_plan(both, {"active_companion": "唐栖"}, 11).payload.party_roster == ["hero", "tang"], "An explicit saved Tang choice wins over default normalized selection")
	var payload: Dictionary = initial_payload(both)
	payload.party_roster = ["hero"]
	for version: int in [12, 13]:
		check(Rules.load_plan(both, payload, version).payload.party_roster == ["hero"], "Schema%d explicit empty companion selection survives loading" % version)
	check(both.Companions.active(both).is_empty(), "Modern explicit hero-only roster remains empty; only legacy load_plan uses historical fallback")
	check(Rules.load_plan(both, payload, 11).payload.party_roster == ["hero"], "Complete optional legacy payload is validated instead of discarded/rehealed")
	for version: Variant in [0, 14, 1.5, true, "13", null, NAN, INF]:
		check(not Rules.load_plan(both, payload, version).ok, "Bad source version rejects: " + str(version))
	for version: int in range(1, 14):
		for key: String in Rules.PARTY_KEYS:
			var partial: Dictionary = payload.duplicate(true)
			partial.erase(key)
			check(not Rules.load_plan(both, partial, version).ok, "Partial party pair rejects in version%d" % version)
	check(not Rules.load_plan(both, {}, 12).ok, "Schema12 requires both party fields")
	check(not Rules.load_plan(both, null, 12).ok, "Non-object player payload rejects")
	check(not Rules.load_plan(both, {"active_companion": 5}, 11).ok, "Malformed legacy active choice rejects")
	for key: String in ["hp", "qi"]:
		for value: Variant in [-1, 0.5, NAN, INF, true, "1", int(both.get("max_" + key)) + 1]:
			var raw: Dictionary = payload.duplicate(true)
			raw[key] = value
			check(not Rules.load_plan(both, raw, 12).ok, "Raw schema12 hero resource rejects before old normalization: " + key)
	var raw_zero: Dictionary = payload.duplicate(true)
	raw_zero.hp = 0
	check(not Rules.load_plan(both, raw_zero, 12).ok and both.hp == 17, "Raw schema12 hero0 cannot hide behind an already positive normalized candidate")
	check(Rules.load_plan(both, raw_zero, 11).ok, "Legacy core normalization remains a deliberate old-reader compatibility policy")
	both.hp = 0
	check(not Rules.load_plan(both, payload, 12).ok and both.hp == 0, "Loader rejects hero0 without silently healing it")


func test_strict_payloads() -> void:
	var state = ready_state()
	var payload: Dictionary = damaged_payload(state)
	var valid: Dictionary = Rules.validate_payload(state, payload)
	check(valid.ok and valid.payload == payload, "Damaged recruited members form a valid complete payload")
	check(valid.is_read_only() and valid.payload.is_read_only() and valid.payload.party_roster.is_read_only() and valid.payload.party_resources.is_read_only() and valid.payload.party_resources.shen.is_read_only() and valid.hero_resources.is_read_only(), "All returned commit data is deeply immutable")
	payload.party_resources.shen.hp = 11
	check(valid.payload.party_resources.shen.hp == 12, "Caller changes cannot alter an earlier returned plan")
	var from_json: Variant = JSON.parse_string(JSON.stringify(payload))
	var normalized: Dictionary = Rules.validate_payload(state, from_json)
	check(normalized.ok and normalized.payload == payload and normalized.payload.party_resources.shen.hp is int, "JSON whole-number floats normalize to canonical integers")
	for shape: Variant in [null, [], "bad", {}, {"party_roster": ["hero"]}, {"party_resources": {}}]:
		rejected(state, shape, "Malformed payload " + str(shape))
	for roster: Variant in [[], ["shen", "hero"], ["hero", "hero"], ["hero", "shen", "shen"], ["hero", "ghost"], ["hero", "沈青"], ["hero", null], ["hero", 1], ["hero", "shen", "tang", "hero"], "hero"]:
		var bad: Dictionary = payload.duplicate(true)
		bad.party_roster = roster
		rejected(state, bad, "Malformed roster " + str(roster))
	var extra: Dictionary = payload.duplicate(true)
	extra.active_companion = "沈青"
	rejected(state, extra, "Unknown payload field")
	for resources: Variant in [null, [], {}, {"shen": {"hp": 1, "qi": 0}}, {"shen": {"hp": 1, "qi": 0}, "tang": {"hp": 2, "qi": 1}, "hero": {"hp": 17, "qi": 1}}, {"shen": {"hp": 1, "qi": 0}, "tang": {"hp": 2, "qi": 1}, "ghost": {"hp": 1, "qi": 1}}]:
		var bad: Dictionary = payload.duplicate(true)
		bad.party_resources = resources
		rejected(state, bad, "Incomplete/extra/invalid resource map")
	for entry: Variant in [null, [], {"hp": 5}, {"qi": 2}, {"hp": 5, "qi": 2, "max_hp": 999}, {1: 2, "qi": 1}]:
		var bad: Dictionary = payload.duplicate(true)
		bad.party_resources.shen = entry
		rejected(state, bad, "Malformed resource entry")
	var actors: Dictionary = actors_for(state)
	for id: String in ["shen", "tang"]:
		for key: String in ["hp", "qi"]:
			for amount: Variant in [-1, 0.5, 1e100, NAN, INF, -INF, "1", true, null, int(actors[id]["max_" + key]) + 1]:
				var bad: Dictionary = payload.duplicate(true)
				bad.party_resources[id][key] = amount
				rejected(state, bad, "Bad %s.%s %s" % [id, key, str(amount)])
	var solo = ready_state(false, false)
	rejected(solo, payload, "Unrecruited actors cannot persist or deploy")
	check(not Rules.validate_payload(null, payload).ok, "Missing state rejects")
	state.hp = state.max_hp + 1
	rejected(state, payload, "Hero over-max resource is not silently catalog-clamped")
	state.hp = 17
	state.qi = -1
	rejected(state, payload, "Negative hero qi rejects")


func test_selection_and_projection() -> void:
	var state = ready_state()
	var payload: Dictionary = damaged_payload(state)
	var state_before: Dictionary = state.to_dict()
	for roster: Array in [["hero"], ["hero", "tang"], ["hero", "shen", "tang"], ["hero", "tang", "shen"], ["hero", "shen"]]:
		var changed: Dictionary = Rules.select_roster(state, payload, roster)
		check(changed.ok and changed.payload.party_roster == roster, "Explicit selection supports zero/one/two companions and order")
		check(changed.payload.party_resources == payload.party_resources and changed.hero_resources == {"hp": 17, "qi": 1}, "Selection conserves selected and benched hp/qi exactly")
		var projected: Dictionary = Rules.battle_resources(state, changed.payload)
		check(projected.ok and projected.resources.size() == roster.size(), "Combat projection includes precisely selected IDs")
		var team: Dictionary = Catalog.build_team(state, roster, projected.resources)
		check(team.ok and team.team.actors.size() == roster.size(), "Filtered projection interoperates with actual strict catalog")
		for actor: Dictionary in team.team.actors:
			check(actor.hp == projected.resources[actor.id].hp and actor.qi == projected.resources[actor.id].qi, "Battle starts with actual persisted resource for " + actor.id)
	check(state.to_dict() == state_before, "Selection and projection never mutate production state")
	var current: Dictionary = payload
	for iteration: int in range(20):
		current = Rules.select_roster(state, current, ["hero"]).payload
		current = Rules.select_roster(state, current, ["hero", "shen"]).payload
	check(current == payload, "Repeated deselect/reselect has no resource gain")
	payload.party_resources.shen.hp = 0
	var selected: Dictionary = Rules.select_roster(state, payload, ["hero", "shen", "tang"])
	check(selected.ok and selected.payload.party_resources.shen.hp == 0, "Selection does not resurrect a downed companion")
	state.battle_active = true
	var input_before: Dictionary = payload.duplicate(true)
	check(not Rules.select_roster(state, payload, ["hero"]).ok, "In-battle roster mutation rejects")
	check(not Rules.rest_plan(state, payload).ok, "In-battle rest rejects")
	check(not Rules.load_plan(state, payload, 12).ok, "In-battle load plan rejects")
	check(not Rules.reconcile_growth(state, ready_state(), payload).ok, "In-battle old-state growth rejects")
	check(not Rules.reconcile_growth(ready_state(), state, payload).ok, "In-battle new-state growth rejects")
	check(payload == input_before and state.hp == 17 and state.qi == 1, "Rejected in-battle operations cannot heal or change resources")


func test_growth_and_recruitment() -> void:
	var before = ready_state()
	var after = ready_state()
	var payload: Dictionary = damaged_payload(before)
	payload.party_resources.shen.hp = 0
	var before_snapshot: Dictionary = before.to_dict()
	var payload_snapshot: Dictionary = payload.duplicate(true)
	# The actual schema12 XP API requires a complete persistent party. Model
	# this fixture as an explicitly migrated legacy state before exercising it.
	after._apply_party_plan(Rules.load_plan(after, {"active_companion": after.active_companion}, 11))
	after.gain_xp(after.xp_to_next())
	var grown: Dictionary = Rules.reconcile_growth(before, after, payload)
	check(grown.ok and actors_for(after).shen.max_hp > actors_for(before).shen.max_hp, "Actual level-up increases catalog companion maxima")
	check(grown.payload == payload, "Level growth preserves absolute companion HP/qi, including downed and benched members")
	check(grown.hero_resources == {"hp": after.max_hp, "qi": after.max_qi}, "Existing explicit gain_xp hero heal stays an upstream choice")
	check(before.to_dict() == before_snapshot and payload == payload_snapshot, "Growth does not mutate old state or source payload")
	var rebuilt = ready_state()
	rebuilt.level = 2
	rebuilt.max_hp += 12
	check(Rules.reconcile_growth(before, rebuilt, payload).hero_resources == {"hp": 17, "qi": 1}, "A max-stat rebuild alone does not heal the hero")
	var rested: Dictionary = Rules.rest_plan(after, grown.payload)
	check(rested.ok and rested.payload.party_resources.shen.hp == actors_for(after).shen.max_hp, "Later explicit rest uses the increased maxima")
	var high = ready_state()
	high.level = 8
	var full_high: Dictionary = initial_payload(high)
	var low = ready_state()
	check(not Rules.validate_payload(low, full_high).ok, "Save validation rejects values above current maxima without hidden clamps")
	var reduced: Dictionary = Rules.reconcile_growth(high, low, full_high)
	check(reduced.ok and reduced.payload.party_resources.shen.hp == actors_for(low).shen.max_hp and reduced.payload.party_resources.tang.hp == actors_for(low).tang.max_hp, "Explicit stat reduction caps resources at actual new maxima")
	var none = ready_state(false, false)
	var shen = ready_state(true, false)
	var empty: Dictionary = initial_payload(none)
	var newly_shen: Dictionary = Rules.reconcile_growth(none, shen, empty)
	check(newly_shen.ok and newly_shen.payload.party_roster == ["hero"] and newly_shen.payload.party_resources.shen.hp == actors_for(shen).shen.max_hp, "Recruitment creates only the new member at actual maxima without autoselection")
	var shen_damaged: Dictionary = newly_shen.payload.duplicate(true)
	shen_damaged.party_resources.shen = {"hp": 3, "qi": 0}
	var both = ready_state()
	var newly_tang: Dictionary = Rules.reconcile_growth(shen, both, shen_damaged)
	check(newly_tang.ok and newly_tang.payload.party_resources.shen == {"hp": 3, "qi": 0} and newly_tang.payload.party_resources.tang.hp == actors_for(both).tang.max_hp, "Later recruitment preserves an injured unselected member")
	check(newly_tang.payload.party_roster == ["hero"], "Recruiting another actor preserves explicit no-companion selection")
	check(not Rules.reconcile_growth(both, shen, newly_tang.payload).ok, "Growth path cannot erase recruited actor history")
	var lost_damage: Dictionary = newly_tang.payload.duplicate(true)
	lost_damage.party_resources.erase("shen")
	check(not Rules.reconcile_growth(both, both, lost_damage).ok, "Missing existing resources cannot masquerade as new recruitment healing")


func test_rest_and_settlement() -> void:
	var state = ready_state()
	var payload: Dictionary = damaged_payload(state)
	payload.party_resources.tang.hp = 0
	var original: Dictionary = payload.duplicate(true)
	var actors: Dictionary = actors_for(state)
	var rested: Dictionary = Rules.rest_plan(state, payload)
	check(rested.ok and rested.hero_resources == {"hp": state.max_hp, "qi": state.max_qi}, "Free rest refills actual hero HP/qi")
	for id: String in ["shen", "tang"]:
		check(rested.payload.party_resources[id] == {"hp": actors[id].max_hp, "qi": actors[id].max_qi}, "Free rest restores recruited selected/benched/downed " + id)
	check(rested.payload.party_roster == payload.party_roster and payload == original and state.hp == 17, "Rest returns a detached plan without selecting or mutating")
	for outcome: String in ["win", "flee"]:
		var terminal: Dictionary = {"hero": {"hp": 0, "qi": 0}, "shen": {"hp": 1, "qi": 2}}
		state.hp = 0
		state.qi = 0
		state.battle_active = true
		check(not Rules.settle_plan(state, payload, terminal, outcome).ok and state.hp == 0, "Active %s cannot invoke outside-battle hero floor" % outcome)
		state.battle_active = false
		var settled: Dictionary = Rules.settle_plan(state, payload, terminal, outcome)
		check(settled.ok and settled.hero_resources == {"hp": 1, "qi": 0}, "%s with a surviving ally explicitly settles downed hero at HP1" % outcome)
		check(settled.payload.party_resources.shen == {"hp": 1, "qi": 2} and settled.payload.party_resources.tang == payload.party_resources.tang, "%s keeps spent qi and benched injuries" % outcome)
		check(state.hp == 0 and terminal.hero.hp == 0 and payload == original, "Settlement never mutates model, caller, or terminal snapshots")
	var hero_survives: Dictionary = {"hero": {"hp": 7, "qi": 1}, "shen": {"hp": 0, "qi": 0}}
	var survived: Dictionary = Rules.settle_plan(state, payload, hero_survives, "win")
	check(survived.ok and survived.hero_resources.hp == 7 and survived.payload.party_resources.shen.hp == 0, "Victory does not refill living hero or revive downed companion")
	var wipe: Dictionary = {"hero": {"hp": 0, "qi": 5}, "shen": {"hp": 0, "qi": 0}}
	var defeat: Dictionary = Rules.settle_plan(state, payload, wipe, "defeat")
	check(defeat.ok and defeat.hero_resources == {"hp": state.max_hp, "qi": 5}, "All-selected defeat restores hero HP and preserves qi above floor2")
	check(defeat.payload.party_resources.shen == {"hp": actors.shen.max_hp, "qi": 2} and defeat.payload.party_resources.tang == {"hp": actors.tang.max_hp, "qi": 2}, "Safe defeat recovery restores all recruited HP and qi floor2 including benched members")
	var low_qi = ready_state(false, false)
	low_qi.max_qi = 1
	low_qi.qi = 0
	var low_payload: Dictionary = initial_payload(low_qi)
	var low_recovery: Dictionary = Rules.settle_plan(low_qi, low_payload, {"hero": {"hp": 0, "qi": 0}}, "defeat")
	check(low_recovery.ok and low_recovery.hero_resources.qi == 1, "Recovery qi floor is capped by actual maximum")
	check(not Rules.settle_plan(state, payload, wipe, "win").ok and not Rules.settle_plan(state, payload, wipe, "flee").ok, "No surviving selected actor cannot report win/flee")
	check(not Rules.settle_plan(state, payload, hero_survives, "defeat").ok, "Living selected actor prevents defeat recovery")
	check(not Rules.settle_plan(state, payload, hero_survives, "victory").ok, "Noncanonical outcome rejects")
	for terminal: Variant in [null, {}, {"hero": {"hp": 0, "qi": 0}}, {"hero": {"hp": 0, "qi": 0}, "shen": {"hp": 1, "qi": 0}, "tang": {"hp": 1, "qi": 0}}, {"hero": {"hp": 0, "qi": 0}, "shen": {"hp": 0.5, "qi": 0}}, {"hero": {"hp": 0, "qi": 0}, "shen": {"hp": 1, "qi": INF}}, {"hero": {"hp": 0, "qi": 0, "max_hp": 100}, "shen": {"hp": 1, "qi": 0}}]:
		var terminal_before: String = var_to_str(terminal)
		check(not Rules.settle_plan(state, payload, terminal, "win").ok, "Incomplete/extra/malformed terminal resources reject")
		check(var_to_str(terminal) == terminal_before and payload == original and state.hp == 0, "Malformed settlement leaves prior state unchanged")
	var only_hero: Dictionary = Rules.select_roster(state, payload, ["hero"]).payload
	check(not Rules.settle_plan(state, only_hero, {"hero": {"hp": 0, "qi": 0}}, "win").ok, "Unselected member cannot count as survivor for victory")
	check(Rules.settle_plan(state, only_hero, {"hero": {"hp": 0, "qi": 0}}, "defeat").ok, "Hero-only defeat can safely recover recruited benched members")
