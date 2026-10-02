extends "res://tests/unified_combat_ui_test.gd"
## Actual full-game controls, prepared level6 roster, fixed30fps engine movie.
var trace:Array[Dictionary]=[]
var source_commit=""
var trace_path=""
var runtime_hashes:Dictionary={}
func _run()->void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):source_commit=argument.trim_prefix("--source=")
		if argument.begins_with("--trace="):trace_path=argument.trim_prefix("--trace=")
	check(not source_commit.is_empty() and not trace_path.is_empty(),"Explicit source/evidence identity")
	runtime_hashes=JSON.parse_string(FileAccess.get_file_as_string("res://tests/unified_integration_check.json")).runtime_sha256
	_verify_runtime()
	root.size=Vector2i(1280,800)
	fixture="user://auto-movie-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false;app.world.set_process(false)
	_setup("heting_receipt",4);s.learn_internal_skill();s.learn_lightness();s.hp-=24
	app.receipt_story.open();await _key(KEY_1)
	var panel=app.overlay.get_meta("party_battle");check(panel!=null,"Real optional encounter enters")
	panel.art.event_presented.connect(func(event):trace.append(event.duplicate(true)))
	await _key(KEY_P);await _frames(15)
	check(s.party_battle_snapshot().paused,"Real pause key stops next safe boundary")
	await _click(panel.commands.actor_buttons.qin);await _key(KEY_1);await _click(panel.unit_plates.hero);await _frames(10)
	await _click(panel.commands.actor_buttons.shen);await _key(KEY_1);await _click(panel.unit_plates.hero);await _frames(10)
	await _click(panel.commands.actor_buttons.tang);await _key(KEY_3);await _frames(10)
	await _click(panel.commands.actor_buttons.hero);await _key(KEY_1);await _frames(20)
	check(_actor(s.party_battle_snapshot(),"qin").categories.martial.queued and _actor(s.party_battle_snapshot(),"shen").categories.martial.queued,"Actual queued ally skill recipients")
	await _key(KEY_P)
	for frame in range(600):
		await process_frame
		if not s.battle_active or (s.party_battle_snapshot().round>=3 and not s.party_battle_snapshot().locked):break
	var basics={};var categories=[]
	for event:Dictionary in trace:
		if event.type!="action" or event.source_id not in ["hero","shen","tang","qin"]:continue
		if event.get("automatic",false):
			var key="%s:%d"%[event.source_id,event.round];check(not basics.has(key),"Recorded automatic basic occurs once per actor/round");basics[key]=true
		else:categories.append(event.get("category",""))
	for id in ["hero","shen","tang","qin"]:check(basics.has(id+":1"),"Every living ally automatically attacks in first round")
	check(categories.has("martial") and categories.has("lightness") and not categories.has("guard"),"Manual categories remain distinct from automatic basic")
	check(s.battle_active and s.party_battle_snapshot().round>=3,"Two full automatic rounds complete without manual basic commands")
	await _key(KEY_P);await _frames(15);await _key(KEY_5)
	for _frame in range(90):
		if not s.battle_active:break
		await process_frame
	check(not s.battle_active and s.party_settlement.outcome=="flee" and s.receipt_stage==1,"Real retreat leaves the optional encounter retryable without a victory reward")
	await _frames(30)
	_verify_runtime()
	var file=FileAccess.open(trace_path,FileAccess.WRITE)
	check(file!=null,"Evidence destination opens")
	if file!=null:
		file.store_string(JSON.stringify({"source_commit":source_commit,"scope":"Prepared level6 full-game source; actual scripted mouse/keys queue optional martial/lightness and pause/resume, fixed30fps two-round automatic basic/skill/enemy playback then real retreat; no manual play/browser/audio/FPS claim","checks":checks,"failures":failures,"events":trace,"settlement":s.party_settlement,"runtime_sha256":runtime_hashes},"\t"));file.close()
	app._stop_audio();app.queue_free();await process_frame
	print("%s: recorded automatic basics plus separate real queued skills; %d checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
func _frames(count:int)->void:
	for _index in range(count):await process_frame
func _verify_runtime()->void:
	for path:String in runtime_hashes:check(FileAccess.get_sha256("res://"+path)==runtime_hashes[path],"Frozen runtime identity: "+path)
