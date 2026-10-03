extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const State=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
const Fixture=preload("res://tests/party_exploration_fixture.gd")
class NoSave extends State:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
class ProbeWorld extends "res://scripts/world.gd":
	var hero_segments:Array=[]
	var follower_segments:Array=[]
	var trace:=false
	var block:=false
	var draw_order:Array=[]
	func _record_follow_segment(a:Vector2,b:Vector2)->void:
		if trace and not a.is_equal_approx(b):hero_segments.append([a,b])
		super._record_follow_segment(a,b)
	func _follower_can_step(a:Vector2,b:Vector2)->bool:
		var accepted:bool=not block and super._follower_can_step(a,b)
		if trace and accepted:follower_segments.append([a,b])
		return accepted
	func _draw()->void:
		draw_order.clear();super._draw()
	func _draw_follower(id:String)->void:
		draw_order.append(id);super._draw_follower(id)
	func _draw_person(p:Vector2,robe:Color,player:bool=false,kind:String="villager")->void:
		if player:draw_order.append("hero")
		super._draw_person(p,robe,player,kind)
var checks:=0
var failures:Array[String]=[]
var app
func check(value:bool,label:String)->void:
	checks+=1
	if not value and failures.size()<30:failures.append(label)
func _initialize()->void:run.call_deferred()
func permutations(prefix:Array,remaining:Array)->Array:
	var result:Array=[prefix]
	for id in remaining:
		var next=remaining.duplicate();next.erase(id)
		result.append_array(permutations(prefix+[id],next))
	return result
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new()
	root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false)
	Fixture.recruited_state(["hero","shen","tang","qin"],app.state)
	for id in ["shen","tang","qin"]:app.state.party_resources[id]={"hp":0,"qi":0}
	var resources:Dictionary=app.state.party_resources.duplicate(true)
	for roster:Array in permutations(["hero"],["shen","tang","qin"]):
		check(app.state.set_party_roster(roster),"accept ordered subset "+str(roster))
		var before:Dictionary=app.state.to_dict().duplicate(true)
		app._sync_exploration_party()
		check(app.world.follower_ids()==roster.slice(1),"exact ordered subset "+str(roster))
		check(app.state.to_dict()==before and app.state.party_resources==resources,"projection never heals "+str(roster))
		var visual:Array=app.world._party_trail.snapshot()
		for i in range(4):app._sync_world_state();app._refresh()
		check(visual==app.world._party_trail.snapshot(),"repeat sync cannot reposition "+str(roster))
	app.state.party_roster.assign(["hero","shen"]);app.state.companion_unlocked=false;app._sync_exploration_party()
	check(app.world.follower_ids().is_empty(),"unrecruited selected actor never displayed")
	app.state.companion_unlocked=true;app._sync_exploration_party()
	check(app.world.follower_ids()==["shen"],"restored recruitment restores ordered roster")
	app.queue_free();await process_frame
	var w=ProbeWorld.new();root.add_child(w);w.set_process(false);w.active=true
	Fixture.select_world(w,["hero","qin","shen","tang"])
	var starts={"qingwei":Vector2(600,450),"sluice":Vector2(700,430),"frostbridge":Vector2(835,390),"mistwood":Vector2(450,440),"heting":Vector2(805,390)}
	var rng:=RandomNumberGenerator.new();rng.seed=6100317
	var actions=["move_left","move_right","move_up","move_down"]
	for map:String in starts:
		w.bridge_repaired=true;w.heting_bridge="west";w.change_map(map,starts[map]);w.trace=true
		var reseeds:int=w._follower_reseed_count
		for frame in range(2000):
			if frame%17==0:
				for a in actions:Input.action_release(a)
				var dx=rng.randi_range(-1,1);var dy=rng.randi_range(-1,1)
				if dx!=0:Input.action_press("move_right" if dx>0 else "move_left")
				if dy!=0:Input.action_press("move_down" if dy>0 else "move_up")
			var before:Dictionary=w._party_trail.debug_snapshot()
			var previous:Vector2=w.player_pos
			w.hero_segments.clear();w.follower_segments.clear()
			var dt:float=[1.0/144.0,1.0/60.0,1.0/30.0,.1][frame%4]
			w._process(dt)
			check(w._party_trail.status().ok,map+" no natural path fault frame "+str(frame))
			check(w._follower_reseed_count==reseeds,map+" ordinary movement never teleports")
			check(w._can_walk(w.player_pos),map+" legal hero")
			var cursor:Vector2=previous
			for segment:Array in w.hero_segments:
				check(segment[0]==cursor,map+" accepted legs continuous")
				check(segment[0].x==segment[1].x or segment[0].y==segment[1].y,map+" actual hero axis leg")
				cursor=segment[1]
			check(cursor.distance_to(w.player_pos)<.01,map+" accepted trail reaches actual hero")
			for segment:Array in w.follower_segments:
				check(segment[0].distance_to(segment[1])<=4.001,map+" follower substep <=4")
				check(w._can_step(segment[0],segment[1]),map+" independently checked follower segment")
			for actor:Dictionary in w._party_trail.snapshot():
				var prior:Dictionary=before.actors[actor.id]
				check(w._follower_can_walk(actor.position),map+" legal "+actor.id)
				check(actor.walk_distance>=prior.walk_distance,map+" monotonic accepted walk distance")
				check(actor.walk_distance-prior.walk_distance<=300.0*minf(dt,.1)+.01,map+" bounded movement budget")
		w.trace=false
		for a in actions:Input.action_release(a)
		for i in range(40):w._process(.1)
		var settled:Array=w._party_trail.snapshot();w._process(.1)
		check(settled==w._party_trail.snapshot(),map+" all followers stop and freeze gait")
		w.camera_pos=Vector2.ZERO;w.viewport_rect.size=Vector2(1600,1050)
		w.player_pos=Vector2(600,450)
		Fixture.prepare_render(w,[Fixture.render_frame("qin",Vector2(600,600)),Fixture.render_frame("shen",Vector2(600,400)),Fixture.render_frame("tang",Vector2(600,500))])
		w.queue_redraw();await process_frame;await process_frame
		check(w.draw_order==["shen","hero","tang","qin"],map+" actual draw order by feet Y: "+str(w.draw_order))
		Fixture.prepare_render(w,[Fixture.render_frame("qin",Vector2(600,450)),Fixture.render_frame("shen",Vector2(600,450)),Fixture.render_frame("tang",Vector2(600,450))])
		w.queue_redraw();await process_frame;await process_frame
		check(w.draw_order==["hero","qin","shen","tang"],map+" deterministic equal-Y roster order: "+str(w.draw_order))
		print("REVIEW ",map," 2000 frames, exact X/Y tracing, legal followers, stable idle, draw order passed")
	# Force a callback block after walking has begun. World adapter must stop,
	# preserve accepted state, and not accidentally recover via roster refresh.
	w.change_map("qingwei",Vector2(600,450));w.block=false
	Input.action_press("move_right");w._process(.1);w.block=true;w._process(.1);Input.action_release("move_right")
	check(w._party_trail.status().reason=="blocked_history","actual callback obstruction fails closed")
	var count:int=w._follower_reseed_count
	w._process(.1);var frozen:Array=w._party_trail.snapshot()
	for i in range(6):
		w.set_exploration_party(["qin","shen","tang"]);w._process(.1)
		check(w._party_trail.snapshot()==frozen and w._follower_reseed_count==count,"blocked fault never bypassed by roster refresh")
	w.block=false;w.teleport(Vector2(650,450))
	check(w._party_trail.status().ok and w._follower_reseed_count==count+1,"explicit legal relocation recovers once")
	w.queue_free();await process_frame
	if not failures.is_empty():
		for failure:String in failures:printerr(failure)
	print("%s independent_party_review: %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
