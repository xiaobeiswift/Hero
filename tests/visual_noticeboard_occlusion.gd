extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
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
	app.world.teleport(Vector2(720.63916015625,469.580535888672));await capture("185-noticeboard-behind-visible")
	app.world.teleport(Vector2(720,515));await capture("186-noticeboard-front-opaque")
	app.state.quest_stage=3;app.state.recruit_companion();app._sync_world_state();app._refresh()
	app.world.teleport(Vector2(750,520));app.world.set_process(false)
	# Prepared render fixture for the overlap screenshot only.
	PartyFixture.prepare_render(app.world,[PartyFixture.render_frame("shen",Vector2(720,467))]);app.world.queue_redraw()
	await capture("187-noticeboard-companion-visible")
	app.world.set_process(true);app._show_board();await capture("188-noticeboard-reading-after-fade")
	app.queue_free();await create_timer(.25).timeout;print("PASS: noticeboard party occlusion actual engine captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
