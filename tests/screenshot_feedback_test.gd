extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func run()->void:
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio()
	var folder="user://capture-name-test"
	assert(DirAccess.make_dir_recursive_absolute(folder)==OK)
	var first=app._screenshot_target(folder,"2026-10-01T16:00:00")
	var second=app._screenshot_target(folder,"2026-10-01T16:00:00")
	assert(first!=second and first.get_file().contains("16-00-00"))
	var marker=FileAccess.open(first,FileAccess.WRITE);marker.store_string("keep");marker.close()
	app.screenshot_sequence=0
	assert(app._screenshot_target(folder,"2026-10-01T16:00:00")!=first)
	assert(FileAccess.get_file_as_string(first)=="keep")
	var before=app.state.to_dict()
	app._capture_screenshot()
	assert(not app.screenshot_pending and app.status_label.text.contains("无图形画面"))
	assert(app.state.to_dict()==before)
	app.quit_pending=true;app.status_label.text="retained";app._capture_screenshot()
	assert(app.status_label.text=="retained")
	app.quit_pending=false;app.screenshot_pending=true;app._capture_screenshot()
	assert(app.status_label.text=="retained")
	app._stop_audio();app.queue_free();await process_frame
	print("PASS: screenshot naming, no overwrite, headless and pending safeguards");quit()
