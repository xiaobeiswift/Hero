extends SceneTree
## Real keyboard/mouse routing and window-close handling; all disk paths belong
## to an isolated test directory. Animation is driven with deterministic deltas.
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")

class RoutedState extends Model:
	var routed_path: String
	var writes: int = 0
	func save_game(_path: String = SAVE_PATH) -> Error:
		writes += 1
		return super.save_game(routed_path)
	func load_game(_path: String = SAVE_PATH) -> Error:
		return super.load_game(routed_path)
	func has_save() -> bool:
		return FileAccess.file_exists(routed_path)

class InterceptMain extends Main:
	var exits: int = 0
	var exit_save: bool = true
	func _quit_cleanly(save_progress: bool = true) -> void:
		exits += 1
		exit_save = save_progress
		quit_pending = true
		world.active = false
		_stop_audio()

var checks: int = 0
var failures: int = 0
var sequence: int = 0
var app
var panel


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _key_now(code: int) -> void:
	for pressed: bool in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(code: int) -> void:
	_key_now(code)
	await process_frame


func _click(control: Control) -> void:
	await _click_point(control.get_global_rect().get_center())


func _click_point(point: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _create() -> void:
	sequence += 1
	app = InterceptMain.new()
	app.state = RoutedState.new()
	app.state.routed_path = "user://courtyard-ui-%d-%d.json" % [OS.get_process_id(), sequence]
	root.add_child(app)
	await process_frame
	app._new_game()
	app._stop_audio()
	app.audio_on = false
	app.state.hp = 47
	app.state.max_hp = 240
	app.state.qi = 1
	app.state.max_qi = 8
	app.state.medicine = 0
	app.state.coins = 77
	app.state.xp = 33
	app.state.victories = 6
	app.state.art_uses["照夜一线"] = 15
	# Prepared prior-story prerequisites make the real schema12 checkpoint
	# canonical; this practice fixture does not claim a natural earned journey.
	app.state.quest_stage = 6
	app.state.side_stage = 3; app.state.side_choice = "rescue"; app.state.side_reward_claimed = true
	app.state.side_found.assign(["boatman", "ledger"]); app.state.side_clues = 2
	app.state.chapter_two_stage = 4; app.state.chapter_two_ending = "protect_witness"
	app.state.archive_clues.assign(["clerk", "inscription"]); app.state.seal_sequence.assign([2, 0, 1])
	app.state.bridge_repaired = true; app.state.tangqi_stage = 3; app.state.tangqi_choice = "teach"
	app.state.tangqi_unlocked = true
	app.state.active_companion = "唐栖"
	app.state._apply_party_plan(app.state.PartyRoster.load_plan(app.state, {"active_companion": "唐栖"}, 11))
	app.world.teleport(Vector2(721, 733))
	app.world._update_nearby()
	app._process(0)
	check(app.state.save_game() == OK, "Isolated baseline save is writable")
	app.battle_presentation_enabled = true
	app.battle_art.set_process(false)
	await process_frame


func _dispose() -> void:
	app._stop_audio()
	app.queue_free()
	await process_frame
	await process_frame
	app = null
	panel = null


func _open() -> void:
	app._process(0)
	app.world._update_nearby()
	check(app.world.nearby_id == "courtyard_practice", "The courtyard sign is reachable at its actual world coordinate")
	await _key(KEY_E)
	panel = app.overlay.get_meta("courtyard_practice") if app.overlay.has_meta("courtyard_practice") else null
	check(panel != null, "Actual E interaction opens the practice modal")
	if panel != null:
		panel.art.set_process(false)


func _finish() -> void:
	panel.art._process(panel.art.get_presentation_duration() + 0.1)


func _sync_fixture() -> void:
	panel.display = panel.rules.snapshot()
	panel.art.set_snapshot(panel.display)
	panel.refresh()


func _real_snapshot() -> Dictionary:
	var variables: Dictionary = {}
	for property: Dictionary in app.state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = String(property.name)
			if name in ["writes", "routed_path"]:
				continue
			var value: Variant = app.state.get(name)
			variables[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"save": app.state.to_dict().duplicate(true), "variables": variables}


func _all_locked() -> bool:
	for button: Button in panel.action_buttons:
		if not button.disabled:
			return false
	for entry: Dictionary in panel.target_cards.values():
		if not entry.button.disabled:
			return false
	return true


func _test_inputs_and_outcomes() -> void:
	await _create()
	var real: Dictionary = _real_snapshot()
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(app.state.routed_path)
	var writes: int = app.state.writes
	await _open()
	if panel == null:
		await _dispose()
		return
	check(app.current_screen == "explore" and app.active_modal and not app.world.visible and not app.world.active and not app.state.battle_active, "Practice pauses exploration in a modal without starting real combat")
	check(panel.rules.hp == 240 and panel.rules.qi == 8 and panel.rules.medicine == 3 and app.state.hp == 47 and app.state.medicine == 0, "Practice opens with independent full HP/qi and three free charges")
	check(panel.action_buttons[0].text.contains("+0气") and panel.action_buttons[2].text.contains("+0气"), "Button resource gains are truthful at full qi")
	await _click(panel.target_cards.bracer.button)
	check(panel.rules.selected_id == "bracer", "Real pointer click on the bracer card selects that target")
	await _click_point(panel.art.get_global_transform() * Vector2(650, 166))
	check(panel.rules.selected_id == "striker", "Real pointer click on the wooden striker selects its body")
	await _click_point(panel.art.get_global_transform() * Vector2(790, 208))
	check(panel.rules.selected_id == "bracer", "Real pointer click on the wooden bracer selects its body")
	await _key(KEY_TAB)
	check(panel.rules.selected_id == "striker", "Actual Tab cycles to the other living target")
	check(panel.turn_text.text.begins_with("第1招"), "Ready state announces first move")
	var initial: Dictionary = panel.rules.snapshot()
	await _key(KEY_ENTER)
	check(panel.rules.turn == 1 and panel.rules.locked and panel.art.is_presenting() and _all_locked(), "Enter resolves one attack and disables target/action controls during presentation")
	check(panel.display.units[0].hp == initial.units[0].hp and panel.health.value == initial.hp and panel.rules.units[0].hp < initial.units[0].hp, "Rules resolve atomically while displayed health waits for contact")
	check(panel.turn_text.text.begins_with("第1招"), "Accepted first move keeps its number during windup")
	var resolved: Dictionary = panel.rules.snapshot()
	await _key(KEY_1)
	await _key(KEY_TAB)
	await _click(panel.target_cards.bracer.button)
	check(panel.rules.snapshot() == resolved, "Keyboard repeat, target cycling and target click cannot alter a locked exchange")
	panel.art._process(0.31)
	check(panel.display.units[0].hp == initial.units[0].hp, "Target bar remains unchanged before the attack impact")
	panel.art._process(0.02)
	check(panel.display.units[0].hp == panel.rules.units[0].hp and panel.display.hp == initial.hp, "Attack impact changes only its selected target, before counter contact")
	check(panel.turn_text.text.begins_with("第1招"), "Impact does not skip to next move number")
	_finish()
	check(not panel.rules.locked and not panel.art.is_presenting() and panel.display == panel.rules.snapshot(), "Completion reconciles the exact rules state and releases input")
	check(panel.turn_text.text.begins_with("第2招"), "Only completed recovery announces the upcoming move")
	await _key(KEY_2)
	check(panel.pending.action == "skill" and panel.pending.hero_qi_delta == -3 and panel.pending.support_damage > 0 and panel.rules.skill_cooldown == 2, "Actual key 2 uses equipped art and copied companion on the next offensive action")
	_finish()
	await _key(KEY_3)
	check(panel.pending.action == "guard" and panel.pending.guarded and panel.pending.hero_qi_delta == 1, "Actual key 3 guards and gains the exact available qi")
	_finish()
	await _key(KEY_4)
	check(panel.pending.action == "item" and panel.pending.heal > 0 and panel.rules.medicine == 2 and app.state.medicine == 0, "Actual key 4 spends only one free practice charge")
	_finish()
	await _key(KEY_5)
	check(panel.rules.outcome == "flee" and panel.rules.locked and panel.pending.counter_damage == 0, "Actual key 5 ends practice without a counterattack")
	await _key(KEY_1)
	check(panel.rules.outcome == "flee" and panel.rules.locked, "Outcome retry cannot bypass an unfinished exit presentation")
	_finish()
	check(panel.notice.text.contains("已收势") and panel.action_buttons[0].visible and not panel.action_buttons[2].visible, "Completed withdrawal exposes only retry and return actions")
	await _key(KEY_ENTER)
	check(panel.rules.active and panel.rules.turn == 0 and panel.rules.hp == 240 and panel.rules.qi == 8 and panel.rules.medicine == 3, "Enter retries the exercise with fresh virtual resources")
	check(panel.turn_text.text.begins_with("第1招"), "Retry resets displayed move count")

	panel.rules.units[0].hp = 1
	_sync_fixture()
	await _click(panel.target_cards.striker.button)
	await _key(KEY_1)
	check(panel.rules.units[0].hp == 0 and panel.rules.selected_id == "striker" and panel.pending.counter_damage == 0, "Finishing hit stays on the dead selected target and honors the protector's announced non-attack")
	await _click(panel.target_cards.bracer.button)
	check(panel.rules.selected_id == "striker", "Survivor cannot be clicked until the finishing pose ends")
	_finish()
	check(panel.rules.selected_id == "bracer" and panel.target_cards.striker.button.disabled and panel.target_cards.striker.bar.value == 0, "Completion auto-selects the survivor and leaves the dead target disabled at zero")
	panel.rules.units[1].hp = 1
	_sync_fixture()
	await _click(panel.action_buttons[0])
	check(panel.rules.outcome == "win" and panel.rules.locked, "Real action-button click resolves the final wooden target")
	_finish()
	check(panel.notice.text.contains("演武完成") and panel.display.units[0].hp == 0 and panel.display.units[1].hp == 0, "Victory presents both stopped wooden targets")
	check(panel.turn_text.text.begins_with("第2招"), "Victory keeps the final completed move count")
	await _key(KEY_1)
	panel.rules.hp = 1
	_sync_fixture()
	await _key(KEY_3)
	check(panel.rules.outcome == "defeat" and panel.rules.hp == 0 and panel.pending.counter_damage == 1, "Lethal practice counter records only the remaining virtual HP")
	_finish()
	check(panel.health.value == 0 and panel.notice.text.contains("耗尽"), "Defeat visibly reaches zero before retry")
	check(panel.turn_text.text.begins_with("第1招"), "Defeat keeps its actual last move count")
	await _key(KEY_2)
	check(not app.active_modal and app.world.visible and not app.overlay.has_meta("courtyard_practice"), "Outcome key 2 returns to the same courtyard")
	check(_real_snapshot() == real and app.state.writes == writes and FileAccess.get_file_as_bytes(app.state.routed_path) == save_bytes, "Inputs, all outcomes and retries leave every real field and existing save byte unchanged")
	await _dispose()


func _test_interruption_and_normal_battle() -> void:
	await _create()
	var real: Dictionary = _real_snapshot()
	var writes: int = app.state.writes
	await _open()
	if panel == null:
		await _dispose()
		return
	await _key(KEY_1)
	var retired = panel
	var stale_finish: Callable = retired._finished
	var stale_impact: Callable = retired._impact.bind("striker", 99)
	# Dispatch synchronously to exercise callbacks before queue_free releases the
	# old panel. Detached nodes must reject them, even while still allocated.
	_key_now(KEY_ESCAPE)
	app._process(0)
	_key_now(KEY_E)
	panel = app.overlay.get_meta("courtyard_practice") if app.overlay.has_meta("courtyard_practice") else null
	check(panel != null and panel != retired and not retired.valid(), "Escape during animation permits a fresh actual-E entry immediately")
	if panel == null:
		await _dispose()
		return
	panel.art.set_process(false)
	var fresh: Dictionary = panel.rules.snapshot()
	stale_impact.call()
	stale_finish.call()
	check(panel.rules.snapshot() == fresh and panel.rules.turn == 0 and panel.pending.is_empty(), "Late detached impact/completion callbacks cannot touch the reopened attempt")
	await process_frame
	await _key(KEY_1)
	_finish()
	check(panel.rules.turn == 1 and not panel.rules.locked, "Fresh presentation remains usable after interruption")
	await _key(KEY_ESCAPE)
	check(_real_snapshot() == real and app.state.writes == writes, "Mid-animation Escape/reopen never autosaves or mutates real progress")

	app.state.tangqi_unlocked = false
	app.state.active_companion = ""
	app.state._apply_party_plan(app.state.PartyRoster.load_plan(app.state, {"active_companion": ""}, 11))
	app.state.hp = 100
	app.state.qi = 2
	app._start_battle("training")
	check(app.current_screen == "battle" and not app.overlay.has_meta("courtyard_practice") and app.state.enemy_hp == 64, "Ordinary training still opens the original single-enemy battle")
	await _key(KEY_1)
	check(app.state.turn == 1 and app.state.enemy_hp == 48 and app.battle_busy, "Ordinary key 1 preserves existing unbraced single-enemy damage")
	app.battle_art._process(app.battle_art.get_presentation_duration() + 0.1)
	check(not app.battle_busy and app.battle_hp.value == 48, "Normal battle still reconciles through its original presentation flow")
	await _key(KEY_5)
	app.battle_art._process(app.battle_art.get_presentation_duration() + 0.1)
	check(app.current_screen == "explore" and not app.battle_busy, "Normal battle withdrawal still returns to exploration")
	await _dispose()


func _geometry_clear() -> bool:
	var area: Rect2 = Rect2(Vector2.ZERO, Vector2(1280, 800))
	for i: int in panel.action_buttons.size():
		var button: Button = panel.action_buttons[i]
		if not area.encloses(button.get_global_rect()):
			return false
		if i > 0 and button.get_global_rect().intersects(panel.action_buttons[i - 1].get_global_rect()):
			return false
	for entry: Dictionary in panel.target_cards.values():
		if not area.encloses(entry.button.get_global_rect()) or not entry.button.get_global_rect().encloses(entry.intent.get_global_rect()):
			return false
	return not panel.target_cards.striker.button.get_global_rect().intersects(panel.target_cards.bracer.button.get_global_rect())


func _test_geometry() -> void:
	await _create()
	root.content_scale_size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for width: int in [1280, 1180]:
		root.size = Vector2i(width, int(round(width * 800.0 / 1280.0)))
		await process_frame
		for zoom: int in [0, 1, 2]:
			app.view_preferences.zoom_index = zoom
			app._apply_view_zoom()
			await _open()
			if panel == null:
				continue
			await process_frame
			check(_geometry_clear(), "Target cards, intent lines and five actions fit without overlap at width %d / zoom %d" % [width, zoom])
			check(panel.scale == Vector2.ONE and panel.health_text.get_theme_font_size("font_size") == 20, "Practice UI retains logical scale and readable text at width %d / zoom %d" % [width, zoom])
			await _click(panel.target_cards.bracer.button)
			check(panel.rules.selected_id == "bracer", "Pointer target routing works at width %d / zoom %d" % [width, zoom])
			await _key(KEY_ESCAPE)
	root.size = Vector2i(1280, 800)
	await _dispose()


func _request_close() -> void:
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST)


func _test_window_close() -> void:
	await _create()
	await _open()
	if panel == null:
		await _dispose()
		return
	await _key(KEY_1)
	var real: Dictionary = app.state.to_dict().duplicate(true)
	var writes: int = app.state.writes
	_request_close()
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(app.state.routed_path))
	check(app.exits == 1 and app.quit_pending and not app.exit_save and app.state.writes == writes + 1 and disk.player == JSON.parse_string(JSON.stringify(real)), "WM close during practice saves original exploration state once and exits only after success")
	_request_close()
	check(app.exits == 1 and app.state.writes == writes + 1, "Duplicate successful WM close cannot write or exit twice")
	await _dispose()

	for discard: bool in [false, true]:
		await _create()
		var path: String = app.state.routed_path
		var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		app.state.coins += 7
		var expected: Dictionary = app.state.to_dict().duplicate(true)
		check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Inject an actual isolated filesystem write failure")
		await _open()
		if panel == null:
			await _dispose()
			continue
		await _key(KEY_1)
		_request_close()
		check(app.exits == 0 and not app.quit_pending and app.active_modal and not app.overlay.has_meta("courtyard_practice") and app.overlay.find_child("DialogueTitle", true, false).text == "手记未能落笔", "Practice WM-close failure replaces the arena with the existing protected error dialogue")
		check(app.state.to_dict() == expected and FileAccess.get_file_as_bytes(path) == old_bytes, "Failed close retains the real live journey and byte-identical earlier save")
		var stale_retry: Callable = app.modal_actions[0]
		await _key(KEY_2)
		writes = app.state.writes
		stale_retry.call()
		check(app.overlay.get_meta("pause_menu", false) and app.exits == 0 and app.state.writes == writes, "Cancel returns to pause and invalidates the old close-retry callback")
		await _key(KEY_ESCAPE)
		await _open()
		check(panel != null and panel.rules.turn == 0 and panel.rules.hp == panel.rules.max_hp, "After cancelling failed close, practice can be entered again cleanly")
		_request_close()
		if discard:
			await _key(KEY_3)
			check(app.exits == 0 and app.overlay.find_child("DialogueTitle", true, false).text == "舍下未存的这一程？", "Discard requires the existing explicit second confirmation")
			await _key(KEY_1)
			check(app.exits == 0 and app.overlay.get_meta("pause_menu", false), "Cancelling discard keeps the journey open")
			_request_close()
			await _key(KEY_3)
			writes = app.state.writes
			await _key(KEY_2)
			check(app.exits == 1 and not app.exit_save and app.state.writes == writes and FileAccess.get_file_as_bytes(path) == old_bytes, "Confirmed discard exits without overwriting the pre-existing save")
		else:
			check(DirAccess.rename_absolute(path + ".tmp", path + ".injected-blocker") == OK, "Remove synthetic blocker without touching the prior save")
			await _key(KEY_1)
			disk = JSON.parse_string(FileAccess.get_file_as_string(path))
			check(app.exits == 1 and not app.exit_save and disk.player == JSON.parse_string(JSON.stringify(expected)), "Retry after storage recovery persists real exploration state and exits")
		await _dispose()


func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Run courtyard_practice_ui_test.gd with an isolated XDG_DATA_HOME")
		quit(2)
		return
	await _test_inputs_and_outcomes()
	await _test_interruption_and_normal_battle()
	await _test_geometry()
	await _test_window_close()
	print("%s: %d integrated courtyard UI checks (input/presentation/outcomes/isolation/layout/window-close)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
