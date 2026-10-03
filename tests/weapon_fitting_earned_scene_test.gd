extends "res://tests/weapon_fitting_earned_driver.gd"
## Four earned boundaries; real fitting and combat inputs after explicit transfers.
const MainScene=preload("res://scenes/main.tscn")
const Prefs=preload("res://scripts/view_preferences.gd")
const TrialFactory=preload("res://scripts/weapon_fitting_trial_rules.gd")
class NoPrefs extends Prefs:
	func load_settings(_path: String=PATH)->Error:return OK
	func save_settings(_path: String=PATH)->Error:return OK
var app
var selected_case: String=""
var scene_cases: Array=[]
var trial_cases: Array=[]
var input_trace: Array=[]
var transfer_points: Array=[]
var earned_boundary_artifacts: Array=[]
var ticks: int=0
var input_count: int=0
var walked_pixels: float=0
var held: String=""
var started_ms: int=0
var observed_tokens: Dictionary={}
var observed_transactions: Array=[]
var auditing_battle: bool=false
var scenario: Dictionary={}
var scope_text: String="Current production State/API-earned prerequisites; exact sourced opening scene-local effects. Declared canonical transfer into Main; held walking/E/numeric/mouse input and natural current PartyUI presentation. Later case has declared model travel between Qingwei and Heting physical segments. Headless fixed-step timing is not user playtime, native pixels, browser or manual performance proof. No stat/gear/recruit flags granted; no user saves touched."

func _run()->void:
	if not prepare_run_output():quit(2);return
	started_ms=Time.get_ticks_msec();minimal_build=true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--case="):selected_case=argument.trim_prefix("--case=")
	var scenarios: Array=[
		{"id":"early_tingchao_solo","school":"听潮阁","full":false,"fitted":"edge","encounter":"sect_trial"},
		{"id":"early_zhaoye_solo","school":"照野堂","full":false,"fitted":"guard","encounter":"sect_trial"},
		{"id":"early_wenshi_solo","school":"问石门","full":false,"fitted":"edge","encounter":"sect_trial"},
		{"id":"later_full_party","school":"听潮阁","full":true,"fitted":"guard","encounter":"heting_consignee"}]
	for item: Dictionary in scenarios:
		if not selected_case.is_empty() and selected_case!=item.id:continue
		scenario=item;case_id=item.id
		var earned=_earned_later() if item.full else _earned_early(item.school)
		if earned==null or failures>0:_finish();return
		var entry_path: String=isolated_root+"/"+case_id+"-api-earned.json"
		check(earned.save_game(entry_path)==OK,"Preserve actual writer16 API-earned boundary before scene transfer")
		earned_boundary_artifacts.append({"case":case_id,"path":ProjectSettings.globalize_path(entry_path),"sha256":FileAccess.get_sha256(entry_path),"state":earned.to_dict(),"scope":"Genuine API-earned boundary before declared physical-scene position transfer"})
		await _scene_case(earned)
		_write_report(false)
		if failures>0:_finish();return
	if selected_case.is_empty() or selected_case=="early_tingchao_solo":
		case_id="historical15_migration";_historical_unlocked_migration()
	_finish()

func prepare_run_output()->bool:
	isolated_root="user://weapon-fitting-earned-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(isolated_root)!=OK:return false
	output=isolated_root+"/report.json"
	return true

func _frame(count: int=1)->void:
	for i: int in count:
		_capture_pending()
		await process_frame;ticks+=1
		_capture_pending()

func _capture_pending()->void:
	if not auditing_battle or not is_instance_valid(app) or not app.overlay.has_meta("party_battle"):return
	var panel=app.overlay.get_meta("party_battle")
	if panel==null or panel.pending.is_empty():return
	var tx: Dictionary=panel.pending
	var key: String=str(tx.epoch)+":"+str(tx.token)
	if observed_tokens.has(key):return
	observed_tokens[key]=true
	observed_transactions.append(tx.duplicate(true))

func _tap(code: int)->void:
	input_count+=1
	var down=InputEventKey.new();down.keycode=code;down.physical_keycode=code;down.pressed=true;Input.parse_input_event(down)
	await _frame()
	var up=InputEventKey.new();up.keycode=code;up.physical_keycode=code;up.pressed=false;Input.parse_input_event(up)
	await _frame(2)

func _click(button: Control)->void:
	if failures>0:return
	var rect: Rect2=button.get_global_rect()
	check(rect.has_area() and root.get_visible_rect().encloses(rect) and button.is_visible_in_tree(),"Actual mouse target visible and inside viewport:"+button.name)
	if failures>0:return
	input_count+=1
	var point: Vector2=rect.get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);await _frame()
	var down=InputEventMouseButton.new();down.position=point;down.global_position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await _frame()
	var up=InputEventMouseButton.new();up.position=point;up.global_position=point;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up);await _frame(3)

func _visible_buttons(node: Node=null)->Array:
	if node==null:node=app.overlay
	var found: Array=[]
	for child: Node in node.get_children():
		if child is Button and child.is_visible_in_tree():found.append(child)
		found.append_array(_visible_buttons(child))
	return found

func _choose(fragment: String, exact: bool=false)->void:
	if failures>0:return
	var labels: Array=[]
	for button in _visible_buttons():
		labels.append(button.text)
		if (String(button.text)==fragment if exact else String(button.text).contains(fragment)) and not button.disabled:
			await _click(button);_record_input("mouse:"+fragment);return
	check(false,"Visible enabled choice missing:"+fragment+" actual="+str(labels))

func _record_input(action: String)->void:
	if not is_instance_valid(app):return
	input_trace.append({"case":case_id,"input":action,"frame":ticks,"map":app.state.map_id,"world_map":app.world.map_id,
		"world_position":[app.world.player_pos.x,app.world.player_pos.y],"stored_position":[app.state.position.x,app.state.position.y],
		"nearby":app.world.nearby_id,"fitting":app.state.weapon_fitting,"level":app.state.level,"screen":app.current_screen})

func _hold(next: String)->void:
	if held==next:return
	if not held.is_empty():Input.action_release(held)
	held=next
	if not held.is_empty():Input.action_press(held);input_count+=1

func _walk(target: Vector2)->void:
	if failures>0:return
	check(not app.active_modal and app.current_screen=="explore","Actual walking begins outside modal")
	if failures>0:return
	for i: int in 3000:
		var previous: Vector2=app.world.player_pos
		var delta: Vector2=target-previous
		if absf(delta.x)<=3 and absf(delta.y)<=3:
			_hold("");await _frame(2);_record_input("walk");return
		_hold(("move_right" if delta.x>0 else "move_left") if absf(delta.x)>3 else ("move_down" if delta.y>0 else "move_up"))
		await _frame();walked_pixels+=previous.distance_to(app.world.player_pos)
		check(app.world._can_walk(app.world.player_pos),"Actual held input remains collision-valid")
		if failures>0:break
	_hold("");check(false,"Walking stuck toward %s at %s on %s"%[target,app.world.player_pos,app.state.map_id])

func _waypoints(points: Array)->void:
	for point: Vector2 in points:
		await _walk(point)
		if failures>0:return

func _interact(site: String)->void:
	if failures>0:return
	check(app.world.nearby_id==site,"Actual E interaction site:"+site+" got "+app.world.nearby_id)
	await _tap(KEY_E)
	check(app.active_modal,"Actual E opens "+site)
	_record_input("E:"+site)

func _close_readonly()->void:
	var before: Dictionary=app.state.to_dict().duplicate(true)
	var disk: Dictionary=_disk_manifest()
	var position: Vector2=app.world.player_pos
	await _tap(KEY_ESCAPE)
	check(not app.active_modal and app.state.to_dict()==before and _disk_manifest()==disk and app.world.player_pos==position,"Escape is read-only and does not move player")

func _disk_manifest(path: String="user://")->Dictionary:
	var found: Dictionary={}
	var directory=DirAccess.open(path)
	if directory==null:return found
	for filename: String in directory.get_files():
		var full: String=path.path_join(filename)
		# This harness's report is outside save semantics and can be checkpointed.
		if full==output:continue
		found[full]={"sha256":FileAccess.get_sha256(full),"bytes":FileAccess.get_file_as_bytes(full).size(),"mtime":FileAccess.get_modified_time(full)}
	for dirname: String in directory.get_directories():
		found.merge(_disk_manifest(path.path_join(dirname)))
	return found

func _open_workshop()->void:
	await _tap(KEY_B);check(app.active_modal,"B opens actual workshop")
	await _choose("剑上配件")
	check(app.overlay.has_meta("weapon_fitting"),"Actual workshop choice opens fitting controller")

func _node_click(node_name: String)->void:
	if failures>0:return
	var button=app.overlay.find_child(node_name,true,false)
	check(button is Button and button.is_visible_in_tree() and not button.disabled,"Live visible enabled fitting control:"+node_name)
	if failures>0:return
	await _click(button);_record_input("mouse:"+node_name)

func _select_candidate(id: String)->void:
	await _node_click("FittingCandidate_"+id)

func _equip_via_ui(id: String)->void:
	if failures>0:return
	var before: Dictionary=app.state.to_dict().duplicate(true)
	await _select_candidate(id)
	await _node_click("FittingAction_revert" if id=="plain" else "FittingAction_equip")
	await _node_click("FittingAction_confirm")
	var expected: Dictionary=before.duplicate(true)
	expected.weapon_fitting=id
	# Explicit normal autosave legitimately synchronizes the live player position.
	expected.position={"x":app.world.player_pos.x,"y":app.world.player_pos.y}
	check(app.state.to_dict()==expected,"Explicit equip changes enum plus declared normal save-position sync only")
	check(app.state.weapon_fitting==id and app.state.attack==before.attack and app.state.defense==before.defense,"Explicit fitting never writes cumulative base stats")
	var projected: Dictionary=app.state.fitting_projection()
	check(projected.ok and projected.attack==app.state.attack+(3 if id=="edge" else (-3 if id=="guard" else 0)) and projected.defense==app.state.defense+(-2 if id=="edge" else (2 if id=="guard" else 0)),"Full stated fitting tradeoff applies once")

func _current_roundtrip(label: String)->void:
	var before: Dictionary=app.state.to_dict().duplicate(true)
	check(int(JSON.parse_string(FileAccess.get_file_as_string(State.SAVE_PATH)).version)==16,"Current explicit save uses writer16")
	if app.active_modal:await _tap(KEY_ESCAPE)
	await _tap(KEY_F9)
	check(app.state.to_dict()==before and app.current_screen=="explore" and not app.active_modal,"Actual F9 retains exact current16 state:"+label)
	check(app.state.fitting_comparison_snapshot().results.is_empty(),"Actual reload clears only session comparison history")
	current16_roundtrips.append({"case":case_id,"label":label,"fitting":app.state.weapon_fitting,"state":before,"save_sha256":FileAccess.get_sha256(State.SAVE_PATH)})

func _start_audit()->void:
	observed_tokens={};observed_transactions=[];auditing_battle=true

func _scene_case(earned)->void:
	root.size=Vector2i(1280,800)
	app=MainScene.instantiate();app.state=earned._detached_persistent_state();app.view_preferences=NoPrefs.new();app.view_preferences.sound_enabled=false
	root.add_child(app);app._stop_audio();app.audio_on=false;app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal()
	_transfer("qingwei",Vector2(460,430),"initial canonical API-earned transfer")
	await _frame(3)
	var start: Dictionary=app.state.to_dict().duplicate(true)
	var start_ticks: int=ticks;var start_inputs: int=input_count;var start_walked: float=walked_pixels
	await _open_workshop()
	var remote_before: Dictionary=app.state.to_dict().duplicate(true);var remote_disk: Dictionary=_disk_manifest()
	await _select_candidate("guard")
	check(app.state.to_dict()==remote_before and _disk_manifest()==remote_disk,"Remote candidate preview equips nothing and writes nothing")
	await _close_readonly()
	await _waypoints([Vector2(480,430),Vector2(480,720),Vector2(721,720)])
	if failures>0:return
	await _open_workshop();await _equip_via_ui("edge");await _equip_via_ui("plain");await _close_readonly()
	await _movement_boundary_preview()
	check(app.state.position!=app.world.player_pos,"Natural held movement creates genuine unsaved position mismatch")
	var plain_baseline: Dictionary=app.state.to_dict().duplicate(true)
	var before_control: Dictionary=_plain_control(app.state,scenario.encounter,case_id+"/plain_before")
	for profile: String in (["ordinary","pressure"] if scenario.full else ["ordinary"]):
		var group: String="";var specs: Array=[]
		for candidate: String in ["plain","edge","guard"]:
			var trial: Dictionary=await _trial(candidate,profile)
			if failures>0:return
			if group.is_empty():group=trial.result.metadata.comparison_key;specs=trial.result.metadata.enemy_specs
			check(trial.result.metadata.comparison_key==group and trial.result.metadata.enemy_specs==specs,"All candidates share identical unfitted-baseline opponents")
	check(app.state.to_dict()==plain_baseline,"All borrowed trials leave exact plain baseline intact")
	var after_control: Dictionary=_plain_control(app.state,scenario.encounter,case_id+"/plain_after")
	_compare_controls(before_control,after_control)
	await _open_workshop();await _equip_via_ui(scenario.fitted);await _current_roundtrip("equipped")
	if failures>0:return
	var prior_progress: Dictionary=app.state.to_dict().duplicate(true)
	if scenario.full:
		_transfer("heting",Vector2(180,350),"declared model travel between two actual-scene physical segments")
		await _frame(3);await _waypoints([Vector2(700,350),Vector2(700,315)])
		await _interact("consignee_warehouse")
		_start_audit();await _choose("保存后阻止强提")
	else:
		await _walk(Vector2(650,720));await _interact("mentor")
		_start_audit();await _choose("开始受试")
	var before_finite: Dictionary=app.state.to_dict().duplicate(true)
	var finite: Dictionary=await _scene_battle(false)
	if failures>0:return
	if scenario.full:
		if finite.outcome=="win":
			check(app.state.consignee_stage==3 and total_xp(app.state)==_dict_total_xp(before_finite) and app.state.coins==before_finite.coins,"Actual fitted finite win secures one lot and pays no XP/coins")
		else:check(app.state.consignee_stage==2 and total_xp(app.state)==_dict_total_xp(before_finite),"Actual fitted loss cannot counterfeit securing the finite lot or earn XP")
		await _tap(KEY_ESCAPE)
	elif finite.outcome=="win" and app.state.sect_trial_won:
		var promotion_before: Dictionary=app.state.to_dict().duplicate(true)
		await _choose("领取内门荐记")
		check(app.state.sect_rank==2 and app.state.defense==int(promotion_before.defense)+1 and app.state.max_qi==int(promotion_before.max_qi)+1 and app.state.sect_merit==int(promotion_before.sect_merit)+3,"Actual promotion earns current base defense/Qi/merit before restore")
		check(app.state.defense==int(prior_progress.defense)+1,"Current earned base differs from preview-era base")
	else:
		check(app.state.sect_rank==1,"Observed failed/unproved exam does not counterfeit earned promotion")
		await _tap(KEY_ESCAPE)
	var progressed: Dictionary=app.state.to_dict().duplicate(true)
	await _open_workshop();await _equip_via_ui("plain")
	var expected: Dictionary=progressed.duplicate(true);expected.weapon_fitting="plain";expected.position={"x":app.world.player_pos.x,"y":app.world.player_pos.y}
	check(app.state.to_dict()==expected and app.state.effective_attack()==app.state.attack and app.state.effective_defense()==app.state.defense,"Restore uses current earned bases without rolling back battle/progression/resources")
	await _current_roundtrip("restored_after_progress")
	scene_cases.append({"case":case_id,"scenario":scenario.duplicate(true),"start":start,"plain_baseline":plain_baseline,"before_finite":before_finite,"finite":finite,"before_restore":progressed,"final":app.state.to_dict(),"fixed_step_seconds":(ticks-start_ticks)/60.0,"walked_pixels":walked_pixels-start_walked,"input_commands":input_count-start_inputs})
	print("FITTING_EARNED_CASE "+case_id+" "+str(finite.get("outcome","missing")))
	app.queue_free();await _frame(3)

func _transfer(region: String, point: Vector2, label: String)->void:
	var before: Dictionary=app.state.to_dict().duplicate(true)
	app.state.map_id=region;app.state.position=point
	app._sync_world_state();app.world.change_map(region,point)
	var expected: Dictionary=before.duplicate(true);expected.map_id=region;expected.position={"x":point.x,"y":point.y}
	check(app.state.to_dict()==expected,"Explicit model location transfer changes no resources or progression")
	transfer_points.append({"case":case_id,"label":label,"before":before,"after":app.state.to_dict(),"position":[point.x,point.y]})

func _movement_boundary_preview()->void:
	# Main ordinarily copies world position before World advances it. Reproduce
	# a real same-frame keyboard opening before the next parent sync, then keep
	# Main processing enabled. No direct State/world position edits are used.
	var start: Vector2=app.world.player_pos
	_hold("move_down")
	for i: int in 10:
		await _frame()
		if app.world.player_pos!=start:break
	_hold("")
	walked_pixels+=start.distance_to(app.world.player_pos)
	check(app.state.position!=app.world.player_pos,"Actual movement boundary exposes ordinary parent/child position lag")
	_record_input("before movement-boundary opening")
	for code: int in [KEY_B,KEY_5]:
		input_count+=1
		var down=InputEventKey.new();down.keycode=code;down.physical_keycode=code;down.pressed=true;Input.parse_input_event(down)
		var up=InputEventKey.new();up.keycode=code;up.physical_keycode=code;up.pressed=false;Input.parse_input_event(up)
		Input.flush_buffered_events() # Deliver genuine pending keyboard events before the next Main process sync.
		_record_input("boundary key "+str(code)+" fitting="+str(app.overlay.has_meta("weapon_fitting"))+" hold="+str(app._fitting_position_hold.get("stored",Vector2.ZERO)))
	await _frame(3)
	check(app.overlay.has_meta("weapon_fitting"),"Actual fast B then fifth keyboard choice opens fitting")
	_record_input("movement-boundary B,5")

func _trial(candidate: String, profile: String)->Dictionary:
	var before: Dictionary=app.state.to_dict().duplicate(true);var position: Vector2=app.world.player_pos;var disk: Dictionary=_disk_manifest()
	if not app.overlay.has_meta("weapon_fitting"):
		await _interact("courtyard_practice");await _choose("借用配件试招")
	await _select_candidate(candidate)
	await _node_click("FittingAction_trial")
	var panel=app.overlay.get_meta("weapon_fitting")
	check(panel.profile=="ordinary","Every fresh trial preparation defaults ordinary")
	if profile=="pressure":await _node_click("FittingAction_pressure")
	_start_audit();await _node_click("FittingAction_start")
	check(app.current_screen=="party_battle" and app.state.battle_active,"Real UI starts current automatic borrowed battle")
	if failures>0:return {}
	var opening: Dictionary=app.state.party_battle_snapshot()
	for actor: Dictionary in opening.actors:check(actor.hp==actor.max_hp and actor.qi==actor.max_qi,"Borrowed full actor resources only")
	check(opening.medicine==3 and opening.encounter_id=="courtyard_practice","Borrowed three medicine retains original practice identity")
	var observed: Dictionary=await _scene_battle(true)
	if failures>0:return {}
	var history: Dictionary=app.state.fitting_comparison_snapshot()
	check(not history.results.is_empty() and history.results.size()<=2,"Only one or two genuine settled comparison results retained")
	if history.results.is_empty():return {}
	var result: Dictionary=history.results[-1]
	check(result.metadata.borrowed_fitting==candidate and result.metadata.installed_fitting=="plain" and result.metadata.profile_id==profile,"Borrowed result correctly names selected versus actual installed fitting")
	check(result.metrics==observed.metrics,"Production result metrics match independently observed accepted tokens")
	check(app.state.to_dict()==before and app.world.player_pos==position and _disk_manifest()==disk,"Borrowed terminal/result changes no real state, saved bytes or either position")
	await _tap(KEY_ESCAPE)
	check(not app.active_modal and app.state.to_dict()==before and app.world.player_pos==position and _disk_manifest()==disk,"Normal result close preserves all real progress, proficiency, resources and disk bytes")
	var row: Dictionary={"case":case_id,"candidate":candidate,"profile":profile,"entry":before,"world_position":[position.x,position.y],"result":result,"observed":observed,"disk":disk,"final":app.state.to_dict(),"final_disk":_disk_manifest()}
	trial_cases.append(row)
	print("FITTING_EARNED_TRIAL "+case_id+"/"+profile+"/"+candidate+" "+str(result.metrics))
	return row

func _scene_battle(trial: bool)->Dictionary:
	check(app.current_screen=="party_battle" and app.state.battle_active,"Actual finite or trial PartyUI entered")
	var panel=app.overlay.get_meta("party_battle",null)
	if panel==null:return {}
	var initial: Dictionary=app.state.party_battle_snapshot()
	var begin: int=ticks
	while app.current_screen=="party_battle" and ticks-begin<60*700:
		if panel._safe_boundary():await _battle_input(panel)
		await _frame()
		if failures>0:break
	_capture_pending();auditing_battle=false
	check(app.current_screen=="explore" and not app.state.battle_active,"Natural PartyUI presentation reaches bounded terminal")
	check(not observed_transactions.is_empty(),"Observer captured genuine accepted transaction tokens")
	if observed_transactions.is_empty():return {}
	var terminal: Dictionary=observed_transactions[-1]
	check(not terminal.after.active,"Observer includes actual terminal accepted transaction")
	if not trial:check(terminal.after.outcome in ["win","defeat"],"Actual fitted finite outcome is genuine and truthfully recorded")
	var metrics: Dictionary=_derive_metrics(initial,observed_transactions)
	return {"outcome":terminal.after.outcome,"initial":initial,"terminal":terminal.after,"metrics":metrics,"transactions":observed_transactions.duplicate(true),"transactions_sha256":JSON.stringify(observed_transactions,"",true).sha256_text(),"fixed_step_seconds":(ticks-begin)/60.0,"settlement":app.state.party_settlement.duplicate(true)}

func _derive_metrics(initial: Dictionary, transactions: Array)->Dictionary:
	var losses: Dictionary={};var total: int=0;var medicine: int=0;var attacks: int=0;var rounds: int=0
	for actor: Dictionary in initial.actors:losses[actor.id]=0
	for tx: Dictionary in transactions:
		for prior: Dictionary in tx.before.actors:
			var current: Dictionary=_actor(tx.after,prior.id)
			var loss: int=maxi(0,int(prior.hp)-int(current.hp));losses[prior.id]+=loss;total+=loss
		medicine+=int(tx.before.medicine)-int(tx.after.medicine)
		for event: Dictionary in tx.events:
			if event.type=="action" and event.get("action_id")=="enemy:attack":attacks+=1
			if event.type=="round_end":rounds+=1
	var final: Dictionary=transactions[-1].after;var remaining: Dictionary={}
	for actor: Dictionary in final.actors:remaining[actor.id]={"hp":actor.hp,"qi":actor.qi}
	return {"actual_hp_lost_by_actor":losses,"total_actual_hp_lost":total,"medicine_used":medicine,"enemy_attacks_executed":attacks,"completed_rounds":rounds,"accepted_transactions":transactions.size(),"outcome":final.outcome,"terminal_round":final.round,"remaining_resources":{"actors":remaining,"medicine":final.medicine,"medicine_heal":final.medicine_heal}}

func _battle_input(panel)->void:
	var view: Dictionary=app.state.party_battle_snapshot()
	var target_id: String=_target(view)
	if not target_id.is_empty() and view.selected_target_id!=target_id:
		await _click(panel.unit_plates[target_id]);return
	for actor: Dictionary in view.actors:
		if actor.hp<=0 or actor.basic_done:continue
		var budget: int=actor.qi;var incoming: Dictionary=_incoming(view,actor.id)
		for action: Dictionary in actor.actions:
			if action.queued:budget-=int(action.cost)
		for action: Dictionary in actor.actions:
			if not Rules.CATEGORIES.has(String(action.category)) or not action.available or action.queued or budget<int(action.cost):continue
			var target: String=actor.id if action.target_team=="self" else target_id
			if action.target_team=="ally":
				var need: int=0
				for ally: Dictionary in view.actors:
					var measure: int=int(ally.max_hp)-int(ally.hp) if int(action.effects.get("healing",0))>0 else int(_incoming(view,ally.id).damage)
					if ally.hp>0 and measure>need:need=measure;target=ally.id
				if need<mini(20,int(action.effects.get("healing",1))):continue
			if bool(action.effects.get("guard",false)) and not incoming.heavy and int(actor.status.get("vulnerability_hits",0))==0:continue
			if action.category=="martial" and int(action.effects.get("healing",0))>0 and actor.hp==actor.max_hp:continue
			if action.category=="internal" and actor.max_hp-actor.hp<int(action.effects.get("healing",0)) and int(action.effects.get("focus_bonus",0))<=int(actor.status.focused_damage):continue
			if action.category=="lightness" and int(incoming.damage)==0:continue
			var key: String=panel.commands.slot_key(actor.id,action.category)
			check(panel.commands.buttons.has(key),"Visible real skill control exists:"+key)
			if failures>0:return
			await _click(panel.commands.buttons[key])
			if not panel.pending_action.is_empty():await _click(panel.unit_plates[target])
			return
	for actor: Dictionary in view.actors:
		if actor.hp<=0:continue
		for action: Dictionary in actor.actions:
			if action.id=="item" and action.available and (actor.hp<=_incoming(view,actor.id).damage or actor.hp*100<actor.max_hp*35):
				if view.selected_actor_id!=actor.id:await _click(panel.commands.actor_buttons[actor.id])
				await _tap(KEY_4);return

func _write_report(done: bool)->void:
	var report: Dictionary={"checks":checks,"failures":failures,"failure_labels":failure_labels,"completed":done,"selected_case":selected_case,"scope":scope_text,"scene_cases":scene_cases,"trial_cases":trial_cases,"control_pairs":control_pairs,"api_fights":api_fights,"api_operations":operations,"transfers":transfer_points,"earned_boundary_artifacts":earned_boundary_artifacts,"input_trace":input_trace,"migrations":migrations,"current16_roundtrips":current16_roundtrips,"wall_seconds":(Time.get_ticks_msec()-started_ms)/1000.0,"fixed_step_ticks":ticks,"input_commands":input_count,"walked_pixels":walked_pixels,"source_sha256":_source_hashes()}
	var file=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()

func _source_hashes()->Dictionary:
	var result: Dictionary={}
	for path: String in ["res://tests/weapon_fitting_earned_driver.gd","res://tests/weapon_fitting_earned_scene_test.gd","res://scripts/main.gd","res://scripts/game_state.gd","res://scripts/weapon_fitting_ui.gd","res://scripts/weapon_fitting_trial_rules.gd","res://scripts/party_battle_ui.gd","res://scripts/automatic_party_combat.gd","res://scripts/workshop_ui.gd","res://scripts/pause_menu.gd"]:
		result[path]=FileAccess.get_sha256(path)
	return result

func _finish()->void:
	_hold("");auditing_battle=false
	var expected_cases: int=4 if selected_case.is_empty() else 1
	var expected_trials: int=15 if selected_case.is_empty() else (6 if selected_case=="later_full_party" else 3)
	check(scene_cases.size()==expected_cases,"All requested earned scene cases completed")
	check(trial_cases.size()==expected_trials,"Exact bounded borrowed trial count completed")
	check(control_pairs.size()==expected_cases,"Exact four pairs/eight plain control fights completed")
	check(current16_roundtrips.size()==expected_cases*2,"Two current16 roundtrips per earned boundary")
	_write_report(true)
	print("%s FITTING_EARNED checks=%d failures=%d cases=%d trials=%d controls=%d"%["PASS" if failures==0 else "FAIL",checks,failures,scene_cases.size(),trial_cases.size(),control_pairs.size()*2])
	if is_instance_valid(app):app.queue_free()
	quit(0 if failures==0 else 1)
