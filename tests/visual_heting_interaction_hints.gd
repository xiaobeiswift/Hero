extends "res://tests/visual_heting_chapter.gd"
## Prepared harbor state, followed by actual E/number/Escape events.
func press(code: int) -> void:
	var event := InputEventKey.new(); event.physical_keycode=code; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event=InputEventKey.new(); event.physical_keycode=code; event.pressed=false
	Input.parse_input_event(event); await process_frame

func run() -> void:
	root.size=Vector2i(1280,800); app=Scene.instantiate(); app.state=NoSave.new(); app.view_preferences=NoWritePrefs.new()
	root.add_child(app); await process_frame; app._new_game(); app._stop_audio(); app.audio_on=false
	var s=app.state
	s.quest_stage=6; s.ending="守望"; s.choose_sect("听潮阁"); s.gain_xp(600)
	s.mist_stage=4; s.mist_ending="warn_ferries"; s.mist_gauges.assign(["rain","stone","basin"])
	s.bridge_repaired=true; s.tangqi_stage=3; s.tangqi_choice="teach"; s.tangqi_unlocked=true; s.active_companion="唐栖"
	assert(s.begin_heting()); app._travel("heting",Vector2(665,620))
	await capture("255-heting-hint-pickup-100")
	assert(app.near_label.text.contains("提货")); await press(KEY_E); await press(KEY_1)
	assert(s.heting_cargo=="meal"); app.view_preferences.zoom_index=1; app._apply_view_zoom()
	await capture("256-heting-hint-manifest-125")
	assert(app.near_label.text.contains("查看货签"))
	app.world.teleport(Vector2(1390,600)); await capture("257-heting-hint-wrong-destination-125")
	assert(app.near_label.text.contains("询问去处"))
	app.world.teleport(Vector2(230,780)); app.view_preferences.zoom_index=2; app._apply_view_zoom(); root.size=Vector2i(1180,737)
	await capture("258-heting-hint-discuss-160-compact")
	assert(app.near_label.text.contains("商议交粮")); var before=s.to_dict(); await press(KEY_E)
	assert(s.to_dict()==before and app.active_modal)
	await capture("259-heting-hint-confirm-compact")
	await press(KEY_ESCAPE); assert(s.to_dict()==before and not app.active_modal)
	app._stop_audio(); app.queue_free(); await create_timer(.25).timeout
	print("PASS: five actual-engine harbor hint captures; E opens choice, Escape keeps loaded cargo"); quit()
