extends SceneTree
## Actual main/world API checks. Isolated save overrides; no normal player saves.
const Scene=preload("res://scenes/main.tscn")
const State=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
const Fixture=preload("res://tests/party_exploration_fixture.gd")
const Lightness=preload("res://scripts/lightness_rules.gd")
const Heting=preload("res://scripts/heting_region.gd")
class NoSave extends State:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
var checks:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func legal_party(label:String)->void:
	for id:String in app.world.follower_ids():
		var actor:Dictionary=app.world.follower_view(id)
		check(app.world._follower_can_walk(actor.position),label+" legal "+id)
		check(actor.position.is_finite() and actor.facing.is_finite(),label+" finite "+id)
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new()
	root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.set_process(false);app.world.set_process(false)
	Fixture.recruited_state(["hero","qin","shen","tang"],app.state)
	app.state.party_resources.qin.hp=0
	app._sync_world_state()
	check(app.world.follower_ids()==["qin","shen","tang"],"Actual deployed order, including zero-HP Qin")
	var persistent:Dictionary=app.state.to_dict().duplicate(true)
	app.state.active_companion="沈青";app._sync_exploration_party()
	check(app.world.follower_ids()==["qin","shen","tang"],"Legacy preferred companion cannot replace party")
	app.state.active_companion=persistent.active_companion
	var origins={"qingwei":Vector2(600,450),"sluice":Vector2(200,520),"frostbridge":Vector2(600,805),"mistwood":Vector2(500,450),"heting":Vector2(805,390)}
	for map:String in origins:
		app.world.change_map(map,origins[map]);app.world._process(0.0)
		check(app.world.follower_ids()==["qin","shen","tang"],map+" retained order")
		check(app.world.exploration_actor_positions().size()==4,map+" exposes all bodies")
		var layers:Array=[];app.world.append_follower_layers(layers)
		check(layers.size()==3 and layers[0].id=="qin" and layers[2].id=="tang",map+" adds every Y-sorted actor")
		legal_party(map)
	check(app.state.to_dict()==persistent,"Map and follower changes never touch persistent resources or state")
	app.world.change_map("qingwei",Vector2(600,450));app.world.active=true
	var origin:Vector2=app.world.player_pos
	Input.action_press("move_right");Input.action_press("move_down")
	app.world._process(.05)
	Input.action_release("move_right");Input.action_release("move_down")
	var path:Dictionary=app.world._party_trail.debug_snapshot()
	check(path.points.size()==3,"Diagonal input records distinct accepted X/Y legs")
	check(path.points[1]==Vector2(app.world.player_pos.x,origin.y),"Exact X-then-Y accepted corner retained")
	check(path.points[2]==app.world.player_pos,"Trail head equals actual accepted hero position")
	for i in range(90):app.world._process(.05)
	var settled:Array=app.world._party_trail.snapshot()
	app.world._process(.05)
	check(app.world._party_trail.snapshot()==settled,"Stopping stabilizes every position, heading and gait")
	app.world.teleport(Lightness.ISLET_CENTER)
	for id:String in app.world.follower_ids():
		check(Lightness.on_islet(app.world.follower_view(id).position),"Lightness relocation reseeds "+id+" on islet")
	app.world.teleport(Lightness.SHORE)
	legal_party("Lightness return")
	app.world.heting_bridge="west";app.world.change_map("heting",Vector2(820,725))
	var count:int=app.world._follower_reseed_count
	app.world.heting_bridge="east";app.world._process(0.0)
	check(app.world._follower_reseed_count==count+1,"Bridge topology causes one safe reseed")
	legal_party("Bridge swap")
	check(app.world.player_pos==Vector2(820,725),"Bridge swap retains legal hero")
	app.world.bridge_repaired=true;app.world.change_map("frostbridge",Vector2(835,800))
	app.world.bridge_repaired=false;app.world._process(0.0)
	check(app.world._can_walk(app.world.player_pos),"Removed Frostbridge repairs stranded hero before party seed")
	legal_party("Frostbridge removal")
	app.world.change_map("qingwei",Vector2(600,450))
	var before:Array=app.world._party_trail.snapshot()
	count=app.world._follower_reseed_count
	app.world._party_trail._fault="history_capacity";app.world._process(.05)
	check(app.world._follower_reseed_count==count,"History capacity does not teleport party")
	check(app.world._party_trail.snapshot()==before,"History capacity fails stopped in place")
	check(app.world.follower_recovery_reason=="history_capacity","Bounded history reports recoverable fault")
	app.world.set_exploration_party(Fixture.manifest(app.state))
	check(app.world._follower_reseed_count==count,"Roster refresh cannot bypass retained-history stop")
	check(app.world._party_trail.snapshot()==before,"Roster refresh leaves stopped party positions unchanged")
	app.world.teleport(Vector2(610,450))
	check(app.world._party_trail.status().ok,"Explicit relocation clears stopped history safely")
	app.state.party_roster.assign(["hero","qin","qin"]);app._sync_exploration_party()
	check(app.world.follower_ids().is_empty(),"Invalid actual roster never renders phantom actors")
	app.state.party_roster.assign(["hero","qin","shen","tang"]);app._sync_exploration_party()
	check(app.world.follower_ids()==["qin","shen","tang"],"Correcting roster to cached signature restores party")
	check(app.world.get_npc_name("healer")=="药铺伙计","Selected Shen substitutes original identity")
	check(app.world.get_npc_name("bridge_worker")=="修桥工位","Selected Tang substitutes original identity")
	check(app.world.get_npc_name("mist_guide")=="引路亭","Selected Qin substitutes original identity")
	check(app.state.to_dict()==persistent,"Motion, faults, relocation and roster view never heal or change saved state")
	check(app.state.set_party_roster(["hero"]),"Actual roster can bench all")
	app._sync_exploration_party()
	check(app.world.follower_ids().is_empty(),"Hero-only roster displays nobody else")
	check(app.world.get_npc_name("healer")=="沈青","Benched Shen returns to original identity")
	app.queue_free();await process_frame
	print("%s exploration_party_world_integration: %d checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
