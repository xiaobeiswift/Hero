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
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(460,430))
	await capture("156-view-standard")
	app._change_view_zoom(1);await capture("157-view-near")
	app._change_view_zoom(1);await capture("158-view-detail")
	app._show_pause();await capture("159-view-rest-control")
	app._close_modal();app.world.teleport(Vector2(70,160));root.size=Vector2i(1180,737);await capture("160-view-edge-compass")
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual three-scale view, fixed HUD, menu and map-edge captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
