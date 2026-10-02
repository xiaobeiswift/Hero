extends "res://tests/unified_combat_ui_test.gd"
func _run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	fixture="user://unified-practice-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false;app.world.set_process(false)
	for outcome:String in ["win","defeat","flee"]:await _ordinary(outcome)
	for discard in [false,true]:await _application_close(discard)
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d current rehearsal result/retry/decline/dismiss/close and original-save byte checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
func _baseline(outcome:String)->Dictionary:
	_setup("courtyard_practice",4 if outcome=="win" else 1)
	if outcome=="defeat":
		s.reset_game();s.position=app.world.player_pos
	check(s.save_game()==OK,"Write good exploration baseline")
	var bytes=FileAccess.get_file_as_bytes(fixture+"/save.json")
	# Distinct unsaved real progress catches accidental autosaves even though
	# sandbox combat correctly avoids mutating persistent resources.
	s.coins+=7;s.hp-=10;s.qi=1
	return {"bytes":bytes,"state":s.to_dict().duplicate(true),"writes":s.writes}
func _enter():
	check(app._start_unified_battle("courtyard_practice"),"Shared rehearsal entry")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
	return panel
func _same(before:Dictionary,label:String)->void:
	check(s.to_dict()==before.state and s.writes==before.writes and FileAccess.get_file_as_bytes(fixture+"/save.json")==before.bytes,label)
func _ordinary(outcome:String)->void:
	var before=_baseline(outcome)
	app._practice_dialogue();await _key(KEY_ESCAPE)
	_same(before,"Declining practice cannot autosave unsaved progress")
	var panel=_enter()
	if outcome=="flee":
		panel._process(.5);_finish(panel);panel.leave();_finish(panel)
	else:
		for step in range(300):
			if not s.battle_active:break
			_step_view(panel)
		if s.battle_active and panel.art.is_presenting():_finish(panel)
	check(not s.battle_active and s.party_settlement.get("outcome")==outcome,"Actual automatic rehearsal reaches "+outcome)
	_same(before,"Practice outcome preserves live fields and disk bytes")
	var stale=app.modal_actions[0]
	await _key(KEY_1)
	check(s.battle_active and s.party_battle_snapshot().round==1,"Result retry starts a new virtual round")
	var next=app.overlay.get_meta("party_battle");next.set_process(false);next.art.set_process(false)
	for actor:Dictionary in s.party_battle_snapshot().actors:
		check(actor.hp==actor.max_hp and actor.qi==actor.max_qi,"Retry fills only virtual resources")
	next.leave();_finish(next)
	_same(before,"Result retry and retreat never write real save")
	await _key(KEY_ESCAPE)
	_same(before,"Escape dismissing result never autosaves")
	stale.call();check(not s.battle_active,"Old result retry cannot reopen a later closed scene")
	panel=_enter();panel.leave();_finish(panel);await _key(KEY_2)
	_same(before,"Return-to-courtyard button never autosaves")
	await process_frame
func _application_close(discard:bool)->void:
	var before=_baseline("defeat");var panel=_enter();panel._process(.5)
	var path=fixture+"/save.json"
	check(DirAccess.make_dir_absolute(path+".tmp")==OK,"Inject owned actual write failure")
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_finish(panel);_finish(panel)
	check(app.exits==0 and app.save_warning and s.to_dict()==before.state and FileAccess.get_file_as_bytes(path)==before.bytes,"Practice explicit close failure retains original exploration state and earlier bytes")
	var stale=app.modal_actions[0];await _key(KEY_2);stale.call()
	check(app.exits==0 and s.to_dict()==before.state,"Cancelled failed close invalidates stale retry without virtual leakage")
	panel=_enter();panel._process(.5);app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);_finish(panel);_finish(panel)
	check(app.exits==0 and s.to_dict()==before.state,"Failed close after retrying practice still retains real state")
	if discard:
		await _key(KEY_3);check(app.exits==0,"Practice discard asks explicit confirmation")
		await _key(KEY_2)
		check(app.exits==1 and FileAccess.get_file_as_bytes(path)==before.bytes,"Confirmed practice close discard preserves old good save")
		check(DirAccess.remove_absolute(path+".tmp")==OK,"Remove only test-owned empty blocker")
	else:
		check(DirAccess.rename_absolute(path+".tmp",path+".injected-blocker")==OK,"Recover test storage without touching original save")
		await _key(KEY_1)
		var saved=JSON.parse_string(FileAccess.get_file_as_string(path)).player
		check(app.exits==1 and saved==JSON.parse_string(JSON.stringify(before.state)) and s.to_dict()==before.state,"Explicit close saves exploration only, never virtual HP/qi/medicine/proficiency")
		check(DirAccess.remove_absolute(path+".injected-blocker")==OK,"Remove only retired empty blocker")
	await process_frame
