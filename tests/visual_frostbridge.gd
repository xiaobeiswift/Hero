extends "res://tests/visual_smoke.gd"
func _run() -> void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
	await create_timer(0.5).timeout
	app.music.stop();app.audio_on=false;app._new_game()
	app.state.quest_stage=6;app.state.side_stage=3;app.state.side_choice="rescue";app.state.side_reward_claimed=true
	app.state.gain_xp(180);app.state.choose_sect("听潮阁");app.state.recruit_companion()
	app.chapter_story.enter_region()
	app.world.teleport(Vector2(560,410))
	await create_timer(0.3).timeout
	await _capture("12-frostbridge-town")
	app.world.teleport(Vector2(670,775))
	await create_timer(0.2).timeout
	await _capture("13-broken-south-bridge")
	app.state.resources.timber=2;app.chapter_story.repair()
	await _capture("14-repaired-south-bridge")
	app._show_map();await _capture("15-frostbridge-map");app._close_modal()
	app.state.add_archive_clue("clerk");app.state.add_archive_clue("inscription")
	app.chapter_story.archive();await _capture("16-three-seal-puzzle");app._close_modal()
	app.state.try_seal(2);app.state.try_seal(0);app.state.try_seal(1)
	app._start_battle("archive_boss");await _capture("17-archive-battle")
	for turn in range(60):
		if not app.state.battle_active:break
		if app.state.hp<50 and app.state.medicine>0:app._battle_action("item")
		elif app.state.turn%2==1:app._battle_action("guard")
		elif app.state.qi>=app.state.active_art_cost() and app.state.skill_cooldown==0:app._battle_action("skill")
		else:app._battle_action("attack")
	app._close_modal();app._refresh();app.chapter_story.innkeeper()
	await _capture("18-archive-ending-choice")
	app._close_modal();app._stop_audio();await create_timer(0.25).timeout
	app.queue_free();await process_frame
	print("PASS: 7 rendered Frostbridge captures saved to res://screenshots")
	quit()
