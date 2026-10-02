extends "res://tests/party_archive_ui_test.gd"
## Prepared prior chapter completion; real E/number entry. Accepted command API
## drives captured motion. Separate input suites cover mouse/focus dispatch.
func _run()->void:
	root.size=Vector2i(1280,800)
	fixture="user://archive-visual-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);app.save_slots.store=Slots.new(fixture)
	await process_frame
	app._stop_audio();app.audio_on=false;app.world.set_process(false)
	_fresh_archive()
	await _talk("chapter_archive");await _key(KEY_1)
	var panel=app.overlay.get_meta("party_battle");panel.art.set_process(false)
	await capture("313-archive-party-protect-rear")
	var rear=panel.art.actor_home("shen")
	panel.leave();_finish(panel)
	check(s.set_formation("并肩"),"Formation changes explicitly outside combat")
	await _talk("chapter_archive");await _key(KEY_1)
	panel=app.overlay.get_meta("party_battle");panel.art.set_process(false)
	check(panel.art.actor_home("shen").distance_to(rear)>60,"Two-person parallel formation visibly advances")
	await capture("314-archive-party-side-by-side")
	panel.request_command("hero","attack");panel.art._process(.38);panel.refresh()
	await capture("315-archive-party-actual-contact")
	_finish(panel);root.size=Vector2i(1179,737)
	await capture("316-archive-party-compact")
	root.size=Vector2i(1280,800)
	panel.request_command("shen","guard");_finish(panel)
	panel.request_command("hero","guard");_finish(panel)
	panel.request_command("shen","attack");panel.art._process(1.30);panel.refresh()
	check(panel.art.selected_id=="shen", "Rotating intent strikes actual parallel companion")
	await capture("319-archive-party-companion-hit")
	_finish(panel)
	_win_archive(panel)
	check(s.chapter_two_stage==3 and s.chapter_two_ending.is_empty(),"Victory leaves the ending undecided")
	await capture("317-archive-party-victory")
	app._close_modal();await _talk("chapter_host")
	await capture("318-archive-party-separate-choice")
	await _key(KEY_ESCAPE)
	app._stop_audio();app.queue_free();await process_frame
	assert(failures==0,"Prepared archive capture assertions failed")
	print("PASS: seven native archive captures; real scene entry, accepted command playback, distinct two-person formations and separate ending")
	quit()

func capture(name:String)->void:
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0;app.hud.tick(0)
	await create_timer(.22).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
