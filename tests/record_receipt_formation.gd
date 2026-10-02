extends "res://tests/visual_receipt_encounter.gd"
## Prepared real encounter; scripted input at fixed step, not manual play or FPS.
const MOVES=[KEY_1,KEY_3,KEY_2,KEY_1]
var step=0
var age=0.0
var elapsed=0.0
var started=false
var ending=false
var checks=0
var failures:Array[String]=[]
var trace:Array=[]
var expected_turn=-1
var initial_resources:Dictionary={}
var source_commit=""

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):source_commit=arg.trim_prefix("--source=")
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app)
	app._new_game();app._stop_audio();app.audio_on=false;prepare();app.state.formation="护后"
	check(app.state.begin_receipt(),"Prepared completed harbor accepts optional errand")
	app.receipt_story.open();press("保存后应战")
	panel=app.overlay.get_meta("receipt_battle");initial_resources=resources();started=true

func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func press_key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event)

func resources()->Dictionary:
	return {"hp":app.state.hp,"qi":app.state.qi,"medicine":app.state.medicine,"coins":app.state.coins,"xp":app.state.xp,"receipt_stage":app.state.receipt_stage}

func advance()->void:
	trace.append({"step":step,"simulated_seconds":elapsed,"resources":resources(),"model":panel.rules.snapshot() if is_instance_valid(panel) else {}})
	step+=1;age=0

func _process(delta:float)->bool:
	if not started or ending:return false
	age+=delta;elapsed+=delta
	if elapsed>15 or not failures.is_empty():ending=true;finish.call_deferred();return false
	if expected_turn>=0 and age>.08:
		check(panel.rules.turn==expected_turn and panel.rules.locked,"One numeric input accepts one real action");expected_turn=-1
	if step==0 and age>.6:press_key(KEY_TAB);advance()
	elif step>=1 and step<=MOVES.size() and age>.32 and not panel.rules.locked:
		if step==1:check(panel.rules.selected_id=="bracer","Tab selects front protector")
		expected_turn=panel.rules.turn+1;press_key(MOVES[step-1]);advance()
	elif step==MOVES.size()+1 and age>.55 and not panel.rules.locked:
		check(panel.rules.units[1].hp==0 and panel.rules.selected_id=="striker","Protector down; survivor automatically selected")
		check(app.state.hp<initial_resources.hp and app.state.medicine==initial_resources.medicine,"Encounter uses real HP without free medicine")
		press_key(KEY_ESCAPE);advance()
	elif step==MOVES.size()+2 and age>1.05:
		check(app.current_screen=="explore" and not app.state.battle_active and app.state.receipt_stage==1,"Retreat returns to world with retryable progress")
		check(app.state.coins==initial_resources.coins and app.state.xp==initial_resources.xp,"Short motion scenario grants no reward")
		ending=true;finish.call_deferred()
	return false

func finish()->void:
	print(JSON.stringify({"source_commit":source_commit,"scope":"Prepared level5 companion encounter, real scripted Tab/number/Escape events, fixed-step source motion; not manual, browser, native release, FPS or audio proof","checks":checks,"failures":failures,"simulated_seconds":elapsed,"initial":initial_resources,"final":resources(),"trace":trace}))
	app._stop_audio();app.queue_free();await create_timer(.2).timeout;quit(0 if failures.is_empty() and step==6 else 1)
