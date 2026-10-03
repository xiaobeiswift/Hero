extends SceneTree
## Synthetic defaults only. Frozen14/15 SOURCE uses current dependencies; the
## complete old15 PCK process is independently tested by its separate probe.
const State = preload("res://scripts/game_state.gd")
const OLD_PATH = "res://tests/fixtures/v029_game_state.gd.txt"
const OLD_SHA = "6a23204d1558b9f2e15ef4150f2c818fb200415fddad00fc35e1e3d99761a159"
const OLD_BYTES = 81624

static func old_reader() -> GDScript:
	var raw := FileAccess.get_file_as_bytes(OLD_PATH)
	if raw.size() != OLD_BYTES or FileAccess.get_sha256(OLD_PATH) != OLD_SHA: return null
	var script := GDScript.new()
	script.source_code = raw.get_string_from_utf8().replace("class_name HeroState\n", "")
	if script.reload() != OK: return null
	return script

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["14", "15", "16"] or not args[1].is_absolute_path():
		push_error("Pass 14, 15 or 16 and an absolute unused isolated output path."); quit(2); return
	var path: String = args[1]
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path + ".tmp") or DirAccess.dir_exists_absolute(path + ".tmp"):
		push_error("Fixture or staging path exists; refusing overwrite."); quit(2); return
	var script = old_reader() if args[0] == "15" else State
	if args[0] == "14":
		var source_path := "res://tests/fixtures/v028_game_state.gd.txt"
		if FileAccess.get_sha256(source_path) != "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5": quit(1); return
		script = GDScript.new(); script.source_code = FileAccess.get_file_as_string(source_path).replace("class_name HeroState\n", "")
		if script.reload() != OK: quit(1); return
	if script == null: quit(1); return
	var producer = script.new()
	if producer.SAVE_VERSION != int(args[0]) or producer.save_game(path) != OK:
		push_error("Requested true-version producer did not write."); quit(1); return
	print("WEAPON_FITTING_FIXTURE version=%s sha256=%s path=%s; frozen14/15 source/current dependencies or current16 serializer, no header relabeling" % [args[0], FileAccess.get_sha256(path), path])
	quit(0)
