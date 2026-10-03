extends "res://tests/heting_consignee_balance_test.gd"
const Finale = preload("res://scripts/volume_one_capstone_rules.gd")
const FIXED_PARTITION = {"capstone_pending_001":"proven_false","capstone_pending_002":"proven_false","capstone_pending_003":"unverified","capstone_pending_004":"unverified"}
const ROSTERS = [["hero"],["hero","shen"],["hero","tang"],["hero","qin"],["hero","shen","tang"],["hero","shen","qin"],["hero","tang","qin"],["hero","shen","tang","qin"]]
var failure_labels: Array = []
var cases: Array = []
var operations: Array = []
var states: Array = []
var isolated_root: String = "user://capstone-independent-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var output: String = ""
var mode: String = "minimal"
var case_id: String = ""
var save_sequence: int = 0
func prepare_run_output() -> bool:
	if DirAccess.make_dir_recursive_absolute(isolated_root) != OK:
		push_error("Cannot create isolated capstone independent evidence directory")
		return false
	output = isolated_root + "/result.json"
	return true

func check(value: bool, label: String) -> void:
	super.check(value,label)
	if not value: failure_labels.append(case_id+":"+label)
func total_xp(s) -> int: return s.xp + 30*s.level*(s.level-1)
func resources(s) -> Dictionary:
	return {"hp":s.hp,"qi":s.qi,"party":s.party_resources.duplicate(true),"medicine":s.medicine,"coins":s.coins,"xp":total_xp(s)}
func travel(s, region: String) -> void:
	var before: Dictionary = resources(s)
	s.map_id = region # Model-only travel projection; not walking or scene evidence.
	check(resources(s)==before,"Model travel cannot heal or reward")
func rest(s, label: String) -> void:
	var before: Dictionary = resources(s)
	s.heal_rest()
	check(s.hp==s.max_hp and s.qi==s.max_qi,"Explicit rest recovers hero "+label)
	check(s.medicine==before.medicine and s.coins==before.coins and total_xp(s)==before.xp,"Explicit rest grants no stock/coins/XP "+label)
	operations.append({"case":case_id,"operation":"explicit_free_rest","label":label,"before":before,"after":resources(s)})
func roundtrip(s, label: String):
	save_sequence+=1
	var path: String=(isolated_root + "/checkpoint-%03d.json")%save_sequence
	var before: Dictionary=s.to_dict().duplicate(true)
	for i: int in 3:
		Finale.goal(s);Finale.order_rows(s);Finale.journal(s)
	check(s.to_dict()==before,"Read-only projections never heal/reward/classify "+label)
	check(s.save_game((isolated_root + "/absent-dir/failed.json"))!=OK and s.to_dict()==before,"Failed checkpoint preserves current state "+label)
	check(s.save_game(path)==OK,"Save "+label)
	var loaded=State.new()
	check(loaded.load_game(path)==OK and loaded.to_dict()==before,"Load exact resources/stage "+label)
	return loaded
func preserved_story(s) -> Dictionary:
	var result: Dictionary={}
	for key: String in s.to_dict():
		if key.begins_with("mist_") or key.begins_with("heting_") or key.begins_with("consignee_") or key.begins_with("side_") or key.begins_with("chapter_two") or key in ["ending","archive_clues","seal_sequence","bridge_repaired","receipt_stage"]:
			result[key]=s.to_dict()[key]
	return result
func earn_harbor(school: String, protected: bool):
	var s=_opening(false)
	if not _journey_win(s,"story",case_id+"/opening"):return null
	_finish_opening(s);_school(s,school)
	check(s.choose_side_route("rescue") and s.find_side_clue("boatman"),"Earn original rescue")
	rest(s,"before_scout")
	if not _journey_win(s,"sluice_scout",case_id+"/scout"):return null
	rest(s,"before_sluice")
	if not _journey_win(s,"sluice_boss",case_id+"/sluice"):return null
	check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"),"Earn archive observations")
	for seal: int in [2,0,1]:check(s.try_seal(seal).valid,"Earn existing archive seal")
	rest(s,"before_archive")
	if not _journey_win(s,"archive_boss",case_id+"/archive"):return null
	check(s.resolve_chapter_two("protect_witness" if protected else "open_records"),"Choose actual archive outcome")
	check(s.begin_mistwood(),"Begin mandatory Mistwood")
	travel(s,"mistwood")
	check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin"),"Earn two gauges")
	if protected:
		rest(s,"protected_before_duel")
		if not _journey_win(s,"mist_scout",case_id+"/protected_access_duel"):return null
	else:check(s.obtain_mist_access("records"),"Use existing public record permission")
	check(s.record_mist_gauge("stone"),"Earn third gauge")
	rest(s,"before_keeper")
	if not _journey_win(s,"mist_keeper",case_id+"/keeper"):return null
	check(s.resolve_mistwood("warn_ferries" if protected else "release_water") and s.begin_heting(),"Earn chosen Mist ending and harbor entry")
	travel(s,"heting")
	check(s.take_heting_cargo("meal") and s.deliver_heting_base("heting_relief"),"Actual first finite cargo")
	check(s.take_heting_cargo("sealed") and s.deliver_heting_base("heting_scale"),"Actual second finite cargo")
	var harbor: String="open_scale" if protected else "short_ferries"
	check(s.choose_heting_plan(harbor) and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_scale" if protected else "heting_relief",harbor),"Actual old harbor final delivery")
	check(s.party_roster==["hero"] and not s.companion_unlocked and not s.tangqi_unlocked and not s.qin_unlocked and not s.internal_unlocked and not s.lightness_unlocked and not s.bridge_repaired and s.receipt_stage==0,"Pure minimum retains no optional recruit/receipt/gear/lesson/bridge")
	return s
func earn_consignee(source, plan: String):
	var s=source._detached_persistent_state()
	rest(s,"before_consignee")
	check(s.begin_consignee(),"Actual consignee acceptance")
	for observation: String in s.Consignee.OBSERVATIONS:check(s.observe_consignee(observation),"Actual solo consignee observation")
	check(s.resolve_consignee_contradiction(s.Consignee.CORRECT_ANSWER).correct and s.choose_consignee_plan(plan),"Actual consignee proof and draft")
	if not _journey_win(s,"heting_consignee",case_id+"/consignee"):return null
	check(not s.begin_capstone(),"Victory without actual consignee handover is insufficient")
	check(s.take_consignee_cargo(s.Consignee.BATCH,s.Consignee.SOURCE),"Actual finite lot pickup")
	check(not s.begin_capstone(),"Carrying consignee lot is insufficient")
	check(s.finish_consignee_delivery(s.Consignee.receiver_for(plan),plan),"Actual old handover earns finale eligibility")
	states.append({"label":case_id+"/earned_entry","state":s.to_dict()})
	return s
func earn_ready(source):
	var s=source._detached_persistent_state()
	travel(s,"heting")
	var before: Dictionary=s.to_dict().duplicate(true)
	check(s.begin_capstone() and s.capstone_stage==1,"Explicit referral")
	before.capstone_stage=1
	check(s.to_dict()==before,"Referral changes only stage")
	s=roundtrip(s,"stage1")
	check(not s.reveal_capstone_letter(),"Letter wrong map rejected")
	travel(s,"frostbridge")
	before=s.to_dict().duplicate(true)
	check(s.reveal_capstone_letter() and s.capstone_stage==2,"Explicit old-letter author/purpose/return")
	before.capstone_stage=2;check(s.to_dict()==before,"Letter changes only stage")
	s=roundtrip(s,"stage2")
	check(not s.start_party_battle("capstone_authorizer"),"Unproved letter is not boss admission")
	var nochange: Dictionary=s.to_dict().duplicate(true)
	for method: String in ["tang_teach","tang_preserve","qin_timing"]:
		if not Finale.available_methods(s,"evidence").has(method):check(not s.resolve_capstone_evidence("authorized_issued_chain",method).correct and s.to_dict()==nochange,"No false live evidence-helper availability "+method)
	check(not s.resolve_capstone_evidence("victory_proves_guilt").correct and s.to_dict()==nochange,"Wrong prewar answer has no costs or mutation")
	check(Finale.goal(s).site_id=="chapter_clerk","Issued-chain evidence goal is clerk, not postwar archive")
	check(s.resolve_capstone_evidence("authorized_issued_chain").correct and s.capstone_stage==3,"Explicit issued-chain proof before fight")
	nochange.capstone_stage=3;check(s.to_dict()==nochange,"Proof does not secretly heal/reward/change grain")
	return roundtrip(s,"stage3")
func finish_capstone(source, plan: String, classify_map: String="frostbridge"):
	var s=source._detached_persistent_state()
	var history: Dictionary=preserved_story(s)
	rest(s,"before_capstone")
	var before: Dictionary=s.to_dict().duplicate(true)
	var xp_before: int=total_xp(s)
	var row: Dictionary=_fight(s,"capstone_authorizer",true,case_id+"/"+plan)
	if row.get("outcome")!="win":
		check(false,"Earned queued finale win "+case_id)
		cases.append({"case":case_id,"plan":plan,"entry":before,"result":row,"failed":true})
		return null
	check(s.capstone_stage==4 and s.capstone_draft=="" and s.capstone_ending=="","Win only acquires book; no classification/draft/disposition")
	check(total_xp(s)==xp_before and s.coins==before.coins,"Victory has zero XP/coin reward")
	check(preserved_story(s)==history,"Victory preserves old choices/cargo/receipt")
	check(not s.start_party_battle("capstone_authorizer"),"Boss cannot replay after book acquired")
	check(Finale.order_rows(s).size()==4,"Exactly four new pending rows")
	for order: Dictionary in Finale.order_rows(s):check(order.evidence=="not_yet_classified" and order.disposition=="pending","Win cannot classify/hold by itself")
	s=roundtrip(s,"stage4")
	travel(s,classify_map)
	var unchanged: Dictionary=s.to_dict().duplicate(true)
	check(not s.choose_capstone_plan(plan) and s.to_dict()==unchanged,"Draft cannot skip classification")
	for method: String in ["shen_shore","shen_mobile"]:
		if not Finale.available_methods(s,"classification").has(method):check(not s.classify_capstone_orders(FIXED_PARTITION,method).correct and s.to_dict()==unchanged,"No false live classification-helper availability "+method)
	var bad: Dictionary=FIXED_PARTITION.duplicate();bad.capstone_pending_003="proven_false"
	check(not s.classify_capstone_orders(bad).correct and s.to_dict()==unchanged,"Unknown is not automatically guilty; wrong partition no cost")
	check(s.classify_capstone_orders(FIXED_PARTITION).correct and s.capstone_stage==5,"Explicit exact four-order partition")
	unchanged.capstone_stage=5;check(s.to_dict()==unchanged,"Classification only changes stage")
	s=roundtrip(s,"stage5_empty_draft")
	unchanged=s.to_dict().duplicate(true)
	check(not s.classify_capstone_orders(FIXED_PARTITION).correct and s.to_dict()==unchanged,"Reloaded classified stage never requires/replays classification")
	check(s.choose_capstone_plan(plan),"Choose reversible draft")
	check(s.choose_capstone_plan(""),"Clear draft preserves explicit classification")
	check(s.capstone_stage==5 and s.choose_capstone_plan(plan),"Draft after clear needs no repeated proof")
	for order: Dictionary in Finale.order_rows(s):check(order.disposition=="pending","Draft operates on zero orders")
	travel(s,"frostbridge")
	unchanged=s.to_dict().duplicate(true)
	check(not s.confirm_capstone_disposition(plan) and s.to_dict()==unchanged,"Archive cannot commit desk disposition")
	travel(s,"sluice")
	unchanged=s.to_dict().duplicate(true)
	check(s.confirm_capstone_disposition(plan) and s.capstone_stage==6,"Explicit desk confirmation")
	unchanged.capstone_stage=6;unchanged.capstone_ending=plan;check(s.to_dict()==unchanged,"Desk changes only new stage/ending and pays nothing")
	for index: int in 4:
		var order: Dictionary=Finale.order_rows(s)[index]
		check(order.id=="capstone_pending_%03d"%(index+1),"Exact fixed new order ID")
		check(order.evidence==("proven_false" if index<2 else "unverified"),"Two proven false and two unknown retain evidence")
		check(order.disposition==("cancelled" if index<2 else ("held" if plan=="pause_batch" else "continuing")),"Exactly two cancellations and chosen treatment of unknowns")
	s=roundtrip(s,"stage6_unpaid")
	unchanged=s.to_dict().duplicate(true)
	check(not s.finish_capstone_homecoming() and s.to_dict()==unchanged,"Desk does not pay homecoming")
	travel(s,"qingwei")
	check(s.capstone_stage==6 and total_xp(s)==xp_before,"Qingwei entry alone does not finish")
	var home_before: Dictionary=s.to_dict().duplicate(true)
	check(s.finish_capstone_homecoming() and s.capstone_stage==7,"Actual model homecoming confirmation")
	check(total_xp(s)==xp_before+160 and s.coins==home_before.coins+80,"Both endings pay exactly160XP80coins once")
	check(preserved_story(s)==history,"Full finale preserves prior history/grain/receipt exactly")
	check(Finale.goal(s).is_empty(),"Completed finale releases optional exploration goal")
	if s.level==home_before.level:check(s.hp==home_before.hp and s.qi==home_before.qi,"Homecoming without levelup cannot heal")
	else:check(s.hp==s.max_hp and s.qi==s.max_qi,"Ordinary levelup recovery explicitly preserved")
	check(s.party_resources==home_before.party_resources,"Homecoming does not heal bench/downed companion absolute resources")
	operations.append({"case":case_id,"operation":"homecoming","before":home_before,"after":s.to_dict()})
	var failed_path: String=(isolated_root + "/missing-parent/save.json")
	unchanged=s.to_dict().duplicate(true)
	check(s.save_game(failed_path)!=OK and s.to_dict()==unchanged,"Save failure cannot replay or undo homecoming")
	check(not s.finish_capstone_homecoming() and s.to_dict()==unchanged,"Repeated terminal homecoming no payout")
	s=roundtrip(s,"stage7_retry_after_failed_save")
	unchanged=s.to_dict().duplicate(true)
	check(not s.finish_capstone_homecoming() and s.to_dict()==unchanged,"Reloaded completion no second payout")
	cases.append({"case":case_id,"plan":plan,"entry":before,"result":row,"classification_map":classify_map,"home_before":home_before,"final":s.to_dict()})
	return s
func _run() -> void:
	if not prepare_run_output(): quit(2); return
	minimal_build=true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--mode="):mode=argument.trim_prefix("--mode=")
	for school: String in ["听潮阁","照野堂","问石门"]:
		for protected: bool in ([false,true] if mode!="quick" else [false]):
			case_id=school+("/protected" if protected else "/public")
			var harbor=earn_harbor(school,protected)
			if harbor==null:_finish();return
			for old_plan: String in (["hold_for_inspection","return_to_owner"] if mode!="quick" else ["return_to_owner"]):
				case_id=school+("/protected/" if protected else "/public/")+old_plan
				var base=earn_consignee(harbor,old_plan)
				if base==null:_finish();return
				var ready=earn_ready(base)
				for plan: String in (["pause_batch","cancel_proven"] if mode!="quick" else ["pause_batch"]):
					var finished=finish_capstone(ready,plan,"sluice" if protected else "frostbridge")
					if finished==null:_finish();return
	_finish()
func _finish() -> void:
	var file=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"failure_labels":failure_labels,"mode":mode,"cases":cases,"journey":journey,"states":states,"operations":operations,"scope":"Earned State/API and automatic-combat model, no physical walking/main-scene/new art/browser proof. Original opening scene-local effects replayed exactly through existing helpers. No direct grants. Explicit rest and ordinary levelups recorded."},"\t"));file.close()
	print("INDEPENDENT_EARNED %d checks %d failures %d complete cases"%[checks,failures,cases.size()])
	quit(0 if failures==0 else 1)
func _fight(s, encounter: String, policy: bool, label: String) -> Dictionary:
	if encounter!="capstone_authorizer":return super._fight(s,encounter,policy,label)
	travel(s,"frostbridge")
	var before: Dictionary=s.to_dict().duplicate(true)
	check(s.start_party_battle(encounter),"Actual new controller enters only ready proof")
	if not s.battle_active:return {}
	check(s.to_dict()==before,"Capstone entry adds no rest/healing/resources")
	var start: Dictionary=s.party_battle_snapshot()
	check(start.enemies.size()==1 and start.enemies[0].id=="liang_zhen","One actual fixed boss and no summons")
	var maxhp: int=start.enemies[0].max_hp
	var prevhp: int=maxhp
	var accepted: int=0
	var basics: Dictionary={}
	var living: Dictionary={}
	var cooldowns: Dictionary={}
	var rows: Array=[]
	var terminal: Dictionary={}
	while s.battle_active and accepted<500:
		var view: Dictionary=s.party_battle_snapshot()
		if not living.has(view.round):
			var ids: Array=[]
			for actor: Dictionary in view.actors:
				if actor.hp>0:ids.append(actor.id)
			living[view.round]=ids
		var item: String=_plan(s.party_session) if policy else ""
		var tx: Dictionary
		if not item.is_empty():
			s.select_party_actor(item);tx=s.party_battle_action("item")
		else:tx=s.advance_party_battle()
		check(tx.accepted,"Actual capstone transaction progresses")
		if not tx.accepted:break
		check(not s.advance_party_battle().accepted,"Locked automatic basic cannot replay")
		check(not s.finish_party_presentation(tx.epoch,tx.token+987654).accepted,"Wrong token cannot present")
		check(tx.after.enemies.size()==1 and tx.after.enemies[0].max_hp==maxhp and tx.after.enemies[0].hp<=prevhp,"Boss fixed endurance and no secret heal")
		prevhp=tx.after.enemies[0].hp
		_check_transaction(tx,cooldowns)
		if tx.action_id=="attack" and tx.source_id in s.party_roster:
			var key: String="%d:%s"%[tx.before.round,tx.source_id]
			check(not basics.has(key),"Exactly one basic at most per actor/round")
			basics[key]=true
		for event: Dictionary in tx.events:
			if event.type=="round_end":
				for id: String in living[tx.before.round]:check(basics.has("%d:%s"%[tx.before.round,id]),"Every living actor earned exactly one completed-round basic")
		if not tx.after.active:
			check(s.capstone_stage==3,"Unpresented terminal cannot grant book")
			check(s.save_game((isolated_root + "/terminal-unpresented.json"))==ERR_BUSY,"Terminal checkpoint cannot save mid-presentation")
		var done: Dictionary=s.finish_party_presentation(tx.epoch,tx.token)
		check(done.accepted,"Actual exact token terminal and nonterminal acknowledgement")
		if not done.accepted:break
		var stable: Dictionary=s.to_dict().duplicate(true)
		check(not s.finish_party_presentation(tx.epoch,tx.token).accepted and s.to_dict()==stable,"Duplicate terminal/action acknowledgement has zero effect")
		rows.append({"round":tx.before.round,"source":tx.source_id,"action":tx.action_id,"events":tx.events,"after_hp":tx.after.enemies[0].hp,"actors":tx.after.actors,"medicine":tx.after.medicine})
		accepted+=1;terminal=tx
	check(not s.battle_active,"New encounter reaches real bounded terminal")
	if terminal.is_empty():return {}
	var row: Dictionary=_record(label,s.level,start,terminal.after,policy,accepted,{"fixed_boss_hp":maxhp,"entry":before,"settlement":s.party_settlement,"basics":basics,"settled_hp":s.hp})
	row["trace"]=rows
	journey.append(row)
	return row
