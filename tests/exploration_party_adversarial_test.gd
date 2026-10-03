extends SceneTree
const Trail = preload("res://scripts/exploration_party_trail.gd")
var failures: Array[String] = []
var checks := 0
var block_vertical := false
var accepted: Array = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func walk(p: Vector2) -> bool:
	return p.is_finite()

func step(a: Vector2, b: Vector2) -> bool:
	if block_vertical and b.y >= 9.0:
		return false
	accepted.append([a, b])
	return true

func seeded():
	var trail = Trail.new()
	check(trail.set_members(["shen"], Vector2.ZERO, Vector2.RIGHT, walk, step).ok, "seed")
	trail.record_segment(Vector2.ZERO, Vector2(100, 0))
	for i: int in range(100):
		trail.advance(1.0 / 60.0, walk, step)
	return trail

func _initialize() -> void:
	# Full out-and-back: walked distance remains positive with zero screen displacement.
	var trail = seeded()
	trail.record_segment(Vector2(100, 0), Vector2(-100, 0))
	trail.advance(0.1, walk, step)
	var before: Dictionary = trail.snapshot()[0]
	trail.advance(0.1, walk, step)
	var after: Dictionary = trail.snapshot()[0]
	check(before.position.distance_to(Vector2(85, 0)) < 0.001, "zero-net setup")
	check(after.position == before.position, "zero-net returns exactly")
	check(after.facing == before.facing and after.facing.is_finite(), "zero-net keeps prior finite facing")
	check(after.moving and absf(after.walk_distance - before.walk_distance - 30.0) < 0.001, "zero-net counts 30 walked units")

	# Collision occurs after crossing elbow: heading and phase use accepted prefix only.
	trail = seeded()
	trail.record_segment(Vector2(100, 0), Vector2(100, 100))
	trail.advance(0.1, walk, step)
	before = trail.snapshot()[0]
	block_vertical = true
	accepted.clear()
	var result: Dictionary = trail.advance(0.1, walk, step)
	after = trail.snapshot()[0]
	var actual: Vector2 = after.position - before.position
	check(result.reason == "blocked_history", "blocked after accepted prefix faults")
	check(after.position == Vector2(100, 8), "blocked prefix stops at last validated point")
	check(after.facing.dot(actual.normalized()) > 0.99999, "blocked prefix facing is accepted net movement")
	check(absf(after.walk_distance - before.walk_distance - 23.0) < 0.001, "blocked prefix phase counts 23 accepted units")
	for segment: Array in accepted:
		var d: Vector2 = segment[1] - segment[0]
		check(d.length() <= 4.001 and (absf(d.x) < 0.001 or absf(d.y) < 0.001), "blocked corner stays axis aligned and bounded")
	trail.advance(0.1, walk, step)
	check(trail.snapshot()[0].position == after.position and not trail.snapshot()[0].moving, "next blocked frame freezes")
	block_vertical = false

	# Heterogeneous deltas and non-45-degree diagonals stress budget and cursors.
	for direction: Vector2 in [Vector2(1, 1).normalized(), Vector2(-0.17, 0.985).normalized(), Vector2(0.995, -0.1).normalized()]:
		trail = Trail.new()
		trail.set_members(["shen", "tang", "qin"], Vector2.ZERO, direction, walk, step)
		var player := Vector2.ZERO
		var max_lag_error := 0.0
		for frame: int in range(2000):
			var dt := 0.1 if frame % 137 == 0 else (1.0 / 144.0 if frame % 2 == 0 else 1.0 / 30.0)
			var next := player + direction * 185.0 * dt
			var elbow := Vector2(next.x, player.y)
			trail.record_segment(player, elbow)
			trail.record_segment(elbow, next)
			check(trail.advance(dt, walk, step).ok, "uneven frame healthy")
			var debug: Dictionary = trail.debug_snapshot()
			for rank: int in range(3):
				var actor: Dictionary = debug.actors[Trail.IDS[rank]]
				max_lag_error = maxf(max_lag_error, absf(debug.head - actor.cursor - 45.0 * (rank + 1)))
			player = next
			accepted.clear()
		check(max_lag_error < 0.05, "uneven/oblique route maintains all rank lags: %f" % max_lag_error)
		print("REVIEW direction=", direction, " max_lag_error=", max_lag_error)
	if failures.is_empty():
		print("PASS exploration_party_adversarial: %d checks" % checks)
		quit(0)
	else:
		for failure: String in failures:
			printerr(failure)
		quit(1)
