extends SceneTree
const Model=preload("res://scripts/game_state.gd")
class FailureState extends Model:
	var fail=false
	var failed=0
	func save_game(path:String=SAVE_PATH)->Error:
		if fail:failed+=1;return ERR_CANT_CREATE
		return super.save_game(path)
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func words(node:Node)->String:
	var result=node.text if node is Label or node is RichTextLabel else ""
	for child in node.get_children():result+=words(child)
	return result
func run()->void:
	assert(FileAccess.file_exists("res://project.binary"))
	var profile=OS.get_environment("XDG_DATA_HOME").simplify_path()
	assert(profile.get_file().ends_with("-close-pack-data") and ProjectSettings.globalize_path("user://").begins_with(profile+"/"))
	app=load("res://scenes/main.tscn").instantiate();app.state=FailureState.new();root.add_child(app);await process_frame;app._new_game()
	var original=FileAccess.get_file_as_bytes(Model.SAVE_PATH);assert(JSON.parse_string(original.get_string_from_utf8()).player.coins==24)
	app.state.coins=25;var mode=OS.get_environment("HERO_CLOSE_MODE");app.state.fail=mode!="normal"
	app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST)
	if mode!="normal":
		assert(not app.quit_pending and app.state.coins==25 and words(app.overlay).contains("手记未能落笔") and FileAccess.get_file_as_bytes(Model.SAVE_PATH)==original)
	match mode:
		"cancel":
			await key(KEY_3);assert(not app.quit_pending and words(app.overlay).contains("舍下未存"));await key(KEY_1)
			assert(not app.quit_pending and app.overlay.get_meta("pause_menu",false) and app.state.coins==25)
		"retry":
			await key(KEY_2);assert(not app.quit_pending and app.overlay.get_meta("pause_menu",false))
			app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST);assert(not app.quit_pending);app.state.fail=false;await key(KEY_1)
		"discard":
			await key(KEY_3);assert(not app.quit_pending and words(app.overlay).contains("舍下未存"));await key(KEY_2)
	var saved=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
	var expected_exit=mode!="cancel"
	assert(app.quit_pending==expected_exit)
	assert(saved.player.coins==(25 if mode in ["normal","retry"] else 24))
	var report={"mode":mode,"exported_project":true,"failed_save_attempts":app.state.failed,"memory_coins":app.state.coins,"saved_coins":saved.player.coins,"quit_pending":app.quit_pending,"active_modal":app.active_modal,"all_checks_passed":true}
	var file=FileAccess.open(OS.get_environment("HERO_CLOSE_REPORT"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	if expected_exit:return
	app._stop_audio();app.queue_free();await create_timer(.25).timeout;quit()
