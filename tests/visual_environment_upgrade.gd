extends SceneTree
## Actual graphical engine capture with an isolated no-save prepared scenario.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class VisualState extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:_run.call_deferred()
func _run()->void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
	await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.quest_stage=6;app.state.recruit_companion()
	app._refresh();app.world.teleport(Vector2(460,430))
	await _capture("70-painted-village")
	app.world.teleport(Vector2(435,650));await _capture("71-painted-courtyard")
	app.world.teleport(Vector2(920,650));await _capture("72-painted-shrine")
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: actual engine painted environment captures");quit()
func _capture(id:String)->void:
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	var err=root.get_texture().get_image().save_png("res://screenshots/"+id+".png")
	if err!=OK:push_error("Capture failed");quit(1)
