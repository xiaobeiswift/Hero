extends SceneTree
## Deterministic advanced-school-art acceptance tests.
## Run with an external temporary XDG_DATA_HOME; never touches SAVE_PATH.
const State = preload("res://scripts/game_state.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
const TEST_SAVE = "user://advanced-martial-rules.json"
const BAD_SAVE = "user://advanced-martial-invalid.json"
const FAIL_DIRECTORY = "user://advanced-martial-save-target"
const SCHOOLS = ["听潮阁", "照野堂", "问石门"]
const SCHOOL_ARTS = {
	"听潮阁": ["回潮断浪", "束潮削势", "伏汐藏锋"],
	"照野堂": ["青灯续脉", "青灯息争", "续灯引锋"],
	"问石门": ["磐石回锋", "石隙封腕", "藏锋立岳"],
}
const ADVANCED = [
	{"id":"束潮削势", "name":"束潮削势", "sect":"听潮阁", "style":"拆势", "description":"回刃束住来势，以短促潮声拆散对手的劲路。", "required_sect_rank":2, "learn_cost":2, "cost":3, "cooldown":2, "attack_multiplier":1, "damage_bonus":8, "healing":0, "guard":false, "weaken_amount":5, "weaken_strikes":2, "focus_attack_multiplier":0, "focus_bonus":0},
	{"id":"伏汐藏锋", "name":"伏汐藏锋", "sect":"听潮阁", "style":"蓄锋", "description":"将长锋藏进退潮的空隙，待下一次平击引汐而出。", "required_sect_rank":2, "learn_cost":3, "cost":4, "cooldown":3, "attack_multiplier":1, "damage_bonus":6, "healing":0, "guard":false, "weaken_amount":0, "weaken_strikes":0, "focus_attack_multiplier":1, "focus_bonus":18},
	{"id":"青灯息争", "name":"青灯息争", "sect":"照野堂", "style":"护生", "description":"一掌缓住争势，一息照拂伤处，使来刃难以尽力。", "required_sect_rank":2, "learn_cost":2, "cost":3, "cooldown":3, "attack_multiplier":1, "damage_bonus":0, "healing":18, "guard":false, "weaken_amount":6, "weaken_strikes":2, "focus_attack_multiplier":0, "focus_bonus":0},
	{"id":"续灯引锋", "name":"续灯引锋", "sect":"照野堂", "style":"续战", "description":"以短息续灯，把余劲留在掌锋，待下一招收束争斗。", "required_sect_rank":2, "learn_cost":3, "cost":4, "cooldown":3, "attack_multiplier":1, "damage_bonus":0, "healing":14, "guard":false, "weaken_amount":0, "weaken_strikes":0, "focus_attack_multiplier":1, "focus_bonus":6},
	{"id":"石隙封腕", "name":"石隙封腕", "sect":"问石门", "style":"封劲", "description":"循石隙点向发力之处，以轻触封住两段劲路。", "required_sect_rank":2, "learn_cost":2, "cost":3, "cooldown":2, "attack_multiplier":1, "damage_bonus":4, "healing":0, "guard":false, "weaken_amount":8, "weaken_strikes":2, "focus_attack_multiplier":0, "focus_bonus":0},
	{"id":"藏锋立岳", "name":"藏锋立岳", "sect":"问石门", "style":"守中蓄锋", "description":"立身承势，藏锋于静；护住这一击，再向空隙递出余力。", "required_sect_rank":2, "learn_cost":3, "cost":4, "cooldown":3, "attack_multiplier":1, "damage_bonus":0, "healing":0, "guard":true, "weaken_amount":0, "weaken_strikes":0, "focus_attack_multiplier":1, "focus_bonus":10},
]
const ORIGINAL = [
	{"id":"照夜一线", "name":"照夜一线", "sect":"", "style":"破阵", "description":"凝气成线，以一往无前之势照破长夜。", "cost":3, "cooldown":2, "attack_multiplier":2, "damage_bonus":8, "healing":0, "guard":false, "required_sect_rank":0},
	{"id":"回潮断浪", "name":"回潮断浪", "sect":"听潮阁", "style":"强攻", "description":"借回潮之势连斩断浪，以更深的调息换取凌厉一击。", "cost":4, "cooldown":3, "attack_multiplier":2, "damage_bonus":16, "healing":0, "guard":false, "required_sect_rank":1},
	{"id":"青灯续脉", "name":"青灯续脉", "sect":"照野堂", "style":"疗伤", "description":"青灯引气，续接伤脉；回身一掌，攻守相济。", "cost":3, "cooldown":3, "attack_multiplier":1, "damage_bonus":0, "healing":30, "guard":false, "required_sect_rank":1},
	{"id":"磐石回锋", "name":"磐石回锋", "sect":"问石门", "style":"守势", "description":"稳如磐石，回锋御敌；出手后守中卸力，收拢破绽。", "cost":3, "cooldown":2, "attack_multiplier":1, "damage_bonus":10, "healing":0, "guard":true, "required_sect_rank":1},
]
var checks: int = 0
var failures: int = 0

func _init() -> void:
	# The standard runner and documented direct invocation provide isolation.
	# Refuse an unisolated direct invocation before writing even a test-only save.
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Run advanced_martial_rules_test.gd with an isolated XDG_DATA_HOME")
		quit(2)
		return
	_test_catalog()
	_test_learning()
	_test_deeds()
	_test_weaken()
	_test_focus()
	_test_proficiency()
	_test_turn_order_and_cooldown()
	_test_cleanup()
	_test_legacy_saves()
	_test_current_saves()
	_test_bad_saves_and_atomicity()
	_cleanup_files()
	if failures == 0:
		print("PASS: %d advanced martial rule checks (C/L/M/W/F/E/S)" % checks)
	else:
		push_error("FAIL: %d of %d advanced martial rule checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _snapshot(s) -> Dictionary:
	# Include every script variable, not only to_dict(): failed operations must
	# preserve enemy state, turn/intent/log, guard, all effects, and trial counters.
	var result: Dictionary = {}
	for property: Dictionary in s.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = s.get(String(property.name))
			result[String(property.name)] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func _inner(school: String = "听潮阁"):
	var s = State.new()
	s.choose_sect(school)
	s.gain_xp(180)
	s.sect_trial_won = true
	s.complete_sect_trial()
	return s

func _fighter(id: String = "束潮削势"):
	var school: String = String(Arts.definition(id).get("sect", "听潮阁"))
	var s = _inner(school)
	s.sect_merit = 5
	for art: String in SCHOOL_ARTS[school]:
		if art != s.sect_art():
			s.learn_art(art)
	s.equip_art(id)
	s.attack = 30
	s.defense = 8
	s.max_hp = 500
	s.hp = 500
	s.max_qi = 20
	s.qi = 20
	s.start_battle("archive_boss")
	s.enemy_max_hp = 10000
	s.enemy_hp = 10000
	return s

func _events(s, route: String = "rescue", outcome: String = "open_records") -> void:
	s.side_choice = route
	s.side_found.assign(["boatman", "ledger"])
	s.side_clues = 2
	s.side_stage = 3
	s.side_reward_claimed = true
	s.chapter_two_stage = 4
	s.chapter_two_ending = outcome
	s.archive_clues.assign(["clerk", "inscription"])
	s.seal_sequence.assign([2, 0, 1])

func _seed_effects(s) -> void:
	s.enemy_weaken_amount = 8
	s.enemy_weaken_strikes = 2
	s.focused_damage = 48

func _clear_effects(s, label: String) -> void:
	check(s.enemy_weaken_amount == 0 and s.enemy_weaken_strikes == 0 and s.focused_damage == 0, label)

func _write(path: String, data: Dictionary, version: Variant = 5) -> void:
	_write_text(path, JSON.stringify({"version": version, "player": data}))

func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Test fixture is writable: " + path)
	if file != null:
		file.store_string(content)
		file.close()

func _reject_load(s, data: Dictionary, label: String, version: Variant = 5, error: int = ERR_FILE_CORRUPT) -> void:
	_write(BAD_SAVE, data, version)
	var before: Dictionary = _snapshot(s)
	check(s.load_game(BAD_SAVE) == error and _snapshot(s) == before, label)

func _test_catalog() -> void:
	check(Arts.all_ids().size() == 10, "C01: catalog has ten arts")
	var ids = Arts.all_ids()
	ids.clear()
	check(Arts.all_ids().size() == 10, "C01: catalog ID list is detached")
	for expected: Dictionary in ADVANCED + ORIGINAL:
		var definition: Dictionary = Arts.definition(expected.id)
		check(definition.is_read_only(), "C01: immutable definition " + expected.id)
		for key: String in ADVANCED[0]:
			check(definition.has(key), "C03: complete field %s.%s" % [expected.id, key])
		for key: String in expected:
			check(definition.get(key) == expected[key], "C03: exact value %s.%s" % [expected.id, key])
		if int(expected.required_sect_rank) < 2:
			for key: String in ["learn_cost", "weaken_amount", "weaken_strikes", "focus_attack_multiplier", "focus_bonus"]:
				check(definition.get(key) == 0, "C03: original art has zero " + key)
		var copy: Dictionary = definition.duplicate(true)
		copy["cost"] = 99
		check(Arts.definition(expected.id).cost == expected.cost, "C01: detached definition copy " + expected.id)
	var lone = State.new()
	check(lone.school_art_ids() == [Arts.BASE_ART] and lone.available_arts() == [Arts.BASE_ART], "C02: unjoined hero only browses/owns base art")
	for school: String in SCHOOLS:
		var count: int = 0
		for id: String in Arts.all_ids():
			if Arts.definition(id).sect == school:
				count += 1
		check(count == 3, "C01: three exclusive arts for " + school)
		var s = State.new()
		s.choose_sect(school)
		for rank: int in [1, 2]:
			s.sect_rank = rank
			check(s.school_art_ids() == [Arts.BASE_ART] + SCHOOL_ARTS[school], "C02: stable four-art browse order " + school)
			check(s.available_arts() == [Arts.BASE_ART, SCHOOL_ARTS[school][0]], "C02: promotion does not grant advanced arts " + school)
		var before = _snapshot(s)
		var browse = s.school_art_ids()
		var available = s.available_arts()
		browse.clear()
		available.clear()
		check(_snapshot(s) == before and s.school_art_ids().size() == 4 and s.available_arts().size() == 2, "C01/C02: queries return detached arrays")
		s.attack = 30
		for id: String in s.school_art_ids():
			var def: Dictionary = Arts.definition(id)
			var description: String = s.art_description(id)
			var damage: int = 30 * int(def.attack_multiplier) + int(def.damage_bonus)
			check(description.contains(str(damage)) and description.contains(String(def.description)), "C03: data-derived damage/description " + id)
			check(description.contains(str(def.cost)) and description.contains(str(def.cooldown)), "C03: data-derived qi/cooldown " + id)
			if int(def.weaken_amount) > 0:
				check(description.contains("卸劲") and description.contains(str(def.weaken_amount)) and description.contains("次攻击"), "C03: weaken description uses attack-count units " + id)
			if int(def.focus_attack_multiplier) > 0:
				check(description.contains("蓄锋") and description.contains(str(30 + int(def.focus_bonus))), "C03: focus description uses attack snapshot value " + id)
	check(Arts.definition("unknown").is_empty() and lone.art_description("unknown").is_empty(), "C03: unknown art queries remain safe")

func _test_learning() -> void:
	for school: String in SCHOOLS:
		var cheap: String = SCHOOL_ARTS[school][1]
		var dear: String = SCHOOL_ARTS[school][2]
		var novice = State.new()
		novice.choose_sect(school)
		novice.sect_merit = 99
		var before = _snapshot(novice)
		check(not novice.can_learn_art(cheap) and not novice.learn_art(cheap) and _snapshot(novice) == before, "L01: merit cannot bypass inner rank " + school)
		var s = _inner(school)
		s.equip_art(s.sect_art())
		before = _snapshot(s)
		check(s.can_learn_art(cheap) and _snapshot(s) == before, "L02: eligibility query is pure")
		check(s.learn_art(cheap), "L02: two-merit purchase succeeds " + school)
		var expected: Dictionary = before.duplicate(true)
		expected.sect_merit = 1
		expected.learned_arts = [cheap]
		check(_snapshot(s) == expected, "L02: purchase changes only exact merit and ownership " + school)
		before = _snapshot(s)
		check(not s.learn_art(cheap) and not s.can_learn_art(cheap) and _snapshot(s) == before, "L02/L04: duplicate purchase rejected atomically")
		check(not s.learn_art(dear) and _snapshot(s) == before, "L04: insufficient merit rejected atomically")
		check(not s.learn_art("unknown") and not s.learn_art(Arts.BASE_ART) and not s.learn_art(s.sect_art()) and _snapshot(s) == before, "L04: only advanced known arts purchasable")
		for other: String in SCHOOLS:
			if other != school:
				check(not s.learn_art(SCHOOL_ARTS[other][1]) and not s.equip_art(SCHOOL_ARTS[other][1]) and _snapshot(s) == before, "L04: cross-school purchase/equip rejected")
		var costly = _inner(school)
		check(costly.art_rank(dear) == 1 and not costly.available_arts().has(dear), "L03: preview proficiency is not ownership")
		check(costly.learn_art(dear) and costly.sect_merit == 0 and costly.equipped_art == Arts.BASE_ART, "L03: three-merit purchase preserves equipped art")
		check(costly.equip_art(dear) and costly.equipped_art == dear, "L03: explicit equip selects purchased art")
		costly.sect_merit = 2
		check(costly.learn_art(cheap), "L06: both arts may be learned in either order")
		for id: String in costly.school_art_ids():
			before = _snapshot(costly)
			check(costly.equip_art(id), "L06: free exploration equip " + id)
			expected = before.duplicate(true)
			expected.equipped_art = id
			check(_snapshot(costly) == expected, "L06: equip changes no resources/stats/proficiency/effects")
		var battle = _fighter(dear)
		_seed_effects(battle)
		battle.skill_cooldown = 2
		battle.sect_merit = 99
		battle.learned_arts.erase(cheap)
		before = _snapshot(battle)
		check(not battle.learn_art(cheap) and not battle.can_learn_art(cheap) and _snapshot(battle) == before, "L04: combat purchase rejects every mutation")
		for id: String in [Arts.BASE_ART, dear, "unknown"]:
			check(not battle.equip_art(id) and _snapshot(battle) == before, "L05: combat equip rejected even for same art")

func _test_deeds() -> void:
	for school: String in SCHOOLS:
		var s = State.new()
		s.choose_sect(school)
		s.sect_trial_won = true
		var old_defense: int = s.defense
		var old_qi: int = s.max_qi
		check(s.complete_sect_trial() and s.sect_rank == 2 and s.sect_merit == 3 and s.defense == old_defense + 1 and s.max_qi == old_qi + 1, "M01: exact one-time promotion " + school)
		s.learn_art(SCHOOL_ARTS[school][2])
		var before = _snapshot(s)
		check(not s.complete_sect_trial() and _snapshot(s) == before, "M01: spending merit cannot reopen promotion")
	var unjoined = State.new()
	_events(unjoined)
	var before = _snapshot(unjoined)
	check(unjoined.eligible_sect_deeds().is_empty() and not unjoined.claim_sect_deed("sluice") and _snapshot(unjoined) == before, "M02: completed events require membership")
	unjoined.choose_sect("听潮阁")
	before = _snapshot(unjoined)
	check(unjoined.eligible_sect_deeds().is_empty() and not unjoined.claim_sect_deed("archive") and _snapshot(unjoined) == before, "M02: completed events require inner rank")
	var s = _inner()
	before = _snapshot(s)
	check(s.eligible_sect_deeds().is_empty() and not s.claim_sect_deed("sluice") and not s.claim_sect_deed("archive") and not s.claim_sect_deed("unknown") and _snapshot(s) == before, "M02: unfinished and unknown deeds rejected atomically")
	_events(s)
	s.side_reward_claimed = false
	s.chapter_two_ending = ""
	before = _snapshot(s)
	check(not s.claim_sect_deed("sluice") and not s.claim_sect_deed("archive") and _snapshot(s) == before, "M02: exact completion conditions required")
	for route: String in ["rescue", "pursuit"]:
		for outcome: String in ["open_records", "protect_witness"]:
			s = _inner()
			_events(s, route, outcome)
			before = _snapshot(s)
			var eligible = s.eligible_sect_deeds()
			check(eligible == ["sluice", "archive"] and _snapshot(s) == before, "M03/M04: both moral choices grant identical eligibility")
			eligible.clear()
			check(s.eligible_sect_deeds() == ["sluice", "archive"] and _snapshot(s) == before, "M03: query is detached and never auto-claims")
			for deed: String in ["sluice", "archive"]:
				before = _snapshot(s)
				check(s.claim_sect_deed(deed), "M03/M04: explicit deed receipt " + route + "/" + outcome + "/" + deed)
				var expected = before.duplicate(true)
				expected.sect_merit = int(before.sect_merit) + 1
				expected.claimed_deeds.append(deed)
				check(_snapshot(s) == expected, "M03: deed only adds one merit and one receipt")
				before = _snapshot(s)
				check(not s.claim_sect_deed(deed) and _snapshot(s) == before, "M03/M06: duplicate/old callback cannot replay receipt")
			check(s.sect_merit == 5 and s.eligible_sect_deeds().is_empty(), "M03/M04: five-merit complete budget")
	for events_first: bool in [false, true]:
		for cheap_first: bool in [false, true]:
			s = State.new()
			s.choose_sect("听潮阁")
			if events_first:
				_events(s)
			s.sect_trial_won = true
			s.complete_sect_trial()
			var first: String = "束潮削势" if cheap_first else "伏汐藏锋"
			var second: String = "伏汐藏锋" if cheap_first else "束潮削势"
			check(s.learn_art(first), "M05: either learning order begins with promotion funds")
			if not events_first:
				_events(s)
			check(s.claim_sect_deed("sluice") and s.claim_sect_deed("archive") and s.learn_art(second) and s.sect_merit == 0 and s.learned_arts.size() == 2, "M05: both event and purchase orders yield both arts")
	s = _inner()
	_events(s)
	s.start_battle()
	_seed_effects(s)
	before = _snapshot(s)
	check(s.eligible_sect_deeds().is_empty() and not s.claim_sect_deed("sluice") and not s.claim_sect_deed("archive") and _snapshot(s) == before, "M02: in-battle deed claims rejected atomically")
	s.battle_action("flee")
	s.sect_merit = 9999
	before = _snapshot(s)
	check(not s.claim_sect_deed("sluice") and not s.claim_sect_deed("archive") and _snapshot(s) == before, "M06: merit cap rejects without consuming receipts")
	s.sect_merit = 9998
	check(s.claim_sect_deed("sluice") and s.sect_merit == 9999 and not s.claimed_deeds.has("archive"), "M06: last capacity accepts exactly one receipt")
	before = _snapshot(s)
	check(not s.claim_sect_deed("archive") and _snapshot(s) == before, "M06: second receipt remains claimable after capacity frees")
	s.sect_merit = 9998
	check(s.claim_sect_deed("archive") and s.sect_merit == 9999, "M06: previously full reward is not lost")
	before = _snapshot(s)
	check(not s.finish_side_quest() and not s.mark_archive_victory() and not s.resolve_chapter_two("open_records") and _snapshot(s) == before, "M06: repeated narrative completion does not grant merit")

func _test_weaken() -> void:
	var s = _fighter()
	var result: Dictionary = s.battle_action("skill")
	check(result.valid and s.enemy_hp == 9962 and s.qi == 17 and s.skill_cooldown == 2, "W01: exact direct damage/cost/cooldown")
	check(s.hp == 496 and s.enemy_weaken_amount == 5 and s.enemy_weaken_strikes == 1, "W01: newly applied weaken affects immediate retaliation")
	s = _fighter("青灯息争")
	s.enemy_base_attack = 17
	s.enemy_strong_attack = 17
	s.enemy_weaken_amount = 6
	s.enemy_weaken_strikes = 2
	s.battle_kind = "story"
	s.battle_action("attack")
	check(s.hp == 497 and s.enemy_weaken_strikes == 1, "W02: 17 - 8 - 6 = 3 on first affected strike")
	s.battle_action("attack")
	check(s.hp == 494 and s.enemy_weaken_amount == 0 and s.enemy_weaken_strikes == 0, "W02: second strike consumes final weaken charge")
	s.battle_action("attack")
	check(s.hp == 485, "W02: third strike is unmodified")
	for kind: String in ["story", "archive_boss"]:
		s = _fighter("青灯息争")
		s.battle_kind = kind
		s.turn = 1
		s.exposed_turns = 2
		s.enemy_weaken_amount = 6
		s.enemy_weaken_strikes = 2
		s.battle_action("attack")
		check(s.hp == 480 and s.enemy_weaken_strikes == 1, "W03: weaken precedes exposure (31 - 8 - 6 + 3 = 20)")
		check(s.exposed_turns == (2 if kind == "archive_boss" else 1), "W03: old exposure ticks then unguarded boss heavy refreshes")
	for companion: String in ["", "沈青", "唐栖"]:
		s = _fighter("青灯息争")
		s.turn = 1
		s.exposed_turns = 2
		s.enemy_weaken_amount = 6
		s.enemy_weaken_strikes = 2
		_set_companion(s, companion, "护后")
		s.battle_action("guard")
		var damage: int = 6 if companion.is_empty() else (4 if companion == "沈青" else 1)
		check(s.hp == 500 - damage and s.exposed_turns == 0 and s.enemy_weaken_strikes == 1, "W04: clear exposure, ceil guard, then companion cover " + companion)
	s = _fighter("石隙封腕")
	s.enemy_base_attack = 2
	s.enemy_weaken_amount = 8
	s.enemy_weaken_strikes = 1
	result = s.battle_action("attack")
	check(s.hp == 499 and s.enemy_weaken_amount == 0 and s.enemy_weaken_strikes == 0, "W05: one-damage floor still consumes final charge")
	for false_claim: String in ["减少 8", "减伤 8", "化去 8", "卸去 8", "削减 8"]:
		check(not String(result.message).contains(false_claim), "W05: log does not claim unavailable eight-point reduction")
	for companion_kill: bool in [false, true]:
		s = _fighter()
		_seed_effects(s)
		if companion_kill:
			_set_companion(s, "沈青")
			s._companion_attack_count = 1
			s.enemy_hp = 80
		else:
			s.enemy_hp = 1
		result = s.battle_action("attack")
		check(result.won and not s.battle_active and s.hp == 500 and not String(result.message).contains("你受到") and not String(result.message).contains("卸劲"), "W06: player/companion kill skips all retaliation and reduction logs")
		_clear_effects(s, "W06: victory clears both effects")
	s = _fighter()
	s.enemy_weaken_amount = 8
	s.enemy_weaken_strikes = 1
	s.battle_action("skill")
	check(s.enemy_weaken_amount == 8 and s.enemy_weaken_strikes == 1 and s.hp == 499, "W07: refresh max(8,5)/max(1,2), then consume one strike")

func _set_companion(s, companion: String, formation: String = "并肩") -> void:
	s.companion_unlocked = companion == "沈青"
	s.tangqi_unlocked = companion == "唐栖"
	s.active_companion = companion
	s.formation = formation
	# Explicitly migrate this legacy battle fixture without resetting any of
	# its seeded encounter transients or granting production fallback selection.
	var migrated = s._detached_persistent_state()
	s._apply_party_plan(s.PartyRoster.load_plan(migrated, {"active_companion": companion}, 11))

func _test_focus() -> void:
	for id: String in ["伏汐藏锋", "续灯引锋", "藏锋立岳"]:
		var s = _fighter(id)
		var definition: Dictionary = Arts.definition(id)
		s.hp = 400
		var immediate: int = 30 + int(definition.damage_bonus)
		var stored: int = 30 + int(definition.focus_bonus)
		var result: Dictionary = s.battle_action("skill")
		check(result.valid and s.enemy_hp == 10000 - immediate and s.focused_damage == stored and s.qi == 16, "F01/F02: correct immediate damage and focus snapshot " + id)
		var incoming: int = 3 if bool(definition.guard) else 9
		check(s.hp == 400 + int(definition.healing) - incoming, "F02: healing/guard occurs before first retaliation " + id)
		s.battle_action("attack")
		check(s.enemy_hp == 10000 - immediate - 30 - stored and s.focused_damage == 0 and s.qi == 18, "F01/F02: next plain attack spends snapshot and restores only two qi " + id)
		check(s.art_uses.get(id, 0) == 1 and s.turn == 2, "F01/F02: focus attack is one action and no extra proficiency")
	var s = _fighter("伏汐藏锋")
	s.battle_action("skill")
	s.battle_action("guard")
	check(s.focused_damage == 48, "F03: guard preserves focus")
	s.hp = 300
	s.battle_action("item")
	check(s.focused_damage == 48, "F03: valid medicine preserves focus")
	s.skill_cooldown = 0
	s.qi = 20
	s.equipped_art = "束潮削势" # Deliberate fixture: skill itself must never consume focus.
	s.battle_action("skill")
	check(s.focused_damage == 48, "F03: another skill does not consume stored focus")
	s.equipped_art = "伏汐藏锋"
	s.skill_cooldown = 0
	s.qi = 20
	s.focused_damage = 70
	s.battle_action("skill")
	check(s.focused_damage == 70, "F03: weaker focus refresh keeps larger old value, without addition")
	s.skill_cooldown = 0
	s.qi = 20
	s.focused_damage = 12
	s.battle_action("skill")
	check(s.focused_damage == 48, "F03: stronger focus refresh replaces smaller old value")
	for invalid_case: String in ["qi", "cooldown", "full_health", "no_medicine", "unknown"]:
		s = _fighter("伏汐藏锋")
		_seed_effects(s)
		s.exposed_turns = 2
		s.guard = true
		s._companion_attack_count = 1
		s._trial_art_used = true
		s._trial_healing = 7
		s._trial_guarded_heavy = true
		var action: String = "skill"
		match invalid_case:
			"qi": s.qi = 0
			"cooldown": s.skill_cooldown = 2
			"full_health": action = "item"
			"no_medicine":
				action = "item"
				s.hp = 300
				s.medicine = 0
			"unknown": action = "not_an_action"
		var before = _snapshot(s)
		check(not s.battle_action(action).valid and _snapshot(s) == before, "F04: complete state unchanged on invalid " + invalid_case)
	s = _fighter("伏汐藏锋")
	s.battle_action("skill")
	s.attack = 42
	var before_hp: int = s.enemy_hp
	s.battle_action("attack")
	check(s.enemy_hp == before_hp - 90 and s.focused_damage == 0, "F05: attack change cannot rewrite original 48-point snapshot")
	for companion: String in ["沈青", "唐栖"]:
		s = _fighter("伏汐藏锋")
		_set_companion(s, companion)
		s.battle_action("skill")
		check(s._companion_attack_count == 1 and s.enemy_hp == 9964, "F06: skill counts as one attack without early assist")
		s.battle_action("attack")
		var extra: int = 7 if companion == "沈青" else 4
		check(s._companion_attack_count == 2 and s.enemy_hp == 9964 - 78 - extra, "F06: enhanced attack counts once, companion damage stays base")
		check(s.qi == (18 if companion == "沈青" else 19), "F06: companion qi behavior unchanged")
		s = _fighter("伏汐藏锋")
		_set_companion(s, companion)
		s._companion_attack_count = 1
		s.focused_damage = 48
		s.enemy_hp = 78
		s.qi = 10
		var result: Dictionary = s.battle_action("attack")
		check(result.won and s._companion_attack_count == 2 and s.qi == 12 and not String(result.message).contains("追加 7") and not String(result.message).contains("追加4"), "F06: direct player kill suppresses companion assist and qi")
		_clear_effects(s, "F06: killing enhanced attack consumes focus")

func _test_proficiency() -> void:
	for expected: Dictionary in ADVANCED:
		var id: String = expected.id
		for uses: int in [4, 14]:
			var s = _fighter(id)
			s.art_uses[id] = uses
			s.hp = 300
			var old_rank: int = 1 if uses == 4 else 2
			var direct: int = 30 + int(expected.damage_bonus) + 3 * (old_rank - 1)
			s.battle_action("skill")
			check(s.enemy_hp == 10000 - direct and s.art_uses[id] == uses + 1 and s.art_rank(id) == old_rank + 1, "F07: threshold cast uses old rank " + id + "/" + str(uses))
			var focus: int = 30 * int(expected.focus_attack_multiplier) + int(expected.focus_bonus)
			check(s.focused_damage == focus and s.enemy_weaken_amount == int(expected.weaken_amount), "F07: proficiency does not amplify either new effect")
			var incoming: int = maxi(1, 17 - 8 - int(expected.weaken_amount))
			if bool(expected.guard):
				incoming = maxi(1, int(ceil(float(incoming) * 0.3)))
			check(s.hp == 300 + int(expected.healing) - incoming, "F07: proficiency never amplifies healing/guard")
			s.battle_action("attack")
			check(s.art_uses[id] == uses + 1, "F07: plain/enhanced attack does not train skill")
			s.skill_cooldown = 0
			s.qi = 20
			var before_hp: int = s.enemy_hp
			s.battle_action("skill")
			check(s.enemy_hp == before_hp - direct - 3 and s.focused_damage == focus, "F07: next cast gets exactly three more direct damage")
		var capped = _fighter(id)
		capped.art_uses[id] = 9999
		capped.battle_action("skill")
		check(capped.art_uses[id] == 9999 and capped.art_rank(id) == 3, "F07: advanced proficiency saturates safely " + id)
	for id: String in ["青灯息争", "续灯引锋"]:
		var s = _fighter(id)
		var amount: int = int(Arts.definition(id).weaken_amount)
		var result: Dictionary = s.battle_action("skill")
		check(result.valid and String(result.message).contains("恢复 0") and s.hp == 500 - maxi(1, 17 - 8 - amount), "F02: full-health healing skill still applies other effects " + id)
		s = _fighter(id)
		s.hp = 497
		result = s.battle_action("skill")
		check(String(result.message).contains("恢复 3") and s.hp == 500 - maxi(1, 17 - 8 - amount), "F02: healing logs actual capped recovery before retaliation " + id)

func _test_turn_order_and_cooldown() -> void:
	for expected: Dictionary in ADVANCED:
		var id: String = expected.id
		for initial_turn: int in [0, 1]:
			var s = _fighter(id)
			s.turn = initial_turn
			s.exposed_turns = 2
			s.hp = 300
			s._update_intent()
			var raw: int = 17 if initial_turn == 0 else 31
			check(s.enemy_intent.contains(str(raw)), "E01: displayed intent remains raw enemy attack " + id)
			var result: Dictionary = s.battle_action("skill")
			var incoming: int = maxi(1, raw - 8 - int(expected.weaken_amount))
			if bool(expected.guard):
				incoming = maxi(1, int(ceil(float(incoming) * 0.3)))
			else:
				incoming += 3
			check(s.hp == 300 + int(expected.healing) - incoming and s.turn == initial_turn + 1, "E01: exact light/heavy retaliation without reordered turns " + id)
			check(String(result.message).contains("你受到 %d 点伤害" % incoming), "E01: displayed damage matches calculation " + id)
			check(s.exposed_turns == (0 if bool(expected.guard) else (1 if initial_turn == 0 else 2)), "E01: only guard clears/prevents boss exposure " + id)
			check(s.enemy_intent.contains(str(31 if initial_turn == 0 else 17)), "E01: next raw intent still alternates " + id)
		var s = _fighter(id)
		s.battle_action("skill")
		var cooldown: int = int(expected.cooldown)
		check(s.skill_cooldown == cooldown, "E02: initial shared cooldown " + id)
		for step: int in range(cooldown):
			var before = _snapshot(s)
			check(not s.battle_action("skill").valid and _snapshot(s) == before, "E02: early skill cannot shorten cooldown " + id)
			s.battle_action("guard")
			check(s.skill_cooldown == cooldown - step - 1, "E02: one valid non-skill turn removes exactly one cooldown")
		check(s.battle_action("skill").valid and s.skill_cooldown == cooldown, "E02: skill available only after exact cooldown turns " + id)

func _test_cleanup() -> void:
	var s = _fighter("伏汐藏锋")
	_seed_effects(s)
	s.enemy_hp = 1
	var name_before: String = s.enemy_name
	var result: Dictionary = s.battle_action("attack")
	check(result.won and s.enemy_name == name_before and not s.battle_log.is_empty(), "E03: victory preserves name/log for result UI")
	_clear_effects(s, "E03: victory clears advanced effects")
	var before = _snapshot(s)
	check(not s.battle_action("attack").valid and _snapshot(s) == before, "M06/E03: repeated victory callback cannot grant more rewards")
	s = _fighter("伏汐藏锋")
	_seed_effects(s)
	s.hp = 1
	s.qi = 0
	s.coins = 23
	s.skill_cooldown = 3
	name_before = s.enemy_name
	result = s.battle_action("attack")
	check(result.finished and not result.won and not s.battle_active and s.hp == s.max_hp and s.coins == 15 and s.qi >= 2 and s.skill_cooldown == 0 and s.exposed_turns == 0, "E03: defeat retains original heal/qi/cooldown/eight-coin penalty")
	check(s.enemy_name == name_before and not s.battle_log.is_empty(), "E03: defeat retains enemy/log for result UI")
	_clear_effects(s, "E03: defeat clears advanced effects")
	s = _fighter()
	_seed_effects(s)
	s.skill_cooldown = 3
	var enemy_hp_before: int = s.enemy_hp
	var hp_before: int = s.hp
	var coins_before: int = s.coins
	var count_before: int = s._companion_attack_count
	result = s.battle_action("flee")
	check(result.finished and not result.won and not s.battle_active and s.turn == 1 and s.hp == hp_before and s.enemy_hp == enemy_hp_before and s.coins == coins_before and s._companion_attack_count == count_before, "E03: flee has no retaliation, assist, or coin penalty")
	_clear_effects(s, "E03: fleeing clears advanced effects")
	_seed_effects(s) # Stale-state fixture must not leak into the next enemy.
	s.start_battle("story")
	_clear_effects(s, "E03: newly started fight clears stale advanced effects")
	check(s.enemy_base_attack == 9 and s.enemy_strong_attack == 19 and s.turn == 0, "E03: new encounter also resets original combat state")
	_seed_effects(s)
	s.claimed_deeds.assign(["sluice", "archive"])
	s.reset_game()
	_clear_effects(s, "E03: reset clears all advanced effects")
	check(s.learned_arts.is_empty() and s.claimed_deeds.is_empty() and s.sect_merit == 0 and s.available_arts() == [Arts.BASE_ART], "E03: new game clears learning and reward receipts")
	var saved = _inner()
	check(saved.save_game(TEST_SAVE) == OK, "E03: load-cleanup fixture saves")
	s = _fighter()
	_seed_effects(s)
	check(s.load_game(TEST_SAVE) == OK and not s.battle_active and s.enemy_name.is_empty() and s.battle_log.is_empty(), "E03: successful load clears entire transient battle")
	_clear_effects(s, "E03: successful load clears all advanced effects")

func _test_legacy_saves() -> void:
	for version: int in [1, 2, 3, 4]:
		var source = _inner()
		_events(source, "pursuit", "protect_witness")
		source.sect_merit = 17
		source.equipped_art = "回潮断浪"
		source.art_uses = {"照夜一线": 5, "回潮断浪": 15, "青灯续脉": 7, "磐石回锋": 9}
		var data: Dictionary = source.to_dict()
		data.erase("learned_arts")
		data.erase("claimed_deeds")
		_write(TEST_SAVE, data, version)
		var loaded = State.new()
		check(loaded.load_game(TEST_SAVE) == OK, "S01: real missing-array legacy version loads " + str(version))
		check(loaded.learned_arts.is_empty() and loaded.claimed_deeds.is_empty() and loaded.sect_merit == 17 and loaded.max_qi == source.max_qi and loaded.defense == source.defense and loaded.art_uses == source.art_uses and loaded.equipped_art == "回潮断浪", "S01: migration preserves balance/stats/original proficiency, grants nothing")
		check(loaded.eligible_sect_deeds() == ["sluice", "archive"], "S02: completed legacy events remain newly claimable")
		check(loaded.claim_sect_deed("sluice") and loaded.claim_sect_deed("archive") and loaded.sect_merit == 19, "S02: each migrated deed claimed exactly once")
		check(loaded.save_game(TEST_SAVE) == OK, "S02: migrated receipt saves at new schema")
		var again = State.new()
		check(again.load_game(TEST_SAVE) == OK and again.to_dict() == loaded.to_dict(), "S02: migrated receipts/progression round-trip")
		var before = _snapshot(again)
		check(not again.claim_sect_deed("sluice") and not again.claim_sect_deed("archive") and not again.complete_sect_trial() and _snapshot(again) == before, "S02: reloading cannot repeat deeds or promotion")
		var pending = State.new()
		pending.choose_sect("听潮阁")
		pending.gain_xp(180)
		pending.sect_trial_won = true
		_events(pending)
		data = pending.to_dict()
		data.erase("learned_arts")
		data.erase("claimed_deeds")
		_write(TEST_SAVE, data, version)
		check(again.load_game(TEST_SAVE) == OK and again.sect_rank == 1 and again.sect_trial_won and again.sect_merit == 0, "S03: legacy unclaimed trial proof survives " + str(version))
		check(not again.learn_art("束潮削势") and not again.claim_sect_deed("sluice"), "S03: pending promotion cannot bypass rank gate")
		check(again.complete_sect_trial() and again.sect_merit == 3 and again.learn_art("束潮削势") and again.claim_sect_deed("sluice"), "S03: old pending promotion resumes normal purchase/deed flow")

func _test_current_saves() -> void:
	check(State.SAVE_VERSION >= 5, "S04: current schema retains version-five martial fields")
	for school: String in SCHOOLS:
		var s = _inner(school)
		_events(s)
		s.claim_sect_deed("archive")
		s.claim_sect_deed("sluice")
		s.learn_art(SCHOOL_ARTS[school][2])
		s.learn_art(SCHOOL_ARTS[school][1])
		s.equip_art(SCHOOL_ARTS[school][2])
		s.art_uses = {Arts.BASE_ART: 4}
		s.art_uses[SCHOOL_ARTS[school][0]] = 15
		s.art_uses[SCHOOL_ARTS[school][1]] = 5
		s.art_uses[SCHOOL_ARTS[school][2]] = 14
		var expected: Dictionary = s.to_dict()
		var detached: Dictionary = s.to_dict()
		detached.learned_arts.clear()
		detached.claimed_deeds.clear()
		check(s.learned_arts.size() == 2 and s.claimed_deeds.size() == 2, "S04: serialized arrays are detached copies")
		s.start_battle()
		_seed_effects(s)
		check(s.save_game(TEST_SAVE) == OK, "S04: complete v5 transaction saves " + school)
		var file = FileAccess.open(TEST_SAVE, FileAccess.READ)
		var document: Dictionary = JSON.parse_string(file.get_as_text())
		file.close()
		check(document.version == State.SAVE_VERSION and document.player.has("learned_arts") and document.player.has("claimed_deeds"), "S04: exact canonical v5 keys persisted")
		for transient: String in ["enemy_weaken_amount", "enemy_weaken_strikes", "focused_damage", "battle_active", "turn", "skill_cooldown"]:
			check(not document.player.has(transient), "S04: transient field omitted " + transient)
		check(not document.player.has("claimed_merit_awards"), "S04: obsolete plan receipt key is not serialized")
		var loaded = State.new()
		check(loaded.load_game(TEST_SAVE) == OK and loaded.to_dict() == expected, "S04: v5 exact durable round-trip " + school)
		_clear_effects(loaded, "S04: reload never restores in-flight weaken/focus")
		var duplicates = expected.duplicate(true)
		duplicates.learned_arts = [SCHOOL_ARTS[school][2], SCHOOL_ARTS[school][1], SCHOOL_ARTS[school][2], SCHOOL_ARTS[school][1]]
		duplicates.claimed_deeds = ["archive", "sluice", "archive", "sluice"]
		_write(TEST_SAVE, duplicates)
		check(loaded.load_game(TEST_SAVE) == OK and loaded.learned_arts == [SCHOOL_ARTS[school][1], SCHOOL_ARTS[school][2]] and loaded.claimed_deeds == ["sluice", "archive"] and loaded.sect_merit == 0, "S05: legal duplicates normalize into canonical catalog/receipt order")
		check(loaded.save_game(TEST_SAVE) == OK, "S05: normalized duplicate state resaves")
		var twice = State.new()
		check(twice.load_game(TEST_SAVE) == OK and twice.to_dict() == loaded.to_dict(), "S05: normalization remains stable after another round-trip")
		var forged = _inner(school).to_dict()
		forged.equipped_art = SCHOOL_ARTS[school][2]
		forged.art_uses = {Arts.BASE_ART: 4, SCHOOL_ARTS[school][1]: 9999, SCHOOL_ARTS[school][2]: 15}
		_write(TEST_SAVE, forged)
		check(loaded.load_game(TEST_SAVE) == OK and loaded.equipped_art == Arts.BASE_ART and loaded.learned_arts.is_empty() and loaded.art_uses.get(SCHOOL_ARTS[school][1], 0) == 0 and loaded.art_uses.get(SCHOOL_ARTS[school][2], 0) == 0 and loaded.available_arts().size() == 2, "S06: equipped ID and proficiency cannot unlock unlearned advanced arts")
		forged.learned_arts = [SCHOOL_ARTS[school][1]]
		_write(TEST_SAVE, forged)
		check(loaded.load_game(TEST_SAVE) == OK and loaded.art_uses.get(SCHOOL_ARTS[school][1], 0) == 9999 and loaded.art_uses.get(SCHOOL_ARTS[school][2], 0) == 0 and loaded.equipped_art == Arts.BASE_ART, "S06: only legitimately learned advanced proficiency is restored")
	var source = _inner()
	var repaired: Dictionary = source.to_dict()
	repaired.claimed_deeds = ["archive", "sluice"]
	repaired.sect_merit = 71
	repaired.side_choice = "rescue"
	repaired.side_stage = 2
	repaired.side_found = ["ledger"]
	repaired.side_clues = 999
	repaired.chapter_two_stage = 0
	repaired.chapter_two_ending = "open_records"
	_write(TEST_SAVE, repaired)
	var loaded = State.new()
	for reload_index: int in range(3):
		check(loaded.load_game(TEST_SAVE) == OK and loaded.claimed_deeds == ["sluice", "archive"] and loaded.sect_merit == 71 and loaded.side_stage == 1 and loaded.chapter_two_ending.is_empty(), "S07: progress repair retains receipts and exact balance " + str(reload_index))
		check(loaded.save_game(TEST_SAVE) == OK, "S07: repaired receipt snapshot resaves")
	_events(loaded)
	var before = _snapshot(loaded)
	check(not loaded.claim_sect_deed("sluice") and not loaded.claim_sect_deed("archive") and _snapshot(loaded) == before, "S07: completing repaired events cannot reissue retained receipts")

func _test_bad_saves_and_atomicity() -> void:
	var live = _fighter("伏汐藏锋")
	_seed_effects(live)
	live.exposed_turns = 2
	live.skill_cooldown = 3
	live._companion_attack_count = 1
	live._trial_art_used = true
	live._trial_healing = 11
	live._trial_guarded_heavy = true
	var valid: Dictionary = _inner().to_dict()
	for key: String in ["learned_arts", "claimed_deeds"]:
		var missing = valid.duplicate(true)
		missing.erase(key)
		_reject_load(live, missing, "S05: v5 rejects missing mandatory " + key)
		for bad: Variant in [null, "not-an-array", {}, 4, true, [4], [null], [false], [{}]]:
			for version: int in [1, 2, 3, 4, 5]:
				var malformed = valid.duplicate(true)
				malformed[key] = bad
				_reject_load(live, malformed, "S05: malformed %s remains invalid in schema %d: %s" % [key, version, str(bad)], version)
	for invalid_ids: Array in [["unknown"], [Arts.BASE_ART], ["回潮断浪"], ["青灯息争"], ["束潮削势", "unknown"], ["束潮削势", "青灯息争"]]:
		var malformed = valid.duplicate(true)
		malformed.learned_arts = invalid_ids
		for version: int in [1, 2, 3, 4, 5]:
			_reject_load(live, malformed, "S05: invalid/cross-school learned art is atomic " + str(invalid_ids), version)
	for rank: int in [0, 1]:
		var malformed = valid.duplicate(true)
		malformed.sect_rank = rank
		malformed.learned_arts = ["束潮削势"]
		_reject_load(live, malformed, "S05: learned advanced art conflicts with low saved rank")
	var unjoined = valid.duplicate(true)
	unjoined.sect = "未入门"
	unjoined.sect_rank = 2
	unjoined.learned_arts = ["束潮削势"]
	_reject_load(live, unjoined, "S05: unjoined hero cannot load advanced ownership")
	for ids: Array in [["unknown"], ["sluice_service"], ["frostbridge_service"], ["sluice", "unknown"]]:
		var malformed = valid.duplicate(true)
		malformed.claimed_deeds = ids
		for version: int in [1, 2, 3, 4, 5]:
			_reject_load(live, malformed, "S05: unknown/obsolete receipt ID rejected " + str(ids), version)
	for version: Variant in [0, -1, 1.5, 4.5, 5.5, State.SAVE_VERSION+1, 99]:
		_reject_load(live, valid, "S08: unknown/fractional schema rejected atomically " + str(version), version, ERR_FILE_UNRECOGNIZED)
	for version: Variant in [null, "5", true, []]:
		_reject_load(live, valid, "S08: nonnumeric schema rejected atomically", version)
	for content: String in ["{truncated", "[]", "null", '{"version":5}', '{"version":5,"player":[]}']:
		_write_text(BAD_SAVE, content)
		var before = _snapshot(live)
		check(live.load_game(BAD_SAVE) == ERR_FILE_CORRUPT and _snapshot(live) == before, "S08: malformed/truncated JSON preserves entire live battle")
	_write_text(BAD_SAVE, " ".repeat(1048577))
	var before = _snapshot(live)
	check(live.load_game(BAD_SAVE) == ERR_FILE_CORRUPT and _snapshot(live) == before, "S08: oversized save preserves entire live battle")
	check(live.load_game("user://advanced-martial-nonexistent.json") == ERR_FILE_NOT_FOUND and _snapshot(live) == before, "S08: missing file preserves entire live battle")
	# Block the temporary file with a directory. The existing valid document must
	# remain byte-for-byte intact; in-memory learning/receipts stay fully committed.
	var s = _inner()
	_events(s)
	check(s.save_game(TEST_SAVE) == OK, "S08: pretransaction disk snapshot saved")
	var original_file = FileAccess.open(TEST_SAVE, FileAccess.READ)
	var original_text: String = original_file.get_as_text()
	original_file.close()
	check(s.learn_art("束潮削势") and s.claim_sect_deed("sluice") and s.claim_sect_deed("archive"), "S08: complete in-memory purchase and reward transactions")
	var committed = _snapshot(s)
	var temporary_path: String = ProjectSettings.globalize_path(TEST_SAVE + ".tmp")
	check(DirAccess.make_dir_absolute(temporary_path) == OK, "S08: temporary-file failure fixture created")
	check(s.save_game(TEST_SAVE) != OK and _snapshot(s) == committed, "S08: save failure never rolls back or half-applies in-memory transactions")
	var unchanged_file = FileAccess.open(TEST_SAVE, FileAccess.READ)
	var unchanged_text: String = unchanged_file.get_as_text()
	unchanged_file.close()
	check(unchanged_text == original_text, "S08: failed atomic write preserves complete previous save")
	var previous = State.new()
	check(previous.load_game(TEST_SAVE) == OK and previous.learned_arts.is_empty() and previous.claimed_deeds.is_empty() and previous.sect_merit == 3, "S08: disk remains coherent pretransaction state")
	check(DirAccess.remove_absolute(temporary_path) == OK, "S08: save blocker removed")
	check(s.save_game(TEST_SAVE) == OK and _snapshot(s) == committed, "S08: retry saves without replaying purchase/claim")
	var loaded = State.new()
	check(loaded.load_game(TEST_SAVE) == OK and loaded.to_dict() == s.to_dict() and loaded.sect_merit == 3 and loaded.learned_arts == ["束潮削势"] and loaded.claimed_deeds == ["sluice", "archive"], "S08: retry persists complete new transaction state")
	before = _snapshot(loaded)
	check(not loaded.learn_art("束潮削势") and not loaded.claim_sect_deed("sluice") and not loaded.claim_sect_deed("archive") and _snapshot(loaded) == before, "S08: successful retry cannot duplicate transactions")
	check(s.save_game("") == ERR_INVALID_PARAMETER and _snapshot(s) == committed, "S08: invalid save destination does not mutate transaction state")

func _cleanup_files() -> void:
	for path: String in [TEST_SAVE, BAD_SAVE, TEST_SAVE + ".tmp", BAD_SAVE + ".tmp", FAIL_DIRECTORY]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
			DirAccess.remove_absolute(absolute)
