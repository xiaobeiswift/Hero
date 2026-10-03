extends SceneTree
## Independent adversarial transfer audit. No ordinary-player save is accessed.
## A private XDG root plus unique owned fixture is required by the runner.
const Model = preload("res://scripts/game_state.gd")
const Transfer = preload("res://scripts/local_save_transfer.gd")
const Slots = preload("res://scripts/local_save_slots.gd")

class FaultTransfer extends Transfer:
	var fault: String = ""
	var destination: String = ""
	var stage_reads: int = 0
	var renames: int = 0
	func _create_stage_directory() -> Dictionary:
		if fault == "mkdir": return {"ok": false, "error": ERR_CANT_CREATE, "reason": "injected"}
		return super._create_stage_directory()
	func _open_stage(path: String) -> FileAccess:
		if fault == "open": return null
		return super._open_stage(path)
	func _write_stage(file: FileAccess, bytes: PackedByteArray) -> Error:
		if fault == "write":
			file.store_buffer(bytes.slice(0, 11))
			return ERR_FILE_CANT_WRITE
		return super._write_stage(file, bytes)
	func _flush_stage(file: FileAccess) -> Error:
		if fault == "flush": return ERR_FILE_CANT_WRITE
		var error: Error = super._flush_stage(file)
		if fault == "late_backup":
			var backup := FileAccess.open(destination + ".bak", FileAccess.WRITE)
			backup.store_string("late backup, preserve me")
			backup.close()
		return error
	func _read_bytes(path: String) -> Dictionary:
		var result: Dictionary = super._read_bytes(path)
		if path.get_file() == "incoming.json":
			stage_reads += 1
			if fault == "read": return {"ok": false, "error": ERR_FILE_CANT_READ}
			if fault == "readback" and result.ok: result.bytes[0] = 123
		return result
	func _rename_stage(source: String, target: String) -> Error:
		renames += 1
		if fault == "rename": return ERR_FILE_CANT_WRITE
		return super._rename_stage(source, target)

var checks: int = 0
var failures: int = 0
var fixture: String
var good: PackedByteArray

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Independent save transfer review requires isolated XDG_DATA_HOME")
		quit(2); return
	fixture = "user://transfer-independent-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create owned test fixture")
	good = (" \n" + JSON.stringify({"version": Model.SAVE_VERSION, "player": Model.new().to_dict()}, "  ") + "\t\n").to_utf8_buffer()
	test_export_is_read_only()
	test_slot_conflicts()
	test_preview_lifetime()
	test_pinned_target()
	test_faults()
	test_encoding_and_parser_envelope()
	test_frozen_legacy_exports()
	remove_tree(fixture)
	check(not DirAccess.dir_exists_absolute(fixture), "Clean only the test-owned fixture")
	check(not FileAccess.file_exists(Model.SAVE_PATH), "No ordinary-player autosave created")
	for slot: int in range(1, 4): check(not FileAccess.file_exists("user://hero_slot_%d.json" % slot), "No ordinary manual slot created")
	if failures == 0: print("PASS: %d independent save transfer safety checks" % checks)
	else: push_error("FAIL: %d of %d independent transfer checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("Independent transfer: " + label)

func subdir(name: String) -> String:
	var path: String = fixture.path_join(name)
	check(DirAccess.make_dir_recursive_absolute(path) == OK, "Create test subdirectory " + name)
	return path

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Write owned fixture " + path.get_file())
	if file != null: file.store_buffer(bytes); file.flush(); file.close()

func snapshot(path: String) -> Dictionary:
	var result: Dictionary = {}
	var directory := DirAccess.open(path)
	if directory == null: return result
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		result[name] = snapshot(full) if directory.current_is_dir() else FileAccess.get_file_as_bytes(full)
		name = directory.get_next()
	directory.list_dir_end()
	return result

func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		if directory.current_is_dir(): remove_tree(full)
		else: DirAccess.remove_absolute(full)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)

func test_export_is_read_only() -> void:
	var path: String = subdir("exports")
	var slots := Slots.new(path)
	var service := Transfer.new(path)
	for slot: int in range(4):
		write_bytes(slots.path_for(slot), good)
		if slot > 0: write_bytes(slots.path_for(slot) + ".bak", good)
	var before: Dictionary = snapshot(path)
	var live := Model.new(); live.coins = 731; live.battle_active = true; live.enemy_hp = 19
	var state: Dictionary = live.to_dict()
	for slot: int in range(4):
		var result: Dictionary = service.export_slot(slot)
		check(result.ok and result.bytes == good and result.version == Model.SAVE_VERSION, "Export returns original whitespace and exact bytes slot %d" % slot)
		check(result.digest == FileAccess.get_sha256(slots.path_for(slot)), "Export digest describes raw source bytes")
		if slot > 0:
			result = service.export_slot(slot, true)
			check(result.ok and result.bytes == good, "Backup export preserves exact bytes")
	check(snapshot(path) == before and live.to_dict() == state and live.battle_active and live.enemy_hp == 19, "Every export leaves disk and unrelated live/transient state unchanged")
	for bad: Variant in [-1, 4, 1.0, true, false, null, "1", "../../escape", [], {}]:
		check(not service.export_slot(bad).ok and not service.preview_import(good, bad).ok, "Reject nonmanual or coerced slot " + str(bad))
	check(not service.export_slot(0, true).ok and not service.preview_import(good, 0).ok, "Autosave export has no backup and autosave cannot import")
	write_bytes(slots.path_for(1), "{broken".to_utf8_buffer())
	before = snapshot(path)
	check(not service.export_slot(1).ok and snapshot(path) == before, "Invalid export never repairs/deletes/canonicalizes damaged bytes")

func test_slot_conflicts() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		for kind: String in ["file", "directory"]:
			var path: String = subdir("conflict-%s-%s" % [suffix.replace(".", "_"), kind])
			var slots := Slots.new(path)
			var occupied: String = slots.path_for(2) + suffix
			if kind == "file": write_bytes(occupied, "preserve conflict".to_utf8_buffer())
			else: check(DirAccess.make_dir_absolute(occupied) == OK, "Create directory conflict")
			var before: Dictionary = snapshot(path)
			var service := Transfer.new(path)
			check(not service.target_available(2) and not service.preview_import(good, 2).ok, "Any primary/backup/temp path is occupied: " + suffix + " " + kind)
			check(snapshot(path) == before, "Rejected preview preserves every conflicting path")

func test_preview_lifetime() -> void:
	var path: String = subdir("preview")
	var slots := Slots.new(path)
	var service := Transfer.new(path)
	var source: PackedByteArray = good.duplicate()
	var preview: Dictionary = service.preview_import(source, 1)
	check(preview.ok and preview.target_slot == 1, "Preview pins explicit first manual slot")
	source.fill(0)
	check(snapshot(path).is_empty(), "Preview does no I/O and mutable caller bytes cannot write")
	check(service.commit_import(preview.token).ok and FileAccess.get_file_as_bytes(slots.path_for(1)) == good, "Retained copy is independent of changed caller bytes")
	var before: Dictionary = snapshot(path)
	check(service.commit_import(preview.token).get("status", "") == "already_imported" and snapshot(path) == before, "Successful duplicate callback is a read-only exact-byte no-op")
	write_bytes(slots.path_for(1) + ".bak", "later backup".to_utf8_buffer())
	before = snapshot(path)
	check(not service.commit_import(preview.token).ok and snapshot(path) == before, "Duplicate cannot pass after a backup appears")
	preview = service.preview_import(good, 2)
	service.cancel_preview(preview.token)
	check(not service.commit_import(preview.token).ok and snapshot(path) == before, "Cancellation invalidates confirmation and preserves all bytes")
	preview = service.preview_import(good, 2)
	var replacement: Dictionary = service.preview_import(good, 3)
	check(not service.commit_import(preview.token).ok and not FileAccess.file_exists(slots.path_for(2)), "New target selection invalidates old token")
	service.cancel_preview(preview.token)
	check(service.commit_import(replacement.token).ok and FileAccess.get_file_as_bytes(slots.path_for(3)) == good, "Cancel stale token cannot cancel the newer target")
	preview = service.preview_import(good, 2)
	check(not service.preview_import(PackedByteArray(), 2).ok and not service.commit_import(preview.token).ok, "Even invalid new input invalidates prior token")

func test_pinned_target() -> void:
	var first: String = subdir("pinned-first")
	var other: String = subdir("pinned-other")
	var service := Transfer.new(first)
	var preview: Dictionary = service.preview_import(good, 1)
	service._slots = Slots.new(other)
	check(not service.commit_import(preview.token).ok and snapshot(first).is_empty() and snapshot(other).is_empty(), "Changing path resolver after preview cannot redirect import")
	service._slots = Slots.new(first)
	check(not service.commit_import(preview.token).ok, "Restoring path after rejected redirect cannot revive token")
	preview = service.preview_import(good, 1)
	service._directory = other
	check(not service.commit_import(preview.token).ok and snapshot(first).is_empty() and snapshot(other).is_empty(), "Changing staging directory after preview cannot redirect import")

func test_faults() -> void:
	for fault: String in ["mkdir", "open", "write", "flush", "read", "readback", "rename", "late_backup"]:
		var path: String = subdir("fault-" + fault)
		var slots := Slots.new(path)
		write_bytes(slots.path_for(0), good)
		write_bytes(slots.path_for(1), good)
		write_bytes(slots.path_for(1) + ".bak", "preserve even invalid backup".to_utf8_buffer())
		write_bytes(slots.path_for(3) + ".tmp", "other pending operation".to_utf8_buffer())
		var before: Dictionary = snapshot(path)
		var service := FaultTransfer.new(path)
		service.destination = slots.path_for(2)
		service.fault = fault
		var preview: Dictionary = service.preview_import(good, 2)
		check(preview.ok, "Preview before injected " + fault)
		var result: Dictionary = service.commit_import(preview.token)
		check(not result.ok and not FileAccess.file_exists(slots.path_for(2)), "Failure cannot publish a partial primary: " + fault)
		if fault == "late_backup": before["hero_slot_2.json.bak"] = "late backup, preserve me".to_utf8_buffer()
		check(snapshot(path) == before, "Failure leaves all old paths intact and no owned stage: " + fault)
		service.fault = ""
		check(not service.commit_import(preview.token).ok and snapshot(path) == before, "Failed token is single-use and cannot silently retry after " + fault)
		if fault == "late_backup": check(service.renames == 0, "Backup arriving after flush blocks final rename")

func test_encoding_and_parser_envelope() -> void:
	var path: String = subdir("syntax")
	var service := Transfer.new(path)
	var bom: PackedByteArray = PackedByteArray([239, 187, 191]); bom.append_array(good)
	var valid_cases: Array[PackedByteArray] = [good, bom]
	# Explicit version15 below also exercises valid present fitting under a historical header.
	var player: String = JSON.stringify(Model.new().to_dict())
	valid_cases.append(("{\"version\":99,\"version\":15,\"player\":" + player + "}").to_utf8_buffer())
	valid_cases.append(("{\"version\":15,\"player\":" + player + ",}").to_utf8_buffer())
	var exact: PackedByteArray = good.duplicate(); exact.resize(1048576)
	for i: int in range(good.size(), exact.size()): exact[i] = 32
	valid_cases.append(exact)
	for bytes: PackedByteArray in valid_cases:
		var p: Dictionary = service.preview_import(bytes, 1)
		check(p.ok, "BOM/last-wins/trailing-comma/1MiB compatibility is explicit")
		if p.ok: service.cancel_preview(p.token)
	var too_big: PackedByteArray = exact.duplicate(); too_big.append(32)
	var bad_cases: Array[PackedByteArray] = [PackedByteArray(), too_big, "[]".to_utf8_buffer(), good + "false".to_utf8_buffer(), good + PackedByteArray([0]), PackedByteArray([192, 175]), PackedByteArray([237, 160, 128]), PackedByteArray([244, 144, 128, 128]), PackedByteArray([226, 130])]
	bad_cases.append(("{\"version\":15,\"player\":" + player + ",\"deep\":" + "[".repeat(513) + "0" + "]".repeat(513) + "}").to_utf8_buffer())
	bad_cases.append(("{\"version\":15,\"player\":" + player + ",\"version\":99}").to_utf8_buffer())
	for bytes: PackedByteArray in bad_cases:
		check(not service.preview_import(bytes, 1).ok and snapshot(path).is_empty(), "Malformed/oversize/unsupported input stays read-only")
	for version: int in range(1, Model.SAVE_VERSION + 1):
		var data: Dictionary = Model.new().to_dict()
		if version == 13:
			data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_saves/schema_13_default.json")).player
		if version < 16: data.erase("weapon_fitting")
		if version < 15:
			for field: String in Model.Capstone.FIELDS: data.erase(field)
		if version < 14:
			for field: String in Model.Consignee.FIELDS: data.erase(field)
		if version < 13: data.erase("internal_unlocked")
		var bytes: PackedByteArray = JSON.stringify({"version": version, "player": data}).to_utf8_buffer()
		var p: Dictionary = service.preview_import(bytes, 1)
		check(p.ok and p.version == version, "Shared semantic reader accepts supported schema %d" % version)
		if p.ok: service.cancel_preview(p.token)

func test_frozen_legacy_exports() -> void:
	var path: String = subdir("genuine-legacy")
	var slots := Slots.new(path)
	var service := Transfer.new(path)
	for fixture_name: String in ["v017", "v019", "v020", "v025", "v028", "v029"]:
		var frozen_path: String = "res://tests/fixtures/" + fixture_name + "_game_state.gd.txt"
		var old_script := GDScript.new()
		old_script.source_code = FileAccess.get_file_as_string(frozen_path).replace("class_name HeroState\n", "")
		check(old_script.reload() == OK, "Compile exact historical writer " + fixture_name)
		var old = old_script.new()
		old.coins = 137; old.hp = 29
		check(old.save_game(slots.path_for(0)) == OK, "Historical writer produces genuine schema " + str(old.SAVE_VERSION))
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(slots.path_for(0))
		var exported: Dictionary = service.export_slot(0)
		check(exported.ok and exported.bytes == bytes and exported.version == old.SAVE_VERSION, "Genuine legacy export preserves historical schema/format " + fixture_name)
		var p: Dictionary = service.preview_import(bytes, 2)
		check(p.ok and service.commit_import(p.token).ok, "Import genuine historical bytes to empty manual slot")
		check(FileAccess.get_file_as_bytes(slots.path_for(2)) == bytes, "Import never migrates genuine legacy bytes")
		var loaded := Model.new()
		check(loaded.load_game(slots.path_for(2)) == OK and loaded.coins == 137 and loaded.hp == 29 and not loaded.internal_unlocked and loaded.consignee_stage == 0, "Separate explicit load applies normal legacy migration")
		check(FileAccess.get_file_as_bytes(slots.path_for(2)) == bytes, "Separate load does not rewrite historical raw bytes")
		DirAccess.remove_absolute(slots.path_for(2))
