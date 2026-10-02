extends "res://tests/automatic_combat_balance_test.gd"
## Natural early and late recruited rosters. Replays production State/API quest
## rewards; no direct level, attack, defense, HP, qi or recruitment assignments.
class HistoricalTrial:
	extends "res://scripts/automatic_party_combat.gd"
	func _trial_endurance() -> Dictionary:
		var spec: Dictionary = super._trial_endurance()
		spec.max_hp = spec.legacy_floor
		return spec
var trial_rows: Array[Dictionary] = []

func _run() -> void:
	for school: String in ["听潮阁", "照野堂", "问石门"]:
		var s = _opening(true)
		if not _journey_win(s, "story", "trial_source_opening"): _finish(); return
		_finish_opening(s)
		_school(s, school)
		for count: int in [1, 2]:
			for formation: String in ["并肩", "护后"]:
				_trial_probe(s, count, formation, "objective", false, "early")
		if not _earn_late(s): _finish(); return
		check(s.qin_recruited() and s.level == 5, "Late trial team is genuinely recruited at earned level5")
		for count: int in range(1, 5):
			for formation: String in ["并肩", "护后"]:
				_trial_probe(s, count, formation, "objective", false, "late")
		_trial_probe(s, 4, "护后", "none", false, "late_no_skill")
		_trial_probe(s, 4, "护后", "wrong_skill", false, "late_wrong_skill")
		if school == "问石门":
			var previous: Dictionary = _trial_probe(s, 4, "护后", "objective", true, "historical_gap")
			check(previous.outcome == "win" and not previous.met and not previous.actual_guarded_heavy, "Historical unscaled late4 wins before actual guarded heavy, reproducing the gap")
		_test_trial_retry(s)
	_test_nontrial_constants()
	_finish()

func _earn_late(s) -> bool:
	check(s.choose_side_route("rescue") and s.find_side_clue("boatman"), "Actual rescue entry")
	s.heal_rest()
	if not _journey_win(s, "sluice_scout", "trial_source_scout"): return false
	s.heal_rest()
	if not _journey_win(s, "sluice_boss", "trial_source_sluice"): return false
	check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"), "Actual archive investigation")
	for seal: int in [2, 0, 1]: check(s.try_seal(seal).valid, "Actual archive seal")
	if not _journey_win(s, "archive_boss", "trial_source_archive"): return false
	check(s.resolve_chapter_two("open_records"), "Actual archive resolution reward")
	check(s.gather_resource("frost_timber").valid and s.repair_bridge(), "Finite natural bridge resources")
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Actual late Tang recruitment")
	check(s.begin_mistwood(), "Actual Mistwood entry")
	s.map_id = "mistwood"
	check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin") and s.obtain_mist_access("records") and s.record_mist_gauge("stone"), "Actual records access and3 gauges")
	s.heal_rest()
	if not _journey_win(s, "mist_keeper", "trial_source_keeper"): return false
	check(s.resolve_mistwood("release_water"), "Actual Mistwood ending")
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Explicit Qin quest and invitation")
	return true

func _trial_plan(model, mode: String) -> String:
	var view: Dictionary = model.snapshot()
	if mode == "none": return ""
	for actor: Dictionary in view.actors:
		if actor.hp <= 0 or actor.basic_done: continue
		var budget: int = int(actor.qi)
		for action: Dictionary in actor.actions:
			if action.queued: budget -= int(action.cost)
		# Tang's two real focus skills can affect separate basics. Martial3 and
		# lightness2 fit initial6qi; next-round basic recovery enables internal2.
		var order: Array[String] = ["martial", "lightness", "internal"]
		for category: String in order:
			for action: Dictionary in actor.actions:
				if action.category != category or not action.available or budget < int(action.cost): continue
				if mode == "wrong_skill" and (actor.id != "hero" or category != "lightness"): continue
				if mode == "objective" and category != "martial" and actor.id != "tang": continue
				var target: String = actor.id if action.target_team == "self" else "sect_trial"
				if actor.id == "hero" and category == "martial":
					if bool(action.effects.get("guard", false)) and not _incoming(view, "hero").heavy: continue
					if int(action.effects.get("healing", 0)) > 0 and actor.hp == actor.max_hp: continue
				elif action.target_team == "ally":
					# Preserve the test subject's real incoming hit until the hero
					# has proved the objective; no fake or preemptively healed hit.
					if not view.trial_provenance.met: continue
					var best: int = 0
					for ally: Dictionary in view.actors:
						var deficit: int = int(ally.max_hp) - int(ally.hp)
						if action.valid_target_ids.has(ally.id) and deficit > best:
							best = deficit
							target = ally.id
					if target == "sect_trial": continue
				var queue: Dictionary = model.queue_skill(actor.id, action.id, target)
				if queue.ok: budget -= int(action.cost)
	for actor: Dictionary in view.actors:
		if actor.hp <= 0: continue
		for action: Dictionary in actor.actions:
			if action.id == "item" and action.available and actor.hp * 100 < actor.max_hp * 35: return actor.id
	return ""

func _trial_probe(source, count: int, formation: String, mode: String, historical: bool, stage: String) -> Dictionary:
	var s = source._detached_persistent_state()
	check(s.set_formation(formation), "Explicit actual formation choice before changing roster")
	check(s.set_party_roster(["hero", "shen", "tang", "qin"].slice(0, count)), "Select only actually recruited trial actors")
	s.heal_rest()
	check(s.equip_art(s.sect_art()), "Trial uses actual owned school art")
	var projected: Dictionary = State.PartyRoster.battle_resources(s, s._party_payload())
	var built: Dictionary = Catalog.build_team(s, s.party_roster, projected.resources)
	check(built.ok, "Natural trial catalog projection")
	var model = HistoricalTrial.new() if historical else Rules.new()
	check(model.configure(built.team, "sect_trial"), "Natural trial entry")
	var initial: Dictionary = model.snapshot()
	var scaling: Dictionary = initial.trial_provenance.hp_scaling
	check(initial.enemies[0].max_hp == scaling.max_hp and scaling.max_hp >= scaling.legacy_floor, "Exact fixed entryHP shown with preserved legacy minimum")
	if not historical:
		check(scaling.max_hp > scaling.two_round_damage_budget, "Fixed HP exceeds bounded actual two-round offense")
	var accepted: int = 0
	var previous_hp: int = int(initial.enemies[0].hp)
	var heavy_round2: bool = false
	var guarded: bool = false
	var rounds: Dictionary = {}
	while model.snapshot().active and accepted < 500:
		var item_actor: String = _trial_plan(model, mode)
		var tx: Dictionary
		if not item_actor.is_empty():
			model.select_actor(item_actor)
			tx = model.accept_action("item")
		else: tx = model.advance()
		check(tx.accepted, "Scaled trial progresses at unchanged action boundary")
		if not tx.accepted: break
		_check_transaction(tx, rounds)
		check(tx.after.enemies[0].max_hp == scaling.max_hp and tx.after.enemies[0].hp <= previous_hp, "Trial enemy never heals or changes HP cap mid-battle")
		previous_hp = int(tx.after.enemies[0].hp)
		for event: Dictionary in tx.events:
			if event.type == "action" and event.source_id == "sect_trial" and event.heavy and event.round == 2: heavy_round2 = true
			if event.type == "trial_guarded_heavy":
				guarded = true
				check(event.action_id == "art:磐石回锋" and event.source_id == "hero", "Trial proof comes from exact hero martial against an actual heavy")
		check(model.complete_presentation(tx.token), "Exact scaled trial presentation acknowledgement")
		accepted += 1
	var final: Dictionary = model.snapshot()
	check(not final.active, "Natural scaled trial terminates")
	if not historical:
		check(heavy_round2, "Every roster leaves time for an actual announced round2 heavy")
		if mode != "objective": check(not final.trial_provenance.met, "No skill/wrong skill cannot fabricate objective proof")
		elif s.sect != "问石门" or formation == "护后" or count == 1:
			check(final.outcome == "win" and final.trial_provenance.met, "Natural objective policy wins with real exact-art/heal/guard proof")
		if s.sect == "问石门": check(final.trial_provenance.met == guarded, "Stone proof never inferred from defense, intent, or other actor")
	var hp: Dictionary = {}
	for actor: Dictionary in final.actors: hp[actor.id] = "%d/%d" % [actor.hp, actor.max_hp]
	var row: Dictionary = {"school": s.sect, "stage": stage, "level": s.level, "actors": count, "formation": formation, "mode": mode, "historical": historical, "outcome": final.outcome, "rounds": final.round, "hp": hp, "medicine": final.medicine, "enemy_max_hp": scaling.max_hp, "budget": scaling, "met": final.trial_provenance.met, "positive_healing": final.trial_provenance.healing, "actual_round2_heavy": heavy_round2, "actual_guarded_heavy": guarded}
	trial_rows.append(row)
	print("TRIAL " + JSON.stringify(row))
	return row

func _test_trial_retry(source) -> void:
	var s = source._detached_persistent_state()
	check(s.set_formation("护后"), "Explicit protect-rear exposes hero to real trial heavy")
	var no_skill: Dictionary = _fight(s, "sect_trial", false, "scaled_trial_no_skill")
	check(no_skill.outcome == "win" and not s.sect_trial_won and s.party_settlement.reward_xp == 45, "No-skill win pays only actual encounter reward and leaves objective retryable")
	var trial: Dictionary = _fight(s, "sect_trial", true, "scaled_trial_retry")
	check(trial.outcome == "win" and s.sect_trial_won and s.party_settlement.reward_xp == 45, "Repeated legitimate attempt grants one reward and real proof, never duplicate acknowledgement")
	var defense: int = s.defense
	var energy: int = s.max_qi
	check(s.complete_sect_trial() and s.defense == defense + 1 and s.max_qi == energy + 1 and s.sect_merit == 3, "Actual trial promotion grants exact once-only stats and merit")
	check(not s.complete_sect_trial() and not s.start_party_battle("sect_trial"), "Claimed trial cannot replay for permanent bonuses")

func _test_nontrial_constants() -> void:
	var s = _opening(false)
	var built: Dictionary = Catalog.build_team(s, ["hero"])
	var expected: Dictionary = {"story": [96], "training": [64], "sluice_scout": [85], "sluice_boss": [150], "archive_boss": [205], "mist_scout": [155], "mist_keeper": [300], "heting_receipt": [190, 110], "courtyard_practice": [96, 64]}
	for id: String in expected:
		var model = Rules.new()
		check(model.configure(built.team, id), "Nontrial model configures")
		var health: Array = []
		for enemy: Dictionary in model.snapshot().enemies: health.append(enemy.max_hp)
		check(health == expected[id] and not model.snapshot().trial_provenance.has("hp_scaling"), "Nontrial authored health unchanged: " + id)

func _finish() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		check(file != null, "Trial outcome artifact opens")
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "trials": trial_rows, "journey": journey, "formula": "max(180, 4*hero_attack+30, 1 + 2*sum(living_attack) + sum(learned_enemy_martial_direct_damage_at_current_rank) + sum(learned_martial_internal_lightness_focus_allowances))"}, "\t"))
			file.close()
	print("%s: %d natural scaled-trial checks; %d trial outcomes" % ["PASS" if failures == 0 else "FAIL", checks, trial_rows.size()])
	quit(0 if failures == 0 else 1)
