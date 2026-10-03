extends RefCounted
## Test-only fixtures. Recruitment uses GameState; visual caches never drive motion.
const State = preload("res://scripts/game_state.gd")
const NAMES = {"shen": "沈青", "tang": "唐栖", "qin": "秦禾"}

static func recruited_state(ids: Array = ["hero", "shen", "tang", "qin"], prepared_state = null):
	var state = prepared_state if prepared_state != null else State.new()
	# Prepared eligible story milestones, followed by the actual recruitment APIs.
	state.quest_stage = 6; state.ending = "守望"; state.choose_sect("听潮阁")
	state.side_stage = 3; state.side_choice = "rescue"; state.side_reward_claimed = true
	state.side_found.assign(["boatman", "ledger"]); state.side_clues = 2
	state.chapter_two_stage = 4; state.chapter_two_ending = "protect_witness"
	state.archive_clues.assign(["clerk", "inscription"]); state.seal_sequence.assign([2, 0, 1])
	state.bridge_repaired = true; state.tangqi_stage = 3; state.tangqi_choice = "preserve"
	state.mist_stage = 4; state.mist_ending = "release_water"; state.mist_approach = "duel"
	state.mist_gauges.assign(["rain", "stone", "basin"]); state.map_id = "mistwood"
	assert(state.recruit_companion())
	assert(state.recruit_tangqi())
	assert(state.begin_qin_quest() and state.inspect_qin_rope() and state.arrange_qin_handoff())
	assert(state.recruit_qin())
	assert(state.set_party_roster(ids))
	return state

static func manifest(state) -> Array:
	var snapshot: Dictionary = state.party_resource_snapshot()
	assert(snapshot.ok)
	var selected: Dictionary = {}
	for actor: Dictionary in snapshot.actors:
		if actor.id in NAMES and actor.recruited and actor.selected:
			selected[actor.id] = {"id": actor.id, "name": actor.name}
	var result: Array = []
	for id: String in snapshot.roster:
		if selected.has(id): result.append(selected[id])
	return result

static func select_world(world, ids: Array = ["hero", "shen", "tang", "qin"]):
	var state = recruited_state(ids)
	assert(world.set_exploration_party(manifest(state)).ok)
	assert(world.follower_ids() == ids.slice(1))
	return state

static func render_frame(id: String, position: Vector2, facing: Vector2 = Vector2.DOWN,
		moving: bool = false, phase: float = 0.0) -> Dictionary:
	assert(NAMES.has(id))
	return {"id": id, "position": position, "facing": facing,
		"moving": moving, "walk_phase": phase, "walk_distance": phase / 0.060}

static func prepare_render(world, frames: Array[Dictionary]) -> void:
	# Prepared render fixture only. Replace the private cache; never mutate a
	# read-only gameplay snapshot or represent these poses as movement evidence.
	world._follower_frames = frames

static func positions(world) -> Dictionary:
	var result: Dictionary = {}
	for id: String in world.follower_ids(): result[id] = world.follower_view(id).position
	return result

static func check_cardinal_motion(world, id: String, origin: Vector2) -> void:
	world.active = true
	for pair in [[Vector2.UP, "move_up"], [Vector2.DOWN, "move_down"],
			[Vector2.LEFT, "move_left"], [Vector2.RIGHT, "move_right"]]:
		if not InputMap.has_action(pair[1]): InputMap.add_action(pair[1])
		world.facing = pair[0]
		world.teleport(origin)
		assert(world._can_step(origin, origin + pair[0] * 74.0))
		var initial: Dictionary = world.follower_view(id)
		assert(not initial.is_empty() and world._follower_can_walk(initial.position))
		var idle_player: Vector2 = world.player_pos
		world._process(0.05)
		assert(world.player_pos == idle_player and not world.follower_view(id).moving)
		Input.action_press(pair[1])
		for _frame in range(8):
			var before: Vector2 = world.follower_view(id).position
			world._process(0.05)
			var actor: Dictionary = world.follower_view(id)
			assert(world._follower_can_walk(actor.position) and world._follower_can_step(before, actor.position))
			assert(actor.moving == (actor.position.distance_to(before) > 0.0001))
		Input.action_release(pair[1])
		var travelled: Dictionary = world.follower_view(id)
		assert(world.player_pos.distance_to(origin + pair[0] * 74.0) < 0.01)
		assert(travelled.position != initial.position and travelled.walk_distance > initial.walk_distance)
		assert(travelled.walk_phase != initial.walk_phase and travelled.facing.dot(pair[0]) > 0.99)
		assert(travelled.position.distance_to(world.player_pos) > 35.0)
		for _frame in range(30): world._process(0.05)
		var resting: Dictionary = world.follower_view(id)
		world._process(0.05)
		assert(not world.follower_view(id).moving and world.follower_view(id).position == resting.position)
		assert(world.follower_view(id).walk_phase == resting.walk_phase)
