extends SceneTree
## Isolated real-state UI checks. Main save calls use a counting adapter; no player save file is written.
const State = preload("res://scripts/game_state.gd")
const Roster = preload("res://scripts/party_roster_ui.gd")
const Portraits = preload("res://scripts/character_portraits.gd")
class RosterTestState extends State:
	var fail_saves: bool = false
	var save_calls: int = 0
	var saved_data: Dictionary = {}
	func save_game(_path: String = SAVE_PATH) -> Error:
		save_calls += 1
		if fail_saves: return ERR_FILE_CANT_WRITE
		saved_data = to_dict().duplicate(true)
		return OK
	func has_save() -> bool: return false
var checks: int = 0
var failures: int = 0
var changes: int = 0
var returns: int = 0
var stories: Array[String] = []
var generation: int = 1
var menu


func _initialize() -> void: run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)


func mount(s, with_stories: bool = true):
	var page = Roster.new()
	page.size = Vector2(1280, 800)
	var callbacks: Dictionary = {}
	if with_stories:
		for id: String in ["shen", "tang", "qin"]: callbacks[id] = func(): stories.append(id)
	var captured: int = generation
	page.bind_state(s, callbacks, func(): returns += 1, func(): changes += 1, func(): return generation == captured)
	root.add_child(page)
	return page


func recruit_all(s = null):
	if s == null: s = State.new()
	check(s.recruit_companion(), "Shen recruited through real invitation")
	s.chapter_two_stage = 4; s.bridge_repaired = true
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Tang recruited through actual personal quest")
	s.map_id = "mistwood"; s.mist_stage = 4; s.mist_ending = "release_water"
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Qin recruited through actual handoff and invitation")
	return s


func resources(s) -> Dictionary:
	return {"hero": {"hp": s.hp, "qi": s.qi}, "companions": s.party_resources.duplicate(true)}


func labels(node: Node) -> String:
	var text: String = node.text if node is Label else ""
	for child: Node in node.get_children(): text += "\n" + labels(child)
	return text


func geometry(size: Vector2) -> void:
	menu.size = size
	menu._layout()
	check(Rect2(Vector2.ZERO, size).encloses(menu.frame.get_rect()), "Frame bounded at " + str(size))
	var prior: Array[Rect2] = []
	for id: String in Roster.IDS:
		var cell: Dictionary = menu.cells[id]
		check(Rect2(Vector2.ZERO, menu.frame.size).encloses(cell.panel.get_rect()), "Card stays on page: " + id)
		for earlier: Rect2 in prior:
			check(not earlier.intersects(cell.panel.get_rect()), "Actor sections never overlap: " + id)
		prior.append(cell.panel.get_rect())
		for child: Node in cell.panel.get_children():
			if child is Control and child.visible:
				check(Rect2(Vector2.ZERO, cell.panel.size).encloses(child.get_rect()), "Card content is bounded: " + id + "/" + child.name)
		check(cell.toggle.size.y >= 38, "Native toggle has a usable click target")
	for child: Node in menu.frame.get_children():
		if child is Control and child.visible: check(Rect2(Vector2.ZERO, menu.frame.size).encloses(child.get_rect()), "Page content is bounded: " + child.name)
	var hero: Rect2 = menu.cells.hero.panel.get_rect()
	var previous_bottom: float = -1
	for id: String in ["shen", "tang", "qin"]:
		var row: Rect2 = menu.cells[id].panel.get_rect()
		check(row.position.x >= hero.end.x, "Companion rows occupy the right-hand leaf: " + id)
		check(row.position.y >= previous_bottom, "Fixed display order stays Shen, Tang, Qin: " + id)
		previous_bottom = row.end.y
		check(not menu.cells[id].toggle.get_rect().intersects(menu.cells[id].story.get_rect()), "Actor action targets never overlap: " + id)
	check(not menu.notice.get_rect().intersects(menu.return_button.get_rect()), "Notice and return have separate space")
	if menu.retry_button.visible:
		check(not menu.notice.get_rect().intersects(menu.retry_button.get_rect()), "Failure notice and retry have separate space")
		check(not menu.retry_button.get_rect().intersects(menu.return_button.get_rect()), "Retry and return targets remain separate")
	var node_count: int = menu.find_children("*", "", true, false).size()
	for repeat in range(4): menu.refresh()
	check(menu.find_children("*", "", true, false).size() == node_count, "Refresh cannot accumulate decoration or control nodes")


func key(code: int, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code; event.keycode = code; event.pressed = pressed; event.shift_pressed = shift
		root.push_input(event, true)
		await process_frame


func click(button: Button) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = motion.position; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func test_main_integration() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	check(game.has_method("_show_party_roster"), "Real main scene exposes the roster entry point")
	if not game.has_method("_show_party_roster"): game.free(); return
	game.state = RosterTestState.new()
	root.add_child(game)
	await process_frame
	game._new_game(); game._stop_audio(); game.audio_on = false
	game.world.set_process(false)
	await key(KEY_I); await key(KEY_5)
	var folio = game.overlay.get_meta("party_roster", null)
	check(folio != null and game.active_modal and game.modal_actions.is_empty(), "Actual I then 5 mounts folio with legacy modal choices cleared")
	if folio == null: game.queue_free(); await process_frame; return
	check(folio.return_button.has_focus(), "Real host retains safe native initial focus")
	await key(KEY_ESCAPE)
	check(game.active_modal and game.overlay.get_meta("inventory", false) and not game.overlay.has_meta("party_roster"), "Folio Escape returns to inventory without falling through to close it")
	await key(KEY_5); await key(KEY_ENTER)
	check(game.overlay.get_meta("inventory", false), "Focused native Enter returns from solo folio exactly once")
	await key(KEY_4)
	check(not game.active_modal, "Inventory's existing close shortcut returns to exploration")
	for id: String in ["shen", "tang", "qin"]:
		game._show_party_roster(); await process_frame
		folio = game.overlay.get_meta("party_roster")
		var before: Dictionary = game.state.to_dict()
		folio.cells[id].story.grab_focus(); await key(KEY_ENTER)
		check(game.active_modal and not game.overlay.has_meta("party_roster"), "Actual supplied callback opens " + id + " information")
		check(game.state.to_dict() == before, "Reading uninvited " + id + " never advances or grants actors")
		await key(KEY_1)
		check(game.overlay.has_meta("party_roster") and game.state.to_dict() == before, "Info return restores roster without advancing " + id)
	game._close_modal()
	var s = game.state
	s.map_id = "mistwood"; s.mist_stage = 4; s.mist_ending = "release_water"
	for advance: Callable in [s.begin_qin_quest, s.inspect_qin_rope, s.arrange_qin_handoff]:
		check(advance.call(), "Prepared Qin's next actual personal quest stage")
		game._show_party_roster(); await process_frame
		folio = game.overlay.get_meta("party_roster")
		var before: Dictionary = s.to_dict()
		folio.cells.qin.story.grab_focus(); await key(KEY_ENTER); await key(KEY_1)
		check(s.to_dict() == before and not s.qin_recruited(), "Reading and returning at Qin stage %d never completes the next step" % s.qin_stage)
	game._new_game()
	recruit_all(game.state)
	s = game.state
	s.map_id = game.world.map_id; s.position = game.world.player_pos
	s.hp = 37; s.qi = 1
	s.party_resources.shen = {"hp": 0, "qi": 2}
	s.party_resources.tang = {"hp": 41, "qi": 0}
	s.party_resources.qin = {"hp": 62, "qi": 3}
	game._refresh(); game._show_inventory(); await key(KEY_5)
	folio = game.overlay.get_meta("party_roster")
	var original: Dictionary = resources(s)
	var saves: int = s.save_calls
	folio.cells.shen.toggle.grab_focus(); await key(KEY_ENTER)
	check(game.overlay.get_meta("party_roster") == folio and not s.party_roster.has("shen") and s.save_calls == saves + 1, "Real selection saves once and leaves the same roster page visible")
	check(resources(s) == original and folio.cells.shen.status.text == "候阵 · 倒下", "Main-scene bench preserves exact downed resources")
	await key(KEY_SPACE)
	check(s.party_roster.has("shen") and resources(s) == original, "Real repeated toggle rejoins without healing")
	s.fail_saves = true
	folio.cells.tang.toggle.grab_focus(); await key(KEY_ENTER)
	check(game.save_warning and not s.party_roster.has("tang") and game.overlay.get_meta("party_roster") == folio, "Failed autosave preserves accepted selection and open roster")
	check(folio.notice.is_visible_in_tree() and folio.notice.text.contains("未存妥") and folio.notice.text.contains("重试保存") and folio.retry_button.is_visible_in_tree(), "Actual save failure is surfaced inside the modal with retry control")
	saves = s.save_calls
	await click(folio.formation_buttons[s.formation])
	check(s.save_calls == saves and game.save_warning and folio.retry_button.visible and resources(s) == original, "Selecting the same formation preserves warning and cannot trigger saving or healing")
	menu = folio; geometry(Vector2(1280, 800)); geometry(Vector2(1179, 737))
	folio.size = Vector2(1280, 800); folio._layout()
	var failed_roster: Array = s.party_roster.duplicate()
	await key(KEY_ESCAPE); await key(KEY_5)
	folio = game.overlay.get_meta("party_roster")
	check(folio.notice.text.contains("未存妥") and folio.retry_button.visible and s.party_roster == failed_roster, "Reopening preserves pending failure notice and selected roster")
	saves = s.save_calls
	await click(folio.retry_button)
	check(s.save_calls == saves + 1 and game.save_warning and folio.retry_button.visible and s.party_roster == failed_roster and resources(s) == original, "Repeated failed retry only retries save; it cannot heal or change membership")
	s.fail_saves = false; saves = s.save_calls
	await click(folio.retry_button)
	check(s.save_calls == saves + 1 and not game.save_warning and not folio.retry_button.visible and not folio.notice.text.contains("重试保存"), "Successful actual retry clears warning and hides retry control")
	check(game.overlay.get_meta("party_roster") == folio and s.saved_data == s.to_dict() and resources(s) == original and s.party_roster == failed_roster, "Retry persists exact accepted roster while keeping it visible")
	check(folio.return_button.has_focus(), "Successful retry moves focus off its hidden button to visible return")
	s.fail_saves = true
	folio.cells.qin.toggle.grab_focus(); await key(KEY_ENTER)
	check(game.save_warning, "Second failed selection prepares native F5 retry")
	s.fail_saves = false; saves = s.save_calls
	await key(KEY_F5)
	check(not game.save_warning and not folio.retry_button.visible and s.save_calls == saves + 1 and resources(s) == original, "Host F5 routes to real in-folio save retry")
	for id: String in ["shen", "tang", "qin"]:
		var before: Dictionary = s.to_dict()
		folio.cells[id].story.grab_focus(); await key(KEY_ENTER); await key(KEY_1)
		folio = game.overlay.get_meta("party_roster")
		check(s.to_dict() == before, "Recruited " + id + " information is read-only and returns to roster")
	var before: Dictionary = s.to_dict()
	game._show_inventory()
	folio._toggle_actor("tang"); folio.retry_save(); folio._open_story("qin")
	check(s.to_dict() == before and game.overlay.get_meta("inventory", false), "Detached old folio callbacks cannot affect replacement inventory")
	game._close_modal(); s.battle_active = true
	game._show_party_roster()
	check(not game.active_modal and not game.overlay.has_meta("party_roster"), "Real main refuses roster entry while battle flag is set")
	s.battle_active = false; game.current_screen = "party_battle"
	game._show_party_roster()
	check(not game.overlay.has_meta("party_roster"), "Real main also refuses roster entry on party battle screen")
	game.current_screen = "explore"
	game._stop_audio(); game.queue_free()
	await process_frame
	check(not FileAccess.file_exists(State.SAVE_PATH), "Real-scene adapter never writes ordinary player saves")


func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): push_error("Use isolated XDG directories"); quit(2); return
	root.size = Vector2i(1280, 800)
	var fresh = State.new()
	var before: Dictionary = fresh.to_dict()
	menu = mount(fresh)
	await process_frame
	check(fresh.to_dict() == before, "Opening the roster does not mutate or advance a fresh save")
	check(menu.cells.size() == 4 and menu.displayed_snapshot.actors.size() == 1, "Four visible slots create only the real hero")
	check(menu.cells.hero.toggle.disabled and menu.cells.hero.toggle.text == "主角在队", "Hero cannot leave")
	check(menu.return_button.has_focus(), "Solo opening focuses safe return")
	for id: String in ["shen", "tang", "qin"]:
		var cell: Dictionary = menu.cells[id]
		check(not cell.panel.get_meta("recruited") and cell.empty.visible and not cell.portrait.visible and cell.portrait.texture == null, "Unrecruited slot stays visibly empty: " + id)
		check(cell.toggle.disabled and cell.hint.visible and not cell.hp.visible and not cell.qi.visible and not cell.actions.visible, "Locked slot has no invented resources/actions: " + id)
		menu._toggle_actor(id)
	check(fresh.to_dict() == before, "Even direct calls cannot select unrecruited actors")
	check(menu.formation_buttons["并肩"].disabled and menu.formation_buttons["护后"].disabled, "Solo party cannot change formation")
	menu._choose_formation("护后"); menu._toggle_actor("hero"); menu._toggle_actor("unknown")
	check(fresh.to_dict() == before, "Solo formation and invalid/hero toggles are no-ops")
	geometry(Vector2(1280, 800)); geometry(Vector2(1179, 737))
	menu._open_story("qin")
	check(stories == ["qin"] and fresh.to_dict() == before, "A supplied story-info callback only opens once and never recruits")
	menu._open_story("qin"); menu.close()
	check(stories == ["qin"] and returns == 0, "Story navigation invalidates all old actions")
	menu.free()
	var s = recruit_all()
	s.hp = 37; s.qi = 1
	s.party_resources.shen = {"hp": 0, "qi": 2}
	s.party_resources.tang = {"hp": 41, "qi": 0}
	s.party_resources.qin = {"hp": 62, "qi": 3}
	var original_resources = resources(s)
	before = s.to_dict()
	menu = mount(s)
	await process_frame
	check(s.to_dict() == before and menu.displayed_snapshot.actors.size() == 4, "Opening all four preserves every resource and story stage")
	check(menu.cells.shen.status.text == "在队 2 · 倒下" and menu.cells.shen.hp.text == "气血  0 / 82", "Downed actor displays actual zero HP and roster position")
	check(menu.cells.tang.qi.text == "真气  0 / 6" and menu.cells.qin.qi.text == "真气  3 / 6", "Each companion has independent exact qi")
	for id: String in Roster.IDS:
		check(menu.cells[id].portrait.texture.region == Portraits.texture_for(id).region, "Original matching portrait: " + id)
		check(menu.cells[id].toggle.focus_mode == Control.FOCUS_ALL, "Native accessible focusable toggle: " + id)
	check(labels(menu).contains("青灯渡脉") and labels(menu).contains("分劲尺") and labels(menu).contains("守渡横杖"), "Each recruited actor shows its real martial action")
	geometry(Vector2(1280, 800)); geometry(Vector2(1179, 737))
	menu.size = Vector2(1280, 800); menu._layout(); menu.refresh()
	menu.cells.shen.toggle.grab_focus()
	await key(KEY_ENTER)
	check(not s.party_roster.has("shen") and menu.cells.shen.status.text == "候阵 · 倒下", "Native Enter benches exactly the focused companion")
	check(menu.cells.shen.toggle.has_focus(), "In-place refresh retains keyboard focus")
	check(resources(s) == original_resources, "Benching does not revive or refill anyone")
	await key(KEY_SPACE)
	check(s.party_roster.has("shen") and resources(s) == original_resources, "Native Space reselects downed companion without healing")
	check(menu.cells.shen.panel.get_meta("roster_order") == 4 and menu.cells.shen.status.text == "在队 4 · 倒下", "Reselected actor shows true appended order instead of implying fixed card order")
	await key(KEY_TAB)
	check(menu.cells.shen.story.has_focus(), "Tab reaches corresponding story information")
	await key(KEY_TAB, true)
	check(menu.cells.shen.toggle.has_focus(), "Shift-Tab returns to toggle")
	await key(KEY_RIGHT)
	check(menu.cells.shen.story.has_focus(), "Arrow navigation uses native focus neighbors")
	await click(menu.cells.tang.toggle)
	check(not s.party_roster.has("tang") and s.party_roster.has("shen") and resources(s) == original_resources, "Mouse selection changes only its targeted actor")
	await click(menu.cells.tang.toggle)
	check(s.party_roster.size() == 4 and resources(s) == original_resources, "Hero plus all three recruited companions can be selected together")
	await click(menu.formation_buttons["护后"])
	check(s.formation == "护后" and menu.formation_buttons["护后"].button_pressed and resources(s) == original_resources, "Explicit formation selection preserves exact resources")
	var change_count: int = changes
	await click(menu.formation_buttons["护后"])
	check(changes == change_count and menu.formation_buttons["护后"].button_pressed, "Repeated native selection keeps current formation pressed without mutation")
	menu._choose_formation("并肩")
	check(s.formation == "并肩" and resources(s) == original_resources, "Both real formations remain available")
	before = s.to_dict()
	s.battle_active = true; menu.refresh()
	for id: String in ["shen", "tang", "qin"]:
		check(menu.cells[id].toggle.disabled and menu.cells[id].story.disabled, "Battle disables actor/story controls: " + id)
		menu._toggle_actor(id); menu._open_story(id)
	menu._choose_formation("护后")
	check(s.to_dict() == before and stories == ["qin"], "Battle guard also rejects direct stale calls")
	s.battle_active = false; menu.refresh()
	generation += 1
	menu._toggle_actor("qin"); menu._choose_formation("护后"); menu._open_story("qin"); menu.close()
	check(s.to_dict() == before and returns == 0 and stories == ["qin"], "Host generation guard invalidates replaced page actions")
	menu.free()
	menu = mount(s, false)
	await process_frame
	check(menu.cells.shen.story.disabled and menu.cells.tang.story.disabled and menu.cells.qin.story.disabled, "Missing story callbacks cannot invoke quest methods")
	await key(KEY_ESCAPE)
	check(returns == 1, "Native Escape invokes supplied return exactly once")
	menu._toggle_actor("qin"); menu.close()
	check(returns == 1 and s.to_dict() == before, "Closing invalidates repeats and stale toggles")
	menu.free()
	await test_main_integration()
	check(not FileAccess.file_exists(State.SAVE_PATH), "Standalone UI check never writes the normal save")
	print("%s: %d four-member roster checks (real state / empty slots / independent resources / native inputs / geometry / stale guards)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
