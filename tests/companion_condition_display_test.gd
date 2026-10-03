extends SceneTree
## Projection/guard tests use isolated no-save state and never modify player files.
const Condition = preload("res://scripts/exploration_companion_condition.gd")
const State = preload("res://scripts/game_state.gd")
const Prefs = preload("res://scripts/view_preferences.gd")
const Scene = preload("res://scenes/main.tscn")
const Fixture = preload("res://tests/party_exploration_fixture.gd")
class NoSave extends State:
	var save_calls: int = 0
	func save_game(_path: String = SAVE_PATH) -> Error:
		save_calls += 1; return OK
	func has_save() -> bool: return false
class NoPrefs extends Prefs:
	func load_settings(_path: String = PATH) -> Error: return OK
	func save_settings(_path: String = PATH) -> Error: return OK
var checks: int = 0
var failures: int = 0
var entries: int = 0
var permit: bool = true
var condition

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func orders(prefix: Array = ["hero"], remaining: Array = ["shen", "tang", "qin"]) -> Array:
	var result: Array = [prefix]
	for id: String in remaining:
		var rest: Array = remaining.duplicate(); rest.erase(id)
		result.append_array(orders(prefix + [id], rest))
	return result
func key(code: int, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code; event.keycode = code; event.pressed = down; event.shift_pressed = shift
		root.push_input(event, true)
		await process_frame
func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): push_error("Use isolated XDG directories"); quit(2); return
	root.size = Vector2i(1179, 736)
	condition = Condition.new()
	condition.position = Vector2(20, 185)
	condition.theme = Theme.new(); condition.theme.default_font = load("res://assets/fonts/NotoSansSC.otf")
	condition.active_guard = func(generation: int): return permit and generation == 31
	condition.entry_requested.connect(func(_generation: int): entries += 1)
	root.add_child(condition)
	await process_frame
	condition.set_context(true, true, 31)
	var s = Fixture.recruited_state()
	s.hp = 0; s.qi = 0
	s.party_resources.shen = {"hp": 0, "qi": 2}
	s.party_resources.tang = {"hp": 1, "qi": 0}
	s.party_resources.qin = {"hp": 3, "qi": 1}
	var all: Array = orders()
	check(all.size() == 16, "All ordered subsets are enumerated")
	for roster: Array in all:
		check(s.set_party_roster(roster), "Real roster accepts " + str(roster))
		var before: Dictionary = s.to_dict().duplicate(true)
		var snapshot: Dictionary = s.party_resource_snapshot()
		condition.refresh_snapshot(snapshot)
		check(condition.displayed_ids == roster.slice(1), "Projection uses validated selected order " + str(roster))
		check(condition.snapshot_valid and not condition.roster_button.disabled, "Valid roster retains direct entry")
		var by_id: Dictionary = {}
		for actor: Dictionary in snapshot.actors: by_id[actor.id] = actor
		for id: String in Condition.IDS:
			var card: Dictionary = condition.cards[id]
			check(card.button.visible == roster.has(id), "Only actually selected actors visible " + id)
			if not roster.has(id): continue
			var actor: Dictionary = by_id[id]
			check(card.hp_bar.value == actor.hp and card.hp_bar.max_value == actor.max_hp, "Real HP bounds " + id)
			check(card.qi_bar.value == actor.qi and card.qi_bar.max_value == actor.max_qi, "Real qi bounds " + id)
			check(card.button.get_meta("downed") == (actor.hp == 0), "Zero HP explicitly represented " + id)
			check((card.status.text == "倒下") == (actor.hp == 0), "Visible state uses words, not color alone " + id)
			card.button.grab_focus(); await process_frame
			check(card.hp_bar.size.y == 5 and card.qi_bar.size.y == 4, "Actual post-theme bars stay thin " + id)
			check(Rect2(Vector2.ZERO, card.button.size).encloses(card.hp_bar.get_rect()) and Rect2(Vector2.ZERO, card.button.size).encloses(card.qi_bar.get_rect()), "Actual post-frame bars stay inside card " + id)
			check(not card.hp_bar.get_rect().intersects(card.qi_bar.get_rect()), "Actual resource bars never overlap " + id)
			check(condition.detail_panel.visible and condition.detail_label.text.contains("气血  %d / %d" % [actor.hp, actor.max_hp]) and condition.detail_label.text.contains("真气  %d / %d" % [actor.qi, actor.max_qi]), "Keyboard details show exact resources " + id)
			check(Rect2(Vector2.ZERO, condition.detail_panel.size).encloses(condition.detail_label.get_rect()) and condition.detail_label.position.y + condition.detail_label.size.y <= condition.detail_panel.size.y - 8, "Shaped exact-detail text retains bottom padding " + id)
			for area: Rect2 in condition.reserved_rects():
				check(Rect2(0, 0, 1179, 736).encloses(area), "Compact visible controls/details bounded")
				check(not area.intersects(Rect2(330, 182, 620, 58)), "Compact controls/details avoid save warning toast")
		check(s.to_dict() == before, "View/focus never mutates real state " + str(roster))
	check(s.set_party_roster(["hero", "qin", "shen", "tang"]), "Prepare focus order")
	condition.refresh_snapshot(s.party_resource_snapshot())
	for button: Button in condition._all_buttons(): button.release_focus()
	await key(KEY_TAB)
	check(condition.cards.qin.button.has_focus(), "Tab starts at actual first selected companion")
	await key(KEY_TAB); check(condition.cards.shen.button.has_focus(), "Tab follows roster order")
	await key(KEY_TAB, true); check(condition.cards.qin.button.has_focus(), "Shift-Tab follows reverse roster order")
	await key(KEY_RIGHT)
	check(root.gui_get_focus_owner() == null and not condition.detail_panel.visible, "Arrow releases focus/detail before world movement")
	condition.cards.tang.button.grab_focus(); await key(KEY_E)
	check(root.gui_get_focus_owner() == null, "E releases focus instead of entering the folio")
	condition.cards.qin.button.grab_focus(); await key(KEY_ENTER)
	check(entries == 1, "Focused Enter activates once")
	await key(KEY_SPACE); check(entries == 2, "Focused Space activates once")
	condition._activate(30); check(entries == 2, "Obsolete callback generation cannot open")
	permit = false; condition._activate(31); check(entries == 2, "Live host guard rejects blocked context")
	permit = true
	for pair: Array in [[true, false], [false, true]]:
		condition.set_context(pair[0], pair[1], 31); condition._activate(31)
		check(entries == 2 and not condition.detail_panel.visible, "Modal/hidden context is inert")
	condition.set_context(true, true, 31)
	var valid: Dictionary = s.party_resource_snapshot().duplicate(true)
	var invalids: Array = [{}, {"ok": false, "actors": []}, {"ok": true, "roster": "hero", "actors": []}]
	var bad: Dictionary = valid.duplicate(true); bad.roster.append("qin"); invalids.append(bad)
	bad = valid.duplicate(true); bad.actors[1].selected = false; invalids.append(bad)
	bad = valid.duplicate(true); bad.actors[1].recruited = false; invalids.append(bad)
	bad = valid.duplicate(true); bad.actors[1].hp = -1; invalids.append(bad)
	bad = valid.duplicate(true); bad.actors[1].qi = 999; invalids.append(bad)
	bad = valid.duplicate(true); bad.actors[1].hp = 1.5; invalids.append(bad)
	bad = valid.duplicate(true); bad.actors.append(bad.actors[1]); invalids.append(bad)
	for invalid: Dictionary in invalids:
		condition.refresh_snapshot(invalid)
		check(not condition.snapshot_valid and condition.displayed_ids.is_empty() and condition.roster_button.disabled, "Malformed snapshot fails closed")
		for card: Dictionary in condition.cards.values():
			check(not card.button.visible and card.hp_bar.value == 0 and card.qi_bar.value == 0, "Invalid projection clears stale bars")
		condition._activate(31); check(entries == 2, "Malformed snapshot cannot open")
		condition.refresh_snapshot(valid)
		check(condition.snapshot_valid and condition.displayed_ids == ["qin", "shen", "tang"], "Recovery reprojects real selected order")
	for button: Button in condition._all_buttons(): button.release_focus()
	condition._hovered = ""
	var actor_rects: Array[Rect2] = [Rect2(condition.position + condition.cards.tang.button.position, condition.cards.tang.button.size)]
	condition.update_occlusion(actor_rects, 1.0)
	check(is_equal_approx(condition.cards.tang.button.modulate.a, .23) and condition.cards.qin.button.modulate.a == 1.0, "Occlusion fades only overlapped control")
	condition.cards.tang.button.grab_focus(); condition.update_occlusion(actor_rects, 1.0)
	check(condition.cards.tang.button.modulate.a == 1.0, "Focused condition remains readable during overlap")
	var revision: int = condition.navigation_revision
	condition.cards.tang.button.release_focus()
	check(condition.navigation_revision > revision, "Detail visibility invalidates navigation exclusions")
	condition.queue_free(); await process_frame
	await test_host_entry()
	print("%s companion_condition_display: %d checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func test_host_entry() -> void:
	var app = Scene.instantiate(); app.state = NoSave.new(); app.view_preferences = NoPrefs.new()
	root.add_child(app); await process_frame
	app._new_game(); app._stop_audio(); app.audio_on = false
	app.set_process(false); app.world.set_process(false)
	Fixture.recruited_state(["hero", "qin", "shen", "tang"], app.state)
	app.state.map_id = app.world.map_id; app.state.position = app.world.player_pos
	app.state.hp = 0; app.state.party_resources.qin.hp = 0; app._refresh()
	var before: Dictionary = app.state.to_dict().duplicate(true)
	var saves: int = app.state.save_calls
	var stale: Callable = app.hud.companion_condition.roster_button.get_signal_connection_list("pressed")[0].callable
	for index: int in range(3):
		app._show_exploration_party_roster(app.modal_generation); await process_frame
		var folio = app.overlay.get_meta("party_roster", null)
		check(folio != null and folio.return_button.text == "继续赶路", "Direct roster explicitly returns to exploration")
		await key(KEY_ESCAPE)
		check(not app.active_modal and not app.overlay.get_meta("inventory", false), "Esc goes directly to exploration")
	check(app.state.save_calls == saves and app.state.to_dict() == before, "Repeated read/cancel/reopen neither saves nor heals at hero HP0")
	stale.call(); check(not app.active_modal, "Old HUD callback remains inert after a full modal roundtrip")
	for screen: String in ["title", "battle", "party_battle", "receipt_battle"]:
		app.current_screen = screen; app.hud.tick(0)
		app._show_exploration_party_roster(app.modal_generation)
		check(not app.active_modal and not app.hud.companion_condition.visible, "Other screen hides and blocks direct entry: " + screen)
	app.current_screen = "explore"; app.quit_pending = true; app.hud.tick(0)
	app._show_exploration_party_roster(app.modal_generation)
	check(not app.active_modal and app.hud.companion_condition.roster_button.disabled, "Quit blocks entry and disables controls")
	app.quit_pending = false; app._show_inventory(); app.hud.tick(0)
	app._show_exploration_party_roster(app.modal_generation)
	check(app.overlay.get_meta("inventory", false) and not app.overlay.has_meta("party_roster"), "Underlying direct entry cannot replace another modal")
	app.modal_autosave_on_close = false; app._close_modal()
	app.state.battle_active = true; app.hud.tick(0); app._show_exploration_party_roster(app.modal_generation)
	check(not app.active_modal and app.hud.companion_condition.roster_button.disabled, "Battle flag blocks even when screen still says exploration")
	app.state.battle_active = false; app._refresh()
	app._show_exploration_party_roster(app.modal_generation); await process_frame
	var folio = app.overlay.get_meta("party_roster")
	for id: String in ["shen", "tang", "qin"]:
		folio._open_story(id); await process_frame
		check(app.overlay.get_meta("party_roster_direct_info", false), "Story remembers direct entry origin " + id)
		var stale_return: Callable = app.modal_actions[0]
		app.modal_actions[0].call(); await process_frame
		folio = app.overlay.get_meta("party_roster")
		check(folio.return_button.text == "继续赶路", "Story returns to same direct-origin folio " + id)
		stale_return.call(); check(app.overlay.get_meta("party_roster") == folio, "Story callback generation cannot replace newer folio")
	folio.close(); await process_frame
	check(app.state.save_calls == saves and app.state.to_dict() == before, "All read-only direct info roundtrips remain save/state-neutral")
	app.queue_free(); await process_frame
	check(not FileAccess.file_exists(State.SAVE_PATH), "No real player save was written")
