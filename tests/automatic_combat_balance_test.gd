extends SceneTree
## Bounded natural-resource diagnostic. No direct level/stat/recruitment writes.
## Opening dialogue effects are replayed explicitly because those callbacks are
## scene-local; all battles/rewards, school choices, lessons, later quests,
## gathering, purchases, invitations and rests use current production State APIs.
const State = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Rules = preload("res://scripts/automatic_party_combat.gd")
const Encounters = preload("res://scripts/unified_encounter_rules.gd")
var checks: int = 0
var failures: int = 0
var results: Array[Dictionary] = []
var journey: Array[Dictionary] = []
var journey_complete: bool = false

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(2)
		return
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _opening(invite: bool):
	var s = State.new()
	# Exact main._elder_dialogue -> _herb_dialogue -> _healer_dialogue effects.
	s.quest_stage = 1
	s.herbs += 1
	s.quest_stage = 2
	s.gain_xp(10)
	s.herbs -= 1
	s.medicine += 2
	s.quest_stage = 3
	s.gain_xp(20)
	if invite:
		check(s.recruit_companion(), "Actual optional Shen invitation")
		s.heal_rest() # Explicit invitation callback includes this public rest.
	check(s.level == 1 and s.attack == 16 and s.max_hp == 100 and s.medicine == 5, "Opening is earned30XP, natural level1, finite5 medicine")
	return s

func _finish_opening(s) -> void:
	check(s.quest_stage == 4, "Actual story victory precedes ending callback")
	# Exact main._finish_quest effects, followed by its explicit school choice.
	s.ending = "秉公"
	s.quest_stage = 5
	s.coins += 60
	s.gain_xp(90)
	s.heal_rest()
	check(s.level == 3 and s.xp == 0, "Only actual story60XP + ending90XP earns level3")

func _school(s, school: String) -> void:
	s.choose_sect(school)
	s.quest_stage = 6 # main._join_sect transition
	check(s.buy_equipment(), "Earned opening coins buy45-coin青钢剑 exactly once")
	check(s.equip_art(s.sect_art()), "Equip owned school art")
	check(s.learn_internal_skill() and s.learn_lightness(), "Explicit level3 lessons, no derived free unlock")
	s.heal_rest()

func _actor(view: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in view.actors:
		if actor.id == id:
			return actor
	return {}

func _target(view: Dictionary) -> String:
	for enemy: Dictionary in view.enemies:
		if enemy.id == "bracer" and enemy.hp > 0:
			return enemy.id
	for enemy: Dictionary in view.enemies:
		if enemy.hp > 0:
			return enemy.id
	return ""

func _incoming(view: Dictionary, actor_id: String) -> Dictionary:
	var result: Dictionary = {"damage": 0, "heavy": false}
	var target: Dictionary = _actor(view, actor_id)
	for intent: Dictionary in view.enemy_intents:
		if intent.type != "attack": continue
		var source_alive: bool = false
		for enemy: Dictionary in view.enemies:
			if enemy.id == intent.source_id and enemy.hp > 0: source_alive = true
		if not source_alive: continue
		var actual: String = ""
		for id: String in intent.target_order:
			if int(_actor(view, id).get("hp", 0)) > 0:
				actual = id
				break
		if actual == actor_id:
			result.damage += maxi(1, int(intent.damage) - int(target.defense)) + (3 if int(target.status.get("vulnerability_hits", 0)) > 0 else 0)
			result.heavy = result.heavy or bool(intent.heavy)
	return result

func _plan(model) -> String:
	# Deterministic policy: break bracer first; only queue for the current basic.
	# Martial first, then useful self-heal, then announced-target lightness.
	# Budget qi locally so the plan never intentionally overbooks queued costs.
	# Guard martial waits for an incoming heavy or an existing vulnerability;
	# trial healing waits for positive missingHP. Medicine only below35% or
	# within the published incoming hit, once per actor/round and finite stock.
	var view: Dictionary = model.snapshot()
	model.select_target(_target(view))
	for actor: Dictionary in view.actors:
		if actor.hp <= 0 or actor.basic_done: continue
		var budget: int = int(actor.qi)
		var incoming: Dictionary = _incoming(view, actor.id)
		for action: Dictionary in actor.actions:
			if action.queued:
				budget -= int(action.cost)
		for action: Dictionary in actor.actions:
			if not Rules.CATEGORIES.has(String(action.category)) or not action.available or budget < int(action.cost): continue
			var target: String = actor.id if action.target_team == "self" else _target(view)
			if action.target_team == "ally":
				if int(action.effects.get("healing", 0)) > 0:
					var deficit: int = 0
					for ally: Dictionary in view.actors:
						var missing: int = int(ally.max_hp) - int(ally.hp)
						if ally.hp > 0 and missing > deficit:
							deficit = missing
							target = ally.id
					if deficit < mini(20, int(action.effects.healing)): continue
				else:
					var threat: int = 0
					for ally: Dictionary in view.actors:
						var damage: int = int(_incoming(view, ally.id).damage)
						if ally.hp > 0 and damage > threat:
							threat = damage
							target = ally.id
					if threat == 0: continue
			if bool(action.effects.get("guard", false)) and not incoming.heavy and int(actor.status.get("vulnerability_hits", 0)) == 0: continue
			if action.category == "internal" and int(actor.max_hp) - int(actor.hp) < int(action.effects.get("healing", 0)) and not (int(action.effects.get("focus_bonus", 0)) > int(actor.status.focused_damage)): continue
			if view.encounter_id == "sect_trial" and actor.id == "hero" and action.category == "martial" and int(action.effects.get("healing", 0)) > 0 and actor.hp == actor.max_hp: continue
			if action.category == "lightness" and int(incoming.damage) == 0: continue
			var queued: Dictionary = model.queue_skill(actor.id, action.id, target)
			if queued.ok: budget -= int(action.cost)
	for actor: Dictionary in view.actors:
		if actor.hp <= 0: continue
		for action: Dictionary in actor.actions:
			if action.id == "item" and action.available and (actor.hp <= _incoming(view, actor.id).damage or actor.hp * 100 < actor.max_hp * 35):
				return actor.id
	return ""

func _record(label: String, level: int, start: Dictionary, finish: Dictionary, policy: bool, accepted: int, extra: Dictionary = {}) -> Dictionary:
	var hp: Dictionary = {}
	var qi: Dictionary = {}
	var starting: Dictionary = {}
	for actor: Dictionary in finish.actors:
		hp[actor.id] = "%d/%d" % [actor.hp, actor.max_hp]
		qi[actor.id] = "%d/%d" % [actor.qi, actor.max_qi]
	for actor: Dictionary in start.actors:
		starting[actor.id] = {"hp": actor.hp, "max_hp": actor.max_hp, "qi": actor.qi, "max_qi": actor.max_qi, "attack": actor.attack, "defense": actor.defense}
	var row: Dictionary = {"label": label, "encounter": finish.encounter_id, "level": level, "actors": finish.actors.size(), "policy": "queued" if policy else "zero_input", "outcome": finish.outcome, "rounds": finish.round, "hp": hp, "qi": qi, "medicine_start": start.medicine, "medicine_end": finish.medicine, "accepted_actions": accepted, "trial_met": finish.trial_provenance.met, "start": starting}
	row.merge(extra)
	print("BALANCE " + JSON.stringify(row))
	results.append(row)
	return row

func _probe(source, encounter: String, count: int, policy: bool, label: String) -> Dictionary:
	var s = source._detached_persistent_state()
	var roster: Array = ["hero", "shen", "tang", "qin"].slice(0, count)
	check(s.set_party_roster(roster), "Probe roster uses only already recruited actors")
	if encounter == "sect_trial":
		s.heal_rest()
		check(s.equip_art(s.sect_art()), "Trial probe mirrors actual entry free-rest and own art")
		if s.sect == "问石门" and count > 1: s.set_formation("护后")
	var before: Dictionary = s.to_dict().duplicate(true)
	var projected: Dictionary = State.PartyRoster.battle_resources(s, s._party_payload())
	check(projected.ok, "Project actual persisted actor resources")
	var built: Dictionary = Catalog.build_team(s, roster, projected.resources)
	check(built.ok, "Build natural detached team")
	var model = Rules.new()
	check(model.configure(built.team, encounter), "Natural probe configures encounter")
	var start: Dictionary = model.snapshot()
	var accepted: int = 0
	var skill_rounds: Dictionary = {}
	while model.snapshot().active and accepted < 500:
		var item_actor: String = _plan(model) if policy else ""
		var tx: Dictionary
		if not item_actor.is_empty():
			model.select_actor(item_actor)
			tx = model.accept_action("item")
		else: tx = model.advance()
		check(tx.accepted, "Natural model progresses without a resource softlock")
		if not tx.accepted: break
		_check_transaction(tx, skill_rounds)
		check(model.complete_presentation(tx.token), "Natural model ack exact token")
		accepted += 1
	check(not model.snapshot().active, "Bounded natural probe reaches terminal outcome")
	check(s.to_dict() == before, "Detached balance probe preserves earned state")
	return _record(label, s.level, start, model.snapshot(), policy, accepted, {"detached_probe": true})

func _check_transaction(tx: Dictionary, rounds: Dictionary) -> void:
	var action: Dictionary = {}
	for actor: Dictionary in tx.before.actors:
		if actor.id == tx.source_id:
			for candidate: Dictionary in actor.actions:
				if candidate.id == tx.action_id: action = candidate
	if Rules.CATEGORIES.has(String(action.get("category", ""))):
		var did_execute: bool = false
		for event: Dictionary in tx.events:
			if event.type == "action": did_execute = true
		if not did_execute: return
		var key: String = tx.source_id + ":" + tx.action_id
		if rounds.has(key): check(int(tx.before.round) >= int(rounds[key]) + int(action.cooldown) + 1, "Natural policy obeys full subsequent-round cooldown")
		rounds[key] = tx.before.round

func _fight(s, encounter: String, policy: bool, label: String) -> Dictionary:
	s.map_id = Encounters.LOCATIONS[encounter][0] # Travel only, no stat change.
	var start_level: int = s.level
	check(s.start_party_battle(encounter), "Actual State adapter enters " + encounter)
	if not s.battle_active: return {}
	var start: Dictionary = s.party_battle_snapshot()
	var accepted: int = 0
	var rounds: Dictionary = {}
	var rewards_before: int = s.xp + 30 * s.level * (s.level - 1)
	var terminal_tx: Dictionary = {}
	while s.battle_active and accepted < 500:
		var item_actor: String = _plan(s.party_session) if policy else ""
		var tx: Dictionary
		if not item_actor.is_empty():
			s.select_party_actor(item_actor)
			tx = s.party_battle_action("item")
		else: tx = s.advance_party_battle()
		check(tx.accepted, "Actual adapter makes progress")
		if not tx.accepted: break
		_check_transaction(tx, rounds)
		check(not s.advance_party_battle().accepted, "Locked duplicate advance cannot repeat actual action")
		var done: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
		check(done.accepted, "Actual adapter settles accepted presentation")
		var stable: Dictionary = s.to_dict().duplicate(true)
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and stable == s.to_dict(), "Duplicate acknowledgement never awards or spends twice")
		accepted += 1
		terminal_tx = tx
	check(not s.battle_active, "Actual natural battle reaches terminal")
	var earned: int = s.xp + 30 * s.level * (s.level - 1) - rewards_before
	check(earned == int(s.party_settlement.get("reward_xp", 0)), "Exact actual settlement XP accounted once")
	var row: Dictionary = _record(label, start_level, start, terminal_tx.after, policy, accepted, {"detached_probe": false, "reward_xp": earned, "coins_change": s.party_settlement.get("coin_change", 0), "settled_hp": s.hp, "settled_level": s.level})
	journey.append(row)
	return row

func _matrix(source, encounter: String, maximum: int, label: String) -> void:
	for count: int in range(1, maximum + 1):
		for policy: bool in [false, true]:
			_probe(source, encounter, count, policy, label)

func _journey_win(s, encounter: String, label: String) -> bool:
	var result: Dictionary = _fight(s, encounter, true, label)
	var won: bool = result.get("outcome") == "win"
	check(won, "Natural deterministic journey policy wins " + encounter)
	return won

func _run() -> void:
	for count: int in [1, 2]:
		var opening = _opening(count == 2)
		for policy: bool in [false, true]:
			_probe(opening, "story", count, policy, "earned_opening")
	var s = _opening(true)
	var opening_result: Dictionary = _fight(s, "story", true, "journey_opening")
	check(opening_result.get("outcome") == "win", "Natural opening journey wins")
	if opening_result.get("outcome") != "win": _finish(); return
	_finish_opening(s)
	var sects: Array[String] = ["听潮阁", "照野堂", "问石门"]
	for school: String in sects:
		var branch = s._detached_persistent_state()
		_school(branch, school)
		_matrix(branch, "sect_trial", 2, "earned_level3_trial_" + school)
		if school == "问石门": branch.set_formation("护后")
		var trial: Dictionary = _fight(branch, "sect_trial", true, "trial_adapter_" + school)
		check(trial.get("outcome") == "win" and branch.sect_trial_won, "Natural school policy both wins and proves actual school condition")
		check(branch.complete_sect_trial() and not branch.complete_sect_trial(), "Actual trial promotion can be claimed only once")
	# Main journey deliberately skips optional trial rewards, so later actors
	# remain on the minimum non-grind school path, rather than boosted levels.
	_school(s, "听潮阁")
	check(s.choose_side_route("rescue") and s.find_side_clue("boatman"), "Real rescue route and first clue")
	s.heal_rest()
	_matrix(s, "sluice_scout", 2, "earned_sluice_scout")
	if not _journey_win(s, "sluice_scout", "journey_sluice_scout"): _finish(); return
	s.heal_rest()
	_matrix(s, "sluice_boss", 2, "earned_sluice_boss")
	if not _journey_win(s, "sluice_boss", "journey_sluice_boss"): _finish(); return
	check(not s.finish_side_quest(), "Sluice branch reward cannot be paid again")
	check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"), "Actual archive clue XP")
	for seal: int in [2, 0, 1]: check(s.try_seal(seal).valid, "Actual correct archive seal")
	_matrix(s, "archive_boss", 2, "earned_level4_archive")
	if not _journey_win(s, "archive_boss", "journey_archive"): _finish(); return
	check(s.resolve_chapter_two("open_records") and not s.resolve_chapter_two("open_records"), "Archive ending grants reward exactly once")
	check(s.gather_resource("frost_timber").valid and s.repair_bridge(), "Gather finite3 timber and consume2 to repair bridge")
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Actual Tang quest/reward/explicit invitation")
	check(s.begin_mistwood(), "Actual completed archive permits Mistwood")
	s.map_id = "mistwood"
	s.heal_rest()
	_matrix(s, "mist_scout", 3, "earned_level5_mist_scout")
	# Use the existing noncombat records route for the main minimum-XP journey.
	check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin") and s.obtain_mist_access("records") and s.record_mist_gauge("stone"), "Actual3 gauges and noncombat records access")
	s.heal_rest() # Existing free mist_camp.
	_matrix(s, "mist_keeper", 3, "earned_level5_mist_keeper")
	if not _journey_win(s, "mist_keeper", "journey_mist_keeper"): _finish(); return
	check(s.resolve_mistwood("release_water") and not s.resolve_mistwood("release_water"), "Actual Mistwood ending reward exactly once")
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Actual Qin quest and explicit fourth invitation after Mist ending")
	check(s.level == 5, "Minimum non-grind path recruits Qin at natural level5")
	s.heal_rest()
	_matrix(s, "training", 4, "earned_level5_four_actor_rematch")
	check(s.begin_heting(), "Actual Mist ending opens harbor")
	s.map_id = "heting"
	check(s.take_heting_cargo("meal") and s.deliver_heting_base("heting_relief"), "Actual first finite cargo rewards10XP")
	check(s.take_heting_cargo("sealed") and s.deliver_heting_base("heting_scale"), "Actual second finite cargo rewards10XP")
	check(s.choose_heting_plan("short_ferries") and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief", "short_ferries"), "Actual final cargo reward100XP")
	check(s.Receipt.begin(s), "Optional receipt is explicitly accepted")
	_matrix(s, "heting_receipt", 4, "earned_receipt_after_harbor_rewards")
	_test_defeat_retry(s)
	check(_fight(s, "heting_receipt", true, "journey_receipt").get("outcome") == "win", "Natural4-actor receipt journey wins")
	check(not s.start_party_battle("heting_receipt"), "Completed receipt cannot award repeat victory")
	journey_complete = s.receipt_stage == 2
	_finish()

func _test_defeat_retry(source) -> void:
	var s = source._detached_persistent_state()
	check(s.set_party_roster(["hero"]), "Choose genuine solo roster for natural no-input risk probe")
	var before_med: int = s.medicine
	var risk: Dictionary = _fight(s, "heting_receipt", false, "natural_solo_defeat_probe")
	if risk.get("outcome") == "defeat":
		check(s.hp == s.max_hp and s.qi >= 2 and s.medicine == before_med and s.receipt_stage == 1, "Defeat recoversHP/qi floor without inventing medicine or consuming retry")
		var retry: Dictionary = _fight(s, "heting_receipt", true, "natural_solo_retry_policy")
		check(not retry.is_empty() and retry.outcome in ["win", "defeat"], "Retry can progress with finite retained resources")
	var med: int = s.medicine
	s.heal_rest()
	check(s.hp == s.max_hp and s.qi == s.max_qi and s.medicine == med, "Free rest restoresHP/qi only; it never refills finite medicine")

func _finish() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		check(file != null, "Diagnostic artifact is writable")
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "journey": journey, "journey_complete": journey_complete, "scope": "Natural earned stats/resources; model balance probes plus State/API journey, not scene proximity/UI acceptance"}, "\t"))
			file.close()
	print("%s: %d natural automatic combat balance/progression checks; %d reported encounters" % ["PASS" if failures == 0 else "FAIL", checks, results.size()])
	quit(0 if failures == 0 else 1)
