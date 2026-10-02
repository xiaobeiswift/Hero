extends SceneTree
const Trail = preload("res://scripts/exploration_party_trail.gd")
var checks := 0
var failures: Array[String] = []
var surfaces: Array[Rect2] = []
var walls: Array[Rect2] = []
var ellipse := false
var logged_steps: Array = []

func _initialize() -> void:
	_counts_and_resources()
	_membership()
	_corner()
	_u_turn()
	_blocked_history()
	_invalid_position()
	_limits_and_invalid_inputs()
	_history_bounds()
	_compact_components()
	_topology_relocation()
	if failures.is_empty():
		print("PASS exploration_party_trail: %d checks" % checks)
		quit(0)
	else:
		for failure: String in failures:
			printerr(failure)
		printerr("FAIL exploration_party_trail: %d failures / %d checks" % [failures.size(), checks])
		quit(1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func open_world() -> void:
	surfaces.clear()
	walls.clear()
	ellipse = false
	logged_steps.clear()

func walk(p: Vector2) -> bool:
	if not p.is_finite():
		return false
	if ellipse and (p / Vector2(40, 36)).length_squared() > 1.0:
		return false
	var included := surfaces.is_empty()
	for rect: Rect2 in surfaces:
		included = included or rect.has_point(p)
	for rect: Rect2 in walls:
		if rect.has_point(p):
			return false
	return included

func step(a: Vector2, b: Vector2) -> bool:
	logged_steps.append([a, b])
	var count := maxi(1, int(ceil(a.distance_to(b) / 0.5)))
	for index: int in range(count + 1):
		if not walk(a.lerp(b, float(index) / count)):
			return false
	return true

func create(ids: Array, position := Vector2.ZERO, facing := Vector2.RIGHT):
	var trail = Trail.new()
	check(trail.set_members(ids, position, facing, walk, step).ok, "valid roster seeds")
	logged_steps.clear()
	return trail

func move(trail, end: Vector2, dt := 1.0 / 60.0, stride := 3.0) -> void:
	var player: Vector2 = trail.debug_snapshot().player
	while player.distance_to(end) > 0.001:
		var next := player.move_toward(end, stride)
		check(trail.record_segment(player, next).ok, "accepted segment records")
		check(trail.advance(dt, walk, step).ok, "accepted route advances")
		player = next

func settle(trail) -> void:
	for index: int in range(150):
		trail.advance(1.0 / 60.0, walk, step)

func _counts_and_resources() -> void:
	for count: int in range(1, 4):
		open_world()
		var manifest: Array = []
		for index: int in range(count):
			manifest.append({"id": Trail.IDS[index], "hp": 0, "qi": index})
		var before: Array = manifest.duplicate(true)
		var trail = create(manifest)
		move(trail, Vector2(450, 0))
		settle(trail)
		var view: Array = trail.snapshot()
		check(view.size() == count and view.is_read_only(), "exact read-only follower count")
		for index: int in range(count):
			var row: Dictionary = view[index]
			check(row.id == Trail.IDS[index] and row.is_read_only(), "ID and row immutability")
			check(row.position.distance_to(Vector2(450 - 45 * (index + 1), 0)) < 0.02, "45-unit rank gap")
			check(row.walk_distance > 0.0 and not row.moving, "real distance and stopped animation")
			check(row.facing.distance_to(Vector2.RIGHT) < 0.01, "real movement direction")
		check(manifest == before, "HP0 selected and resource manifest unchanged")
		var debug: Dictionary = trail.debug_snapshot()
		debug.actors[manifest[0].id].position = Vector2(999, 999)
		check(trail.snapshot()[0].position != Vector2(999, 999), "debug copies cannot mutate live actors")

func _membership() -> void:
	open_world()
	var trail = create(["hero", "shen", "tang"])
	move(trail, Vector2(90, 0))
	var before: Dictionary = trail.debug_snapshot().actors
	check(trail.set_members(["tang", "shen", "qin"], Vector2(90, 0), Vector2.RIGHT, walk, step).ok, "reorder and add")
	var after: Dictionary = trail.debug_snapshot().actors
	for id: String in ["shen", "tang"]:
		check(before[id] == after[id], "reorder retains all per-ID transient state")
	check(trail.debug_snapshot().order == ["tang", "shen", "qin"], "selected order preserved")
	check(trail.set_members(["qin", "shen"], Vector2(90, 0), Vector2.RIGHT, walk, step).ok, "remove member")
	check(not trail.debug_snapshot().actors.has("tang") and trail.snapshot().size() == 2, "removed immediately")
	before = trail.debug_snapshot()
	check(not trail.set_members(["shen", "shen"], Vector2(90, 0), Vector2.RIGHT, walk, step).ok, "duplicate rejected")
	check(not trail.set_members(["intruder"], Vector2(90, 0), Vector2.RIGHT, walk, step).ok, "unknown rejected")
	check(trail.debug_snapshot() == before, "invalid manifests atomic")
	var cursor: float = before.actors.shen.cursor
	move(trail, Vector2(300, 0))
	settle(trail)
	check(trail.debug_snapshot().actors.shen.cursor >= cursor, "reordered cursor never rewinds")
	check(trail.snapshot()[0].position.distance_to(Vector2(255, 0)) < 0.02, "new first rank catches up")
	check(trail.snapshot()[1].position.distance_to(Vector2(210, 0)) < 0.02, "retained second rank catches up")
	check(trail.set_members([], Vector2(300, 0), Vector2.RIGHT, walk, step).ok and trail.snapshot().is_empty(), "empty roster removes all")

func _corner() -> void:
	open_world()
	surfaces = [Rect2(-10, -5, 215, 10), Rect2(195, -5, 10, 220)]
	var trail = create(["shen", "tang", "qin"], Vector2(140, 0))
	move(trail, Vector2(200, 0))
	move(trail, Vector2(200, 180))
	settle(trail)
	var points: Array = trail.debug_snapshot().points
	check(points.has(Vector2(200, 0)), "elbow retained until rearmost follower consumes it")
	for index: int in range(3):
		check(trail.snapshot()[index].position.distance_to(Vector2(200, 135 - index * 45)) < 0.02, "corner rank stays on corridor")
	for segment: Array in logged_steps:
		var change: Vector2 = segment[1] - segment[0]
		check(change.length() <= Trail.STEP + 0.01, "every movement collision substep bounded")
		check(absf(change.x) < 0.001 or absf(change.y) < 0.001, "no diagonal shortcut at elbow")

func _u_turn() -> void:
	open_world()
	var trail = create(["shen", "tang", "qin"])
	var prior: Dictionary = trail.debug_snapshot().actors
	for end: Vector2 in [Vector2(180, 0), Vector2.ZERO, Vector2(180, 0), Vector2(180, 90)]:
		move(trail, end)
		var current: Dictionary = trail.debug_snapshot().actors
		for id: String in Trail.IDS:
			check(current[id].cursor >= prior[id].cursor, "U-turn/repeated coordinate cursor monotonic")
		prior = current
	settle(trail)
	check(trail.snapshot()[0].position.distance_to(Vector2(180, 45)) < 0.02, "first actor follows latest U-turn route")
	check(trail.snapshot()[1].position.distance_to(Vector2(180, 0)) < 0.02, "second actor reaches elbow")
	check(trail.snapshot()[2].position.distance_to(Vector2(135, 0)) < 0.02, "third actor remains on correct historical leg")

func _blocked_history() -> void:
	open_world()
	var trail = create(["shen"])
	trail.record_segment(Vector2.ZERO, Vector2(200, 0))
	walls = [Rect2(90, -100, 10, 200)]
	for index: int in range(100):
		trail.advance(0.1, walk, step)
	var view: Dictionary = trail.snapshot()[0]
	check(trail.status().reason == "blocked_history" and trail.status().recovery_required, "blocked history reports recovery")
	check(view.position.x < 90, "blocked actor cannot cross wall")
	var stopped: Vector2 = view.position
	trail.advance(0.1, walk, step)
	check(trail.snapshot()[0].position == stopped and not trail.snapshot()[0].moving, "blocked trail freezes safely")
	check(trail.reseed(Vector2(200, 0), Vector2.RIGHT, walk, step, "topology").ok, "explicit topology recovery")
	check(trail.snapshot()[0].position.x > 100, "reseed stays connected to accepted player")
	check(trail.debug_snapshot().player == Vector2(200, 0), "recovery does not move accepted player")

func _invalid_position() -> void:
	open_world()
	var trail = create(["shen", "tang", "qin"])
	var prior := trail.snapshot()
	walls = [Rect2(-50, -5, 10, 10)]
	check(trail.advance(0.1, walk, step).reason == "invalid_position", "newly invalid actor detected")
	check(trail.snapshot()[0].position == prior[0].position, "invalid position never silently teleported")
	check(trail.reseed(Vector2.ZERO, Vector2.RIGHT, walk, step, "invalid_position").ok, "explicit invalid-position recovery")
	for row: Dictionary in trail.snapshot():
		check(walk(row.position), "recovered actor valid")

func _limits_and_invalid_inputs() -> void:
	open_world()
	var trail = create(["shen", "tang", "qin"])
	trail.record_segment(Vector2.ZERO, Vector2(500, 0))
	var before: Array = trail.snapshot()
	trail.advance(100000.0, walk, step)
	var after: Array = trail.snapshot()
	for index: int in range(3):
		check(after[index].walk_distance - before[index].walk_distance <= Trail.SPEED * Trail.MAX_DELTA + 0.01, "long delta bounded")
		check(after[index].moving, "bounded real motion animates")
	var positions: Dictionary = trail.debug_snapshot().actors
	for delta: float in [NAN, INF, -1.0]:
		check(trail.advance(delta, walk, step).reason == "invalid_input", "invalid delta rejected")
		check(trail.snapshot()[0].position == positions.shen.position, "invalid delta cannot move")
	before = trail.snapshot()
	check(not trail.record_segment(Vector2(INF, 0), Vector2(1, 0)).ok, "nonfinite segment rejected")
	check(not trail.reseed(Vector2(NAN, 0), Vector2.RIGHT, walk, step).ok, "nonfinite seed rejected")
	check(not trail.set_members(["qin"], Vector2(INF, 0), Vector2.RIGHT, walk, step).ok, "nonfinite roster anchor rejected")
	check(trail.snapshot() == before, "nonfinite inputs preserve actors")
	check(trail.record_segment(Vector2(500, 0), Vector2(510, 10)).reason == "axis_segments_required", "diagonal recording rejected")
	check(trail.advance(0.1, walk, step).recovery_required, "diagonal fails closed")
	trail.reseed(Vector2(510, 10), Vector2(INF, NAN), walk, step, "relocation")
	check(trail.snapshot()[0].facing == Vector2.DOWN, "nonfinite facing has deterministic fallback")
	check(trail.record_segment(Vector2(600, 10), Vector2(601, 10)).reason == "relocation_required", "unannounced relocation rejected")
	check(trail.debug_snapshot().player == Vector2(601, 10), "accepted point retained without fabricated connecting segment")

func _history_bounds() -> void:
	open_world()
	var trail = create(["shen", "tang", "qin"])
	var player := Vector2.ZERO
	for index: int in range(5000):
		var elbow := player + Vector2(1.5, 0)
		var end := elbow + Vector2(0, 1.5)
		trail.record_segment(player, elbow)
		trail.record_segment(elbow, end)
		trail.advance(1.0 / 60.0, walk, step)
		player = end
		logged_steps.clear()
	check(trail.status().ok, "long staircase history advances without overflow")
	check(trail.status().history_nodes <= 125, "consumed staircase history pruned")
	var debug: Dictionary = trail.debug_snapshot()
	check(debug.distances[0] <= debug.actors.qin.cursor + 0.001, "rearmost cursor retained after pruning")
	# Continuous long straight routes are coalesced and trim consumed prefixes.
	trail.reseed(Vector2.ZERO, Vector2.RIGHT, walk, step, "relocation")
	for index: int in range(4000):
		trail.record_segment(Vector2(index * 3, 0), Vector2((index + 1) * 3, 0))
		trail.advance(1.0 / 60.0, walk, step)
		logged_steps.clear()
	check(trail.status().ok and trail.status().history_nodes <= 2, "straight route prefix trimming is bounded")
	trail.reseed(Vector2.ZERO, Vector2.RIGHT, walk, step, "relocation")
	player = Vector2.ZERO
	var unchanged: Array = trail.snapshot()
	for index: int in range(3000):
		var end := player + (Vector2(1, 0) if index % 2 == 0 else Vector2(0, 1))
		trail.record_segment(player, end)
		player = end
	check(trail.status().reason == "history_capacity", "unconsumed node cap reports bounded fallback")
	check(trail.status().history_nodes == Trail.MAX_NODES, "hard node cap respected")
	check(trail.snapshot() == unchanged, "capacity fallback never moves actors")
	trail.advance(0.1, walk, step)
	check(trail.snapshot() == unchanged, "capacity fallback frozen on advance")
	trail.reseed(Vector2.ZERO, Vector2.RIGHT, walk, step, "relocation")
	check(trail.record_segment(Vector2.ZERO, Vector2(9000, 0)).reason == "history_capacity", "hard arc-length cap respected")
	check(trail.status().history_nodes == 1, "oversize segment never stored")

func _compact_components() -> void:
	open_world()
	ellipse = true
	var trail = create(["shen", "tang", "qin"], Vector2.ZERO, Vector2.DOWN)
	var first: Array = trail.snapshot()
	for row: Dictionary in first:
		check(walk(row.position) and step(Vector2.ZERO, row.position), "80x72 island connected seed")
		check(row.position.length() <= 36.0, "island uses compact placement")
	check(first[0].position != first[1].position and first[1].position != first[2].position, "island distinct candidates")
	trail.reseed(Vector2.ZERO, Vector2.DOWN, walk, step, "relocation")
	check(trail.snapshot() == first, "compact seed deterministic")
	move(trail, Vector2(25, 0), 1.0 / 60.0, 1.0)
	move(trail, Vector2(-25, 0), 1.0 / 60.0, 1.0)
	settle(trail)
	for row: Dictionary in trail.snapshot():
		check(walk(row.position), "island motion stays on connected land")
	open_world()
	surfaces = [Rect2(-5, -300, 10, 600)]
	trail = create(["shen", "tang", "qin"])
	move(trail, Vector2(0, -180))
	settle(trail)
	for row: Dictionary in trail.snapshot():
		check(walk(row.position) and absf(row.position.x) < 0.01, "narrow component remains on pedestrian path")
	open_world()
	surfaces = [Rect2(-0.1, -0.1, 0.2, 0.2)]
	trail = create(["shen", "tang", "qin"])
	for row: Dictionary in trail.snapshot():
		check(row.position == Vector2.ZERO, "tiny component safely shares only accepted point")

func _topology_relocation() -> void:
	open_world()
	surfaces = [Rect2(-200, -40, 160, 80), Rect2(40, -40, 160, 80), Rect2(-50, -10, 100, 20)]
	var trail = create(["shen", "tang", "qin"], Vector2(60, 0))
	check(trail.snapshot()[0].position == Vector2(15, 0), "first actor initially on bridge")
	surfaces.pop_back()
	check(trail.advance(0.1, walk, step).reason == "invalid_position", "removed bridge invalidates follower")
	check(trail.reseed(Vector2(60, 0), Vector2.RIGHT, walk, step, "topology").ok, "removed bridge safely reseeded")
	for row: Dictionary in trail.snapshot():
		check(row.position.x >= 40 and step(Vector2(60, 0), row.position), "bridge recovery stays on accepted shore")
	check(trail.debug_snapshot().player == Vector2(60, 0), "topology cannot repair or move player")
	var distance: float = trail.snapshot()[0].walk_distance
	trail.reseed(Vector2(100, 20), Vector2.UP, walk, step, "teleport")
	check(trail.snapshot()[0].walk_distance == distance and not trail.snapshot()[0].moving, "explicit relocation does not invent walking")
