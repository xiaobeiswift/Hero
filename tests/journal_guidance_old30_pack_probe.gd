extends SceneTree
## Three separate processes: current producer, exact retained Web30 PCK reader/
## writer, current verifier. Prepared API-earned fixture/model+IO scope only.
## No current dependencies are injected into the old pack. Not UI/browser proof.
const PACK_SHA: String = "375f03e9fd93c7a799fd0486be2905ec310221b89885bf96d4694902d751d1f6"
const PACK_BYTES: int = 59285968
const BUNDLE_SHA: String = "aa950207fd293f8b90630677b34753c177d4d50ff281f8aea804d6470f176bed"
const FITTINGS: Array[String] = ["plain", "edge", "guard"]
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh_file(path: String) -> bool:
	return not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path + ".tmp") and not DirAccess.dir_exists_absolute(path + ".tmp")

func disk(folder: String) -> Dictionary:
	var result: Dictionary = {}
	var directory = DirAccess.open(folder)
	if directory == null: return result
	for file: String in directory.get_files(): result[file] = FileAccess.get_sha256(folder.path_join(file))
	return result

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("XDG_DATA_HOME").is_empty() or args.size() != 3 or args[0] not in ["produce", "old", "verify"] or not args[1].is_absolute_path() or not args[2].is_absolute_path():
		push_error("Use isolated XDG and: produce|old|verify EXACT_WEB30_PCK FRESH_SHARED_OUTPUT_DIRECTORY")
		quit(2); return
	var mode: String = args[0]
	var pack: String = args[1]
	var output: String = args[2]
	var handle = FileAccess.open(pack, FileAccess.READ)
	check(handle != null and handle.get_length() == PACK_BYTES and FileAccess.get_sha256(pack) == PACK_SHA, "Exact retained cloud Web30 PCK pin")
	if handle != null: handle.close()
	check(FileAccess.file_exists("res://project.binary") == (mode == "old"), "Only middle process uses the complete historical pack")
	if failures: quit(1); return
	var script = load("res://scripts/game_state.gd")
	var state = script.new()
	var version: String = String(ProjectSettings.get_setting("application/config/version", ""))
	check(version == ("0.0.30" if mode == "old" else "0.0.34"), "Loaded project version matches the requested runtime")
	var source_sha: String = FileAccess.get_sha256("res://scripts/game_state.gd") if FileAccess.file_exists("res://scripts/game_state.gd") else ""
	if source_sha.is_empty(): source_sha = "compiled source text unavailable; bound by exact complete PCK"
	print("JOURNAL_GUIDANCE_COMPAT_RESOURCE mode=%s version=%s script=%s source=%s" % [mode, version, script.resource_path, source_sha])
	check(state.SAVE_VERSION == 16, "Both versions use unchanged writer16")
	if mode == "produce":
		check(not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output), "Refuse reuse of any prior output")
		if failures: quit(1); return
		check(DirAccess.make_dir_recursive_absolute(output) == OK, "Create isolated output")
		var bundle_path: String = "res://tests/journal_guidance_baseline_inputs.json"
		check(FileAccess.get_sha256(bundle_path) == BUNDLE_SHA, "Immutable exact API-earned/PCK-accepted baseline bundle")
		if failures: quit(1); return
		var bundle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bundle_path))
		var raw: PackedByteArray = PackedByteArray()
		for fixture: Dictionary in bundle.fixtures:
			if fixture.label == "preaccept_open_records_release_water": raw = String(fixture.input_utf8).to_utf8_buffer()
		var inspected: Dictionary = state.inspect_save_bytes(raw)
		check(inspected.get("ok", false), "Production reader accepts exact earned fixture")
		if failures: quit(1); return
		state = inspected.state
		var original: Dictionary = JSON.parse_string(raw.get_string_from_utf8())
		check(state._same_save_value(state.to_dict(), original.player), "Producer reader preserves every exact earned input field")
		var session = load("res://scripts/journal_guidance_session.gd").new()
		session.reset(state)
		var before: Dictionary = state.to_dict().duplicate(true)
		check(session.track(state, "tang_notes", session.token(state)), "Explicit transient selection exists while saving")
		check(state.to_dict() == before, "Tracking leaves every canonical field unchanged")
		for fitting: String in FITTINGS:
			var equipped: Dictionary = state.set_weapon_fitting(fitting)
			check(equipped.get("ok", false) and state.weapon_fitting == fitting, "Use existing fitting model for " + fitting)
			var path: String = output.path_join("new31-" + fitting + ".json")
			check(fresh_file(path) and state.save_game(path) == OK, "Current serializer writes unused " + fitting)
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			check(document.version == 16 and state._same_save_value(document.player, state.to_dict()) and session.tracked_arc_id == "tang_notes", "Unchanged16 payload while selection remains transient: " + fitting)
			for field: String in document.player: check(not field.begins_with("journal") and not field.begins_with("tracked_"), "No journal save field: " + field)
	elif mode == "old":
		for fitting: String in FITTINGS:
			var subject: String = output.path_join("new31-" + fitting + ".json")
			var returned: String = output.path_join("old30-" + fitting + ".json")
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(subject))
			check(document.get("version") == 16 and document.get("player", {}).get("weapon_fitting") == fitting, "Actual current16 subject retains " + fitting)
			var before: Dictionary = disk(output)
			check(state.load_game(subject) == OK, "Actual old30 PCK accepts current31 schema16: " + fitting)
			check(state._same_save_value(state.to_dict(), document.player) and disk(output) == before, "Old load preserves all fields and all input bytes: " + fitting)
			check(fresh_file(returned) and state.save_game(returned) == OK, "Actual old30 serializer writes separate roundtrip: " + fitting)
			check(FileAccess.get_file_as_bytes(returned) == FileAccess.get_file_as_bytes(subject), "Unchanged serializer emits byte-identical16: " + fitting)
	else:
		for fitting: String in FITTINGS:
			var subject: String = output.path_join("new31-" + fitting + ".json")
			var returned: String = output.path_join("old30-" + fitting + ".json")
			var before: Dictionary = disk(output)
			var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(subject))
			check(state.load_game(returned) == OK, "Current31 accepts genuine old30 roundtrip: " + fitting)
			check(state._same_save_value(state.to_dict(), expected.player), "Current31 retains all earned/fitting/resources/roster/position fields: " + fitting)
			check(disk(output) == before, "Current read changes no roundtrip bytes: " + fitting)
	check(FileAccess.get_sha256(pack) == PACK_SHA, "Historical full pack unchanged")
	print("JOURNAL_GUIDANCE_OLD30_%s checks=%d failures=%d; actual retained Web30/current31 schema16 model+IO boundary, prepared earned input, no UI/browser claim" % [mode.to_upper(), checks, failures])
	quit(0 if failures == 0 else 1)
