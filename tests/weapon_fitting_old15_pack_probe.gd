extends SceneTree
## Separate process: --main-pack EXACT_OLD_PCK --script THIS_ABSOLUTE_SCRIPT
## -- EXACT_OLD_PCK ACTUAL16_SUBJECT UNUSED_ABSOLUTE15_CONTROL_OUTPUT
## No current source preload or dependency substitution. Synthetic model/IO
## boundary only, never a browser, live deployment or graphical claim.
const PCK_SHA = "bdd6c5f2e202a4072e5d3f41024d0ea97e384f0435caedbd7afebebdef74b3c1"
const PCK_BYTES = 59251392
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _all(s) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in s.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = s.get(property.name)
			result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func _disk(paths: Array[String]) -> Dictionary:
	var result := {}
	for path: String in paths: result[path] = FileAccess.get_file_as_bytes(path)
	return result

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open isolated subject copy")
	if file != null: file.store_buffer(bytes); file.close()

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 3: quit(2); return
	for arg: String in args:
		if not arg.is_absolute_path(): quit(2); return
	var pack: String = args[0]; var subject: String = args[1]; var control: String = args[2]
	if FileAccess.file_exists(control) or DirAccess.dir_exists_absolute(control): quit(2); return
	var handle := FileAccess.open(pack, FileAccess.READ)
	check(handle != null and handle.get_length() == PCK_BYTES and FileAccess.get_sha256(pack) == PCK_SHA, "Complete actual old15 PCK pin")
	if handle != null: handle.close()
	if failures: quit(1); return
	var old_script = load("res://scripts/game_state.gd")
	print("WEAPON_FITTING_OLD15_RESOURCE_PATH path=%s; read-only exported-script remapping observation, not a new-package acceptance claim" % old_script.resource_path)
	var old = old_script.new()
	check(old.SAVE_VERSION == 15 and old.to_dict().has("capstone_stage") and not old.to_dict().has("weapon_fitting"), "Actual packed15 reader and dependency closure")
	check(old.save_game(control) == OK, "Actual old15 PCK produces a genuine default positive control")
	var default: Dictionary = old.to_dict(); var controlbytes := FileAccess.get_file_as_bytes(control)
	old.coins = 777
	check(old.load_game(control) == OK and old.to_dict() == default and FileAccess.get_file_as_bytes(control) == controlbytes, "Actual15 reader accepts genuine15 and preserves its bytes")
	var bytes := FileAccess.get_file_as_bytes(subject)
	var document: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	check(document.version == 16 and document.player.weapon_fitting == "plain", "Actual16 default subject requires plain fitting, never relabeled15")
	var folder := "user://weapon-fitting-packed15"
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Isolated packed15 fixture folder")
	var slots = load("res://scripts/local_save_slots.gd").new(folder)
	old.coins = 913; old.skill_cooldown = 3; old.enemy_hp = 17; old.enemy_name = "sentinel"
	old.enemy_intent = "unchanged"; old.battle_log.assign(["read-only rejection"])
	old.party_battle_epoch = 53; old.receipt_battle_epoch = 29
	old.party_settlement = {"sentinel": [1, 2]}; old.receipt_settlement = {"sentinel": 3}
	check(old.save_game(slots.path_for(0)) == OK and slots.save_slot(old, 1) == OK, "Prepare old primary and manual control")
	old.coins += 1
	check(slots.save_slot(old, 1) == OK, "Prepare genuine old manual backup")
	var paths: Array[String] = [subject, control, slots.path_for(0), slots.path_for(1), slots.path_for(1) + ".bak"]
	var before := _all(old); var disk := _disk(paths)
	check(old.load_game(subject) == ERR_FILE_UNRECOGNIZED, "Actual packed15 rejects16 before restoration")
	check(old._same_save_value(_all(old), before) and _disk(paths) == disk, "Every live script variable and primary/manual/backup/subject/control byte preserved")
	for target: int in [0, 1, 2]:
		var path: String = slots.path_for(0) if target == 0 else (slots.path_for(1) if target == 1 else slots.path_for(1) + ".bak")
		_write(path, bytes)
		disk = _disk(paths); before = _all(old)
		var status: int = slots.load_backup(old, 1) if target == 2 else slots.load_slot(old, target)
		check(status == ERR_FILE_UNRECOGNIZED, "Old15 slot route rejects16:%d" % target)
		check(old._same_save_value(_all(old), before) and _disk(paths) == disk, "Old15 rejection leaves all live and disk state:%d" % target)
	check(FileAccess.get_sha256(pack) == PCK_SHA, "Complete actual15 PCK remains byte-exact")
	print("WEAPON_FITTING_OLD15_PCK_RESULT checks=%d failures=%d control_sha256=%s; complete old runtime model/IO boundary only" % [checks, failures, FileAccess.get_sha256(control)])
	quit(0 if failures == 0 else 1)
