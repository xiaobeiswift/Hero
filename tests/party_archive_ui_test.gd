extends "res://tests/party_battle_ui_test.gd"
## Full-game prepared prior chapter state, actual archive and ending inputs.
func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture="user://archive-party-ui-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);app.save_slots.store=Slots.new(fixture)
	await process_frame
	app._stop_audio();app.audio_on=false;app.world.set_process(false)
	await _entry_safety()
	for choice in ["open_records","protect_witness"]:await _ending_safety(choice)
	await _close_archive()
	app._stop_audio();app.queue_free();await process_frame
	check(not FileAccess.file_exists(Model.SAVE_PATH),"No real save touched")
	print("%s: %d archive party scene/ending/save checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)

func _fresh_archive(count:int=2)->void:
	app.quit_pending=false;app.exits=0;s.fail_writes=false
	app.current_screen="explore";app.active_modal=false;app._clear_overlay()
	s.reset_game();s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(180)
	s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	if count==2:check(s.recruit_companion(),"Only available Shen is explicitly invited")
	check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"),"Existing chapter/clue APIs prepare canonical archive")
	for key in [2,0,1]:check(s.try_seal(key).valid,"Actual seal order progresses")
	s.map_id="frostbridge";s.formation="护后";s.heal_rest()
	app.world.change_map("frostbridge",Vector2(190,500));s.position=app.world.player_pos;app._refresh()

func _entry_safety()->void:
	_fresh_archive()
	app.chapter_story.archive();var before=s.to_dict();var old=app.modal_actions[0]
	old.call();check(s.to_dict()==before and not s.battle_active,"Far archive callback has no side effect")
	app._close_modal();await _talk("chapter_archive");old=app.modal_actions[0];before=s.to_dict()
	await _key(KEY_ESCAPE);old.call();check(s.to_dict()==before and not s.battle_active,"Canceled archive callback cannot fight")
	await _talk("chapter_archive");old=app.modal_actions[0];app._show_map();old.call()
	check(not s.battle_active,"Older archive generation cannot enter from map")
	app._close_modal();await _talk("chapter_archive");s.fail_writes=true
	await _key(KEY_1)
	check(not s.battle_active and app.save_warning and s.hp==before.hp and s.medicine==before.medicine,"Failed archive entry save spends no resource")
	s.fail_writes=false;await _key(KEY_1)
	var panel=app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
	check(panel!=null and panel.encounter=="archive_boss","Same choice retries into real party controller")
	if panel==null:return
	panel.art.set_process(false)
	check(panel.commands.context.title=="封仓问剑" and panel.unit_plates.has("archive_boss") and not panel.unit_plates.has("puheng"),"Correct encounter and unique opponent metadata")
	check(panel.commands.context.location.ends_with(s.formation),"Battle caption exposes actual current formation")
	await _click(panel.commands.actor_buttons.shen);await _key(KEY_3)
	var accepted=s.party_battle_snapshot();await _key(KEY_3,true)
	check(s.party_battle_snapshot()==accepted,"Held command cannot spend another actor turn")
	_finish(panel);await _key(KEY_5);_finish(panel)
	check(not s.battle_active and s.chapter_two_stage==2 and s.chapter_two_ending.is_empty(),"Retreat keeps solved seal and no ending")

func _win_archive(panel)->void:
	for turn in range(100):
		if not s.battle_active:break
		var snapshot=s.party_battle_snapshot();var actor=_actor(snapshot,snapshot.active_actor_id)
		var action="attack"
		for move:Dictionary in actor.actions:
			if move.available and move.category=="martial" and move.target_team=="enemy":action=move.id
		if actor.hp<actor.max_hp/2 and snapshot.medicine>0:action="item"
		panel.request_command(actor.id,action)
		check(not panel.pending.is_empty(),"Actual legal command accepts while winning archive")
		if panel.pending.is_empty():break
		_finish(panel)
	check(not s.battle_active and s.party_settlement.get("outcome")=="win","Prepared normal stats win archive")

func _ending_safety(choice:String)->void:
	_fresh_archive()
	await _talk("chapter_archive");await _key(KEY_1)
	var panel=app.overlay.get_meta("party_battle");panel.art.set_process(false)
	var coins=s.coins;_win_archive(panel)
	check(s.chapter_two_stage==3 and s.chapter_two_ending.is_empty() and s.coins==coins+40,"Fight gives only40 coins and leaves separate ending")
	app._close_modal()
	app.chapter_story.innkeeper();var stale=app.modal_actions[0];var before=s.to_dict()
	stale.call();check(s.to_dict()==before,"Remote ending cannot resolve or reward")
	app._close_modal();await _talk("chapter_host");stale=app.modal_actions[0];before=s.to_dict()
	await _key(KEY_ESCAPE);stale.call();check(s.to_dict()==before,"Canceled ending cannot resolve or reward")
	await _talk("chapter_host");stale=app.modal_actions[0];app._show_inventory();stale.call()
	check(s.to_dict()==before,"Stale ending from a different modal cannot resolve")
	app._close_modal();await _talk("chapter_host");stale=app.modal_actions[0]
	app.world.teleport(Vector2(1100,700));app._process(0);before=s.to_dict();stale.call()
	check(s.to_dict()==before,"Walking away invalidates an otherwise fresh ending")
	app._close_modal();await _talk("chapter_host")
	var selected=app.modal_actions[0 if choice=="open_records" else 1]
	before=s.to_dict();var saved_bytes=FileAccess.get_file_as_bytes(fixture+"/save.json");s.fail_writes=true
	await _key(KEY_1 if choice=="open_records" else KEY_2)
	check(s.chapter_two_stage==4 and s.chapter_two_ending==choice and s.coins==int(before.coins)+65,"Explicit nearby choice awards exact65 separately")
	check(app.save_warning and app.exits==0 and FileAccess.get_file_as_bytes(fixture+"/save.json")==saved_bytes,"Failed ending autosave keeps memory and old bytes")
	var complete=s.to_dict();selected.call();stale.call()
	check(s.to_dict()==complete,"Repeated ending callbacks cannot replay reward after save failure")
	s.fail_writes=false;app._autosave();var saved=State.new();saved.fixture=fixture
	check(saved.load_game()==OK and saved.to_dict()==s.to_dict() and not app.save_warning,"Retry writes exactly the chosen ending and all resources")
	await _talk("chapter_host")
	check(not app.modal_actions.is_empty() and s.chapter_two_stage==4,"Completed ending remains an ordinary inn interaction")

func _close_archive()->void:
	_fresh_archive()
	await _talk("chapter_archive");await _key(KEY_1)
	var panel=app.overlay.get_meta("party_battle");panel.art.set_process(false)
	panel.request_command("hero","guard");s.fail_writes=true;panel.request_application_close();_finish(panel);_finish(panel)
	check(not s.battle_active and app.exits==0 and app.save_warning and s.chapter_two_stage==2,"Failed close saves neither false victory nor quit")
	check(s.seal_sequence==[2,0,1] and s.chapter_two_ending.is_empty(),"Close retains actual solved puzzle for retry")
