extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.set_process(false)
	app.view_preferences.zoom_index=2;app._apply_view_zoom()
	for row in [["205-shrine-roof-visibility",Vector2(900,695)],["206-clinic-roof-visibility",Vector2(300,185)],["207-shrine-front-depth",Vector2(900,820)]]:
		assert(app.world._can_walk(row[1]));app.world.teleport(row[1]);await capture(row[0])
	assert(app.world._can_walk(Vector2(1050,710)));app.world.teleport(Vector2(1050,710))
	# Prepared render fixture, not evidence of movement or recruited membership.
	PartyFixture.prepare_render(app.world,[PartyFixture.render_frame("shen",Vector2(900,695))])
	await capture("208-companion-roof-visibility")
	app.queue_free();await create_timer(.25).timeout;print("PASS: actual building roof/foreground/companion visibility captures");quit()
func capture(name:String)->void:
	app.toast_time=0;app.hud.quest_notice_time=0;app.world.queue_redraw();await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
