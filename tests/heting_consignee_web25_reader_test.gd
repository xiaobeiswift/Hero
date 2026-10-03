extends SceneTree
## Optional exact old-PCK model test, run separately from current source tests.
## Mounts the exact cloud-exported Web25 candidate from the same published
## source locally. It is not the Windows-deployed artifact; no browser/export/upload.
## Do not preload current HeroState: the reader must come from the old pack.
const EXPECTED_PCK_SHA = "1c5d2f6b8f59b1314b179cea2e238c76682b44dbabba15401b03e80d5a738acb"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _hash(path: String) -> String:
	return FileAccess.get_sha256(path)
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var args := OS.get_cmdline_user_args()
	var pck: String = args[0] if args.size() > 0 else "res://builds/Hero-Web-0.0.25-web1/site/index.pck"
	pck = ProjectSettings.globalize_path(pck)
	check(FileAccess.file_exists(pck) and _hash(pck) == EXPECTED_PCK_SHA, "Pinned exact cloud-exported Web25 PCK identity; not live artifact bytes")
	if failures > 0: quit(1); return
	# Preserve the historical13-versus14 reader boundary using exact frozen14
	# producer source. Packed reader code is version-pinned below; this legacy
	# test does not claim an isolated dependency closure. The new14-versus15
	# complete-old-runtime probe runs in a separate process.
	var current_path := "res://scripts/game_state.gd"
	var producer_source := FileAccess.get_file_as_string("res://tests/fixtures/v028_game_state.gd.txt")
	check(FileAccess.get_sha256("res://tests/fixtures/v028_game_state.gd.txt") == "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5", "Exact frozen14 producer source")
	var producer := GDScript.new(); producer.source_code = producer_source.replace("class_name HeroState\n", "")
	check(producer.reload() == OK, "Compile frozen14 producer with class-name adaptation only")
	var current = producer.new()
	var path := "user://web25-reject14-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(current.SAVE_VERSION == 14 and current.save_game(path) == OK, "Actual frozen14 producer writes14")
	var absolute_path := ProjectSettings.globalize_path(path)
	var bytes := FileAccess.get_file_as_bytes(absolute_path)
	current = null
	check(ProjectSettings.load_resource_pack(pck, true), "Mount exact old pack without exporting it")
	var old_script = ResourceLoader.load(current_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	check(old_script != null, "Load reader script from pinned old pack")
	if old_script == null: quit(1); return
	var old = old_script.new()
	check(old.SAVE_VERSION == 13 and not old.to_dict().has("consignee_stage"), "Reader is actual old schema13, not cached current source")
	old.coins = 913; old.skill_cooldown = 3
	var before: Dictionary = old.to_dict()
	check(old.load_game(absolute_path) == ERR_FILE_UNRECOGNIZED, "Actual old packed reader rejects14")
	check(old.to_dict() == before and old.skill_cooldown == 3, "Packed reader leaves persistent/transient old state untouched")
	check(FileAccess.get_file_as_bytes(absolute_path) == bytes, "Rejected14 file bytes unchanged")
	check(_hash(pck) == EXPECTED_PCK_SHA, "Read-only old PCK remains byte exact")
	DirAccess.remove_absolute(absolute_path)
	if failures == 0: print("PASS: %d exact cloud-exported Web25 PCK schema14 rejection checks; not live artifact/browser persistence evidence" % checks)
	quit(0 if failures == 0 else 1)
