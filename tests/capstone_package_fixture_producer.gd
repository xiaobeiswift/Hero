extends SceneTree
## Only freezes authentic Web28 producer bytes and Godot-imported pixel pins.
## Current dependencies are used; this is not full-old-runtime acceptance.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_absolute_path() or FileAccess.file_exists(args[0]): quit(2); return
	var path: String = "res://tests/fixtures/v028_game_state.gd.txt"
	if FileAccess.get_sha256(path) != "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5": quit(2); return
	var script := GDScript.new(); script.source_code=FileAccess.get_file_as_string(path).replace("class_name HeroState\n","")
	if script.reload()!=OK: quit(2); return
	var old = script.new()
	if old.SAVE_VERSION!=14 or old.to_dict().has("capstone_stage") or old.save_game(args[0])!=OK: quit(2); return
	print("GENUINE14 ",FileAccess.get_sha256(args[0]))
	for name: String in ["painted_liang_combat_v4", "painted_liang_portrait_v1"]:
		var texture: Texture2D = load("res://assets/generated/characters/"+name+".png")
		var image: Image = texture.get_image(); image.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data())
		print("IMPORTED_RGBA ",name," ",hash.finish().hex_encode())
	quit(0)
