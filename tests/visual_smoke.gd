extends SceneTree
## Scripted graphical capture. Run without --headless. Does not write normal saves.
const Scene = preload("res://scenes/main.tscn")
const Model = preload("res://scripts/game_state.gd")
var app
class VisualState extends Model:
	func save_game(_path: String=SAVE_PATH) -> Error:
		return OK
	func has_save() -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = Scene.instantiate()
	app.state = VisualState.new()
	root.add_child(app)
	await create_timer(0.7).timeout
	app.music.stop()
	app.audio_on = false
	await _capture("01-title")
	app._new_game()
	await create_timer(0.2).timeout
	await _capture("02-village")
	app._interact("elder")
	await _capture("03-dialogue")
	app._close_modal()
	app.state.recruit_companion()
	app.state.heal_rest()
	app._start_battle("story")
	await _capture("04-battle")
	app._battle_action("attack")
	await create_timer(0.1).timeout
	await _capture("05-battle-feedback")
	app._battle_action("flee")
	app.state.quest_stage=6
	app.state.choose_sect("听潮阁")
	app._travel("sluice",Vector2(600,500))
	await create_timer(0.3).timeout
	await _capture("06-sluice")
	app._show_inventory()
	await _capture("07-inventory")
	app._close_modal()
	app._show_martials()
	await _capture("08-martial-arts")
	app._close_modal()
	app._show_map()
	await _capture("09-region-map")
	app._close_modal()
	app.music.stop()
	app.sfx.stop()
	app.music.stream=null
	app.sfx.stream=null
	await create_timer(0.3).timeout
	app.queue_free()
	await process_frame
	print("PASS: 9 rendered visual captures saved to res://screenshots")
	quit()

func _capture(id: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var error=image.save_png("res://screenshots/"+id+".png")
	if error!=OK:
		push_error("Cannot save visual capture: "+str(error))
		quit(1)
