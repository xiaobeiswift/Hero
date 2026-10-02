extends "res://tests/audit_heting_current_test.gd"
## Deterministic clock, real scene/input and test-owned filesystem failures.
## Only the final OS exit is intercepted; close requests use the real handler.

func _run() -> void:
	fixture = "user://heting-notice-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create isolated notice fixture")
	store = Slots.new(fixture)
	state_probe = RoutedState.new(); state_probe.directory = fixture
	game = CloseProbe.new(); game.state = state_probe
	root.add_child(game); game.save_slots.store = store
	await process_frame
	game.set_process(false); game.world.set_process(false)
	game._stop_audio(); game.audio_on = false
	await _routine_feedback()
	await _interruptions_and_instructions()
	await _failure_feedback()
	# Same real file-failure/close guards as the current harbor acceptance suite.
	await _loaded_exit_guards()
	for path in state_probe.accessed:
		_check(path.begins_with(fixture + "/"), "All I/O belongs to this test")
	_check(not FileAccess.file_exists(Model.SAVE_PATH), "Normal player autosave untouched")
	game._stop_audio(); game.queue_free(); await process_frame
	_remove_fixture(fixture)
	_check(not DirAccess.dir_exists_absolute(fixture), "Remove only owned failure fixtures")
	if failures == 0: print("PASS: %d harbor notice timing/save/close checks" % checks)
	else: push_error("FAIL: %d of %d harbor notice timing/save/close checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _brief(message: String) -> void:
	game._process(0)
	_check(is_equal_approx(game.toast_time, 3.0) and game.status_label.text.contains(message), "Successful action starts three-second notice: " + message)
	_check(game.hud.toast_wash.visible and is_equal_approx(game.hud.toast_wash.modulate.a, 1.0), "Success is initially fully readable")
	game._process(2.5)
	_check(game.hud.toast_wash.visible and is_equal_approx(game.hud.toast_wash.modulate.a, .5), "Success fades during final second")
	game._process(.51)
	_check(not game.hud.toast_wash.visible and game.toast_time <= 0, "Success clears after three seconds")

func _routine_feedback() -> void:
	_port(1, "", "", "west")
	await _talk("heting_cargo"); _press("押开锅粮")
	_check(state_probe.heting_cargo == "meal", "Take succeeds through actual choice")
	_brief("已押开锅粮")
	await _talk("heting_cargo"); _press("退车归位")
	_check(state_probe.heting_cargo.is_empty(), "Park succeeds through actual choice")
	_brief("退回原位")
	await _talk("heting_winch"); _press("改接东岸")
	_check(state_probe.heting_bridge == "east", "Winch succeeds through actual choice")
	_brief("浮栈已接往东岸")
	state_probe.hp = 1; state_probe.qi = 0
	await _talk("heting_relief"); _press("借棚调息")
	_check(state_probe.hp == state_probe.max_hp and state_probe.qi == state_probe.max_qi, "Rest restores actual resources")
	_brief("棚下调息")
	# A newly successful action gets a fresh clock; it does not inherit the fade.
	await _talk("heting_winch"); _press("改接西岸"); game._process(2.8)
	await _talk("heting_winch"); _press("改接东岸")
	_check(is_equal_approx(game.toast_time, 3.0), "Repeated distinct success resets duration")
	_brief("浮栈已接往东岸")

func _interruptions_and_instructions() -> void:
	await _talk("heting_cargo"); _press("押对秤封粮")
	game._process(1.0)
	await _talk("heting_winch")
	var stale: Callable = game.modal_actions[0]
	game._process(0)
	_check(not game.hud.toast_wash.visible, "Modal hides an in-flight success notice")
	await _key(KEY_ESCAPE); game._process(0)
	_check(game.hud.toast_wash.visible and is_equal_approx(game.toast_time, 2.0), "Quick cancel returns only the remaining notice time")
	await _talk("heting_winch"); game._process(2.1)
	await _key(KEY_ESCAPE); game._process(0)
	var before: Dictionary = state_probe.to_dict()
	var writes: int = state_probe.writes
	stale.call(); game._process(0)
	_check(not game.hud.toast_wash.visible and state_probe.to_dict() == before and state_probe.writes == writes, "Expired or canceled page cannot revive notice, change bridge or save")
	# The actual loaded-pier restriction is a signal, not a fabricated toast.
	game.world.teleport(Vector2(805,425)); game._process(0)
	Input.action_press("move_down")
	for i in range(10): game.world._process(.05)
	Input.action_release("move_down"); game._process(0)
	_check(game.status_label.text.contains("步栈") and is_equal_approx(game.toast_time, 7.0), "Loaded-pier guidance retains full seven seconds")
	game._process(3.1)
	_check(game.hud.toast_wash.visible and is_equal_approx(game.hud.toast_wash.modulate.a, 1.0), "Blocked-route guidance remains readable beyond short success duration")
	game._process(4.0)
	_check(not game.hud.toast_wash.visible, "Non-save guidance expires normally")
	game._toast("沿北街绕行，或去绞缆机改泊。")
	_check(is_equal_approx(game.toast_time, 7.0), "Existing callers keep the seven-second default")
	# Invalidated final cargo/plan is guidance too, not successful routine work.
	_port(3, "reserve", "open_scale", "east")
	game.world.teleport(game.world.interactables.heting_scale.pos)
	game.heting_story.finish("heting_scale", "short_ferries")
	_check(game.status_label.text.contains("重新核对") and is_equal_approx(game.toast_time, 7.0), "Changed cargo/plan warning retains full duration")

func _failure_feedback() -> void:
	_port(1, "", "", "west")
	await _talk("heting_winch"); game._save()
	var saved: PackedByteArray = _bytes(store.path_for(0))
	_block_autosave(); _press("改接东岸"); game._process(0)
	_check(state_probe.heting_bridge == "east" and game.save_warning, "Successful mutation can coexist with a real write failure")
	_check(game.status_label.text.contains("浮栈") and game.status_label.text.count("存档失败") == 1 and game.status_label.text.count("F5") == 1, "Success preserves one clear recovery warning")
	_check(is_equal_approx(game.toast_time, 7.0), "Short success cannot shorten unresolved save warning")
	game._process(3.2)
	_check(game.hud.toast_wash.visible and is_equal_approx(game.hud.toast_wash.modulate.a, 1.0), "Failure stays opaque past three seconds")
	game._process(4.0)
	_check(game.hud.toast_wash.visible and game.status_label.text.contains("F5") and is_equal_approx(game.hud.toast_wash.modulate.a, 1.0), "Failure persists after its normal timer")
	_check(_bytes(store.path_for(0)) == saved, "Failed save preserves pre-existing bytes")
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(game.exits == 0 and not game.quit_pending and game.active_modal, "Window-close still stays open on actual write failure")
	_press("返回小憩"); await _key(KEY_ESCAPE); game._process(0)
	_check(game.save_warning and game.hud.toast_wash.visible and state_probe.heting_bridge == "east", "Cancel close retains unsaved mutation and persistent warning")
	_unblock_autosave(); await _key(KEY_F5); game._process(0)
	_check(not game.save_warning and is_equal_approx(game.toast_time, 7.0) and _saved_state() == state_probe.to_dict(), "Successful explicit retry saves state and keeps normal save confirmation")
	await _talk("heting_winch"); _press("改接西岸")
	_brief("浮栈已接往西岸")
