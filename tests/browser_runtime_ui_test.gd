extends SceneTree
## Native headless UI regression checks with browser_mode injected explicitly.
## This exercises Web-specific application branches, not browser/IndexedDB persistence.
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")
const Prefs = preload("res://scripts/view_preferences.gd")
const Slots = preload("res://scripts/local_save_slots.gd")

class RoutedState extends Model:
	var directory: String
	var fail_save: bool = false
	var writes: int = 0
	var accessed_paths: Array[String] = []
	func save_game(path: String = SAVE_PATH) -> Error:
		writes += 1
		path = directory.path_join("hero_save.json") if path == SAVE_PATH else path
		if not path.begins_with(directory + "/"): return ERR_UNAUTHORIZED
		if fail_save: path = directory.path_join("missing-directory/blocked.json")
		accessed_paths.append(path)
		return super.save_game(path)
	func load_game(path: String = SAVE_PATH) -> Error:
		path = directory.path_join("hero_save.json") if path == SAVE_PATH else path
		if not path.begins_with(directory + "/"): return ERR_UNAUTHORIZED
		accessed_paths.append(path)
		return super.load_game(path)
	func has_save() -> bool:
		return FileAccess.file_exists(directory.path_join("hero_save.json"))

class RoutedPrefs extends Prefs:
	var directory: String
	var writes: int = 0
	func load_settings(_path: String = PATH) -> Error:
		return super.load_settings(directory.path_join("preferences.cfg"))
	func save_settings(_path: String = PATH) -> Error:
		writes += 1
		return super.save_settings(directory.path_join("preferences.cfg"))

class AuditMain extends Main:
	var directory: String
	var native_exit_calls: int = 0
	var native_exit_save: bool = true
	var screenshot_target_calls: int = 0
	func _show_title() -> void:
		# Route manual-file discovery before the first title is built in _ready.
		if save_slots != null: save_slots.store = Slots.new(directory)
		super._show_title()
	func _quit_cleanly(save_progress: bool = true) -> void:
		if browser_mode:
			super._quit_cleanly(save_progress)
		else:
			# Native exit dispatch is observable without terminating this test tree.
			native_exit_calls += 1
			native_exit_save = save_progress
	func _screenshot_target(_folder: String, stamp: String) -> String:
		screenshot_target_calls += 1
		return super._screenshot_target(directory.path_join("screenshots"), stamp)

var checks: int = 0
var failures: int = 0
var fixture: String
var app

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func body(node: Node) -> String:
	var result: String = node.text if node is Label or node is RichTextLabel or node is Button else ""
	for child in node.get_children(): result += "\n" + body(child)
	return result

func button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found = button(child, caption)
		if found != null: return found
	return null

func press(node: Node, caption: String) -> void:
	var target = button(node, caption)
	check(target != null, "Clickable control exists: " + caption)
	if target != null: target.pressed.emit()
	await process_frame

func pause_status() -> String:
	var status = app.overlay.find_child("PauseDisplayStatus", true, false)
	check(status != null and status.is_visible_in_tree(), "Pause save result is visible in the menu")
	return "" if status == null else status.text

func expire_toast() -> void:
	app._process(10.0)
	check(app.toast_time <= 0, "Transient toast has expired")

func files_at(path: String) -> PackedStringArray:
	var result = PackedStringArray()
	var directory = DirAccess.open(path)
	if directory == null: return result
	for name in directory.get_files(): result.append(path.path_join(name))
	for name in directory.get_directories(): result.append_array(files_at(path.path_join(name)))
	result.sort()
	return result

func remove_fixture(path: String) -> void:
	var directory = DirAccess.open(path)
	if directory == null: return
	for name in directory.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories(): remove_fixture(path.path_join(name))
	DirAccess.remove_absolute(path)

func create_app(web_mode: bool) -> void:
	var directory = fixture.path_join("browser" if web_mode else "native")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated runtime fixture")
	app = AuditMain.new()
	check(app.browser_mode == OS.has_feature("web"), "Runtime default still follows the engine Web feature")
	app.directory = directory
	app.state = RoutedState.new()
	app.state.directory = directory
	app.view_preferences = RoutedPrefs.new()
	app.view_preferences.directory = directory
	app.view_preferences.sound_enabled = false
	if web_mode: app.browser_mode = true
	root.add_child(app)
	await process_frame
	app._stop_audio()
	check(app.current_screen == "title" and not app.state.has_save(), "Cold title uses only isolated save discovery")
	await press(app.overlay, "踏入江湖")
	check(app.current_screen == "explore" and app.state.has_save(), "New journey writes routed autosave")

func test_browser_controls() -> void:
	await create_app(true)
	app._announce_browser_storage(true)
	var controls = body(app.hud.system_bar)
	check(controls.contains("存卷") and controls.contains("读卷") and controls.contains("小憩"), "Web HUD retains clickable save/load/rest controls")
	for shortcut in ["F5", "F6", "F9", "F10"]:
		check(not controls.contains(shortcut), "Web HUD does not advertise " + shortcut)
	await press(app.hud.system_bar, "小憩 Esc")
	check(app.active_modal and app.overlay.get_meta("pause_menu", false) and app.modal_actions.size() == 5, "HUD mouse callback opens the five-row Web pause menu")
	check(button(app.overlay, "保存当前旅程") != null and button(app.overlay, "保存并返回首页") != null, "Web pause menu offers save and save/return instead of desktop quit")
	check(not body(app.overlay).contains("关闭游戏"), "Web pause copy never promises to close the browser")
	var stale_save: Callable = app.modal_actions[3]
	app.state.coins += 7
	app.world.teleport(Vector2(480, 440))
	var writes: int = app.state.writes
	await press(app.overlay, "保存当前旅程")
	check(app.state.writes == writes + 1 and not app.save_warning and app.current_screen == "explore", "Mouse save writes once and retains the live journey")
	check(app.overlay.get_meta("pause_menu", false) and pause_status().contains("已写入此浏览器"), "Successful save has explicit visible in-menu feedback")
	var saved = Model.new()
	check(saved.load_game(app.save_slots.store.path_for(0)) == OK and saved.to_dict() == app.state.to_dict(), "Web-path save round-trips actual state and current world position")
	writes = app.state.writes
	stale_save.call()
	check(app.state.writes == writes, "Save callback from the replaced pause menu is inert")
	var disk = FileAccess.get_file_as_bytes(app.save_slots.store.path_for(0))
	app.state.coins += 11
	app.state.fail_save = true
	await key(KEY_4)
	check(app.save_warning and app.current_screen == "explore" and pause_status().contains("保存失败"), "Keyboard row four exposes failed save while retaining the journey")
	check(FileAccess.get_file_as_bytes(app.save_slots.store.path_for(0)) == disk, "Real filesystem failure preserves previous autosave bytes")
	await key(KEY_ESCAPE)
	expire_toast()
	check(app.hud.toast_wash.visible and app.status_label.text.contains("小憩") and not app.status_label.text.contains("F5"), "Expired failed-save toast retains an actionable Web recovery warning")
	check(is_equal_approx(app.hud.toast_wash.modulate.a, 1.0), "Unresolved Web save failure remains fully opaque after toast expiry")
	app.state.fail_save = false
	await key(KEY_ESCAPE)
	await key(KEY_4)
	check(not app.save_warning and pause_status().contains("已写入此浏览器"), "Keyboard save retry clears the failure and reports success")
	# Manual slots use the same routed store, including their real UI callback.
	await key(KEY_ESCAPE)
	await press(app.hud.system_bar, "存卷")
	check(body(app.overlay).contains("此浏览器") and body(app.overlay).contains("清除网站数据") and not body(app.overlay).contains("F5"), "Web manual-save copy explains storage scope without refresh shortcuts")
	await key(KEY_1)
	check(app.save_slots.store.describe(1).status == "valid", "Manual save mouse-entry/keyboard-choice path writes only the isolated slot")
	await key(KEY_ESCAPE)
	await press(app.hud.system_bar, "读卷")
	check(body(app.overlay).contains("自动续写") and app.modal_actions.size() == 5, "Web load mouse callback opens autosave and three manual choices")
	await key(KEY_ESCAPE)
	# View changes prove preferences are routed as well, never normal user settings.
	await key(KEY_ESCAPE)
	await key(KEY_EQUAL)
	check(app.view_preferences.writes == 1 and FileAccess.file_exists(app.directory.path_join("preferences.cfg")), "Pause view input persists only routed test preferences")
	await key(KEY_ESCAPE)

func test_storage_and_screenshot() -> void:
	app._announce_browser_storage(false)
	app._toast("短暂提示", false, 0.01)
	expire_toast()
	check(not app.browser_storage_available and app.hud.toast_wash.visible and app.status_label.text == app._browser_storage_message(), "Unavailable browser storage remains visible after unrelated toast expiry")
	check(is_equal_approx(app.hud.toast_wash.modulate.a, 1.0), "Unavailable-storage warning does not fade with the expired toast")
	await key(KEY_ESCAPE)
	await key(KEY_4)
	check(not app.save_warning and pause_status().contains("未提供持久存储"), "Successful memory/filesystem save never claims persistence when browser storage is unavailable")
	await key(KEY_ESCAPE)
	expire_toast()
	check(app.hud.toast_wash.visible and app.status_label.text.contains("可能丢失进度"), "Storage warning survives successful save and resume")
	check(is_equal_approx(app.hud.toast_wash.modulate.a, 1.0), "Storage warning stays fully opaque after successful save and resume")
	var before_files = files_at(app.directory)
	var before_state = app.state.to_dict()
	var before_writes: int = app.state.writes
	app.last_screenshot_path = "retained previous path"
	await key(KEY_F12)
	check(app.status_label.text.contains("浏览器或系统截图工具") and not app.status_label.text.contains("已保存"), "Web F12 callback gives instructions without false screenshot success")
	check(not app.screenshot_pending and app.screenshot_target_calls == 0 and app.screenshot_sequence == 0 and app.last_screenshot_path == "retained previous path", "Web screenshot never enters native capture or creates a destination")
	check(files_at(app.directory) == before_files and app.state.to_dict() == before_state and app.state.writes == before_writes, "Web screenshot creates no files and leaves game progress unchanged")
	app._announce_browser_storage(true)
	expire_toast()
	check(not app.hud.toast_wash.visible, "Restored storage removes resolved persistent warning")

func test_title_gates() -> void:
	app.state.coins += 3
	await key(KEY_ESCAPE)
	await key(KEY_5)
	check(app.current_screen == "explore" and body(app.overlay).contains("只有保存成功才会离开"), "Web return-to-title first presents the save gate")
	app.state.fail_save = true
	var previous = FileAccess.get_file_as_bytes(app.save_slots.store.path_for(0))
	await key(KEY_1)
	check(app.current_screen == "explore" and app.active_modal and app.save_warning and not app.quit_pending, "Failed return save never reaches title or requests process quit")
	check(body(app.overlay).contains("本地写入失败") and FileAccess.get_file_as_bytes(app.save_slots.store.path_for(0)) == previous, "Failure modal reports actual write failure and keeps the existing save")
	var stale_retry: Callable = app.modal_actions[0]
	app.state.fail_save = false
	await key(KEY_1)
	check(app.current_screen == "title" and not app.save_warning and not app.quit_pending and app.native_exit_calls == 0, "Successful retry returns to title and leaves the browser process alive")
	var writes: int = app.state.writes
	stale_retry.call()
	check(app.state.writes == writes, "Stale retry cannot write after returning to title")
	await press(app.overlay, "续写前缘")
	check(app.current_screen == "explore", "Saved Web journey resumes from title")
	app.state.fail_save = true
	app._quit_cleanly(true)
	check(app.current_screen == "explore" and app.save_warning and body(app.overlay).contains("本地写入失败"), "Direct Web quit request also obeys failed-save title gating")
	await key(KEY_3)
	check(body(app.overlay).contains("不会删除已有存档"), "Discard path explicitly explains preservation of existing saves")
	await key(KEY_1)
	check(app.current_screen == "explore" and app.overlay.get_meta("pause_menu", false), "Cancelling discard keeps the current journey")
	await key(KEY_5)
	await key(KEY_1)
	await key(KEY_3)
	writes = app.state.writes
	await key(KEY_2)
	check(app.current_screen == "title" and not app.quit_pending and app.native_exit_calls == 0 and app.state.writes == writes, "Confirmed discard returns to title without writing or desktop quit")
	app.state.fail_save = false
	await press(app.overlay, "续写前缘")
	writes = app.state.writes
	app._quit_cleanly(false)
	check(app.current_screen == "title" and not app.quit_pending and app.state.writes == writes and app.native_exit_calls == 0, "Web no-save quit returns to title without native shutdown")
	for path: String in app.state.accessed_paths:
		check(path.begins_with(app.directory + "/"), "Browser-model I/O remains inside its fixture")
	app.queue_free()
	await process_frame

func test_native_defaults() -> void:
	await create_app(false)
	check(not app.browser_mode, "Native runtime remains native without injecting browser mode")
	check(body(app.hud.system_bar).contains("存卷  F6") and body(app.hud.system_bar).contains("读卷  F10"), "Native HUD retains function-key labels")
	await key(KEY_F6)
	check(body(app.overlay).contains("F5") and body(app.overlay).contains("F9"), "Native manual-save copy retains desktop shortcuts")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(button(app.overlay, "返回首页") != null and button(app.overlay, "暂别江湖") != null, "Native pause rows retain return-to-title and exit actions")
	await key(KEY_4)
	await key(KEY_1)
	check(app.current_screen == "title" and app.native_exit_calls == 0, "Native fourth row still saves and returns to title")
	await press(app.overlay, "续写前缘")
	app.state.fail_save = true
	await key(KEY_F5)
	expire_toast()
	check(app.save_warning and app.status_label.text.contains("F5"), "Native failed-save recovery still names the desktop save shortcut")
	app.state.fail_save = false
	await key(KEY_F5)
	await key(KEY_F12)
	check(app.status_label.text.contains("无图形画面") and not app.status_label.text.contains("浏览器或系统"), "Native headless screenshot retains its original feedback branch")
	await key(KEY_ESCAPE)
	await key(KEY_5)
	await key(KEY_1)
	check(app.native_exit_calls == 1 and not app.native_exit_save, "Native fifth row still dispatches desktop exit after successful save")
	app.queue_free()
	await process_frame

func run() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() != "headless":
		print("FAIL: Run this branch-injection audit with native Godot --headless")
		quit(1)
		return
	fixture = "user://browser-runtime-ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	await test_browser_controls()
	await test_storage_and_screenshot()
	await test_title_gates()
	await test_native_defaults()
	remove_fixture(fixture)
	check(not DirAccess.dir_exists_absolute(fixture), "Isolated fixtures are removed")
	if failures == 0:
		print("PASS: %d browser-mode/native UI checks (native headless branch injection; not real browser persistence)" % checks)
	else:
		print("FAIL: %d of %d browser runtime UI checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
