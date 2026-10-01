extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("Screenshot QA requires graphics");quit(1);return
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.world.teleport(Vector2(470,615));app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.5).timeout
	app._capture_screenshot();app._capture_screenshot()
	assert(app.screenshot_pending)
	await RenderingServer.frame_post_draw;await process_frame
	var first:String=app.last_screenshot_path
	assert(not app.screenshot_pending and app.screenshot_sequence==1 and not Image.load_from_file(first).is_empty())
	await app._capture_screenshot();await process_frame
	var second:String=app.last_screenshot_path
	assert(second!=first and app.screenshot_sequence==2 and not Image.load_from_file(second).is_empty())
	assert(app.status_label.text.contains("截图已保存") and app.status_label.text.length()<48 and not app.status_label.text.contains("/workspace/"))
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/107-compact-screenshot-feedback.png")==OK)
	# Only remove the two disposable files created by this test, after full PNG decoding.
	assert(DirAccess.remove_absolute(first)==OK and DirAccess.remove_absolute(second)==OK)
	app.queue_free();await create_timer(.25).timeout
	print("PASS: two unique native PNGs, repeated-input coalescing, compact capture feedback");quit()
