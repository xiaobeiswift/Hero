class_name LocalSaveTransfer
extends RefCounted
## Exact-byte local transfer. Only an empty manual slot can receive an import.
## No operation saves/loads a live model, rotates backups, or rewrites schemas.
## Atomic rename protects this synchronous VFS operation, not browser durability
## or a different tab/process racing the final check. SHA-256 detects changed
## bytes; it is neither a signature nor evidence that a save is authentic.

const State = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const MAX_IMPORT_BYTES: int = State.MAX_SAVE_BYTES
# Actual Hero documents are shallow. Bound parser work before handing arbitrary
# untrusted structures to JSON; this envelope does not change legacy semantics.
const MAX_JSON_NESTING: int = 512

var _slots: Slots
var _directory: String
var _token_counter: int = 0
var _preview: Dictionary = {}


func _init(directory: String = "user://") -> void:
	_directory = directory
	_slots = Slots.new(directory)


func export_slot(slot: Variant, backup: bool = false) -> Dictionary:
	if not _valid_slot(slot, not backup):
		return _failure(ERR_INVALID_PARAMETER, "invalid_slot")
	var path: String = _slots.path_for(slot) + (".bak" if backup else "")
	var read: Dictionary = _read_bytes(path)
	if not read.ok:
		return read
	var inspected: Dictionary = _inspect_bytes(read.bytes)
	if not inspected.ok:
		return inspected
	return {
		"ok": true, "error": OK, "bytes": read.bytes, "digest": _digest(read.bytes),
		"version": inspected.version, "metadata": _metadata(inspected.state),
	}


func target_available(slot: Variant) -> bool:
	if not _valid_slot(slot, false) or DirAccess.open(_directory) == null:
		return false
	var path: String = _slots.path_for(slot)
	# Pending ordinary saves are conflicts too. Never clean up a preexisting
	# .tmp file, and never consider a backup-only slot empty.
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if _exists(path + suffix):
			return false
	return true


func preview_import(bytes: PackedByteArray, slot: Variant) -> Dictionary:
	# Even a rejected new selection invalidates an older confirmation.
	_preview = {}
	if not _valid_slot(slot, false):
		return _failure(ERR_INVALID_PARAMETER, "invalid_slot")
	var inspected: Dictionary = _inspect_bytes(bytes)
	if not inspected.ok:
		return inspected
	if not target_available(slot):
		return _failure(ERR_ALREADY_EXISTS, "target_occupied")
	_token_counter += 1
	var digest: String = _digest(bytes)
	_preview = {
		"token": _token_counter, "bytes": bytes.duplicate(), "digest": digest,
		"slot": slot, "destination": _slots.path_for(slot), "directory": _directory,
		"committed": false, "consumed": false,
	}
	return {
		"ok": true, "error": OK, "token": _token_counter, "digest": digest,
		"version": inspected.version, "metadata": _metadata(inspected.state), "target_slot": slot,
	}


func cancel_preview(token: int) -> void:
	if _preview.get("token", -1) == token:
		_preview = {}


func commit_import(token: int) -> Dictionary:
	if _preview.is_empty() or _preview.token != token:
		return _failure(ERR_INVALID_PARAMETER, "stale_preview")
	if _preview.consumed and not _preview.committed:
		return _failure(ERR_INVALID_PARAMETER, "stale_preview")
	# One user confirmation authorizes one attempt. Any failure needs a fresh
	# preview even if a transient disk error or competing file later disappears.
	_preview.consumed = true
	var bytes: PackedByteArray = _preview.bytes
	if _digest(bytes) != _preview.digest:
		return _failure(ERR_FILE_CORRUPT, "changed_preview")
	var slot: int = _preview.slot
	var destination: String = _preview.destination
	if destination != _slots.path_for(slot) or _directory != _preview.directory:
		return _failure(ERR_INVALID_PARAMETER, "changed_target")
	if _preview.committed:
		# Repeated activation is a read-only no-op only while the previous result
		# still exists exactly. A changed/replaced/deleted target is never success.
		var read: Dictionary = _read_bytes(destination)
		if not read.ok or read.bytes != bytes:
			return _failure(ERR_ALREADY_EXISTS, "stale_preview")
		for suffix: String in [".bak", ".tmp", ".bak.tmp"]:
			if _exists(destination + suffix):
				return _failure(ERR_ALREADY_EXISTS, "stale_preview")
		return {"ok": true, "error": OK, "status": "already_imported"}
	if not target_available(slot):
		return _failure(ERR_ALREADY_EXISTS, "target_occupied")
	# Reuse the shared validator on the privately retained immutable bytes.
	var inspected: Dictionary = _inspect_bytes(bytes)
	if not inspected.ok:
		return inspected
	var stage: Dictionary = _create_stage_directory()
	if not stage.ok:
		return stage
	var temporary: String = String(stage.path).path_join("incoming.json")
	var file: FileAccess = _open_stage(temporary)
	if file == null:
		_cleanup_stage(stage.path, temporary)
		return _failure(ERR_FILE_CANT_OPEN, "stage_open_failed")
	var write_error: Error = _write_stage(file, bytes)
	if write_error == OK:
		write_error = _flush_stage(file)
	file.close()
	if write_error != OK:
		_cleanup_stage(stage.path, temporary)
		return _failure(write_error, "stage_write_failed")
	var readback: Dictionary = _read_bytes(temporary)
	if not readback.ok or readback.bytes != bytes or _digest(readback.bytes) != _preview.digest:
		_cleanup_stage(stage.path, temporary)
		return _failure(ERR_FILE_CORRUPT, "stage_readback_failed")
	# Final check and rename are consecutive synchronous operations: no await,
	# callback, model mutation, backup rotation, or deletion in between.
	if not target_available(slot):
		_cleanup_stage(stage.path, temporary)
		return _failure(ERR_ALREADY_EXISTS, "target_occupied")
	var rename_error: Error = _rename_stage(temporary, destination)
	if rename_error != OK:
		_cleanup_stage(stage.path, temporary)
		return _failure(rename_error, "stage_rename_failed")
	_preview.committed = true
	# The staged bytes now live in the target. Only remove our empty directory.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))
	return {"ok": true, "error": OK, "status": "imported"}


func _inspect_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return _failure(ERR_FILE_CORRUPT, "empty_input")
	if bytes.size() > MAX_IMPORT_BYTES:
		return _failure(ERR_FILE_CORRUPT, "too_large")
	if not _valid_utf8(bytes):
		return _failure(ERR_FILE_CORRUPT, "invalid_encoding")
	if not _bounded_json_nesting(bytes):
		return _failure(ERR_FILE_CORRUPT, "too_deep")
	var inspected: Dictionary = State.new().inspect_save_bytes(bytes)
	if not inspected.ok:
		return _failure(inspected.error, "unsupported_version" if inspected.error == ERR_FILE_UNRECOGNIZED else "invalid_save")
	return inspected


func _metadata(state: State) -> Dictionary:
	return {"player_name": state.player_name, "level": state.level, "location": state.map_id, "hp": state.hp, "max_hp": state.max_hp}


func _valid_slot(slot: Variant, allow_autosave: bool) -> bool:
	return slot is int and slot >= (0 if allow_autosave else 1) and slot <= 3


func _exists(path: String) -> bool:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		return true
	# A dangling symlink is still a conflicting path, not an empty slot.
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())


func _read_bytes(path: String) -> Dictionary:
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	if parent == null or parent.is_link(path.get_file()) or DirAccess.dir_exists_absolute(path):
		return _failure(ERR_FILE_CANT_READ, "source_conflict")
	if not FileAccess.file_exists(path):
		return _failure(ERR_FILE_NOT_FOUND, "missing_source")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(FileAccess.get_open_error(), "source_open_failed")
	var length: int = file.get_length()
	if length > MAX_IMPORT_BYTES:
		file.close()
		return _failure(ERR_FILE_CORRUPT, "too_large")
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or read_error != OK:
		return _failure(ERR_FILE_CANT_READ, "source_read_failed")
	return {"ok": true, "error": OK, "bytes": bytes}


func _create_stage_directory() -> Dictionary:
	# make_dir is the ownership claim. FileAccess.WRITE cannot exclusively
	# create a file, so never open a guessed/preexisting temp filename directly.
	# A per-operation directory also prevents deleting another writer's .tmp.
	var path: String = _directory.path_join(".hero-import-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()])
	var error: Error = DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return _failure(error, "stage_create_failed")
	return {"ok": true, "error": OK, "path": path}


func _open_stage(path: String) -> FileAccess:
	return FileAccess.open(path, FileAccess.WRITE)


func _write_stage(file: FileAccess, bytes: PackedByteArray) -> Error:
	file.store_buffer(bytes)
	return file.get_error()


func _flush_stage(file: FileAccess) -> Error:
	file.flush()
	return file.get_error()


func _rename_stage(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))


func _cleanup_stage(directory: String, temporary: String) -> void:
	# Called only for a directory this operation successfully created, and only
	# the one known filename. Never recursively delete or touch existing temps.
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _failure(error: Error, reason: String) -> Dictionary:
	return {"ok": false, "error": error, "reason": reason}


func _valid_utf8(bytes: PackedByteArray) -> bool:
	# Validate scalar UTF-8 without the decoder's replacement characters or
	# error logging. A leading BOM is valid and Godot strips it for parsing;
	# retain it unchanged in the exported/imported bytes. Reject raw NUL because
	# Godot's String decoder replaces it, obscuring the original document.
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 128:
			if first == 0:
				return false
			index += 1
			continue
		var count: int = 0
		var scalar: int = 0
		var minimum: int = 0
		if first >= 194 and first <= 223:
			count = 2; scalar = first & 31; minimum = 128
		elif first >= 224 and first <= 239:
			count = 3; scalar = first & 15; minimum = 2048
		elif first >= 240 and first <= 244:
			count = 4; scalar = first & 7; minimum = 65536
		else:
			return false
		if index + count > bytes.size():
			return false
		for offset: int in range(1, count):
			var next: int = bytes[index + offset]
			if next < 128 or next > 191:
				return false
			scalar = (scalar << 6) | (next & 63)
		if scalar < minimum or scalar > 1114111 or (scalar >= 55296 and scalar <= 57343):
			return false
		index += count
	return true


func _bounded_json_nesting(bytes: PackedByteArray) -> bool:
	# This is only a resource guard, not a second JSON/schema parser. JSON.parse
	# remains authoritative for syntax (including duplicate/trailing behavior).
	var depth: int = 0
	var quoted: bool = false
	var escaped: bool = false
	for byte: int in bytes:
		if quoted:
			if escaped:
				escaped = false
			elif byte == 92:
				escaped = true
			elif byte == 34:
				quoted = false
		elif byte == 34:
			quoted = true
		elif byte == 123 or byte == 91:
			depth += 1
			if depth > MAX_JSON_NESTING:
				return false
		elif byte == 125 or byte == 93:
			depth -= 1
	return true
