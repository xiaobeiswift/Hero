extends "res://tests/capstone_independent_party_test.gd"
func down_helper_from_actual_damage(source, actor: String):
	var s=source._detached_persistent_state()
	check(s.set_party_roster(["hero",actor]) and s.set_formation("并肩"),"Actual two-member exposure roster")
	rest(s,"explicit_before_injury_probe")
	var cycles: int=0
	var xp_before: int=total_xp(s)
	while int(s.party_resources[actor].hp)>0 and cycles<10:
		check(s.start_party_battle("capstone_authorizer"),"Actual injury probe starts encounter")
		while s.battle_active and s.party_battle_snapshot().round<=2:
			var tx: Dictionary=s.advance_party_battle()
			check(tx.accepted and s.finish_party_presentation(tx.epoch,tx.token).accepted,"Actual announced attacks cause helper wound")
			if not tx.accepted:break
		if s.battle_active:
			var flee: Dictionary=s.party_battle_action("flee")
			check(flee.accepted and s.finish_party_presentation(flee.epoch,flee.token).accepted,"Flee preserves actual helper injury")
		cycles+=1
	check(s.party_resources[actor].hp==0 and s.capstone_stage==3 and total_xp(s)==xp_before,"Actual helper downing grants no XP and does not revoke proof")
	operations.append({"case":case_id,"operation":"actual_helper_down","actor":actor,"cycles":cycles,"state":s.to_dict()})
	return roundtrip(s,"actual_helper_down_keeps_completed_proof")
func interrupted_checkpoint(source) -> void:
	var s=source._detached_persistent_state()
	check(s.save_game((isolated_root + "/pre-battle-restart.json"))==OK,"Real prebattle checkpoint")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes((isolated_root + "/pre-battle-restart.json"))
	var checkpoint: Dictionary=s.to_dict().duplicate(true)
	check(s.start_party_battle("capstone_authorizer"),"Checkpoint interruption actual battle begins")
	var tx: Dictionary=s.advance_party_battle()
	check(tx.accepted and s.save_game((isolated_root + "/pre-battle-restart.json"))==ERR_BUSY,"Pending presentation cannot overwrite checkpoint")
	check(FileAccess.get_file_as_bytes((isolated_root + "/pre-battle-restart.json"))==bytes,"Actual pending checkpoint bytes preserved")
	var restarted=State.new()
	check(restarted.load_game((isolated_root + "/pre-battle-restart.json"))==OK and restarted.to_dict()==checkpoint,"Fresh-state restart loads exact prebattle persisted stage/resources")
	check(not restarted.finish_party_presentation(tx.epoch,tx.token).accepted and restarted.to_dict()==checkpoint,"Old instance token cannot commit into restarted state")
	check(s.finish_party_presentation(tx.epoch,tx.token).accepted,"Original instance can still finish its own token")
	var flee: Dictionary=s.party_battle_action("flee")
	check(flee.accepted and s.finish_party_presentation(flee.epoch,flee.token).accepted,"Original interrupted instance exits through real flee")
	check(restarted.to_dict()==checkpoint,"Old instance settlement cannot mutate restart")
func classify_with_helper_and_finish(s, helper: String, plan: String) -> void:
	var before: Dictionary=s.to_dict().duplicate(true)
	check(s.classify_capstone_orders(FIXED_PARTITION,helper).correct,"Actual standing helper classification")
	before.capstone_stage=5;check(s.to_dict()==before,"Helper classification adds no credit/stat flags")
	check(s.set_party_roster(["hero"]),"Bench classifier after completed action")
	s=roundtrip(s,"helper_classification_persists_benched")
	check(s.capstone_stage==5 and not s.classify_capstone_orders(FIXED_PARTITION,helper).correct,"Completed helper classification cannot be revoked or repeated")
	travel(s,"sluice");check(s.choose_capstone_plan(plan) and s.confirm_capstone_disposition(plan),"Actual disposition after helper benches")
	travel(s,"qingwei")
	var companion_resources: Dictionary=s.party_resources.duplicate(true)
	check(s.finish_capstone_homecoming() and s.party_resources==companion_resources,"Homecoming levelup preserves wounded and benched helper resources")
	states.append({"label":case_id+"/helper_completed","state":s.to_dict()})
func postgame_optional(s) -> void:
	travel(s,"heting")
	check(s.capstone_stage==7 and s.receipt_stage==0 and s.begin_receipt(),"Unfinished receipt still begins after finale")
	rest(s,"postgame_receipt")
	check(_journey_win(s,"heting_receipt",case_id+"/optional_receipt"),"Actual optional receipt fight after finale")
	check(s.compare_receipt() and s.receipt_stage==3 and s.capstone_stage==7,"Actual receipt comparison does not rewrite finale")
	recruit_real_party(s,"teach","shore")
	check(s.capstone_stage==7,"Actual optional care/craft/Qin recruitment remains open after finale")
	states.append({"label":case_id+"/postgame_optional_completed","state":s.to_dict()})
func _run() -> void:
	if not prepare_run_output(): quit(2); return
	minimal_build=true;mode="boundaries"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	case_id="actual_boundary_lineage"
	var harbor=earn_harbor("听潮阁",false)
	if harbor==null:_finish();return
	var base=earn_consignee(harbor,"return_to_owner")
	if base==null:_finish();return
	var ready=earn_ready(base)
	interrupted_checkpoint(ready)
	var finished=finish_capstone(ready,"pause_batch")
	if finished==null:_finish();return
	postgame_optional(finished)
	# All optional receipt stages are reached by real legacy APIs/battle.
	var receipt=base._detached_persistent_state()
	check(receipt.begin_receipt(),"Actual pending optional receipt")
	for stage: int in [1,2,3]:
		case_id="receipt%d_before_finale"%stage
		if stage==2:
			rest(receipt,"actual_optional_receipt_before_finale")
			if not _journey_win(receipt,"heting_receipt",case_id+"/receipt"):_finish();return
		elif stage==3:check(receipt.compare_receipt(),"Actual optional receipt verified")
		check(receipt.receipt_stage==stage,"Receipt stage earned rather than assigned")
		var r=earn_ready(receipt)
		var end=finish_capstone(r,"cancel_proven")
		if end==null:_finish();return
		check(end.receipt_stage==stage,"Finale preserves optional receipt status%d"%stage)
	var used_party=base._detached_persistent_state()
	recruit_real_party(used_party,"teach","shore")
	for actor: String in ["tang","qin"]:
		case_id="actual_used_helper_down_"+actor
		var used_ready=helper_ready(used_party,"tang_teach" if actor=="tang" else "qin_timing")
		var used_down=down_helper_from_actual_damage(used_ready,actor)
		check(used_down.capstone_stage==3 and used_down.party_resources[actor].hp==0,"Previously used evidence helper may fall without erasing accepted proof")
		check(used_down.set_party_roster(["hero"]),"Bench genuinely downed helper before ordinary defeat")
		var defeat_before: Dictionary=used_down.to_dict().duplicate(true)
		check(_fight(used_down,"capstone_authorizer",false,case_id+"/existing_defeat_recovery").get("outcome")=="defeat","Genuine solo defeat while used helper benched/down")
		var catalog: Dictionary=Catalog.build_team(used_down,["hero","shen","tang","qin"])
		for member: Dictionary in catalog.team.actors:
			if member.id!="hero":check(used_down.party_resources[member.id].hp==member.max_hp and used_down.party_resources[member.id].qi>=2,"Existing defeat revives all recruited even benched helper; explicit policy preserved")
		check(used_down.coins==maxi(0,defeat_before.coins-8) and used_down.medicine==defeat_before.medicine and used_down.capstone_stage==3,"No new-only defeat resource policy")
	for variant: String in ["shore","mobile"]:
		case_id="actual_helper_"+variant
		var party=base._detached_persistent_state()
		recruit_real_party(party,"teach" if variant=="shore" else "preserve",variant)
		var party_ready=helper_ready(party,"tang_teach" if variant=="shore" else "tang_preserve")
		var hurt=down_helper_from_actual_damage(party_ready,"shen")
		check(hurt.set_party_roster(["hero","shen","tang","qin"]),"Select actual downed Shen in full roster")
		var fight: Dictionary=_fight(hurt,"capstone_authorizer",true,case_id+"/downed_roster_win")
		check(fight.get("outcome")=="win" and hurt.party_resources.shen.hp==0,"Actual win retains downed deployed companion")
		var before: Dictionary=hurt.to_dict().duplicate(true)
		check(not hurt.classify_capstone_orders(FIXED_PARTITION,"shen_"+variant).correct and hurt.to_dict()==before,"Actual downed helper cannot classify; no historical participation credited")
		check(hurt.classify_capstone_orders(FIXED_PARTITION).correct,"Solo classification remains free with downed helper")
		check(hurt.set_party_roster(["hero"]),"Bench actual downed companion")
		hurt=roundtrip(hurt,"stage5_down_bench_persists")
		travel(hurt,"sluice");check(hurt.choose_capstone_plan("pause_batch") and hurt.confirm_capstone_disposition("pause_batch"),"Downed helper does not block exact disposition")
		travel(hurt,"qingwei");before=hurt.to_dict().duplicate(true)
		check(hurt.finish_capstone_homecoming() and hurt.party_resources==before.party_resources and hurt.party_resources.shen.hp==0,"Homecoming levelup never revives downed/benched helper")
		states.append({"label":case_id+"/downed_completed","state":hurt.to_dict()})
		# Separate legitimately standing helper action, then bench and reload.
		var standing=party_ready._detached_persistent_state()
		check(standing.set_party_roster(["hero","shen","tang","qin"]),"Select standing full roster")
		rest(standing,"explicit_standing_helper_branch")
		check(_fight(standing,"capstone_authorizer",true,case_id+"/standing").get("outcome")=="win","Standing helper branch earns book")
		classify_with_helper_and_finish(standing,"shen_"+variant,"cancel_proven")
	_finish()
