extends SceneTree
## Extract exact license notices from the installed Godot engine.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: godot --headless --script tools/export_licenses.gd -- OUTPUT_DIRECTORY")
		quit(2)
		return
	var destination := args[0]
	DirAccess.make_dir_recursive_absolute(destination)
	var license_file := FileAccess.open(destination.path_join("GODOT-LICENSE.txt"), FileAccess.WRITE)
	var third_party := FileAccess.open(destination.path_join("GODOT-THIRD-PARTY-NOTICES.txt"), FileAccess.WRITE)
	if license_file == null or third_party == null:
		push_error("Could not write engine licenses")
		quit(1)
		return
	license_file.store_string(Engine.get_license_text() + "\n")
	third_party.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n")
	for component in Engine.get_copyright_info():
		third_party.store_string(str(component.name) + "\n")
		for part in component.parts:
			third_party.store_string("Files: " + ", ".join(part.files) + "\n")
			third_party.store_string("Copyright: " + "\n".join(part.copyright) + "\n")
			third_party.store_string("License: " + str(part.license) + "\n\n")
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		third_party.store_string("\n===== " + str(name) + " =====\n\n" + str(licenses[name]) + "\n")
	license_file.close()
	third_party.close()
	print("PASS: engine MIT and third-party notices extracted")
	quit(0)
