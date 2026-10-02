extends "res://tests/unified_combat_ui_test.gd"
func _run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	fixture="user://unified-terminal-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false;app.world.set_process(false)
	for outcome in ["win","defeat"]:
		await _terminal_close(outcome,false)
		await _terminal_close(outcome,true)
	await _sluice_callbacks()
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d accepted-terminal close/once-only reward/teleport/retry and sluice callback checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
func _terminal_close(outcome:String,fail:bool)->void:
	var kind="training" if outcome=="win" else "heting_receipt"
	_setup(kind,4 if outcome=="win" else 1)
	check(app._start_unified_battle(kind),"Real terminal-close encounter enters")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
	var path=fixture+"/save.json";var old=FileAccess.get_file_as_bytes(path)
	var coins=s.coins;var earned=s.xp+30*s.level*(s.level-1)
	for step in range(400):
		if panel.pending.is_empty():panel._process(.5)
		if not panel.pending.is_empty() and not panel.pending.after.active:break
		_finish(panel)
	check(not panel.pending.is_empty() and panel.pending.after.outcome==outcome,"Reach real accepted terminal "+outcome)
	var final_tx=panel.pending;var sequence=final_tx.after.action_sequence;var writes=s.writes
	if fail:check(DirAccess.make_dir_absolute(path+".tmp")==OK,"Inject real final-write failure")
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(app.exits==0 and panel.close_pending,"Terminal presentation completes before exit")
	_finish(panel)
	check(not s.battle_active and s.party_settlement.outcome==outcome and s.party_session.snapshot().action_sequence==sequence,"Terminal close does not append flee or repeat action")
	check(s.writes==writes+1,"Explicit close writes once after terminal settlement")
	check(s.coins==coins+(12 if outcome=="win" else -8),"Exactly one reward or defeat penalty")
	check(s.xp+30*s.level*(s.level-1)==earned+(30 if outcome=="win" else 0),"Exactly one terminal XP award")
	if outcome=="defeat":
		check(s.map_id=="heting" and s.position==Vector2(230,735) and app.world.player_pos==s.position,"Defeat teleports actual world before close save")
	var terminal=s.to_dict()
	if fail:
		check(app.exits==0 and app.save_warning and FileAccess.get_file_as_bytes(path)==old,"Failed terminal close preserves previous real save")
		check(DirAccess.rename_absolute(path+".tmp",path+".blocker")==OK,"Retire only synthetic failure blocker")
		await _key(KEY_1)
		check(s.to_dict()==terminal and app.exits==1,"Retry exits without second reward or penalty")
		check(DirAccess.remove_absolute(path+".blocker")==OK,"Remove empty test blocker")
	else:check(app.exits==1,"Successful terminal save exits")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).player==JSON.parse_string(JSON.stringify(terminal)),"Saved terminal document matches settled exploration state")
	writes=s.writes;app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(app.exits==1 and s.writes==writes and s.to_dict()==terminal,"Duplicate successful close has no second write or exit")
	await process_frame
func _sluice_callbacks()->void:
	_setup("sluice_scout",1)
	s.side_stage=0;s.side_choice="";s.side_found.clear();s.side_clues=0
	await _key(KEY_E);var cancelled=app.modal_actions[0]
	await _key(KEY_ESCAPE);var before=s.to_dict();var writes=s.writes;cancelled.call()
	check(s.to_dict()==before and s.writes==writes and not s.battle_active,"Cancelled scout callback cannot choose a route or save")
	await _key(KEY_E);var distant=app.modal_actions[0]
	app.world.teleport(app.world.player_pos+Vector2(-200,0));app._process(0);before=s.to_dict();writes=s.writes;distant.call()
	check(s.to_dict()==before and s.writes==writes and s.side_choice=="","Distant valid-generation scout callback cannot choose route")
	app._close_modal();app.world.teleport(app.world.interactables.ledger_runner.pos+Vector2(0,24));app._process(0)
	await _key(KEY_E);var hp_before=s.hp;var med_before=s.medicine;s.fail_writes=true;await _key(KEY_1)
	check(not s.battle_active and s.side_choice=="pursuit" and s.hp==hp_before and s.medicine==med_before,"Failed legitimate pre-entry save retains explicit route without accepting combat cost")
	s.fail_writes=false;app._sluice_party_entry("sluice_scout",app.modal_generation)
	check(s.battle_active and app.current_screen=="party_battle","Legitimate retry enters the shared scout controller")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false);panel.leave();_finish(panel)
	await process_frame
