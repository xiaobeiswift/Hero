extends SceneTree
## Run only with an isolated XDG_DATA_HOME; every fixture is synthetic.
const State = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
var checks: int = 0
var failures: int = 0
var _root: String

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Run with an isolated XDG_DATA_HOME")
		quit(2)
		return
	_root = "user://transfer-core-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(_root) == OK, "Create unique synthetic _root")
	test_shared()
	test_export()
	test_import()
	test_path_conflicts()
	test_envelope()
	test_versions()
	remove_tree(_root)
	check(not DirAccess.dir_exists_absolute(_root), "Clean only owned synthetic fixtures")
	if failures == 0: print("PASS: %d save-transfer core/compatibility checks" % checks)
	else: push_error("FAIL: %d of %d transfer core checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func test_shared() -> void:
	var live := State.new()
	live.player_name = "检验中的旅人"
	live.start_battle()
	var before := state_snapshot(live)
	var inspected := live.inspect_save_bytes(document())
	check(inspected.ok and inspected.state != live and inspected.version == State.SAVE_VERSION, "Shared inspector produces detached candidate")
	inspected.state.coins += 100
	check(state_snapshot(live) == before, "Detached candidate cannot mutate live persistent or combat state")
	for malformed: PackedByteArray in [PackedByteArray(), "null".to_utf8_buffer(), "[]".to_utf8_buffer(), "{".to_utf8_buffer(), document(99)]:
		check(not live.inspect_save_bytes(malformed).ok and state_snapshot(live) == before, "Rejected inspection leaves complete live state unchanged")

func test_export() -> void:
	var directory := folder("exports")
	var slots := Slots.new(directory)
	var transfer := Transfer.new(directory)
	var exact := PackedByteArray([239, 187, 191]) + " \r\n".to_utf8_buffer() + document(11, {"player_name": "旧档😀", "level": 10000}) + "\t\r\n".to_utf8_buffer()
	for slot: int in range(4):
		write(slots.path_for(slot), exact)
		if slot > 0: write(slots.path_for(slot) + ".bak", exact)
	var before := snapshot(directory)
	for slot: int in range(4):
		for backup: bool in ([false] if slot == 0 else [false, true]):
			var result := transfer.export_slot(slot, backup)
			check(result.ok and result.bytes == exact, "Export %d backup=%s preserves exact BOM/legacy bytes" % [slot, backup])
			check(result.version == 11 and result.metadata.level == 99 and result.metadata.player_name == "旧档😀", "Metadata uses legacy normalization without rewriting source")
			check(result.digest == transfer._digest(exact), "Export digest matches exact original bytes")
			result.bytes[0] = 0
		check(snapshot(directory) == before, "Export and returned-byte mutation preserve all files and timestamps")
	check(not transfer.export_slot(0, true).ok, "Autosave backup export is not exposed")
	for invalid: Variant in [-1, 4, 1.0, true, false, "1", "../hero_save", null, [], {}]:
		check(not transfer.export_slot(invalid).ok and not transfer.export_slot(invalid, true).ok, "Invalid export slot never becomes a filename")
	write(slots.path_for(1), document(99))
	check(transfer.export_slot(1).error == ERR_FILE_UNRECOGNIZED, "Export rejects future schema")
	write(slots.path_for(1), "damage".to_utf8_buffer())
	check(not transfer.export_slot(1).ok, "Export rejects corrupt source")
	DirAccess.remove_absolute(slots.path_for(1))
	check(not transfer.export_slot(1).ok, "Export never substitutes backup for missing primary")
	DirAccess.make_dir_absolute(slots.path_for(1))
	check(not transfer.export_slot(1).ok, "Export rejects directory source")
	DirAccess.remove_absolute(slots.path_for(1))
	var valid := document()
	for size: int in [0, Transfer.MAX_IMPORT_BYTES - 1, Transfer.MAX_IMPORT_BYTES, Transfer.MAX_IMPORT_BYTES + 1]:
		var padded := PackedByteArray() if size == 0 else valid + " ".repeat(size - valid.size()).to_utf8_buffer()
		write(slots.path_for(1), padded)
		var snapshot_before := snapshot(directory)
		check(transfer.export_slot(1).ok == (size > 0 and size <= Transfer.MAX_IMPORT_BYTES), "Export checks size boundary before parsing %d" % size)
		check(snapshot(directory) == snapshot_before, "Rejected/boundary export preserves exact file and mtime")

func test_import() -> void:
	var directory := folder("imports")
	var slots := Slots.new(directory)
	var transfer := Transfer.new(directory)
	write(slots.path_for(0), document(State.SAVE_VERSION, {"coins": 777}))
	write(slots.path_for(2), document(State.SAVE_VERSION, {"coins": 888}))
	write(slots.path_for(2) + ".bak", "preserved damaged backup".to_utf8_buffer())
	var old_files := snapshot(directory)
	var live := State.new()
	live.start_battle()
	var live_before := state_snapshot(live)
	var source := " \n".to_utf8_buffer() + document(11, {"hp": 0, "coins": 63}) + "\r\n".to_utf8_buffer()
	var exact := source.duplicate()
	var preview := transfer.preview_import(source, 1)
	check(preview.ok and preview.version == 11 and preview.target_slot == 1 and preview.metadata.hp == 1, "Preview validates detached legacy candidate and fixed chosen target")
	check(snapshot(directory) == old_files, "Preview creates no files")
	preview.metadata.level = 99
	source[0] = 0
	var committed := transfer.commit_import(preview.token)
	check(committed.ok and committed.status == "imported", "Confirmed empty-slot import succeeds")
	check(bytes(slots.path_for(1)) == exact, "Private original bytes survive source and metadata mutations")
	for name: String in old_files:
		check(snapshot(directory)[name] == old_files[name], "Import preserves autosave and other primary/backup bytes and mtime")
	check(not FileAccess.file_exists(slots.path_for(1) + ".bak"), "Import never rotates/creates backup")
	check(state_snapshot(live) == live_before, "Transfer leaves all live progress/combat fields unchanged")
	var after := snapshot(directory)
	for ignored: int in range(3):
		var duplicate := transfer.commit_import(preview.token)
		check(duplicate.ok and duplicate.status == "already_imported" and snapshot(directory) == after, "Repeated confirmation is verified read-only no-op")
	check(not transfer.preview_import(exact, 1).ok and snapshot(directory) == after, "New preview rejects identical occupied primary")
	var cancelled := transfer.preview_import(exact, 3)
	check(cancelled.ok, "Another empty target can preview")
	transfer.cancel_preview(cancelled.token)
	check(not transfer.commit_import(cancelled.token).ok and snapshot(directory) == after, "Cancellation invalidates token without changing files")
	for invalid: Variant in [0, -1, 4, 1.0, true, false, "1", "../../../hero_save", null, [], {}]:
		check(not transfer.target_available(invalid) and not transfer.preview_import(exact, invalid).ok, "Only typed manual slot IDs 1–3 may receive imports")
	check(not Transfer.new(directory.path_join("missing-parent")).preview_import(exact, 1).ok, "Missing target parent fails closed")

func test_path_conflicts() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		var directory := folder("symlink" + suffix.replace(".", "_"))
		var slots := Slots.new(directory)
		var transfer := Transfer.new(directory)
		var handle := DirAccess.open(directory)
		var name := slots.path_for(1).get_file() + suffix
		check(handle.create_link("missing-original", name) == OK, "Create isolated dangling symlink")
		check(handle.is_link(name), "Verify dangling symlink fixture")
		check(not transfer.target_available(1) and not transfer.preview_import(document(), 1).ok, "Dangling symlink is occupied even without readable destination")
		check(handle.is_link(name) and handle.read_link(name) == "missing-original", "Rejected preview preserves exact original symlink")
		handle.remove(name)
	var directory := folder("changed-primary")
	var slots := Slots.new(directory)
	var transfer := Transfer.new(directory)
	var preview := transfer.preview_import(document(), 1)
	check(transfer.commit_import(preview.token).ok, "Prepare committed receipt")
	write(slots.path_for(1), document(State.SAVE_VERSION, {"coins": 999}))
	var before := snapshot(directory)
	check(not transfer.commit_import(preview.token).ok and snapshot(directory) == before, "Committed receipt cannot claim success or overwrite changed primary")
	DirAccess.remove_absolute(slots.path_for(1))
	check(not transfer.commit_import(preview.token).ok and not FileAccess.file_exists(slots.path_for(1)), "Committed receipt cannot restore a deleted primary")

func test_envelope() -> void:
	var directory := folder("envelope")
	var transfer := Transfer.new(directory)
	var valid := document()
	for size: int in [Transfer.MAX_IMPORT_BYTES - 1, Transfer.MAX_IMPORT_BYTES, Transfer.MAX_IMPORT_BYTES + 1]:
		var padded := valid + " ".repeat(size - valid.size()).to_utf8_buffer()
		var result := transfer.preview_import(padded, 1)
		check(result.ok == (size <= Transfer.MAX_IMPORT_BYTES), "Inclusive 1MiB byte boundary %d" % size)
		if result.ok: transfer.cancel_preview(result.token)
	var exact_limit := valid + " ".repeat(Transfer.MAX_IMPORT_BYTES - valid.size()).to_utf8_buffer()
	var limit_preview := transfer.preview_import(exact_limit, 1)
	check(limit_preview.ok and transfer.commit_import(limit_preview.token).ok, "Exactly 1MiB commits successfully")
	check(bytes(Slots.new(directory).path_for(1)) == exact_limit, "Exactly 1MiB import remains byte-identical")
	DirAccess.remove_absolute(Slots.new(directory).path_for(1))
	for malformed: PackedByteArray in [PackedByteArray(), " ".to_utf8_buffer(), "null".to_utf8_buffer(), "[]".to_utf8_buffer(), "{}".to_utf8_buffer(), "{".to_utf8_buffer(), valid + " false".to_utf8_buffer(), valid + valid]:
		check(not transfer.preview_import(malformed, 1).ok, "Empty/malformed/trailing second data rejected")
	for version: Variant in [0, 1.5, 17, 99, "16", true, null]:
		check(not transfer.preview_import(document(version), 1).ok, "Invalid/future version rejected: " + str(version))
	for patch: Dictionary in [{"hp": 0}, {"hp": 101}, {"qi": 7}, {"resources": {}}, {"resources": {"wood": -1}}, {"internal_unlocked": true}, {"qin_unlocked": true}, {"map_id": "../escape"}, {"level": 100}, {"player_name": "  noncanonical  "}]:
		check(not transfer.preview_import(document(State.SAVE_VERSION, patch), 1).ok, "Current semantic/canonical/progression violation rejected: " + str(patch))
	for bad: PackedByteArray in [PackedByteArray([255]), PackedByteArray([192, 175]), PackedByteArray([224, 128, 175]), PackedByteArray([237, 160, 128]), PackedByteArray([244, 144, 128, 128]), PackedByteArray([240, 159]), PackedByteArray([128]), PackedByteArray([0])]:
		var doc := '{"version":14,"note":"'.to_utf8_buffer() + bad + '","player":'.to_utf8_buffer() + JSON.stringify(State.new().to_dict()).to_utf8_buffer() + '}'.to_utf8_buffer()
		check(not transfer.preview_import(doc, 1).ok, "Malformed UTF-8 and raw NUL rejected before decoder substitution")
	var bom := PackedByteArray([239, 187, 191]) + valid
	check(transfer.preview_import(bom, 1).ok, "Leading UTF-8 BOM follows existing file reader semantics")
	for version: int in [13, State.SAVE_VERSION]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_saves/schema_13_default.json")).player if version == 13 else State.new().to_dict()
		var player := JSON.stringify(data)
		var duplicate := ('{"version":99,"version":%d,"player":%s}' % [version, player]).to_utf8_buffer()
		check(transfer.preview_import(duplicate, 1).ok, "Schema%d duplicate keys retain Godot last-key-wins semantics" % version)
		check(not transfer.preview_import(('{"version":%d,"version":99,"player":%s}' % [version, player]).to_utf8_buffer(), 1).ok, "Effective duplicate value still undergoes complete semantic validation")
		check(transfer.preview_import(('{"version":%d,"player":%s,}' % [version, player]).to_utf8_buffer(), 1).ok, "Schema%d Godot trailing-comma compatibility is explicit" % version)
		for depth: int in [Transfer.MAX_JSON_NESTING - 1, Transfer.MAX_JSON_NESTING]:
			var nested := ('{"version":%d,"extra":%s0%s,"player":%s}' % [version, "[".repeat(depth), "]".repeat(depth), player]).to_utf8_buffer()
			check(transfer.preview_import(nested, 1).ok == (depth < Transfer.MAX_JSON_NESTING), "Complete nesting is bounded at512 before parser")
		var quoted := ('{"version":%d,"note":"%s\\\"%s","player":%s}' % [version, "[".repeat(1000), "]".repeat(1000), player]).to_utf8_buffer()
		check(transfer.preview_import(quoted, 1).ok, "Nesting guard ignores quoted and escaped brackets")
	check(snapshot(directory).is_empty(), "Envelope previews leave disk unchanged")

func test_versions() -> void:
	for version: int in range(1, State.SAVE_VERSION + 1):
		var directory := folder("legacy-%d" % version)
		var slots := Slots.new(directory)
		var transfer := Transfer.new(directory)
		var data := State.new().to_dict()
		if version == 13:
			data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_saves/schema_13_default.json")).player
		if version < 16: data.erase("weapon_fitting")
		if version < 15:
			for field: String in State.Capstone.FIELDS: data.erase(field)
		if version < 14:
			for field: String in State.Consignee.FIELDS: data.erase(field)
		if version < 13: data.erase("internal_unlocked")
		if version < 12:
			data.level = 10000
			data.hp = 0
		var exact := (" \n" + JSON.stringify({"version": version, "player": data}, "  ") + "\r\n").to_utf8_buffer()
		var preview := transfer.preview_import(exact, 1)
		check(preview.ok and preview.version == version, "Schema %d preview preserves original staged semantics" % version)
		if not preview.ok: continue
		check(transfer.commit_import(preview.token).ok and bytes(slots.path_for(1)) == exact, "Schema %d import preserves old bytes without migration" % version)
		var loaded := State.new()
		check(loaded.load_game(slots.path_for(1)) == OK, "Imported schema %d remains readable" % version)
		check(transfer.export_slot(1).bytes == exact, "Schema %d re-export preserves exact byte identity" % version)
		if version < 12: check(loaded.level == 99 and loaded.hp == 1, "Legacy normalization occurs only when reading")
		if version < 13: check(not loaded.internal_unlocked, "Legacy import cannot invent learned internal skill")
		if version < 14: check(loaded.consignee_stage == 0 and loaded.consignee_observations.is_empty(), "Legacy import cannot invent consignee progress")
	var frozen := GDScript.new()
	frozen.source_code = FileAccess.get_file_as_string("res://tests/fixtures/v022_game_state.gd.txt").replace("class_name HeroState\n", "")
	check(frozen.reload() == OK, "Genuine frozen schema12 reader still compiles")
	var old = frozen.new()
	var before: Dictionary = old.to_dict()
	for version: int in [13, 14, 15, 16]:
		var current := Slots.new(_root.path_join("legacy-%d" % version)).path_for(1)
		check(old.load_game(current) == ERR_FILE_UNRECOGNIZED and old.to_dict() == before, "Frozen old reader rejects schema%d without mutation" % version)

func document(version: Variant = State.SAVE_VERSION, patch: Dictionary = {}) -> PackedByteArray:
	var data := State.new().to_dict()
	# Synthetic old-layout stress cases; genuine historical13 has its own fixture.
	if version is int and version < 16: data.erase("weapon_fitting")
	if version is int and version < 15:
		for field: String in State.Capstone.FIELDS: data.erase(field)
	if version is int and version < 14:
		for field: String in State.Consignee.FIELDS: data.erase(field)
	if version is int and version < 13: data.erase("internal_unlocked")
	for key: String in patch: data[key] = patch[key]
	return JSON.stringify({"version": version, "player": data}, "\t").to_utf8_buffer()

func folder(name: String) -> String:
	var path := _root.path_join(name)
	check(DirAccess.make_dir_absolute(path) == OK, "Create synthetic fixture folder")
	return path

func write(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Write synthetic fixture")
	if file != null:
		file.store_buffer(data)
		file.close()

func bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return PackedByteArray()
	var result := file.get_buffer(file.get_length())
	file.close()
	return result

func snapshot(path: String) -> Dictionary:
	var result: Dictionary = {}
	var directory := DirAccess.open(path)
	directory.include_hidden = true
	for name: String in directory.get_files():
		var child := path.path_join(name)
		result[name] = {"bytes": bytes(child), "modified": FileAccess.get_modified_time(child)}
	for name: String in directory.get_directories():
		result[name] = {"directory": snapshot(path.path_join(name))}
	return result

func state_snapshot(state: State) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in state.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[property.name] = state.get(property.name)
	return result.duplicate(true)

func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	directory.include_hidden = true
	for name: String in directory.get_directories(): remove_tree(path.path_join(name))
	for name: String in directory.get_files(): directory.remove(name)
	DirAccess.remove_absolute(path)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
