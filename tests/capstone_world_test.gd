extends SceneTree
## Prepared world fixtures + real Input actions and fixed-step movement.
## Not earned story, real-time performance, native-pixel or browser acceptance.
const World=preload("res://scripts/world.gd")
const Frost=preload("res://scripts/frostbridge_region.gd")
const Liang=preload("res://scripts/painted_battle_liang.gd")
const Rules=preload("res://scripts/volume_one_capstone_rules.gd")
const Fixture=preload("res://tests/capstone_world_fixture.gd")
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
var checks:int=0
var failures:int=0
var w
var interactions:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func _walk(route:Array)->void:
	for target:Vector2 in route:
		var steps:int=0
		while w.player_pos.distance_to(target)>0.1 and steps<2200:
			var difference:Vector2=target-w.player_pos
			var action:String="move_right" if difference.x>.1 else ("move_left" if difference.x<-.1 else ("move_down" if difference.y>0 else "move_up"))
			var distance:float=absf(difference.x) if absf(difference.x)>.1 else absf(difference.y)
			var before:Vector2=w.player_pos
			Input.action_press(action);w._process(minf(1.0/60.0,distance/World.SPEED));Input.action_release(action)
			check(w.player_pos!=before and w._can_step(before,w.player_pos),"accepted held-input world leg")
			for actor:Vector2 in w.exploration_actor_positions():check(w._can_walk(actor),"all actual actor feet legal")
			if w.player_pos==before:break
			steps+=1
		check(w.player_pos.distance_to(target)<.11,"waypoint reached "+str(target))
func _collisions()->PackedByteArray:
	var result:=PackedByteArray()
	for y:int in range(155,1016,11):
		for x:int in range(30,1571,11):result.append(int(w._can_walk(Vector2(x,y))))
	return result
func run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	for action:String in ["move_right","move_left","move_down","move_up"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	w=World.new();w.terrain_cache_enabled=false;root.add_child(w);w.set_process(false)
	w.interacted.connect(func(id:String):interactions.append(id))
	var old_points:Dictionary=Frost.points()
	var s=Fixture.state(4);Fixture.sync(w,s)
	w.change_map("sluice",Vector2(1390,290));PartyFixture.select_world(w)
	var old_topology:Array=w._follower_topology_key();var count:int=w._follower_reseed_count
	for stage:int in range(1,8):
		Fixture.sync(w,Fixture.state(stage));w._process(0)
		check(w._follower_topology_key()==old_topology and w._follower_reseed_count==count,"capstone redraw never changes topology or reseeds")
	Fixture.sync(w,s)
	_walk([Vector2(1110,290),Vector2(1110,650),Vector2(1340,650),World.CAPSTONE_DESK_APPROACH])
	check(w.nearby_id==World.CAPSTONE_DESK_ID and w.nearby_name=="待发令案","legal southern desk approach selects desk")
	check(w.interaction_verb(w.nearby_id)=="核对四号","correct classification verb")
	for distance:float in [74.9,75.0,75.1]:
		w.teleport(World.CAPSTONE_DESK_POSITION+Vector2(0,distance));w._update_nearby()
		check((w.nearby_id==World.CAPSTONE_DESK_ID)==(distance<75),"strict live desk radius "+str(distance))
		interactions.clear()
		var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
		event=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
		check(interactions==([World.CAPSTONE_DESK_ID] if distance<75 else []),"actual E emits only strict-near desk event "+str(distance))
	for id:String in ["sluice_boss","ledger_runner","stranded_boatman"]:
		w.teleport(w.interactables[id].pos);w._update_nearby();check(w.nearby_id==id,"old nearby actor disambiguation "+id)
	w.teleport(World.CAPSTONE_DESK_APPROACH)
	_walk([Vector2(1110,690),Vector2(1110,765),Vector2(565,765),Vector2(565,520),Vector2(150,520)])
	check(w.nearby_id=="return_village","south stone bridge reaches existing Qingwei exit")
	w.bridge_repaired=false;w.change_map("frostbridge",Vector2(1420,235))
	_walk([Vector2(1380,235),Vector2(1380,388),Vector2(1000,388),Vector2(700,388),Vector2(405,388),Vector2(405,365)])
	check(w.nearby_id=="chapter_host","north Frostbridge reaches Wen with south unrepaired")
	_walk([Vector2(405,388),Vector2(1000,388),Vector2(1150,388),Vector2(1150,385)])
	check(w.nearby_id=="chapter_clerk" and w.interactables.size()==old_points.size(),"same-site ledger never creates competing point")
	_walk([Vector2(1080,385),Vector2(1080,745),Vector2(1320,745)])
	check(w.nearby_id=="chapter_archive","archive reachable south of unchanged building")
	for stage:int in range(8):
		Fixture.sync(w,Fixture.state(stage))
		check(w.capstone_archive_presentation()==("liang" if stage==3 else ("book_taken" if stage>=4 else "legacy")),"archive single occupant phase"+str(stage))
		if stage==3:check(w.get_npc_name("chapter_archive")=="梁缜·签令主事" and w.interaction_verb("chapter_archive")=="与梁缜对质","Liang name/verb agree")
		if stage>=4:check(w.interactables.chapter_archive.kind=="board" and w.get_npc_name("chapter_archive").contains("簿已取"),"aftermath board no repeated boss")
	check(is_equal_approx(Liang.opaque_rect(Vector2.ZERO,Liang.NPC_CELL_SIZE,"idle").size.y,72.0),"same accepted idle exactly72px")
	_walk([Vector2(1080,745),Vector2(1080,388),Vector2(700,388),Vector2(405,388),Vector2(405,500),Vector2(140,500)])
	check(w.nearby_id=="return_sluice" and not w.bridge_repaired,"return route never repairs south bridge")
	_test_rows_and_reload()
	# Densely compare every map's stage0 collision surface against all7 projections.
	for map:String in ["qingwei","sluice","frostbridge","mistwood","heting"]:
		Fixture.sync(w,Fixture.state(0));w.change_map(map,Vector2(500,450));var old:PackedByteArray=_collisions()
		for stage:int in range(1,8):Fixture.sync(w,Fixture.state(stage));check(_collisions()==old,"unchanged stage0 collision samples "+map+"/"+str(stage))
	Fixture.sync(w,Fixture.state(0));w.change_map("sluice",World.CAPSTONE_DESK_APPROACH)
	check(not w.interactables.has(World.CAPSTONE_DESK_ID) and w.capstone_desk_rows().is_empty(),"reset removes desk/rows")
	w.change_map("frostbridge",Vector2(1320,745));check(w.interactables==old_points,"reset exact old Frost points")
	_test_followers()
	w.queue_free();await process_frame
	print("%s capstone_world: %d checks; prepared world real held-input fixed-step, no earned/native/browser claim"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
func _test_rows_and_reload()->void:
	for plan:String in Rules.PLANS:
		for stage:int in range(8):
			var s=Fixture.state(stage,plan)
			if stage==5:s.capstone_draft=plan
			var before:Dictionary=s.to_dict();Fixture.sync(w,s)
			var rows:Array[Dictionary]=w.capstone_desk_rows()
			check(rows.size()==(4 if stage>=4 else 0),"exact finite rows after acquired book")
			for i:int in rows.size():
				check(rows[i].id==Rules.ORDER_IDS[i],"stable authored ID")
				check(rows[i].disposition==("pending" if stage<6 else ("cancelled" if i<2 else ("held" if plan=="pause_batch" else "continuing"))),"committed model disposition")
			if stage==5:
				var pending:Array[Dictionary]=rows.duplicate(true)
				for draft:String in ["","pause_batch","cancel_proven","pause_batch"]:
					s.capstone_draft=draft;Fixture.sync(w,s);check(w.capstone_desk_rows()==pending,"draft A/B/A/cancel changes no sheet disposition")
				s.capstone_draft=plan;Fixture.sync(w,s)
			if not rows.is_empty():rows[0].disposition="fake";check(w.capstone_desk_rows()[0].disposition!="fake","detached visual rows")
			var path:String="user://capstone-world-reload-%d.json"%stage
			check(s.save_game(path)==OK,"prepared canonical fixture save")
			var loaded=Fixture.State.new();check(loaded.load_game(path)==OK,"reload accepted canonical fixture")
			Fixture.sync(w,loaded);check(w.capstone_orders==Rules.order_rows(s) and w.capstone_goal==Rules.goal(s),"reload exact same derived projections")
			check(s.to_dict()==before,"world projection never mutates state")
			DirAccess.remove_absolute(path)
func _test_followers()->void:
	Fixture.sync(w,Fixture.state(5));w.change_map("sluice",World.CAPSTONE_DESK_APPROACH)
	var topology:Array=w._follower_topology_key()
	for id:String in ["shen","tang","qin"]:
		PartyFixture.prepare_render(w,[PartyFixture.render_frame(id,World.CAPSTONE_DESK_POSITION-Vector2(0,10))])
		check(w._capstone_prop_opacity(World.CAPSTONE_DESK_POSITION,Rect2(World.CAPSTONE_DESK_POSITION-Vector2(58,48),Vector2(116,52)))<1,"desk fades for "+id)
		var prompt:Rect2=w._interaction_prompt_rect(World.CAPSTONE_DESK_POSITION,"E 核对处置草案")
		for foot:Vector2 in w.exploration_actor_positions():check(not prompt.intersects(Rect2(foot-Vector2(20,62),Vector2(40,70))),"prompt avoids all actors "+id)
	var layers:Array=[];w.append_follower_layers(layers);check(layers.size()==1 and layers[0].kind=="follower","same follower Y-sort consumer")
	check(w._follower_topology_key()==topology,"render consumer no topology mutation")
