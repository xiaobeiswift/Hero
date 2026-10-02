extends SceneTree
## Prepared companion; actual E/Tab/1–5 events. Fixed-step capture, not FPS.
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
var panel
var step=0
var age=0.0
var elapsed=0.0
var started=false
var ending=false
var before:Dictionary={}
var checks=0
var failures:Array[String]=[]
var trace:Array=[]
var source_commit=""
var expected_turn=-1
const MOVES=[KEY_1,KEY_3,KEY_2,KEY_1,KEY_1]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source_commit=arg.trim_prefix("--source=")
	begin.call_deferred()
func begin()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app)
	app._new_game();app._stop_audio();app.audio_on=false
	app.state.companion_unlocked=true;app.state.active_companion="沈青";app.world.teleport(Vector2(725,782));app._process(0);app._sync_world_state()
	app.toast_time=0;app.hud.quest_notice_time=0;before=app.state.to_dict();started=true
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event)
func advance()->void:
	trace.append({"stage":step,"time":elapsed,"model":panel.rules.snapshot() if panel!=null and is_instance_valid(panel) else {}});step+=1;age=0
func _process(delta:float)->bool:
	if not started or ending:return false
	elapsed+=delta;age+=delta
	check(app.state.to_dict()==before,"real exploration state unchanged")
	if elapsed>16 or not failures.is_empty():ending=true;finish.call_deferred();return false
	if expected_turn>=0 and age>.08:
		check(panel.rules.turn==expected_turn and panel.rules.locked,"number accepts exactly one action");expected_turn=-1
	if step==0 and age>.55:
		check(app.world.nearby_id=="courtyard_practice","actual nearby courtyard entry");key(KEY_E);advance()
	elif step==1 and age>.75:
		panel=app.overlay.get_meta("courtyard_practice") if app.overlay.has_meta("courtyard_practice") else null;check(panel!=null,"E opened exercise")
		if panel!=null:key(KEY_TAB)
		advance()
	elif step>=2 and step<2+MOVES.size() and age>.35 and not panel.rules.locked:
		if step==2:check(panel.rules.selected_id=="bracer","Tab selects shield")
		expected_turn=panel.rules.turn+1;key(MOVES[step-2]);advance()
	elif step==2+MOVES.size() and not panel.rules.locked and age>.8:
		check(panel.rules.units[1].hp==0,"shield target down");check(panel.rules.selected_id=="striker","surviving target selected");key(KEY_ESCAPE);advance()
	elif step==3+MOVES.size() and age>.55:
		check(not app.active_modal,"Escape returns without opening pause");ending=true;finish.call_deferred()
	return false
func finish()->void:
	var record={"source_commit":source_commit,"scope":"prepared companion, actual scripted E/Tab/number/Escape input, fixed-step source motion; not manual play, FPS or release","checks":checks,"failures":failures,"simulated_seconds":elapsed,"trace":trace,"real_state_unchanged":app.state.to_dict()==before}
	print(JSON.stringify(record));app._stop_audio();app.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() and step==8 else 1)
