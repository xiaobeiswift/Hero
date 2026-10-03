extends RefCounted
## Thin Web transport. It never parses save JSON or chooses filesystem paths.
## Download dispatch is not a browser/disk persistence receipt.
signal selection_finished(operation: int, status: String, bytes: PackedByteArray)
const MAX_IMPORT_BYTES: int = 1048576
var _bridge
var _page
var _callback
var _operation: int = -1

func _init() -> void:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		_bridge = Engine.get_singleton("JavaScriptBridge")
		_page = _bridge.get_interface("HeroSaveTransfer")
		if _page != null:
			# Godot callbacks must remain referenced while JavaScript can call them.
			_callback = _bridge.create_callback(_received)

func available() -> bool:
	return _bridge != null and _page != null and _callback != null

func choose_file(operation: int) -> bool:
	if not available(): return false
	cancel()
	_operation = operation
	# Invoked directly from the button/key handler. No await/deferred picker.
	return bool(_page.chooseFile(operation, _callback))

func cancel() -> void:
	_operation = -1
	if _page != null: _page.cancel()

func dispose() -> void:
	cancel()
	_callback = null
	_page = null
	_bridge = null

func request_download(bytes: PackedByteArray, slot: int, backup: bool) -> bool:
	if not available() or bytes.is_empty() or bytes.size() > MAX_IMPORT_BYTES: return false
	if slot < 0 or slot > 3 or (slot == 0 and backup): return false
	var filename: String = "Hero-auto.json" if slot == 0 else "Hero-slot-%d%s.json" % [slot, "-backup" if backup else ""]
	# Pinned Godot 4.6.3: download_buffer returns void, never a success flag.
	_bridge.download_buffer(bytes, filename, "application/json")
	return true

func _received(args: Array) -> void:
	if args.size() < 2 or not (args[0] is int or args[0] is float) or not args[1] is String: return
	if _operation < 0 or args[0] != _operation: return
	var operation: int = _operation # Reject fractional/nonfinite IDs before integer coercion.
	_operation = -1 # One terminal callback per selection, even on a malformed result.
	var status: String = args[1]
	var bytes := PackedByteArray()
	if status == "selected":
		if args.size() != 3 or args[2] == null:
			status = "invalid"
		else:
			bytes = _bridge.js_buffer_to_packed_byte_array(args[2])
			if bytes.is_empty() or bytes.size() > MAX_IMPORT_BYTES:
				status = "oversize" if bytes.size() > MAX_IMPORT_BYTES else "invalid"
				bytes = PackedByteArray()
	elif status not in ["cancelled", "oversize", "invalid", "read_error"]:
		status = "invalid"
	selection_finished.emit(operation, status, bytes)
