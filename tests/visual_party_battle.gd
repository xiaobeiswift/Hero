extends "res://tests/party_battle_ui_test.gd"
## Actual full-game source renderer, prepared late-party state, scripted input.
## No browser/audio/real-time FPS claim. Saves stay in the isolated test profile.
func _run() -> void:
	root.size = Vector2i(1280,800)
	fixture = "user://party-visual-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); app.save_slots.store = Slots.new(fixture)
	await process_frame
	app._stop_audio(); app.audio_on = false; app.world.set_process(false)
	app._new_game()
	for id in ["elder", "herb", "healer", "healer"]:
		await _talk(id); await _key(KEY_1)
	await _talk("bandit"); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle", null)
	assert(panel != null)
	panel.art.set_process(false)
	await capture("298-party-opening-real-recruitment")
	panel.request_command("hero", "attack"); panel.art._process(.38); panel.refresh()
	await capture("299-party-opening-actual-contact")
	_finish(panel); panel.leave(); _finish(panel)
	_prepare(4, "heting_receipt"); s.hp -= 24
	app.world.teleport(app.world.interactables.heting_scale.pos + Vector2(0,24)); app._process(0)
	app.receipt_story.open(); await _key(KEY_1)
	panel = app.overlay.get_meta("party_battle", null); assert(panel != null); panel.art.set_process(false)
	await capture("300-party-four-live-ready")
	root.size = Vector2i(1179,737)
	await capture("301-party-four-live-compact")
	root.size = Vector2i(1280,800)
	await _click(panel.commands.actor_buttons.qin); await _key(KEY_2)
	await capture("302-party-qin-choose-ally")
	panel.select_target("hero"); panel.art._process(.38); panel.refresh()
	await capture("303-party-qin-protection-contact")
	_finish(panel)
	panel.request_command("shen", "art:shen_xumai"); panel.select_target("hero"); panel.art._process(.38); panel.refresh()
	await capture("304-party-shen-healing-contact")
	_finish(panel)
	panel.request_command("hero", "attack"); _finish(panel)
	panel.request_command("tang", "guard"); panel.art._process(1.30); panel.refresh()
	await capture("305-party-enemy-actual-phase")
	_finish(panel); panel.leave(); _finish(panel)
	if app.active_modal: app._close_modal()
	app._show_party_roster()
	await capture("306-party-four-roster")
	app._stop_audio(); app.queue_free(); await process_frame
	assert(failures == 0, "Capture input assertions failed")
	print("PASS: nine full-game party captures; natural opening recruitment, prepared late four-person state, real controls and accepted motion facts")
	quit()

func capture(name: String) -> void:
	app._refresh(); app.toast_time = 0; app.hud.quest_notice_time = 0; app.hud.tick(0)
	await create_timer(.22).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/" + name + ".png") == OK)
