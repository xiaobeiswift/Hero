extends SceneTree
## Prepared story state; actual engine input/movement; fixed-step evidence, not FPS.
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Prefs=preload("res://scripts/view_preferences.gd")
const Harbor=preload("res://scripts/heting_region.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
var stage=0
var age=0.0
var elapsed=0.0
var action=""
var started=false
var ending=false
var distance_walked=0.0
var prior=Vector2.ZERO
var checks=0
var failures:Array[String]=[]
var trace:Array=[]
var source_commit=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source_commit=arg.trim_prefix("--source=")
	begin.call_deferred()
func begin()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoPrefs.new();root.add_child(app)
	app._new_game();app._stop_audio();app.audio_on=false
	var s=app.state
	s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(600)
	s.side_stage=3;s.side_clues=2;s.side_found.assign(["boatman","ledger"]);s.side_choice="rescue";s.side_reward_claimed=true
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	s.mist_stage=4;s.mist_approach="duel";s.mist_ending="warn_ferries";s.mist_gauges.assign(["rain","stone","basin"])
	s.bridge_repaired=true;s.tangqi_stage=3;s.tangqi_choice="teach";s.tangqi_unlocked=true;s.active_companion="唐栖"
	verify(s.begin_heting(),"prepared entry")
	app._travel("heting",Vector2(665,620));app._change_view_zoom(1)
	app.toast_time=0;app.hud.quest_notice_time=0;prior=app.world.player_pos;started=true
func verify(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures.append(label);push_error(label)
func key(code:int)->void:
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	var release=InputEventKey.new();release.keycode=code;release.physical_keycode=code;release.pressed=false;Input.parse_input_event(release)
func move(next:String)->void:
	if action==next:return
	if not action.is_empty():Input.action_release(action)
	action=next
	if not action.is_empty():Input.action_press(action)
func approach(target:Vector2)->bool:
	var delta=target-app.world.player_pos
	if absf(delta.x)>7:move("move_right" if delta.x>0 else "move_left");return false
	if absf(delta.y)>7:move("move_down" if delta.y>0 else "move_up");return false
	move("");return true
func advance()->void:
	move("");trace.append({"stage":stage,"time":elapsed,"position":str(app.world.player_pos),"bridge":app.state.heting_bridge,"cargo":app.state.heting_cargo,"delivered":app.state.heting_delivered.duplicate()});stage+=1;age=0
func _process(delta:float)->bool:
	if not started or ending:return false
	elapsed+=delta;age+=delta
	distance_walked+=prior.distance_to(app.world.player_pos);prior=app.world.player_pos
	verify(Harbor.walkable(app.world.player_pos,app.state.heting_bridge,not app.state.heting_cargo.is_empty()),"player remains on live route")
	verify(Harbor.walkable(app.world.companion_pos,app.state.heting_bridge,false),"party remains on harbor terrain")
	if elapsed>18 or not failures.is_empty():ending=true;finish.call_deferred();return false
	match stage:
		0:
			if age>=.6:key(KEY_E);advance()
		1:
			if age>=1.0:
				verify(app.active_modal,"cargo page opened by E");key(KEY_2);advance()
		2:
			if age>.1:
				verify(app.state.heting_cargo=="sealed","second cargo choice loads sealed batch")
				if approach(Vector2(665,735)):advance()
		3:
			if approach(Vector2(820,735)):key(KEY_E);advance()
		4:
			if age>=1.0:
				verify(app.active_modal,"winch page opened by E");key(KEY_1);advance()
		5:
			if age>.1:
				verify(app.state.heting_bridge=="east","choice moves actual pontoon east")
				if approach(Vector2(1130,735)):advance()
		6:
			if approach(Vector2(1390,735)):advance()
		7:
			if approach(Vector2(1390,600)):key(KEY_E);advance()
		8:
			if age>=1.0:
				verify(app.active_modal,"scale receiver reached through live route");key(KEY_1);advance()
		9:
			if age>=1.2:
				verify(app.state.heting_delivered==["sealed"] and app.state.heting_cargo.is_empty(),"confirmed delivery consumes exactly one batch")
				verify(distance_walked>900,"moving cart followed a substantial bridge route")
				ending=true;finish.call_deferred()
	return false
func finish()->void:
	move("")
	var record={"source_commit":source_commit,"scope":"prepared source state, actual scripted E/number and held movement input, fixed-step movie; not manual play, FPS measurement or desktop release","simulated_seconds":elapsed,"distance_walked":distance_walked,"checks":checks,"failures":failures,"trace":trace,"final":app.state.to_dict()}
	print(JSON.stringify(record))
	app.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() and stage==9 else 1)
