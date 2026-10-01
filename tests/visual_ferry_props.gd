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
	app._new_game();app._stop_audio();app.audio_on=false;app.toast_time=0;app.hud.quest_notice_time=0
	app.world.teleport(Vector2(854,453));await capture("152-painted-fishing-deck")
	app.world.teleport(Vector2(1500,780));await capture("153-painted-ferry-deck-skiff")
	app.world.painted_props_enabled=false;await capture("154-ferry-props-fallback")
	app.world.painted_props_enabled=true;app.world.teleport(Vector2(1260,812));root.size=Vector2i(1180,737);await capture("155-painted-ferry-compact")
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual wood deck/skiff and fallback captures");quit()
func capture(name:String)->void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
