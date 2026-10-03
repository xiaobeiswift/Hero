extends "res://tests/heting_consignee_balance_test.gd"
## Production State/API earned routes plus detached policy comparisons. Only
## main's scene-local opening callbacks and map travel are replayed directly.
## No injected XP, stats, coins, medicine, recruits, training or purchased gear.
const CapstoneData = preload("res://scripts/volume_one_capstone_combat_data.gd")
const ROSTERS: Array = [["hero"], ["hero", "shen"], ["hero", "tang"], ["hero", "qin"], ["hero", "shen", "tang"], ["hero", "shen", "qin"], ["hero", "tang", "qin"], ["hero", "shen", "tang", "qin"]]
var timing_policy: String = "timed"
var capstone_matrix: Array[Dictionary] = []
var capstone_profiles: Array[Dictionary] = []
var recovery_results: Array[Dictionary] = []
var timing_comparisons: Array[Dictionary] = []

func _run() -> void:
	for school: String in ["听潮阁", "照野堂", "问石门"]:
		var minimum = _earned_capstone(school, false, false)
		if minimum == null: _finish(); return
		check(minimum.receipt_stage == 0 and not minimum.companion_unlocked and not minimum.tangqi_unlocked and not minimum.qin_unlocked, "Minimum skips optional XP/recruitment/receipt")
		check(not minimum.internal_unlocked and not minimum.lightness_unlocked, "Minimum begins without optional free lessons")
		for formation: String in ["并肩"]:
			check(minimum.formation == formation and not minimum.set_formation("护后"), "Never-recruited solo retains actual default formation")
			var comparison: Dictionary = {}
			for policy: String in ["idle", "greedy", "timed"]:
				var row: Dictionary = _capstone_probe(minimum, ["hero"], policy, school + "/minimum/" + formation)
				capstone_matrix.append(row); comparison[policy] = row
				if policy == "timed": check(row.outcome == "win", "Minimum no-gear/no-recruit/no-lesson/no-grind active strategy wins " + school)
			_record_timing(comparison, school + "/minimum/" + formation)
		_test_capstone_homecoming(minimum, school)
		_test_spent_inventory_recovery(minimum, school)
		for lessons: bool in [false, true]:
			var source = _earned_capstone(school, true, lessons)
			if source == null: _finish(); return
			for formation: String in ["并肩", "护后"]:
				check(source.set_formation(formation), "Genuine roster formation")
				for roster: Array in ROSTERS:
					var comparison: Dictionary = {}
					for policy: String in ["idle", "greedy", "timed"]:
						var row: Dictionary = _capstone_probe(source, roster, policy, school + ("/free_lessons/" if lessons else "/starter_only/") + formation)
						capstone_matrix.append(row); comparison[policy] = row
						if policy == "timed": check(row.outcome == "win", "Every genuine subset/both formations wins actively " + school + str(roster))
					_record_timing(comparison, school + ("/free_lessons/" if lessons else "/starter_only/") + str(roster) + "/" + formation)
	_finish()

func _earned_capstone(school: String, recruits: bool, lessons: bool):
	minimal_build = true
	var s = _opening(recruits)
	if not _journey_win(s, "story", "earned_opening_" + school): return null
	_finish_opening(s)
	_school(s, school)
	if lessons:
		check(s.learn_internal_skill() and s.learn_lightness() and s.equip_art(s.sect_art()), "Explicit free lessons and owned school art")
		s.heal_rest()
	check(s.choose_side_route("rescue") and s.find_side_clue("boatman"), "Earned rescue branch")
	s.heal_rest()
	if not _journey_win(s, "sluice_scout", "earned_scout_" + school): return null
	s.heal_rest()
	if not _journey_win(s, "sluice_boss", "earned_sluice_" + school): return null
	check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"), "Earned archive observations")
	for seal: int in [2, 0, 1]: check(s.try_seal(seal).valid, "Earned archive seal sequence")
	s.heal_rest()
	if not _journey_win(s, "archive_boss", "earned_archive_" + school): return null
	check(s.resolve_chapter_two("open_records"), "Earned archive disposition")
	if recruits:
		check(s.gather_resource("frost_timber").valid and s.repair_bridge(), "Finite gathered bridge material")
		check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Genuine Tang history and invitation")
	check(s.begin_mistwood(), "Earned Mistwood entry")
	s.map_id = "mistwood"
	check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin") and s.obtain_mist_access("records") and s.record_mist_gauge("stone"), "Records route without optional scout reward")
	s.heal_rest()
	if not _journey_win(s, "mist_keeper", "earned_keeper_" + school): return null
	check(s.resolve_mistwood("release_water"), "Earned Mistwood ending")
	if recruits: check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Genuine Qin handover and invitation")
	check(s.begin_heting(), "Earned base Heting entry")
	s.map_id = "heting"
	check(s.take_heting_cargo("meal") and s.deliver_heting_base("heting_relief"), "Finite original meal delivery")
	check(s.take_heting_cargo("sealed") and s.deliver_heting_base("heting_scale"), "Finite original sealed delivery")
	check(s.choose_heting_plan("short_ferries") and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief", "short_ferries"), "Original Heting final handover reward")
	s.heal_rest()
	check(s.begin_consignee(), "Explicit predecessor acceptance")
	for observation: String in s.Consignee.OBSERVATIONS: check(s.observe_consignee(observation), "Actual predecessor observation")
	check(s.resolve_consignee_contradiction(s.Consignee.CORRECT_ANSWER).ok and s.choose_consignee_plan("hold_for_inspection"), "Predecessor finite lot proof and draft")
	if not _journey_win(s, "heting_consignee", "earned_consignee_" + school): return null
	check(s.take_consignee_cargo(s.Consignee.BATCH, s.Consignee.SOURCE) and s.finish_consignee_delivery(s.Consignee.receiver_for("hold_for_inspection"), "hold_for_inspection"), "Actual retained-lot handover reward")
	var xp_before: int = _total_xp(s)
	var coins_before: int = s.coins
	check(s.begin_capstone(), "Explicit new referral after completed handover")
	s.map_id = "frostbridge"
	check(not s.start_party_battle("capstone_authorizer"), "Battle cannot precede old-letter/issued-chain proof")
	check(s.reveal_capstone_letter(), "Original letter authorship/return established")
	check(not s.start_party_battle("capstone_authorizer"), "Letter alone cannot authorize battle")
	check(s.resolve_capstone_evidence(s.Capstone.CORRECT_ANSWER).ok, "Issued register proves chain before pending book exists")
	check(s.capstone_stage == 3 and xp_before == _total_xp(s) and coins_before == s.coins, "Referral/letter/proof adds no invented reward")
	s.heal_rest()
	check(s.receipt_stage == 0 and s.equipment == "旧铁剑" and s.armor == "粗布行衣", "All routes skip optional receipt and purchased/crafted gear")
	capstone_profiles.append({"school": school, "recruits": recruits, "lessons": lessons, "persistent_entry": s.to_dict().duplicate(true), "total_xp": _total_xp(s)})
	return s

func _plan(model) -> String:
	var view: Dictionary = model.snapshot()
	if view.encounter_id != CapstoneData.ENCOUNTER_ID or timing_policy == "greedy": return super._plan(model)
	if timing_policy == "idle": return ""
	model.select_target("liang_zhen")
	var phase: String = String(view.enemies[0].cadence_phase)
	for actor: Dictionary in view.actors:
		if actor.hp <= 0 or actor.basic_done: continue
		var budget: int = int(actor.qi)
		var incoming: Dictionary = _incoming(view, actor.id)
		for action: Dictionary in actor.actions:
			if action.queued: budget -= int(action.cost)
		for action: Dictionary in actor.actions:
			if not Rules.CATEGORIES.has(String(action.category)) or not action.available or budget < int(action.cost): continue
			var target: String = actor.id if action.target_team == "self" else "liang_zhen"
			if action.target_team == "ally":
				if int(action.effects.get("healing", 0)) > 0:
					var deficit: int = 0
					for ally: Dictionary in view.actors:
						var missing: int = int(ally.max_hp) - int(ally.hp)
						if ally.hp > 0 and missing > deficit: deficit = missing; target = ally.id
					if deficit < mini(20, int(action.effects.healing)): continue
				else:
					var threat: int = 0
					for ally: Dictionary in view.actors:
						var risk: Dictionary = _incoming(view, ally.id)
						if ally.hp > 0 and risk.heavy and int(risk.damage) > threat: threat = int(risk.damage); target = ally.id
					if threat == 0: continue
			if bool(action.effects.get("guard", false)) and not incoming.heavy: continue
			if action.category == "martial" and action.target_team == "enemy" and not bool(action.effects.get("guard", false)):
				# Damage waits for the public recovery opening. Tang instead
				# weakens before the published heavy, covering heavy+recovery.
				if int(action.effects.get("weaken_amount", 0)) > 0:
					if phase != "heavy": continue
				elif phase != "recovery": continue
			if action.category == "internal":
				var needed: bool = int(actor.max_hp) - int(actor.hp) >= int(action.effects.get("healing", 0))
				var useful_focus: bool = phase == "recovery" and int(action.effects.get("focus_bonus", 0)) > int(actor.status.focused_damage)
				if not needed and not useful_focus: continue
			if action.category == "lightness":
				var useful_focus: bool = phase == "recovery" and int(action.effects.get("focus_bonus", 0)) > int(actor.status.focused_damage)
				if not incoming.heavy and not useful_focus: continue
			var queued: Dictionary = model.queue_skill(actor.id, action.id, target)
			if queued.ok: budget -= int(action.cost)
	for actor: Dictionary in view.actors:
		if actor.hp <= 0: continue
		for action: Dictionary in actor.actions:
			if action.id == "item" and action.available and (actor.hp <= _incoming(view, actor.id).damage or actor.hp * 100 < actor.max_hp * 35): return actor.id
	return ""

func _capstone_probe(source, roster: Array, policy: String, label: String) -> Dictionary:
	timing_policy = policy
	var s = source._detached_persistent_state()
	check(s.set_party_roster(roster), "Only genuinely recruited roster subset")
	var before: Dictionary = s.to_dict().duplicate(true)
	var projected: Dictionary = State.PartyRoster.battle_resources(s, s._party_payload())
	check(projected.ok, "Actual persistent resources project")
	var built: Dictionary = Catalog.build_team(s, s.party_roster, projected.resources)
	check(built.ok, "No synthetic actor resources")
	var model = Rules.new()
	check(model.configure(built.team, CapstoneData.ENCOUNTER_ID), "Actual earned team configures")
	var start: Dictionary = model.snapshot()
	var accepted: int = 0
	var skill_rounds: Dictionary = {}
	var basics: Dictionary = {}
	var round_living: Dictionary = {}
	var rounds: Array[Dictionary] = []
	var enemy_actions: Array[Dictionary] = []
	var chosen_actions: Array[Dictionary] = []
	var outgoing_by_phase: Dictionary = {"guard": 0, "heavy": 0, "recovery": 0}
	var previous_hp: int = int(start.enemies[0].hp)
	var damage_taken: int = 0
	var healing: int = 0
	var defense_events: Dictionary = {}
	while model.snapshot().active and accepted < 700:
		var view: Dictionary = model.snapshot()
		if not round_living.has(view.round):
			var living: Array[String] = []
			for actor: Dictionary in view.actors:
				if actor.hp > 0: living.append(actor.id)
			round_living[view.round] = living
		var item_actor: String = _plan(model)
		var tx: Dictionary
		if not item_actor.is_empty(): model.select_actor(item_actor); tx = model.accept_action("item")
		else: tx = model.advance()
		check(tx.accepted, "Policy progresses on exact automatic scheduler")
		if not tx.accepted: break
		_check_transaction(tx, skill_rounds)
		if tx.action_id == "attack":
			var key: String = "%d:%s" % [tx.before.round, tx.source_id]
			check(not basics.has(key), "No duplicate living actor basic")
			basics[key] = true
		check(tx.after.enemies.size() == 1 and tx.after.enemies[0].max_hp == start.capstone_provenance.liang_zhen_max_hp and tx.after.enemies[0].hp <= previous_hp, "Fixed sole opponent never heals/scales/adds wave")
		previous_hp = int(tx.after.enemies[0].hp)
		for event: Dictionary in tx.events:
			if event.type == "action":
				if event.source_id == "liang_zhen": enemy_actions.append({"round": event.round, "target": event.target_id, "heavy": event.heavy, "damage": event.damage, "weakened": event.weakened})
				else: chosen_actions.append({"round": event.round, "actor": event.source_id, "action": event.action_id, "target": event.target_id, "phase": view.enemies[0].cadence_phase})
			if event.type == "damage":
				if event.source_id == "liang_zhen": damage_taken += int(event.amount)
				else: outgoing_by_phase[view.enemies[0].cadence_phase] += int(event.amount)
			if event.type == "heal": healing += int(event.amount)
			if event.type in ["guard", "lightness_absorb", "barrier_absorb", "weaken", "focus"]: defense_events[event.type] = int(defense_events.get(event.type, 0)) + 1
			if event.type == "round_end":
				for id: String in round_living[tx.before.round]: check(basics.has("%d:%s" % [tx.before.round, id]), "Every initially living actor receives completed-round basic")
				var hp: Dictionary = {}; var qi: Dictionary = {}
				for actor: Dictionary in tx.after.actors: hp[actor.id] = actor.hp; qi[actor.id] = actor.qi
				rounds.append({"round": tx.before.round, "hp": hp, "qi": qi, "medicine": tx.after.medicine, "enemy_hp": previous_hp})
		check(model.complete_presentation(tx.token), "Exact presentation token accepted once")
		accepted += 1
	check(not model.snapshot().active and s.to_dict() == before, "Bounded detached outcome leaves source intact")
	var row: Dictionary = _record(label, s.level, start, model.snapshot(), policy != "idle", accepted, {"strategy": policy, "detached_probe": true, "roster": roster.duplicate(), "formation": s.formation, "basics_by_round": basics, "completed_rounds": rounds, "actual_enemy_actions": enemy_actions, "manual_actions": chosen_actions, "entry_endurance": start.capstone_provenance, "damage_taken": damage_taken, "healing": healing, "support_events": defense_events, "outgoing_by_phase": outgoing_by_phase})
	return row

func _record_timing(comparison: Dictionary, label: String) -> void:
	var greedy: Dictionary = comparison.greedy
	var timed: Dictionary = comparison.timed
	timing_comparisons.append({"label": label, "greedy_rounds": greedy.rounds, "timed_rounds": timed.rounds, "greedy_damage": greedy.damage_taken, "timed_damage": timed.damage_taken, "greedy_medicine": int(greedy.medicine_start) - int(greedy.medicine_end), "timed_medicine": int(timed.medicine_start) - int(timed.medicine_end), "timed_support": timed.support_events, "timed_opening_damage": timed.outgoing_by_phase.recovery})

func _test_capstone_homecoming(source, school: String) -> void:
	for plan: String in ["pause_batch", "cancel_proven"]:
		var s = source._detached_persistent_state()
		timing_policy = "timed"
		var xp: int = _total_xp(s); var coins: int = s.coins
		if not _journey_win(s, CapstoneData.ENCOUNTER_ID, "actual_capstone_" + school + "/" + plan): return
		check(s.capstone_stage == 4 and s.capstone_draft == "" and s.capstone_ending == "", "Win secures pending book only")
		check(s.party_settlement.reward_xp == 0 and _total_xp(s) == xp and s.coins == coins, "Victory has zero chapter XP/coins")
		check(not s.start_party_battle(CapstoneData.ENCOUNTER_ID), "Accepted victory cannot repeat encounter")
		check(s.classify_capstone_orders(s.Capstone.CORRECT_PARTITION).ok and s.capstone_stage == 5, "Explicit four-order classification after win")
		check(s.choose_capstone_plan(plan), "Explicit reversible plan")
		s.map_id = "sluice"
		check(s.confirm_capstone_disposition(plan) and s.capstone_stage == 6 and _total_xp(s) == xp and s.coins == coins, "Desk disposition still grants no reward")
		s.map_id = "qingwei"
		check(s.finish_capstone_homecoming() and s.capstone_stage == 7 and _total_xp(s) == xp + 160 and s.coins == coins + 80, "Only actual homecoming grants equal160XP/80coins")
		var after: Dictionary = s.to_dict().duplicate(true)
		check(not s.finish_capstone_homecoming() and s.to_dict() == after, "Completion reward cannot replay")

func _test_spent_inventory_recovery(source, school: String) -> void:
	var s = source._detached_persistent_state()
	var xp: int = _total_xp(s)
	var stats: Array = [s.level, s.max_hp, s.max_qi, s.attack, s.defense]
	# Actually consume each finite medicine after taking an announced hit and
	# fleeing. No inventory write, purchase, crafting or reward is involved.
	var spent: int = 0
	while s.medicine > 0 and spent < 30:
		s.map_id = "frostbridge"
		check(s.start_party_battle(CapstoneData.ENCOUNTER_ID), "Spent-inventory entry")
		while s.party_battle_snapshot().round == 1:
			var tx: Dictionary = s.advance_party_battle()
			check(tx.accepted and s.finish_party_presentation(tx.epoch, tx.token).accepted, "Take actual first announced hit")
		var flee: Dictionary = s.party_battle_action("flee")
		check(flee.accepted and s.finish_party_presentation(flee.epoch, flee.token).accepted, "Retain real damage on flee")
		check(s.use_medicine(), "Consume one actual existing medicine")
		spent += 1
	# Repeated unskilled defeats exercise the unchanged8-coin loss policy.
	# They are resource-loss trials, never training wins or injected growth.
	var defeats: int = 0
	while s.coins > 0 and defeats < 100:
		timing_policy = "idle"
		var loss: Dictionary = _fight(s, CapstoneData.ENCOUNTER_ID, false, "spent_coin_defeat_" + school)
		check(loss.get("outcome") == "defeat" and s.capstone_stage == 3, "Actual idle defeat spends capped coins and preserves proof")
		if loss.get("outcome") != "defeat": return
		check(s.map_id == "frostbridge" and s.position == Vector2(405, 430), "Only new encounter recovers at safe Frostbridge rest approach")
		defeats += 1
	check(s.coins == 0 and s.medicine == 0 and _total_xp(s) == xp, "Genuinely depleted zero/zero trial gained no XP")
	check(stats == [s.level, s.max_hp, s.max_qi, s.attack, s.defense], "Defeats fabricated no stats")
	var hp_before: int = s.hp; var qi_before: int = s.qi
	s.map_id = "qingwei"
	check(s.learn_internal_skill() and s.learn_lightness() and s.equip_art(s.sect_art()), "Existing free lessons and owned school art remain available with zero coins")
	check(s.hp == hp_before and s.qi == qi_before and _total_xp(s) == xp and s.coins == 0 and s.medicine == 0, "Learning adds no invented healing or consumables/XP")
	s.heal_rest()
	check(s.hp == s.max_hp and s.qi == s.max_qi and s.coins == 0 and s.medicine == 0, "Existing explicit free rest restores HP/Qi only")
	timing_policy = "timed"
	var recovery: Dictionary = _fight(s, CapstoneData.ENCOUNTER_ID, true, "zero_zero_free_lesson_retry_" + school)
	check(recovery.get("outcome") == "win" and s.capstone_stage == 4 and _total_xp(s) == xp and s.coins == 0 and s.medicine == 0, "Zero/zero free-lesson recovery wins without fabricated XP/stats/resources")
	recovery_results.append({"school": school, "medicine_actually_spent": spent, "actual_defeats": defeats, "total_xp_before_after": xp, "entry_stats": stats, "result": recovery})

func _total_xp(s) -> int:
	return s.xp + 30 * s.level * (s.level - 1)

func _finish() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		check(file != null, "Capstone evidence artifact opens")
		if file:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "entry_profiles": capstone_profiles, "matrix": capstone_matrix, "timing_comparisons": timing_comparisons, "recovery": recovery_results, "journey": journey, "scope": "Production State/API earned routes and detached model comparisons. Map-only travel and exact scene-local opening effects are explicit; no main-scene proximity, rendering or playable chapter claim."}, "\t")); file.close()
	print("%s: %d capstone earned checks; %d comparisons; %d zero/zero recoveries" % ["PASS" if failures == 0 else "FAIL", checks, capstone_matrix.size(), recovery_results.size()])
	quit(0 if failures == 0 else 1)
