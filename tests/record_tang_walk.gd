extends SceneTree
## Scripted input in the exact frozen source; fixed-step capture, not a realtime FPS test.
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
var elapsed=0.0
var running=false
var ending=false
var action=""
var start_position=Vector2(600,440)
func _initialize()->void:begin.call_deferred()
func begin()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app)
	app._new_game();app._stop_audio();app.audio_on=false;app.state.quest_stage=6;app.state.side_stage=3;app.state.chapter_two_stage=4;app.state.bridge_repaired=true;app.state.tangqi_stage=3;app.state.tangqi_choice="preserve";app.state.tangqi_unlocked=true;app.state.select_companion("唐栖");app._sync_world_state();app._refresh();app._change_view_zoom(1);app._change_view_zoom(1);app.world.teleport(start_position);app.world.companion_pos=Vector2(548,477)
	app.toast_time=0;app.hud.quest_notice_time=0;running=true
func set_action(next:String)->void:
	if next==action:return
	if not action.is_empty():Input.action_release(action)
	action=next
	if not action.is_empty():Input.action_press(action)
func _process(delta:float)->bool:
	if not running or ending:return false
	elapsed+=delta
	var next=""
	if elapsed>=.3 and elapsed<1.3:next="move_right"
	elif elapsed>=1.3 and elapsed<1.75:next="move_down"
	elif elapsed>=1.75 and elapsed<2.75:next="move_left"
	elif elapsed>=2.75 and elapsed<3.2:next="move_up"
	set_action(next)
	if elapsed>=4.0:
		ending=true;finish.call_deferred()
	return false
func finish()->void:
	set_action("")
	print(JSON.stringify({"scope":"scripted held movement in clean9aa58ca runtime source, fixed24FPS recording","start":str(start_position),"end":str(app.world.player_pos),"companion":app.state.current_companion(),"companion_end":str(app.world.companion_pos),"companion_walk_phase":app.world.companion_walk_time,"duration_simulated":elapsed,"viewport":str(root.size),"world_view":str(app.world_view.size)}))
	app.queue_free();await create_timer(.2).timeout;quit()
