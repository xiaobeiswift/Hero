extends SceneTree
const Main=preload("res://scripts/main.gd")
const Model=preload("res://scripts/game_state.gd")
class AuditState extends Model:
	var fail=false
	var writes=0
	var saved:Dictionary={}
	func save_game(_path:String=SAVE_PATH)->Error:
		writes+=1
		if fail:return ERR_CANT_CREATE
		saved=to_dict().duplicate(true);return OK
	func has_save()->bool:return not saved.is_empty()
class DiskState extends Model:
	var audit_path:String
	func save_game(_path:String=SAVE_PATH)->Error:
		return super.save_game(audit_path)
	func has_save()->bool:return FileAccess.file_exists(audit_path)
class AuditMain extends Main:
	var exits=0
	var exit_save=true
	func _quit_cleanly(save_progress:bool=true)->void:
		exits+=1;exit_save=save_progress;quit_pending=true
var app
func _initialize()->void:run.call_deferred()
func create_game(start_game:bool=true)->void:
	app=AuditMain.new();app.state=AuditState.new();root.add_child(app);await process_frame
	if start_game:app._new_game()
	app._stop_audio();app.audio_on=false
func dispose()->void:
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func request_close()->void:app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST)
func disk_failure_case(discard:bool)->void:
	# A unique test-owned path prevents touching the normal hero_save.json even
	# if this focused check is invoked without the aggregate runner's isolation.
	var folder="user://window-close-audit-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	assert(not DirAccess.dir_exists_absolute(folder))
	assert(DirAccess.make_dir_recursive_absolute(folder)==OK)
	app=AuditMain.new();app.state=DiskState.new();app.state.audit_path=folder+"/progress.json"
	root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	var path:String=app.state.audit_path
	assert(FileAccess.file_exists(path));var original=FileAccess.get_file_as_bytes(path)
	# Fail opening the temporary file while retaining a real existing good save.
	assert(DirAccess.make_dir_absolute(path+".tmp")==OK)
	app.state.coins+=7;request_close()
	assert(app.exits==0 and not app.quit_pending and app.active_modal and app.state.coins==31)
	assert(FileAccess.get_file_as_bytes(path)==original)
	if discard:
		await key(KEY_3);assert(app.exits==0);await key(KEY_2)
		assert(app.exits==1 and FileAccess.get_file_as_bytes(path)==original)
	else:
		# Preserve the synthetic blocker under another name, then retry normally.
		assert(DirAccess.rename_absolute(path+".tmp",path+".injected-blocker")==OK)
		await key(KEY_1)
		assert(app.exits==1 and JSON.parse_string(FileAccess.get_file_as_string(path)).player.coins==31)
	await dispose()
func run()->void:
	await create_game();app.state.coins+=1;app.state.fail=true
	var saved=app.state.saved.duplicate(true);var writes:int=app.state.writes
	request_close()
	assert(app.state.writes==writes+1 and app.exits==0 and not app.quit_pending and app.active_modal)
	assert(app.overlay.find_child("DialogueTitle",true,false).text=="手记未能落笔")
	assert(app.state.saved==saved and app.state.coins==25)
	var stale:Callable=app.modal_actions[0];request_close();writes=app.state.writes
	stale.call();assert(app.state.writes==writes and app.exits==0)
	await key(KEY_2);assert(app.overlay.get_meta("pause_menu",false) and not app.quit_pending)
	request_close();await key(KEY_3);assert(app.exits==0 and app.overlay.find_child("DialogueTitle",true,false).text=="舍下未存的这一程？")
	await key(KEY_1);assert(app.overlay.get_meta("pause_menu",false) and app.exits==0)
	request_close();app.state.fail=false;await key(KEY_1)
	assert(app.exits==1 and app.quit_pending and not app.exit_save and app.state.saved.coins==25)
	writes=app.state.writes;request_close();assert(app.exits==1 and app.state.writes==writes)
	await dispose()
	await create_game();app.state.coins+=1;app.state.fail=true;saved=app.state.saved.duplicate(true)
	request_close();writes=app.state.writes;await key(KEY_3);assert(app.exits==0)
	await key(KEY_2);assert(app.exits==1 and app.quit_pending and not app.exit_save and app.state.writes==writes and app.state.saved==saved)
	await dispose()
	await create_game();app.state.coins+=1;writes=app.state.writes;request_close()
	assert(app.exits==1 and not app.exit_save and app.state.writes==writes+1 and app.state.saved.coins==25)
	await dispose()
	await create_game(false);request_close();assert(app.exits==1 and app.state.writes==0 and not app.exit_save)
	await dispose()
	await create_game();app._start_battle("story");writes=app.state.writes;saved=app.state.saved.duplicate(true);request_close()
	assert(app.exits==1 and not app.exit_save and app.state.writes==writes and app.state.saved==saved)
	await dispose()
	await disk_failure_case(false);await disk_failure_case(true)
	print("PASS: real pre-existing save bytes survive filesystem failure/discard, recover on retry; desktop-close save failure keeps progress open; retry/cancel/explicit discard, duplicate events and title/battle boundaries");quit()
