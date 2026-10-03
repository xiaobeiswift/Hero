extends "res://tests/audit_second_region_test.gd"
## Real Godot UI + real isolated file core; injected transport is NOT a browser.
const Slots = preload("res://scripts/local_save_slots.gd")
const TransferUI = preload("res://scripts/save_transfer_ui.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
class FixtureState extends "res://scripts/game_state.gd":
	var autosave_calls: int = 0
	var fixture_autosave: String = ""
	func save_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH:
			autosave_calls += 1
			return super.save_game(fixture_autosave)
		return super.save_game(path)
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
	var downloads: Array = []
	var enabled: bool = true
	func available() -> bool: return enabled
	func choose_file(value: int) -> bool:
		operation = value; picks += 1
		return enabled
	func cancel() -> void: cancellations += 1
	func dispose() -> void: cancel()
	func request_download(bytes: PackedByteArray, slot: int, backup: bool) -> bool:
		downloads.append({"bytes": bytes.duplicate(), "slot": slot, "backup": backup})
		return enabled
var directory: String
var fake: FakeBrowser
var core: CountedTransfer
var ui
var state_before: Dictionary
var fixture_bytes: PackedByteArray

func _run() -> void:
	directory = "user://transfer-ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated transfer fixture")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	_check(_find_button(game.overlay, "导入 / 导出手记") == null, "Native title does not promise browser transport")
	game.save_slots.transfer.dispose()
	game.save_slots.store = Slots.new(directory)
	fake = FakeBrowser.new(); core = CountedTransfer.new(directory)
	ui = TransferUI.new(game.save_slots, directory, fake, core)
	game.save_slots.transfer = ui
	game.state = FixtureState.new(); game.state.fixture_autosave = directory.path_join("fixture_auto.json")
	game.browser_mode = true; game.browser_storage_available = false
	_check(not game.web_save_transfer_enabled, "Transfer feature defaults off without explicit test opt-in")
	game._show_title()
	_check(_find_button(game.overlay, "导入 / 导出手记") == null, "Default-off Web title hides transfer entry")
	var closed_generation: int = game.modal_generation
	ui.show(); ui.targets(); ui.exports(); ui.choose_file(1, game.modal_generation); ui.download(0, false, game.modal_generation); ui.confirm(0, game.modal_generation)
	_check(fake.picks == 0 and fake.downloads.is_empty() and core.commits == 0 and game.modal_generation == closed_generation, "Default-off direct UI calls cannot pick/download/commit or open transfer")
	game.current_screen = "explore"; game.save_slots.save_page()
	_check(game.modal_actions.size() == 4 and _find_button(game.overlay, "导入 / 导出手记") == null, "Default-off Web save page retains historical four entries")
	game.web_save_transfer_enabled = true # Explicit isolated fake-transport opt-in.
	game._show_title()
	_check(_find_button(game.overlay, "导入 / 导出手记") != null, "Cold Web title always exposes import without saves")
	state_before = game.state.to_dict().duplicate(true)
	var incoming = FixtureState.new(); incoming.player_name = "[b]青苇[/b]<客>"; incoming.coins = 307
	fixture_bytes = (" \r\n" + JSON.stringify({"version": incoming.SAVE_VERSION, "player": incoming.to_dict()}, "  ") + "\r\n").to_utf8_buffer()
	_press("导入 / 导出手记")
	_check(_modal_text().contains("未提供持久存储") and _modal_text().contains("空白"), "Entry states empty-only limit and unavailable persistence")
	_press("导入到空白手记")
	await _key(KEY_1)
	_check(fake.picks == 1 and ui._target == 1, "First numeric target opens fake picker immediately")
	var cancelled_op: int = fake.operation
	fake.selection_finished.emit(cancelled_op, "cancelled", PackedByteArray())
	_check(_modal_text().contains("已取消选择") and not FileAccess.file_exists(game.save_slots.store.path_for(1)), "File cancellation never commits")
	var cancelled_generation: int = game.modal_generation
	fake.selection_finished.emit(cancelled_op, "selected", fixture_bytes)
	_check(game.modal_generation == cancelled_generation and ui._preview_token == -1, "Late selection after cancellation is ignored")
	await _key(KEY_ESCAPE)
	_check(game.current_screen == "title" and game.state.autosave_calls == 0, "Escape returns cold title without an autosave")
	await _preview(1)
	_check(_modal_text().contains("[lb]b[rb]") and not _modal_text().contains("[b]青苇"), "Validated player metadata cannot inject BBCode")
	_check(_modal_text().contains("&lt;客&gt;") and _modal_text().contains("格式"), "Preview escapes HTML and displays validated format")
	_check(_modal_text().contains("手记一 · 空白") and _modal_text().contains("另外"), "Preview names empty target and separate confirmed loading")
	_check(game.state.to_dict() == state_before and game.state.autosave_calls == 0, "Preview changes neither live state nor autosave")
	var stale_confirm: Callable = game.modal_actions[0]
	await _key(KEY_3)
	stale_confirm.call()
	_check(core.commits == 0 and not FileAccess.file_exists(game.save_slots.store.path_for(1)), "Cancelled preview invalidates retained confirm callable")
	await _preview(1)
	var first_op: int = fake.operation
	var first_confirm: Callable = game.modal_actions[0]
	await _key(KEY_2)
	var reselected_op: int = fake.operation
	_check(reselected_op != first_op, "Reselection gets a new operation token")
	fake.selection_finished.emit(first_op, "selected", fixture_bytes)
	first_confirm.call()
	_check(ui._preview_token == -1 and core.commits == 0, "Old callback and confirm cannot revive after reselection")
	fake.selection_finished.emit(reselected_op, "selected", fixture_bytes)
	var confirm: Callable = game.modal_actions[0]
	var good_token: int = ui._preview_token
	fake.selection_finished.emit(reselected_op, "selected", fixture_bytes)
	_check(ui._preview_token == good_token and good_token >= 0, "Duplicate completed callback preserves the usable valid preview")
	await _key(KEY_ENTER)
	confirm.call(); fake.selection_finished.emit(reselected_op, "selected", fixture_bytes)
	_check(core.commits == 1 and FileAccess.get_file_as_bytes(game.save_slots.store.path_for(1)) == fixture_bytes, "Explicit single-use Enter imports exact original bytes once")
	_check(_modal_text().contains("持久保存尚无完成回执") and _modal_text().contains("保留原始 JSON"), "Import success makes no durable-storage receipt claim")
	_check(game.state.to_dict() == state_before and game.state.autosave_calls == 0, "Import never autoloads, changes active journey or writes autosave")
	_check(not FileAccess.file_exists(game.save_slots.store.path_for(1) + ".bak"), "Import creates no backup")
	await _key(KEY_1)
	_check(_find_button(game.overlay, "手记一") != null and game.state.to_dict() == state_before, "Success may browse separate load list without loading")
	await _key(KEY_2)
	_check(_find_button(game.overlay, "读取当前版本") != null and game.state.to_dict() == state_before, "Existing load remains a separate choice")
	_press("读取当前版本")
	_check(_find_button(game.overlay, "确认读取") != null and game.state.to_dict() == state_before, "Existing load still requires its own confirmation")
	# Cancel, never perform the separate load in this transfer-only fixture.
	game._show_title()
	_write(game.save_slots.store.path_for(2) + ".bak", fixture_bytes)
	ui.targets()
	_check(_find_button(game.overlay, "选择文件 → 手记二") == null and _modal_text().contains("包括备份"), "Backup-only slot is occupied in target summary")
	await _preview(3)
	var preview_confirm: Callable = game.modal_actions[0]
	_write(game.save_slots.store.path_for(3) + ".bak", fixture_bytes)
	preview_confirm.call()
	_check(_modal_text().contains("导入未完成") and not FileAccess.file_exists(game.save_slots.store.path_for(3)), "Confirmation rechecks newly occupied backup-only target")
	_check(FileAccess.get_file_as_bytes(game.save_slots.store.path_for(3) + ".bak") == fixture_bytes, "Rejected confirmation preserves raced backup exactly")
	DirAccess.remove_absolute(game.save_slots.store.path_for(3) + ".bak")
	var invalid_payloads: Array[PackedByteArray] = ["{bad".to_utf8_buffer(), JSON.stringify({"version": incoming.SAVE_VERSION + 1, "player": incoming.to_dict()}).to_utf8_buffer(), PackedByteArray([255,254,253])]
	var oversized := PackedByteArray(); oversized.resize(1048577); invalid_payloads.append(oversized)
	for bytes: PackedByteArray in invalid_payloads:
		ui.targets(); _press("选择文件 → 手记三")
		fake.selection_finished.emit(fake.operation, "selected", bytes)
		_check(_modal_text().contains("未通过完整校验") and ui._preview_token == -1, "Invalid/future/UTF8/oversize payload rejected before confirm")
		await _key(KEY_ESCAPE)
		_check(game.state.autosave_calls == 0 and game.state.to_dict() == state_before, "Rejected payload and Escape preserve live state/autosave")
	await _preview(3)
	var old_confirm: Callable = game.modal_actions[0]
	game.battle_busy = true; old_confirm.call(); game.battle_busy = false; old_confirm.call()
	_check(not FileAccess.file_exists(game.save_slots.store.path_for(3)) and ui._preview_token == -1, "Pending presentation consumes confirmation without later revival")
	for blocker: String in ["battle", "party", "quit", "navigation"]:
		ui.targets(); _press("选择文件 → 手记三")
		var old_op: int = fake.operation
		match blocker:
			"battle": game.state.battle_active = true
			"party": game.state._party_pending_token = 9; game.state.party_session = preload("res://scripts/automatic_party_combat.gd").new()
			"quit": game.quit_pending = true
			"navigation": game._show_title()
		fake.selection_finished.emit(old_op, "selected", fixture_bytes)
		_check(ui._preview_token == -1 and not FileAccess.file_exists(game.save_slots.store.path_for(3)), "Late file is rejected during " + blocker)
		game.state.battle_active = false; game.state._party_pending_token = -1; game.state.party_session = null; game.quit_pending = false
		game._show_title()
	# Download known saved bytes, including a valid backup of an absent primary.
	_write(game.save_slots.store.path_for(0), fixture_bytes)
	for slot: int in [0, 1, 2]:
		ui.exports(); ui.export_detail(slot)
		_press("下载备份" if slot == 2 else "下载当前版本")
		_check(fake.downloads[-1].bytes == fixture_bytes and fake.downloads[-1].slot == slot and fake.downloads[-1].backup == (slot == 2), "Fake transport receives exact saved bytes for auto/manual/backup")
		_check(_modal_text().contains("已请求下载，请在浏览器确认保留") and _modal_text().contains("未提供文件已落盘"), "Download UI reports request only")
	_write(game.save_slots.store.path_for(1), "{invalid".to_utf8_buffer())
	ui.export_detail(1)
	_check(_find_button(game.overlay, "下载当前版本") == null, "Invalid primary cannot be offered as downloadable")
	_write(game.save_slots.store.path_for(1), fixture_bytes)
	# Exploration preserves historical 1–4 and adds transfer at key 5.
	game.current_screen = "explore"; game.state.position = game.world.player_pos; state_before = game.state.to_dict().duplicate(true)
	game.save_slots.save_page()
	_check(game.modal_actions.size() == 5 and _find_button(game.overlay, "返回江湖") != null, "Web F6 keeps historical slots and return, adds fifth transfer entry")
	await _key(KEY_5)
	_check(_find_button(game.overlay, "导入到空白手记") != null, "Key 5 enters transfer page")
	await _key(KEY_ESCAPE); await _key(KEY_ESCAPE)
	_check(not game.active_modal and game.state.autosave_calls == 0, "Transfer back then save-page Escape suppress all close-autosaves")
	ui.browse_import(); game.save_slots.detail(1); game.save_slots.request_load(1, false)
	_check(not game.modal_autosave_on_close, "Transfer-origin load confirmation preserves passive no-autosave flag")
	_press("返回详情"); _press("返回列表"); await _key(KEY_ESCAPE)
	_check(game.state.autosave_calls == 0, "Transfer-origin load/detail/cancel/list/close performs no save")
	for enabled: bool in [false, true]:
		game.web_save_transfer_enabled = enabled
		var normal_before: int = game.state.autosave_calls
		game._show_save_slots()
		_check(game.modal_autosave_on_close and not game.save_slots.transfer_browse, "Ordinary save shortcut restores historical close behavior regardless of gate")
		await _key(KEY_ESCAPE)
		game._show_load_slots()
		_check(game.modal_autosave_on_close and not game.save_slots.transfer_browse, "Ordinary load shortcut restores historical close behavior regardless of gate")
		await _key(KEY_ESCAPE)
		_check(game.state.autosave_calls == normal_before + 2, "Normal save/load close semantics are unchanged")
	await _preview(3)
	root.size = Vector2i(1179, 736)
	await process_frame
	var frame = game.overlay.get_node("DialogueSheet")
	_check(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(frame.get_rect()), "Paper transfer frame stays inside design canvas at compact 1179x736")
	for child in frame.get_children():
		if child is Button: _check(Rect2(Vector2.ZERO, frame.size).encloses(child.get_rect()), "Compact paper button bounded: " + child.name)
	var held := InputEventKey.new(); held.physical_keycode = KEY_ENTER; held.pressed = true; held.echo = true
	var commits_before: int = core.commits
	game._unhandled_key_input(held)
	_check(core.commits == commits_before, "Held/repeated Enter cannot confirm")
	var stale_after_exit: int = fake.operation
	var live_before_exit: Dictionary = game.state.to_dict().duplicate(true)
	game.queue_free(); await process_frame
	fake.selection_finished.emit(stale_after_exit, "selected", fixture_bytes)
	_check(not FileAccess.file_exists(directory.path_join("hero_slot_3.json")), "Host disposal disconnects callback and cancels preview")
	_check(live_before_exit == state_before, "All transfer operations preserve active exploration state")
	_remove_fixture(directory)
	if failures == 0: print("PASS: %d isolated transfer UI checks (fake browser transport)" % checks)
	else: push_error("FAIL: %d of %d transfer UI checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _preview(slot: int) -> void:
	ui.targets(); _press("选择文件 → " + game.save_slots.title(slot))
	fake.selection_finished.emit(fake.operation, "selected", fixture_bytes)
	await process_frame
	_check(_find_button(game.overlay, "确认导入 " + game.save_slots.title(slot)) != null, "Valid detached preview offers explicit confirm")

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Open isolated fixture path")
	if file != null: file.store_buffer(bytes); file.close()

func _remove_fixture(path: String) -> void:
	for filename in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(filename))
	for child in DirAccess.get_directories_at(path): _remove_fixture(path.path_join(child))
	DirAccess.remove_absolute(path)
