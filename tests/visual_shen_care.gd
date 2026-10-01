extends "res://tests/visual_smoke.gd"
func _prepare()->void:
	app._new_game();app.state.quest_stage=6;app.state.ending="守望";app.state.choose_sect("听潮阁");app.state.gain_xp(600);app.state.recruit_companion()
	app.state.side_stage=3;app.state.side_choice="pursuit";app.state.side_reward_claimed=true;app.state.side_clues=2;app.state.side_found.assign(["boatman","ledger"])
	app.state.chapter_two_stage=4;app.state.chapter_two_ending="protect_witness";app.state.bridge_repaired=true;app.state.archive_clues.assign(["clerk","inscription"]);app.state.seal_sequence.assign([2,0,1])
	app._travel("qingwei",Vector2(330,365));app._refresh()
func _run()->void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
	await create_timer(0.5).timeout;app._stop_audio();app.audio_on=false
	_prepare();app._interact("healer");app.shen_story.pharmacy()
	await _capture("56-shen-personal-story")
	app.shen_story.begin();app._travel("sluice",Vector2(560,790));app._interact("stranded_boatman")
	await _capture("57-shen-pursuit-consultation")
	app.shen_story.consult();app.state.begin_tangqi_quest();app.world.teleport(Vector2(570,350));app._interact("sluice_cache")
	await _capture("58-two-stories-shared-shelter")
	app.shen_story.inspect();app._travel("qingwei",Vector2(330,365));app.shen_story.pharmacy()
	await _capture("59-shen-care-choice")
	app.shen_story.choose("shore");app._close_modal();app.world.teleport(Vector2(720,480));app._interact("board")
	await _capture("60-shore-care-commitment")
	app.shen_story.post();app._close_modal();app._travel("sluice",Vector2(560,790));app._interact("stranded_boatman")
	await _capture("61-shore-care-aftermath")
	_prepare();app.state.ending="秉公";app.state.begin_shen_care();app.state.consult_shen_patient();app.state.inspect_shen_shelter();app.state.choose_shen_care("mobile")
	app.world.teleport(Vector2(720,480));app._interact("board")
	await _capture("62-mobile-care-commitment")
	app.shen_story.post();app._close_modal();app.companion_story.roster()
	await _capture("63-shen-care-roster")
	app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
	print("PASS: 8 prepared-scenario Shen care rendered captures saved")
	quit()
