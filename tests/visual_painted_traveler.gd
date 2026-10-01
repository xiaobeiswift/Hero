extends SceneTree
## Actual runtime screenshot/movie capture, prepared progression and disabled saves.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class VisualState extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.gain_xp(200);app.state.quest_stage=6;app.state.choose_sect("听潮阁")
	app._refresh();app.world.teleport(Vector2(435,650));app.world.facing=Vector2.DOWN
	app._toast("绘制旅人 · 四向行走准备场景")
	await create_timer(.4).timeout;await capture("91-painted-hero-front")
	await walk("move_right",.40);await capture("92-painted-hero-side")
	await walk("move_up",.55);await capture("93-painted-hero-back")
	await walk("move_left",.65)
	await walk("move_down",.55)
	await create_timer(.3).timeout
	app.world.teleport(Vector2(484,700));app.world.facing=Vector2.DOWN
	await create_timer(.3).timeout;await capture("94-transparent-canopy")
	await walk("move_left",.5);await create_timer(.4).timeout
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: painted traveller actual-engine walking capture");quit()
func walk(action:String,seconds:float)->void:
	Input.action_press(action);await create_timer(seconds).timeout;Input.action_release(action);await process_frame
func capture(id:String)->void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://screenshots/"+id+".png")!=OK:push_error("Capture failed");quit(1)
