extends "res://tests/audit_second_region_test.gd"
## Independent real-scene manual-save audit. Run only with an isolated XDG_DATA_HOME.
## All active-model save/load operations use this fixture root. XDG isolates title metadata discovery.
const Slots = preload("res://scripts/local_save_slots.gd")
const BaseState = preload("res://scripts/game_state.gd")

class RoutedState:
	extends "res://scripts/game_state.gd"
	var autosave_path: String
	var autosave_writes: int = 0
	var autosave_reads: int = 0
	var fail_autosave: bool = false
	var accessed_paths: Array[String] = []
	func save_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH:
			autosave_writes += 1
			if fail_autosave: return ERR_FILE_CANT_WRITE
			path = autosave_path
		accessed_paths.append(path)
		return super.save_game(path)
	func load_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH:
			autosave_reads += 1
			path = autosave_path
		accessed_paths.append(path)
		return super.load_game(path)
	func has_save() -> bool:
		return FileAccess.file_exists(autosave_path)

var fixture: String
var store
var state_probe: RoutedState

func _run() -> void:
	fixture = "user://manual-ui-independent-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create independent fixture root")
	store = Slots.new(fixture)
	state_probe = RoutedState.new()
	state_probe.autosave_path = store.path_for(0)
	game = load("res://scenes/main.tscn").instantiate()
	# Install the state before _ready so title discovery cannot inspect real saves.
	game.state = state_probe
	root.add_child(game)
	game.save_slots.store = store
	await process_frame
	await _test_cold_title_cancellation()
	game._new_game()
	await _test_input_routes()
	_test_overwrite_and_cancel()
	_test_load_failure_and_autosave_failure()
	await _test_title_backup_only_and_new_game()
	await _test_battle_and_keyboard_guards()
	await _test_interrupted_mouse_callbacks()
	if "--exercise-stale-callback-replay" in OS.get_cmdline_user_args(): _test_stale_callback_guards()
	for path: String in state_probe.accessed_paths:
		_check(path.begins_with(fixture + "/"), "State I/O stays in injected root: " + path.get_file())
	_check(not FileAccess.file_exists(BaseState.SAVE_PATH), "Audit never creates normal-player autosave")
	for slot: int in range(1,4):
		_check(not FileAccess.file_exists("user://hero_slot_%d.json" % slot), "Audit never creates normal-player manual slot %d" % slot)
	game._stop_audio()
	game.queue_free()
	await process_frame
	_remove_fixture(fixture)
	_check(not DirAccess.dir_exists_absolute(fixture), "Remove independent fixtures")
	if failures == 0: print("PASS: %d independent manual-save UI audit checks" % checks)
	else: push_error("FAIL: %d of %d independent manual-save UI audit checks" % [failures,checks])
	quit(0 if failures == 0 else 1)

func _test_cold_title_cancellation() -> void:
	var saved := BaseState.new()
	saved.coins = 777
	_check(saved.save_game(store.path_for(0)) == OK and saved.save_game(store.path_for(1)) == OK, "Prepare prior-session autosave and manual branch before cold-title browsing")
	var bytes: PackedByteArray = _bytes(store.path_for(0))
	var write_count: int = state_probe.autosave_writes
	_check(state_probe.coins == 24, "Cold-start active state is distinct from saved prior-session branch")
	game._show_title()
	await _key(KEY_ESCAPE)
	_check(game.current_screen == "title" and game.active_modal and _bytes(store.path_for(0)) == bytes, "Escape on cold-start title cannot replace existing autosave with defaults")
	_press("查阅手记")
	await _key(KEY_ESCAPE)
	_check(game.current_screen == "title" and _bytes(store.path_for(0)) == bytes, "Escape in title load chooser preserves prior-session autosave")
	await _key(KEY_2)
	await _key(KEY_ESCAPE)
	_check(game.current_screen == "title" and _bytes(store.path_for(0)) == bytes, "Escape in title slot detail preserves prior-session autosave")
	_press("读取当前版本")
	await _key(KEY_ESCAPE)
	_check(game.current_screen == "title" and _bytes(store.path_for(0)) == bytes, "Escape in title load confirmation preserves prior-session autosave")
	_press("返回详情")
	_press("返回列表")
	_press("返回")
	_check(game.current_screen == "title" and _bytes(store.path_for(0)) == bytes, "Cancelling every title load step preserves prior-session autosave")
	_press("踏入江湖")
	await _key(KEY_ESCAPE)
	_check(game.current_screen == "title" and _bytes(store.path_for(0)) == bytes, "Escape in new-journey confirmation preserves existing autosave")
	_press("返回")
	_check(state_probe.autosave_writes == write_count and state_probe.coins == 24, "Cold-title browsing and cancellation perform no autosave or implicit loading")
	# Direct calls are defense-in-depth coverage, separate from the actual key paths above.
	game._close_modal()
	_check(game.current_screen == "title" and game.active_modal and _bytes(store.path_for(0)) == bytes and state_probe.autosave_writes == write_count, "Direct title close is guarded against default-state autosave replacement")
	DirAccess.remove_absolute(store.path_for(1))

func _test_input_routes() -> void:
	var saves_before: int = state_probe.autosave_writes
	await _key(KEY_F5)
	_check(state_probe.autosave_writes == saves_before + 1 and not game.active_modal, "F5 still quick-saves without opening the slot menu")
	state_probe.coins = 444
	var loads_before: int = state_probe.autosave_reads
	await _key(KEY_F9)
	_check(state_probe.autosave_reads == loads_before + 1 and state_probe.coins == 24 and not game.active_modal, "F9 still quick-loads autosave without a slot chooser")
	await _click_top("存档")
	_check(game.active_modal and _modal_text().contains("留住不同的江湖"), "Actual top save button opens manual slots")
	_check(game.modal_actions.size() == 4, "Save chooser has exactly three manual slots plus return")
	await _key(KEY_3)
	_check(store.describe(3).status == "valid" and not FileAccess.file_exists(store.path_for(1)), "Third keyboard choice writes only manual slot 3")
	await _key(KEY_ESCAPE)
	await _click_top("读档")
	_check(game.active_modal and game.modal_actions.size() == 5, "Actual top load button opens autosave plus all three manual slots")
	await _key(KEY_4)
	_check(_find_button(game.overlay, "读取当前版本") != null and _modal_text().contains("手记三"), "Fourth load choice targets manual slot 3")
	await _key(KEY_ESCAPE)
	await _key(KEY_F6)
	_check(_modal_text().contains("留住不同的江湖"), "F6 opens manual save menu")
	await _key(KEY_ESCAPE)
	await _key(KEY_F10)
	_check(_modal_text().contains("选择一段前缘"), "F10 opens manual load menu")
	await _key(KEY_ESCAPE)

func _test_overwrite_and_cancel() -> void:
	for slot: int in range(1,4):
		state_probe.coins = slot * 100
		_check(store.save_slot(state_probe, slot) == OK, "Create slot %d branch" % slot)
	var original: Dictionary = _manual_snapshot()
	state_probe.coins = 999
	game.save_slots.save_page()
	game.save_slots.request_save(3)
	_check(_modal_text().contains("重写手记三"), "Overwrite confirmation names selected third slot")
	_press("返回手记")
	_check(_manual_snapshot() == original, "Cancelling third-slot overwrite preserves all exact manual bytes")
	game.save_slots.request_save(3)
	var repeat: Callable = game.modal_actions[0]
	_press("确认重写")
	_check(_bytes(store.path_for(3) + ".bak") == original[store.path_for(3)], "UI third-slot overwrite preserves exact previous primary")
	var saved: Dictionary = _manual_snapshot()
	repeat.call()
	_check(_manual_snapshot() == saved, "Repeated same-state save callback does not rotate a meaningful backup")
	_check(_bytes(store.path_for(1)) == original[store.path_for(1)] and _bytes(store.path_for(2)) == original[store.path_for(2)], "Third-slot overwrite leaves first and second branches untouched")
	game._close_modal()

func _test_load_failure_and_autosave_failure() -> void:
	game.save_slots.detail(2)
	_press("读取当前版本")
	var manual_before: Dictionary = _manual_snapshot()
	var auto_before: PackedByteArray = _bytes(store.path_for(0))
	state_probe.fail_autosave = true
	_press("确认读取")
	_check(state_probe.coins == 200 and game.current_screen == "explore" and not game.active_modal, "Manual load still resumes valid state when autosave fails")
	_check(game.save_warning and game.status_label.text.contains("自动存档失败") and game.status_label.text.contains("已续写"), "Manual load reports autosave failure beside load success")
	_check(_bytes(store.path_for(0)) == auto_before, "Failed load-time autosave preserves old autosave bytes")
	_check(_manual_snapshot() == manual_before, "Failed load-time autosave never changes manual primary or backups")
	game._process(8.0)
	_check(game.status_label.text.contains("自动存档失败"), "Autosave failure warning persists after success toast expires")
	state_probe.fail_autosave = false
	game._save()
	_check(not game.save_warning and _read_coins(store.path_for(0)) == 200, "F5 implementation retries and clears loaded-branch autosave warning")
	# A file removed or corrupted after the confirmation was shown cannot mutate live state.
	game.save_slots.detail(1)
	_press("读取当前版本")
	var state_before: Dictionary = state_probe.to_dict()
	_write(store.path_for(1), "{bad".to_utf8_buffer())
	_press("确认读取")
	_check(state_probe.to_dict() == state_before and game.status_label.text.contains("未改变"), "Corrupt-after-selection primary fails without mutating current state")
	_check(game.active_modal, "Failed confirmed load remains dismissible")
	game.save_slots.detail(3)
	_press("读取备份")
	state_before = state_probe.to_dict()
	DirAccess.remove_absolute(store.path_for(3) + ".bak")
	_press("确认读取")
	_check(state_probe.to_dict() == state_before and game.status_label.text.contains("未改变"), "Removed-after-selection backup fails without mutating current state")
	game._close_modal()
	# Deterministic backup-open failure on an occupied slot must preserve every branch.
	state_probe.coins = 789
	_check(DirAccess.make_dir_absolute(store.path_for(2) + ".bak.tmp") == OK, "Block backup temporary file with a directory")
	manual_before = _manual_snapshot()
	game.save_slots.request_save(2)
	_press("确认重写")
	_check(game.status_label.text.contains("未能保存") and _manual_snapshot() == manual_before, "Blocked backup write is visible and preserves every manual file")
	DirAccess.remove_absolute(store.path_for(2) + ".bak.tmp")
	game._close_modal()

func _test_title_backup_only_and_new_game() -> void:
	state_probe.coins = 333
	_check(state_probe.save_game(store.path_for(1) + ".bak") == OK, "Create backup-only branch")
	for slot: int in range(0,4): DirAccess.remove_absolute(store.path_for(slot))
	var before: Dictionary = _manual_snapshot()
	game._show_title()
	_check(_find_button(game.overlay, "续写前缘") == null and _find_button(game.overlay, "查阅手记") != null, "Title discovers backup-only progress with no autosave or manual primaries")
	_press("查阅手记")
	await _key(KEY_2)
	_check(_find_button(game.overlay,"读取当前版本") == null and _find_button(game.overlay,"读取备份") != null, "Backup-only detail offers backup and no invalid primary")
	_press("返回列表")
	_press("返回")
	_check(game.current_screen == "title" and not FileAccess.file_exists(store.path_for(0)), "Backing out of title save browsing preserves title and does not create autosave")
	_press("踏入江湖")
	_check(game.current_screen == "explore" and state_probe.coins == 24 and _manual_snapshot() == before, "New journey without autosave preserves the backup-only branch")
	game.save_slots.detail(1)
	_press("读取备份")
	_press("确认读取")
	_check(state_probe.coins == 333 and _manual_snapshot() == before, "Backup-only branch remains recoverable after a new journey")

func _test_battle_and_keyboard_guards() -> void:
	game._start_battle("spar")
	var before: Dictionary = _manual_snapshot()
	for key: Key in [KEY_F5,KEY_F6,KEY_F9,KEY_F10]: await _key(key)
	_check(game.current_screen == "battle" and not game.active_modal and _manual_snapshot() == before, "All save/load function-key routes are blocked during combat")
	for slot: int in range(1,4):
		game.save_slots.request_save(slot)
		game.save_slots.perform_save(slot)
		game.save_slots.request_load(slot, false)
		game.save_slots.perform_load(slot, true)
	_check(game.current_screen == "battle" and not game.active_modal and _manual_snapshot() == before, "Direct delayed save/load callbacks cannot execute during combat")
	game._battle_action("flee")
	game._close_modal()

func _test_interrupted_mouse_callbacks() -> void:
	state_probe.coins = 111
	_check(store.save_slot(state_probe,1) == OK, "Prepare real interrupted-mouse save target")
	state_probe.coins = 222
	game.save_slots.request_save(1)
	var position: Vector2 = _find_button(game.overlay,"确认重写").get_global_rect().get_center()
	await _mouse_button(position, true)
	await _key(KEY_ESCAPE)
	var before: Dictionary = _manual_snapshot()
	await _mouse_button(position, false)
	_check(_manual_snapshot() == before and not game.active_modal, "Escape while holding overwrite button prevents action on delayed release")
	game.save_slots.request_load(1,false)
	position = _find_button(game.overlay,"确认读取").get_global_rect().get_center()
	await _mouse_button(position, true)
	await _key(KEY_2)
	game.save_slots.load_page()
	game.save_slots.detail(2)
	var state_before: Dictionary = state_probe.to_dict()
	await _mouse_button(position, false)
	_check(state_probe.to_dict() == state_before and game.active_modal and _modal_text().contains("手记二"), "Navigating away while holding load button prevents stale release from loading")
	game._close_modal()

func _mouse_button(position: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _test_stale_callback_guards() -> void:
	# Defense-in-depth only: the actual interrupted input paths are tested above.
	# Production UI dispatch did not reproduce these explicit Callable replays.
	state_probe.coins = 101
	_check(store.save_slot(state_probe,1) == OK, "Prepare defense-in-depth callback replay fixture")
	state_probe.coins = 202
	game.save_slots.request_save(1)
	var stale_save: Callable = game.modal_actions[0]
	_press("返回手记")
	game._close_modal()
	var before: Dictionary = _manual_snapshot()
	stale_save.call()
	_check(_manual_snapshot() == before and not game.active_modal, "Cancelled overwrite token rejects explicitly replayed Callable")
	game.save_slots.request_load(1,false)
	var stale_load: Callable = game.modal_actions[0]
	_press("返回详情")
	game.save_slots.load_page()
	game.save_slots.detail(2)
	var state_before: Dictionary = state_probe.to_dict()
	stale_load.call()
	_check(state_probe.to_dict() == state_before and game.active_modal and _modal_text().contains("手记二"), "Obsolete load token cannot replace newer slot selection")
	game._close_modal()
	game.save_slots.request_save(1)
	var accepted_save: Callable = game.modal_actions[0]
	accepted_save.call()
	_check(_read_coins(store.path_for(1)) == 202, "Current overwrite token still performs authorized save")
	before = _manual_snapshot()
	state_probe.coins = 303
	accepted_save.call()
	_check(_manual_snapshot() == before, "Completed overwrite token cannot be replayed against a changed live branch")
	game._close_modal()

func _click_top(caption: String) -> void:
	var button: Button = _find_button(game, caption)
	_check(button != null, "Top button exists: " + caption)
	if button == null: return
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = motion.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _manual_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for slot: int in range(1,4):
		for suffix: String in ["", ".bak"]:
			var path: String = store.path_for(slot) + suffix
			if FileAccess.file_exists(path): result[path] = _bytes(path)
	return result
func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)
func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
func _read_coins(path: String) -> int:
	var loaded := BaseState.new()
	return loaded.coins if loaded.load_game(path) == OK else -1
func _remove_fixture(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var child: String = path.path_join(entry)
		if dir.current_is_dir(): _remove_fixture(child)
		else: DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
