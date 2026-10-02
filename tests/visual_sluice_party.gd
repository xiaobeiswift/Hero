extends "res://tests/party_sluice_ui_test.gd"
## Native full-game prepared chapter completion; true command/target inputs.
## Does not claim an earned playthrough or browser performance/audio coverage.
func _run() -> void:
	root.size = Vector2i(1280,800)
	fixture = "user://sluice-visual-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); app.save_slots.store = Slots.new(fixture)
	await process_frame
	app._stop_audio(); app.audio_on = false; app.world.set_process(false)
	_fresh_sluice()
	await _talk("ledger_runner"); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle"); assert(panel != null); panel.art.set_process(false)
	await capture("307-sluice-party-scout-ready")
	panel.leave(); _finish(panel)
	_fresh_sluice(true,true)
	await _talk("sluice_boss"); await _key(KEY_1)
	panel = app.overlay.get_meta("party_battle"); assert(panel != null); panel.art.set_process(false)
	await capture("308-sluice-party-boss-ready")
	panel.request_command("hero","attack"); _finish(panel)
	panel.request_command("shen","guard"); _finish(panel)
	check(s.party_battle_snapshot().round==2,"Heavy second round is real")
	panel.request_command("hero","attack"); _finish(panel)
	panel.request_command("shen","guard"); panel.art._process(1.30); panel.refresh()
	await capture("309-sluice-party-heavy-contact")
	_finish(panel)
	check(_actor(panel.commands.snapshot,"hero").status.vulnerability_hits==2,"Actual heavy target receives two-hit vulnerability")
	await capture("310-sluice-party-vulnerability")
	panel.request_command("hero","guard"); panel.art._process(.38); panel.refresh()
	check(_actor(panel.commands.snapshot,"hero").status.vulnerability_hits==0,"Accepted own guard clears status at contact")
	await capture("311-sluice-party-guard-clears")
	_finish(panel); root.size=Vector2i(1179,737)
	await capture("312-sluice-party-compact")
	panel.leave(); _finish(panel)
	app._stop_audio(); app.queue_free(); await process_frame
	assert(failures==0,"Prepared real input trace failed")
	print("PASS: six native sluice party captures with real source inputs and exact accepted vulnerability/guard events")
	quit()

func capture(name:String)->void:
	app._refresh(); app.toast_time=0; app.hud.quest_notice_time=0; app.hud.tick(0)
	await create_timer(.22).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
