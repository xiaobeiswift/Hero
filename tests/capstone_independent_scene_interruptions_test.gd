extends "res://tests/capstone_independent_earned_scene_test.gd"
## Separate boundary evidence, NOT additional six-stop route claims. History and
## capstone stage3 are earned through real production APIs and tokens, then one
## canonical initial transfer admits genuine main-scene battle/input checks.
var boundary_results:Array=[]
func _run()->void:
	if not prepare_run_output():quit(2);return
	real_started=Time.get_ticks_msec();minimal_build=true
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	case_id="solo_actual_flee_defeat"
	var base=earn_harbor("听潮阁",false)
	var earned=earn_consignee(base,"hold_for_inspection")
	if failures>0 or earned==null:_finish();return
	var ready=earn_ready(earned)
	rest(ready,"explicit_before_boundary_transfer")
	await _prepare_scene(ready,false)
	await _solo_interruptions()
	if failures>0:_finish();return
	app.queue_free();await _frame(3)
	case_id="actual_downed_shen"
	_earn_full_party(base,false)
	earned=earn_consignee(base,"return_to_owner")
	if failures>0 or earned==null:_finish();return
	ready=earn_ready(earned);rest(ready,"explicit_before_boundary_transfer")
	check(ready.set_party_roster(["hero","shen"]),"Downed boundary starts genuine two-person roster through API")
	await _prepare_scene(ready,false)
	await _natural_downed_helper()
	_finish()
func _prepare_scene(earned,party:bool)->void:
	root.size=Vector2i(1280,800);current_scenario={"party":party,"plan":"pause_batch"}
	app=MainScene.instantiate();app.state=SceneProbeState.new();app.state._copy_persistent_from(earned)
	app.state.save_path=isolated_root+"/"+case_id+".json";app.view_preferences=NoPrefs.new();app.view_preferences.sound_enabled=false
	root.add_child(app);app._stop_audio();app.audio_on=false;app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal();app._sync_world_state()
	app.world.change_map("frostbridge",Vector2(1320,745));await _frame(3)
	await _interact("chapter_archive");await _choose("查看应战准备")
func _start_scene_battle()->void:
	await _choose("保存后阻止交发",true)
	check(app.current_screen=="party_battle" and app.state.battle_active,"Boundary battle is admitted by actual dialogue input")
func _wait_terminal()->void:
	var begin:int=ticks
	while app.current_screen=="party_battle" and ticks-begin<60*700:await _frame()
	check(app.current_screen=="explore" and not app.state.battle_active,"Actual PartyUI reaches and acknowledges terminal")
func _solo_interruptions()->void:
	var original:Dictionary=app.state.to_dict().duplicate(true);var stale:Callable=_callback("保存后阻止交发")
	await _start_scene_battle()
	var panel=app.overlay.get_meta("party_battle")
	# P requests the real public pause. Let any presentation complete naturally.
	await _tap(KEY_P)
	var until:int=ticks
	while not app.state.party_battle_snapshot().paused and ticks-until<1000:await _frame()
	var paused:Dictionary=app.state.party_battle_snapshot().duplicate(true)
	await _frame(90)
	check(app.state.party_battle_snapshot()==paused,"Actual P pause retains current action/round/resources across90frames")
	await _tap(KEY_5);await _wait_terminal()
	check(app.state.party_settlement.outcome=="flee" and app.state.capstone_stage==3,"Actual numeric flee gives no book or progress")
	check(total_xp(app.state)==_dict_total_xp(original) and app.state.coins==original.coins,"Actual flee awards no XP/coins")
	check(app.world.player_pos==Vector2(1320,745),"Actual flee never transports player")
	_stale_noop(stale,"original battle entry after flee")
	await _choose("先回霜桥行走");await _interact("chapter_archive");await _choose("查看应战准备")
	var before_defeat:Dictionary=app.state.to_dict().duplicate(true)
	await _start_scene_battle()
	await _wait_terminal() # Deliberately no commands; no manufactured damage.
	check(app.state.party_settlement.outcome=="defeat" and app.state.capstone_stage==3,"Natural zero-command solo defeat gives no book")
	check(app.state.map_id=="frostbridge" and app.world.map_id=="frostbridge" and app.world.player_pos==Vector2(405,430),"Actual capstone defeat settles only at Frostbridge inn405,430")
	check(total_xp(app.state)==_dict_total_xp(before_defeat) and app.state.coins==before_defeat.coins-8,"Actual defeat exact8coins loss, zero story reward")
	check(app.state.hp==app.state.max_hp and app.state.medicine==before_defeat.medicine,"Only standard defeat recovery occurs, with unchanged medicine stock")
	await _choose("站稳，再作打算");await _interact("chapter_host");await _choose("借榻调息",true)
	await _waypoints([Vector2(405,388),Vector2(1080,388),Vector2(1080,745),Vector2(1320,745)])
	await _interact("chapter_archive");await _choose("查看应战准备");await _start_scene_battle();await _scene_battle(false)
	check(app.state.capstone_stage==4,"Walking back after explicit rest and actual retry wins normally")
	boundary_results.append({"case":case_id,"entry":original,"final":app.state.to_dict(),"checks":"actual pause90frames/flee/zero-input defeat/standard Frostbridge recovery/explicit Wen rest/walk-back/retry win"})
func _natural_downed_helper()->void:
	var initial:Dictionary=app.state.to_dict().duplicate(true);var retreats:int=0
	while int(app.state.party_resources.shen.hp)>0 and retreats<5:
		await _start_scene_battle()
		var panel=app.overlay.get_meta("party_battle");var start:int=ticks
		# No commands, so natural automatic enemy hits reduce real saved HP. Flee
		# after round6 if necessary, preserving resources rather than granting damage.
		while app.current_screen=="party_battle" and ticks-start<60*400:
			var view:Dictionary=app.state.party_battle_snapshot()
			if int(app.state.party_resources.shen.hp)<=0 or int(view.round)>=7:
				await _tap(KEY_P)
				while app.current_screen=="party_battle" and not panel._safe_boundary():await _frame()
				if app.current_screen=="party_battle":await _tap(KEY_5)
				break
			await _frame()
		await _wait_terminal();retreats+=1
		check(app.state.party_settlement.outcome=="flee" and app.state.capstone_stage==3,"Resource-preserving real retreat keeps encounter retryable")
		if failures>0:return
		await _choose("先回霜桥行走")
		if int(app.state.party_resources.shen.hp)>0:
			await _interact("chapter_archive");await _choose("查看应战准备")
	check(int(app.state.party_resources.shen.hp)==0 and app.state.hp>0,"Real presented enemy hits genuinely down Shen while hero survives")
	if failures>0:return
	var downed:Dictionary=app.state.to_dict().duplicate(true)
	check(app.state.set_party_roster(["hero","shen","tang","qin"]),"Genuinely recruited four roster accepts saved downed Shen without healing")
	current_scenario.party=true
	await _interact("chapter_archive");await _choose("查看应战准备");await _start_scene_battle();await _scene_battle(false)
	check(app.state.party_resources.shen.hp==0,"Real win preserves naturally downed Shen and adds no automatic recovery")
	await _choose("记下守闸桌去处")
	await _waypoints([Vector2(1080,745),Vector2(1080,388),Vector2(700,388),Vector2(405,388),Vector2(405,500),Vector2(140,500)])
	await _interact("return_sluice",false)
	await _waypoints([Vector2(1110,290),Vector2(1110,650),Vector2(1340,650),Vector2(1340,690)])
	await _interact("capstone_order_desk");await _choose("选择同行核对方法")
	check(_choices()==["自己列明依据与后果","回到四号目录"],"Actual E-opened desk rejects naturally downed deployed Shen helper")
	check(Finale.available_methods(app.state,"classification")==["solo"],"Actual saved downed helper matches production method projection")
	await _choose("自己列明依据与后果");await _choose("作出四号分类");await _mutation("001、002证伪",5,false,true)
	check(app.state.party_resources.shen.hp==0 and app.state.capstone_stage==5,"Solo classification remains available without healing or inventing helper credit")
	boundary_results.append({"case":case_id,"entry":initial,"naturally_downed":downed,"final":app.state.to_dict(),"real_flees":retreats,"checks":"naturally downed via real automatic combat and input flee; no direct resource changes; real four-roster retry preserves downed Shen; actual desk hides helper and accepts solo"})
func _finish()->void:
	_hold("")
	var f=FileAccess.open(output,FileAccess.WRITE)
	if f!=null:
		f.store_string(JSON.stringify({"checks":checks,"failures":failures,"failure_labels":failure_labels,"boundaries":boundary_results,"trace":trace,"interruptions":interruption_checks,"api_journey":journey,"api_operations":operations,"ticks":ticks,"wall_seconds":(Time.get_ticks_msec()-real_started)/1000.0,"scope":"Separate boundary harness, not12-route/mainline evidence. Genuine production API/token-earned history and stage3 transferred once per boundary; subsequent actions use real main-scene input, held walking and PartyUI natural presentation. Resources are earned/reduced by actual actions only. No raw HP/progress writes, no manual token settlement, no silent healing or travel teleport. Headless fixed-step; not native/browser/manual-time proof."},"\t"));f.close()
	print("%s independent capstone real-scene interruptions: %d checks, %d failures, %d boundaries"%["PASS" if failures==0 else "FAIL",checks,failures,boundary_results.size()])
	if is_instance_valid(app):app.queue_free()
	await process_frame;quit(0 if failures==0 and boundary_results.size()==2 else 1)
