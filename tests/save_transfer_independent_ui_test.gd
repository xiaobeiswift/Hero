extends "res://tests/audit_second_region_test.gd"
## Independent real-scene audit with an injected local transport, not browser QA.
## Covers already-loaded state, failure warning retention, interruption and raw
## output identity. Every model/save path is routed to an isolated owned fixture.
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const TransferUI = preload("res://scripts/save_transfer_ui.gd")
const Model = preload("res://scripts/game_state.gd")
class Routed extends Model:
	var path: String
	var writes: int = 0
	var fail: bool = false
	func save_game(target: String = SAVE_PATH) -> Error:
		if target == SAVE_PATH:
			writes += 1
			if fail: return ERR_FILE_CANT_WRITE
			target = path
		return super.save_game(target)
	func load_game(target: String = SAVE_PATH) -> Error:
		return super.load_game(path if target == SAVE_PATH else target)
	func has_save() -> bool: return FileAccess.file_exists(path)
class Transport extends RefCounted:
	signal selection_finished(operation: int, status: String, bytes: PackedByteArray)
	var operation: int = -1
	var picks: int = 0
	var downloads: Array = []
	var present: bool = true
	var disposed: bool = false
	func available() -> bool: return present
	func choose_file(token: int) -> bool:
		operation = token; picks += 1; return present
	func cancel() -> void: pass
	func dispose() -> void: disposed = true
	func request_download(bytes: PackedByteArray, slot: int, backup: bool) -> bool:
		downloads.append({"bytes": bytes.duplicate(), "slot": slot, "backup": backup}); return present
var fixture: String
var slots
var ui
var transport: Transport
var incoming: PackedByteArray
var probe: Routed
func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture = "user://transfer-independent-ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create owned UI fixture")
	slots = Slots.new(fixture)
	probe = Routed.new(); probe.path = slots.path_for(0)
	var stored := Model.new(); stored.coins = 618; stored.hp = 38
	_check(stored.save_game(probe.path) == OK, "Write prior-session fixture autosave")
	game = load("res://scenes/main.tscn").instantiate(); game.state = probe; root.add_child(game)
	await process_frame
	game.save_slots.transfer.dispose(); game.save_slots.store = slots
	transport = Transport.new(); ui = TransferUI.new(game.save_slots, fixture, transport)
	game.save_slots.transfer = ui; game.browser_mode = true
	_check(not game.web_save_transfer_enabled and not ui.allowed(), "Release defaults to no browser transfer before explicit test opt-in")
	game.web_save_transfer_enabled = true
	incoming = ("\n" + JSON.stringify({"version": 13, "player": Model.new().to_dict()}, " ") + "\r\n").to_utf8_buffer()
	await title_and_loaded_read_only()
	await repeated_and_interrupted_callbacks()
	await download_changed_source()
	await import_then_separate_load()
	await held_pointer_and_context()
	var retained = ui
	var last_operation: int = transport.operation
	game._stop_audio(); game.queue_free(); await process_frame
	_check(transport.disposed and not transport.selection_finished.is_connected(retained._selected), "Destroying host disposes and disconnects transport callbacks")
	transport.selection_finished.emit(last_operation, "selected", incoming)
	_check(not FileAccess.file_exists(slots.path_for(2)), "Freed host cannot import from retained transport")
	_remove_fixture(fixture)
	_check(not FileAccess.file_exists(Model.SAVE_PATH), "Independent UI never creates ordinary-player autosave")
	if failures == 0: print("PASS: %d independent transfer UI isolation checks" % checks)
	else: push_error("FAIL: %d of %d independent transfer UI checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
func snapshot() -> Dictionary:
	var disk: Dictionary = {}
	for slot: int in range(4):
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			var path: String = slots.path_for(slot) + suffix
			if FileAccess.file_exists(path): disk[path] = FileAccess.get_file_as_bytes(path)
	return {"disk": disk, "state": probe.to_dict().duplicate(true), "writes": probe.writes}
func unchanged(before: Dictionary, label: String) -> void:
	_check(snapshot() == before, label)
func begin_select(slot: int) -> int:
	ui.show(); ui.targets(); ui.choose_file(slot, game.modal_generation)
	return transport.operation
func preview(slot: int) -> int:
	var operation: int = begin_select(slot)
	transport.selection_finished.emit(operation, "selected", incoming)
	return operation
func title_and_loaded_read_only() -> void:
	game._show_title()
	var before: Dictionary = snapshot()
	ui.show(); ui.exports(); ui.export_detail(0); ui.download(0, false, game.modal_generation)
	_check(transport.downloads.size() == 1 and transport.downloads[0].bytes == before.disk[probe.path], "Cold-title export uses prior-session file, never default live state")
	await _key(KEY_ESCAPE)
	unchanged(before, "Cold-title export and Escape preserve active defaults and saved branch")
	game._load()
	_check(probe.coins == 618 and probe.hp == 38 and probe.writes == 1, "Existing explicit load remains the only state/autosave transition")
	probe.coins = 819; probe.fail = true; game._save()
	_check(game.save_warning, "Prepare loaded branch with failed autosave warning")
	before = snapshot()
	ui.show(); ui.targets(); await _key(KEY_ESCAPE); game._close_modal()
	unchanged(before, "Exiting transfer through manual list cannot save loaded unsaved branch")
	_check(game.save_warning, "Transfer cancellation retains existing autosave failure warning")
	for status: String in ["cancelled", "read_error", "oversize", "invalid"]:
		var operation: int = begin_select(1)
		transport.selection_finished.emit(operation, status, PackedByteArray())
		await _key(KEY_ESCAPE); game._close_modal()
		unchanged(before, "Loaded branch remains unchanged on callback " + status)
	transport.present = false; ui.show(); await _key(KEY_ESCAPE); game._close_modal()
	unchanged(before, "Unavailable browser transport path is read-only")
	transport.present = true; probe.fail = false
func repeated_and_interrupted_callbacks() -> void:
	var before: Dictionary = snapshot()
	var operation: int = preview(1)
	var generation: int = game.modal_generation
	var token: int = ui._preview_token
	var confirm: Callable = game.modal_actions[0]
	transport.selection_finished.emit(operation, "selected", incoming)
	_check(game.modal_generation == generation and ui._preview_token == token, "Repeated completed file read does not cancel the still-valid preview")
	game._show_inventory(); confirm.call()
	transport.selection_finished.emit(operation, "selected", incoming)
	unchanged(before, "Different newer overlay invalidates old read and retained confirm")
	_check(not game.overlay.get_meta("save_transfer", false), "Old callback cannot replace newer inventory overlay")
	game.modal_autosave_on_close = false; game._close_modal()
	operation = preview(1); confirm = game.modal_actions[0]
	game.quit_pending = true; confirm.call(); game.quit_pending = false; confirm.call()
	unchanged(before, "Quit interruption consumes pending UI confirmation and cannot revive on reset")
	_check(ui._preview_token == -1, "Quit-interrupted preview token is invalidated")
	ui.show()
func download_changed_source() -> void:
	_write(slots.path_for(1), incoming)
	ui.show(); ui.export_detail(1)
	var download: Callable = game.modal_actions[0]
	_write(slots.path_for(1), "{damaged after detail".to_utf8_buffer())
	var before: Dictionary = snapshot()
	var count: int = transport.downloads.size()
	download.call()
	_check(transport.downloads.size() == count and _modal_text().contains("未请求下载"), "Download revalidates changed source instead of trusting old metadata")
	unchanged(before, "Rejected export preserves damaged source and loaded live branch")
	_write(slots.path_for(1), incoming); _write(slots.path_for(1) + ".bak", incoming)
	before = snapshot(); ui.export_detail(1)
	_press("下载备份")
	_check(transport.downloads.size() == count + 1 and transport.downloads[-1].bytes == incoming and transport.downloads[-1].backup, "Backup export returns exact bytes of explicit backup selection")
	await _key(KEY_ESCAPE); game._close_modal()
	unchanged(before, "Backup export and leaving do not autosave unsaved loaded state")
func import_then_separate_load() -> void:
	var before: Dictionary = snapshot()
	preview(3)
	var confirm: Callable = game.modal_actions[0]
	confirm.call(); confirm.call()
	_check(probe.to_dict() == before.state and probe.writes == before.writes and FileAccess.get_file_as_bytes(probe.path) == before.disk[probe.path], "Import success preserves already-loaded unsaved branch and exact autosave")
	_check(FileAccess.get_file_as_bytes(slots.path_for(3)) == incoming and not FileAccess.file_exists(slots.path_for(3) + ".bak"), "Single explicit import writes only raw third-slot primary")
	var after_import: Dictionary = snapshot()
	_press("查阅手记"); game.save_slots.detail(3); _press("读取当前版本")
	unchanged(after_import, "Navigating success to existing load confirmation is still read-only")
	_press("确认读取")
	_check(probe.coins == 24 and probe.writes == before.writes + 1 and not game.active_modal, "Separate explicit load applies imported state and existing autosave exactly once")
	_check(FileAccess.get_file_as_bytes(slots.path_for(3)) == incoming and not FileAccess.file_exists(slots.path_for(3) + ".bak"), "Separate load preserves imported raw primary without migration writeback")
func held_pointer_and_context() -> void:
	var before: Dictionary = snapshot()
	preview(2)
	var button: Button = _find_button(game.overlay, "确认导入 手记二")
	_check(button != null, "Locate explicit second-slot confirm")
	var position: Vector2 = button.get_global_rect().get_center()
	var down := InputEventMouseButton.new(); down.position = position; down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true
	root.push_input(down, true); await process_frame
	ui.show()
	var up := InputEventMouseButton.new(); up.position = position; up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
	root.push_input(up, true); await process_frame
	unchanged(before, "Mouse release from replaced confirm cannot import into new page")
	for context: String in ["battle", "receipt_battle", "party_battle", "unknown"]:
		game.current_screen = "explore"; preview(2)
		var confirm: Callable = game.modal_actions[0]
		game.current_screen = context; confirm.call()
		game.current_screen = "explore"; confirm.call()
		unchanged(before, "Bad screen invalidates retained import confirmation: " + context)
	game.current_screen = "explore"; preview(2)
	var confirm: Callable = game.modal_actions[0]
	game.web_save_transfer_enabled = false; confirm.call()
	game.web_save_transfer_enabled = true; confirm.call()
	unchanged(before, "Disabling rollout during preview consumes old authorization")
	ui.show()
func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Write isolated UI file")
	if file != null: file.store_buffer(bytes); file.flush(); file.close()
func _remove_fixture(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		if directory.current_is_dir(): _remove_fixture(full)
		else: DirAccess.remove_absolute(full)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
