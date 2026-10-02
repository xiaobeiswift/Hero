extends "res://tests/audit_second_region_test.gd"
## Prepared completed-chapter fixtures; actual main-scene E/choice/ESC/save flow.
const Region = preload("res://scripts/mistwood_region.gd")
const Rules = preload("res://scripts/qin_companion_rules.gd")
const State = preload("res://scripts/game_state.gd")

func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	game = load("res://scenes/main.tscn").instantiate()
	if not game.has_method("_new_game"): game.free(); quit(2); return
	game.state = AuditState.new()
	root.add_child(game)
	await process_frame
	game.world.set_process(false)
	for ending in Rules.ENDINGS: await _route(ending)
	game._stop_audio(); game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	_check(not FileAccess.file_exists(State.SAVE_PATH), "Scene test never creates normal player save")
	print("%s: %d Qin invitation scene checks (two endings / real keys / stale guards / saves)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _prepare(ending: String) -> void:
	game._new_game()
	var s = game.state
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁")
	s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	s.mist_stage = 4; s.mist_ending = ending; s.mist_approach = "duel"
	s.mist_gauges.assign(["rain", "stone", "basin"])
	game._travel("mistwood", Region.points().mist_guide.pos + Vector2(0, 35))

func _talk(id: String) -> void:
	game.world.teleport(Region.points()[id].pos + Vector2(0, 35))
	game._process(0)
	await _key(KEY_E)
	_check(game.active_modal, "Real E opens " + id)

func _saved_stage(stage: int) -> void:
	var restored = State.new()
	_check(restored.load_game(AuditState.AUDIT_PATH) == OK, "Schema12 Qin scene save loads")
	_check(restored.qin_stage == stage and restored.qin_unlocked == (stage == 4), "Saved exact Qin progress")

func _route(ending: String) -> void:
	_prepare(ending)
	var s = game.state
	var resources = [s.xp, s.coins, s.medicine, s.resources.duplicate(true), s.mist_ending, s.mist_gauges.duplicate()]
	await _talk("mist_guide")
	_check(_modal_text().contains("尺绳有托") and not s.qin_unlocked, "Optional invitation offered without auto-grant")
	var canceled: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE); canceled.call()
	_check(s.qin_stage == 0 and not s.qin_unlocked, "Escape invalidates captured acceptance")
	await _talk("mist_guide")
	await _key(KEY_2)
	_check(_modal_text().contains("底稿"), "Original water-story dialogue stays accessible")
	await _key(KEY_ESCAPE)
	await _talk("mist_guide")
	var remote: Callable = game.modal_actions[0]
	game.world.teleport(Vector2(800, 800)); remote.call()
	_check(s.qin_stage == 0, "Remote stale acceptance cannot advance")
	await _key(KEY_ESCAPE)
	await _talk("mist_guide"); await _key(KEY_1)
	_check(s.qin_stage == 1 and not game.active_modal, "Actual key accepts voluntary quest")
	_saved_stage(1)
	await process_frame
	_check(game.mist_story.title() == "尺绳有托" and game.mist_story.target_id() == "mist_rain_gauge", "HUD and compass point to real rope site")
	_check(game.quest_label.text == "尺绳有托" and game.world._quest_target_id() == "mist_rain_gauge", "Accepted local quest takes precedence over next-chapter tracker")
	await _talk("mist_rain_gauge")
	var rope: Callable = game.modal_actions[0]
	await _key(KEY_1); rope.call()
	_check(s.qin_stage == 2, "Rope callback commits once")
	_saved_stage(2)
	_check(game.mist_story.target_id() == "mist_camp", "Handoff target is real camp")
	await _talk("mist_camp")
	await _key(KEY_2)
	_check(s.qin_stage == 2 and not game.active_modal, "Free rest remains available without completing handoff")
	await _talk("mist_camp"); await _key(KEY_1)
	_check(s.qin_stage == 3 and not s.qin_unlocked, "Handoff does not implicitly recruit")
	_saved_stage(3)
	await _talk("mist_guide")
	var invite: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE); invite.call()
	_check(s.qin_stage == 3 and not s.qin_unlocked, "Cancel invitation leaves slot empty")
	await _talk("mist_guide"); await _key(KEY_1); invite.call()
	_check(s.qin_recruited() and s.party_roster == ["hero", "qin"], "Explicit invitation selects only actual recruited Qin")
	_saved_stage(4)
	await _talk("mist_guide")
	_check(_find_button(game.overlay, "邀请秦禾") == null, "Repeated conversation cannot invite twice")
	_check(game.mist_story.journal().contains("尺绳有托"), "Journal retains completed personal quest")
	await _key(KEY_ESCAPE)
	_check([s.xp, s.coins, s.medicine, s.resources, s.mist_ending, s.mist_gauges] == resources, "Invitation creates no item/XP/coin reward and preserves ending/readings")
