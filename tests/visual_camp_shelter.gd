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
	app.world.teleport(Vector2(1315,785));await capture("169-painted-camp-shelter")
	app.world.painted_camp_enabled=false;await capture("170-camp-shelter-fallback")
	app.world.painted_camp_enabled=true;app.world.teleport(Vector2(1339,720));await capture("171-shelter-party-visibility")
	app.state.quest_stage=3;app.state.recruit_companion();app._sync_world_state();app._refresh();app.world.teleport(Vector2(1339,755));await capture("172-camp-companion-depth")
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual campsite material/depth captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
