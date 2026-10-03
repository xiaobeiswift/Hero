extends "res://tests/automatic_combat_balance_test.gd"
## Model balance matrix on real earned State/API journeys; not scene/UI proof.
## All school branches start from the earned opening; no direct resource edits.
var matrix: Array[Dictionary] = []
var entry_profiles: Array[Dictionary] = []
var minimal_build: bool = false
var probe_roster: Array = ["hero"]

func _run() -> void:
	for minimal: bool in [false, true]:
		minimal_build = minimal
		for school: String in ["听潮阁", "照野堂", "问石门"]:
			var s = _opening(true)
			if not _journey_win(s, "story", "consignee_opening_" + school): _finish(); return
			_finish_opening(s)
			_school(s, school)
			check(s.choose_side_route("rescue") and s.find_side_clue("boatman"), "Consignee real rescue route")
			s.heal_rest()
			if not _journey_win(s, "sluice_scout", "consignee_scout_" + school): _finish(); return
			s.heal_rest()
			if not _journey_win(s, "sluice_boss", "consignee_sluice_" + school): _finish(); return
			check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"), "Consignee real archive clues")
			for seal: int in [2, 0, 1]: check(s.try_seal(seal).valid, "Consignee real seals")
			s.heal_rest()
			if not _journey_win(s, "archive_boss", "consignee_archive_" + school): _finish(); return
			check(s.resolve_chapter_two("open_records"), "Consignee real archive ending")
			check(s.gather_resource("frost_timber").valid and s.repair_bridge(), "Consignee finite bridge resources")
			check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Consignee real Tang recruitment")
			check(s.begin_mistwood(), "Consignee real Mistwood acceptance")
			s.map_id = "mistwood"
			check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin") and s.obtain_mist_access("records") and s.record_mist_gauge("stone"), "Consignee nongrind Mistwood records route")
			s.heal_rest()
			if not _journey_win(s, "mist_keeper", "consignee_mist_" + school): _finish(); return
			check(s.resolve_mistwood("release_water"), "Consignee real Mistwood ending")
			check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Consignee real Qin recruitment")
			check(s.begin_heting(), "Consignee real harbor acceptance")
			s.map_id = "heting"
			check(s.take_heting_cargo("meal") and s.deliver_heting_base("heting_relief"), "Consignee real first harbor delivery")
			check(s.take_heting_cargo("sealed") and s.deliver_heting_base("heting_scale"), "Consignee real second harbor delivery")
			check(s.choose_heting_plan("short_ferries") and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief", "short_ferries"), "Consignee real harbor final reward")
			check(s.Receipt.begin(s), "Consignee real receipt acceptance")
			s.heal_rest()
			if not _journey_win(s, "heting_receipt", "consignee_receipt_" + school): _finish(); return
			check(s.level == 6 and s.receipt_stage == 2, "Consignee entry naturally earns level6 and receipt stage2")
			var medicine_before: int = s.medicine
			s.heal_rest()
			check(s.medicine == medicine_before, "Consignee rest grants no medicine")
			entry_profiles.append({"school": school, "build": "starter_only" if minimal_build else "school_lessons", "level": s.level, "xp": s.xp, "hp": s.hp, "qi": s.qi, "attack": s.attack, "defense": s.defense, "equipment": s.equipment, "armor": s.armor, "medicine": s.medicine, "coins": s.coins, "art": s.equipped_art, "art_uses": s.art_uses.duplicate(true), "advanced_arts": s.learned_arts.duplicate(true)})
			for formation: String in ["并肩", "护后"]:
				check(s.set_formation(formation), "Natural requested formation")
				for roster: Array in [["hero"], ["hero", "shen"], ["hero", "tang"], ["hero", "qin"], ["hero", "shen", "tang"], ["hero", "shen", "qin"], ["hero", "tang", "qin"], ["hero", "shen", "tang", "qin"]]:
					probe_roster = roster
					for policy: bool in [false, true]:
						var row: Dictionary = _probe(s, "heting_consignee", roster.size(), policy, school + "_" + formation + ("_starter_only" if minimal_build else "_school_lessons"))
						matrix.append(row)
						if policy: check(row.outcome == "win", "Natural queued level6 strategy wins " + school + "/" + formation + "/" + str(roster))
	_finish()

func _school(s, school: String) -> void:
	if not minimal_build:
		super._school(s, school)
		return
	s.choose_sect(school)
	s.quest_stage = 6 # Exact main._join_sect callback, no XP or stats written.
	check(s.equip_art("照夜一线"), "Minimal build uses owned starter art")
	check(not s.internal_unlocked and not s.lightness_unlocked, "Minimal build skips optional lessons")
	check(s.equipment == "旧铁剑" and s.armor == "粗布行衣", "Minimal build retains starter gear")
	s.heal_rest()

func _probe(source, encounter: String, count: int, policy: bool, label: String) -> Dictionary:
	var s = source._detached_persistent_state()
	check(s.set_party_roster(probe_roster), "Consignee roster uses only real recruits")
	check(s.party_roster.size() == count, "Natural subset count matches requested roster")
	var before: Dictionary = s.to_dict().duplicate(true)
	var projected: Dictionary = State.PartyRoster.battle_resources(s, s._party_payload())
	check(projected.ok, "Consignee projects actual persisted resources")
	var built: Dictionary = Catalog.build_team(s, s.party_roster, projected.resources)
	check(built.ok, "Consignee builds natural detached roster")
	var model = Rules.new()
	check(model.configure(built.team, encounter), "Consignee natural entry configures")
	var start: Dictionary = model.snapshot()
	var accepted: int = 0
	var cooldown_rounds: Dictionary = {}
	var basics: Dictionary = {}
	var round_living: Dictionary = {}
	var round_records: Array[Dictionary] = []
	var enemy_actions: Array[Dictionary] = []
	var previous_hp: Dictionary = {"du_hui": 260, "consignee_guard": 160}
	while model.snapshot().active and accepted < 500:
		var view: Dictionary = model.snapshot()
		if not round_living.has(view.round):
			var living: Array[String] = []
			for actor: Dictionary in view.actors:
				if actor.hp > 0: living.append(actor.id)
			round_living[view.round] = living
		var item_actor: String = _plan(model) if policy else ""
		var tx: Dictionary
		if not item_actor.is_empty():
			model.select_actor(item_actor)
			tx = model.accept_action("item")
		else: tx = model.advance()
		check(tx.accepted, "Natural consignee transaction progresses")
		if not tx.accepted: break
		_check_transaction(tx, cooldown_rounds)
		if tx.action_id == "attack":
			var key: String = "%d:%s" % [tx.before.round, tx.source_id]
			check(not basics.has(key), "Natural actor never gains duplicate round basic")
			basics[key] = true
		for enemy: Dictionary in tx.after.enemies:
			check(enemy.max_hp == start.consignee_provenance[enemy.id + "_max_hp"] and enemy.hp <= previous_hp[enemy.id], "Natural fight never heals or pads durability")
			previous_hp[enemy.id] = enemy.hp
		for event: Dictionary in tx.events:
			if event.type == "action" and event.source_id in ["du_hui", "consignee_guard"]:
				enemy_actions.append({"round": event.round, "source": event.source_id, "target": event.target_id, "heavy": event.heavy, "damage": event.damage, "weakened": event.weakened})
			if event.type == "round_end":
				for id: String in round_living[tx.before.round]:
					check(basics.has("%d:%s" % [tx.before.round, id]), "Every initially living actor gets exactly one completed-round basic")
				var hp: Dictionary = {}
				var qi: Dictionary = {}
				for actor: Dictionary in tx.after.actors:
					hp[actor.id] = actor.hp
					qi[actor.id] = actor.qi
				round_records.append({"round": tx.before.round, "hp": hp, "qi": qi, "medicine": tx.after.medicine, "enemy_hp": previous_hp.duplicate(true)})
		check(model.complete_presentation(tx.token), "Natural consignee exact token acknowledgement")
		accepted += 1
	check(not model.snapshot().active, "Natural consignee outcome bounded")
	check(s.to_dict() == before, "Consignee diagnostic never changes earned state")
	return _record(label, s.level, start, model.snapshot(), policy, accepted, {"detached_probe": true, "roster": probe_roster.duplicate(), "basics_by_round": basics, "completed_rounds": round_records, "actual_enemy_actions": enemy_actions, "entry_endurance": start.consignee_provenance})

func _target(view: Dictionary) -> String:
	# Receipt keeps its prior support-first rule. In the new encounter, a heavy
	# opponent is the focus, then a recovery opening, then the first living foe.
	if view.encounter_id != "heting_consignee": return super._target(view)
	for phase: String in ["heavy", "recovery", "light"]:
		for enemy: Dictionary in view.enemies:
			if enemy.hp > 0 and enemy.get("cadence_phase") == phase: return enemy.id
	return ""

func _finish() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		check(file != null, "Consignee matrix artifact opens")
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures, "matrix": matrix, "entry_profiles": entry_profiles, "journey": journey, "scope": "Current automatic model plus genuine State/API journey. Scene-local opening dialogue effects are explicitly replayed; no scene proximity or manual UI journey claimed."}, "\t"))
			file.close()
	print("%s: %d natural consignee balance checks; %d matrix outcomes" % ["PASS" if failures == 0 else "FAIL", checks, matrix.size()])
	quit(0 if failures == 0 else 1)
