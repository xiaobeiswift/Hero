extends "res://tests/heting_consignee_balance_test.gd"
## Independent integration proof: API-earned predecessors, actual new scene input.
const MainScene = preload("res://scenes/main.tscn")
const Prefs = preload("res://scripts/view_preferences.gd")
const Harbor = preload("res://scripts/heting_region.gd")
const OUT = "user://consignee-independent"
class ProbeState extends State:
	var writes: int = 0
	var fail_save: bool = false
	func save_game(_path: String = SAVE_PATH) -> Error:
		writes += 1
		if fail_save: return ERR_CANT_CREATE
		return super.save_game((OUT + "/%d" % OS.get_process_id()) + "/isolated-autosave.json")
	func has_save() -> bool: return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
var evidence: Array = []
var results_scene: Array = []
var ticks: int = 0
var moved_distance: float = 0
var held: String = ""
var real_started: int = 0
var current_case: String = ""
var earned_school: String = "听潮阁"
var last_command_signature: String = ""
var scene_failure_labels: Array = []

func check(value: bool, label: String) -> void:
	super.check(value,label)
	if not value: scene_failure_labels.append(label)

func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(OUT + "/%d" % OS.get_process_id()) != OK:
		push_error("Cannot create isolated independent evidence directory"); quit(2); return
	real_started = Time.get_ticks_msec()
	minimal_build = true
	var earned = _earn_predecessors()
	if failures > 0: _finish(); return
	for scenario: Dictionary in [{"harbor":"short_ferries","plan":"hold_for_inspection","bridge":"west"},{"harbor":"open_scale","plan":"return_to_owner","bridge":"east"}]:
		var s = earned._detached_persistent_state()
		check(s.choose_heting_plan(scenario.harbor) and s.take_heting_cargo("reserve") and s.finish_heting_delivery("heting_relief" if scenario.harbor=="short_ferries" else "heting_scale",scenario.harbor),"Earn requested old ending through original API")
		s.heal_rest()
		check(s.receipt_stage==0 and s.party_roster==["hero"] and not s.companion_unlocked and not s.tangqi_unlocked and not s.qin_unlocked,"Minimum solo skips all optional recruits and receipt")
		current_case = scenario.plan
		await _scene_case(s,scenario)
		if failures > 0: break
	_finish()

func _earn_predecessors():
	var s = _opening(false)
	if not _journey_win(s,"story","scene_predecessor_opening"):return s
	_finish_opening(s);_school(s,earned_school)
	check(s.choose_side_route("rescue") and s.find_side_clue("boatman"),"Earn rescue")
	s.heal_rest()
	if not _journey_win(s,"sluice_scout","scene_predecessor_scout"):return s
	s.heal_rest()
	if not _journey_win(s,"sluice_boss","scene_predecessor_sluice"):return s
	check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"),"Earn archive clues")
	for seal:int in [2,0,1]:check(s.try_seal(seal).valid,"Earn seal")
	s.heal_rest()
	if not _journey_win(s,"archive_boss","scene_predecessor_archive"):return s
	check(s.resolve_chapter_two("open_records") and s.begin_mistwood(),"Earn archive ending and Mistwood")
	s.map_id="mistwood"
	check(s.record_mist_gauge("rain") and s.record_mist_gauge("basin") and s.obtain_mist_access("records") and s.record_mist_gauge("stone"),"Earn nongrind records path")
	s.heal_rest()
	if not _journey_win(s,"mist_keeper","scene_predecessor_keeper"):return s
	check(s.resolve_mistwood("release_water") and s.begin_heting(),"Earn Mistwood and harbor")
	s.map_id="heting"
	check(s.take_heting_cargo("meal") and s.deliver_heting_base("heting_relief"),"Earn first harbor handover")
	check(s.take_heting_cargo("sealed") and s.deliver_heting_base("heting_scale"),"Earn second harbor handover")
	return s

func _frame(count:int=1)->void:
	for i:int in range(count):
		await process_frame
		ticks+=1
func _tap(code:int)->void:
	var press=InputEventKey.new();press.keycode=code;press.physical_keycode=code;press.pressed=true
	Input.parse_input_event(press)
	await _frame()
	var release=InputEventKey.new();release.keycode=code;release.physical_keycode=code;release.pressed=false
	Input.parse_input_event(release)
	await _frame(2)
func _hold(next:String)->void:
	if held==next:return
	if not held.is_empty():Input.action_release(held)
	held=next
	if not held.is_empty():Input.action_press(held)
func _walk(to:Vector2)->void:
	check(not app.active_modal and app.current_screen=="explore","Movement begins outside modal")
	for i:int in range(5000):
		var p:Vector2=app.world.player_pos
		var delta:Vector2=to-p
		if absf(delta.x)<=3 and absf(delta.y)<=3:
			_hold("");await _frame(2);_record_scene("walk");return
		_hold(("move_right" if delta.x>0 else "move_left") if absf(delta.x)>3 else ("move_down" if delta.y>0 else "move_up"))
		await _frame()
		moved_distance+=p.distance_to(app.world.player_pos)
		check(app.world._can_walk(app.world.player_pos),"Actual character always stays on live walkable topology")
		if failures>0:break
	_hold("");check(false,"Route stuck toward %s at %s"%[to,app.world.player_pos])
func _record_scene(what:String)->void:
	var s=app.state
	evidence.append({"case":current_case,"what":what,"ticks":ticks,"pos":[app.world.player_pos.x,app.world.player_pos.y],"nearby":app.world.nearby_id,"stage":s.consignee_stage,"clues":s.consignee_observations.duplicate(),"plan":s.consignee_draft,"cargo":s.consignee_cargo_location,"bridge":s.heting_bridge,"writes":s.writes})
func _interact(site:String)->void:
	check(app.world.nearby_id==site,"Actual nearby E site:"+site)
	await _tap(KEY_E)
	check(app.active_modal,"E opens real main-scene dialog:"+site)
	_record_scene("E:"+site)
func _buttons()->Array:
	var found:Array=[]
	for i:int in range(1,6):
		var b=app.overlay.find_child("DialogueChoice"+str(i),true,false)
		if b!=null:found.append(b)
	return found
func _choose(fragment:String,mouse:bool=false)->void:
	var buttons:Array=_buttons()
	for i:int in range(buttons.size()):
		var b=buttons[i]
		if String(b.text).contains(fragment):
			check(b.get_global_rect().has_area() and root.get_visible_rect().encloses(b.get_global_rect()),"Choice fully inside real logical viewport:"+fragment)
			if mouse:
				var center:Vector2=b.get_global_rect().get_center()
				var motion=InputEventMouseMotion.new();motion.position=center;motion.global_position=center;Input.parse_input_event(motion);await _frame()
				var down=InputEventMouseButton.new();down.position=center;down.global_position=center;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await _frame()
				var up=InputEventMouseButton.new();up.position=center;up.global_position=center;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up);await _frame(3)
			else:await _tap(KEY_1+i)
			_record_scene(("mouse:" if mouse else "number:")+fragment)
			return
	check(false,"Missing real dialogue choice:"+fragment+" available="+str(buttons.map(func(b):return b.text)))
func _close_readonly()->void:
	var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
	await _tap(KEY_ESCAPE)
	check(not app.active_modal and app.state.to_dict()==before and app.state.writes==writes,"Escape on inspection never changes state or writes")

func _scene_case(earned,scenario:Dictionary)->void:
	root.size=Vector2i(1280,800)
	app=MainScene.instantiate();app.state=ProbeState.new();app.state._copy_persistent_from(earned);app.view_preferences=NoPrefs.new();root.add_child(app)
	app._stop_audio();app.audio_on=false;app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal();app._sync_world_state();app.world.change_map("heting",Vector2(180,350));await _frame(3)
	var start_tick:int=ticks;var start_distance:float=moved_distance
	var start:Dictionary=app.state.to_dict().duplicate(true)
	await _walk(Vector2(535,350));await _interact("heting_dispatch");await _choose("问北仓");await _close_readonly()
	await _interact("heting_dispatch");await _choose("问北仓")
	# One accepted mutation intentionally fails its first isolated save. Retry only persists.
	app.state.fail_save=true;await _choose("接下本批")
	check(app.state.consignee_stage==1 and app.save_warning,"Accepted begin remains truthful after save failure")
	app.state.fail_save=false;await _choose("重试保存")
	check(not app.save_warning and app.state.consignee_stage==1,"Retry persists accepted begin without repeating")
	await _choose("亲自核验",true)
	check(app.state.consignee_observations==["removal_order"],"First actual physical clue earned by mouse")
	await _close_readonly()
	for hotkey:int in [KEY_M,KEY_J]:
		var passive_before:Dictionary=app.state.to_dict().duplicate(true);var passive_writes:int=app.state.writes
		await _tap(hotkey);await _close_readonly()
		check(app.state.to_dict()==passive_before and app.state.writes==passive_writes,"Map/journal full inspection and Escape remain read-only")
	await _walk(Vector2(805,350));await _walk(Vector2(805,620));await _walk(Vector2(970,620));await _walk(Vector2(970,780));await _interact("heting_lighter");await _choose("核验南联");await _choose("亲自核验");await _close_readonly()
	if scenario.bridge=="west":
		await _walk(Vector2(820,780));await _walk(Vector2(820,735));await _interact("heting_winch");await _choose("改接西岸")
	await _walk(Vector2(805,620));await _walk(Vector2(805,350));await _walk(Vector2(700,350));await _walk(Vector2(700,315));await _interact("consignee_warehouse");await _choose("亲自核验")
	check(app.state.consignee_observations==["removal_order","southern_counterfoil","lot_seals"],"All clues physically earned in noncanonical order")
	await _choose("核对三处矛盾")
	var wrong_before:Dictionary=app.state.to_dict().duplicate(true);var wrong_writes:int=app.state.writes
	await _choose("两篓干粮")
	check(app.state.to_dict()==wrong_before and app.state.writes==wrong_writes,"Wrong deduction gives explanation without costs, lost clues or saves")
	await _choose("重新核对");await _choose("未验先撤");await _choose("拟作封粮留验")
	if scenario.plan=="return_to_owner":await _choose("更改本批草案");await _choose("拟作撤运还粮")
	check(app.state.consignee_stage==2 and app.state.consignee_draft==scenario.plan,"Draft is reversible before real battle")
	var combat_before:Dictionary=app.state.to_dict().duplicate(true)
	await _choose("保存后阻止强提")
	check(app.current_screen=="party_battle" and app.state.battle_active,"Main-scene choice enters actual current PartyUI")
	check(app.state.hp==combat_before.hp and app.state.qi==combat_before.qi and app.state.medicine==combat_before.medicine,"No entry heal or resource injection")
	var panel=app.overlay.get_meta("party_battle")
	var opening:Dictionary=app.state.party_battle_snapshot()
	check(opening.enemies.size()==2 and opening.enemies[0].max_hp==260 and opening.enemies[1].max_hp==160,"Scene presents both fixed durable named enemies")
	var fight_ticks:int=ticks
	while app.current_screen=="party_battle" and ticks-fight_ticks<60*700:
		if panel._safe_boundary():_scene_plan(panel)
		await _frame()
	check(app.current_screen=="explore" and app.state.consignee_stage==3,"Natural solo real scene combat wins and only secures grain")
	check(app.state.coins==combat_before.coins and _earned_xp(app.state)==_dict_xp(combat_before),"Actual victory awards no XP or coins")
	var fight_frames:int=ticks-fight_ticks
	if failures>0:return
	await _choose("查看北仓这一车");await _choose("押本批两篓");await _choose("继续押送")
	check(app.state.consignee_stage==4 and app.world.heting_cart_loaded(),"Exactly one new cart uses real loaded geometry")
	await _walk(Vector2(700,350));await _walk(Vector2(150,350));await _interact("return_mistwood");await _close_readonly()
	await _interact("return_mistwood");await _choose("停回北仓后离开")
	check(app.state.map_id=="mistwood" and app.state.consignee_stage==3 and app.state.consignee_cargo_location=="warehouse","Explicit park-and-leave keeps same batch")
	await _interact("exit_heting");await _choose("返回鹤汀埠")
	await _walk(Vector2(700,350));await _walk(Vector2(700,315));await _interact("consignee_warehouse");await _choose("押本批两篓");await _choose("继续押送")
	await _walk(Vector2(805,315));await _walk(Vector2(805,425))
	_hold("move_down");await _frame(80);_hold("")
	check(app.world.player_pos.y<450 and app.world.heting_cart_loaded(),"Real held movement cannot drive loaded cart down foot pier")
	await _walk(Vector2(805,350))
	if scenario.bridge=="west":
		await _walk(Vector2(330,350));await _walk(Vector2(330,728));await _walk(Vector2(820,728));await _interact("heting_winch");await _choose("改接东岸")
		check(app.state.heting_bridge=="east" and app.world.heting_cart_loaded(),"Loaded original lot survives live west-to-east winch change")
		await _walk(Vector2(1530,728));await _walk(Vector2(1530,600));await _walk(Vector2(1390,600));await _interact("heting_scale");await _choose("交接本批封粮")
	else:
		await _walk(Vector2(1530,350));await _walk(Vector2(1530,728));await _walk(Vector2(665,728));await _walk(Vector2(665,620));await _interact("heting_cargo");await _choose("交接本批封粮")
	var before_final:Dictionary=app.state.to_dict().duplicate(true);var writes_final:int=app.state.writes
	await _choose("先留在车上")
	check(app.state.to_dict()==before_final and app.state.writes==writes_final,"Final cancellation neither saves nor delivers nor awards")
	var receiver:String="heting_scale" if scenario.plan=="hold_for_inspection" else "heting_cargo"
	await _interact(receiver);await _choose("交接本批封粮")
	var stale:Callable=app.modal_actions[0]
	await _choose("确认交下本批",true)
	check(app.state.consignee_stage==5 and app.state.consignee_ending==scenario.plan,"Mouse final confirmation fixes requested ending")
	check(app.state.coins==int(before_final.coins)+60 and _earned_xp(app.state)==_dict_xp(before_final)+120,"Final handover pays exact equal120XP60coins")
	var after:Dictionary=app.state.to_dict().duplicate(true);var after_writes:int=app.state.writes;stale.call()
	check(app.state.to_dict()==after and app.state.writes==after_writes,"Stale final callback cannot duplicate reward or saves")
	check(app.state.heting_ending==scenario.harbor and app.state.receipt_stage==0,"Both old ending and optional unstarted receipt retained")
	var loaded=State.new();check(loaded.load_game((OUT + "/%d" % OS.get_process_id())+"/isolated-autosave.json")==OK and loaded.to_dict()==app.state.to_dict(),"Actual isolated autosave roundtrips final current schema")
	var v:Dictionary=Harbor.consignee_visual_state(true,5,app.state.consignee_cargo_location,scenario.plan)
	check(v.cart_full==0 and v.warehouse_full==0 and (v.scale_full==2 if scenario.plan=="hold_for_inspection" else v.boat_empty==2),"Persistent visual state conserves one final batch")
	results_scene.append({"scenario":scenario,"start":start,"final":after,"fixed_step_seconds":(ticks-start_tick)/60.0,"combat_fixed_step_seconds":fight_frames/60.0,"walked_pixels":moved_distance-start_distance,"visual":v})
	print("SCENE_CASE "+JSON.stringify(results_scene[-1]))
	app.queue_free();await _frame(3)

func _earned_xp(s)->int:return s.xp+30*s.level*(s.level-1)
func _dict_xp(d:Dictionary)->int:return int(d.xp)+30*int(d.level)*(int(d.level)-1)
func _scene_plan(panel)->void:
	# Choose only current published actions via the real UI adapter; never finish
	# tokens, change resources, call model.advance, or modify stats.
	var view:Dictionary=app.state.party_battle_snapshot()
	panel.select_target(_target(view))
	for actor:Dictionary in view.actors:
		if actor.hp<=0 or actor.basic_done:continue
		var budget:int=actor.qi
		for action:Dictionary in actor.actions:
			if action.queued:budget-=int(action.cost)
		for action:Dictionary in actor.actions:
			if not Rules.CATEGORIES.has(String(action.category)) or not action.available or action.queued or budget<int(action.cost):continue
			var incoming:Dictionary=_incoming(view,actor.id)
			if bool(action.effects.get("guard",false)) and not incoming.heavy:continue
			if action.category=="internal" and actor.max_hp-actor.hp<int(action.effects.get("healing",0)):continue
			if action.category=="lightness" and incoming.damage==0:continue
			panel.request_command(actor.id,action.id)
			if not panel.pending_action.is_empty():
				var chosen:String=String(panel.target_ids[0])
				var largest:int=-1
				for ally:Dictionary in view.actors:
					if panel.target_ids.has(ally.id) and int(ally.max_hp)-int(ally.hp)>largest:
						largest=int(ally.max_hp)-int(ally.hp);chosen=ally.id
				panel.select_target(chosen)
			budget-=int(action.cost)
	for actor:Dictionary in view.actors:
		if actor.hp<=0:continue
		for action:Dictionary in actor.actions:
			if action.id=="item" and action.available and (actor.hp<=_incoming(view,actor.id).damage or actor.hp*100<actor.max_hp*35):panel.request_command(actor.id,"item");return

func _finish()->void:
	_hold("")
	var report={"checks":checks,"failures":failures,"failure_labels":scene_failure_labels,"scope":"Predecessors earned through production State/current automatic combat APIs, explicit original opening dialog effects. New chapter uses real main scene, held movement, E, numbered choices, injected mouse events and real automatic PartyUI presentation/settlement. Fixed60Hz headless; no manual/realtime/browser/duration20-40minute claim. No inflated stats; no user saves touched.","wall_seconds":(Time.get_ticks_msec()-real_started)/1000.0,"ticks":ticks,"api_journey":journey,"scene_results":results_scene,"trace":evidence}
	var f=FileAccess.open((OUT + "/%d" % OS.get_process_id())+"/earned_scene_journey.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("%s independent earned scene: %d checks, %d failures, %d outcomes"%["PASS" if failures==0 else "FAIL",checks,failures,results_scene.size()])
	if is_instance_valid(app):app.queue_free()
	await process_frame
	quit(0 if failures==0 and results_scene.size()==2 else 1)
