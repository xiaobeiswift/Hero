extends "res://tests/weapon_fitting_trial_model_test.gd"
## Metrics are compared against every accepted before/after transaction and
## independently against unmodified frozen numerical result/event fixtures.
var observed: Dictionary = {}
var expected_metrics: Dictionary = {}
var metric_events: Array = []
var numerical_entry: Dictionary = {}

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--numerical-entry="):
			var file: FileAccess = FileAccess.open(argument.trim_prefix("--numerical-entry="), FileAccess.READ)
			check(file != null, "Frozen numerical entry file opens")
			if file != null: numerical_entry = JSON.parse_string(file.get_as_text()); file.close()
	_test_earned_entry_metrics()
	var s = _earned_capstone("听潮阁", true, true)
	if s != null:
		_test_special_metric_cases(s)
		_test_late_metrics(s)
	for label: String in ["heal", "medicine", "barrier_absorb", "lightness_absorb", "zero_damage", "protect", "ally_down", "queue_cancel", "win", "defeat", "flee"]:
		check(observed.has(label), "Actual accepted trace covers " + label)
	_finish_fitting("metrics")

func _start_metric_audit(model) -> void:
	expected_metrics = {"losses": {}, "loss": 0, "medicine": 0, "attacks": 0, "rounds": 0, "accepted": 0}
	metric_events = []
	for actor: Dictionary in model.snapshot().actors: expected_metrics.losses[actor.id] = 0
	check(model.fitting_trial_snapshot().metrics.total_actual_hp_lost == 0 and model.fitting_trial_snapshot().metrics.accepted_transactions == 0, "Fresh/retry metrics begin at zero")

func _audit_transaction(model, tx: Dictionary) -> void:
	check(tx.accepted, "Metrics transaction accepted")
	if not tx.accepted: return
	for prior: Dictionary in tx.before.actors:
		var current: Dictionary = _actor(tx.after, prior.id)
		var loss: int = maxi(0, int(prior.hp) - int(current.hp))
		expected_metrics.losses[prior.id] += loss
		expected_metrics.loss += loss
	expected_metrics.medicine += int(tx.before.medicine) - int(tx.after.medicine)
	expected_metrics.accepted += 1
	for event: Dictionary in tx.events:
		metric_events.append(event)
		if event.type in ["heal", "medicine", "barrier_absorb", "lightness_absorb", "protect", "queue_cancel"]:
			observed[event.type] = true
		if event.type == "damage" and event.amount == 0: observed.zero_damage = true
		if event.type == "down" and expected_metrics.losses.has(event.target_id): observed.ally_down = true
		if event.type == "action" and event.get("action_id") == "enemy:attack": expected_metrics.attacks += 1
		if event.type == "round_end": expected_metrics.rounds += 1
		check(event.type != "proficiency", "Borrowed trial never earns proficiency")
	var metrics: Dictionary = model.fitting_trial_snapshot().metrics
	check(metrics.actual_hp_lost_by_actor == expected_metrics.losses and metrics.total_actual_hp_lost == expected_metrics.loss, "Actual capped HP lost per actor/team equals accepted deltas")
	check(metrics.medicine_used == expected_metrics.medicine, "Medicine spent matches accepted resource deltas")
	check(metrics.enemy_attacks_executed == expected_metrics.attacks, "Executed attacks exclude protect/expired target actions")
	check(metrics.completed_rounds == expected_metrics.rounds, "Completed rounds count actual round_end, not displayed round")
	check(metrics.accepted_transactions == expected_metrics.accepted, "Each accepted token counted once")
	check(metrics.outcome == tx.after.outcome and metrics.terminal_round == (0 if tx.after.active else int(tx.after.round)), "Active and terminal rounds/outcome are distinct")
	for actor: Dictionary in tx.after.actors:
		check(metrics.remaining_resources.actors[actor.id] == {"hp": actor.hp, "qi": actor.qi}, "Remaining borrowed actor resources exact")
	check(metrics.remaining_resources.medicine == tx.after.medicine and metrics.remaining_resources.medicine_heal == 40, "Remaining borrowed medicine exact")
	# Re-presenting a transaction, including a duplicate collector call, cannot
	# alter metrics. The collector never depends on complete_presentation.
	model._record_fitting_transaction(tx, true)
	check(model.fitting_trial_snapshot().metrics == metrics, "Duplicate accepted token cannot recount metrics")
	check(not model.advance().accepted, "Locked advance rejected")
	check(not model.accept_action("item").accepted, "Locked item rejected")
	check(not model.complete_presentation(int(tx.token) + 999999), "Wrong presentation token rejected")
	check(model.fitting_trial_snapshot().metrics == metrics, "Presentation/rejected actions cannot charge metrics")
	check(model.complete_presentation(tx.token), "Accepted exact token completes")
	check(not model.complete_presentation(tx.token), "Duplicate completion rejected")
	check(model.fitting_trial_snapshot().metrics == metrics, "Repeated completion does not count anything again")
	if not tx.after.active: observed[tx.after.outcome] = true

func _drive_metrics(s, fitting: String, profile: String, policy: String = "queued", model = null) -> Dictionary:
	var before: Dictionary = s.to_dict().duplicate(true)
	if model == null: model = _new_trial(s, fitting, profile)
	_start_metric_audit(model)
	var start: Dictionary = model.snapshot()
	var steps: int = 0
	while model.snapshot().active and steps < 1200:
		var metrics_before: Dictionary = model.fitting_trial_snapshot().metrics
		var item_actor: String = ""
		if policy == "queued": item_actor = _plan(model)
		elif policy == "basic_medicine":
			model.select_target(_target(model.snapshot()))
			for actor: Dictionary in model.snapshot().actors:
				if actor.hp <= 0: continue
				for action: Dictionary in actor.actions:
					if action.id == "item" and action.available and (actor.hp <= _incoming(model.snapshot(), actor.id).damage or actor.hp * 100 < actor.max_hp * 35): item_actor = actor.id; break
		check(model.fitting_trial_snapshot().metrics == metrics_before, "Queue/target/policy has no metric side effect")
		var tx: Dictionary
		if item_actor.is_empty(): tx = model.advance()
		else: model.select_actor(item_actor); tx = model.accept_action("item")
		if not tx.accepted: check(false, "Metric policy must progress"); break
		_audit_transaction(model, tx)
		steps += 1
	check(not model.snapshot().active, "Metric battle reaches bounded outcome")
	var final: Dictionary = model.fitting_trial_snapshot()
	check(_frozen_tree(final), "Final metrics and metadata immutable")
	check(s.to_dict() == before, "Win/loss/medicine/skills preserve entire real persistent State")
	check(not model.advance().accepted and not model.accept_action("flee").accepted, "Terminal no-op cannot restart model")
	check(model.fitting_trial_snapshot() == final, "Terminal no-op leaves result unchanged")
	var row: Dictionary = {"school": s.sect, "level": s.level, "roster": s.party_roster.duplicate(), "formation": s.formation,
		"gear": s.equipment, "fitting": fitting, "profile": profile, "policy": policy,
		"metadata": final.metadata, "metrics": final.metrics, "events_sha256": JSON.stringify(metric_events).sha256_text(), "specs": start.enemies}
	fitting_rows.append(row)
	return row

func _test_earned_entry_metrics() -> void:
	var losses: int = 0
	var samples: int = 0
	check(not numerical_entry.is_empty(), "Unchanged numerical entry fixture required")
	for school: String in ["听潮阁", "照野堂", "问石门"]:
		var s = _opening(true)
		if not _journey_win(s, "story", "trial_metrics_entry_" + school): return
		_finish_opening(s)
		s.choose_sect(school); s.quest_stage = 6 # Existing scene-local join callback.
		check(s.learn_internal_skill() and s.learn_lightness() and s.equip_art(s.sect_art()), "Genuine level3 lessons/owned school art")
		s.heal_rest()
		var starter = s._detached_persistent_state()
		check(s.buy_equipment(), "Genuinely earned steel sword purchase")
		for pair: Array in [["starter", starter], ["steel", s]]:
			var base = pair[1]
			for layout: Array in [[["hero"], "并肩"], [["hero", "shen"], "并肩"], [["hero", "shen"], "护后"]]:
				check(base.set_party_roster(["hero", "shen"]) and base.set_formation(layout[1]) and base.set_party_roster(layout[0]), "Genuine early selected roster/formation")
				var key: String = ""
				for fitting: String in ["plain", "edge", "guard"]:
					var row: Dictionary = _drive_metrics(base, fitting, "pressure")
					samples += 1
					if row.metrics.outcome == "defeat": losses += 1
					check(row.metrics.medicine_used == 3, "Accepted high-pressure early profile really exhausts borrowed medicine")
					if key.is_empty(): key = row.metadata.comparison_key
					check(row.metadata.comparison_key == key, "Metrics candidate group frozen")
					_compare_numerical_entry(row, pair[0])
	check(samples == 54 and losses == 10, "Frozen genuine level3 sample retains54 runs/10 losses; no retuning")

func _compare_numerical_entry(row: Dictionary, gear: String) -> void:
	var fitting: String = {"plain": "original", "edge": "offense", "guard": "defense"}[row.fitting]
	for prior: Dictionary in numerical_entry.get("rows", []):
		if prior.preset != "recommended40_64" or prior.school != row.school or prior.gear != gear or prior.fitting != fitting or prior.roster != row.roster or prior.formation != row.formation: continue
		check(row.events_sha256 == prior.events_sha256, "Full accepted event digest matches unchanged numerical probe")
		check(_fixture_equal(row.specs, prior.specs) and row.metrics.outcome == prior.outcome and row.metrics.terminal_round == prior.rounds, "Frozen numerical specs/outcome/terminal round unchanged")
		check(row.metrics.total_actual_hp_lost == prior.damage_taken and row.metrics.actual_hp_lost_by_actor.hero == prior.hero_damage_taken and row.metrics.medicine_used == prior.medicine_used, "Numerical probe loss/medicine metrics exact")
		check(row.metrics.accepted_transactions == prior.accepted, "Numerical accepted transaction count exact")
		# Raw probe enemy_actions intentionally included protection; do not use
		# it as the production attack counter or rounds as completed_rounds.
		check(row.metrics.enemy_attacks_executed <= prior.enemy_actions and row.metrics.completed_rounds < row.metrics.terminal_round, "Production attack/round definitions remain distinct from probe diagnostics")
		return
	check(false, "Matching frozen numerical sample exists")

func _test_special_metric_cases(s) -> void:
	var changed = s._detached_persistent_state()
	check(changed.set_party_roster(["hero"]), "Solo metric boundary fixture")
	changed.attack = 1; changed.defense = 0; changed.hp = 1; changed.max_hp = 1
	var overkill: Dictionary = _drive_metrics(changed, "plain", "pressure", "idle")
	check(overkill.metrics.total_actual_hp_lost == 1 and overkill.metrics.enemy_attacks_executed == 1 and overkill.metrics.completed_rounds == 0 and overkill.metrics.terminal_round == 1 and overkill.metrics.outcome == "defeat", "Overkill records1 actual HP, one attack, no completed partial round")
	var retry: Dictionary = _drive_metrics(changed, "plain", "pressure", "idle")
	check(retry.metrics == overkill.metrics and retry.metadata == overkill.metadata, "Retry resets resources/metrics yet preserves frozen identity")
	var flee_model = _new_trial(s, "guard", "pressure")
	_start_metric_audit(flee_model)
	_audit_transaction(flee_model, flee_model.accept_action("flee"))
	check(flee_model.fitting_trial_snapshot().metrics.completed_rounds == 0 and flee_model.fitting_trial_snapshot().metrics.terminal_round == 1 and flee_model.fitting_trial_snapshot().metrics.medicine_used == 0, "Immediate flee preserves untouched virtual stock and partial round")
	changed = s._detached_persistent_state(); changed.attack = 999
	check(changed.set_party_roster(["hero"]), "Solo high-attack partial-round fixture")
	var short_win: Dictionary = _drive_metrics(changed, "edge", "ordinary")
	check(short_win.metrics.outcome == "win" and short_win.metrics.terminal_round == 1 and short_win.metrics.completed_rounds == 0 and short_win.metrics.enemy_attacks_executed == 0, "Ally-phase victory is not a completed round")
	changed = s._detached_persistent_state(); changed.attack = 999
	check(changed.set_party_roster(["hero", "shen", "tang", "qin"]), "Queued-invalid target fixture real owned roster")
	var queued = _new_trial(changed, "plain", "ordinary")
	check(queued.queue_skill("tang", Catalog.TANG_ART, "bracer").ok and queued.select_target("bracer"), "Queue later actor before target is killed")
	_drive_metrics(changed, "plain", "ordinary", "idle", queued)
	changed = s._detached_persistent_state(); changed.defense = 39
	check(changed.set_party_roster(["hero", "shen", "tang", "qin"]) and changed.set_formation("护后"), "Protected front actor fixture")
	var shielded = _new_trial(changed, "plain", "pressure")
	check(shielded.queue_skill("qin", Catalog.QIN_ART, "hero").ok, "Real Qin shield precedes first light attack")
	_drive_metrics(changed, "plain", "pressure", "idle", shielded)
	changed = s._detached_persistent_state(); changed.hp = 1; changed.max_hp = 1; changed.defense = 0
	check(changed.set_party_roster(["hero", "shen", "tang", "qin"]) and changed.set_formation("护后"), "Downed-front/no revival fixture")
	var down_model = _new_trial(changed, "plain", "pressure")
	_start_metric_audit(down_model)
	while down_model.snapshot().active and down_model.snapshot().actors[0].hp > 0:
		_audit_transaction(down_model, down_model.advance())
	var before: Dictionary = down_model.fitting_trial_snapshot()
	check(not down_model.select_actor("hero") and not down_model.queue_skill("shen", Catalog.SHEN_ART, "hero").ok, "Downed actor cannot act or receive healing")
	check(down_model.fitting_trial_snapshot() == before, "Rejected down/heal operations have no metric change")

func _test_late_metrics(s) -> void:
	for layout: Array in [[["hero"], "并肩"], [["hero", "shen", "tang", "qin"], "护后"]]:
		check(s.set_party_roster(["hero", "shen", "tang", "qin"]) and s.set_formation(layout[1]) and s.set_party_roster(layout[0]), "Late genuine roster/formation")
		for profile: String in TrialFactory.PROFILES:
			for fitting: String in ["plain", "edge", "guard"]:
				_drive_metrics(s, fitting, profile, "queued")
	# Clearly synthetic save-boundary sensitivity, not a fabricated earned
	# level99 journey: preserve the accepted high-stat damage-floor limitation.
	var high = s._detached_persistent_state()
	check(high.set_party_roster(["hero"]), "High-stat sensitivity solo")
	high.level = 99; high.attack = 323; high.defense = 105; high.max_hp = 1286; high.hp = 1286
	var counts: Array = []
	for fitting: String in ["plain", "edge", "guard"]:
		var row: Dictionary = _drive_metrics(high, fitting, "pressure", "basic_medicine")
		counts.append([row.metrics.medicine_used, row.metrics.total_actual_hp_lost, row.metrics.terminal_round])
	check(counts[0] == counts[1] and counts[1] == counts[2], "High-stat damage-floor sample remains nondifferentiating; no hidden retuning")


# JSON.parse_string represents numbers as floats. Compare structure and exact
# scalar numeric value; Dictionary == deliberately distinguishes int/float.
func _fixture_equal(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not _fixture_equal(left[key], right[key]): return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size(): return false
		for index: int in left.size():
			if not _fixture_equal(left[index], right[index]): return false
		return true
	return left == right
