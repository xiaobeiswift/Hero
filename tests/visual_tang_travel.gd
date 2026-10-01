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
	app._new_game();app._stop_audio();app.audio_on=false;app.state.quest_stage=6;app.state.side_stage=3;app.state.chapter_two_stage=4;app.state.bridge_repaired=true;app.state.tangqi_stage=3;app.state.tangqi_choice="preserve";app.state.tangqi_unlocked=true;app.state.select_companion("唐栖");app._sync_world_state();app._refresh()
	app._change_view_zoom(1);app._change_view_zoom(1);app.world.teleport(Vector2(610,440));app.world.set_process(false)
	app.world.companion_pos=Vector2(658,470);app.world.companion_facing=Vector2.DOWN;app.world.companion_moving=false;app.world.queue_redraw();await capture("193-tang-painted-party-front")
	app.world.companion_facing=Vector2.RIGHT;app.world.companion_moving=true;app.world.companion_walk_time=0;app.world.queue_redraw();await capture("194-tang-painted-party-stride")
	app.world.companion_facing=Vector2.UP;app.world.companion_walk_time=PI;app.world.queue_redraw();await capture("195-tang-painted-party-back")
	app.state.active_companion="";app.state.tangqi_unlocked=false;app.state.map_id="frostbridge";app._sync_world_state();app.world.change_map("frostbridge",Vector2(700,805));app._refresh();app.world.queue_redraw();await capture("196-tang-painted-workstation")
	app.queue_free();await create_timer(.25).timeout;print("PASS: four actual Tang exploration and workstation captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
