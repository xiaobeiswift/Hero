extends SceneTree
const UnifiedUI = preload("res://tests/unified_ui_test_driver.gd")
const Main=preload("res://scripts/main.gd")
const Model=preload("res://scripts/game_state.gd")
class AuditState extends Model:
	var fail=false
	var writes=0
	var snapshot:Dictionary={}
	func save_game(_path:String=SAVE_PATH)->Error:
		writes+=1
		if fail:return ERR_CANT_CREATE
		snapshot=to_dict().duplicate(true);return OK
	func has_save()->bool:return not snapshot.is_empty()
class AuditMain extends Main:
	var exit_calls=0
	var last_exit_save=true
	func _quit_cleanly(save_progress:bool=true)->void:
		exit_calls+=1;last_exit_save=save_progress
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func text(node:Node)->String:
	var result=node.text if node is Label or node is RichTextLabel else ""
	for child in node.get_children():result+=text(child)
	return result
func run()->void:
	app=AuditMain.new();app.state=AuditState.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	await key(KEY_ESCAPE)
	assert(app.active_modal and app.overlay.get_meta("pause_menu",false) and app.modal_actions.size()==5)
	var frame=app.overlay.find_child("JourneyPause",true,false)
	assert(frame!=null and Rect2(0,0,1280,800).encloses(frame.get_rect()))
	assert(text(frame).contains("气血 100 / 100") and text(frame).contains("Esc 继续"))
	var position:Vector2=app.world.player_pos
	Input.action_press("move_right");await create_timer(.15).timeout;Input.action_release("move_right")
	assert(app.world.player_pos==position and not app.world.active)
	var stale:Callable=app.modal_actions[4]
	await key(KEY_ESCAPE);assert(not app.active_modal)
	stale.call();assert(not app.active_modal and app.exit_calls==0)
	await key(KEY_I);await key(KEY_ESCAPE);assert(not app.active_modal) # Existing one-Escape menu dismissal.
	await key(KEY_ESCAPE);await key(KEY_1);assert(not app.active_modal)
	await key(KEY_ESCAPE);await key(KEY_2);assert(app.active_modal and not app.overlay.get_meta("pause_menu",false))
	assert(text(app.overlay).contains("存") or text(app.overlay).contains("手记"));await key(KEY_ESCAPE)
	await key(KEY_ESCAPE);await key(KEY_3);assert(app.active_modal and not app.overlay.get_meta("pause_menu",false));await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	var sound=app.overlay.find_child("PauseSound",true,false);assert(sound!=null)
	sound.pressed.emit();await process_frame
	assert(app.audio_on and app.overlay.find_child("PauseSound",true,false).text.contains("开"))
	await key(KEY_4);assert(text(app.overlay).contains("保存成功才会离开"))
	await key(KEY_2);assert(app.overlay.get_meta("pause_menu",false))
	await key(KEY_4);await key(KEY_1)
	assert(app.current_screen=="title" and app.exit_calls==0 and not app.state.snapshot.is_empty())
	app._new_game();app.state.fail=true
	await key(KEY_ESCAPE);await key(KEY_5)
	assert(app.exit_calls==0 and text(app.overlay).contains("三份手动手记不受影响"))
	await key(KEY_1)
	assert(app.current_screen=="explore" and app.exit_calls==0 and app.save_warning and text(app.overlay).contains("本地写入失败"))
	var old_retry:Callable=app.modal_actions[0]
	await key(KEY_3);assert(text(app.overlay).contains("不会删除已有存档"))
	await key(KEY_1);assert(app.overlay.get_meta("pause_menu",false) and app.exit_calls==0)
	var writes:int=app.state.writes;old_retry.call();assert(app.state.writes==writes)
	await key(KEY_5);await key(KEY_1);app.state.fail=false;await key(KEY_1)
	assert(app.exit_calls==1 and not app.last_exit_save and not app.save_warning)
	# Explicit failed-save discard is separately confirmed and never retries a write.
	app._close_modal();app.state.fail=true;await key(KEY_ESCAPE);await key(KEY_5);await key(KEY_1);await key(KEY_3)
	writes=app.state.writes;await key(KEY_2)
	assert(app.exit_calls==2 and not app.last_exit_save and app.state.writes==writes)
	app.state.fail=false;app._close_modal();UnifiedUI.open_training(app)
	await key(KEY_P);assert(app.current_screen=="party_battle" and UnifiedUI.active(app))
	app._show_pause();assert(UnifiedUI.active(app))
	app.battle_presentation_enabled=false;UnifiedUI.leave(app);app._close_modal()
	app.queue_free();await create_timer(.25).timeout
	print("PASS: rest menu input, movement block, save-gated exit, retry/discard and stale callbacks");quit()
