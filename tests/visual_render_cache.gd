extends SceneTree
## Run graphically. Same-frame A/B captures are suitable for pixel comparison.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.set_process(false);app.world.set_process(false);app.world.visible=true
	await create_timer(.5).timeout
	if not app.world.terrain_cache_ready():push_error("Terrain cache not ready");quit(1);return
	if app.world._terrain_viewport.render_target_update_mode!=SubViewport.UPDATE_DISABLED:push_error("Cache keeps rendering");quit(1);return
	var points=[Vector2(460,430),Vector2(435,650),Vector2(900,455),Vector2(1260,350),Vector2(1400,880),Vector2(1514,930)]
	DirAccess.make_dir_recursive_absolute("res://builds/render-cache-qa")
	for i in range(points.size()):
		app.world.teleport(points[i]);app.world.time_passed=2.0
		var original=app.state.to_dict()
		for enabled in [false,true]:
			app.world.terrain_cache_enabled=enabled;app.world.render_culling_enabled=enabled;app.world.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			var path="res://builds/render-cache-qa/view-%d-%s.png"%[i,str(enabled)]
			if root.get_texture().get_image().save_png(path)!=OK:push_error("Capture failed");quit(1);return
		if app.state.to_dict()!=original:push_error("Drawing changed gameplay state");quit(1);return
	print("PASS: 6 actual-engine cached/culling comparison pairs; one-shot cache disabled after bake")
	app._stop_audio();app.queue_free();await create_timer(.3).timeout;quit()
