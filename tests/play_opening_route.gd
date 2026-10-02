extends SceneTree
## Native graphical smoke play. Uses normal movement, quest choices and combat values.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
var source_commit=OS.get_environment("HERO_QA_SOURCE_COMMIT")
const ACTIONS=["move_right","move_left","move_down","move_up"]
var app
var failures:Array[String]=[]
var trace:Array=[]
var distance_walked=0.0
var start_ms=0
func _initialize()->void:run.call_deferred()
func verify(ok:bool,message:String)->bool:
	if not ok:failures.append(message);push_error(message)
	return ok
func record(label:String)->void:
	trace.append({"step":label,"seconds":(Time.get_ticks_msec()-start_ms)/1000.0,"position":[app.world.player_pos.x,app.world.player_pos.y],"quest_stage":app.state.quest_stage,"hp":app.state.hp,"qi":app.state.qi,"medicine":app.state.medicine,"coins":app.state.coins,"level":app.state.level,"xp":app.state.xp,"attack":app.state.attack,"defense":app.state.defense,"battle_turn":app.state.turn,"enemy_hp":app.state.enemy_hp,"enemy_max_hp":app.state.enemy_max_hp,"companion":app.state.current_companion()})
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func stop_movement()->void:
	for action in ACTIONS:Input.action_release(action)
func walk(points:Array)->bool:
	for target:Vector2 in points:
		var deadline=Time.get_ticks_msec()+20000
		while app.world.player_pos.distance_to(target)>12:
			if Time.get_ticks_msec()>deadline or app.active_modal or app.current_screen!="explore":
				stop_movement();return verify(false,"Walking blocked near "+str(app.world.player_pos)+" toward "+str(target))
			var offset:Vector2=target-app.world.player_pos
			var desired=[offset.x>6,offset.x< -6,offset.y>6,offset.y< -6]
			for i in range(4):
				if desired[i]:Input.action_press(ACTIONS[i])
				else:Input.action_release(ACTIONS[i])
			var before:Vector2=app.world.player_pos;await process_frame;distance_walked+=before.distance_to(app.world.player_pos)
		stop_movement();await process_frame;record("walk "+str(target))
	return true
func capture(name:String)->void:
	await create_timer(.25).timeout;await RenderingServer.frame_post_draw
	verify(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK,"Save route screenshot "+name)
func talk(id:String,choice:int=1)->bool:
	if not verify(app.world.nearby_id==id,"Expected nearby interaction "+id+", got "+app.world.nearby_id):return false
	await key(KEY_E)
	if not verify(app.active_modal,"Interaction opens "+id):return false
	await key(KEY_1+choice-1);return true
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Use a native graphical engine for this route");quit(2);return
	var profile=OS.get_environment("XDG_DATA_HOME").simplify_path()
	var user_path=ProjectSettings.globalize_path("user://").simplify_path()
	if not profile.is_absolute_path() or not profile.get_file().ends_with("-route-data") or not user_path.begins_with(profile+"/"):
		push_error("Use a fresh isolated XDG_DATA_HOME ending in -route-data");quit(2);return
	if FileAccess.file_exists(Model.SAVE_PATH):push_error("Use a fresh isolated profile; existing route save will not be overwritten");quit(2);return
	start_ms=Time.get_ticks_msec();root.size=Vector2i(1280,800)
	var prefs=Prefs.new();prefs.sound_enabled=false;verify(prefs.save_settings()==OK,"Save muted isolated route preference")
	app=Scene.instantiate();root.add_child(app);await process_frame;await key(KEY_ENTER);await key(KEY_EQUAL)
	if not verify(app.current_screen=="explore" and app.state.quest_stage==0,"Fresh title starts ordinary new game"):await finish();return
	record("fresh start")
	if not await talk("elder"):await finish();return
	if not verify(app.state.quest_stage==1,"Accept opening quest"):await finish();return
	if not await walk([Vector2(620,380),Vector2(780,380),Vector2(900,320),Vector2(1100,320),Vector2(1240,370)]):await finish();return
	if not await talk("herb"):await finish();return
	if not verify(app.state.quest_stage==2 and app.state.herbs==1,"Gather exactly one quest herb"):await finish();return
	record("gathered herb");await capture("216-opening-route-herb")
	if not await walk([Vector2(1100,320),Vector2(900,320),Vector2(780,380),Vector2(500,380),Vector2(350,345)]):await finish();return
	if not await talk("healer"):await finish();return
	if not verify(app.state.quest_stage==3 and app.state.herbs==0,"Deliver herb and obtain ferry lead"):await finish();return
	if not await talk("healer"):await finish();return
	if not verify(app.state.current_companion()=="沈青","Recruit Shen through the actual invitation"):await finish();return
	record("Shen joined")
	if not await walk([Vector2(500,380),Vector2(780,480),Vector2(800,560),Vector2(850,660),Vector2(1080,660),Vector2(1240,755)]):await finish();return
	if not await talk("bandit"):await finish();return
	if not verify(app.state.battle_active and app.battle_presentation_enabled,"Enter ordinary animated story encounter"):await finish();return
	record("duel entered");await capture("217-opening-route-first-duel")
	for step in range(24):
		if not app.state.battle_active:break
		var action=KEY_1
		if app.state.hp<app.state.max_hp*.45 and app.state.medicine>0:action=KEY_4
		elif app.state.turn%2==1:action=KEY_3
		elif app.state.qi>=app.state.active_art_cost() and app.state.skill_cooldown==0:action=KEY_2
		await key(action)
		var deadline=Time.get_ticks_msec()+12000
		while app.battle_busy and Time.get_ticks_msec()<deadline:await process_frame
		if not verify(not app.battle_busy,"Accepted combat animation completes"):await finish();return
		record("combat key "+str(action-KEY_1+1))
	if not verify(not app.state.battle_active and app.state.quest_stage==4,"Win opening duel using normal stats and items"):await finish();return
	await key(KEY_ENTER)
	if not await walk([Vector2(1080,660),Vector2(850,660),Vector2(840,560),Vector2(780,480),Vector2(565,480)]):await finish();return
	if not await talk("elder",2):await finish();return
	if not verify(app.active_modal and app.state.quest_stage==5,"Choose ferrymen evidence ending"):await finish();return
	await key(KEY_1)
	if not verify(app.state.quest_stage==6 and app.state.sect=="听潮阁" and app.state.ending=="守望","Complete opening chapter and choose school through dialogue"):await finish();return
	record("chapter complete");await capture("218-opening-route-chapter-complete")
	await key(KEY_F5)
	var coins:int=app.state.coins;var position:Vector2=app.world.player_pos
	await key(KEY_F9)
	verify(app.state.quest_stage==6 and app.state.sect=="听潮阁" and app.state.coins==coins and app.state.current_companion()=="沈青" and app.world.player_pos.distance_to(position)<.01,"Actual save and reload retain completed chapter, party and position")
	record("saved and reloaded");await finish()
func finish()->void:
	stop_movement()
	var report={"source_commit":source_commit if not source_commit.is_empty() else "unrecorded", "driver_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"Scripted native source runtime, fresh ordinary character, normal movement/collision and UI inputs, unmodified rewards/health/combat, no teleports or fixed-step movie; not manual play or an exported binary","utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"audio_driver":AudioServer.get_driver_name(),"seconds":(Time.get_ticks_msec()-start_ms)/1000.0,"distance_walked":distance_walked,"trace":trace,"failures":failures,"save_sha256":FileAccess.get_sha256(Model.SAVE_PATH)}
	var file=FileAccess.open("res://tests/native_opening_route.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: native opening route completed with normal play values" if failures.is_empty() else "FAIL: native opening route; inspect native_opening_route.json")
	quit(0 if failures.is_empty() else 1)
