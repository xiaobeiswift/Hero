extends SceneTree
## Run with the current source project as --path; this test owns no state writes.
const Trail = preload("../scripts/exploration_party_trail.gd")
const Heting = preload("res://scripts/heting_region.gd")
const Lightness = preload("res://scripts/lightness_rules.gd")
var bridge := "west"
var checks := 0
var failures: Array[String] = []
var moved_segments: Array = []

func _initialize() -> void:
	_foot_pier()
	_bridge_removal()
	_reed_islet()
	if failures.is_empty():
		print("PASS exploration_party_source_collision: %d checks" % checks)
		quit(0)
	else:
		for failure: String in failures:
			printerr(failure)
		quit(1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func pedestrian_walk(point: Vector2) -> bool:
	return Heting.walkable(point, bridge, false)

func pedestrian_step(a: Vector2, b: Vector2) -> bool:
	moved_segments.append([a, b])
	return Heting.can_step(a, b, bridge, false)

func _foot_pier() -> void:
	var trail = Trail.new()
	var player := Vector2(805, 665)
	check(trail.set_members(["shen", "tang", "qin"], player, Vector2.UP, pedestrian_walk, pedestrian_step).ok, "Heting seed valid")
	check(not Heting.walkable(Vector2(805, 510), bridge, true), "foot pier rejects cargo route")
	check(Heting.walkable(Vector2(805, 510), bridge, false), "foot pier accepts companions as pedestrians")
	moved_segments.clear()
	for index: int in range(90):
		var next := player + Vector2(0, -3)
		check(pedestrian_step(player, next), "accepted player pedestrian step")
		check(trail.record_segment(player, next).ok, "pier segment recorded")
		check(trail.advance(1.0 / 60.0, pedestrian_walk, pedestrian_step).ok, "party crosses pedestrian pier")
		player = next
	for index: int in range(120):
		trail.advance(1.0 / 60.0, pedestrian_walk, pedestrian_step)
	for row: Dictionary in trail.snapshot():
		check(Heting.walkable(row.position, bridge, false), "each follower valid on current pedestrian geometry")
		check(row.position.x == 805.0, "narrow pier keeps followers on route")
	for segment: Array in moved_segments:
		check(Heting.can_step(segment[0], segment[1], bridge, false), "each actual segment pedestrian-valid")

func _bridge_removal() -> void:
	var trail = Trail.new()
	var player := Vector2(820, 725)
	check(trail.set_members(["shen", "tang", "qin"], player, Vector2.RIGHT, pedestrian_walk, pedestrian_step).ok, "island party seed")
	# Relocate player only through an accepted recorded west-bridge route; keep
	# followers on its previous route until one is standing on the removable deck.
	var finish := Vector2(200, 725)
	check(Heting.can_step(player, finish, "west", false), "source west pontoon route accepted")
	check(trail.record_segment(player, finish).ok, "source bridge route recorded")
	player = finish
	for index: int in range(80):
		trail.advance(1.0 / 60.0, pedestrian_walk, pedestrian_step)
	var on_old_deck := false
	for row: Dictionary in trail.snapshot():
		on_old_deck = on_old_deck or Heting.WEST_PONTOON.has_point(row.position)
	check(on_old_deck, "test has followers on removable source bridge")
	bridge = "east"
	var outcome: Dictionary = trail.advance(1.0 / 60.0, pedestrian_walk, pedestrian_step)
	check(outcome.recovery_required and outcome.reason == "invalid_position", "source bridge removal detected")
	check(trail.reseed(player, Vector2.LEFT, pedestrian_walk, pedestrian_step, "topology").ok, "source bridge recovery")
	for row: Dictionary in trail.snapshot():
		check(Heting.can_step(player, row.position, "east", false), "reseeded on connected current shore")
	check(trail.debug_snapshot().player == player, "bridge recovery leaves accepted player unchanged")
	bridge = "west"

func islet_walk(point: Vector2) -> bool:
	return Lightness.on_islet(point)

func islet_step(a: Vector2, b: Vector2) -> bool:
	var pieces := maxi(1, int(ceil(a.distance_to(b) / 1.0)))
	for index: int in range(pieces + 1):
		if not Lightness.on_islet(a.lerp(b, float(index) / pieces)):
			return false
	return true

func _reed_islet() -> void:
	var trail = Trail.new()
	check(trail.set_members(["qin", "shen", "tang"], Lightness.LANDING, Vector2.RIGHT, islet_walk, islet_step).ok, "current reed-islet source geometry seeds")
	var positions: Array[Vector2] = []
	for row: Dictionary in trail.snapshot():
		check(Lightness.on_islet(row.position), "compact source islet follower valid")
		check(islet_step(Lightness.LANDING, row.position), "compact source islet follower connected")
		check(not positions.has(row.position), "compact source islet follower distinct")
		positions.append(row.position)
	check(trail.debug_snapshot().order == ["qin", "shen", "tang"], "source islet preserves selected order")
