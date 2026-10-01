extends SceneTree
## Independent integration audit. Use an isolated XDG_DATA_HOME when running.
## Run: godot --headless --path . --script tests/audit_progression_test.gd

class AuditState:
	extends "res://scripts/game_state.gd"
	const AUDIT_PATH := "user://hero_progression_audit.json"

	func save_game(path: String = SAVE_PATH) -> Error:
		return super.save_game(AUDIT_PATH if path == SAVE_PATH else path)

	func load_game(path: String = SAVE_PATH) -> Error:
		return super.load_game(AUDIT_PATH if path == SAVE_PATH else path)

	func has_save() -> bool:
		return FileAccess.file_exists(AUDIT_PATH)

var game
var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("Main scene could not be loaded; integration audit not run")
		quit(2)
		return
	game = scene.instantiate()
	if not game.has_method("_new_game"):
		push_error("Main script failed to compile; progression audit not run")
		game.free()
		quit(2)
		return
	root.add_child(game)
	await process_frame
	# The real UI runs against an isolated save adapter, never the player's save.
	game.state = AuditState.new()
	game._new_game()
	_check(game.current_screen == "explore" and not game.active_modal, "New game enters exploration")
	await _test_keyboard_flow()
	_test_world_navigation()
	_test_quest_collection()
	_test_battle_recovery()
	_test_story_completion()
	_test_repeat_battle()
	_test_companion_and_equipment()
	_test_partial_save_safety()
	_test_autosave_failure_visibility()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	game.music.stop()
	game.sfx.stop()
	game.music.stream = null
	game.sfx.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d independent progression audit checks" % checks)
	else:
		push_error("FAIL: %d of %d independent progression audit checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_keyboard_flow() -> void:
	game.world.teleport(Vector2(520, 440))
	for key: Key in [KEY_E, KEY_ENTER]:
		game._process(0.0)
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		_check(game.active_modal and _find_button(game.overlay, "这盏灯，我来找") != null, "Actual input dispatch opens nearby dialogue: " + str(key))
		event.pressed = false
		Input.parse_input_event(event)
		game._close_modal()
	for key: Key in [KEY_I, KEY_J]:
		game._process(0.0)
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		_check(game.active_modal, "Actual input dispatch opens menu shortcut: " + str(key))
		event.pressed = false
		Input.parse_input_event(event)
		game._close_modal()
	game.world.teleport(Vector2(460, 430))


func _test_world_navigation() -> void:
	var start := Vector2(460, 430)
	var queue: Array[Vector2] = [start]
	var visited: Dictionary = {start: true}
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		for offset: Vector2 in [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
			var next := point + offset
			if not visited.has(next) and game.world._can_step(point,next):
				visited[next] = true
				queue.append(next)
	for id: String in game.world.interactables:
		var target: Vector2 = game.world.interactables[id]["pos"]
		var reachable := false
		for point: Vector2 in visited:
			if point.distance_to(target) < 70 and (not bool(game.world.interactables[id].get("islet",false)) or game.world.Lightness.on_islet(point)):
				reachable = true
				break
		if bool(game.world.interactables[id].get("islet",false)):
			_check(not reachable and game.world._can_walk(target), "Intentional islet target is safe but not reachable by ordinary mainland walking: "+id)
		else:
			_check(reachable, "Walkable route reaches interaction: " + id)
	for unsafe: Vector2 in [Vector2(300, 250), Vector2(300, 0), Vector2(998, 484), Vector2(9999, 9999)]:
		game.world.teleport(unsafe)
		_check(game.world._can_walk(game.world.player_pos), "Loaded/teleported location is repaired to walkable terrain: " + str(unsafe))
	game.world.teleport(start)


func _test_quest_collection() -> void:
	game._elder_dialogue()
	_press("这盏灯，我来找")
	_check(game.state.quest_stage == 1, "Elder starts the quest")
	game._herb_dialogue()
	_press("收入行囊")
	_check(game.state.quest_stage == 2 and game.state.herbs == 1 and game.state.xp == 10, "Collecting herb advances quest and rewards once")
	game._herb_dialogue()
	_check(_find_button(game.overlay, "收入行囊") == null, "Repeated herb interaction cannot duplicate reward")
	game._close_modal()
	game._healer_dialogue()
	_press("收下药，前往旧渡口")
	_check(game.state.quest_stage == 3 and game.state.herbs == 0 and game.state.medicine == 5 and game.state.xp == 30, "Healer consumes herb and advances quest once")
	game._healer_dialogue()
	_check(_find_button(game.overlay, "收下药，前往旧渡口") == null, "Repeated healer interaction cannot duplicate quest reward")
	game._close_modal()


func _test_battle_recovery() -> void:
	game.state.hp = 1
	game._start_battle("story")
	game._battle_action("attack")
	_check(not game.state.battle_active and game.current_screen == "explore", "Defeat returns to exploration")
	_check(game.state.quest_stage == 3 and game.state.hp == game.state.max_hp and game.state.coins == 16, "Defeat restores health and preserves quest, charging eight coins")
	game._close_modal()
	game._start_battle("story")
	game._battle_action("flee")
	_check(game.state.quest_stage == 3 and not game.state.battle_active and not game.active_modal, "Flee preserves retryable story stage")
	game.state.heal_rest()
	game._start_battle("story")
	_win_battle()
	_check(game.state.quest_stage == 4 and game.state.victories == 1, "Retry after defeat and flee can win story encounter")
	var before: Dictionary = game.state.to_dict()
	game._battle_action("attack")
	_check(game.state.to_dict() == before, "A repeated battle-completion input cannot award twice")
	_press("收剑，回村")


func _test_story_completion() -> void:
	game._elder_dialogue()
	var before_coins: int = game.state.coins
	_press("交给船家")
	_check(game.state.ending == "守望" and game.state.coins == before_coins + 60, "Narrative choice is preserved and rewarded once")
	_check(game.active_modal and _find_button(game.overlay, "听潮阁") != null, "Final choice opens sect selection")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	if not game.active_modal:
		game._elder_dialogue()
	_check(_find_button(game.overlay, "听潮阁") != null, "Dismissed sect choice remains reachable without requiring reload")
	if _find_button(game.overlay, "听潮阁") == null:
		# Continue the audit after reporting this independent failure.
		game._choose_sect()
	_press("听潮阁")
	_check(game.state.sect == "听潮阁" and game.state.quest_stage == 6, "Joining sect marks chapter and quest guidance complete")
	_check(game.state.quest_hint().contains("切磋"), "Post-chapter quest hint points to playable activities")
	game._elder_dialogue()
	_check(_find_button(game.overlay, "交给船家") == null and _find_button(game.overlay, "交给县衙") == null, "Completed narrative cannot be rewarded twice through elder dialogue")
	game._close_modal()
	var before: Dictionary = game.state.to_dict()
	game._save()
	game.state.coins = 0
	game._load()
	_check(game.state.to_dict() == before, "Completed chapter survives UI save/load with all resources")
	_check(not game.active_modal, "Loading completed chapter does not reopen an unnecessary sect choice")


func _test_repeat_battle() -> void:
	var before_coins: int = game.state.coins
	var before_victories: int = game.state.victories
	game._bandit_dialogue()
	_press("友好切磋")
	_check(game.state.enemy_max_hp == 64, "UI starts the intended lighter repeat encounter")
	_win_battle()
	_check(game.state.coins == before_coins + 12 and game.state.victories == before_victories + 1, "Repeat encounter grants training rewards")
	_check(game.state.quest_stage == 6, "Repeat encounter preserves completed chapter")
	_press("继续行走")


func _test_partial_save_safety() -> void:
	var path := "user://hero_audit_partial.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version":1,"player":{"level":1,"quest_stage":2}}')
	file.close()
	var before: Dictionary = game.state.to_dict()
	var result = game.state.load_game(path)
	if result == OK:
		# A compatibility loader may repair older incomplete data instead of rejecting it.
		_check(game.state.quest_stage != 2 or game.state.herbs > 0, "Accepted partial save cannot strand the herb-delivery quest")
	else:
		_check(game.state.to_dict() == before, "Rejected partial save preserves the active game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_companion_and_equipment() -> void:
	game._healer_dialogue()
	_press("邀请同行")
	_check(game.state.companion_unlocked and game.state.formation == "并肩", "Companion can be recruited through healer dialogue")
	game._process(0.0)
	_check(game.world.companion_active, "Recruited companion is enabled in exploration")
	game._healer_dialogue()
	_check(_find_button(game.overlay, "邀请同行") == null, "Companion recruitment cannot repeat")
	game._close_modal()
	game._show_inventory()
	var before_coins: int = game.state.coins
	var before_attack: int = game.state.attack
	_press("青钢剑 · 45文")
	_check(game.state.equipment == "青钢剑" and game.state.coins == before_coins - 45 and game.state.attack == before_attack + 4, "UI equipment purchase charges once and applies its bonus")
	_press("青钢剑 · 45文")
	_check(game.state.coins == before_coins - 45 and game.state.attack == before_attack + 4, "Repeated purchase cannot charge or stack bonuses")
	_press("切换阵型")
	_check(game.state.formation == "护后", "Inventory switches companion to defensive formation")
	_press("切换阵型")
	_check(game.state.formation == "并肩", "Inventory switches companion back to attacking formation")
	game._close_modal()
	game._save()
	var before: Dictionary = game.state.to_dict()
	game.state.reset_game()
	game._load()
	_check(game.state.to_dict() == before, "Companion, formation and equipment survive UI save/load")


func _test_autosave_failure_visibility() -> void:
	game._new_game()
	var blocked_tmp := ProjectSettings.globalize_path(AuditState.AUDIT_PATH + ".tmp")
	_check(DirAccess.make_dir_absolute(blocked_tmp) == OK, "Create isolated failed-write fixture")
	game._elder_dialogue()
	_press("这盏灯，我来找")
	_check(game.state.quest_stage == 1, "Failed autosave does not discard in-memory progress")
	_check(game.status_label.text.contains("存档") and (game.status_label.text.contains("失败") or game.status_label.text.contains("未成功") or game.status_label.text.contains("重试")), "Autosave failure remains visible after quest-success toast")
	DirAccess.remove_absolute(blocked_tmp)
	game._save()
	_check(not game.save_warning and game.status_label.text.contains("已存档"), "Successful retry clears the save failure warning")


func _win_battle() -> void:
	for attempt in range(50):
		if not game.state.battle_active:
			return
		game._battle_action("skill" if game.state.qi >= 3 and game.state.skill_cooldown == 0 else "attack")
	_check(false, "Battle resolves within fifty accepted actions")


func _press(text: String) -> void:
	var button := _find_button(game.overlay, text)
	_check(button != null, "Dialogue button exists: " + text)
	if button != null:
		button.pressed.emit()


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var button := _find_button(child, text)
		if button != null:
			return button
	return null


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
