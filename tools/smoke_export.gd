extends SceneTree
## External PCK test driver: never bundled in the release PCK. Requires isolated XDG paths.
## The editor loads the exported PCK; release-template binaries do not support --script.
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Export smoke: " + message)

func _run() -> void:
	_check(FileAccess.file_exists("res://project.binary"), "Must load the exported binary project")
	_check(not DirAccess.dir_exists_absolute("res://tests"), "Test scripts excluded")
	_check(not DirAccess.dir_exists_absolute("res://tools"), "Build tools excluded")
	_check(not DirAccess.dir_exists_absolute("res://screenshots"), "Screenshots excluded")
	_check(not DirAccess.dir_exists_absolute("res://builds"), "Build outputs excluded")
	_check(FileAccess.file_exists("res://assets/fonts/LICENSE.txt"), "Font license retained")
	_check(FileAccess.file_exists("res://licenses/GODOT-LICENSE.txt"), "Engine license retained")
	_check(FileAccess.file_exists("res://licenses/GODOT-THIRD-PARTY-NOTICES.txt"), "Engine third-party notices retained")
	_check(ResourceLoader.exists("res://assets/fonts/NotoSansSC.otf"), "Chinese font retained")
	_check(ResourceLoader.exists("res://assets/generated/qingwei_ferry_title.png"), "Title artwork retained")
	_check(ResourceLoader.exists("res://assets/river_theme.wav"), "Music retained")
	var scene = load("res://scenes/main.tscn")
	_check(scene != null, "Packed main scene loads")
	if scene == null:
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.has_method("_new_game"), "Packed gameplay script loads")
	_check(game.current_screen == "title", "Release opens at title")
	game._new_game()
	_check(game.current_screen == "explore" and not game.active_modal, "New game enters exploration")
	game._interact("elder")
	_check(game.active_modal, "Dialogue opens")
	game._close_modal()
	game._show_inventory()
	_check(game.active_modal, "Inventory opens")
	game._close_modal()
	game._show_martials()
	_check(game.active_modal, "Martial arts panel opens")
	game._close_modal()
	game._show_map()
	_check(game.active_modal, "Map opens")
	game._close_modal()
	game._start_battle("story")
	_check(game.state.battle_active and game.current_screen == "battle", "Battle opens")
	game._battle_action("attack")
	_check(game.state.battle_active, "Battle turn resolves")
	game._battle_action("flee")
	_check(not game.state.battle_active and game.current_screen == "explore", "Retreat returns to exploration")
	game.state.quest_stage = 6
	game.state.choose_sect("听潮阁")
	game._travel("sluice", Vector2(190, 520))
	_check(game.state.map_id == "sluice", "Second region loads")
	_check(game.state.save_game() == OK, "Release writes isolated local save")
	_check(game.state.load_game() == OK, "Release reads isolated local save")
	game.music.stop()
	game.sfx.stop()
	game.music.stream = null
	game.sfx.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	print("%s: %d exported-pack checks; %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
