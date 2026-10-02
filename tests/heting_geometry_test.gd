extends SceneTree
const Region = preload("res://scripts/heting_region.gd")
var checks := 0
var failures := 0
var total_reachable := 0

func _initialize() -> void:
	var expected := {
		"return_mistwood": Vector2(150, 335),
		"heting_dispatch": Vector2(535, 350),
		"heting_winch": Vector2(820, 735),
		"heting_cargo": Vector2(665, 620),
		"heting_lighter": Vector2(970, 780),
		"heting_relief": Vector2(230, 780),
		"heting_scale": Vector2(1390, 600),
	}
	var locations := Region.points()
	_check(locations.size() == 7, "Exactly seven interaction points")
	for id in expected:
		_check(locations.has(id) and locations[id].pos == expected[id], "Exact interaction point: " + id)
	_check(Region.WORLD_SIZE == Vector2(1600, 1050), "World dimensions remain 1600 by 1050")
	_check(Region.safe_spawn() == Vector2(180, 350), "Exact entry safe spawn")
	_check(Region.NORTH_LAND == Rect2(30, 155, 1540, 295), "North street design geometry")
	_check(Region.WEST_LAND == Rect2(30, 435, 330, 580), "West bank design geometry")
	_check(Region.EAST_LAND == Rect2(1280, 435, 290, 580), "East bank design geometry")
	_check(Region.CARGO_ISLAND == Rect2(590, 565, 440, 270), "Central unloading deck design geometry")
	_check(Region.FOOT_PIER == Rect2(770, 435, 70, 145), "Fixed pedestrian pier design geometry")
	_check(Region.WEST_PONTOON == Rect2(345, 690, 260, 76), "West pontoon design geometry")
	_check(Region.EAST_PONTOON == Rect2(1015, 690, 280, 76), "East pontoon design geometry")
	locations.heting_cargo.pos = Vector2.ZERO
	_check(Region.points().heting_cargo.pos == expected.heting_cargo, "Point lookups are independent")
	var all_routes := [
		[Vector2(180,350), Vector2(535,350)],
		[Vector2(665,620), Vector2(675,735), Vector2(820,735)],
		[Vector2(820,735), Vector2(970,780)],
		[Vector2(230,780), Vector2(330,780), Vector2(330,350), Vector2(1390,350), Vector2(1530,350), Vector2(1530,600), Vector2(1390,600)],
	]
	for side in ["west", "east"]:
		for loaded in [false, true]:
			var state := "%s/%s" % [side, "loaded" if loaded else "empty"]
			for id in expected:
				_check(Region.walkable(expected[id], side, loaded), state + " landmark footprint is safe: " + id)
			_check(Region.walkable(Region.safe_spawn(), side, loaded), state + " safe entry")
			_check(Region.valid_cart_position(Region.LOADED_SAFE, side), state + " loaded recovery stays on island")
			for p in [Vector2(NAN,500), Vector2(INF,500), Vector2(500,-INF), Vector2(29,500), Vector2(1571,500), Vector2(500,154), Vector2(500,1016), Vector2(465,520), Vector2(1135,810), Vector2(809,925)]:
				_check(not Region.walkable(p, side, loaded), state + " water/invalid/outside rejected: " + str(p))
			for building in Region.BUILDINGS:
				_check(not Region.walkable(building.get_center(), side, loaded), state + " solid building footprint")
				_check(not Region.walkable(Vector2(building.get_center().x, building.end.y + 3), side, loaded), state + " seven-pixel wall clearance")
			_check(Region.walkable(Vector2(805,505), side, loaded) == not loaded, state + " real foot-only gate")
			_check(Region.walkable(Vector2(475,728), side, loaded) == (side == "west"), state + " painted west pontoon state")
			_check(Region.walkable(Vector2(1149,728), side, loaded) == (side == "east"), state + " painted east pontoon state")
			_check(not Region.can_step(Vector2(650,620), Vector2(230,780), side, loaded), state + " diagonal cannot skip water")
			_check(not Region.can_step(Vector2(535,180), Vector2(535,300), side, loaded), state + " large step cannot skip warehouse")
			_check(Region.can_step(Vector2(805,425), Vector2(805,596), side, loaded) == not loaded, state + " continuous pier traversal")
			for route in all_routes:
				_route(route, side, loaded, state)
			if not loaded:
				_route([Vector2(535,350), Vector2(805,350), Vector2(805,595), Vector2(665,620)], side, false, state + " foot shortcut")
			var bridge_route := [Vector2(820,735), Vector2(615,735), Vector2(350,735), Vector2(230,735), Vector2(230,780)] if side == "west" else [Vector2(820,735), Vector2(1020,735), Vector2(1330,735), Vector2(1390,600)]
			_route(bridge_route, side, loaded, state + " live pontoon")
			var visited := _reachable(side, loaded)
			total_reachable += visited.size()
			for id in expected:
				var found := false
				for p in visited:
					if p.distance_to(expected[id]) <= 8.0 and Region.can_step(p, expected[id], side, loaded):
						found = true
						break
				_check(found, state + " BFS reaches NPC/source/receiver/exit: " + id)
			# Changing bridge or loading on a stale bridge/pier repairs coordinates,
			# while a legal loaded position is kept exactly; caller cargo is untouched.
			var legal := Vector2(665,620)
			_check(Region.repaired_position(legal, side, loaded) == legal, state + " legal save location preserved")
			for bad in [Vector2(NAN,0), Vector2(900,930), Vector2(475,728) if side == "east" else Vector2(1149,728)]:
				var fixed := Region.repaired_position(bad, side, loaded)
				_check(fixed == (Region.LOADED_SAFE if loaded else Region.ENTRY), state + " prescribed recovery destination")
				_check(Region.walkable(fixed, side, loaded), state + " repaired save is walkable")
			_check(Region.repaired_position(Vector2(805,505), side, true) == Region.LOADED_SAFE, state + " stale loaded foot-pier save repairs to cargo deck")
			for pair in [[Vector2(805,505), Vector2(745,515)], [Vector2(350,735), Vector2(410,750)], [Vector2(600,700), Vector2(560,630)], [Vector2(1390,600), Vector2(1360,620)]]:
				var safe := Region.safe_companion_position(pair[0], pair[1], side)
				_check(Region.walkable(safe, side), state + " companion target cannot stay in water")
				if Region.walkable(pair[0], side):
					_check(Region.can_step(pair[0], safe, side), state + " companion segment stays on current surface")
	# Actor-centre tests exercise every navigable edge, including overlapping seams.
	for side in ["west", "east"]:
		for r in [Region.WEST_PONTOON if side == "west" else Region.EAST_PONTOON, Region.FOOT_PIER]:
			var p: Vector2 = r.get_center()
			_check(Region.walkable(p, side), "Shared paint/collision rect interior")
		_check(not Region.walkable(Vector2(475,692), side) if side == "west" else not Region.walkable(Vector2(1140,692), side), "Actor footprint cannot hang off a pontoon edge")
	_check(not Region.can_step(Vector2(NAN,0), Region.ENTRY, "west"), "NaN continuous motion rejected")
	_check(not Region.can_step(Region.ENTRY, Vector2(INF,0), "west"), "Infinite continuous motion rejected")
	_check(Region.location(Vector2(805,505)) == "鹤汀埠 · 北步栈", "Foot pier has its own location")
	_check(Region.location(Vector2(970,780)) == "鹤汀埠 · 南泊短驳", "Lighter has its own location")
	print("%s: %d Heting geometry assertions; %d reachable BFS samples across west/east × empty/loaded" % ["PASS" if failures == 0 else "FAIL", checks, total_reachable])
	quit(0 if failures == 0 else 1)

func _route(route: Array, side: String, loaded: bool, label: String) -> void:
	for i in range(route.size() - 1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / 5.0)))
		for j in range(steps + 1):
			var p := a.lerp(b, float(j) / steps)
			_check(Region.walkable(p, side, loaded), label + " contractual route sample " + str(p))
		_check(Region.can_step(a, b, side, loaded), label + " contractual continuous route")

func _reachable(side: String, loaded: bool) -> Dictionary:
	var queue: Array[Vector2] = [Region.safe_spawn()]
	var visited := {queue[0]: true}
	var examined := {queue[0]: true}
	var cursor := 0
	while cursor < queue.size():
		var p := queue[cursor]
		cursor += 1
		for offset in [Vector2(8,0), Vector2(-8,0), Vector2(0,8), Vector2(0,-8)]:
			var next: Vector2 = p + offset
			if examined.has(next):
				continue
			examined[next] = true
			if Region.can_step(p, next, side, loaded):
				visited[next] = true
				queue.append(next)
	return visited

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
