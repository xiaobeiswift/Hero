extends SceneTree
## Real-engine movement with an isolated prepared companion; no player saves.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800)
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.quest_stage=6;app.state.choose_sect("听潮阁");app.state.recruit_companion();app._refresh()
	app.world.teleport(Vector2(435,650));app.world.facing=Vector2.DOWN
	app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.6).timeout;await capture("108-painted-shen-pair")
	await walk("move_right",.40);await capture("109-painted-shen-right")
	await walk("move_up",.55);await capture("110-painted-shen-back")
	await walk("move_left",.65);await capture("111-painted-shen-left")
	await walk("move_down",.55);await capture("112-painted-shen-front")
	await create_timer(.7).timeout
	assert(app.world.companion_name=="沈青" and app.world.companion_active)
	app.queue_free();await create_timer(.25).timeout
	print("PASS: painted Shen real-engine directional follow capture");quit()
func walk(action:String,seconds:float)->void:
	Input.action_press(action);await create_timer(seconds).timeout;Input.action_release(action);await process_frame
func capture(id:String)->void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+id+".png")==OK)
