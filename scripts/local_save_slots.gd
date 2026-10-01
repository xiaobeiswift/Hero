class_name LocalSaveSlots
extends RefCounted
## Independent local manual saves. Slot 0 is the existing, read-only autosave.
## No operation loads through or writes to a different slot as a side effect.

const State = preload("res://scripts/game_state.gd")
const COPY_CHUNK_BYTES: int = 65536

var _directory: String


func _init(directory: String = "user://") -> void:
	_directory = directory


func path_for(slot: Variant) -> String:
	# Check the type before formatting: floats, booleans, and path-like strings
	# must never become a file name through GDScript's numeric coercion.
	if not _valid_slot(slot, true):
		return ""
	return _directory.path_join("hero_save.json" if slot == 0 else "hero_slot_%d.json" % slot)


func save_slot(state: State, slot: Variant) -> Error:
	if state == null or not _valid_slot(slot, false):
		return ERR_INVALID_PARAMETER
	if state.battle_active:
		return ERR_BUSY
	var path: String = path_for(slot)
	var backup: String = path + ".bak"
	if FileAccess.file_exists(path):
		var previous := State.new()
		var previous_error: Error = previous.load_game(path)
		if previous_error == OK and _matches_current_save(state, path):
			return OK
		# A valid primary always becomes the recovery copy. If the primary is
		# damaged or from a newer version, leave every existing backup alone.
		# With no backup, preserve even the unreadable original for recovery.
		if previous_error == OK or not _exists(backup):
			var backup_error: Error = _copy_atomic(path, backup)
			if backup_error != OK:
				return backup_error
	# HeroState owns the validated schema and its existing atomic save path.
	return state.save_game(path)


func load_slot(state: State, slot: Variant) -> Error:
	if state == null or not _valid_slot(slot, true):
		return ERR_INVALID_PARAMETER
	if state.battle_active:
		return ERR_BUSY
	# HeroState validates the entire document before changing the active model.
	# Loading deliberately does not rewrite, upgrade, repair, or back up files.
	return state.load_game(path_for(slot))


func load_backup(state: State, slot: Variant) -> Error:
	if state == null or not _valid_slot(slot, false):
		return ERR_INVALID_PARAMETER
	if state.battle_active:
		return ERR_BUSY
	return state.load_game(path_for(slot) + ".bak")


func describe(slot: Variant) -> Dictionary:
	return _describe_path(path_for(slot))


func describe_backup(slot: Variant) -> Dictionary:
	if not _valid_slot(slot, false):
		return _describe_path("")
	return _describe_path(path_for(slot) + ".bak")


func has_manual_saves() -> bool:
	for slot: int in range(1, 4):
		var path: String = path_for(slot)
		if _exists(path) or _exists(path + ".bak"):
			return true
	return false


func _valid_slot(slot: Variant, allow_autosave: bool) -> bool:
	return slot is int and slot >= (0 if allow_autosave else 1) and slot <= 3


func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func _describe_path(path: String) -> Dictionary:
	# Unknown/missing data never exposes a guessed level or location. modified
	# is the file's Unix timestamp, location is the model's validated map_id.
	var result: Dictionary = {
		"exists": false, "status": "empty", "level": 0,
		"location": "", "modified": 0,
	}
	if path.is_empty() or not _exists(path):
		return result
	result["exists"] = true
	result["modified"] = FileAccess.get_modified_time(path)
	var preview := State.new()
	var error: Error = preview.load_game(path)
	if error == OK:
		result["status"] = "valid"
		result["level"] = preview.level
		result["location"] = preview.map_id
	elif error == ERR_FILE_UNRECOGNIZED:
		result["status"] = "incompatible"
	else:
		result["status"] = "corrupt"
	return result


func _matches_current_save(state: State, path: String) -> bool:
	# Match HeroState's current-schema output exactly. Duplicate activation must
	# not rotate the only meaningful previous save into an identical backup.
	# Byte matching still allows an explicit save to migrate legacy schemas or
	# normalize hand-edited/noncanonical files through HeroState.save_game.
	var expected: PackedByteArray = JSON.stringify({
		"version": State.SAVE_VERSION, "player": state.to_dict(),
	}, "\t").to_utf8_buffer()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() != expected.size():
		file.close()
		return false
	var actual: PackedByteArray = file.get_buffer(expected.size())
	file.close()
	return actual == expected


func _copy_atomic(source_path: String, destination_path: String) -> Error:
	# Copy bytes, not a parsed/re-serialized model: preserve old schema fields,
	# formatting, and original damaged data. Stream to bound memory use even
	# when the source exceeds HeroState's one-MiB parsing limit.
	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var temporary: String = destination_path + ".tmp"
	var destination: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if destination == null:
		var open_error: Error = FileAccess.get_open_error()
		source.close()
		return open_error
	var remaining: int = source.get_length()
	var copy_error: Error = OK
	while remaining > 0:
		var count: int = mini(remaining, COPY_CHUNK_BYTES)
		var bytes: PackedByteArray = source.get_buffer(count)
		if bytes.size() != count:
			copy_error = ERR_FILE_CANT_READ
			break
		destination.store_buffer(bytes)
		copy_error = destination.get_error()
		if copy_error != OK:
			break
		remaining -= count
	source.close()
	if copy_error == OK:
		destination.flush()
		copy_error = destination.get_error()
	destination.close()
	if copy_error == OK:
		copy_error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(destination_path)
		)
	if copy_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return copy_error
