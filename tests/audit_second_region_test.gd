extends "res://tests/audit_progression_test.gd"
## Independent real-scene branch audit; uses the inherited isolated save adapter.


func _run() -> void:
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	if not game.has_method("_new_game"):
		push_error("Main script failed to compile; second-region audit not run")
		game.free()
		quit(2)
		return
	root.add_child(game)
	await process_frame
	game.state = AuditState.new()
	game._new_game()
	game._exit_sluice_dialogue()
	_check(_find_button(game.overlay, "前往废闸") == null, "Second region remains gated before chapter completion")
	game._close_modal()
	await _test_modal_keys()
	await _test_rescue_first()
	await _test_pursuit_first_and_recovery()
	_test_region_save_recovery()
	await _test_map_and_martial_menus()
	await _test_title_overwrite_confirmation()
	_test_legacy_completed_chapter()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	game.music.stop()
	game.sfx.stop()
	game.music.stream = null
	game.sfx.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d independent second-region audit checks" % checks)
	else:
		push_error("FAIL: %d of %d independent second-region audit checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_modal_keys() -> void:
	game._elder_dialogue()
	await _key(KEY_SPACE)
	_check(game.state.quest_stage == 1 and not game.active_modal, "Space activates first modal option exactly once")
	game.state.quest_stage = 4
	game._elder_dialogue()
	await _key(KEY_2)
	_check(game.state.ending == "守望" and game.state.quest_stage == 5, "Number two selects the second story option")
	await _key(KEY_3)
	_check(game.state.sect == "问石门" and game.state.quest_stage == 6, "Number three selects the third sect")
	game._show_inventory()
	await _key(KEY_4)
	_check(not game.active_modal, "Number four closes inventory through its fourth option")
	game._show_journal();await process_frame
	var journal=game.overlay.get_meta("journal_ui",null)
	_check(is_instance_valid(journal) and game.modal_actions.is_empty(),"Dedicated J owns controls without generic modal actions")
	var tracked:String=game.journal_session.tracked_arc_id
	var browsed:String=journal.browse_arc_id
	await _key(KEY_ENTER)
	_check(game.active_modal and journal.browse_arc_id==browsed and game.journal_session.tracked_arc_id==tracked,"Enter on initial J row only browses, never tracks or closes")
	journal.action_buttons.close.grab_focus();await _key(KEY_ENTER)
	_check(not game.active_modal, "Enter on focused real J Close closes exactly once")
	game._modal("普通对话键盘回归","通用单选项","保持原有确认方式。")
	await _key(KEY_ENTER)
	_check(not game.active_modal,"Enter retains generic one-option modal close behavior")


func _prepare_completed_chapter() -> void:
	game._new_game()
	game.state.quest_stage = 6
	game.state.ending = "守望"
	game.state.gain_xp(180)
	game.state.choose_sect("听潮阁")
	game.state.coins = 150
	game.state.medicine = 5
	game._process(0.0)
	game._refresh()


func _enter_sluice() -> void:
	game._exit_sluice_dialogue()
	_press("前往废闸")
	_check(game.state.map_id == "sluice" and game.world.map_id == "sluice", "Travel synchronizes state and rendered map")
	_check(game.state.position == game.world.player_pos and game.world._can_walk(game.world.player_pos), "Travel saves the safe destination coordinate")
	_check(game.region_header.text == game.state.current_region_name(), "Region header follows destination")


func _check_boss_locked() -> void:
	_interact_at("sluice_boss")
	_check(_find_button(game.overlay, "问个明白") == null, "Boss requires both clues")
	game._close_modal()


func _test_rescue_first() -> void:
	_prepare_completed_chapter()
	_enter_sluice()
	_check_sluice_navigation()
	_check_boss_locked()
	_interact_at("stranded_boatman")
	_press("割断缆绳救人")
	await _dismiss_and_reload("boatman clue")
	_check(game.state.side_choice == "rescue" and game.state.side_stage == 1 and game.state.side_found == ["boatman"], "Rescue-first records exactly one clue and locks the branch")
	_interact_at("stranded_boatman")
	_check(_find_button(game.overlay, "割断缆绳救人") == null, "Boatman cannot yield a repeated clue or reward")
	game._close_modal()
	_check_boss_locked()
	game.world.teleport(Vector2(560, 760))
	game._save()
	var before: Dictionary = game.state.to_dict()
	_forget_session_without_saving()
	game._load()
	_check(game.state.to_dict() == before and game.world.map_id == "sluice", "One-clue branch survives loading from another map")
	game.state.qi = 0
	var before_scout_xp: int = _total_xp()
	_start_sluice_party("sluice_scout")
	var scout: Dictionary = game.state.party_battle_snapshot()
	_check(scout.enemies[0].max_hp == 85 and scout.enemy_intents[0].damage == 11, "Scout snapshot carries its distinct health and public damage telegraph")
	var rejected: Dictionary = game.state.to_dict()
	await _key(KEY_1)
	_check(game.state.party_battle_snapshot() == scout and game.state.to_dict() == rejected, "Unavailable numbered martial input leaves the entire party and persistent state unchanged")
	_win_battle()
	_check(_total_xp() == before_scout_xp + 25 and game.state.party_settlement.reward_xp == 25, "Scout settlement grants exactly twenty-five XP")
	_check(game.state.side_stage == 2 and game.state.side_clues == 2 and game.state.coins == 164, "Scout victory grants exactly one ledger and fourteen coins")
	_check(game.state.quest_stage == 6, "Scout cannot rewind main-story stage")
	_check(not _modal_text().contains("需要再听听船工的证言"), "Rescue-first scout result does not ask for an already-collected clue")
	_press("收起账页")
	_interact_at("ledger_runner")
	_check(_find_button(game.overlay, "截住传令人") == null, "Defeated scout is not farmable through its dialogue")
	game._close_modal()
	game.state.heal_rest()
	_start_sluice_party("sluice_boss")
	var boss: Dictionary = game.state.party_battle_snapshot()
	_check(boss.enemies[0].max_hp == 150 and boss.enemy_intents[0].damage == 16, "Boss snapshot carries its distinct health and opening telegraph")
	_automatic_round()
	boss = game.state.party_battle_snapshot()
	_check(boss.round == 2 and boss.enemy_intents[0].heavy and boss.enemy_intents[0].damage == 28, "Automatic basic, enemy strike and round boundary reveal next heavy intent")
	_automatic_round()
	var panel = _party_panel()
	_check(_hero().status.vulnerability_hits == 2 and panel.commands.snapshot.actors[0].status.vulnerability_hits == 2, "Boss heavy attack exposes two remaining vulnerability hits in the real party HUD snapshot")
	var before_locked_lightness: Dictionary = game.state.party_battle_snapshot()
	await _key(KEY_3)
	_check(game.state.party_battle_snapshot()==before_locked_lightness and _hero().status.vulnerability_hits==2, "Locked unlearned lightness cannot impersonate the removed guard command or clear real vulnerability")
	_check(_party_panel().commands.snapshot.actors[0].status.vulnerability_hits==2, "Party HUD preserves real unconsumed vulnerability")
	var before_coins: int = game.state.coins
	var before_medicine: int = game.state.medicine
	var before_boss_xp: int = _total_xp()
	_win_battle()
	_check(game.state.side_stage == 3 and game.state.side_reward_claimed, "Boss victory completes the side quest")
	_check(_total_xp() == before_boss_xp + 150 and game.state.party_settlement.battle_reward_xp == 70 and game.state.party_settlement.branch_reward_xp == 80, "Rescue settlement awards seventy battle XP and eighty branch XP once")
	_check(game.state.coins == before_coins + 80 and game.state.medicine == before_medicine + 2, "Rescue branch grants boss thirty-five plus quest forty-five coins and two medicine")
	await _dismiss_and_reload("completed rescue branch")
	_check_completion_replay_safety()


func _test_pursuit_first_and_recovery() -> void:
	_prepare_completed_chapter()
	_enter_sluice()
	_start_sluice_party("sluice_scout")
	await _party_key(KEY_5)
	_check(not game.state.battle_active and game.state.map_id == "sluice" and game.state.side_choice == "pursuit" and game.state.side_found.is_empty(), "Numbered flee leaves pursuit retryable without awarding a clue")
	_interact_at("ledger_runner")
	_check(not _modal_text().contains("船工已经获救"), "Runner retry does not claim an unrescued boatman is safe")
	game.state.hp = 1
	_press("截住传令人")
	_freeze_party()
	_automatic_round()
	game._process(0.0)
	_check(game.state.map_id == "qingwei" and game.world.map_id == "qingwei", "Second-region defeat returns both map states to the village")
	_check(game.state.hp == game.state.max_hp and game.state.coins == 142 and game.state.position == game.world.player_pos, "Defeat restores health, loses eight coins and synchronizes position")
	_check(game.state.side_choice == "pursuit" and game.state.side_stage == 1 and game.state.side_clues == 0, "Defeat preserves branch choice without granting a false clue")
	game._close_modal()
	_enter_sluice()
	_start_sluice_party("sluice_scout")
	_win_battle()
	await _dismiss_and_reload("scout victory")
	_check(game.state.side_found == ["ledger"] and game.state.side_stage == 1, "Retry can recover the ledger before rescuing the boatman")
	_check_boss_locked()
	_interact_at("stranded_boatman")
	_press("割断缆绳救人")
	_press("记下证言")
	_check(game.state.side_stage == 2 and game.state.side_choice == "pursuit", "Later rescue completes clues without changing pursuit choice")
	game.state.heal_rest()
	_start_sluice_party("sluice_boss")
	_automatic_round()
	_automatic_round()
	_check(_hero().status.vulnerability_hits == 2, "Pursuit boss also applies actual per-actor vulnerability")
	await _party_key(KEY_5)
	_check(_hero().status.vulnerability_hits == 0 and not game.state.battle_active and game.state.side_stage == 2 and not game.state.side_reward_claimed, "Flee clears battle vulnerability without losing clues or finishing quest")
	_interact_at("sluice_cache")
	_press("静坐调息")
	_check(game.state.hp == game.state.max_hp and game.state.qi == game.state.max_qi, "Second-region rest point restores health and qi")
	_start_sluice_party("sluice_boss")
	var before_coins: int = game.state.coins
	var before_medicine: int = game.state.medicine
	var before_boss_xp: int = _total_xp()
	_win_battle()
	_check(game.state.side_stage == 3 and game.state.coins == before_coins + 100 and game.state.medicine == before_medicine, "Pursuit branch grants boss thirty-five plus quest sixty-five coins without rescue medicine")
	_check(_total_xp() == before_boss_xp + 150 and game.state.party_settlement.battle_reward_xp == 70 and game.state.party_settlement.branch_reward_xp == 80, "Pursuit settlement awards seventy battle XP and eighty branch XP once")
	_press("收好水令")
	_check_completion_replay_safety()


func _check_completion_replay_safety() -> void:
	var before: Dictionary = game.state.to_dict()
	game._finish_sluice()
	_check(game.state.to_dict() == before, "Repeated quest completion cannot duplicate rewards")
	game._close_modal()
	_interact_at("sluice_boss")
	_check(_find_button(game.overlay, "问个明白") == null, "Completed boss cannot be restarted from its dialogue")
	game._close_modal()
	game._save()
	_forget_session_without_saving()
	game._load()
	_check(game.state.to_dict() == before and game.world.map_id == "sluice", "Completed branch survives save/load with all rewards unchanged")
	game._travel("qingwei", Vector2(1390, 560))
	_check(game.world.interactables.has("elder") and not game.world.interactables.has("sluice_boss"), "Returning village restores the correct interaction set")
	_check(game.state.side_stage == 3 and game.state.quest_stage == 6, "Returning village preserves both completed quests")


func _test_region_save_recovery() -> void:
	_prepare_completed_chapter()
	_enter_sluice()
	game.state.position = Vector2(820, 600)
	game.state.save_game()
	_forget_session_without_saving()
	game._load()
	_check(game.world.map_id == "sluice" and game.world._can_walk(game.world.player_pos), "Loading a stale second-region coordinate repairs unsafe terrain on the saved map")
	game._process(0.0)
	_check(game.state.position == game.world.player_pos, "Repaired load coordinate is reflected back into persistent state")


func _check_sluice_navigation() -> void:
	var queue: Array[Vector2] = [Vector2(190, 520)]
	var visited: Dictionary = {queue[0]: true}
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		for offset: Vector2 in [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
			var next := point + offset
			if not visited.has(next) and game.world._can_walk(next):
				visited[next] = true
				queue.append(next)
	for id: String in game.world.interactables:
		var target: Vector2 = game.world.interactables[id]["pos"]
		var reachable := false
		for point: Vector2 in visited:
			if point.distance_to(target) < 70:
				reachable = true
				break
		_check(reachable, "Walkable second-region route reaches interaction: " + id)


func _key(key: Key) -> void:
	game._process(0.0)
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	# Dedicated native Buttons activate on release; deliver it before assertions.
	await process_frame


func _forget_session_without_saving() -> void:
	game.state.reset_game()
	game.world.change_map("qingwei", game.state.position)
	game._clear_overlay()
	game.active_modal = false
	game.current_screen = "explore"


func _dismiss_and_reload(label: String) -> void:
	var before: Dictionary = game.state.to_dict()
	await _key(KEY_ESCAPE)
	_check(not game.active_modal, "Escape dismisses result modal: " + label)
	_forget_session_without_saving()
	game._load()
	_check(game.state.to_dict() == before and game.world.map_id == before["map_id"], "Escape dismissal persists result before reload: " + label)


func _modal_text() -> String:
	return _gather_text(game.overlay)


func _gather_text(node: Node) -> String:
	var result := ""
	if node is Label or node is RichTextLabel:
		result += node.text
	for child in node.get_children():
		result += _gather_text(child)
	return result


func _test_map_and_martial_menus() -> void:
	for map_id: String in ["qingwei", "sluice"]:
		game._travel(map_id, Vector2(460, 430) if map_id == "qingwei" else Vector2(190, 520))
		var before: Dictionary = game.state.to_dict()
		await _key(KEY_M)
		var chart := _find_chart(game.overlay)
		_check(game.active_modal and chart != null, "M opens the drawn map: " + map_id)
		if chart != null:
			_check(chart.map_id == map_id and chart.player_position == game.world.player_pos and chart.markers == game.world.interactables, "Map uses current region, position and interaction markers: " + map_id)
		await _key(KEY_ESCAPE)
		_check(game.state.to_dict() == before, "Map inspection cannot teleport or change resources: " + map_id)
	var sect_arts := {"听潮阁": "回潮断浪", "照野堂": "青灯续脉", "问石门": "磐石回锋"}
	for sect: String in sect_arts:
		game._new_game()
		game.state.quest_stage = 5
		game.state.ending = "守望"
		game._choose_sect()
		_press(sect)
		game.state.gain_xp(180)
		var art: String = sect_arts[sect]
		game.state.art_uses[art] = 4
		await _key(KEY_K)
		_check(game.active_modal and _find_button(game.overlay, "修习 " + art) != null, "K exposes the joined sect's martial art: " + art)
		for other_sect: String in sect_arts:
			if other_sect != sect:
				_check(_find_button(game.overlay, "修习 " + sect_arts[other_sect]) == null, "Other sect's exclusive art is unavailable: " + sect_arts[other_sect])
		await _key(KEY_2)
		_check(game.state.equipped_art == art and not game.active_modal, "Second modal choice equips the sect art: " + art)
		_enter_sluice()
		_check(game.state.choose_side_route("rescue") and game.state.find_side_clue("boatman") and game.state.find_side_clue("ledger"), "Art fixture earns valid boss eligibility through real progress APIs")
		var cost: int = game.state.active_art_cost()
		var action_id: String = "art:" + art
		var button_key: String = "hero::slot:martial"
		game.state.qi = cost - 1
		_start_sluice_party("sluice_boss")
		var panel = _party_panel()
		var descriptor: Dictionary = panel.commands.descriptors[button_key]
		_check(not descriptor.available and not panel.commands.action_reason("hero", action_id).is_empty() and descriptor.name == art and descriptor.cost == cost, "Real party button exposes art name/cost and the below-cost rejection: " + art)
		var rejected: Dictionary = game.state.party_battle_snapshot()
		await _key(KEY_1)
		_check(game.state.party_battle_snapshot() == rejected and game.state.art_uses[art] == 4, "Rejected art cannot spend a party action or earn proficiency: " + art)
		await _party_key(KEY_5)
		game.state.qi = cost
		game.state.hp = 60
		_start_sluice_party("sluice_boss")
		panel = _party_panel()
		_check(panel.commands.descriptors[button_key].available and panel.commands.action_reason("hero", action_id).is_empty(), "Party button enables at exact required qi: " + art)
		await _party_key(KEY_1)
		_check(_hero().qi == 0 and _hero().cooldowns[action_id] == game.state.active_art_cooldown() and game.state.art_uses[art] == 5 and game.state.art_rank(art) == 2, "Accepted sect art charges correct resources and crosses proficiency threshold: " + art)
		if sect == "照野堂":
			_check(game.state.hp > 60, "Healer art produces a net health recovery")
		elif sect == "问石门":
			_check(_hero().status.vulnerability_hits == 0 and game.state.hp >= 57, "Defensive art guards actual incoming attack")
		var after_art: Dictionary = game.state.party_battle_snapshot()
		await _key(KEY_K)
		await _key(KEY_M)
		_check(game.current_screen == "party_battle" and game.overlay.get_meta("party_battle", null) == panel and game.state.party_battle_snapshot() == after_art, "K/M cannot replace the party encounter or spend combat actions")
		await _key(KEY_1)
		_check(game.state.party_battle_snapshot() == after_art and game.state.art_uses[art] == 5, "Cooldown rejection cannot earn extra proficiency")
		await _party_key(KEY_5)
		await _key(KEY_K)
		_check(_modal_text().contains("熟习") and _modal_text().contains("已施展5次"), "Martial menu reflects new proficiency")
		await _key(KEY_ESCAPE)
		var before: Dictionary = game.state.to_dict()
		_forget_session_without_saving()
		game._load()
		_check(game.state.to_dict() == before, "Equipped art and proficiency survive menu-close autosave: " + art)
		if sect == "问石门":
			game.state.heal_rest()
			_start_sluice_party("sluice_boss")
			_automatic_round()
			_automatic_round()
			_check(_hero().status.vulnerability_hits == 2, "Defensive art fixture receives genuine boss-heavy vulnerability")
			var hp_before: int = game.state.hp
			var defensive: Dictionary = await _party_key(KEY_1)
			_check(_hero().status.vulnerability_hits == 0 and _has_event(defensive, "vulnerability_expire") and game.state.hp >= hp_before - 3, "Defensive art clears earned vulnerability and guards the following attack")
			await _party_key(KEY_5)


func _find_chart(node: Node) -> Node:
	if node.has_method("_point") and node.has_method("_draw_markers"):
		return node
	for child in node.get_children():
		var result := _find_chart(child)
		if result != null:
			return result
	return null


func _test_title_overwrite_confirmation() -> void:
	game._save()
	var before: Dictionary = game.state.to_dict()
	var saved_text := FileAccess.get_file_as_string(AuditState.AUDIT_PATH)
	game._show_title()
	await _key(KEY_ENTER)
	_check(_find_button(game.overlay, "确认新旅程") != null and game.state.to_dict() == before, "Starting with an existing save asks before resetting state")
	_check(FileAccess.get_file_as_string(AuditState.AUDIT_PATH) == saved_text, "Pending new-game confirmation leaves saved progress unchanged")
	await _key(KEY_2)
	_check(_find_button(game.overlay, "续写前缘") != null, "Cancelling new-game confirmation returns to the title")
	await _key(KEY_2)
	_check(game.state.to_dict() == before and game.current_screen == "explore", "Continue after cancellation restores the intact saved adventure")
	game._show_title()
	await _key(KEY_1)
	await _key(KEY_1)
	_check(game.state.quest_stage == 0 and game.state.side_stage == 0 and game.state.coins == 24 and game.state.map_id == "qingwei", "Confirmed new game resets main, side and economy progress")
	game._load()
	_check(game.state.quest_stage == 0 and game.state.art_uses == {"照夜一线": 0}, "Confirmed new game replaces the isolated save with fresh progress")


func _test_legacy_completed_chapter() -> void:
	game._new_game()
	game.state.quest_stage = 5
	game.state.ending = "守望"
	game.state.choose_sect("听潮阁")
	var noncanonical: Dictionary = game.state.to_dict()
	var previous_bytes: PackedByteArray = FileAccess.get_file_as_bytes(AuditState.AUDIT_PATH)
	_check(game.state.save_game() == ERR_FILE_CORRUPT and game.state.to_dict() == noncanonical and FileAccess.get_file_as_bytes(AuditState.AUDIT_PATH) == previous_bytes, "Schema12 refuses noncanonical completion without rewriting the previous save or live progress")
	var rejected_path: String = "user://hero_audit_legacy_completion_current.json"
	var current_file = FileAccess.open(rejected_path, FileAccess.WRITE)
	current_file.store_string(JSON.stringify({"version": game.state.SAVE_VERSION, "player": noncanonical}))
	current_file.close()
	_check(game.state.load_game(rejected_path) == ERR_FILE_CORRUPT and game.state.to_dict() == noncanonical, "Schema12 rejects the same old completion shape before mutating live state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rejected_path))
	# Write the intended historical envelope with only original version1 fields.
	var legacy: Dictionary = {}
	for field: String in ["player_name", "level", "xp", "coins", "hp", "max_hp", "qi", "max_qi", "attack", "defense", "medicine", "herbs", "quest_stage", "sect", "ending", "position", "victories"]:
		legacy[field] = noncanonical[field]
	var old_file = FileAccess.open(AuditState.AUDIT_PATH, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"version": 1, "player": legacy}))
	old_file.close()
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(AuditState.AUDIT_PATH)
	var historical_reader = AuditState.new()
	_check(historical_reader.load_game() == OK and FileAccess.get_file_as_bytes(AuditState.AUDIT_PATH) == old_bytes, "State migration reads without replacing historical source bytes")
	_forget_session_without_saving()
	game._load()
	_check(game.state.quest_stage == 6 and game.state.sect == "听潮阁", "Actual version1 completed chapter with stage five and chosen sect migrates to stage six")
	game._exit_sluice_dialogue()
	_check(_find_button(game.overlay, "前往废闸") != null, "Legacy completed save can access the newly added region")
	game._close_modal()


func _interact_at(id: String) -> void:
	if game.active_modal:
		game._close_modal()
	_check(game.world.interactables.has(id), "Interaction exists on the rendered region: " + id)
	if not game.world.interactables.has(id):
		return
	game.world.teleport(game.world.interactables[id].pos)
	game._process(0.0)
	game._interact(id)


func _start_sluice_party(kind: String) -> void:
	_interact_at("ledger_runner" if kind == "sluice_scout" else "sluice_boss")
	_press("截住传令人" if kind == "sluice_scout" else "问个明白")
	_freeze_party()
	_check(game.current_screen == "party_battle" and game.state.party_battle_snapshot().get("encounter_id") == kind, "Ordinary guarded scene choice starts the actual party encounter: " + kind)


func _party_panel():
	return game.overlay.get_meta("party_battle", null)


func _freeze_party() -> void:
	var panel = _party_panel()
	_check(is_instance_valid(panel), "Independent encounter mounts its real PartyUI controller")
	if is_instance_valid(panel):
		panel.set_process(false)
		panel.art.set_process(false)


func _hero() -> Dictionary:
	for actor: Dictionary in game.state.party_battle_snapshot().get("actors", []):
		if actor.id == "hero":
			return actor
	return {}


func _total_xp() -> int:
	return game.state.xp + 30 * game.state.level * (game.state.level - 1)


func _progress() -> Dictionary:
	return {"coins": game.state.coins, "xp": _total_xp(), "side_stage": game.state.side_stage,
		"side_found": game.state.side_found.duplicate(), "side_reward_claimed": game.state.side_reward_claimed}


func _party_key(key: Key) -> Dictionary:
	var panel = _party_panel()
	if not is_instance_valid(panel):
		_check(false, "Numbered party input requires the real controller")
		return {}
	panel.set_process(false);panel.art.set_process(false)
	var before: Dictionary = _progress()
	await _key(key)
	if panel.pending.is_empty(): panel._process(1.0)
	var tx: Dictionary = panel.pending.duplicate(true)
	_check(not tx.is_empty() and tx.get("accepted", false), "Numbered command accepts a real party transaction: " + str(key))
	if tx.is_empty():
		return {}
	_check(_progress() == before, "Accepted party action leaves rewards and clues unchanged until renderer completion")
	_check(panel.art.is_presenting(), "Accepted party transaction begins its real renderer timeline")
	panel.art._process(panel.art.get_presentation_duration() + 0.1)
	return tx


func _has_event(tx: Dictionary, type: String) -> bool:
	for event: Dictionary in tx.get("events", []):
		if event.type == type:
			return true
	return false


func _automatic_round() -> Dictionary:
	var initial_round: int = game.state.party_battle_snapshot().round
	var last: Dictionary = {}
	for index: int in range(32):
		if not game.state.battle_active or game.state.party_battle_snapshot().round > initial_round: return last
		var before: Dictionary = _progress()
		last = UnifiedDriver.begin_step(game, false)
		_check(last.get("accepted", false), "Actual scheduler progresses without manual attack input")
		if not last.get("accepted", false): return last
		_check(_progress() == before, "Accepted automatic action cannot award before its renderer acknowledgement")
		UnifiedDriver.finish_step(game)
	_check(false, "One automatic round must finish within its finite actor/enemy/boundary actions")
	return last
