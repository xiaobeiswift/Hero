extends SceneTree
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")
const CombatUI = preload("res://scripts/party_battle_ui.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
class State extends Model:
	var fixture: String
	var fail_writes: bool = false
	var writes: int = 0
	func save_game(path: String = SAVE_PATH) -> Error:
		writes += 1
		if fail_writes: return ERR_CANT_CREATE
		return super.save_game(fixture + "/save.json" if path == SAVE_PATH else path)
	func load_game(path: String = SAVE_PATH) -> Error:
		return super.load_game(fixture + "/save.json" if path == SAVE_PATH else path)
	func has_save() -> bool: return FileAccess.file_exists(fixture + "/save.json")
class CloseProbe extends Main:
	var exits: int = 0
	func _quit_cleanly(_save_progress: bool = true) -> void:
		if not quit_pending: exits += 1; quit_pending = true
var app
var s: State
var checks = 0
var failures = 0
var fixture: String
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("Party UI: " + label)
func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture = "user://party-ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); app.save_slots.store = Slots.new(fixture)
	await process_frame
	app._stop_audio(); app.audio_on = false; app.world.set_process(false)
	await _entry_gate()
	await _normal_entries()
	for count in [1, 2, 3, 4]: await _selection_and_costs(count)
	await _targets_and_timing()
	await _close_safety()
	await _close_decisions()
	await _victory_settlement()
	await _defeat_recovery()
	app._stop_audio(); app.queue_free(); await process_frame
	check(not FileAccess.file_exists(Model.SAVE_PATH), "No normal player save created")
	print("%s: %d full-game party controller checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _prepare(count: int = 4, kind: String = "training") -> void:
	app.quit_pending = false; app.exits = 0; s.fail_writes = false
	app.current_screen = "explore"; app.active_modal = false; app._clear_overlay()
	s.reset_game(); app.world.change_map("qingwei", s.position)
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁"); s.gain_xp(600)
	s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"]); s.side_clues = 2
	s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"; s.bridge_repaired = true
	s.archive_clues.assign(["clerk", "inscription"]); s.seal_sequence.assign([2, 0, 1])
	check(s.recruit_companion(), "Actual Shen invitation")
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Actual Tang invitation")
	s.mist_stage = 4; s.mist_ending = "release_water"; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"])
	s.map_id = "mistwood"
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Actual Qin invitation APIs")
	check(s.set_party_roster(["hero", "shen", "tang", "qin"].slice(0, count)), "Select exact occupied roster")
	if kind == "heting_receipt":
		s.heting_stage = 4; s.heting_bridge = "east"; s.heting_draft = "short_ferries"; s.heting_ending = "short_ferries"
		s.heting_delivered.assign(["meal", "sealed", "reserve"]); s.map_id = "heting"; check(s.begin_receipt(), "Actual optional receipt accepts")
		app.world.change_map("heting", Vector2(1420, 300))
	else:
		s.map_id = "qingwei"; s.quest_stage = 3 if kind == "story" else 6
		app.world.change_map("qingwei", Vector2(955, 630))
	s.position = app.world.player_pos; s.heal_rest(); app._refresh()

func _open(kind: String = "training"):
	var panel = CombatUI.open(app, kind)
	check(panel != null and app.current_screen == "party_battle" and s.battle_active, "Actual controller starts " + kind)
	if panel != null: panel.art.set_process(false)
	return panel

func _finish(panel) -> void:
	if is_instance_valid(panel) and panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration() + .1)

func _key(key: Key, echo: bool = false) -> void:
	var event = InputEventKey.new(); event.physical_keycode = key; event.keycode = key; event.pressed = true; event.echo = echo
	Input.parse_input_event(event); await process_frame
	event.pressed = false; event.echo = false; Input.parse_input_event(event)

func _click(control: Control) -> void:
	var center: Vector2 = control.get_global_rect().get_center()
	center = root.get_final_transform() * center
	var event = InputEventMouseButton.new(); event.position = center; event.global_position = center; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event.pressed = false; Input.parse_input_event(event); await process_frame

func _actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id: return actor
	return {}

func _entry_gate() -> void:
	_prepare(1)
	s.fail_writes = true; var before = s.to_dict()
	check(CombatUI.open(app, "training") == null and not s.battle_active and app.save_warning, "Failed entry save prevents battle")
	check(s.to_dict() == before, "Failed entry does not spend resources")
	s.fail_writes = false
	var panel = _open(); panel.leave(); _finish(panel)
	check(app.current_screen == "explore" and not s.battle_active, "Retry entry then flee returns to exploration")

func _selection_and_costs(count: int) -> void:
	_prepare(count)
	var panel = _open()
	if panel == null: return
	check(panel.commands.groups.size() == count, "Only occupied actors have command groups")
	check(panel.unit_plates.puheng.facts.hp == s.party_battle_snapshot().enemies[0].hp and not panel.unit_plates.puheng.intent.is_empty(), "Opponent plate exposes true HP and announced action order")
	for id in s.party_roster.duplicate():
		await _click(panel.commands.actor_buttons[id])
		check(s.party_battle_snapshot().active_actor_id == id, "Native selector controls " + id)
		await _key(KEY_3)
		check(panel.art.is_presenting() and not panel.pending.is_empty(), "Selected actor guard accepts and locks")
		var accepted = s.party_battle_snapshot()
		await _key(KEY_3, true); panel.select_actor("hero"); panel.cycle_target()
		check(s.party_battle_snapshot() == accepted, "Held key and locked selections cannot spend another turn")
		_finish(panel)
	check(s.party_battle_snapshot().round == 2, "Enemies act only after all actual allies spend turn")
	var locked_paths = s.to_dict()
	app._show_inventory(); app._show_martials(); app._show_save_slots(); app._show_load_slots(); app._close_modal()
	check(app.current_screen == "party_battle" and s.to_dict() == locked_paths and panel.valid(), "Menus and modal close cannot dismantle battle")
	panel.leave(); _finish(panel)
	check(not s.battle_active and app.current_screen == "explore", "Flee works for roster size%d" % count)

func _talk(id: String) -> void:
	app.world.teleport(app.world.interactables[id].pos + Vector2(0, 24)); app._process(0)
	await _key(KEY_E)
	check(app.active_modal, "Actual exploration E opens " + id)

func _normal_entries() -> void:
	app.current_screen = "explore"; app.active_modal = false; app._clear_overlay(); app._new_game()
	for id in ["elder", "herb", "healer", "healer"]:
		await _talk(id); await _key(KEY_1)
	check(s.quest_stage == 3 and s.party_roster == ["hero", "shen"], "Opening gains real companion without prepared stats")
	await _talk("bandit"); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle", null)
	check(panel != null and app.current_screen == "party_battle" and panel.commands.groups.size() == 2, "Default opening dialogue enters independent party controller")
	if panel != null:
		panel.art.set_process(false); panel.leave(); _finish(panel)
	_prepare(4)
	await _talk("bandit"); await _key(KEY_1)
	panel = app.overlay.get_meta("party_battle", null)
	check(panel != null and panel.encounter == "training", "Default repeat dialogue enters four-person training")
	if panel != null:
		panel.art.set_process(false); panel.leave(); _finish(panel)
	_prepare(4, "heting_receipt")
	await _talk("heting_scale")
	# The harbor aftermath retains its original branch before the optional errand.
	app.receipt_story.open(); await _key(KEY_1)
	panel = app.overlay.get_meta("party_battle", null)
	check(panel != null and panel.encounter == "heting_receipt", "Default saved receipt dialogue enters real four-person controller")
	if panel != null:
		panel.art.set_process(false); panel.leave(); _finish(panel)

func _targets_and_timing() -> void:
	_prepare(4, "heting_receipt")
	s.hp -= 20 # Prepared injury gives the independent healing action a real target.
	var panel = _open("heting_receipt")
	if panel == null: return
	panel.select_actor("qin"); await _key(KEY_2)
	check(panel.pending_action == "art:qin_shoudu" and not s.party_battle_snapshot().locked, "Shield waits for explicit ally target")
	var before = s.party_battle_snapshot()
	await _key(KEY_ESCAPE)
	check(panel.pending_action.is_empty() and s.party_battle_snapshot() == before, "Escape cancels target mode without cost or flee")
	panel.request_command("qin", "art:qin_shoudu"); panel.select_target("hero")
	check(s.party_battle_snapshot().locked and _actor(s.party_battle_snapshot(), "qin").qi == 3, "Accepted shield costs Qin qi once")
	check(_actor(panel.art.display_snapshot, "hero").status.barrier == 0, "Shield is not visible before presentation event")
	_finish(panel)
	check(_actor(panel.art.display_snapshot, "hero").status.barrier == 18, "Actual event grants visible shield18")
	panel.select_actor("hero"); await _click(panel.unit_plates.bracer)
	check(s.party_battle_snapshot().selected_target_id == "bracer", "Native enemy nameplate click selects its actual target")
	await _key(KEY_1)
	var tx = panel.pending
	check(panel.art.display_snapshot.enemies == tx.before.enemies, "Enemy HP not leaked from resolved after snapshot")
	panel.art._process(.2)
	check(panel.art.acting_unit_id == "hero" and panel.commands.context.acting_unit_id == "hero", "Locked phase uses actual acting source")
	_finish(panel)
	var state_after = s.to_dict(); panel._finished()
	check(s.to_dict() == state_after, "Repeated finish callback cannot settle twice")
	panel.request_command("tang", "guard"); _finish(panel)
	panel.request_command("shen", "guard")
	panel.art._process(1.30); panel.refresh()
	check(panel.art.acting_unit_id == "striker" and panel.commands.context.acting_unit_id == "striker", "Enemy response phase names the actual enemy source")
	check(panel.art.selected_id == "hero" and panel.unit_plates.hero.selected, "Enemy response highlights its actual recipient, not previous guarding ally")
	check(panel.commands.utility_caption(panel.commands.snapshot.active_actor_id,"item").contains("交锋中"), "Medicine has explicit visible action-lock caption during enemy response")
	_finish(panel)
	panel.select_actor("shen"); panel.request_command("shen", "art:shen_xumai")
	check(not panel.pending_action.is_empty(), "Damaged living ally can receive Shen heal")
	panel.cycle_target(); await _key(KEY_ENTER); _finish(panel)
	check(_actor(s.party_battle_snapshot(), "shen").qi == 3, "Shen heal consumes only her own qi")
	panel.leave(); _finish(panel)

func _close_safety() -> void:
	_prepare(4)
	var panel = _open()
	panel.request_command("hero", "attack")
	s.fail_writes = true
	app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(panel.close_pending and app.exits == 0 and s.party_battle_snapshot().locked, "WM close queues until accepted action finishes")
	_finish(panel)
	check(panel.art.is_presenting() and panel.pending.action_id == "flee", "Close queues one real flee after action")
	_finish(panel)
	check(app.current_screen == "explore" and app.save_warning and app.exits == 0 and not s.battle_active, "Save failure retains settled game and never exits")
	var settled = s.to_dict()
	var retry = _button(app.overlay, "重试保存")
	check(retry != null, "Save failure exposes retry")
	if retry != null:
		retry.pressed.emit(); check(s.to_dict() == settled and app.exits == 0, "Failed retry preserves resources/reward identity")
		s.fail_writes = false; _button(app.overlay, "重试保存").pressed.emit()
	check(app.exits == 1 and app.quit_pending and s.to_dict() == settled, "Successful retry exits once without replaying action")

func _victory_settlement() -> void:
	_prepare(4, "heting_receipt")
	var panel = _open("heting_receipt")
	var before_coins = s.coins; var total_xp = s.xp + 30 * s.level * (s.level - 1)
	for step in range(100):
		if not s.battle_active: break
		var snapshot = s.party_battle_snapshot(); var target = ""
		for enemy: Dictionary in snapshot.enemies:
			if enemy.hp > 0 and (target.is_empty() or enemy.id == "bracer"): target = enemy.id
		panel.select_target(target); panel.request_command(snapshot.active_actor_id, "attack"); _finish(panel)
	check(not s.battle_active and s.receipt_stage == 2, "Real four-person controller completes finite receipt encounter")
	check(app.active_modal, "Settled party receipt reaches original narrative result dialogue")
	check(s.coins == before_coins + 40 and s.xp + 30 * s.level * (s.level - 1) == total_xp + 80, "Receipt reward exactly once")
	var after = s.to_dict()
	if is_instance_valid(panel): panel._finished(); panel.request_application_close()
	check(s.to_dict() == after and CombatUI.open(app, "heting_receipt") == null, "Stale completion/reentry cannot farm completed receipt")

func _close_decisions() -> void:
	for branch in ["cancel", "discard", "normal"]:
		_prepare(2)
		var panel = _open()
		var before = s.to_dict()
		s.fail_writes = branch != "normal"
		app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST); _finish(panel)
		check(not s.battle_active and s.to_dict() == before, "Close without action preserves exact resources: " + branch)
		if branch == "normal":
			check(app.exits == 1 and not app.save_warning, "Normal close saves and exits once")
		elif branch == "cancel":
			_button(app.overlay, "返回小憩").pressed.emit()
			await _key(KEY_ESCAPE)
			check(app.exits == 0 and not app.active_modal and app.save_warning, "Cancel failed close resumes playable exploration with warning")
			s.fail_writes = false; app._save()
			check(not app.save_warning and app.exits == 0, "Explicit later save clears warning without exiting")
		else:
			_button(app.overlay, "不保存离开").pressed.emit()
			check(app.exits == 0 and _button(app.overlay, "确认不保存离开") != null, "Discard requires second explicit confirmation")
			_button(app.overlay, "确认不保存离开").pressed.emit()
			check(app.exits == 1 and app.quit_pending, "Confirmed discard exits once")

func _defeat_recovery() -> void:
	_prepare(4, "heting_receipt")
	s.hp = 1
	for id in s.party_resources: s.party_resources[id].hp = 1
	var before_coins = s.coins
	var panel = _open("heting_receipt")
	var saw_downed_hero = false
	for step in range(40):
		if not s.battle_active: break
		var snapshot = s.party_battle_snapshot()
		if _actor(snapshot, "hero").hp == 0:
			saw_downed_hero = true
			check(snapshot.active_actor_id != "hero" and panel.commands.action_reason("hero","attack") == "已倒下", "Downed hero cannot act while living companions continue")
		panel.request_command(snapshot.active_actor_id, "guard"); _finish(panel)
	check(saw_downed_hero and not s.battle_active and s.party_settlement.outcome == "defeat", "Only full selected-party defeat triggers recovery")
	check(s.coins == before_coins - 8 and s.receipt_stage == 1 and app.current_screen == "explore", "Defeat applies bounded coin loss and leaves retryable encounter")
	check(app.world.player_pos == s.position and s.hp == s.max_hp, "Safe recovery position reaches world before next frame")
	for actor: Dictionary in s.party_resource_snapshot().actors:
		check(actor.hp == actor.max_hp and actor.qi >= 2, "Every recruited actor has usable post-defeat recovery")
	var settled = s.to_dict()
	if is_instance_valid(panel): panel._finished()
	check(s.to_dict() == settled, "Repeated defeated controller cannot deduct coins again")

func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = _button(child, text)
		if found != null: return found
	return null
