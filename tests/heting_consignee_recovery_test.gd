extends "res://tests/heting_consignee_earned_scene_test.gd"
var recoveries:Array=[]
func _run()->void:
	if DirAccess.make_dir_recursive_absolute(OUT + "/%d" % OS.get_process_id()) != OK:
		push_error("Cannot create isolated independent evidence directory"); quit(2); return
	real_started=Time.get_ticks_msec();minimal_build=true
	for school:String in ["听潮阁","照野堂","问石门"]:
		earned_school=school
		var s=_earn_predecessors()
		check(s.choose_heting_plan("short_ferries") and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief","short_ferries"),"Earn old chapter ending")
		check(s.level==6 and s.party_roster==["hero"] and s.equipment=="旧铁剑" and not s.internal_unlocked and not s.lightness_unlocked,"Natural no-recruit starter equipment recovery entry")
		# Deliberately adversarial spent-inventory fixture; no added XP/stats/gear.
		s.medicine=0;s.coins=0
		check(s.equip_art(s.sect_art()) and s.learn_internal_skill() and s.learn_lightness(),"Existing free eligible school/internal/lightness lessons work with no coins")
		s.heal_rest()
		check(s.medicine==0 and s.coins==0,"Ordinary free rest grants no medicine/coins")
		check(s.begin_consignee(),"Begin independently without optional receipt")
		for observation:String in s.Consignee.OBSERVATIONS:check(s.observe_consignee(observation),"Solo API physical-observation contract")
		check(s.resolve_consignee_contradiction(s.Consignee.CORRECT_ANSWER).correct and s.choose_consignee_plan("hold_for_inspection"),"Valid recovered new battle entry")
		var before:Dictionary=s.to_dict().duplicate(true)
		var result:Dictionary=_fight(s,"heting_consignee",true,"no_consumable_recovery_"+school)
		check(result.get("outcome")=="win","No-consumable recovery wins:"+school)
		check(s.consignee_stage==3 and s.medicine==0 and s.coins==0 and _earned_xp(s)==_dict_xp(before),"No medicine/purchase/grinding/reward used for recovered win")
		recoveries.append({"school":school,"entry":before,"result":result,"final":s.to_dict()})
	_finish()
func _finish()->void:
	var report={"checks":checks,"failures":failures,"failure_labels":scene_failure_labels,"scope":"Each school separately earns complete predecessor route using current State/current automatic-combat APIs with starter gear and no recruits. Only medicine and coins are explicitly set to zero as an adversarial spent-inventory fixture. Existing free school/internal/lightness lessons and explicit free rest; no extra XP, stat inflation, gear, purchases, receipts, grind or new scene claim.","api_journey":journey,"recoveries":recoveries}
	var f=FileAccess.open((OUT + "/%d" % OS.get_process_id())+"/no_consumable_recovery.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("%s no-consumable recovery %d checks %d failures %d schools"%["PASS" if failures==0 else "FAIL",checks,failures,recoveries.size()]);quit(0 if failures==0 and recoveries.size()==3 else 1)
