extends "res://tests/visual_smoke.gd"
func _run() -> void:
	app=Scene.instantiate()
	app.state=VisualState.new()
	root.add_child(app)
	await create_timer(0.5).timeout
	app.music.stop();app.audio_on=false
	app._new_game()
	app.state.level=3;app.state.coins=180
	app.state.buy_equipment()
	app.state.resources={"iron":3,"timber":1,"cloth":3,"herb":3}
	app._refresh()
	app._show_workshop()
	await _capture("10-workshop")
	app.workshop.trade_page(false)
	await _capture("11-material-market")
	app._close_modal()
	app._stop_audio()
	await create_timer(0.25).timeout
	app.queue_free()
	await process_frame
	print("PASS: 2 rendered economy captures saved to res://screenshots")
	quit()
