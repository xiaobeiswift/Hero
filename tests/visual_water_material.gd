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
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(1020,643));app.toast_time=0;app.hud.quest_notice_time=0
	await capture("148-painted-water-pond")
	app.world.painted_water_enabled=false;await capture("149-water-fallback-comparison")
	app.world.painted_water_enabled=true;app.world.teleport(Vector2(1390,782));await capture("150-painted-water-ferry")
	app.world.teleport(Vector2(854,453));await capture("151-painted-water-pier")
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual painted pond/channel and fishing pier captures");quit()
func capture(name:String)->void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
