extends "res://tests/weapon_fitting_trial_model_test.gd"
## Genuine State, inherited earned-journey fixture and actual Main/PartyUI.
## Headless input/geometry/lifecycle coverage; native pixel acceptance is separate.
const Main = preload("res://scripts/main.gd")
const RehearsalUI = preload("res://scripts/encounter_rehearsal_ui.gd")
class ProbeMain extends Main:
	var saves: int = 0
	var exits: int = 0
	func _autosave() -> void:
		saves += 1
		super._autosave()
	func _quit_cleanly(_save_progress: bool = true) -> void:
		exits += 1
		quit_pending = true
var app
var completed_source
var ui_results: Array[Dictionary] = []


func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var earned = _earned_capstone("听潮阁", true, true)
	if earned == null: _finish_ui(); return
	var before_liang = earned._detached_persistent_state()
	if not _journey_win(earned, "capstone_authorizer", "rehearsal_ui_actual_unlock"): _finish_ui(); return
	completed_source = earned._detached_persistent_state()
	app = ProbeMain.new(); root.add_child(app); await process_frame
	app._stop_audio(); app.audio_on = false; app.world.set_process(false)
	await _test_earned_cards(before_liang)
	await _test_inputs_and_geometry()
	await _test_interrupted_pages()
	for id: String in ["heting_consignee", "capstone_authorizer"]:
		await _test_terminal_loop(id, "flee")
		await _test_terminal_loop(id, "win")
		await _test_terminal_loop(id, "defeat")
	await _test_save_failure_close()
	for outcome: String in ["win", "defeat", "flee"]:
		await _test_accepted_terminal_close(outcome)
	app._stop_audio(); app.queue_free(); await process_frame
	_finish_ui()


func _prepare_ui(source = null) -> void:
	app.quit_pending = false; app.save_warning = false; app.current_screen = "explore"; app.active_modal = false
	app._clear_overlay(); app._rehearsal_position_hold.clear(); app._fitting_position_hold.clear(); app._journal_position_hold.clear()
	app.state = (completed_source if source == null else source)._detached_persistent_state()
	app.state.map_id = "qingwei"
	app.world.change_map("qingwei", Vector2(420, 450)); app._sync_world_state()
	app.world.teleport(app.world.interactables.courtyard_practice.pos + Vector2(0,24)); app.world.set_process(false)
	app.state.position = Vector2(100,100)
	app.state.hp = 17; app.state.qi = 0; app.state.medicine = 0
	for id: String in app.state.party_resources: app.state.party_resources[id] = {"hp":0,"qi":0}
	check(app.state.save_game() == OK, "Genuine State creates isolated real-journey checkpoint")
	app.state.coins += 1 # Unsaved difference makes accidental autosaving visible.
	app._practice_dialogue()
	app._refresh()


func _folio(): return app.overlay.get_meta("encounter_rehearsal", null)


func _baseline_ui() -> Dictionary:
	return {"state":app.state.to_dict(), "position":app.world.player_pos, "bytes":FileAccess.get_file_as_bytes(State.SAVE_PATH), "saves":app.saves}


func _same_ui(before: Dictionary, message: String) -> void:
	check(app.state.to_dict() == before.state and app.world.player_pos == before.position and app.saves == before.saves and FileAccess.get_file_as_bytes(State.SAVE_PATH) == before.bytes, message)


func _key_ui(code: Key, repeat: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event = InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed; event.echo = repeat and pressed
		Input.parse_input_event(event); await process_frame


func _click_ui(button: Control) -> void:
	check(button != null, "Named native control exists")
	if button == null: return
	var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event = InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		Input.parse_input_event(event); await process_frame


func _texts(node: Node) -> String:
	var text: String = node.text if node is Label or node is Button else ""
	for child: Node in node.get_children(): text += "\n" + _texts(child)
	return text


func _test_earned_cards(before_liang) -> void:
	_prepare_ui(State.new()); var before: Dictionary = _baseline_ui()
	await _key_ui(KEY_4)
	check(_folio() != null and _folio().options.is_empty() and _folio().card_buttons.is_empty(), "Fresh actual journey opens no earned cards")
	check(not _texts(_folio()).contains("杜晦") and not _texts(_folio()).contains("梁缜"), "Locked names and scenarios never appear in folio")
	check(not _folio().action_buttons.has("start"), "Unowned encounter has no start target")
	await _key_ui(KEY_ESCAPE); _same_ui(before, "Empty folio browsing and dismissal preserve state/files")
	_prepare_ui(before_liang); before = _baseline_ui(); await _key_ui(KEY_4)
	check(_folio().card_buttons.keys() == ["heting_consignee"] and not _texts(_folio()).contains("梁缜"), "Genuine pre-Liang stage has only earned Du Hui card")
	var old = _folio(); old.choose("capstone_authorizer")
	check(_folio() == old and not app.state.battle_active, "Calling hidden card cannot forge earned entry")
	await _key_ui(KEY_ESCAPE); _same_ui(before, "Rejected hidden card and close never save")
	_prepare_ui(); before = _baseline_ui(); await _key_ui(KEY_4)
	check(_folio().card_buttons.size() == 2 and _folio().metadata.team.actors.size() == app.state.party_roster.size(), "Both genuine victories expose two cards and exact selected party")
	check(_texts(_folio()).contains("当前等级") and _texts(_folio()).contains("不还原当年等级") and _texts(_folio()).contains("不发奖励"), "Ordinary player text accurately scopes present-day borrowed rehearsal")
	for extent: Vector2 in [Vector2(1280,800),Vector2(1179,737)]:
		var full_page = _folio(); full_page.size = extent; full_page._layout()
		await process_frame; await process_frame
		check(full_page.scroll.scroll_vertical == 0,"Initial four-person preview remains at the top")
		for actor: Dictionary in full_page.metadata.team.actors:
			var row: Control = full_page.content.get_node("RehearsalActor_" + String(actor.id))
			check(full_page.scroll.get_global_rect().encloses(row.get_global_rect()),"Complete initially selected party row fits reading viewport: " + String(actor.id) + "/" + str(extent))
		_check_reading_geometry(full_page)
	await _key_ui(KEY_ESCAPE); _same_ui(before, "Earned preview remains write-free")


func _test_inputs_and_geometry() -> void:
	_prepare_ui()
	check(app.state.set_party_roster(["hero","qin","shen"]) and app.state.set_formation("护后"), "Actual three-person chosen order and formation")
	app._practice_dialogue(); var before: Dictionary = _baseline_ui()
	await _key_ui(KEY_4)
	var page = _folio(); var ids: Array = []
	for actor: Dictionary in page.metadata.team.actors: ids.append(actor.id)
	check(ids == ["hero","qin","shen"] and page.metadata.team.formation == "护后" and not _texts(page.content).contains("唐栖"), "Benched recruit omitted; selected order is exact")
	check(page.action_buttons.close.has_focus(), "Safe native initial focus is return, not accidental start")
	await _key_ui(KEY_2); page = _folio()
	check(page.encounter_id == "capstone_authorizer" and page.card_buttons.capstone_authorizer.has_focus(), "Native key2 selects only the second earned card")
	await _key_ui(KEY_1, true)
	check(_folio() == page, "Repeated key echoes cannot rebuild or start")
	await _key_ui(KEY_TAB)
	check(root.gui_get_focus_owner() != null, "Native Tab retains keyboard focus")
	await _click_ui(page.card_buttons.heting_consignee); page = _folio()
	check(page.encounter_id == "heting_consignee", "Pointer changes selected earned card")
	for extent: Vector2 in [Vector2(1280,800), Vector2(1179,737)]:
		page.size = extent; page._layout(); await process_frame
		check(Rect2(Vector2.ZERO,extent).encloses(page.frame.get_rect()), "Complete folio including footer fits " + str(extent))
		for name: String in ["RehearsalClose","RehearsalStart","RehearsalBack","RehearsalContentScroll","RehearsalFooterNotice","RehearsalKeyboardHelp","RehearsalKeyboardBacking"]:
			var control: Control = page.frame.get_node(name)
			check(Rect2(Vector2.ZERO,page.frame.size).encloses(control.get_rect()), "Folio control stays bounded: " + name)
		check(not page.scroll.get_rect().intersects(page.action_buttons.start.get_rect()) and not page.footer_notice.get_rect().intersects(page.action_buttons.start.get_rect()), "Reading region and fixed footer do not overlap")
		check(page.action_buttons.start.size.y >= 44 and page.action_buttons.back.size.y >= 44, "Native actions preserve readable click targets")
		check(page.scroll.get_v_scroll_bar().max_value > page.scroll.get_v_scroll_bar().page, "Compact team details have a usable scrolling region")
		_check_reading_geometry(page)
	page.size = Vector2(1280,800); page._layout()
	await _key_ui(KEY_F5); _same_ui(before, "F5 in read-only folio cannot autosave")
	page.action_buttons.close.grab_focus(); await _key_ui(KEY_ENTER)
	check(not app.active_modal and not app.state.battle_active, "Focused native Enter closes once without first-choice fallback")
	_same_ui(before, "Native card/Tab/Enter browsing preserves real resources and save bytes")
	app.world.player_pos += Vector2(1,0); await process_frame
	check(app.state.position == app.world.player_pos and app._rehearsal_position_hold.is_empty(), "Actual movement after dismissal resumes position synchronization")


func _check_reading_geometry(page) -> void:
	var help: Control = page.frame.get_node("RehearsalKeyboardHelp")
	var backing: Control = page.frame.get_node("RehearsalKeyboardBacking")
	var book: Control = page.frame.get_node("FolioDecorativeBacking")
	check(book.get_rect().encloses(backing.get_rect()) and backing.get_rect().encloses(help.get_rect()),"Keyboard help has its own backing wholly inside the book")
	check(help.size.y <= 28 and not help.get_rect().intersects(page.footer_notice.get_rect()),"Keyboard help shrinks after wrapping and stays separate from footer notice")
	var ink_right: float = page.scroll.get_global_rect().end.x - page.scroll.get_v_scroll_bar().size.x - 8
	for child: Node in page.content.get_children():
		if child is Label:
			check(child.get_global_rect().end.x <= ink_right,"Wrapped reading ink reserves scrollbar gutter: " + String(child.name))
			check(child.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY,"Long folio prose actually wraps within its assigned width: " + String(child.name))


func _test_interrupted_pages() -> void:
	_prepare_ui(); await _key_ui(KEY_4)
	var stale = _folio(); var before: Dictionary = _baseline_ui()
	stale.close(); stale.start(); stale.choose("capstone_authorizer"); stale.close()
	check(not app.state.battle_active and not app.active_modal, "Close immediately invalidates same-frame start/selection/close callbacks")
	_same_ui(before, "Stale closed callbacks cannot mutate or save")
	RehearsalUI.open(app); stale = _folio()
	app.state.set_formation("并肩" if app.state.formation == "护后" else "护后")
	var changed: Dictionary = app.state.to_dict(); stale.start()
	check(not app.state.battle_active and app.state.to_dict() == changed, "Changed real configuration invalidates prepared start without undoing change")
	stale.close(); check(not app.active_modal, "Invalidated folio still permits safe return")
	RehearsalUI.open(app); stale = _folio(); before = _baseline_ui()
	app.world.teleport(app.world.interactables.courtyard_practice.pos + Vector2(100,0))
	stale.start(); check(not app.state.battle_active, "Actual world proximity is rechecked at start")
	stale.close(); app.world.teleport(before.position)
	check(RehearsalUI.open(app) != null, "Returning to actual courtyard can open fresh page")
	stale = _folio(); app.modal_generation += 1; stale.start()
	check(not app.state.battle_active, "Stale host generation rejects start")
	app._close_modal()


func _finish_ui_action(panel) -> void:
	if is_instance_valid(panel) and panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration() + .2)


func _battle_ui():
	var panel = app.overlay.get_meta("party_battle", null)
	if panel != null: panel.set_process(false); panel.art.set_process(false)
	return panel


func _test_terminal_loop(id: String, desired: String) -> void:
	_prepare_ui()
	if desired == "defeat":
		check(app.state.set_party_roster(["hero"]), "Defeat fixture chooses actual solo roster")
		app.state.attack = 1; app.state.defense = 0 # Explicit weak UI fixture, not earned progression evidence.
	elif desired == "win":
		check(app.state.set_party_roster(["hero","qin","tang","shen"]), "Win fixture chooses actual four-person party")
		app.state.attack = 100; app.state.defense = 100 # Deterministic UI terminal fixture; model balance tested separately.
	RehearsalUI.open(app, id); var before: Dictionary = _baseline_ui(); var old_page = _folio()
	old_page.start(); old_page.start()
	var panel = _battle_ui()
	check(panel != null and panel.encounter == id and not panel.rehearsal_metadata.is_empty(), "Exactly one detached rehearsal controller starts " + id)
	if panel == null: return
	var first_epoch: int = app.state.party_battle_epoch
	check(app.state.party_battle_snapshot().resource_policy == "encounter_rehearsal", "Original encounter uses explicit virtual resource policy")
	var badge = panel.find_child("RehearsalBattleBadge", true, false)
	check(badge != null and badge.text.contains("无奖励") and badge.get_rect().end.y <= 20, "Unmistakable virtual badge occupies reserved header strip")
	for actor: Dictionary in app.state.party_battle_snapshot().actors:
		check(actor.hp == actor.max_hp and actor.qi == actor.max_qi and actor.categories.size() == 3, "Every selected actor has virtual full resources and three fixed skill slots")
	var event_loss: int = 0; var used: int = 0; var attacks: int = 0; var rounds: int = 0; var steps: int = 0
	if desired == "flee": panel.leave()
	while app.current_screen == "party_battle" and steps < 500:
		if panel.pending.is_empty(): panel._process(1.0)
		if not panel.pending.is_empty():
			var tx: Dictionary = panel.pending
			for actor: Dictionary in tx.before.actors: event_loss += maxi(0, int(actor.hp) - int(_actor(tx.after, actor.id).hp))
			used += int(tx.before.medicine) - int(tx.after.medicine)
			for event: Dictionary in tx.events:
				if event.type == "action" and event.get("action_id", "") == "enemy:attack": attacks += 1
				if event.type == "round_end": rounds += 1
			var pending_epoch: int = tx.epoch; var pending_token: int = tx.token
			_finish_ui_action(panel)
			check(not app.state.finish_party_presentation(pending_epoch,pending_token).get("accepted",false), "Repeated acknowledgement cannot settle a second time")
		_same_ui(before, "Every actual accepted/replayed UI action leaves real state/world/files exact")
		steps += 1
	check(_folio() != null and _folio().page == "results", "Actual terminal routes directly to rehearsal debrief " + desired)
	if _folio() == null: return
	var page = _folio(); var latest: Dictionary = page.result_rows[-1]
	check(latest.metrics.outcome == desired, "Debrief truthfully reports actual terminal " + desired)
	check(latest.metrics.total_actual_hp_lost == event_loss and latest.metrics.medicine_used == used and latest.metrics.enemy_attacks_executed == attacks and latest.metrics.completed_rounds == rounds, "Debrief numbers match independently counted accepted UI events")
	check(_texts(page).contains("完整回合") and _texts(page).contains("结束于第"), "Completed and terminal rounds have distinct visible labels")
	panel._return_to_world(app.state.party_settlement); panel._finished()
	check(_folio() == page and page.result_rows.size() == 1, "Repeated old return and finish callbacks cannot replace or duplicate debrief")
	page.start(); page.start(); panel = _battle_ui()
	check(panel != null and app.state.party_battle_epoch != first_epoch, "Same-condition explicit retry creates exactly one fresh epoch")
	panel.leave(); _finish_ui_action(panel)
	check(_folio().result_rows.size() == 2 and _folio().result_rows[0].metadata.comparison_key == _folio().result_rows[1].metadata.comparison_key, "Only two identical-condition results compare")
	_folio().start(); panel = _battle_ui(); panel.leave(); _finish_ui_action(panel)
	check(_folio().result_rows.size() == 2, "Third retry evicts older result without growing history")
	await process_frame; await process_frame
	_check_reading_geometry(_folio())
	for name: String in ["RehearsalMetricsMeaning","RehearsalComparisonScope"]:
		var explanation: Label = _folio().content.get_node(name)
		check(explanation.get_line_count() >= 2,"Full safety explanation wraps to multiple lines: " + name)
	_same_ui(before, "Repeated debrief and retry never autosave, move, heal or reward real journey")
	ui_results.append({"encounter":id,"outcome":desired,"metrics":latest.metrics})
	await _key_ui(KEY_ESCAPE)
	check(_folio() != null and _folio().page == "preview", "Debrief Escape returns to exact selected configuration preview")
	await _key_ui(KEY_ESCAPE); _same_ui(before, "Second Escape returns to courtyard without saving")


func _test_save_failure_close() -> void:
	_prepare_ui(); RehearsalUI.open(app, "heting_consignee"); var before: Dictionary = _baseline_ui()
	_folio().start(); var panel = _battle_ui(); panel._process(1.0)
	check(DirAccess.make_dir_absolute(State.SAVE_PATH + ".tmp") == OK, "Inject owned isolated save failure")
	var exits: int = app.exits
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST); app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_finish_ui_action(panel); _finish_ui_action(panel)
	check(app.exits == exits and app.save_warning and not app.state.battle_active, "Application close waits for action, discards only virtual battle and retains failed save in game")
	check(FileAccess.get_file_as_bytes(State.SAVE_PATH) == before.bytes, "Failed close preserves last good real checkpoint bytes")
	var expected: Dictionary = before.state.duplicate(true); expected.position = {"x":before.position.x,"y":before.position.y}
	check(app.state.to_dict() == expected, "Only explicit close synchronizes real location; virtual values never leak")
	var stale_retry: Callable = app.modal_actions[0]
	await _key_ui(KEY_2); stale_retry.call()
	check(app.exits == exits and app.active_modal, "Returning from save failure cancels stale retry")
	check(DirAccess.remove_absolute(State.SAVE_PATH + ".tmp") == OK, "Remove only test-created empty failure blocker")
	app._close_modal(); RehearsalUI.open(app, "heting_consignee"); _folio().start(); panel = _battle_ui()
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST); _finish_ui_action(panel); _finish_ui_action(panel)
	check(app.exits == exits + 1 and not app.save_warning and not app.state.battle_active, "Successful explicit close exits once after saving only real journey")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(State.SAVE_PATH)).player
	check(saved == JSON.parse_string(JSON.stringify(app.state.to_dict())), "Written close checkpoint exactly matches real persistent state")


func _test_accepted_terminal_close(outcome: String) -> void:
	_prepare_ui()
	var id: String = "capstone_authorizer" if outcome == "defeat" else "heting_consignee"
	if outcome == "defeat":
		check(app.state.set_party_roster(["hero"]), "Terminal-close defeat uses chosen solo party")
		app.state.attack = 1; app.state.defense = 0 # Deterministic lifecycle fixture, not balance evidence.
	elif outcome == "win":
		check(app.state.set_party_roster(["hero","qin","tang","shen"]), "Terminal-close win uses chosen four-person party")
		app.state.attack = 100; app.state.defense = 100
	RehearsalUI.open(app, id); var before: Dictionary = _baseline_ui()
	_folio().start(); var panel = _battle_ui()
	check(panel != null, "Accepted-terminal close has actual controller")
	if panel == null: return
	if outcome == "flee": panel.leave()
	var steps: int = 0
	while steps < 500:
		if panel.pending.is_empty(): panel._process(1.0)
		if not panel.pending.is_empty() and not panel.pending.after.active: break
		_finish_ui_action(panel); steps += 1
	check(not panel.pending.is_empty() and not panel.pending.after.active and panel.pending.after.outcome == outcome, "Actual accepted " + outcome + " is held before final presentation acknowledgement")
	if panel.pending.is_empty() or panel.pending.after.active: return
	var terminal: Dictionary = panel.pending.duplicate(true)
	var metrics: Dictionary = app.state.party_session.rehearsal_snapshot().metrics
	check(app.state.battle_active and panel.art.is_presenting() and app.state.rehearsal_comparison_snapshot().results.is_empty(), "Pending terminal remains live and has no debrief record yet")
	check(DirAccess.make_dir_absolute(State.SAVE_PATH + ".tmp") == OK, "Inject actual filesystem failure before accepted-terminal close")
	var exits: int = app.exits
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST); app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(panel.close_pending and panel.pending == terminal and app.state.party_session.rehearsal_snapshot().metrics == metrics, "Repeated close preserves accepted terminal and appends no flee/action/metrics")
	_same_ui(before, "Accepted terminal awaiting close still leaves real journey and old save untouched")
	_finish_ui_action(panel)
	panel._finished(); panel._return_to_world(app.state.party_settlement); panel.request_application_close()
	check(not app.state.finish_party_presentation(int(terminal.epoch), int(terminal.token)).get("accepted", false), "Old terminal token cannot settle twice after close")
	var history: Dictionary = app.state.rehearsal_comparison_snapshot()
	check(history.results.size() == 1 and history.results[0].metrics == metrics and history.results[0].metrics.outcome == outcome, "Close acknowledges exactly one original terminal result without appended retreat")
	check(app.state.party_settlement.outcome == outcome and app.state.party_settlement.rehearsal and not app.state.party_settlement.awarded and app.state.party_settlement.reward_xp == 0 and app.state.party_settlement.coin_change == 0, "Accepted-terminal close preserves outcome and never awards real reward")
	check(app.exits == exits and app.save_warning and not app.quit_pending and not app.state.battle_active, "Failed accepted-terminal close remains in game exactly once")
	var expected: Dictionary = before.state.duplicate(true); expected.position = {"x":before.position.x,"y":before.position.y}
	check(app.state.to_dict() == expected and app.world.player_pos == before.position and app.saves == before.saves, "Only explicit save-and-exit synchronizes real position; no world, resource or autosave effect")
	check(FileAccess.get_file_as_bytes(State.SAVE_PATH) == before.bytes, "Actual failed accepted-terminal save preserves last good bytes")
	var stale_retry: Callable = app.modal_actions[0]
	var blocker_removed: bool = false
	if outcome == "flee":
		var stale_discard: Callable = app.modal_actions[2]
		await _key_ui(KEY_3)
		check(app.exits == exits and not app.quit_pending and app.active_modal and _texts(app.overlay).contains("确认不保存离开"), "Failed-close discard requires its separate explicit confirmation")
		stale_retry.call(); stale_discard.call()
		check(app.exits == exits and FileAccess.get_file_as_bytes(State.SAVE_PATH) == before.bytes, "Stale failed-close controls cannot skip confirmation or rewrite old save")
		var final_discard: Callable = app.modal_actions[1]
		await _key_ui(KEY_2); final_discard.call(); stale_retry.call()
		check(app.exits == exits + 1 and app.quit_pending and app.state.to_dict() == expected, "Explicit confirmed discard exits once with no virtual state leakage")
		check(FileAccess.get_file_as_bytes(State.SAVE_PATH) == before.bytes and app.state.rehearsal_comparison_snapshot().results.size() == 1, "Confirmed discard preserves old checkpoint and does not add another result")
	elif outcome == "win":
		check(DirAccess.remove_absolute(State.SAVE_PATH + ".tmp") == OK, "Recover storage for the same settled terminal, without a new rehearsal")
		blocker_removed = true
		stale_retry.call()
		check(app.exits == exits + 1 and app.quit_pending and not app.save_warning, "Same failed-close retry saves and exits exactly once")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(State.SAVE_PATH)).player
		check(saved == JSON.parse_string(JSON.stringify(expected)) and app.state.to_dict() == expected, "Same-terminal retry writes exact real persistent bytes, never virtual resources")
		var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(State.SAVE_PATH)
		stale_retry.call(); panel._finished(); panel._return_to_world(app.state.party_settlement); panel.request_application_close()
		var retried: Dictionary = app.state.rehearsal_comparison_snapshot()
		check(app.exits == exits + 1 and retried.results.size() == 1 and retried.results[0].metrics == metrics and app.state.party_settlement.outcome == outcome, "Successful same-terminal retry and duplicate callbacks preserve original metrics, outcome and one result")
		check(FileAccess.get_file_as_bytes(State.SAVE_PATH) == saved_bytes and app.state.to_dict() == expected, "Duplicate old retry/terminal callbacks cannot write or mutate after successful exit")
	else:
		await _key_ui(KEY_2); stale_retry.call()
		check(app.exits == exits and not app.quit_pending and app.active_modal and app.overlay.get_meta("pause_menu", false), "Cancel accepted-terminal failed close safely returns to pause and invalidates old retry")
		app._close_modal()
	if not blocker_removed: check(DirAccess.remove_absolute(State.SAVE_PATH + ".tmp") == OK, "Remove only this accepted-terminal test's empty failure blocker")
	ui_results.append({"case":"accepted_terminal_close","encounter":id,"outcome":outcome,"metrics":metrics,"discard_confirmed":outcome == "flee","same_terminal_retry":outcome == "win"})


func _finish_ui() -> void:
	var report: Dictionary = {"checks":checks,"failures":failures,"cases":ui_results,"scope":"headless source UI/lifecycle; no native pixel or package claim"}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var output = FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE)
			if output != null: output.store_string(JSON.stringify(report,"\t"))
	print("%s: %d earned rehearsal UI/lifecycle checks" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
