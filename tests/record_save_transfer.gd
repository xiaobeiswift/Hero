extends SceneTree
## Actual full-main-scene native TEST evidence. Browser mode, feature opt-in and
## transport are injected; the file core, InputEvents and rendered UI are real.
const Model = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const TransferUI = preload("res://scripts/save_transfer_ui.gd")
class FixtureState extends "res://scripts/game_state.gd":
	var saves: int = 0
	var loads: int = 0
	var fixture_path: String
	func save_game(path: String = SAVE_PATH) -> Error:
		saves += 1
		return super.save_game(fixture_path if path == SAVE_PATH else path)
	func load_game(path: String = SAVE_PATH) -> Error:
		loads += 1
		return super.load_game(fixture_path if path == SAVE_PATH else path)
	func has_save() -> bool: return false
class CountedTransfer extends "res://scripts/local_save_transfer.gd":
	var commits: int = 0
	func commit_import(token: int) -> Dictionary:
		commits += 1
		return super.commit_import(token)
class FakeBrowser extends RefCounted:
	signal selection_finished(operation: int, status: String, bytes: PackedByteArray)
	var operation: int = -1
	var picks: int = 0
	var cancellations: int = 0
	var downloads: Array[Dictionary] = []
	func available() -> bool: return true
	func choose_file(value: int) -> bool:
		operation = value; picks += 1; return true
	func cancel() -> void: cancellations += 1
	func dispose() -> void: cancel()
	func request_download(bytes: PackedByteArray, slot: int, backup: bool) -> bool:
		downloads.append({"bytes": bytes.duplicate(), "slot": slot, "backup": backup}); return true
var app
var state: FixtureState
var fake: FakeBrowser
var core: CountedTransfer
var ui
var checks: int = 0
var failures: int = 0
var evidence_dir: String = ""
var source_manifest: String = ""
var source_identity: String = ""
var capture_mode: String = "validate"
var runtime_hashes: Dictionary = {}
var captures: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var fixture_root: String
var store_dir: String
var synthetic_path: String
var fixture_bytes: PackedByteArray
var expected_files: Dictionary = {}
var seeded_files: Dictionary = {}
var baseline: Dictionary = {}
var banner: Label
var opted_in: bool = false

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1; push_error("Save transfer native: " + message)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): evidence_dir = argument.trim_prefix("--out=")
		if argument.begins_with("--manifest="): source_manifest = argument.trim_prefix("--manifest=")
		if argument.begins_with("--source="): source_identity = argument.trim_prefix("--source=")
		if argument.begins_with("--mode="): capture_mode = argument.trim_prefix("--mode=")
	if evidence_dir.is_empty() or source_manifest.is_empty() or source_identity.is_empty() or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Explicit isolated paths and source identity required"); quit(2); return
	runtime_hashes = JSON.parse_string(FileAccess.get_file_as_string(source_manifest))
	_verify_source()
	check(ProjectSettings.get_setting("hero/features/web_save_transfer_enabled", true) == false, "Production project feature gate remains false")
	DirAccess.make_dir_recursive_absolute(evidence_dir + "/screenshots")
	fixture_root = "user://TEST_ROOT-save-transfer-%d" % OS.get_process_id()
	store_dir = fixture_root.path_join("store")
	check(DirAccess.make_dir_recursive_absolute(store_dir) == OK, "Create isolated TEST_ROOT fixture")
	state = FixtureState.new(); state.fixture_path = store_dir.path_join("hero_save.json")
	app = load("res://scenes/main.tscn").instantiate(); app.state = state
	root.add_child(app); await process_frame
	app._stop_audio(); app.audio_on = false; app.set_process(false); app.world.set_process(false)
	app.save_slots.transfer.dispose(); app.save_slots.store = Slots.new(store_dir)
	fake = FakeBrowser.new(); core = CountedTransfer.new(store_dir)
	ui = TransferUI.new(app.save_slots, store_dir, fake, core); app.save_slots.transfer = ui
	app.browser_mode = true; app.browser_storage_available = false
	check(not app.web_save_transfer_enabled, "Main feature gate defaults off before TEST opt-in")
	root.size = Vector2i(1280, 800)
	app._show_title(); baseline = state.to_dict().duplicate(true)
	_add_test_banner(); await _settle()
	check(_button(app.overlay, "导入 / 导出手记") == null, "Default-off cold Web title has no transfer entry")
	check(_files(fixture_root).is_empty(), "Cold title starts with no fixture saves")
	_assert_unchanged("cold default-off title")
	await _capture("01-default-off-cold-web-title-1280x800", "Production gate OFF; injected Web mode; empty isolated store")

	app.web_save_transfer_enabled = true; opted_in = true; app._show_title(); await _settle()
	await _click_text("导入 / 导出手记")
	check(_body().contains("未提供持久存储"), "Opt-in menu explains unavailable persistence")
	_assert_unchanged("explicit isolated TEST opt-in menu")
	await _capture("02-test-opt-in-transfer-menu-1280x800", "TEST gate ON; empty store; no file transport has occurred")

	# Explicit synthetic file preparation occurs only after the cold views.
	var incoming = Model.new(); incoming.player_name = "青苇·试验旅人"; incoming.coins = 307
	check(incoming._stage_save_data(incoming.to_dict(), incoming.SAVE_VERSION).ok, "Prepared synthetic incoming state is canonical")
	fixture_bytes = (" \r\n" + JSON.stringify({"version": incoming.SAVE_VERSION, "player": incoming.to_dict()}, "  ") + "\r\n").to_utf8_buffer()
	synthetic_path = fixture_root.path_join("prepared-synthetic-original.json")
	_write(synthetic_path, fixture_bytes)
	_write(app.save_slots.store.path_for(0), fixture_bytes)
	_write(app.save_slots.store.path_for(2) + ".bak", fixture_bytes)
	_write(store_dir.path_join("unrelated-retained-sentinel.txt"), "TEST ONLY retained bytes; do not modify\n".to_utf8_buffer())
	expected_files = _files(fixture_root); seeded_files = expected_files.duplicate(true)
	inputs.append({"kind": "explicit_synthetic_fixture_setup", "files": seeded_files, "note": "These prepared synthetic files are not player saves and are not gameplay-earned state"})
	await _click_text("导入到空白手记"); await _click_text("选择文件 → 手记一")
	await _deliver("selected", FileAccess.get_file_as_bytes(synthetic_path))
	check(_body().contains("格式 %d" % Model.SAVE_VERSION) and _body().contains("青苇·试验旅人"), "Preview shows validated synthetic metadata")
	check(_body().contains("另外") and _body().contains("空白"), "Preview explains separate loading and empty target")
	check(core.commits == 0 and not FileAccess.file_exists(app.save_slots.store.path_for(1)), "Preview has not written destination")
	_assert_unchanged("validated preview before confirmation")
	await _capture("03-synthetic-json-empty-target-preview-1280x800", "Prepared JSON validated; slot 1 empty; no commit or load")

	root.gui_release_focus(); await _key(KEY_ENTER)
	expected_files["store/hero_slot_1.json"] = FileAccess.get_sha256(synthetic_path)
	check(core.commits == 1, "Actual Enter confirmation commits exactly once")
	check(FileAccess.get_file_as_bytes(app.save_slots.store.path_for(1)) == fixture_bytes, "Confirmed empty target contains exact original raw bytes")
	check(_body().contains("未自动读取") and _body().contains("尚无完成回执"), "Success says no autoload and no persistence receipt")
	_assert_unchanged("single confirmed import success")
	await _capture("04-confirmed-import-no-autoload-1280x800", "Exactly one confirmed raw-byte create; live state and autosave unchanged")

	await _click_text("返回转存"); await _click_text("导入到空白手记")
	check(_button(app.overlay, "选择文件 → 手记一") == null and _button(app.overlay, "选择文件 → 手记二") == null, "Primary-occupied and backup-only slots cannot be selected")
	check(_button(app.overlay, "选择文件 → 手记三") != null, "Only still-empty slot 3 is offered")
	_assert_unchanged("occupied and backup-only target list")
	await _capture("05-occupied-backup-only-unavailable-1280x800", "Slot 1 occupied; slot 2 backup-only retained; only slot 3 selectable")

	await _click_text("选择文件 → 手记三"); await _deliver("selected", "{not-json".to_utf8_buffer())
	check(_body().contains("未通过完整校验") and ui._preview_token == -1, "Invalid JSON is rejected without confirm token")
	_assert_unchanged("invalid JSON rejection")
	await _capture("06-invalid-json-no-change-1280x800", "Invalid synthetic JSON rejected; no target or other file change")

	await _click_text("重新选择文件")
	var cancelled_operation: int = fake.operation
	await _deliver("cancelled", PackedByteArray())
	check(_body().contains("已取消选择文件"), "File cancellation gives readable no-change status")
	fake.selection_finished.emit(cancelled_operation, "selected", fixture_bytes); await _settle()
	check(ui._preview_token == -1 and core.commits == 1, "Late cancelled callback cannot restore preview or commit")
	_assert_unchanged("cancelled selection and late callback")
	await _capture("07-cancelled-file-no-change-1280x800", "Cancelled fake picker; stale selected callback ignored; files unchanged")

	await _click_text("返回转存"); await _click_text("下载已存手记"); await _click_text("手记二")
	check(_button(app.overlay, "下载当前版本") == null, "Backup-only export has no nonexistent primary choice")
	await _click_text("下载备份")
	check(fake.downloads.size() == 1 and fake.downloads[0].bytes == fixture_bytes and fake.downloads[0].backup and fake.downloads[0].slot == 2, "Fake download request receives exact retained backup bytes")
	check(_body().contains("已请求下载") and _body().contains("未提供文件已落盘"), "Download status promises request only, never actual download success")
	_assert_unchanged("fake backup download request")
	await _click_text("返回转存"); await _click_text("导入到空白手记"); await _click_text("选择文件 → 手记三")
	await _deliver("selected", fixture_bytes)
	root.size = Vector2i(1179, 737); await _settle()
	_assert_unchanged("compact validated preview before cancellation")
	await _capture("08-compact-empty-target-preview-1179x736", "Requested 1179x737; aspect-kept native framebuffer 1179x736; unconfirmed slot 3")
	root.gui_release_focus(); await _key(KEY_3)
	check(_button(app.overlay, "导入到空白手记") != null and ui._preview_token == -1, "Actual numeric key cancels compact preview")
	await _key(KEY_ESCAPE)
	check(app.current_screen == "title", "Actual Escape returns to title without loading")
	_assert_unchanged("cancel compact preview then Escape")
	check(not FileAccess.file_exists(app.save_slots.store.path_for(3)), "Unconfirmed slot 3 never created")
	check(not FileAccess.file_exists(app.save_slots.store.path_for(1) + ".bak"), "Import does not invent a backup")
	check(core.commits == 1 and state.saves == 0 and state.loads == 0, "Exactly one file-core commit; zero live save or load calls")
	_verify_source()
	var downloads: Array[Dictionary] = []
	for entry: Dictionary in fake.downloads:
		downloads.append({"slot": entry.slot, "backup": entry.backup, "bytes": entry.bytes.size(), "equals_prepared_raw_bytes": entry.bytes == fixture_bytes, "transport": "FAKEBROWSERTRANSPORT", "actual_browser_download": false})
	var result: Dictionary = {"scope": "Actual NATIVE Godot full main scene with injected browser_mode, explicit isolated TEST-GATE-OPT-IN and FAKEBROWSERTRANSPORT. Real local transfer core and synthetic fixture files; actual Godot InputEvent buttons and keys. No genuine browser, OS picker, browser download, persistent-storage, manual-play, export or release claim.", "source_identity": source_identity, "mode": capture_mode, "engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "production_default_gate": ProjectSettings.get_setting("hero/features/web_save_transfer_enabled"), "checks": checks, "failures": failures, "captured": captures, "inputs": inputs, "checkpoints": checkpoints, "runtime_sha256": runtime_hashes, "fixture_root": ProjectSettings.globalize_path(fixture_root), "seeded_files": seeded_files, "final_files": _files(fixture_root), "only_confirmed_created_file": "store/hero_slot_1.json", "fixture_raw_sha256": FileAccess.get_sha256(synthetic_path), "fixture_raw_bytes": fixture_bytes.size(), "retained_backup_sha256": FileAccess.get_sha256(app.save_slots.store.path_for(2) + ".bak"), "live_state_unchanged": state.to_dict() == baseline, "live_save_calls": state.saves, "live_load_calls": state.loads, "core_commit_calls": core.commits, "fake_picker_requests": fake.picks, "fake_download_requests": downloads}
	var output = FileAccess.open(evidence_dir + "/transfer-trace.json", FileAccess.WRITE)
	check(output != null, "Trace file opens"); result.checks = checks; result.failures = failures
	if output != null: output.store_string(JSON.stringify(result, "\t")); output.close()
	print("%s: save transfer %s; %d checks, %d capture records (native only outside headless)" % ["PASS" if failures == 0 else "FAIL", capture_mode, checks, captures.size()])
	app._stop_audio(); app.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)

func _add_test_banner() -> void:
	var layer = CanvasLayer.new(); layer.layer = 100; root.add_child(layer)
	banner = Label.new(); banner.position = Vector2(8, 8); banner.size = Vector2(1264, 46)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 13)
	banner.add_theme_color_override("font_color", Color.WHITE)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.01, 0.02, 0.03, .93)
	style.content_margin_left = 8; style.content_margin_top = 4; style.content_margin_bottom = 4
	banner.add_theme_stylebox_override("normal", style); layer.add_child(banner)

func _verify_source() -> void:
	for path: String in runtime_hashes:
		check(FileAccess.get_sha256("res://" + path) == runtime_hashes[path], "Exact source resource: " + path)

func _settle() -> void:
	for _i in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = _button(child, text)
		if found != null: return found
	return null

func _body() -> String:
	var label = app.overlay.find_child("DialogueBody", true, false)
	return label.text if label != null else ""

func _click_text(text: String) -> void:
	await _settle()
	var control = _button(app.overlay, text)
	check(control != null, "Actual input target exists: " + text)
	if control == null: return
	var logical: Vector2 = control.get_global_rect().get_center()
	var center: Vector2 = root.get_final_transform() * logical
	inputs.append({"kind": "actual_InputEventMouseButton_press_release", "text": text, "target": String(control.get_path()), "logical": [logical.x, logical.y], "window": [center.x, center.y]})
	var event = InputEventMouseButton.new(); event.position = center; event.global_position = center; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event.pressed = false; Input.parse_input_event(event); await _settle()

func _key(key: Key) -> void:
	inputs.append({"kind": "actual_InputEventKey_press_release", "physical_keycode": key})
	var event = InputEventKey.new(); event.physical_keycode = key; event.keycode = key; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event.pressed = false; Input.parse_input_event(event); await _settle()

func _deliver(status: String, bytes: PackedByteArray) -> void:
	inputs.append({"kind": "FAKEBROWSERTRANSPORT_selection_callback", "operation": fake.operation, "status": status, "bytes": bytes.size(), "actual_browser": false})
	fake.selection_finished.emit(fake.operation, status, bytes); await _settle()

func _write(path: String, bytes: PackedByteArray) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Explicit synthetic fixture opens: " + path.get_file())
	if file != null: file.store_buffer(bytes); file.close()

func _files(path: String, prefix: String = "") -> Dictionary:
	var result: Dictionary = {}
	for filename: String in DirAccess.get_files_at(path):
		result[prefix + filename] = FileAccess.get_sha256(path.path_join(filename))
	for directory: String in DirAccess.get_directories_at(path):
		result.merge(_files(path.path_join(directory), prefix + directory + "/"))
	return result

func _assert_unchanged(label: String) -> void:
	check(state.to_dict() == baseline, label + ": live journey unchanged")
	check(state.saves == 0 and state.loads == 0, label + ": no save/autosave or load call")
	check(_files(fixture_root) == expected_files, label + ": exact expected files and bytes only")
	checkpoints.append({"label": label, "state_unchanged": state.to_dict() == baseline, "save_calls": state.saves, "load_calls": state.loads, "core_commits": core.commits, "files": _files(fixture_root)})

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _capture(name: String, note: String) -> void:
	banner.text = "NATIVE TEST EVIDENCE | TEST-GATE-OPT-IN: " + ("ON (isolated test only)" if opted_in else "OFF (production default)") + " | FAKEBROWSERTRANSPORT\n" + note
	await _settle()
	var geometry: Dictionary = {}
	var frame = app.overlay.get_node_or_null("DialogueSheet")
	if frame != null:
		check(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(frame.get_rect()), name + ": frame inside design canvas")
		var body: RichTextLabel = frame.get_node("DialogueBody")
		check(Rect2(Vector2.ZERO, frame.size).encloses(body.get_rect()), name + ": body viewport inside frame")
		geometry = {"frame": _rect(frame.get_global_rect()), "body": _rect(body.get_global_rect()), "body_content_height": body.get_content_height(), "body_view_height": body.size.y, "body_scroll_active": body.scroll_active, "body_parsed_text": body.get_parsed_text(), "buttons": []}
		for child in frame.get_children():
			if child is Button:
				check(Rect2(Vector2.ZERO, frame.size).encloses(child.get_rect()), name + ": button inside frame: " + child.text)
				var caption: Label = child.get_node("ChoiceCaption")
				check(Rect2(Vector2.ZERO, child.size).encloses(caption.get_rect()) and caption.get_minimum_size().y <= caption.size.y, name + ": caption shaped height fits: " + child.text)
				geometry.buttons.append({"text": child.text, "rect": _rect(child.get_global_rect()), "caption_rect": _rect(caption.get_global_rect()), "caption_minimum": [caption.get_minimum_size().x, caption.get_minimum_size().y]})
	var row: Dictionary = {"name": name, "native_rendered": DisplayServer.get_name() != "headless", "requested_window_size": [root.size.x, root.size.y], "note": note, "TEST-GATE-OPT-IN": opted_in, "FAKEBROWSERTRANSPORT": true, "production_default_gate": false, "screen": app.current_screen, "modal_title": frame.get_node("DialogueTitle").text if frame != null else "渡灯录", "body": _body(), "geometry": geometry, "state_unchanged": state.to_dict() == baseline, "save_calls": state.saves, "load_calls": state.loads, "core_commits": core.commits, "files": _files(fixture_root)}
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var pixels: Image = root.get_texture().get_image()
		var aspect_scale: float = minf(float(root.size.x) / 1280.0, float(root.size.y) / 800.0)
		var expected: Vector2i = Vector2i(floori(1280.0 * aspect_scale), floori(800.0 * aspect_scale))
		check(pixels.get_size() == expected, name + ": actual framebuffer uses aspect-kept expected size")
		var path: String = evidence_dir + "/screenshots/" + name + ".png"
		check(pixels.save_png(path) == OK, name + ": actual framebuffer saved")
		row.width = pixels.get_width(); row.height = pixels.get_height(); row.sha256 = FileAccess.get_sha256(path)
	captures.append(row)
	print("FRAME ", name, " native_rendered=", row.native_rendered)
