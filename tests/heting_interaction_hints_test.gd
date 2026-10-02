extends "res://tests/audit_heting_current_test.gd"
## E labels describe the next sheet. Input never bypasses its confirmation.

func _run() -> void:
	fixture = "user://heting-hints-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK, "Create isolated hint fixture")
	store = Slots.new(fixture)
	state_probe = RoutedState.new(); state_probe.directory = fixture
	game = CloseProbe.new(); game.state = state_probe
	root.add_child(game); game.save_slots.store = store
	await process_frame
	game.set_process(false); game.world.set_process(false); game._stop_audio(); game.audio_on = false
	await _source_and_receiver_flow()
	await _draft_and_finished_flow()
	_display_fit()
	game._stop_audio(); game.queue_free(); await process_frame
	_remove_fixture(fixture)
	_check(not DirAccess.dir_exists_absolute(fixture) and not FileAccess.file_exists(Model.SAVE_PATH), "Only test-owned save data was used")
	if failures == 0: print("PASS: %d harbor context/input/display checks" % checks)
	else: push_error("FAIL: %d of %d harbor context/input/display checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _expect(id: String, verb: String) -> void:
	game.world.teleport(game.world.interactables[id].pos); game._process(0)
	_check(game.world.nearby_id == id and game.world.interaction_verb(id) == verb, "Context verb agrees with actual nearest site: " + id + " / " + verb)
	_check(game.near_label.text == "[ E ]  " + verb + " · " + game.world.nearby_name, "Lower-left hint mirrors the exact action and site")
	_check(game.hud.interaction.visible, "Existing interaction strip is visible")

func _source_and_receiver_flow() -> void:
	_port(1, "", "", "west")
	_expect("heting_lighter", "询问货物")
	await _key(KEY_E)
	_check(_find_button(game.overlay, "押待分粮") == null, "Unavailable reserve prompt opens explanation, not a false loading option")
	await _key(KEY_ESCAPE)
	_expect("heting_cargo", "提货")
	var before: Dictionary = state_probe.to_dict(); var writes: int = state_probe.writes
	await _key(KEY_E)
	_check(game.active_modal and state_probe.to_dict() == before and state_probe.writes == writes, "E opens source sheet without automatically taking cargo or saving")
	await _key(KEY_ESCAPE)
	_check(state_probe.to_dict() == before and state_probe.writes == writes, "Cancel leaves cargo and saves unchanged")
	await _key(KEY_E); await _key(KEY_1); game._process(0)
	_check(state_probe.heting_cargo == "meal" and game.world.nearby_id == "heting_cargo" and game.world.interaction_verb("heting_cargo") == "查看货签", "Actual numeric loading updates prompt while standing at same source")
	_check(game.near_label.text.contains("查看货签") and not game.near_label.text.contains("提货"), "Stationary HUD refresh does not retain old verb")
	_expect("heting_cargo", "查看货签"); await _key(KEY_E)
	_check(_find_button(game.overlay, "退车归位") != null, "Loaded source still offers parking through its cargo sheet")
	await _key(KEY_2); game._process(0)
	_check(state_probe.heting_cargo.is_empty() and game.near_label.text.contains("提货"), "Actual parking refreshes stationary prompt to loading")
	await _key(KEY_E); await _key(KEY_1)
	_expect("heting_scale", "询问去处"); before = state_probe.to_dict(); writes = state_probe.writes
	await _key(KEY_E)
	_check(_modal_text().contains("货签各有所属") and _find_button(game.overlay, "交粮当面复称") == null, "Wrong receiver retains narrative guidance without a delivery option")
	await _key(KEY_ESCAPE)
	_check(state_probe.to_dict() == before and state_probe.writes == writes, "Wrong-destination question does not consume cargo or save")
	_expect("heting_relief", "商议交粮"); before = state_probe.to_dict()
	await _key(KEY_E)
	_check(state_probe.to_dict() == before and _find_button(game.overlay, "交下开锅粮") != null, "Correct receiver E only opens explicit delivery choice")
	await _key(KEY_ESCAPE); _check(state_probe.to_dict() == before, "Cancel correct receiver keeps loaded cargo")
	await _key(KEY_E); await _key(KEY_1); await _key(KEY_ESCAPE); game._process(0)
	_check(state_probe.heting_delivered == ["meal"] and game.near_label.text.contains("交谈"), "Delivery refreshes receiver hint without requiring movement")
	_expect("heting_relief", "交谈"); await _key(KEY_E)
	_check(_modal_text().contains("锅沿升起") and _find_button(game.overlay, "借棚调息") != null, "Delivered receiver still exposes aftermath and rest dialogue")
	await _key(KEY_ESCAPE)
	_expect("heting_cargo", "提货"); await _key(KEY_E)
	_check(_find_button(game.overlay, "押对秤封粮") != null and _find_button(game.overlay, "押开锅粮") == null, "Remaining source advertises only actual finite stock")
	await _key(KEY_1); _expect("heting_scale", "商议交粮")
	await _key(KEY_E); await _key(KEY_1); await _key(KEY_ESCAPE)
	_expect("heting_cargo", "询问货物"); await _key(KEY_E)
	_check(_modal_text().contains("两批已办"), "Exhausted source opens the honest empty-stock narrative")
	await _key(KEY_ESCAPE); _expect("heting_dispatch", "商议分粮")

func _draft_and_finished_flow() -> void:
	await _key(KEY_E); await _key(KEY_1); await _key(KEY_ESCAPE)
	_expect("heting_lighter", "提货"); await _key(KEY_E); await _key(KEY_1)
	_expect("heting_lighter", "查看货签")
	_expect("heting_scale", "询问去处"); await _key(KEY_E)
	_check(_find_button(game.overlay, "改作守秤留粮") != null, "Wrong reserve destination keeps the reversible plan discussion")
	await _key(KEY_2)
	_check(state_probe.heting_draft == "open_scale" and state_probe.heting_stage == 3 and state_probe.heting_cargo == "reserve", "Changing plan still requires a separate final delivery")
	await _key(KEY_ESCAPE); game._process(0)
	_check(game.near_label.text.contains("商议交粮"), "Changed plan updates the same receiver hint in place")
	await _key(KEY_E); await _key(KEY_1); await _key(KEY_ESCAPE)
	_check(state_probe.heting_stage == 4 and state_probe.heting_cargo.is_empty(), "Explicit confirmation completes only the intended final batch")
	for id in ["heting_scale", "heting_relief", "heting_dispatch", "heting_cargo", "heting_lighter"]:
		_expect(id, "交谈")
		await _key(KEY_E); _check(game.active_modal, "Finished site still opens its narrative: " + id); await _key(KEY_ESCAPE)
	_expect("heting_winch", "调整浮桥")
	var before: Dictionary = state_probe.to_dict()
	await _key(KEY_E); _check(state_probe.to_dict() == before, "Winch E opens options without automatically changing bridge")
	await _key(KEY_ESCAPE)
	_expect("return_mistwood", "前往")

func _display_fit() -> void:
	# Physical window sizes use the existing logical1280x800 canvas; no new scale preference.
	for window_size in [Vector2i(1280,800), Vector2i(1180,737)]:
		root.size = window_size
		for zoom in range(3):
			for full_detail in [false,true]:
				_port(3, "reserve", "short_ferries", "east")
				game.view_preferences.zoom_index = zoom; game.view_preferences.full_resolution = full_detail; game._apply_view_zoom()
				for pair in [["heting_lighter","查看货签"],["heting_scale","询问去处"],["heting_relief","商议交粮"],["heting_winch","调整浮桥"],["heting_dispatch","商议分粮"]]:
					_expect(pair[0],pair[1])
					var text: String = "E  " + pair[1]
					var target: Vector2 = game.world.interactables[pair[0]].pos
					var box: Rect2 = game.world._interaction_prompt_rect(target,text)
					var measured: Vector2 = game.world.ui_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
					_check(box.size.x >= measured.x + 19 and box.size.y == 23, "Long plain-language local prompt has measured padding")
					_check(Rect2(game.world.camera_pos,game.world.viewport_rect.size).encloses(box), "Prompt fits actual camera at each supported zoom/window/detail mode")
					var hint_width: float = game.near_label.get_theme_font("font").get_string_size(game.near_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
					_check(hint_width <= game.near_label.size.x and Rect2(0,0,1280,800).encloses(game.near_label.get_global_rect()), "Mirrored instruction fits the existing lower-left HUD")
