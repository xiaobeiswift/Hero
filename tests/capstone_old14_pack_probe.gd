extends SceneTree
## Optional portable old14-reader proof. Start a SEPARATE process with the
## caller-supplied external old Web28 --main-pack; no current source preloads.
## Supply absolute pack and true15 subject paths. Never look up a repo binary.
## Run capstone_independent_fixture_producer.gd in the current process first.
const SHA = "c8e652c0c716ef1c78ae80b1a70a08db97b9395e0ab8be1407e954ed52d46bad"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].is_absolute_path() or not args[1].is_absolute_path(): quit(2); return
	var pack: String = args[0]; var subject: String = args[1]
	check(FileAccess.get_sha256(pack) == SHA, "Exact retained old cloud-exported Web28 pack identity")
	var old_script = load("res://scripts/game_state.gd")
	var old = old_script.new()
	check(old.SAVE_VERSION == 14 and not old.to_dict().has("capstone_stage"), "Actual old14 reader loaded in separate old-pack process")
	old.coins = 913; old.skill_cooldown = 3; old.party_battle_epoch = 53
	var data: Dictionary = old.to_dict(); var bytes := FileAccess.get_file_as_bytes(subject)
	check(JSON.parse_string(bytes.get_string_from_utf8()).version == 15, "Subject is supplied true15 pinned-producer document")
	check(old.load_game(subject) == ERR_FILE_UNRECOGNIZED, "Old packed reader rejects15 before restoration")
	check(old.to_dict() == data and old.skill_cooldown == 3 and old.party_battle_epoch == 53 and old.party_session == null, "Packed rejection preserves persistent/transient state")
	check(FileAccess.get_file_as_bytes(subject) == bytes, "Rejected current subject bytes unchanged")
	var control := "user://old14-control.json"
	check(old.save_game(control) == OK, "True14 packed producer writes own control")
	var controlbytes := FileAccess.get_file_as_bytes(control)
	old.coins = 77; old.skill_cooldown = 9
	check(old.load_game(control) == OK and old.to_dict() == data and FileAccess.get_file_as_bytes(control) == controlbytes, "True14 control accepted and bytes preserved")
	check(FileAccess.get_sha256(pack) == SHA, "Read-only old PCK hash unchanged")
	print("INDEPENDENT_OLD_PCK_RESULT checks=%d failures=%d; old cloud pack model boundary, no browser/live deployment claim" % [checks, failures])
	quit(0 if failures == 0 else 1)
