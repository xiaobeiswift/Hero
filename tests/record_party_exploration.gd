extends "res://tests/unified_combat_ui_test.gd"
## Prepared full-game state; actual Input actions and real world fixed-step processing.
## Never writes follower positions or frame caches. Silent engine rendering, not FPS evidence.
const STEP_TIME := 1.0 / 30.0
const ACTORS := ["hero", "shen", "tang", "qin"]
const ACTIONS := ["move_right", "move_down", "move_left", "move_up"]
const HEADINGS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const ORIGINS := [Vector2(430,430),Vector2(520,330),Vector2(760,430),Vector2(520,550)]
var evidence_dir := ""
var source_manifest := ""
var source_identity := ""
var capture_mode := "stills"
var trace: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var runtime_hashes: Dictionary = {}
var step_number := 0
var held_actions: Array[String] = []
var qin_keys: Dictionary = {}
var source_resources: Dictionary = {}

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): evidence_dir=argument.trim_prefix("--out=")
		if argument.begins_with("--manifest="): source_manifest=argument.trim_prefix("--manifest=")
		if argument.begins_with("--source="): source_identity=argument.trim_prefix("--source=")
		if argument.begins_with("--mode="): capture_mode=argument.trim_prefix("--mode=")
	if evidence_dir.is_empty() or source_manifest.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Explicit isolated paths and source identity required"); quit(2); return
	runtime_hashes=JSON.parse_string(FileAccess.get_file_as_string(source_manifest))
	_verify_source()
	DirAccess.make_dir_recursive_absolute(evidence_dir+"/screenshots")
	fixture="user://party-walk-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame
	app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	_setup("heting_receipt",4);s.learn_lightness()
	root.size=Vector2i(1280,800)
	for action: String in ACTIONS:
		if not InputMap.has_action(action):InputMap.add_action(action)
	await process_frame
	check(app.world.follower_ids()==["shen","tang","qin"],"Real main sync uses the selected deployed roster")
	source_resources=s.party_resource_snapshot().duplicate(true)
	if capture_mode.ends_with("movie"):await _movie()
	else:await _stills()
	_hold([])
	check(s.party_resource_snapshot()==source_resources,"Exploration playback does not change health, Qi or party resources")
	_verify_source()
	var result={"scope":"Prepared completed-story full-game state with actual recruitment/roster selection, real Input actions and world._process(1/30); native fixed-step silent rendering. Teleports/map changes are explicit scene setup or safe reseed checks. No manual play, browser, audio or realtime FPS claim.","source_identity":source_identity,"mode":capture_mode,"fixed_step_seconds":STEP_TIME,"steps":step_number,"checks":checks,"failures":failures,"captured":captures,"qin_keys":qin_keys,"runtime_sha256":runtime_hashes,"trace":trace}
	var out=FileAccess.open(evidence_dir+"/"+capture_mode+"-trace.json",FileAccess.WRITE)
	check(out!=null,"Trace destination opens")
	if out!=null:out.store_string(JSON.stringify(result,"\t"));out.close()
	print("%s: party exploration %s; %d checks, %d fixed steps, %d capture records (native only outside headless validation)"%["PASS" if failures==0 else "FAIL",capture_mode,checks,step_number,captures.size()])
	app._stop_audio();app.queue_free();await process_frame
	quit(0 if failures==0 else 1)

func _verify_source() -> void:
	for path: String in runtime_hashes:
		check(FileAccess.get_sha256("res://"+path)==runtime_hashes[path],"Exact source resource: "+path)

func _hold(actions: Array) -> void:
	for action: String in ACTIONS:Input.action_release(action)
	held_actions.clear()
	for action: String in actions:Input.action_press(action);held_actions.append(action)

func _relocate(map: String, origin: Vector2, heading: Vector2=Vector2.RIGHT) -> void:
	_hold([])
	s.map_id=map;s.position=origin
	app._sync_world_state()
	app.world.facing=heading
	app.world.change_map(map,origin)
	app.world.camera_pos=app.world._camera_target()
	app._process(0);app._refresh()
	check(app.world.player_pos.distance_to(origin)<0.01,"Prepared hero origin is legal: "+map)
	_record("explicit_scene_setup",false)

func _frame(label: String) -> void:
	var previous: Dictionary={}
	for id: String in app.world.follower_ids():previous[id]=app.world.follower_view(id).position
	app._process(0)
	app.world._process(STEP_TIME)
	app._process(STEP_TIME)
	step_number+=1
	for id: String in app.world.follower_ids():
		var actor: Dictionary=app.world.follower_view(id)
		check(app.world._follower_can_step(previous[id],actor.position),label+" swept legal actual follower "+id)
		check(actor.moving==(actor.position.distance_to(previous[id])>0.0001),label+" movement flag follows accepted position "+id)
	_record(label,true)
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw

func _walk(actions: Array, frames: int, label: String) -> void:
	_hold(actions)
	for _i in range(frames):await _frame(label)
	_hold([])

func _record(label: String, walking: bool) -> void:
	var rows: Array=[]
	rows.append({"id":"hero","position":[app.world.player_pos.x,app.world.player_pos.y],"facing":[app.world.facing.x,app.world.facing.y],"moving":app.world.moving,"phase":app.world.walk_time})
	for id: String in app.world.follower_ids():
		var actor: Dictionary=app.world.follower_view(id)
		check(app.world._follower_can_walk(actor.position),label+" legal actor "+id)
		var key:int=posmod(floori(actor.walk_phase*4.0/TAU),4) if actor.moving else 0
		rows.append({"id":id,"position":[actor.position.x,actor.position.y],"facing":[actor.facing.x,actor.facing.y],"moving":actor.moving,"phase":actor.walk_phase,"walk_distance":actor.walk_distance,"qin_authored_key":key if id=="qin" else -1})
		if id=="qin" and walking and actor.moving:
			var direction:String=app.world.QinWalk.direction_for(actor.facing)
			if not qin_keys.has(direction):qin_keys[direction]=[]
			if not qin_keys[direction].has(key):qin_keys[direction].append(key)
	trace.append({"step":step_number,"label":label,"input":held_actions.duplicate(),"map":app.world.map_id,"roster":s.party_roster.duplicate(),"actors":rows,"reseed_count":app.world._follower_reseed_count,"recovery_reason":app.world.follower_recovery_reason})

func _capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name()=="headless":
		captures.append({"name":name,"native_rendered":false,"step":step_number,"state":trace.back()})
		return
	await RenderingServer.frame_post_draw
	var pixels: Image=root.get_texture().get_image()
	check(pixels.get_width()==root.size.x and abs(pixels.get_height()-root.size.y)<=1,"Native framebuffer dimensions: "+name)
	check(pixels.save_png(evidence_dir+"/screenshots/"+name+".png")==OK,"Actual framebuffer written: "+name)
	var view:Rect2=Rect2(app.world.camera_pos,app.world.viewport_rect.size)
	for foot:Vector2 in app.world.exploration_actor_positions():check(view.has_point(foot-Vector2(0,40)),"Actor torso lies in native world viewport: "+name)
	captures.append({"name":name,"width":pixels.get_width(),"height":pixels.get_height(),"step":step_number,"state":trace.back()})
	print("FRAME ",name," ",pixels.get_width(),"x",pixels.get_height())

func _stills() -> void:
	for size:Vector2i in [Vector2i(1280,800),Vector2i(1179,737)]:
		root.size=size;await process_frame;app._refresh()
		var suffix:String="-%dx%d"%[size.x,size.y]
		for i in range(4):
			_relocate("qingwei",ORIGINS[i],HEADINGS[i])
			await _walk([ACTIONS[i]],30,"cardinal_"+ACTIONS[i])
			for id:String in app.world.follower_ids():
				check(app.world.follower_view(id).moving and app.world.follower_view(id).facing.dot(HEADINGS[i])>.99,"All selected companions really walking cardinal direction: "+id)
			await _capture("party-"+ACTIONS[i]+suffix)
		var maps:Dictionary={"qingwei":Vector2(430,430),"sluice":Vector2(200,520),"frostbridge":Vector2(550,805),"mistwood":Vector2(500,450),"heting":Vector2(610,390)}
		for map:String in maps:
			_relocate(map,maps[map]);await _walk(["move_right"],24,"map_"+map)
			await _capture("party-map-"+map+suffix)
		_relocate("qingwei",Vector2(450,350));await _walk(["move_right"],42,"corner_east")
		await _walk(["move_down"],14,"corner_south");await _capture("party-corner"+suffix)
	root.size=Vector2i(1280,800);await process_frame;app._refresh()
	for count:int in [2,3,4]:
		check(s.set_party_roster(ACTORS.slice(0,count)),"Actual selected roster size "+str(count))
		app._sync_exploration_party();_relocate("qingwei",Vector2(430,430))
		await _walk(["move_right"],30,"roster_"+str(count))
		check(app.world.follower_ids().size()==count-1,"Exactly selected companions visible")
		await _capture("party-selected-"+str(count-1)+"-companions")
	# Full-game Qin contact keys come from accepted movement, never frame assignment.
	for i in range(4):
		_relocate("qingwei",ORIGINS[i],HEADINGS[i]);_hold([ACTIONS[i]])
		var seen:Array=[]
		for frame:int in range(30):
			await _frame("qin_loop_"+ACTIONS[i])
			var qin:Dictionary=app.world.follower_view("qin")
			var key:int=posmod(floori(qin.walk_phase*4.0/TAU),4)
			if qin.moving and not seen.has(key):
				seen.append(key);await _capture("party-qin-"+ACTIONS[i]+"-key-"+str(key))
		_hold([]);check(seen.size()==4,"Four authored Qin contact keys reached by actual motion: "+ACTIONS[i])
	_relocate("qingwei",app.world.Lightness.ISLET_CENTER)
	for id:String in app.world.follower_ids():check(app.world.Lightness.on_islet(app.world.follower_view(id).position),"Safe islet reseed: "+id)
	await _capture("party-safe-islet-reseed")
	s.heting_bridge="west";_relocate("heting",Vector2(820,725))
	s.heting_bridge="east";app._sync_world_state();app.world._process(0);_record("explicit_bridge_topology_reseed",false)
	await _capture("party-safe-bridge-reseed")

func _movie() -> void:
	# Approximately 20 seconds at fixed 30fps. Native engine frames, silent.
	_relocate("qingwei",Vector2(450,350))
	await _walk([],30,"opening_idle")
	for route:Array in [["move_right",48],["move_down",26],["move_left",48],["move_up",26]]:
		await _walk([route[0]],route[1],"continuous_corner_"+route[0])
	await _walk([],20,"settled_after_corners")
	for map:String in ["sluice","frostbridge","mistwood","heting"]:
		var origin:Vector2={"sluice":Vector2(200,520),"frostbridge":Vector2(550,805),"mistwood":Vector2(500,450),"heting":Vector2(610,390)}[map]
		_relocate(map,origin)
		await _walk(["move_right"],38,"map_walk_"+map)
		await _walk([],12,"map_idle_"+map)
	for i in range(4):
		_relocate("qingwei",ORIGINS[i],HEADINGS[i]);await _walk([ACTIONS[i]],30,"cardinal_close_"+ACTIONS[i])
	await _walk([],20,"ending_idle")
	for direction:String in ["front","right","back","left"]:
		check(qin_keys.get(direction,[]).size()==4,"Movie contains all four Qin contact keys: "+direction)
