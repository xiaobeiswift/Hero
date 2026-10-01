extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoWritePrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app._change_view_zoom(1);app._change_view_zoom(1)
	app.world.teleport(Vector2(1230,350));await capture("173-painted-reedbank-bamboo")
	app.world.painted_bamboo_enabled=false;await capture("174-bamboo-procedural-comparison")
	app.world.painted_bamboo_enabled=true;app.world.teleport(Vector2(1390,560));await capture("175-painted-path-bamboo")
	app.world.teleport(Vector2(1315,785));await capture("176-painted-ferry-bamboo")
	app.queue_free();await create_timer(.25).timeout;print("PASS: painted bamboo actual engine captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
