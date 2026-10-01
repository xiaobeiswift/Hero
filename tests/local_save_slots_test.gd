extends SceneTree
## Run with an isolated XDG_DATA_HOME; every fixture also uses a unique folder.
## No test reads or writes the player's normal autosave or manual-slot paths.

const State = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
var checks: int = 0
var failures: int = 0
var _root: String


func _init() -> void:
	_root = "user://local-save-slot-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(_root) == OK, "Create isolated fixture root")
	_test_paths_and_invalid_ids()
	_test_roundtrip_backup_and_isolation()
	_test_duplicate_save()
	_test_read_only_autosave_and_metadata()
	_test_battle_blocking()
	_test_rejected_loads()
	_test_backup_preservation()
	_test_backup_failures()
	_test_write_failures()
	_test_old_save_compatibility()
	_remove_tree(_root)
	_check(not DirAccess.dir_exists_absolute(_root), "Remove only the isolated test fixture folder")
	if failures == 0:
		print("PASS: %d local save-slot checks" % checks)
	else:
		push_error("FAIL: %d of %d local save-slot checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_paths_and_invalid_ids() -> void:
	var defaults := Slots.new()
	# Path construction only: never open anything in the player's real folder.
	_check(defaults.path_for(0) == State.SAVE_PATH, "Default slot 0 keeps the original autosave path")
	for slot: int in range(1, 4):
		_check(defaults.path_for(slot) == "user://hero_slot_%d.json" % slot, "Fixed default manual path %d" % slot)
	var store = _store("paths")
	var state := State.new()
	var empty: Dictionary = {"exists": false, "status": "empty", "level": 0, "location": "", "modified": 0}
	for slot: int in range(4):
		_check(store.describe(slot) == empty, "Missing slot %d metadata" % slot)
		_check(store.load_slot(state, slot) == ERR_FILE_NOT_FOUND, "Missing slot %d load" % slot)
		_check(store.describe_backup(slot) == empty, "Missing backup %d metadata" % slot)
		if slot > 0:
			_check(store.load_backup(state, slot) == ERR_FILE_NOT_FOUND, "Missing backup %d load" % slot)
	_check(not store.has_manual_saves(), "Empty store has no manual saves")
	for invalid: Variant in [-1, 4, 9000, "1", "../hero_save", "1/../../hero_save", 1.0, true, false, null, [], {}]:
		_check(store.path_for(invalid).is_empty(), "Invalid ID has no path: " + str(invalid))
		_check(store.save_slot(state, invalid) == ERR_INVALID_PARAMETER, "Invalid write ID rejected: " + str(invalid))
		_check(store.load_slot(state, invalid) == ERR_INVALID_PARAMETER, "Invalid load ID rejected: " + str(invalid))
		_check(store.load_backup(state, invalid) == ERR_INVALID_PARAMETER, "Invalid backup ID rejected: " + str(invalid))
		_check(store.describe(invalid) == empty and store.describe_backup(invalid) == empty, "Invalid ID metadata is empty: " + str(invalid))
	_check(store.save_slot(state, 0) == ERR_INVALID_PARAMETER, "Autosave write is forbidden")
	_check(store.load_backup(state, 0) == ERR_INVALID_PARAMETER, "Autosave backup is not part of this API")
	_check(store.save_slot(null, 1) == ERR_INVALID_PARAMETER, "Null save model rejected")
	_check(store.load_slot(null, 1) == ERR_INVALID_PARAMETER, "Null load model rejected")
	_check(store.load_backup(null, 1) == ERR_INVALID_PARAMETER, "Null backup model rejected")
	_check(_folder_snapshot(store.path_for(0).get_base_dir()).is_empty(), "Invalid calls create no files")


func _test_roundtrip_backup_and_isolation() -> void:
	var store = _store("roundtrip")
	var state := State.new()
	state.player_name = "青苇旧客"
	state.level = 3
	state.coins = 88
	state.position = Vector2(125.5, 273.25)
	_check(store.save_slot(state, 1) == OK, "First manual save succeeds")
	_check(store.has_manual_saves(), "Primary marks the store as populated")
	_check(not FileAccess.file_exists(store.path_for(1) + ".bak"), "First save creates no unnecessary backup")
	_check(not FileAccess.file_exists(store.path_for(0)), "Manual save does not create an autosave")
	var original: Dictionary = state.to_dict()
	# Noncanonical formatting and non-ASCII text must survive byte-for-byte.
	var original_bytes: PackedByteArray = (" \r\n\t" + JSON.stringify({"version": State.SAVE_VERSION, "player": original}, "  ") + "\r\n").to_utf8_buffer()
	_write_bytes(store.path_for(1), original_bytes)
	state.player_name = "新旅客"
	state.coins = 233
	state.level = 5
	_check(store.save_slot(state, 1) == OK, "Overwrite succeeds after preserving the old save")
	_check(_bytes(store.path_for(1) + ".bak") == original_bytes, "Backup preserves exact prior bytes")
	var current_bytes: PackedByteArray = _bytes(store.path_for(1))
	var loaded := State.new()
	_check(store.load_slot(loaded, 1) == OK and loaded.to_dict() == state.to_dict(), "Current manual save round-trips")
	var files_before: Dictionary = _folder_snapshot(store.path_for(1).get_base_dir())
	_check(store.load_backup(loaded, 1) == OK and loaded.to_dict() == original, "Backup restores the old model")
	_check(_folder_snapshot(store.path_for(1).get_base_dir()) == files_before, "Restoring backup never replaces primary or rewrites files")
	for slot: int in range(2, 4):
		state.coins = slot * 100
		_check(store.save_slot(state, slot) == OK, "Save independent slot %d" % slot)
		_check(store.load_slot(loaded, slot) == OK and loaded.coins == slot * 100, "Load independent slot %d" % slot)
	_check(_bytes(store.path_for(1)) == current_bytes and _bytes(store.path_for(1) + ".bak") == original_bytes, "Other slot saves preserve slot 1 and its backup")
	files_before = _folder_snapshot(store.path_for(1).get_base_dir())
	state.reset_game()
	_check(_folder_snapshot(store.path_for(1).get_base_dir()) == files_before and store.has_manual_saves(), "Starting a new model does not erase manual saves")
	_check(not FileAccess.file_exists(store.path_for(1) + ".tmp") and not FileAccess.file_exists(store.path_for(1) + ".bak.tmp"), "Successful writes leave no temporary files")
	DirAccess.remove_absolute(store.path_for(1))
	DirAccess.remove_absolute(store.path_for(2))
	DirAccess.remove_absolute(store.path_for(3))
	_check(store.has_manual_saves(), "A backup-only store still counts as having manual progress")
	_check(store.describe(1).status == "empty" and store.describe_backup(1).status == "valid", "Backup-only metadata is independent")
	_check(store.load_backup(loaded, 1) == OK and loaded.to_dict() == original, "Backup-only recovery succeeds")


func _test_duplicate_save() -> void:
	var store = _store("duplicate")
	var state := State.new()
	_check(store.save_slot(state, 1) == OK, "Create initial duplicate-save fixture")
	var first_files: Dictionary = _folder_snapshot(store.path_for(1).get_base_dir())
	_check(store.save_slot(state, 1) == OK and _folder_snapshot(store.path_for(1).get_base_dir()) == first_files, "Identical first save is a read-only no-op and creates no backup")
	state.coins += 50
	_check(store.save_slot(state, 1) == OK, "Changed state creates meaningful previous backup")
	var before: Dictionary = _folder_snapshot(store.path_for(1).get_base_dir())
	for ignored: int in range(3):
		_check(store.save_slot(state, 1) == OK and _folder_snapshot(store.path_for(1).get_base_dir()) == before, "Repeated activation preserves meaningful backup and timestamps")
	var restored := State.new()
	_check(store.load_backup(restored, 1) == OK and restored.coins == 24, "Duplicate save never replaces the original recovery point")
	state.coins += 50
	var preceding: PackedByteArray = _bytes(store.path_for(1))
	_check(store.save_slot(state, 1) == OK and _bytes(store.path_for(1) + ".bak") == preceding, "A later genuinely changed state still rotates the backup")


func _test_read_only_autosave_and_metadata() -> void:
	var store = _store("metadata")
	var state := State.new()
	state.level = 7
	state.map_id = "frostbridge"
	state.coins = 37
	_check(state.save_game(store.path_for(0)) == OK, "Create a fixture autosave through the existing model")
	_check(not store.has_manual_saves(), "An autosave alone is not a manual save")
	_check(store.save_slot(state, 1) == OK, "Create metadata fixture")
	state.level = 8
	_check(store.save_slot(state, 1) == OK, "Create metadata backup fixture")
	var data: Dictionary = state.to_dict()
	data.level = 10000
	data.map_id = "unknown-map"
	_write_document(store.path_for(2), State.SAVE_VERSION, data)
	var before: Dictionary = _folder_snapshot(store.path_for(0).get_base_dir())
	var active_before: Dictionary = _state_snapshot(state)
	for ignored: int in range(3):
		var metadata: Dictionary = store.describe(1)
		_check(metadata.exists and metadata.status == "valid" and metadata.level == 8 and metadata.location == "frostbridge", "Manual metadata validates in a disposable model")
		_check(metadata.modified == FileAccess.get_modified_time(store.path_for(1)) and metadata.modified > 0, "Metadata includes source modification timestamp")
		var backup: Dictionary = store.describe_backup(1)
		_check(backup.status == "valid" and backup.level == 7 and backup.location == "frostbridge", "Backup metadata describes backup progress")
		_check(store.describe(2).level == 99 and store.describe(2).location == "qingwei", "Metadata reflects model validation and normalization")
		_check(store.describe(0).status == "valid" and store.describe(0).level == 7, "Autosave can be described")
	_check(_state_snapshot(state) == active_before, "Metadata never mutates the active model")
	var loaded := State.new()
	_check(store.load_slot(loaded, 0) == OK and loaded.level == 7 and loaded.coins == 37, "Autosave remains loadable through slot 0")
	_check(store.load_slot(loaded, 1) == OK and store.load_backup(loaded, 1) == OK, "Read manual primary and backup")
	_check(store.save_slot(state, 0) == ERR_INVALID_PARAMETER, "Existing autosave cannot be overwritten by slot API")
	_check(_folder_snapshot(store.path_for(0).get_base_dir()) == before, "All metadata/load calls preserve every file's bytes and timestamp")
	_check(not FileAccess.file_exists(store.path_for(0) + ".bak"), "Reading autosave creates no backup")


func _test_battle_blocking() -> void:
	var store = _store("battle")
	var state := State.new()
	_check(store.save_slot(state, 1) == OK, "Prepare battle primary fixture")
	state.coins += 1
	_check(store.save_slot(state, 1) == OK, "Prepare battle backup fixture")
	_check(state.save_game(store.path_for(0)) == OK, "Prepare battle autosave fixture")
	state.start_battle()
	var before: Dictionary = _state_snapshot(state)
	var files_before: Dictionary = _folder_snapshot(store.path_for(0).get_base_dir())
	for slot: int in range(1, 4):
		_check(store.save_slot(state, slot) == ERR_BUSY, "Battle blocks saving slot %d" % slot)
		_check(store.load_backup(state, slot) == ERR_BUSY, "Battle blocks backup load %d" % slot)
	for slot: int in range(4):
		_check(store.load_slot(state, slot) == ERR_BUSY, "Battle blocks primary load %d" % slot)
	_check(_state_snapshot(state) == before, "Blocked operations preserve all progress and combat")
	_check(_folder_snapshot(store.path_for(0).get_base_dir()) == files_before, "Blocked operations preserve disk files")


func _test_rejected_loads() -> void:
	var store = _store("rejected")
	var state := State.new()
	state.coins = 999
	state.player_name = "保留进度"
	state.skill_cooldown = 4
	var before: Dictionary = _state_snapshot(state)
	var variants: Array[Dictionary] = [
		{"content": "{broken", "status": "corrupt", "error": ERR_FILE_CORRUPT},
		{"content": JSON.stringify({"version": State.SAVE_VERSION, "player": {}}), "status": "corrupt", "error": ERR_FILE_CORRUPT},
		{"content": JSON.stringify({"version": State.SAVE_VERSION + 1, "player": state.to_dict()}), "status": "incompatible", "error": ERR_FILE_UNRECOGNIZED},
		{"content": " ".repeat(1048577), "status": "corrupt", "error": ERR_FILE_CORRUPT},
	]
	for fixture: Dictionary in variants:
		for slot: int in range(4):
			_write_bytes(store.path_for(slot), fixture.content.to_utf8_buffer())
			_check(store.load_slot(state, slot) == fixture.error and _state_snapshot(state) == before, "Rejected primary preserves active state: %s slot %d" % [fixture.status, slot])
			var metadata: Dictionary = store.describe(slot)
			_check(metadata.exists and metadata.status == fixture.status and metadata.level == 0 and metadata.location.is_empty(), "Rejected primary metadata: %s slot %d" % [fixture.status, slot])
		for slot: int in range(1, 4):
			_write_bytes(store.path_for(slot) + ".bak", fixture.content.to_utf8_buffer())
			_check(store.load_backup(state, slot) == fixture.error and _state_snapshot(state) == before, "Rejected backup preserves active state: %s slot %d" % [fixture.status, slot])
			_check(store.describe_backup(slot).status == fixture.status, "Rejected backup metadata: %s slot %d" % [fixture.status, slot])
	var files_before: Dictionary = _folder_snapshot(store.path_for(0).get_base_dir())
	store.describe(1)
	store.describe_backup(1)
	store.load_slot(state, 1)
	store.load_backup(state, 1)
	_check(_folder_snapshot(store.path_for(0).get_base_dir()) == files_before, "Rejected reads never repair or rewrite damaged files")
	_check(store.has_manual_saves(), "Damaged manual files still count as existing progress")


func _test_backup_preservation() -> void:
	var state := State.new()
	state.coins = 18
	for kind: String in ["corrupt", "future", "oversized"]:
		var store = _store("preserve_" + kind)
		_check(store.save_slot(state, 1) == OK, "Create primary for " + kind)
		state.coins += 1
		_check(store.save_slot(state, 1) == OK, "Create a good recovery copy for " + kind)
		var good_backup: PackedByteArray = _bytes(store.path_for(1) + ".bak")
		var bad_bytes: PackedByteArray = "{truncated".to_utf8_buffer()
		if kind == "future":
			bad_bytes = JSON.stringify({"version": 99, "player": state.to_dict()}).to_utf8_buffer()
		elif kind == "oversized":
			bad_bytes = "x".repeat(1048577).to_utf8_buffer()
		_write_bytes(store.path_for(1), bad_bytes)
		state.coins += 1
		_check(store.save_slot(state, 1) == OK, "Replace a damaged primary while retaining recovery: " + kind)
		_check(_bytes(store.path_for(1) + ".bak") == good_backup, "Never overwrite a good backup with " + kind)
		var restored := State.new()
		_check(store.load_backup(restored, 1) == OK, "Protected backup remains loadable: " + kind)
		_write_bytes(store.path_for(2), bad_bytes)
		_check(store.save_slot(state, 2) == OK and _bytes(store.path_for(2) + ".bak") == bad_bytes, "Without a backup, preserve original damaged bytes: " + kind)
		_write_bytes(store.path_for(3), bad_bytes)
		var existing_backup: PackedByteArray = "unreadable but potentially recoverable older backup".to_utf8_buffer()
		_write_bytes(store.path_for(3) + ".bak", existing_backup)
		_check(store.save_slot(state, 3) == OK and _bytes(store.path_for(3) + ".bak") == existing_backup, "Damaged primary also leaves any existing backup untouched: " + kind)


func _test_backup_failures() -> void:
	var state := State.new()
	for blocked: String in ["temporary", "destination"]:
		var store = _store("backup_failure_" + blocked)
		_check(store.save_slot(state, 1) == OK, "Create backup-failure primary")
		var original: PackedByteArray = _bytes(store.path_for(1))
		var obstruction: String = store.path_for(1) + (".bak.tmp" if blocked == "temporary" else ".bak")
		_check(DirAccess.make_dir_absolute(obstruction) == OK, "Create deterministic backup obstruction " + blocked)
		_write_bytes(obstruction.path_join("keep.txt"), "fixture sentinel".to_utf8_buffer())
		state.coins += 1
		_check(store.save_slot(state, 1) != OK, "Backup failure prevents save: " + blocked)
		_check(_bytes(store.path_for(1)) == original, "Backup failure preserves primary bytes: " + blocked)
		_check(_bytes(obstruction.path_join("keep.txt")) == "fixture sentinel".to_utf8_buffer(), "Backup failure preserves obstruction: " + blocked)
		_check(not FileAccess.file_exists(store.path_for(1) + ".tmp"), "Backup failure never starts primary write: " + blocked)
		if blocked == "destination":
			_check(not FileAccess.file_exists(store.path_for(1) + ".bak.tmp"), "Failed backup rename cleans only its temporary file")
	# Failure to stage a newer backup must leave an already-good backup intact.
	var store = _store("backup_failure_existing")
	_check(store.save_slot(state, 1) == OK, "Prepare existing primary failure fixture")
	state.coins += 1
	_check(store.save_slot(state, 1) == OK, "Prepare existing good backup failure fixture")
	var primary: PackedByteArray = _bytes(store.path_for(1))
	var backup: PackedByteArray = _bytes(store.path_for(1) + ".bak")
	_check(DirAccess.make_dir_absolute(store.path_for(1) + ".bak.tmp") == OK, "Block backup temporary path")
	state.coins += 1
	_check(store.save_slot(state, 1) != OK, "Existing good backup does not excuse a failed required backup")
	_check(_bytes(store.path_for(1)) == primary and _bytes(store.path_for(1) + ".bak") == backup, "Failed backup staging keeps both good files exact")


func _test_write_failures() -> void:
	var state := State.new()
	var store = _store("write_failure_existing")
	_check(store.save_slot(state, 1) == OK, "Create existing primary for failed write")
	var original: PackedByteArray = _bytes(store.path_for(1))
	_check(DirAccess.make_dir_absolute(store.path_for(1) + ".tmp") == OK, "Block primary temporary path deterministically")
	_write_bytes((store.path_for(1) + ".tmp").path_join("keep.txt"), "do not remove".to_utf8_buffer())
	state.coins = 222
	_check(store.save_slot(state, 1) != OK, "Primary write failure returns error")
	_check(_bytes(store.path_for(1)) == original and _bytes(store.path_for(1) + ".bak") == original, "Failed primary write leaves current primary and recovery copy intact")
	_check(_bytes((store.path_for(1) + ".tmp").path_join("keep.txt")) == "do not remove".to_utf8_buffer(), "Failed primary write leaves blocked directory intact")
	var first_store = _store("write_failure_first")
	_check(DirAccess.make_dir_absolute(first_store.path_for(1) + ".tmp") == OK, "Block first-save temporary path")
	_check(first_store.save_slot(state, 1) != OK and not FileAccess.file_exists(first_store.path_for(1)), "Failed first save leaves no primary")
	var rename_store = _store("write_failure_rename")
	_check(DirAccess.make_dir_absolute(rename_store.path_for(1)) == OK, "Block primary rename destination")
	_write_bytes(rename_store.path_for(1).path_join("keep.txt"), "keep".to_utf8_buffer())
	_check(rename_store.save_slot(state, 1) != OK, "Primary rename failure returns error")
	_check(not FileAccess.file_exists(rename_store.path_for(1) + ".tmp"), "Failed primary rename removes temporary file")
	_check(_bytes(rename_store.path_for(1).path_join("keep.txt")) == "keep".to_utf8_buffer(), "Primary rename failure leaves obstruction intact")
	var missing_store := Slots.new(_root.path_join("missing_parent/child"))
	_check(missing_store.save_slot(state, 1) != OK, "Missing parent directory returns an error without creating paths")


func _test_old_save_compatibility() -> void:
	var store = _store("old_versions")
	var old: Dictionary = {
		"player_name": "旧存档", "level": 2, "xp": 10, "coins": 56,
		"hp": 80, "max_hp": 112, "qi": 2, "max_qi": 6,
		"attack": 19, "defense": 5, "medicine": 3, "herbs": 0,
		"quest_stage": 0, "sect": "未入门", "ending": "",
		"position": {"x": 333, "y": 444}, "victories": 1,
	}
	var state := State.new()
	_write_document(store.path_for(1), 1, old)
	var exact_old: PackedByteArray = _bytes(store.path_for(1))
	_check(store.describe(1).status == "valid" and store.describe(1).location == "qingwei", "True version-1 minimal save metadata")
	_check(store.load_slot(state, 1) == OK and state.coins == 56 and state.position == Vector2(333, 444), "Original minimal version-1 save loads")
	_check(state.learned_arts.is_empty() and state.mist_stage == 0, "Old saves use feature compatibility defaults")
	_check(_bytes(store.path_for(1)) == exact_old, "Loading an old save does not upgrade its file")
	_check(store.save_slot(state, 1) == OK and _bytes(store.path_for(1) + ".bak") == exact_old, "Overwriting an old save preserves its original schema bytes")
	_check(store.load_backup(state, 1) == OK, "Old-schema backup restores normally")
	for version: int in range(1, State.SAVE_VERSION + 1):
		_write_document(store.path_for(2), version, state.to_dict())
		_check(store.load_slot(state, 2) == OK and store.describe(2).status == "valid", "Supported schema %d remains loadable through slots" % version)


func _store(name: String):
	var directory: String = _root.path_join(name)
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create fixture " + name)
	return Slots.new(directory)


func _write_document(path: String, version: int, data: Dictionary) -> void:
	_write_bytes(path, JSON.stringify({"version": version, "player": data}).to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Open test fixture: " + path.get_file())
	if file == null:
		return
	file.store_buffer(bytes)
	file.flush()
	_check(file.get_error() == OK, "Write test fixture: " + path.get_file())
	file.close()


func _bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	_check(file != null, "Read test fixture: " + path.get_file())
	if file == null:
		return PackedByteArray()
	var result: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return result


func _folder_snapshot(directory: String) -> Dictionary:
	var result: Dictionary = {}
	for filename: String in DirAccess.get_files_at(directory):
		var path: String = directory.path_join(filename)
		result[filename] = {"bytes": _bytes(path), "modified": FileAccess.get_modified_time(path)}
	return result


func _state_snapshot(state: State) -> Dictionary:
	return {
		"progress": state.to_dict(), "battle_active": state.battle_active,
		"enemy_name": state.enemy_name, "enemy_hp": state.enemy_hp,
		"enemy_max_hp": state.enemy_max_hp, "turn": state.turn,
		"battle_log": state.battle_log.duplicate(), "skill_cooldown": state.skill_cooldown,
		"enemy_intent": state.enemy_intent, "guard": state.guard,
	}


func _remove_tree(directory: String) -> void:
	# Only called on our freshly created, unique root or its descendants.
	for child: String in DirAccess.get_directories_at(directory):
		_remove_tree(directory.path_join(child))
	for filename: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
