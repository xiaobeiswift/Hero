extends "res://tests/visual_heting_chapter.gd"
## Prepared loadout, actual E/Tab/numeric input, accepted action poses.
var panel
func run() -> void:
	root.size=Vector2i(1280,800)
	app=Scene.instantiate(); app.state=NoSave.new(); app.view_preferences=NoWritePrefs.new()
	root.add_child(app); await process_frame; app._new_game(); app._stop_audio(); app.audio_on=false
	app.state.gain_xp(250); app.state.choose_sect("听潮阁"); app.state.equip_art(app.state.sect_art())
	app.world.teleport(Vector2(725,782)); app._process(0); app._refresh()
	await capture("264-courtyard-practice-entry")
	assert(app.world.nearby_id=="courtyard_practice")
	await key(KEY_E); panel=app.overlay.get_meta("courtyard_practice"); panel.art.set_process(false)
	await capture("265-courtyard-two-target-ready")
	await key(KEY_TAB); assert(panel.rules.selected_id=="bracer")
	await capture("266-courtyard-bracer-selected")
	await key(KEY_2); panel.art._process(.34)
	await capture("267-courtyard-skill-contact")
	panel.art._process(3.0)
	await key(KEY_3); panel.art._process(.90)
	await capture("268-courtyard-guard-counter")
	panel.art._process(3.0)
	var limit=0
	while panel.rules.active and panel.rules.units[1].hp>0 and limit<20:
		await key(KEY_4 if panel.rules.hp<50 and panel.rules.medicine>0 else KEY_1)
		panel.art._process(3.0); limit+=1
	assert(panel.rules.units[1].hp==0 and panel.rules.selected_id=="striker")
	await capture("269-courtyard-auto-retarget")
	while panel.rules.active and limit<45:
		await key(KEY_4 if panel.rules.hp<50 and panel.rules.medicine>0 else KEY_1)
		panel.art._process(3.0); limit+=1
	assert(panel.rules.outcome=="win")
	await capture("270-courtyard-practice-complete")
	await key(KEY_ESCAPE)
	app.state.companion_unlocked=true; app.state.active_companion="沈青"
	root.size=Vector2i(1180,737); app._interact("courtyard_practice");panel=app.overlay.get_meta("courtyard_practice");panel.art.set_process(false)
	await capture("271-courtyard-compact-companion")
	app._stop_audio(); app.queue_free(); await create_timer(.25).timeout
	print("PASS: eight actual-engine courtyard captures, actual E/Tab/numeric inputs and accepted practice outcomes"); quit()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	await process_frame; event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
