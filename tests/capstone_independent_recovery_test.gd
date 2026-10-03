extends "res://tests/capstone_independent_earned_test.gd"
func exhaust_real_inventory(s) -> void:
	var start_xp: int=total_xp(s)
	var count: int=0
	while s.medicine>0 and count<20:
		check(s.start_party_battle("capstone_authorizer"),"Spent-stock setup enters actual retry")
		while s.battle_active and s.hp>s.max_hp-45:
			var tx: Dictionary=s.advance_party_battle()
			check(tx.accepted,"Spent-stock setup actual incoming damage")
			check(s.finish_party_presentation(tx.epoch,tx.token).accepted,"Spent-stock damage presentation")
			if not tx.accepted:break
		if s.battle_active:
			var flee: Dictionary=s.party_battle_action("flee")
			check(flee.accepted and s.finish_party_presentation(flee.epoch,flee.token).accepted,"Actual flee preserves wounds and no reward")
		check(s.use_medicine(),"Consume existing medicine against actual wound")
		count+=1
	var coin_start: int=s.coins
	var cloth: int=-1
	for b: int in range(coin_start/6+1):
		if (coin_start-6*b)%5==0:cloth=b;break
	check(cloth>=0,"Finite earned coins spendable through existing material prices")
	if cloth>=0:
		var timber: int=(coin_start-6*cloth)/5
		while cloth>0:
			var buy: int=mini(99,cloth);check(s.buy_material("cloth",buy),"Actual existing6-coin purchase");cloth-=buy
		while timber>0:
			var buy: int=mini(99,timber);check(s.buy_material("timber",buy),"Actual existing5-coin purchase");timber-=buy
	check(s.medicine==0 and s.coins==0 and total_xp(s)==start_xp and s.capstone_stage==3,"Spent stock earned through APIs; no XP/grinding or stage grant")
	operations.append({"case":case_id,"operation":"actual_inventory_exhaustion","state":s.to_dict(),"medicine_cycles":count,"coin_spend":coin_start})
func _run() -> void:
	if not prepare_run_output(): quit(2); return
	minimal_build=true;mode="recovery"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	for school: String in ["听潮阁","照野堂","问石门"]:
		case_id=school+"/genuine_spent_stock_recovery"
		var harbor=earn_harbor(school,false)
		if harbor==null:_finish();return
		var base=earn_consignee(harbor,"return_to_owner")
		if base==null:_finish();return
		var s=earn_ready(base)
		rest(s,"before_adverse_idle_probe")
		var before: Dictionary=s.to_dict().duplicate(true)
		var idle: Dictionary=_fight(s,"capstone_authorizer",false,case_id+"/idle_risk")
		check(idle.get("outcome")=="defeat","Adverse idle route reaches genuine defeat, not acceptance requirement")
		check(s.capstone_stage==3 and s.map_id=="frostbridge" and s.position==Vector2(405,430),"New defeat returns only to authored Frostbridge inn-side")
		check(s.coins==maxi(0,before.coins-8) and s.hp==s.max_hp and s.qi>=2 and s.medicine==before.medicine,"Existing defeat restoresHP/Qi floor; loses at most8coins; no medicine")
		check(total_xp(s)==int(before.xp)+30*int(before.level)*(int(before.level)-1),"Defeat cannot fabricate XP")
		s=roundtrip(s,"actual_defeat_retry")
		exhaust_real_inventory(s)
		var zero_probe=s._detached_persistent_state()
		check(_fight(zero_probe,"capstone_authorizer",false,case_id+"/zero_coin_defeat").get("outcome")=="defeat" and zero_probe.coins==0 and zero_probe.medicine==0 and zero_probe.capstone_stage==3,"Actual zero-coin defeat never makes coins negative or restores stock")
		var after_spend: Dictionary=s.to_dict().duplicate(true)
		check(s.equip_art(s.sect_art()) and s.learn_internal_skill() and s.learn_lightness(),"Existing free school/internal/lightness access with zero funds")
		check(s.hp==after_spend.hp and s.qi==after_spend.qi,"Learning/equipping does not secretly heal")
		rest(s,"explicit_existing_free_recovery")
		check(s.coins==0 and s.medicine==0 and total_xp(s)==int(after_spend.xp)+30*int(after_spend.level)*(int(after_spend.level)-1),"Free recovery needs no purchase, stock refill or grind")
		var finished=finish_capstone(s,"cancel_proven")
		if finished==null:_finish();return
		check(finished.medicine==0 and finished.coins==80,"Recovered final fight consumes no medicine; only homecoming adds80coins")
	_finish()
