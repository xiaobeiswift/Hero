extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoWritePrefs extends Prefs:
	var fail=false
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return ERR_CANT_CREATE if fail else OK
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.state.quest_stage=1;app._sync_world_state();app._refresh();app.view_preferences.zoom_index=2;app._apply_view_zoom();app.world.teleport(Vector2(610,440));app.world.set_process(false);app.world.time_passed=2.0
	await capture("201-clear-near-view")
	app._toggle_view_detail();await capture("202-light-near-view")
	app._toggle_view_detail();app._show_pause();await capture("203-clear-light-settings")
	root.size=Vector2i(1180,737);app.view_preferences.fail=true;app.overlay.find_child("PauseQuality",true,false).pressed.emit();await capture("204-display-setting-warning")
	app.queue_free();await create_timer(.25).timeout;print("PASS: clear/light near-view and visible preference-warning captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;app.world.queue_redraw();await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
