extends "res://tests/capstone_independent_earned_test.gd"
func recruit_real_party(s, tang: String, shen: String) -> void:
	travel(s,"qingwei")
	check(s.recruit_companion(),"Actual optional Shen invitation, never granted flag")
	check(s.begin_shen_care() and s.consult_shen_patient() and s.inspect_shen_shelter() and s.choose_shen_care(shen) and s.post_shen_notice(),"Actual complete Shen care history")
	travel(s,"frostbridge")
	check(s.gather_resource("frost_timber").valid and s.repair_bridge(),"Actual finite timber and optional repaired bridge")
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest(tang) and s.recruit_tangqi(),"Actual chosen Tang personal history and invitation")
	travel(s,"mistwood")
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Actual Qin handoff and invitation")
	check(s.party_roster==["hero","shen","tang","qin"],"Genuine four actor roster")
func helper_ready(source, method: String):
	var s=source._detached_persistent_state()
	travel(s,"heting");check(s.begin_capstone(),"Party accepts true referral")
	travel(s,"frostbridge");check(s.reveal_capstone_letter(),"Party verifies returned letter")
	var before: Dictionary=resources(s)
	check(s.set_party_roster(["hero"]),"Bench genuine helpers")
	check(resources(s)==before,"Roster change cannot heal or spend")
	var unchanged: Dictionary=s.to_dict().duplicate(true)
	check(Finale.available_methods(s,"evidence")==["solo"] and not s.resolve_capstone_evidence("authorized_issued_chain",method).correct and s.to_dict()==unchanged,"Benched helper unavailable and rejection atomic")
	check(s.set_party_roster(["hero","shen","tang","qin"]),"Redeploy real helpers")
	check(Finale.available_methods(s,"evidence").has(method),"Genuine history/deployment/standing enables method")
	check(not s.resolve_capstone_evidence("authorized_issued_chain","shen_shore").correct,"Care history cannot impersonate issued-record method")
	check(s.resolve_capstone_evidence("authorized_issued_chain",method).correct,"Actual optional helper proves issued chain")
	check(s.set_party_roster(["hero"]),"Bench helper after accepted evidence")
	s=roundtrip(s,"actual_helper_benched_after_evidence")
	check(s.capstone_stage==3,"Completed proof persists after helper benches/reloads")
	check(not Finale.journal(s).contains("唐栖") and not Finale.journal(s).contains("秦禾") and not Finale.journal(s).contains("沈青"),"Minimal save never invents historical named helper credit")
	return s
func _run() -> void:
	if not prepare_run_output(): quit(2); return
	minimal_build=true;mode="party_subsets"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	var school_index: int=0
	for school: String in ["听潮阁","照野堂","问石门"]:
		case_id=school+"/genuine_party"
		var harbor=earn_harbor(school,false)
		if harbor==null:_finish();return
		var base=earn_consignee(harbor,"return_to_owner")
		if base==null:_finish();return
		var tang: String="preserve" if school_index==2 else "teach"
		recruit_real_party(base,tang,"mobile" if school_index==2 else "shore")
		var method: String="qin_timing" if school_index==0 else ("tang_teach" if school_index==1 else "tang_preserve")
		var ready=helper_ready(base,method)
		for formation: String in ["并肩","护后"]:
			check(ready.set_party_roster(["hero","shen","tang","qin"]) and ready.set_formation(formation),"Select formation using real recruited companions")
			for roster: Array in ROSTERS:
				var before: Dictionary=resources(ready)
				check(ready.set_party_roster(roster) and resources(ready)==before,"Every actual roster subset preserves wounded/benched pool")
				case_id=school+"/"+formation+"/"+str(roster)
				for plan: String in ["pause_batch","cancel_proven"]:
					var finished=finish_capstone(ready,plan)
					if finished==null:_finish();return
		school_index+=1
	_finish()
