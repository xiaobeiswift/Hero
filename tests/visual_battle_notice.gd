extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app._start_battle("training")
	app._toast("截图已保存 · 本地 screenshots 文件夹");app._battle_action("attack")
	await create_timer(.36).timeout;await capture("146-battle-notice-clear")
	if app.battle_busy:await app.battle_art.presentation_finished
	app.save_warning=true;app.toast_time=0;root.size=Vector2i(1180,737);app.hud.tick(0)
	await create_timer(.2).timeout;await capture("147-battle-save-warning-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: battle notice and persistent warning actual engine captures");quit()
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
