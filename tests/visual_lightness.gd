extends "res://tests/visual_smoke.gd"
func _run()->void:
	app=Scene.instantiate();app.state=VisualState.new();root.add_child(app)
	await create_timer(0.5).timeout;app._stop_audio();app.audio_on=false
	app._new_game();app.state.quest_stage=6;app.state.ending="守望";app.state.choose_sect("问石门");app.state.gain_xp(600);app.state.recruit_companion()
	app._refresh();app.world.teleport(Vector2(650,720));app.lightness_story.lesson()
	await _capture("64-lightness-lesson")
	app.lightness_story.learn();app.world.teleport(app.state.Lightness.SHORE);app._interact("reed_cross")
	await _capture("65-reed-crossing")
	app.lightness_story.cross(true)
	await _capture("66-reed-islet-landing")
	app._interact("reed_relic")
	await _capture("67-reed-islet-inscription")
	app.lightness_story.discover();app._show_map()
	await _capture("68-reed-islet-map")
	app._close_modal();app._interact("reed_return");app.lightness_story.cross(false)
	await _capture("69-reed-islet-return")
	app._stop_audio();await create_timer(0.25).timeout;app.queue_free();await process_frame
	print("PASS: 6 prepared lightness and islet captures saved")
	quit()
