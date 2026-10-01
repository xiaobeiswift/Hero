extends SceneTree
## Independent headless geometry/input audit. Isolated save adapter; no normal player saves or GUI.
const World = preload("res://scripts/world.gd")
const L = preload("res://scripts/lightness_rules.gd")

class AuditState:
	extends "res://scripts/game_state.gd"
	const AUDIT_PATH = "user://lightness-independent-geometry.json"
	func save_game(path: String = SAVE_PATH) -> Error:
		return super.save_game(AUDIT_PATH if path == SAVE_PATH else path)
	func load_game(path: String = SAVE_PATH) -> Error:
		return super.load_game(AUDIT_PATH if path == SAVE_PATH else path)
	func has_save() -> bool:
		return FileAccess.file_exists(AUDIT_PATH)

var checks: int = 0
var failures: int = 0
var world

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	world = World.new()
	root.add_child(world)
	world.set_process(false)
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	_authored_geometry()
	_connectivity()
	_interaction_components()
	_actual_long_frame_input()
	_companion_boundary()
	_map_and_recovery()
	await _pending_receipt_learning()
	world.queue_free()
	await process_frame
	print("%s: %d independent lightness geometry/input checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _authored_geometry() -> void:
	for p in [L.SHORE, L.LANDING, L.RELIC_POSITION, world.interactables.reed_return.pos]:
		_check(world._can_walk(p), "Authored point is safe: %s" % p)
	for x in range(1441, 1474):
		_check(not world._can_walk(Vector2(x, 930)), "Water gap remains solid at x=%d" % x)
	_check(world._can_step(Vector2(1400, 775), Vector2(1535, 775)), "Existing ferry dock still supports walking")
	_check(not world._can_step(Vector2(820, 484), Vector2(1170, 484)), "Long movement cannot cross existing pond")
	_check(not world._can_step(Vector2(160, 250), Vector2(450, 250)), "Long movement cannot cross clinic")
	_check(not world._can_step(L.SHORE, L.LANDING) and not world._can_step(L.LANDING, L.SHORE), "Water crossing requires explicit travel in both directions")
	for bad in [Vector2(NAN, 930), Vector2(INF, 930), Vector2(1600, 930), Vector2(1500, 1050)]:
		_check(not world._can_step(L.LANDING, bad), "Invalid/outside endpoint rejected")

func _flood(start: Vector2) -> Dictionary:
	var queue: Array[Vector2] = [start]
	var visited: Dictionary = {start: true}
	var cursor: int = 0
	while cursor < queue.size():
		var p: Vector2 = queue[cursor]
		cursor += 1
		for offset in [Vector2(10, 0), Vector2(-10, 0), Vector2(0, 10), Vector2(0, -10)]:
			var next: Vector2 = p + offset
			if not visited.has(next) and world._can_step(p, next):
				visited[next] = true
				queue.append(next)
	return visited

func _connectivity() -> void:
	var mainland: Dictionary = _flood(Vector2(460, 430))
	_check(mainland.has(L.SHORE), "Shore source has an ordinary route from village spawn")
	var mainland_touches_islet: bool = false
	for p: Vector2 in mainland:
		if L.on_islet(p): mainland_touches_islet = true
	_check(not mainland_touches_islet, "Mainland flood fill cannot enter island")
	var islet: Dictionary = _flood(L.LANDING)
	var island_reaches_mainland: bool = false
	for p: Vector2 in islet:
		if not L.on_islet(p): island_reaches_mainland = true
	_check(not island_reaches_mainland, "Island flood fill cannot escape to mainland")
	for id in ["reed_return", "reed_relic"]:
		var reachable: bool = false
		for p: Vector2 in islet:
			if p.distance_to(world.interactables[id].pos) < 10: reachable = true
		_check(reachable, "Island paths reach %s" % id)

func _interaction_components() -> void:
	for x in range(1345, 1441, 5):
		for y in range(855, 1006, 5):
			var p := Vector2(x, y)
			if not world._can_walk(p): continue
			world.player_pos = p
			world._update_nearby()
			_check(world.nearby_id not in ["reed_return", "reed_relic"], "Mainland cannot select across-water island interaction")
	for id in ["reed_return", "reed_relic"]:
		world.teleport(world.interactables[id].pos)
		_check(world.nearby_id == id, "Each island interaction is independently selectable: %s" % id)
	world.teleport(L.SHORE - Vector2(75, 0))
	_check(world.nearby_id != "reed_cross", "Exact 75-unit shore boundary does not select the crossing")
	world.teleport(L.SHORE - Vector2(74.9, 0))
	_check(world.nearby_id == "reed_cross", "Just-inside shore radius selects crossing")

func _actual_long_frame_input() -> void:
	world.active = true
	for delta in [1.0 / 60.0, 0.2, 1.0]:
		for directions in [["move_right"], ["move_right", "move_up"], ["move_right", "move_down"]]:
			world.teleport(Vector2(1440, 930))
			for action in directions: Input.action_press(action)
			world._process(delta)
			for action in directions: Input.action_release(action)
			_check(not L.on_islet(world.player_pos) and world._can_walk(world.player_pos), "Actual long-frame directional input cannot enter island")
		for directions in [["move_left"], ["move_left", "move_up"], ["move_left", "move_down"]]:
			world.teleport(Vector2(1474, 930))
			for action in directions: Input.action_press(action)
			world._process(delta)
			for action in directions: Input.action_release(action)
			_check(L.on_islet(world.player_pos), "Actual long-frame directional input cannot leave island")
	world.teleport(Vector2(500, 420))
	Input.action_press("move_right")
	world._process(0.1)
	Input.action_release("move_right")
	_check(world.player_pos.is_equal_approx(Vector2(518.5, 420)), "Real ordinary movement still advances at original speed")

func _companion_boundary() -> void:
	world.companion_active = true
	for i in range(72):
		var angle: float = i * TAU / 72.0
		var p: Vector2 = L.ISLET_CENTER + Vector2(cos(angle), sin(angle)) * L.ISLET_RADIUS * 0.999
		world.teleport(p)
		_check(L.on_islet(world.companion_pos), "Teleport companion stays inside at every island edge")
		for facing in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			world.facing = facing
			world._process(0.25)
			_check(L.on_islet(world.companion_pos), "Follower stays inside for every edge and facing")
	world.companion_active = false

func _map_and_recovery() -> void:
	world.teleport(Vector2(1460, 930))
	_check(world._can_walk(world.player_pos), "Stale water coordinate is repaired onto walkable land")
	if L.on_islet(world.player_pos):
		_check(world.nearby_id in ["reed_return", "reed_relic"], "Recovered island placement retains accessible interaction")
	for id in ["sluice", "frostbridge", "mistwood"]:
		world.change_map(id, Vector2(150, 550))
		_check(not world.interactables.has("reed_cross") and not world.interactables.has("reed_return") and not world.interactables.has("reed_relic"), "Island markers never leak to %s" % id)
	world.change_map("qingwei", L.SHORE)
	_check(world.interactables.has("reed_cross") and world.interactables.has("reed_return") and world.interactables.has("reed_relic"), "All island interactions survive return to cached village")

func _find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var result: Button = _find_button(child, label)
		if result != null: return result
	return null

func _press(game, label: String) -> void:
	var button: Button = _find_button(game.overlay, label)
	_check(button != null, "Expected real modal button: %s" % label)
	if button != null: button.pressed.emit()

func _pending_receipt_learning() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.state = AuditState.new()
	game._new_game()
	game.state.gain_xp(180)
	game.state.choose_sect("听潮阁")
	game.state.quest_stage = 6
	game.state.ending = "守望"
	game.state.sect_trial_won = true
	game.world.teleport(Vector2(650, 720))
	game._process(0.0)
	var before: Dictionary = game.state.to_dict()
	game._interact("mentor")
	_check(_find_button(game.overlay, "领取内门荐记") != null and _find_button(game.overlay, "稍后领取") != null, "Pending receipt retains original claim and postpone options")
	_press(game, "轻身基础")
	_press(game, "修习踏苇行")
	var expected: Dictionary = before.duplicate(true)
	expected.lightness_unlocked = true
	_check(game.state.to_dict() == expected, "Learning while promotion pending changes only the technique flag")
	game._load()
	_check(game.state.to_dict() == expected and game.state.sect_rank == 1 and game.state.sect_trial_won, "Pending receipt and free lesson survive autosave reload together")
	game._interact("mentor")
	_press(game, "稍后领取")
	_check(game.state.to_dict() == expected, "Postponing after learning preserves unclaimed receipt and all resources")
	game._interact("mentor")
	_press(game, "领取内门荐记")
	_check(game.state.sect_rank == 2 and game.state.sect_merit == int(before.sect_merit) + 3 and game.state.defense == int(before.defense) + 1 and game.state.max_qi == int(before.max_qi) + 1 and game.state.lightness_unlocked, "Original promotion remains claimable with exact bonuses after learning")
	game._stop_audio()
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
