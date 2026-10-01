extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app._toast("青苇渡人物画面 · 准备场景")
	for pair in [[Vector2(460,430),"95-painted-village-cast"],[Vector2(600,750),"96-painted-mentor"],[Vector2(1210,735),"97-painted-ferry-sparrer"],[Vector2(275,365),"98-painted-pharmacist"]]:
		app.world.teleport(pair[0]);await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png("res://screenshots/"+pair[1]+".png")!=OK:push_error("Capture failed");quit(1);return
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: 4 actual-engine painted village cast captures");quit()
