extends "res://tests/heting_consignee_balance_test.gd"
## Independent reviewer: actual State/API route, no optional recruits, receipts,
## side-character XP, gear purchases, internal/lightness lessons, or training.
func _run() -> void:
	minimal_build = true
	for school: String in ["听潮阁", "照野堂", "问石门"]:
		var s = _opening(false)
		if not _journey_win(s, "story", "minimum_opening_" + school): _finish(); return
		_finish_opening(s)
		_school(s, school)
		check(s.choose_side_route("rescue") and s.find_side_clue("boatman"), "Mandatory rescue")
		s.heal_rest()
		if not _journey_win(s, "sluice_scout", "minimum_scout_" + school): _finish(); return
		s.heal_rest()
		if not _journey_win(s, "sluice_boss", "minimum_boss_" + school): _finish(); return
		check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"), "Archive observations")
		for seal: int in [2, 0, 1]: check(s.try_seal(seal).valid, "Archive authored seals")
		s.heal_rest()
		if not _journey_win(s, "archive_boss", "minimum_archive_" + school): _finish(); return
		check(s.resolve_chapter_two("open_records"), "Archive public records")
		check(s.begin_mistwood(), "Mandatory Mistwood")
		s.map_id = "mistwood"
		check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin") and s.obtain_mist_access("records") and s.record_mist_gauge("stone"), "Noncombat records route")
		s.heal_rest()
		if not _journey_win(s, "mist_keeper", "minimum_keeper_" + school): _finish(); return
		check(s.resolve_mistwood("release_water"), "Mandatory Mistwood ending")
		check(s.begin_heting(), "Mandatory harbor")
		s.map_id = "heting"
		check(s.take_heting_cargo("meal") and s.deliver_heting_base("heting_relief"), "Base delivery one")
		check(s.take_heting_cargo("sealed") and s.deliver_heting_base("heting_scale"), "Base delivery two")
		check(s.choose_heting_plan("short_ferries") and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief", "short_ferries"), "Base harbor final delivery")
		s.heal_rest()
		check(s.receipt_stage == 0 and not s.companion_unlocked and not s.tangqi_unlocked and not s.qin_unlocked and not s.internal_unlocked and not s.lightness_unlocked, "No optional content contributes XP, resources or lessons")
		print("MINIMUM_ENTRY " + JSON.stringify({"school": school, "level": s.level, "xp": s.xp, "hp": s.hp, "qi": s.qi, "attack": s.attack, "defense": s.defense, "medicine": s.medicine, "coins": s.coins}))
		for harbor: String in ["short_ferries", "open_scale"]:
			for plan: String in ["hold_for_inspection", "return_to_owner"]:
				var test = s._detached_persistent_state()
				# This branch is an explicit synthetic choice permutation after the
				# completely earned route above. No rewards/stats are adjusted.
				test.heting_draft = harbor; test.heting_ending = harbor
				check(test.begin_consignee(), "Begin without optional receipt/recruits")
				for observation: String in test.Consignee.OBSERVATIONS: check(test.observe_consignee(observation), "Solo current batch evidence")
				check(test.resolve_consignee_contradiction(test.Consignee.CORRECT_ANSWER).ok and test.choose_consignee_plan(plan), "Earn draft")
				if not _journey_win(test, "heting_consignee", school + "/" + harbor + "/" + plan): _finish(); return
				var old_coins: int = test.coins
				var old_xp: int = test.xp + 30 * test.level * (test.level - 1)
				check(test.consignee_stage == 3 and test.party_settlement.reward_xp == 0, "Victory secures only")
				check(test.take_consignee_cargo(test.Consignee.BATCH, test.Consignee.SOURCE), "One real lot")
				check(test.finish_consignee_delivery(test.Consignee.receiver_for(plan), plan), "Explicit final handover")
				check(test.coins == old_coins + 60 and test.xp + 30 * test.level * (test.level - 1) == old_xp + 120, "Both solo paths pay equal once-only rewards")
				check(not test.finish_consignee_delivery(test.Consignee.receiver_for(plan), plan), "Duplicate handover blocked")
	_finish()
