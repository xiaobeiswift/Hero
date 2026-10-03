extends "res://tests/capstone_independent_earned_test.gd"
## Earned prerequisites and equal-input finite controls. Never a UI proof by itself.
const HistoricalProducer = preload("res://tests/weapon_fitting_fixture_producer.gd")
var api_fights: Array = []
var control_pairs: Array = []
var migrations: Array = []
var current16_roundtrips: Array = []

func _fight(s, encounter: String, policy: bool, label: String) -> Dictionary:
	travel(s, String(Encounters.LOCATIONS[encounter][0]))
	var before: Dictionary = s.to_dict().duplicate(true)
	check(s.start_party_battle(encounter), "Earned production adapter accepts " + encounter)
	if not s.battle_active: return {}
	var start: Dictionary = s.party_battle_snapshot()
	var trace_rows: Array = []
	var terminal: Dictionary = {}
	var cooldowns: Dictionary = {}
	while s.battle_active and trace_rows.size() < 900:
		var item: String = _plan(s.party_session) if policy else ""
		var tx: Dictionary
		if item.is_empty(): tx = s.advance_party_battle()
		else:
			s.select_party_actor(item)
			tx = s.party_battle_action("item")
		check(tx.get("accepted", false), "Earned model transaction progresses")
		if not tx.get("accepted", false): break
		_check_transaction(tx, cooldowns)
		trace_rows.append({"round":tx.before.round,"source":tx.source_id,"action":tx.action_id,"events":tx.events,
			"actors":tx.after.actors,"enemies":tx.after.enemies,"medicine":tx.after.medicine,"outcome":tx.after.outcome})
		check(s.finish_party_presentation(tx.epoch,tx.token).accepted, "Earned exact presentation acknowledgement")
		terminal = tx
	check(not s.battle_active and not terminal.is_empty(), "Earned bounded model fight terminates")
	if terminal.is_empty(): return {}
	var row: Dictionary = {"label":label,"encounter":encounter,"start":start,"entry":before,"final":s.to_dict(),
		"outcome":terminal.after.outcome,"settlement":s.party_settlement,"trace":trace_rows,
		"events_sha256":JSON.stringify(trace_rows,"",true).sha256_text(),"policy":"deterministic production API queued",
		"xp_delta":total_xp(s)-_dict_total_xp(before),"coins_delta":s.coins-int(before.coins)}
	api_fights.append(row)
	journey.append({"label":label,"outcome":row.outcome,"encounter":encounter,"xp_delta":row.xp_delta,"coins_delta":row.coins_delta})
	return row

func _dict_total_xp(d: Dictionary) -> int:
	return int(d.xp)+30*int(d.level)*(int(d.level)-1)

func _earned_early(school: String):
	var s = _opening(false)
	if not _journey_win(s,"story",case_id+"/opening"): return null
	_finish_opening(s)
	_school(s,school)
	check(s.quest_stage==6 and s.sect==school and s.level==3, "Actual opening and school earn early fitting eligibility")
	check(s.party_roster==["hero"] and not s.companion_unlocked and not s.tangqi_unlocked and not s.qin_unlocked,"Early solo never recruited anyone")
	check(s.equipment=="旧铁剑" and s.armor=="粗布行衣" and not s.internal_unlocked and not s.lightness_unlocked,"Early starter gear and no optional lessons")
	check(s.capstone_stage==0 and s.chapter_two_stage==0 and s.mist_stage==0 and s.heting_stage==0,"Early fitting has no later chapter prerequisite")
	return s

func _earned_later():
	var s = earn_harbor("听潮阁",false)
	if s==null: return null
	check(s.recruit_companion(),"Genuine Shen invitation")
	travel(s,"frostbridge")
	check(s.gather_resource("frost_timber").valid and s.repair_bridge(),"Actual finite timber and bridge")
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(),"Genuine Tang quest and invitation")
	travel(s,"mistwood")
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Genuine Qin rope, handoff and invitation")
	check(s.set_party_roster(["hero","shen","tang","qin"]),"Deploy only four genuinely recruited actors")
	travel(s,"heting")
	check(s.begin_consignee(),"Actual finite consignee acceptance")
	for observation: String in s.Consignee.OBSERVATIONS:
		check(s.observe_consignee(observation),"Actual consignee evidence "+observation)
	check(s.resolve_consignee_contradiction(s.Consignee.CORRECT_ANSWER).correct and s.choose_consignee_plan("return_to_owner"),"Actual consignee proof and reversible draft")
	rest(s,"explicit_before_fitting_and_later_finite_encounter")
	check(s.capstone_stage==0 and s.receipt_stage==0 and s.consignee_stage==2,"No capstone, optional receipt or counterfeit consignee victory")
	return s

func _plain_control(s, encounter: String, label: String) -> Dictionary:
	var clone = s._detached_persistent_state()
	var input: Dictionary = clone.to_dict().duplicate(true)
	var row: Dictionary = _fight(clone,encounter,true,label)
	return {"canonical_input":input,"fight":row}

func _compare_controls(before: Dictionary, after: Dictionary) -> void:
	check(before.canonical_input==after.canonical_input,"Plain controls begin from exactly equal complete canonical State")
	var a: Dictionary=before.fight
	var b: Dictionary=after.fight
	check(a.entry==b.entry and a.start==b.start,"Plain controls share exact model travel projection and combat entry")
	check(a.trace==b.trace and a.events_sha256==b.events_sha256,"Plain accepted actions, events and combat states exactly match")
	check(a.final==b.final and a.settlement==b.settlement and a.xp_delta==b.xp_delta and a.coins_delta==b.coins_delta,"Plain finite outcome, resources, progression and rewards exactly match")
	control_pairs.append({"case":case_id,"before":before,"after":after,"equal":a.trace==b.trace and a.final==b.final})

func _historical_unlocked_migration() -> void:
	var script = HistoricalProducer.old_reader()
	check(script!=null,"Retained old15 producer byte identity verified")
	if script==null:return
	var old = script.new()
	check(old.SAVE_VERSION==15,"Historical source genuinely writes15")
	# Exact old scene-local opening effects, not relabelled current State.
	old.quest_stage=1;old.herbs+=1;old.quest_stage=2;old.gain_xp(10)
	old.herbs-=1;old.medicine+=2;old.quest_stage=3;old.gain_xp(20)
	if not _journey_win(old,"story","historical15/opening"):return
	_finish_opening(old)
	old.choose_sect("听潮阁");old.quest_stage=6
	var before: Dictionary=old.to_dict().duplicate(true)
	var path: String=isolated_root+"/actual-old15-unlocked.json"
	check(old.save_game(path)==OK,"Actual historical15 serializer writes earned unlocked State")
	var old_bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var document: Dictionary=JSON.parse_string(old_bytes.get_string_from_utf8())
	check(int(document.version)==15 and not document.player.has("weapon_fitting"),"Genuine15 file has no fitting field")
	var loaded=State.new()
	check(loaded.load_game(path)==OK and loaded.weapon_fitting=="plain","Actual unlocked15 defaults plain on current read")
	var canonical: Dictionary=loaded.to_dict().duplicate(true)
	canonical.erase("weapon_fitting")
	check(canonical==before and loaded.preview_weapon_fitting("edge").ok,"Historical migration preserves earned progress and permits early preview")
	var output_path: String=isolated_root+"/migrated-current16.json"
	check(loaded.save_game(output_path)==OK,"Deliberate migrated save uses current writer")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(output_path)).version)==16,"Migration rewrite is explicitly16")
	check(FileAccess.get_file_as_bytes(path)==old_bytes,"Migration never overwrites retained original15 bytes")
	migrations.append({"case":"actual-old15-source-unlocked","old_path":path,"old_sha256":FileAccess.get_sha256(path),"old":before,"current":loaded.to_dict(),"source_sha256":HistoricalProducer.OLD_SHA,
		"scope":"Exact old15 source producer and actual15 serializer with current dependencies; not a complete historical PCK process"})
