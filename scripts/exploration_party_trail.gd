class_name PartyExplorationTrail
extends RefCounted
## Transient, detached pedestrian following. No HeroState or resource references.
## Supply each accepted X/Y leg separately; never pass its diagonal shortcut.
## Collision callbacks are called immediately and never retained.

const IDS: Array[String] = ["shen", "tang", "qin"]
const GAP := 45.0
# The player moves at 185 Euclidean units/s. Its accepted X/Y breadcrumbs grow
# at up to 185*sqrt(2) ~= 261.63 route units/s, so the path budget needs headroom.
const SPEED := 300.0
const MAX_DELTA := 0.1
const STEP := 4.0
const MAX_SUBSTEPS := 64
const MAX_NODES := 2048
const MAX_LENGTH := 8192.0
const RETAIN_LENGTH := 180.0
const EPS := 0.0001

var _order: Array[String] = []
var _actors: Dictionary = {}
var _points: Array[Vector2] = []
var _distances: Array[float] = []
var _head := 0.0
var _player := Vector2.ZERO
var _facing := Vector2.DOWN
var _initialized := false
var _fault := ""
var _last_reseed := ""


func set_members(manifest: Array, accepted_player: Vector2, facing: Vector2,
		can_walk: Callable, can_step: Callable) -> Dictionary:
	# Only read the ID; HP=0 and every other resource remain the caller's concern.
	var next_order: Array[String] = []
	var seen_hero := false
	for row: Variant in manifest:
		var value: Variant = row.get("id", null) if row is Dictionary else row
		if not value is String:
			return _result("invalid_manifest", false)
		var id: String = value
		if id == "hero" and not seen_hero:
			seen_hero = true
			continue
		if not IDS.has(id) or next_order.has(id):
			return _result("invalid_manifest", false)
		next_order.append(id)
	if next_order.size() > 3 or not _walkable(accepted_player, can_walk):
		return _result("invalid_player_position", true)
	if not can_step.is_valid():
		return _result("invalid_input", false)
	if not _initialized:
		_order = next_order
		return reseed(accepted_player, facing, can_walk, can_step, "initial")
	if accepted_player.distance_to(_player) > 0.01:
		return _result("relocation_required", true)
	var next_actors: Dictionary = {}
	for id: String in next_order:
		if _actors.has(id):
			next_actors[id] = _actors[id]
	# Existing actors keep their exact position, facing, phase and cursor.
	for index: int in range(next_order.size()):
		var id: String = next_order[index]
		if not next_actors.has(id):
			next_actors[id] = _seed_actor(id, index, accepted_player,
				_safe_facing(facing), can_walk, can_step, next_actors)
	_order = next_order
	_actors = next_actors
	_prune()
	return status()


func reseed(accepted_player: Vector2, facing: Vector2, can_walk: Callable,
		can_step: Callable, reason: String = "relocation") -> Dictionary:
	# Call only for a relocation, topology change, or invalid position/history.
	# The caller has already accepted the player point; this never repairs it.
	if not _walkable(accepted_player, can_walk) or not can_step.is_valid():
		return _result("invalid_player_position", true)
	_player = accepted_player
	_facing = _safe_facing(facing)
	_points = [accepted_player]
	_distances = [0.0]
	_head = 0.0
	_initialized = true
	_fault = ""
	_last_reseed = reason
	var next_actors: Dictionary = {}
	for index: int in range(_order.size()):
		var id: String = _order[index]
		var actor := _seed_actor(id, index, _player, _facing, can_walk, can_step, next_actors)
		# Relocation is not walking; preserve accumulated animation distance.
		if _actors.has(id):
			actor.walk_distance = _actors[id].walk_distance
		next_actors[id] = actor
	_actors = next_actors
	return status()


func record_segment(start: Vector2, finish: Vector2) -> Dictionary:
	if not _initialized or not start.is_finite() or not finish.is_finite():
		return _result("invalid_input", false)
	if not _fault.is_empty():
		_player = finish
		return status()
	if start.distance_to(_player) > 0.01:
		_fail("relocation_required")
		_player = finish
		return status()
	var change := finish - start
	_player = finish
	if change.x != 0.0 and change.y != 0.0:
		_fail("axis_segments_required")
		return status()
	var length := change.length()
	if length == 0.0:
		return status()
	_prune()
	var merge := false
	if _points.size() >= 2:
		var previous := _points[-1] - _points[-2]
		merge = absf(previous.cross(change)) <= EPS and previous.dot(change) > 0.0
	if (not merge and _points.size() >= MAX_NODES) or _head + length - _distances[0] > MAX_LENGTH:
		# Bounded fail-closed fallback: keep the entire still-needed path intact.
		# Do not jump actors, shortcut corners, or silently reseed for capacity.
		_fail("history_capacity")
		return status()
	_head += length
	if merge:
		_points[-1] = finish
		_distances[-1] = _head
	else:
		_points.append(finish)
		_distances.append(_head)
	return status()


func advance(delta: float, can_walk: Callable, can_step: Callable) -> Dictionary:
	for id: String in _order:
		_actors[id].moving = false
	if not _initialized:
		return status()
	if not is_finite(delta) or delta < 0.0 or not can_walk.is_valid() or not can_step.is_valid():
		return _result("invalid_input", false)
	if not _fault.is_empty():
		return status()
	if not _walkable(_player, can_walk):
		_fail("invalid_player_position")
		return status()
	for id: String in _order:
		if not _walkable(_actors[id].position, can_walk):
			_fail("invalid_position")
			return status()
	var budget := SPEED * minf(delta, MAX_DELTA)
	for index: int in range(_order.size()):
		var actor: Dictionary = _actors[_order[index]]
		var target := maxf(float(actor.cursor), _head - GAP * float(index + 1))
		_move_actor(actor, target, budget, can_walk, can_step)
		if not _fault.is_empty():
			break
	_prune()
	return status()


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _order:
		var actor: Dictionary = _actors[id]
		var view := {"id": id, "position": actor.position, "facing": actor.facing,
			"moving": actor.moving, "walk_distance": actor.walk_distance,
			"walk_phase": fposmod(float(actor.walk_distance) * 0.060, TAU)}
		view.make_read_only()
		result.append(view)
	result.make_read_only()
	return result


func status() -> Dictionary:
	return _result(_fault, not _fault.is_empty())


func debug_snapshot() -> Dictionary:
	# Detached copies for tests/diagnostics; mutation cannot affect live state.
	return {"order": _order.duplicate(), "actors": _actors.duplicate(true),
		"points": _points.duplicate(), "distances": _distances.duplicate(),
		"head": _head, "player": _player, "status": status()}


func _result(reason: String, recovery: bool) -> Dictionary:
	return {"ok": reason.is_empty(), "reason": reason, "recovery_required": recovery,
		"history_nodes": _points.size(), "last_reseed_reason": _last_reseed}


func _fail(reason: String) -> void:
	_fault = reason


func _seed_actor(id: String, index: int, player: Vector2, facing: Vector2,
		can_walk: Callable, can_step: Callable, occupied: Dictionary) -> Dictionary:
	var position := _seed_position(player, facing, index, can_walk, can_step, occupied)
	var distance := position.distance_to(player)
	return {"id": id, "position": position, "facing": facing, "moving": false,
		"walk_distance": 0.0, "cursor": _head - distance,
		"joining": distance > EPS, "join_position": player, "join_s": _head}


func _seed_position(player: Vector2, facing: Vector2, index: int,
		can_walk: Callable, can_step: Callable, occupied: Dictionary) -> Vector2:
	var rear := -facing
	var side := Vector2(-facing.y, facing.x)
	var directions: Array[Vector2] = [rear, side, -side, facing,
		(rear + side).normalized(), (rear - side).normalized(),
		(facing + side).normalized(), (facing - side).normalized()]
	# Full 45-unit ranks first. Small disconnected components fall back to a
	# compact fan around the accepted point, each joined by a validated segment.
	var radii: Array[float] = [GAP * float(index + 1), GAP, 30.0, 24.0, 18.0, 12.0, 6.0]
	for separation: float in [18.0, 9.0, 0.0]:
		for radius: float in radii:
			for direction: Vector2 in directions:
				var candidate := player + direction * radius
				if not _segment_valid(player, candidate, can_walk, can_step):
					continue
				if not _segment_valid(candidate, player, can_walk, can_step):
					continue
				var distinct := true
				for other: Dictionary in occupied.values():
					if candidate.distance_to(other.position) < separation - EPS:
						distinct = false
						break
				if distinct:
					return candidate
	# A component smaller than one actor's step can only share its safe point.
	return player


func _move_actor(actor: Dictionary, target: float, budget: float,
		can_walk: Callable, can_step: Callable) -> void:
	var update_start: Vector2 = actor.position
	for _iteration: int in range(MAX_SUBSTEPS):
		if budget <= EPS or target - float(actor.cursor) <= EPS:
			break
		var boundary: Vector2
		var boundary_s: float
		if bool(actor.joining):
			boundary = actor.join_position
			boundary_s = float(actor.join_s)
		else:
			var next_index := _next_index(float(actor.cursor))
			if next_index < 0:
				break
			boundary = _points[next_index]
			boundary_s = _distances[next_index]
		var current: Vector2 = actor.position
		var remaining := current.distance_to(boundary)
		if remaining <= EPS:
			actor.position = boundary
			actor.cursor = boundary_s
			actor.joining = false
			continue
		var amount := minf(minf(budget, STEP), minf(remaining, target - float(actor.cursor)))
		var next := current.move_toward(boundary, amount)
		if not _segment_valid(current, next, can_walk, can_step):
			_fail("blocked_history")
			break
		var displacement := next - current
		var walked := displacement.length()
		actor.position = next
		actor.cursor = float(actor.cursor) + walked
		actor.walk_distance = float(actor.walk_distance) + walked
		if walked > EPS:
			actor.moving = true
		budget -= walked
		if amount >= remaining - EPS:
			actor.position = boundary
			actor.cursor = boundary_s
			actor.joining = false
	# A diagonal input is an X/Y micro-staircase, so its final microleg is not
	# the visible heading. Use the accepted displacement of this entire update.
	# A complete out-and-back has no net direction; retain its prior heading.
	var update_displacement: Vector2 = actor.position - update_start
	if update_displacement.length_squared() > EPS * EPS:
		actor.facing = update_displacement.normalized()


func _next_index(cursor: float) -> int:
	for index: int in range(1, _distances.size()):
		if _distances[index] > cursor + EPS:
			return index
	return -1


func _prune() -> void:
	if _points.size() <= 1:
		return
	var keep_from := _head - RETAIN_LENGTH
	for id: String in _order:
		if not _actors.has(id):
			continue
		var actor: Dictionary = _actors[id]
		var needed := float(actor.join_s) if bool(actor.joining) else float(actor.cursor)
		keep_from = minf(keep_from, needed)
	while _points.size() > 1 and _distances[1] <= keep_from + EPS:
		_points.pop_front()
		_distances.pop_front()
	# Collinear compression can leave a long first segment. Trim only its
	# consumed prefix, retaining the exact point/corner and all live cursors.
	if _points.size() > 1 and keep_from > _distances[0] + EPS:
		var fraction := (keep_from - _distances[0]) / (_distances[1] - _distances[0])
		_points[0] = _points[0].lerp(_points[1], fraction)
		_distances[0] = keep_from


func _safe_facing(value: Vector2) -> Vector2:
	return value.normalized() if value.is_finite() and value.length_squared() > EPS else Vector2.DOWN


func _walkable(position: Vector2, can_walk: Callable) -> bool:
	return position.is_finite() and can_walk.is_valid() and bool(can_walk.call(position))


func _segment_valid(start: Vector2, finish: Vector2, can_walk: Callable, can_step: Callable) -> bool:
	return _walkable(start, can_walk) and _walkable(finish, can_walk) and can_step.is_valid() \
		and bool(can_step.call(start, finish))
