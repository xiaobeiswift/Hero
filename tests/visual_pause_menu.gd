extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	var fail=false
	func save_game(_path:String=SAVE_PATH)->Error:return ERR_CANT_CREATE if fail else OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(435,650));app._refresh()
	app._show_pause();await capture("137-journey-rest")
	app.modal_actions[4].call();await capture("138-rest-exit-confirm")
	app.state.fail=true;app.modal_actions[0].call();await capture("139-rest-save-failed")
	app.modal_actions[2].call();await capture("140-rest-discard-confirm")
	app.modal_actions[0].call();root.size=Vector2i(1180,737);await capture("141-journey-rest-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual rest-menu and write-failure UI captures");quit()
func capture(name:String)->void:
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
