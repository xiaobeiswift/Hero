extends "res://tests/automatic_party_combat_test.gd"
const Consignee = preload("res://scripts/heting_consignee_combat_data.gd")
const LEGACY_IDS: Array[String] = ["story", "training", "sect_trial", "courtyard_practice", "sluice_scout", "sluice_boss", "archive_boss", "mist_scout", "mist_keeper", "heting_receipt"]

func _run() -> void:
	_test_fixed_entry_and_cadence()
	_test_per_target_guard_and_opening()
	_test_new_scheduler_resources()
	_test_new_cancel_and_death()
	_test_new_flee_and_pause()
	_test_legacy_traces()
	print("%s: %d consignee model and legacy parity checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _test_fixed_entry_and_cadence() -> void:
	for count: int in range(1, 5):
		var model = _rules(_team(count, 1, 1000), "heting_consignee")
		var first: Dictionary = model.snapshot()
		check(first.consignee_provenance.is_read_only(), "Entry provenance recursively immutable")
		check(first.enemies[0].id == "du_hui" and first.enemies[0].name == "杜晦·平川粮栈管事" and first.enemies[0].max_hp == 260, "Du fixed authored identity and health")
		check(first.enemies[1].id == "consignee_guard" and first.enemies[1].name == "收运护手" and first.enemies[1].max_hp == 160, "Anonymous guard fixed authored identity and health")
		for round_number: int in range(1, 7):
			_to_round(model, round_number)
			var view: Dictionary = model.snapshot()
			check(view.enemies[0].max_hp == 260 and view.enemies[1].max_hp == 160 and view.consignee_provenance == first.consignee_provenance, "No changing durability during combat")
			check(view.enemy_intents.size() == 2, "Both living opponents announce independently")
			var heavy_count: int = 0
			for intent: Dictionary in view.enemy_intents:
				var phase: Dictionary = Consignee.phase(intent.source_id, round_number)
				check(intent.type == "attack" and intent.damage == phase.damage and intent.phase == phase.phase and intent.guarded == phase.guarded and intent.opening == phase.opening, "Published cadence matches each own targetable opponent")
				check(not intent.description.is_empty() and intent.description.contains(str(intent.damage)) and intent.description.contains("入场气血"), "Announcement includes actual damage and fixed entry health")
				if intent.heavy: heavy_count += 1
			check(heavy_count <= 1, "Staggered cadence never doubles heavy pressure")
			check(not view.enemy_intents.any(func(i): return i.type == "protect"), "No permanent striker/bracer copy")

func _test_per_target_guard_and_opening() -> void:
	var model = _rules(_team(1, 11, 1000), "heting_consignee")
	var attack: Dictionary = _step(model)
	check(_event(attack, "damage", "hero", "du_hui").amount == 6, "Du light guard halves own received damage rounding up")
	_to_round(model, 2)
	check(model.select_target("consignee_guard"), "Can choose recovering guard")
	attack = _step(model)
	check(_event(attack, "damage", "hero", "consignee_guard").amount == 17, "Only guard receives its announced recovery opening6")
	_to_round(model, 3)
	check(model.select_target("du_hui"), "Can choose recovering Du")
	attack = _step(model)
	check(_event(attack, "damage", "hero", "du_hui").amount == 19, "Only Du receives its announced recovery opening8")
	var weakened = _rules(_team(3, 1, 1000), "heting_consignee")
	check(weakened.queue_skill("tang", "art:tang_fenjin", "consignee_guard").ok, "Existing weakening can select guard heavy")
	var heavy: Dictionary = {}
	while weakened.snapshot().round == 1:
		var tx: Dictionary = _step(weakened)
		if tx.source_id == "consignee_guard": heavy = _event(tx, "action", "consignee_guard")
	check(heavy.heavy and heavy.damage == 28 and heavy.weakened == 5, "Guard heavy uses existing weakening exactly")

func _test_new_scheduler_resources() -> void:
	var model = _rules(_team(4, 1, 1000), "heting_consignee")
	var first: Dictionary = model.snapshot()
	check(not model.accept_action("attack").accepted and not model.accept_action("guard").accepted, "New encounter exposes no extra manual combat mode")
	check(model.queue_skill("hero", "art:照夜一线", "consignee_guard").ok and model.queue_skill("hero", "lightness:hero_tawei", "hero").ok, "Existing independent queues remain available")
	var basics: Array[String] = []
	var previous_hp: Dictionary = {"du_hui": 260, "consignee_guard": 160}
	while model.snapshot().round == 1:
		var tx: Dictionary = model.advance()
		check(tx.accepted and tx.events.is_read_only(), "New transaction accepted and immutable")
		var locked: Dictionary = model.snapshot()
		check(not model.advance().accepted and locked == model.snapshot(), "Duplicate advance cannot replay costs/damage")
		check(not model.complete_presentation(tx.token - 1) and not model.complete_presentation(-1), "Wrong/stale presentation rejected")
		if tx.action_id == "attack": basics.append(tx.source_id)
		for enemy: Dictionary in tx.after.enemies:
			check(enemy.hp <= previous_hp[enemy.id], "No hidden healing")
			previous_hp[enemy.id] = enemy.hp
		check(model.complete_presentation(tx.token) and not model.complete_presentation(tx.token), "Only exact token acknowledges once")
	check(basics == ["hero", "shen", "tang", "qin"], "Exactly one basic per living actor, despite optional categories")
	check(model.snapshot().actors[0].qi == first.actors[0].qi - 3 - 2 + 2, "Only actual known skill costs and actual basic Qi applied")
	var bad: Dictionary = _team()
	bad.actors[0].hp = "160"
	var malformed = Rules.new()
	check(not malformed.configure(bad, "heting_consignee"), "Malformed resource type rejects before session start")
	check(not model.queue_skill("unknown", "art:照夜一线", "du_hui").accepted and not model.queue_skill("hero", "made_up", "du_hui").accepted, "Unknown actor/action rejected")
	var extra: Dictionary = _team(4)
	extra.actors.append(extra.actors[1].duplicate(true))
	check(not Rules.new().configure(extra, "heting_consignee"), "Roster capacity remains four")

func _test_new_cancel_and_death() -> void:
	var team: Dictionary = _team(4, 1, 1000)
	team.actors[0].attack = 200
	team.actors[1].hp = 0
	var model = _rules(team, "heting_consignee")
	check(model.select_target("consignee_guard"), "Focus heavy target")
	check(model.queue_skill("tang", "art:tang_fenjin", "consignee_guard").ok, "Queue exact living target")
	check(model.queue_skill("qin", "lightness:qin_yanliu", "qin").ok, "Queue cancellable existing lightness")
	check(model.cancel_queued("qin", "lightness") and not model.cancel_queued("qin", "lightness"), "Cancel once without charging")
	check(not model.select_actor("shen") and not model.queue_skill("shen", "art:shen_xumai", "hero").ok, "DeadHP0 actor cannot select or queue")
	var first: Dictionary = _step(model)
	check(_unit(first.after, "consignee_guard").hp == 0, "Earlier basic kills exact queued target")
	var cancelled: Dictionary = _step(model)
	check(cancelled.source_id == "tang" and not _event(cancelled, "queue_cancel").is_empty(), "Exact lost target cancels without retargeting skill")
	check(_unit(cancelled.after, "tang").qi == 12 and not _unit(cancelled.after, "tang").categories.martial.used, "Cancelled target charges no Qi/category")
	check(_step(model).source_id == "tang", "Dead teammate skipped; next living actor still gets basic")
	check(_step(model).source_id == "qin", "Fourth roster actor remains independently entitled")
	var view: Dictionary = model.snapshot()
	check(view.actors.size() == 4 and view.actors[1].id == "shen" and view.actors[1].hp == 0 and view.actors[1].basic_round == 0, "Dead roster retained with HP0 and zero basics")

func _test_new_flee_and_pause() -> void:
	var team: Dictionary = _team(2, 1, 1000)
	team.actors[0].hp = 900
	var model = _rules(team, "heting_consignee")
	var item: Dictionary = model.accept_action("item")
	check(item.accepted and item.after.medicine == 2 and item.after.actors[0].hp == 945 and not item.after.actors[0].basic_done, "Medicine uses finite stock without consuming basic")
	check(model.set_paused(true) and model.complete_presentation(item.token) and model.snapshot().paused, "Pause waits for accepted presentation")
	check(not model.advance().accepted and not model.accept_action("item").accepted, "Paused advancement and same-round repeated medicine blocked")
	check(model.set_paused(false), "Resume safe boundary")
	check(model.queue_skill("shen", "lightness:shen_liuying", "shen").ok, "Future queued skill before flee")
	var flee: Dictionary = model.accept_action("flee")
	check(flee.after.outcome == "flee" and flee.after.medicine == 2 and flee.after.actors[0].hp == 945, "Flee retains spent medicine and actual healing")
	check(not _unit(flee.after, "shen").categories.lightness.queued and not model.advance().accepted, "Flee drops queued actions and prevents enemy attacks")
	check(model.complete_presentation(flee.token), "Terminal flee presentation remains acknowledged")

func _clean_tokens(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key not in ["epoch", "token", "pending_token"]: result[key] = _clean_tokens(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_clean_tokens(entry))
		return result
	return value

func _legacy_trace(model, id: String, count: int, formation: String, manual: bool) -> String:
	check(model.configure(_team(count, 7, 1000, Arts.BASE_ART, formation), id), "Legacy trace starts " + id)
	var transcript: Array = [model.snapshot()]
	var limit: int = 0
	while model.snapshot().active and model.snapshot().round < 8 and limit < 200:
		var view: Dictionary = model.snapshot()
		if manual:
			for actor: Dictionary in view.actors:
				if actor.hp <= 0 or actor.basic_done: continue
				for action: Dictionary in actor.actions:
					if Rules.CATEGORIES.has(String(action.category)) and action.available and not action.valid_target_ids.is_empty():
						model.queue_skill(actor.id, action.id, action.valid_target_ids[0])
		var tx: Dictionary = model.advance()
		check(tx.accepted, "Legacy trace makes progress")
		if not tx.accepted: break
		transcript.append(tx)
		check(model.complete_presentation(tx.token), "Legacy exact token ack")
		limit += 1
	return JSON.stringify(_clean_tokens(transcript)).sha256_text()

func _test_legacy_traces() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/heting_consignee_legacy_traces.json"))
	check(fixture is Dictionary and fixture.get("source_commit") == "66008e36", "Exact pre-change legacy trace fixture exists")
	if not fixture is Dictionary: return
	for id: String in LEGACY_IDS:
		for count: int in [1, 4]:
			for formation: String in ["并肩", "护后"]:
				for manual: bool in [false, true]:
					var key: String = "%s/%d/%s/%s" % [id, count, formation, str(manual)]
					check(_legacy_trace(Rules.new(), id, count, formation, manual) == fixture.traces.get(key), "All old specs, scheduler, snapshots and event traces unchanged: " + key)
