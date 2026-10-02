extends "res://tests/party_battle_ui_test.gd"
## Real scene entry, input and event presentation, with isolated prepared
## chapter-one completion. No early Tang/Qin recruitment is fabricated.
var shown_vulnerability: Array = []
func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture = "user://sluice-ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); app.save_slots.store = Slots.new(fixture)
	await process_frame
	app._stop_audio(); app.audio_on = false; app.world.set_process(false)
	await _guarded_entries()
	await _actor_round()
	await _vulnerability_presentation()
	await _saved_close()
	app._stop_audio(); app.queue_free(); await process_frame
	check(not FileAccess.file_exists(Model.SAVE_PATH), "No normal profile touched")
	print("%s: %d sluice full-game entry/input/presentation checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _fresh_sluice(ally: bool = true, boss: bool = false) -> void:
	app.quit_pending = false; app.exits = 0; s.fail_writes = false
	app.current_screen = "explore"; app.active_modal = false; app._clear_overlay()
	s.reset_game(); s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁"); s.gain_xp(180)
	if ally: check(s.recruit_companion(), "Only naturally available Shen may join this chapter")
	s.formation = "护后"; s.heal_rest(); s.map_id = "sluice"
	app.world.change_map("sluice", Vector2(190,520)); s.position = app.world.player_pos
	if boss:
		check(s.choose_side_route("rescue"), "Prepared valid rescue route")
		s.find_side_clue("boatman"); s.find_side_clue("ledger")
	app._refresh()

func _guarded_entries() -> void:
	_fresh_sluice()
	app._runner_dialogue(); var remote = app.modal_actions[0]; var untouched = s.to_dict()
	remote.call()
	check(s.to_dict() == untouched and not s.battle_active, "Far callback cannot choose pursuit or spend resources")
	app._close_modal()
	await _talk("ledger_runner"); var stale = app.modal_actions[0]
	await _key(KEY_ESCAPE); stale.call()
	check(s.side_choice.is_empty() and not s.battle_active, "Cancelled dialog callback cannot enter battle")
	await _talk("ledger_runner"); stale = app.modal_actions[0]
	app._show_map(); stale.call()
	check(s.side_choice.is_empty() and not s.battle_active, "Older generation cannot enter battle from another modal")
	app._close_modal(); await _talk("ledger_runner")
	s.fail_writes = true
	var stock = s.medicine; var health = s.hp; var energy = s.qi
	await _key(KEY_1)
	check(s.side_choice == "pursuit" and s.side_stage == 1, "Valid nearby choice is retained for save retry")
	check(not s.battle_active and app.save_warning and s.medicine == stock and s.hp == health and s.qi == energy, "Failed entry checkpoint accepts no fight or resource cost")
	s.fail_writes = false; await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
	check(panel != null and panel.encounter == "sluice_scout", "Same choice retries into actual party controller")
	if panel == null: return
	panel.art.set_process(false)
	check(panel.commands.context.title == "半页水令" and panel.unit_plates.has("sluice_scout"), "Real encounter labels and unique opponent identity")
	check(not panel.unit_plates.has("puheng"), "No false Pu Heng unit inserted")
	var saved = State.new(); saved.fixture = fixture
	check(saved.load_game() == OK and saved.side_choice == "pursuit", "Entry checkpoint includes route decision")
	await _key(KEY_5); _finish(panel)
	check(not s.battle_active and s.side_found.is_empty() and s.side_choice == "pursuit", "Numbered flee retains branch without granting ledger")
	if app.active_modal: app._close_modal()
	await _talk("sluice_boss")
	check(not app.modal_actions.is_empty() and not app._start_party_battle("sluice_boss"), "Opening-only adapter does not bypass sluice clue gate")
	check(not s.can_start_sluice_party_battle("sluice_boss"), "Boss remains locked without both clues")

func _actor_round() -> void:
	_fresh_sluice()
	await _talk("ledger_runner"); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null; check(panel != null, "Scene E and number start scout")
	if panel == null: return
	panel.art.set_process(false)
	for id in ["shen","hero"]:
		await _click(panel.commands.actor_buttons[id]); await _key(KEY_3)
		var accepted = s.party_battle_snapshot()
		await _key(KEY_3,true); await _key(KEY_TAB)
		check(s.party_battle_snapshot() == accepted, "Animation lock rejects echo and target changes")
		_finish(panel)
	check(s.party_battle_snapshot().round == 2 and s.party_battle_snapshot().enemy_intents[0].heavy, "All recruited allies act before visible heavy intent")
	root.size = Vector2i(1179,737); await process_frame
	await _click(panel.commands.actor_buttons.shen)
	check(s.party_battle_snapshot().active_actor_id == "shen", "Compact physical click selects real companion")
	await _key(KEY_F)
	check(root.gui_get_focus_owner() != null, "Keyboard exposes command details while Tab selects targets")
	await _key(KEY_5); _finish(panel); root.size = Vector2i(1280,800)

func _vulnerability_presentation() -> void:
	_fresh_sluice(false,true)
	await _talk("sluice_boss"); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null; check(panel != null, "Actual two-clue boss entry")
	if panel == null: return
	panel.art.set_process(false)
	check(panel.commands.context.title == "逆水而行" and panel.unit_plates.sluice_boss.facts.hp == 150, "Boss metadata and actual HP are visible")
	panel.art.event_presented.connect(func(event: Dictionary):
		if String(event.type).begins_with("vulnerability_"):
			var shown = _actor(panel.art.display_snapshot,event.target_id)
			shown_vulnerability.append(event.duplicate(true))
			check(shown.status.vulnerability_hits == event.remaining, "Status presentation changes at exact accepted event")
	)
	panel.request_command("hero","attack"); _finish(panel)
	check(panel.unit_plates.sluice_boss.intent.contains("重击"), "Second round telegraphs heavy attack")
	panel.request_command("hero","attack")
	check(_actor(panel.commands.snapshot,"hero").status.vulnerability_hits == 0, "UI never reveals after-state vulnerability before impact")
	_finish(panel)
	check(_actor(panel.commands.snapshot,"hero").status.vulnerability_hits == 2 and not shown_vulnerability.is_empty(), "Actual struck actor displays two-hit vulnerability")
	check(panel.logs.any(func(line): return line.contains("破绽")), "Optional journal explains actual status and recovery")
	panel.request_command("hero","guard"); _finish(panel)
	check(_actor(panel.commands.snapshot,"hero").status.vulnerability_hits == 0, "Selected actor's guard clears displayed vulnerability")
	check(shown_vulnerability.any(func(event): return event.type == "vulnerability_expire" and event.reason == "guard"), "Guard clear is a real event")
	panel.leave(); _finish(panel)
	check(s.side_stage == 2 and not s.side_reward_claimed, "Flee clears combat without finishing branch")

func _saved_close() -> void:
	_fresh_sluice()
	await _talk("ledger_runner"); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null; check(panel != null, "Close-flow scout starts")
	if panel == null: return
	panel.art.set_process(false)
	panel.request_command("hero","guard"); s.fail_writes = true
	panel.request_application_close(); _finish(panel)
	check(panel.close_pending and panel.art.is_presenting(), "Window close waits for accepted action then actual flee")
	_finish(panel)
	check(app.exits == 0 and not s.battle_active and app.save_warning, "Save failure retains game after safely leaving encounter")
	check(s.side_choice == "pursuit" and s.side_found.is_empty(), "Failed-close outcome cannot invent clue or reward")
	s.fail_writes = false
	app._autosave()
	var saved = State.new(); saved.fixture = fixture
	check(saved.load_game() == OK and saved.side_choice == "pursuit" and saved.side_found.is_empty(), "Explicit retry saves consistent retryable route")
