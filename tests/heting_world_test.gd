extends SceneTree
## Actual VillageWorld + MapChart integration. Isolated test save only.
## This is headless runtime/geometry coverage, not rendered-pixel or GUI QA.
const World = preload("res://scripts/world.gd")
const Chart = preload("res://scripts/map_chart.gd")
const Heting = preload("res://scripts/heting_region.gd")
const Mist = preload("res://scripts/mistwood_region.gd")
const Lightness = preload("res://scripts/lightness_rules.gd")
const State = preload("res://scripts/game_state.gd")
const SAVE_PATH = "user://heting-world-integration-fixture.json"
const EXPECTED = {
	"return_mistwood": Vector2(150,335), "heting_dispatch": Vector2(535,350),
	"heting_winch": Vector2(820,735), "heting_cargo": Vector2(665,620),
	"heting_lighter": Vector2(970,780), "heting_relief": Vector2(230,780),
	"heting_scale": Vector2(1390,600),
}

class DrawWorld:
	extends "res://scripts/world.gd"
	var draw_count: int = 0
	func _draw() -> void:
		draw_count += 1
		super._draw()

class DrawChart:
	extends "res://scripts/map_chart.gd"
	var draw_count: int = 0
	func _draw() -> void:
		draw_count += 1
		super._draw()

var checks: int = 0
var failures: int = 0
var reachable_samples: int = 0
var world
var chart

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	world = DrawWorld.new()
	chart = DrawChart.new()
	root.add_child(world)
	root.add_child(chart)
	world.set_process(false)
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	_fields_and_regions()
	_geometry_and_navigation()
	_long_frame_input()
	_loaded_save_recovery()
	_companion_segments()
	_other_region_regression()
	await _draw_states()
	world.queue_free()
	chart.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		var path := ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("%s: %d Heting world/chart integration checks; %d reachable samples; headless only, no pixel QA" % ["PASS" if failures == 0 else "FAIL", checks, reachable_samples])
	quit(0 if failures == 0 else 1)

func _fields_and_regions() -> void:
	var properties: Dictionary = {}
	for property in world.get_property_list(): properties[property.name] = property.type
	for field in ["heting_bridge", "heting_cargo", "heting_draft", "heting_ending", "mist_ending", "heting_target_id"]:
		_check(properties.get(field) == TYPE_STRING, "Exact String field: " + field)
	_check(properties.get("heting_delivered") == TYPE_ARRAY, "Typed deliveries field exists")
	_check(world.heting_delivered.is_typed() and world.heting_delivered.get_typed_builtin() == TYPE_STRING, "Deliveries accept String entries")
	world.heting_bridge = "west"
	world.heting_cargo = ""
	world.change_map("heting", Heting.ENTRY)
	_check(world.map_id == "heting" and world.interactables.size() == 7, "Fifth map admitted with exact seven points")
	_check(world._safe_spawn() == Heting.ENTRY, "Unloaded safe spawn is northern entry")
	_check(world.current_location == "鹤汀埠 · 北岸交割街", "Heting location never falls back to village")
	for id in EXPECTED:
		_check(world.interactables.has(id) and world.interactables[id].pos == EXPECTED[id], "Authored point unchanged: " + id)
		world.teleport(EXPECTED[id])
		_check(world.nearby_id == id, "Actual nearby selection resolves " + id)
		_check(world.get_npc_name(id) == Heting.points()[id].name, "Name lookup resolves " + id)
		_check(world._location_for_position().begins_with("鹤汀埠"), "Heting location at " + id)
	_check(world.interaction_verb("return_mistwood") == "前往", "Return point has travel verb")
	_check(world.interaction_verb("heting_winch") == "改泊", "Winch has mechanical context verb")
	for id in ["heting_cargo", "heting_lighter"]:
		_check(world.interaction_verb(id) == "查看", "Cargo sources show inspection verb")
	for id in ["heting_dispatch", "heting_relief", "heting_scale"]:
		_check(world.interaction_verb(id) == "交谈", "Heting NPC uses conversation verb")
	world.shen_target_id = "return_mistwood"
	world.heting_target_id = "heting_scale"
	_check(world._quest_target_id() == "heting_scale", "Parent supplied valid Heting target owns priority")
	world.heting_target_id = "absent"
	_check(world._quest_target_id() == "return_mistwood", "Invalid Heting target preserves existing personal route")
	world.shen_target_id = ""
	world.personal_target_id = "return_mistwood"
	_check(world._quest_target_id() == "return_mistwood", "Tang Qi return target remains usable in fifth map")
	world.personal_target_id = ""
	world.heting_target_id = ""
	_check(world._quest_target_id() == "heting_dispatch", "Fifth map fallback is a real local point")
	world.change_map("mistwood", Vector2(1440,505))
	_check(world.player_pos == Vector2(1440,505) and Mist.walkable(world.player_pos), "Existing Mist return location is preserved")
	_check(world.interactables.exit_heting.pos == Vector2(1470,485), "New downstream exit is exact")
	_check(world.interaction_verb("exit_heting") == "前往", "Mist exit context is travel")
	world.heting_target_id = "exit_heting"
	_check(world._quest_target_id() == "exit_heting", "New chapter can target Mist downstream exit")
	var old_points := {"return_frostbridge":Vector2(150,550),"mist_guide":Vector2(350,360),"mist_rain_gauge":Vector2(550,245),"mist_stone_gauge":Vector2(1000,300),"mist_basin":Vector2(1250,765),"mist_camp":Vector2(290,790),"mist_scout":Vector2(1030,560),"mist_gate":Vector2(1320,500)}
	_check(world.interactables.size() == 9, "Mist adds one point without removing an original")
	for id in old_points:
		_check(world.interactables[id].pos == old_points[id] and Mist.walkable(old_points[id]), "Original Mist point stays walkable and unchanged: " + id)
	_check(world._can_step(Vector2(1320,500), Vector2(1470,485)), "Gate-to-exit road stays unblocked")
	world.heting_target_id = ""

func _geometry_and_navigation() -> void:
	for side in ["west", "east"]:
		for cargo in ["", "meal"]:
			world.heting_bridge = side
			world.heting_cargo = cargo
			world.change_map("heting", Heting.ENTRY)
			var label: String = side + "/" + ("empty" if cargo.is_empty() else cargo)
			_check(world.get_region_hint().contains("西岸" if side == "west" else "东岸"), label + " hint follows active bridge")
			_check(world._can_walk(Vector2(805,505)) == cargo.is_empty(), label + " cart blocks northern foot pier")
			_check(world._can_step(Vector2(805,425),Vector2(805,595)) == cargo.is_empty(), label + " pier validates whole motion")
			_check(world._can_walk(Vector2(475,735)) == (side == "west"), label + " west bridge collision matches state")
			_check(world._can_walk(Vector2(1140,735)) == (side == "east"), label + " east bridge collision matches state")
			_check(not world._can_step(Vector2(665,620),Vector2(230,780)), label + " diagonal cannot skip basin")
			_check(not world._can_step(Vector2(535,180),Vector2(535,300)), label + " long step cannot tunnel warehouse")
			var visited := _flood(Heting.ENTRY)
			reachable_samples += visited.size()
			for id in EXPECTED:
				var reached := false
				for p:Vector2 in visited:
					if p.distance_to(EXPECTED[id]) <= 24 and world._can_step(p, EXPECTED[id]):
						reached = true
						break
				_check(reached, label + " real world flood reaches " + id)
				world.teleport(EXPECTED[id])
				_check(world.player_pos == EXPECTED[id], label + " legal landmark survives teleport")
			world.companion_active = true
			world.active = true
			world.teleport(Vector2(820,735))
			_walk_route([Vector2(330,735),Vector2(330,780),Vector2(230,780)] if side == "west" else [Vector2(1390,735),Vector2(1390,600)], label + " active pontoon")
			world.teleport(Vector2(230,780))
			_walk_route([Vector2(330,780),Vector2(330,350),Vector2(1530,350),Vector2(1530,600),Vector2(1390,600)], label + " northern loaded bypass")
			if cargo.is_empty():
				world.teleport(Vector2(805,665))
				_walk_route([Vector2(805,350),Vector2(535,350)], label + " foot shortcut")
	world.companion_active = false

func _flood(start: Vector2) -> Dictionary:
	var queue:Array[Vector2]=[start]
	var visited:Dictionary={start:true}
	var cursor:=0
	while cursor < queue.size():
		var p:Vector2=queue[cursor]
		cursor += 1
		for offset in [Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20)]:
			var next:Vector2=p+offset
			if not visited.has(next) and world._can_step(p,next):
				visited[next]=true
				queue.append(next)
	return visited

func _walk_route(route: Array, label: String) -> void:
	for endpoint:Vector2 in route:
		var offset:Vector2=endpoint-world.player_pos
		_check(absf(offset.x) < 0.05 or absf(offset.y) < 0.05, label + " test route is keyboard-aligned")
		var action:String=("move_right" if offset.x > 0 else "move_left") if absf(offset.x) >= 0.05 else ("move_down" if offset.y > 0 else "move_up")
		var steps:=maxi(1,int(ceil(offset.length()/8.0)))
		var delta:=offset.length()/float(steps)/World.SPEED
		Input.action_press(action)
		for _step in range(steps):
			var previous:Vector2=world.player_pos
			var old_companion:Vector2=world.companion_pos
			world._process(delta)
			_check(world._can_step(previous,world.player_pos), label + " actual movement stays on terrain")
			_check(Heting.walkable(world.companion_pos,world.heting_bridge), label + " follower is on land")
			_check(Heting.can_step(old_companion,world.companion_pos,world.heting_bridge) or world.companion_pos.is_equal_approx(world.player_pos), label + " follower segment is legal or explicitly resynced")
		Input.action_release(action)
		_check(world.player_pos.distance_to(endpoint) < 0.05, label + " actual input reaches endpoint")

func _long_frame_input() -> void:
	for side in ["west", "east"]:
		world.heting_bridge = side
		world.heting_cargo = "sealed"
		world.change_map("heting",Vector2(805,425))
		for delta in [0.15,1.0,2.0]:
			world.teleport(Vector2(805,425))
			Input.action_press("move_down")
			world._process(delta)
			Input.action_release("move_down")
			_check(world.player_pos == Vector2(805,425), "Loaded long frame cannot jump north foot pier")
			world.teleport(Vector2(805,595))
			Input.action_press("move_up")
			world._process(delta)
			Input.action_release("move_up")
			_check(world.player_pos == Vector2(805,595), "Loaded long frame cannot jump south foot pier")
		world.teleport(Vector2(820,735))
		var blocked:String="move_right" if side == "west" else "move_left"
		Input.action_press(blocked)
		world._process(3.0)
		Input.action_release(blocked)
		_check(world.player_pos == Vector2(820,735), "Inactive pontoon blocks a frame spanning the whole water gap")
		world.active = false
		Input.action_press("move_down")
		var old:Vector2=world.player_pos
		world._process(1.0)
		Input.action_release("move_down")
		_check(world.player_pos == old, "Modal pause does not advance loaded cart")
		world.active = true
		for directions in [["move_left","move_down"],["move_right","move_down"],["move_left","move_up"],["move_right","move_up"]]:
			for position in [Vector2(805,425),Vector2(805,595),Vector2(615,735),Vector2(1015,735)]:
				world.teleport(position)
				var start:Vector2=world.player_pos
				for action in directions:Input.action_press(action)
				world._process(1.0)
				for action in directions:Input.action_release(action)
				# _process performs x then y; both actual segments must be safe.
				var elbow:=Vector2(world.player_pos.x,start.y)
				_check(world._can_step(start,elbow) and world._can_step(elbow,world.player_pos), "Actual diagonal long-frame axis segments cannot tunnel")

func _ready_state():
	var s=State.new()
	s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁")
	s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	s.mist_stage=4;s.mist_gauges.assign(s.Mist.GAUGES);s.mist_approach="duel";s.mist_ending="release_water"
	s.map_id="mistwood";s.position=Vector2(1440,505)
	_check(s.begin_heting(), "Save fixture begins through public rule")
	s.map_id="heting"
	return s

func _sync_from_state(s) -> void:
	world.heting_bridge=s.heting_bridge
	world.heting_delivered.assign(s.heting_delivered)
	world.heting_cargo=s.heting_cargo
	world.heting_draft=s.heting_draft
	world.heting_ending=s.heting_ending
	world.mist_ending=s.mist_ending

func _loaded_save_recovery() -> void:
	for side in ["west","east"]:
		for cargo in ["meal","sealed","reserve"]:
			var s=_ready_state()
			s.heting_bridge=side
			if cargo=="reserve":
				s.take_heting_cargo("meal");s.deliver_heting_base("heting_relief")
				s.take_heting_cargo("sealed");s.deliver_heting_base("heting_scale")
				s.choose_heting_plan("open_scale")
			_check(s.take_heting_cargo(cargo), "Save fixture loads requested batch")
			for position in [Vector2(665,620),Vector2(805,505),Vector2(800,930),Vector2(475,735) if side=="east" else Vector2(1140,735),Vector2(9999,9999)]:
				s.position=position
				_check(s.save_game(SAVE_PATH)==OK, "Current cargo fixture saves")
				var loaded=State.new()
				_check(loaded.load_game(SAVE_PATH)==OK, "Real save round-trip accepts finite unsafe position")
				var before:Dictionary=loaded.to_dict()
				_sync_from_state(loaded)
				world.change_map(loaded.map_id,loaded.position)
				var expected:Vector2=position if Heting.walkable(position,side,true) else Heting.LOADED_SAFE
				_check(world.player_pos==expected, "Loaded save preserves valid point or repairs to island")
				_check(world.heting_cargo==cargo and world.heting_delivered==loaded.heting_delivered, "World repair never drops or delivers cargo")
				_check(loaded.to_dict()==before, "Geometry repair does not change model or rewards")
				_check(Heting.walkable(world.companion_pos,side), "Loaded companion spawns on valid terrain")
			for invalid in [Vector2(NAN,0),Vector2(INF,0),Vector2(-500,-500)]:
				world.teleport(invalid)
				_check(world.player_pos==Heting.LOADED_SAFE and world.heting_cargo==cargo, "Bad runtime position safely retains loaded cart")
		world.heting_cargo=""
		world.teleport(Vector2(805,505))
		_check(world.player_pos==Vector2(805,505), "Empty cart preserves foot-pier save")
		world.teleport(Vector2(800,930))
		_check(world.player_pos==Heting.ENTRY, "Empty invalid save uses northern entry")
		world.heting_cargo="meal"
		_check(world._safe_spawn()==Heting.LOADED_SAFE, "Loaded safe spawn is the island")
		world.teleport(Vector2(820,735))
		world.heting_bridge="east" if side=="west" else "west"
		world._process(0.0)
		_check(world.player_pos==Vector2(820,735) and world.heting_cargo=="meal", "Loaded island winch change never moves player off the island")
		world.heting_bridge=side
		world.teleport(Vector2(475,735) if side=="west" else Vector2(1140,735))
		world.heting_bridge="east" if side=="west" else "west"
		world._process(0.0)
		_check(world.player_pos==Heting.LOADED_SAFE and world.heting_cargo=="meal", "Changing pontoon repairs a stale loaded bridge position")
	world.heting_cargo=""
	world.heting_delivered.clear()
	world.heting_draft=""
	world.heting_ending=""

func _companion_segments() -> void:
	world.companion_active=true
	world.heting_cargo=""
	for side in ["west","east"]:
		world.heting_bridge=side
		world.change_map("heting",Heting.ENTRY)
		for point in [Vector2(805,505),Vector2(600,585),Vector2(1015,820),Vector2(330,715),Vector2(1530,552),Vector2(820,735)]:
			world.teleport(point)
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				world.facing=direction
				for delta in [1.0/60.0,0.25,1.0]:
					var before:Vector2=world.companion_pos
					world._process(delta)
					_check(Heting.walkable(world.companion_pos,side), "Companion edge/corner interpolation has legal endpoint")
					_check(Heting.can_step(before,world.companion_pos,side) or world.companion_pos==world.player_pos, "Companion edge/corner follows safe segment or syncs")
		# Both endpoints are legal, but the direct interpolation crosses the basin.
		world.teleport(Vector2(665,620))
		world.companion_pos=Vector2(230,780)
		world._process(1.0)
		_check(world.companion_pos==world.player_pos, "Disconnected legal endpoints never cause a water-crossing lerp")
		# The companion was left on the former floating deck while the player
		# operated the island winch; no stale deck coordinate survives next tick.
		world.teleport(Vector2(820,735))
		world.companion_pos=Vector2(475,735) if side=="east" else Vector2(1140,735)
		world._process(0.0)
		_check(world.companion_pos==world.player_pos, "Removed pontoon resynchronizes companion without interpolation")
		world.heting_cargo="sealed"
		world.teleport(Vector2(820,735))
		world.companion_pos=Vector2(NAN,0)
		world._process(0.1)
		_check(world.companion_pos==world.player_pos and world.heting_cargo=="sealed", "Invalid companion repairs without changing cargo")
		world.heting_cargo=""
	world.companion_active=false

func _other_region_regression() -> void:
	world.heting_target_id="heting_scale"
	for id in ["qingwei","sluice","frostbridge","mistwood"]:
		world.change_map(id,Vector2(460,430) if id=="qingwei" else Vector2(150,550))
		_check(world.map_id==id and world._can_walk(world.player_pos), "Existing map entry remains valid: "+id)
		_check(not world.interactables.has("heting_cargo"), "Fifth-region cargo markers never leak into "+id)
		_check(world.interactables.has(world._quest_target_id()) or world._quest_target_id().is_empty(), "Stale fifth target never breaks old region "+id)
	world.change_map("qingwei",Lightness.LANDING)
	world.companion_active=true
	_check(Lightness.on_islet(world.companion_pos), "Existing lightness companion spawn stays on island")
	for facing in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		world.facing=facing
		world._process(0.25)
		_check(Lightness.on_islet(world.companion_pos), "Existing lightness following is unaffected")
	_check(not world._can_step(Lightness.SHORE,Lightness.LANDING), "Heting integration does not open lightness water gap")
	world.change_map("unknown",Vector2(460,430))
	_check(world.map_id=="qingwei", "Unknown region still falls back safely")
	world.heting_target_id=""

func _draw_states() -> void:
	chart.map_id="heting"
	chart.markers=Heting.points()
	world.companion_active=true
	var cases:int=0
	for side in ["west","east"]:
		chart.heting_bridge=side
		var terrain:Array[Rect2]=chart._heting_terrain_rects()
		_check(terrain==Heting.terrain_rects(side,false), "Chart reuses authoritative terrain union")
		_check(terrain.has(Heting.FOOT_PIER), "Chart always shows fixed foot pier")
		_check(terrain.has(Heting.WEST_PONTOON)==(side=="west") and terrain.has(Heting.EAST_PONTOON)==(side=="east"), "Chart shows only active pontoon")
		terrain.clear()
		_check(chart._heting_terrain_rects().size()==6, "Chart terrain result cannot mutate next draw")
		for previous_ending in ["release_water","warn_ferries"]:
			for ending in ["","short_ferries","open_scale"]:
				for cargo in ["","meal","sealed","reserve"]:
					world.heting_bridge=side
					world.heting_cargo=cargo
					world.heting_delivered.assign(["meal","sealed"] if not ending.is_empty() else [])
					world.heting_draft=ending
					world.heting_ending=ending
					world.mist_ending=previous_ending
					world.heting_target_id="heting_scale"
					world.change_map("heting",Vector2(820,735))
					chart.player_position=world.player_pos
					chart.current_target=world._quest_target_id()
					var previous_world_draw:int=world.draw_count
					var previous_chart_draw:int=chart.draw_count
					world.queue_redraw();chart.queue_redraw()
					await process_frame
					await process_frame
					_check(world.draw_count>previous_world_draw and chart.draw_count>previous_chart_draw, "Actual world and chart CanvasItem draw executes state combination")
					_check(chart.markers.heting_lighter.pos==Vector2(970,780), "Aftermath never moves lighter marker into water")
					cases += 1
	_check(cases==48, "Both bridges/prior endings/aftermaths and all cargo sprites draw headlessly")
