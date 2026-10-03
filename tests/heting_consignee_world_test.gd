extends SceneTree
## Actual world/keyboard/follower/chart integration on the current source.
## Headless draw-call coverage is not rendered-pixel acceptance.
const JournalFixture=preload("res://tests/journal_guidance_test_fixture.gd")
const Guidance=preload("res://scripts/journal_guidance_rules.gd")
const World=preload("res://scripts/world.gd")
const Region=preload("res://scripts/heting_region.gd")
const Chart=preload("res://scripts/map_chart.gd")
const Routes=preload("res://scripts/heting_cart_routes.gd")
const Fixture=preload("res://tests/party_exploration_fixture.gd")
class ProbeWorld extends "res://scripts/world.gd":
	var drawn_followers:Array[String]=[]
	func _draw()->void:
		drawn_followers.clear();super._draw()
	func _draw_follower(id:String)->void:
		drawn_followers.append(id);super._draw_follower(id)
var world:ProbeWorld
var checks:int=0
var failures:int=0
var movement_frames:int=0
var block_hints:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func run()->void:
	for action in ["move_up","move_down","move_left","move_right"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	world=ProbeWorld.new();root.add_child(world);world.set_process(false)
	var state=Fixture.select_world(world)
	var resources_before:Dictionary=state.to_dict().duplicate(true)
	world.heting_stage=3;world.change_map("heting",Region.ENTRY)
	check(world.interactables.size()==7 and not world.interactables.has("consignee_warehouse"),"New point is hidden before old harbor completion")
	world.heting_stage=4;world.heting_delivered.assign(["meal","sealed","reserve"])
	world.heting_draft="open_scale";world.heting_ending="open_scale"
	world.refresh_heting_points()
	check(world.interactables.size()==8,"Stationary refresh exposes only the new warehouse")
	for id in ["heting_dispatch","heting_lighter","heting_cargo","heting_scale","heting_relief"]:
		check(world.interaction_verb(id)=="交谈","Pre-offer old-site verbs stay compatible: "+id)
	var policy=JournalFixture.consignee(4,"west","return_to_owner")
	var projected=JournalFixture.project(world,policy,"heting_consignee")
	check(projected.destination_receiver=="heting_grain_boat" and world._quest_target_id()=="heting_cargo","Canonical real receiver projects original central-boat marker")
	policy=JournalFixture.consignee(1)
	projected=JournalFixture.project(world,policy,"heting_consignee")
	check(projected.arc_id=="heting_consignee" and world._quest_target_id()=="consignee_warehouse","Real unobserved source is an independent compass target")
	for side in ["west","east"]:
		for stage in range(6):
			for plan in (["hold_for_inspection","return_to_owner"] if stage==5 else ["hold_for_inspection"]):
				_set_phase(stage,side,plan)
				var label="%s/stage%d/%s"%[side,stage,plan]
				var immutable=_snapshot()
				check(world.follower_ids()==["shen","tang","qin"],label+" actual selected party remains all four people")
				check(world.heting_cart_loaded()==(stage==4),label+" new lot controls shared loaded state")
				check(world._safe_spawn()==(Region.LOADED_SAFE if stage==4 else Region.ENTRY),label+" safe spawn shares loaded state")
				check(world._can_walk(Vector2(805,505))==(stage!=4),label+" north pier is walking-only")
				check(world._follower_topology_key()==["heting",side,stage==4],label+" topology shares loaded state")
				world.teleport(Region.CONSIGNEE_WAREHOUSE)
				check(world.nearby_id=="consignee_warehouse",label+" nearest E at source is unambiguous")
				check(world._can_step(world.player_pos,Vector2(700,350)),label+" loaded cart can leave the real source")
				_walk([Vector2(700,350),Vector2(1530,350),Vector2(1530,600),Vector2(1390,600)],label+" source to scale")
				check(world.nearby_id=="heting_scale",label+" keyboard reaches exact scale receiver")
				world.teleport(Region.CONSIGNEE_WAREHOUSE)
				var boat_route=[Vector2(700,350),Vector2(330,350),Vector2(330,728),Vector2(665,728),Vector2(665,620)] if side=="west" else [Vector2(700,350),Vector2(1530,350),Vector2(1530,728),Vector2(665,728),Vector2(665,620)]
				_walk(boat_route,label+" source to boat")
				check(world.nearby_id=="heting_cargo",label+" keyboard reaches original boat receiver")
				if stage!=4:
					world.teleport(Region.CONSIGNEE_WAREHOUSE)
					_walk([Vector2(700,350),Vector2(805,350),Vector2(805,620),Vector2(665,620)],label+" walking foot-pier route")
				_chart(stage,side,plan)
				world.queue_redraw();await process_frame;await process_frame
				check(world.drawn_followers.size()==3,label+" region draws all selected followers")
				for id in ["shen","tang","qin"]:check(world.drawn_followers.count(id)==1,label+" renders each companion once: "+id)
				check(_snapshot()==immutable,label+" travel/chart/drawing never changes old or new quest fields")
	_context_verbs()
	_combined_loading_and_recovery()
	_party_visibility_and_prompts()
	check(state.to_dict()==resources_before,"World travel and rendering cannot heal, reward or rewrite party resources")
	world.queue_free();await process_frame
	print("%s: %d consignee world/cart/follower/chart checks; %d actual movement frames; headless only"%["PASS" if failures==0 else "FAIL",checks,movement_frames])
	quit(0 if failures==0 else 1)
func _set_phase(stage:int,side:String,plan:String)->void:
	world.heting_bridge=side;world.heting_cargo="";world.consignee_stage=stage
	world.consignee_observations.assign([] if stage==0 else ["lot_seals","removal_order","southern_counterfoil"])
	world.consignee_draft=plan if stage>=2 else ""
	world.consignee_cargo_location="" if stage==0 else ("warehouse" if stage<4 else ("cart" if stage==4 else ("public_scale" if plan=="hold_for_inspection" else "grain_boat")))
	world.consignee_ending=plan if stage==5 else ""
	world.refresh_heting_points();world.active=true
	world.teleport(Region.CONSIGNEE_WAREHOUSE)
func _snapshot()->Dictionary:
	return {"old_stage":world.heting_stage,"old_cargo":world.heting_cargo,"old_delivered":world.heting_delivered.duplicate(),"old_draft":world.heting_draft,"old_ending":world.heting_ending,
		"stage":world.consignee_stage,"observations":world.consignee_observations.duplicate(),"draft":world.consignee_draft,"location":world.consignee_cargo_location,"ending":world.consignee_ending}
func _walk(route:Array,label:String)->void:
	for target:Vector2 in route:
		var offset:Vector2=target-world.player_pos
		check(absf(offset.x)<.05 or absf(offset.y)<.05,label+" test is keyboard-aligned")
		var action=("move_right" if offset.x>0 else "move_left") if absf(offset.x)>=.05 else ("move_down" if offset.y>0 else "move_up")
		var steps=maxi(1,ceili(offset.length()/8.0));var delta=offset.length()/float(steps)/World.SPEED
		Input.action_press(action)
		for _i in range(steps):
			var previous:Vector2=world.player_pos;var followers=Fixture.positions(world)
			world._process(delta);movement_frames+=1
			check(world._can_step(previous,world.player_pos),label+" player segment uses real terrain")
			for id:String in world.follower_ids():
				var at:Vector2=world.follower_view(id).position
				check(Region.walkable(at,world.heting_bridge),label+" companion remains on land: "+id)
				check(Region.can_step(followers[id],at,world.heting_bridge),label+" companion cannot cut across water: "+id)
		Input.action_release(action)
		check(world.player_pos.distance_to(target)<.05,label+" keyboard reaches exact endpoint")
func _chart(stage:int,side:String,plan:String)->void:
	var chart=Chart.new();chart.map_id="heting";chart.heting_bridge=side
	var policy=JournalFixture.consignee(stage,side,plan)
	chart.heting_cargo=policy.heting_cargo;chart.consignee_cargo_location=policy.consignee_cargo_location
	chart.player_position=Region.CONSIGNEE_WAREHOUSE;chart.markers=world.interactables.duplicate(true)
	var context={"map_id":"heting","player_position":chart.player_position,"markers":chart.markers.duplicate(true)}
	var before:Dictionary=policy.to_dict()
	var projected=Guidance.resolve(policy,"heting_consignee",context)
	chart.set_journal_guidance(projected)
	check(chart.heting_cart_loaded()==(stage==4),"Chart loaded state agrees with world")
	if stage==4:
		var receiver="heting_scale" if plan=="hold_for_inspection" else "heting_cargo"
		check(projected.next_target_id==receiver and chart.current_target==receiver,"Actual consignee plan projects independently expected physical receiver")
		check(chart.cart_route==Routes.route(chart.player_position,chart.markers[receiver].pos,side),"Chart exact supplied route matches independent loaded geometry")
	else:check(chart.cart_route.is_empty(),"Walking and completed chart have no obsolete cargo route")
	check(policy.to_dict()==before,"Chart projection cannot mutate actual canonical prepared state")
	# Independent actual carrying/boat fixture, not current_target injection.
	policy=JournalFixture.consignee(4,side,"return_to_owner")
	chart.consignee_cargo_location=policy.consignee_cargo_location
	projected=Guidance.resolve(policy,"heting_consignee",context);chart.set_journal_guidance(projected)
	check(projected.destination_receiver=="heting_grain_boat" and chart.current_target=="heting_cargo" and not chart.cart_route.is_empty() and chart.cart_route[-1]==Region.points().heting_cargo.pos,"Model normalizes real boat once; chart consumes physical marker and route")
	projected.cart_route[0]=Vector2(-99,-99)
	check(chart.cart_route[0]==Region.CONSIGNEE_WAREHOUSE,"Chart owns a detached supplied route")
	chart.free()
func _context_verbs()->void:
	var verbs=["问北仓封粮","核验封粮","前往对质","提取粮车","查看提货位","查看交接记录"]
	for stage in range(6):
		_set_phase(stage,"west","hold_for_inspection")
		check(world.interaction_verb("consignee_warehouse")==verbs[stage],"Warehouse verb matches its actual sheet")
	_set_phase(1,"west","")
	check(world.interaction_verb("heting_dispatch")=="核对撤运单" and world.interaction_verb("heting_lighter")=="核对收货联","Investigation sites name their actual evidence")
	for plan in ["hold_for_inspection","return_to_owner"]:
		_set_phase(4,"west",plan)
		var receiver="heting_scale" if plan=="hold_for_inspection" else "heting_cargo"
		check(world.interaction_verb(receiver)=="商议本批交接","Loaded receiver advertises a sheet, never automatic delivery")
func _combined_loading_and_recovery()->void:
	world.traversal_blocked.connect(func(_message):block_hints+=1)
	for side in ["west","east"]:
		for old_cargo in ["","meal"]:
			for location in ["warehouse","cart","public_scale","grain_boat"]:
				world.heting_bridge=side;world.heting_cargo=old_cargo;world.consignee_cargo_location=location
				var loaded=not old_cargo.is_empty() or location=="cart"
				check(world.heting_cart_loaded()==loaded,"Old and new cart fields combine without aliasing")
				world.teleport(Vector2(805,505))
				check(world.player_pos==(Region.LOADED_SAFE if loaded else Vector2(805,505)),"Foot-pier stale-position recovery uses the shared flag")
				check(world.heting_cargo==old_cargo and world.consignee_cargo_location==location,"Recovery retains both independent cargo fields")
		_set_phase(4,side,"hold_for_inspection")
		world.teleport(Vector2(805,435));var before=block_hints
		Input.action_press("move_down");world._process(.15);world._process(.15);Input.action_release("move_down")
		check(block_hints==before+1 and world.player_pos.y<443,"New cart gives one physical blocked-pier hint")
		world.teleport(Vector2(475,728) if side=="west" else Vector2(1150,728))
		world.heting_bridge="east" if side=="west" else "west"
		world._process(0)
		check(world.player_pos==Region.LOADED_SAFE and world.consignee_cargo_location=="cart","Changing the bridge repairs stale cart position without delivery")
		for id:String in world.follower_ids():check(Region.walkable(world.follower_view(id).position,world.heting_bridge),"Bridge reseed preserves each real follower on current terrain")
		_set_phase(3,side,"hold_for_inspection");world.teleport(Region.CONSIGNEE_WAREHOUSE)
		var count=world._follower_reseed_count
		world.consignee_stage=4;world.consignee_cargo_location="cart";world._process(0)
		check(world._follower_reseed_count==count+1 and world.follower_recovery_reason=="topology","Loading new lot reseeds follower topology once")
func _party_visibility_and_prompts()->void:
	_set_phase(2,"west","hold_for_inspection")
	world.camera_pos=Vector2.ZERO;world.viewport_rect.size=Vector2(1600,1050)
	world.teleport(Vector2(700,367));world.camera_pos=Vector2.ZERO
	for id:String in ["shen","tang","qin"]:
		var frame=Fixture.render_frame(id,Vector2(690,291));Fixture.prepare_render(world,[frame])
		check(Region.consignee_opacity(world.exploration_actor_positions())<1.0,"Receiver fades for each independently occluded companion: "+id)
		check(Region.consignee_record_opacity(Vector2(700,315),world.exploration_actor_positions())<1.0,"New-lot record fades for each independently occluded companion: "+id)
		Fixture.prepare_render(world,[Fixture.render_frame(id,Vector2(700,375))])
		var box:Rect2=world._interaction_prompt_rect(Region.CONSIGNEE_WAREHOUSE,"E  前往对质")
		check(not box.intersects(Rect2(Vector2(680,313),Vector2(40,70))),"Warehouse prompt avoids each companion body: "+id)
	check(Region.consignee_opacity([Vector2(1000,400)])==1.0,"Receiver remains opaque when no actor is behind")
