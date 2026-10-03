extends "res://tests/heting_consignee_earned_scene_test.gd"
## All four party members explicitly recruited through genuine earned APIs.
var methods:Dictionary={}
var method_checks:Array=[]
var clone_misses:int=0
func _run()->void:
	if DirAccess.make_dir_recursive_absolute(OUT + "/%d" % OS.get_process_id()) != OK:
		push_error("Cannot create isolated independent evidence directory"); quit(2); return
	real_started=Time.get_ticks_msec();minimal_build=true
	var base=_earn_predecessors()
	for scenario:Dictionary in [{"harbor":"short_ferries","plan":"hold_for_inspection","bridge":"west","tang":"teach","shen":"shore"},{"harbor":"open_scale","plan":"return_to_owner","bridge":"east","tang":"preserve","shen":"mobile"}]:
		var s=base._detached_persistent_state()
		check(s.recruit_companion(),"Explicitly invite genuine Shen")
		check(s.begin_shen_care() and s.consult_shen_patient() and s.inspect_shen_shelter() and s.choose_shen_care(scenario.shen) and s.post_shen_notice(),"Earn and post real Shen care history")
		s.map_id="frostbridge"
		check(s.gather_resource("frost_timber").valid and s.repair_bridge(),"Earn finite bridge materials for Tang")
		check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest(scenario.tang) and s.recruit_tangqi(),"Earn Tang history and explicit invitation")
		s.map_id="mistwood"
		check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Earn Qin history and explicit invitation")
		s.map_id="heting"
		check(s.choose_heting_plan(scenario.harbor) and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief" if scenario.harbor=="short_ferries" else "heting_scale",scenario.harbor),"Earn original ending, no synthetic branch flags")
		check(s.learn_internal_skill() and s.learn_lightness(),"Acquire optional real skill-class lessons")
		check(s.set_party_roster(["hero","shen","tang","qin"]),"Deploy all four genuinely recruited actors")
		s.heal_rest()
		methods={"consignee_warehouse":"tang_"+scenario.tang,"heting_dispatch":"qin_timing","heting_lighter":"shen_"+scenario.shen}
		current_case="four_"+scenario.plan
		await _scene_case(s,scenario)
		if failures>0:break
	_finish()
func _choose(fragment:String,mouse:bool=false)->void:
	if fragment!="亲自核验":
		await super._choose(fragment,mouse);return
	var site:String=app.world.nearby_id
	var method:String=methods[site]
	var expected:String=app.consignee_story.METHOD_LABELS[method]
	var available:Array=_buttons().map(func(b):return b.text)
	check(available.has("亲自核验") and available.has(expected),"Earned history and standing deployed party offer useful alternative:"+method)
	var observation:String=app.consignee_story.OBSERVATION_SITES.find_key(site)
	var actor:String="tang" if method.begins_with("tang") else ("shen" if method.begins_with("shen") else "qin")
	var selected:Callable=app.modal_actions[available.find(expected)]
	# Adversarial UI-in-flight undeployment uses the actual validated roster API.
	check(app.state.set_party_roster(["hero"]),"Temporarily deselect companions through public roster API")
	var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
	selected.call();await _frame(2)
	check(app.state.to_dict()==before and app.state.writes==writes and not app.state.consignee_observations.has(observation),"Stale companion choice refuses genuinely recruited but no-longer-selected actor")
	check(_buttons().map(func(b):return b.text)==["亲自核验","先不核验"],"Refreshed UI retains sufficient solo route when party deselected")
	check(app.state.set_party_roster(["hero","shen","tang","qin"]),"Restore actual roster")
	await _close_readonly();await _interact(site)
	if site!="consignee_warehouse":await super._choose(app.consignee_story.link_label(site))
	var all_available:Array=_buttons().map(func(b):return b.text)
	check(all_available.has(expected),"Companion method reappears after real selection")
	await super._choose(expected,mouse)
	check(app.state.consignee_contributions.has(method),"Actual E and numbered/mouse dialogue records contribution:"+method)
	method_checks.append({"site":site,"method":method,"actor":actor,"roster":app.state.party_roster.duplicate(),"standing":app.state.party_resource_snapshot(),"clues":app.state.consignee_observations.duplicate()})
func _finish()->void:
	_hold("")
	var report={"checks":checks,"failures":failures,"failure_labels":scene_failure_labels,"scope":"API-earned predecessor history and all four genuine recruitments; new chapter actual main-scene movement/E/number/mouse/real PartyUI. No stats/resources fabricated. Adversarial in-flight roster changes use public selection API. Fixed60Hz headless only.","wall_seconds":(Time.get_ticks_msec()-real_started)/1000.0,"api_journey":journey,"scene_results":results_scene,"companion_methods":method_checks,"trace":evidence}
	var f=FileAccess.open((OUT + "/%d" % OS.get_process_id())+"/earned_party_scene.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("%s independent earned four-person scene: %d checks, %d failures, %d outcomes"%["PASS" if failures==0 else "FAIL",checks,failures,results_scene.size()])
	if is_instance_valid(app):app.queue_free()
	await process_frame;quit(0 if failures==0 and results_scene.size()==2 else 1)
