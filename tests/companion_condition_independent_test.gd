extends SceneTree
## Independent read-only exploration projection and native-input checks.
## All writes target an owned isolated fixture; no ordinary save/profile is used.
const MainScene = preload("res://scenes/main.tscn")
const Model = preload("res://scripts/game_state.gd")
const Preferences = preload("res://scripts/view_preferences.gd")
const Fixture = preload("res://tests/party_exploration_fixture.gd")
const Portraits = preload("res://scripts/character_portraits.gd")
const UnifiedUI = preload("res://tests/unified_ui_test_driver.gd")
class OwnedState extends Model:
	var writes: int = 0
	var fail_writes: bool = false
	var fixture: String = "user://condition-review-save.json"
	func save_game(_path: String = SAVE_PATH) -> Error:
		writes += 1
		return ERR_CANT_CREATE if fail_writes else super.save_game(fixture)
	func load_game(_path: String = SAVE_PATH) -> Error: return super.load_game(fixture)
	func has_save() -> bool: return FileAccess.file_exists(fixture)
class NoPreferences extends Preferences:
	func load_settings(_path: String = PATH) -> Error: return OK
	func save_settings(_path: String = PATH) -> Error: return OK
var app
var strip
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error("Independent condition: " + label)
func sync() -> void:
	app._process(0)
func combinations(prefix: Array, remaining: Array) -> Array:
	var result: Array = [prefix]
	for id in remaining:
		var rest: Array = remaining.duplicate(); rest.erase(id)
		result.append_array(combinations(prefix + [id], rest))
	return result
func memory_and_disk() -> Dictionary:
	return {"state": app.state.to_dict().duplicate(true), "writes": app.state.writes,
		"bytes": FileAccess.get_file_as_bytes(app.state.fixture)}
func unchanged(before: Dictionary, label: String) -> void:
	check(app.state.to_dict() == before.state and app.state.writes == before.writes and FileAccess.get_file_as_bytes(app.state.fixture) == before.bytes, label)
func event_key(code: int, down: bool, shift: bool = false) -> void:
	var e = InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down; e.shift_pressed = shift
	Input.parse_input_event(e)
	await process_frame
	sync()
func key(code: int, shift: bool = false) -> void:
	await event_key(code, true, shift); await event_key(code, false, shift)
func click(button: Button) -> void:
	var motion = InputEventMouseMotion.new(); motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true); await process_frame
	for down: bool in [true, false]:
		var e = InputEventMouseButton.new(); e.position = motion.position; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
		root.push_input(e, true); await process_frame; sync()
func check_values(label: String) -> void:
	var snapshot: Dictionary = app.state.party_resource_snapshot()
	check(snapshot.ok, label + " valid source")
	if not snapshot.ok: return
	var selected: Array = snapshot.roster.slice(1)
	check(strip.displayed_ids == selected, label + " exact selected order")
	for index: int in selected.size():
		var button: Button = strip.cards[selected[index]].button
		check(button.visible and button.position.x == index * 103, label + " actual ordered card position " + selected[index])
		if index > 0:
			check(not button.get_rect().intersects(strip.cards[selected[index - 1]].button.get_rect()), label + " adjacent cards never overlap")
	for id: String in ["shen", "tang", "qin"]:
		check(strip.cards[id].button.visible == selected.has(id), label + " only selected cards occupy HUD " + id)
	for actor: Dictionary in snapshot.actors:
		if actor.id == "hero" or not selected.has(actor.id): continue
		var c: Dictionary = strip.cards[actor.id]
		check(c.hp_bar.value == actor.hp and c.hp_bar.max_value == actor.max_hp and c.qi_bar.value == actor.qi and c.qi_bar.max_value == actor.max_qi, label + " exact resources " + actor.id)
		check(Rect2(Vector2.ZERO, c.button.size).encloses(c.hp_bar.get_rect()) and Rect2(Vector2.ZERO, c.button.size).encloses(c.qi_bar.get_rect()), label + " actual post-theme resource bars stay inside card " + actor.id)
		check(not c.hp_bar.get_rect().intersects(c.qi_bar.get_rect()) and c.hp_bar.size.y <= 5.001 and c.qi_bar.size.y <= 4.001, label + " actual post-theme resource bars remain thin and separate " + actor.id)
		check(c.portrait.texture is AtlasTexture and c.portrait.texture.region == Portraits.texture_for(actor.id).region, label + " original portrait " + actor.id)
		if actor.hp == 0: check(c.status.text.contains("倒下"), label + " explicit downed " + actor.id)
		var detail: String = String(c.button.get_meta("condition_detail", ""))
		check(detail.contains("气血  %d / %d" % [actor.hp, actor.max_hp]) and detail.contains("真气  %d / %d" % [actor.qi, actor.max_qi]), label + " exact readable details " + actor.id)
func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): push_error("Use isolated XDG directories"); quit(2); return
	root.size = Vector2i(1280, 800)
	app = MainScene.instantiate(); app.state = OwnedState.new(); app.view_preferences = NoPreferences.new()
	root.add_child(app); await process_frame
	app._new_game(); app._stop_audio(); app.audio_on = false; app.set_process(false); app.world.set_process(false)
	strip = app.hud.companion_condition
	check(strip != null, "actual main HUD mounts condition component")
	if strip == null: app.queue_free(); quit(1); return
	sync(); check(strip.displayed_ids.is_empty(), "new uninvited state has no phantom companions")
	Fixture.recruited_state(["hero", "qin", "shen", "tang"], app.state)
	app.state.map_id = "qingwei"; app.world.change_map("qingwei", Vector2(600, 450)); app.state.position = app.world.player_pos
	app.state.hp = 39; app.state.qi = 1
	app.state.party_resources.shen = {"hp": 0, "qi": 2}
	app.state.party_resources.tang = {"hp": 29, "qi": 0}
	app.state.party_resources.qin = {"hp": 43, "qi": 3}
	app._refresh(); sync()
	for roster: Array in combinations(["hero"], ["shen", "tang", "qin"]):
		check(app.state.set_party_roster(roster), "real model accepts ordered subset " + str(roster))
		app._refresh()
		var before: Dictionary = memory_and_disk()
		for repeat in range(3): sync()
		check_values("ordered subset " + str(roster))
		unchanged(before, "repeated projection never writes/heals " + str(roster))
	app.state.set_party_roster(["hero", "qin", "shen", "tang"]); app._refresh(); sync()
	var before: Dictionary = memory_and_disk()
	strip.cards.shen.button.grab_focus(); await process_frame; sync()
	check(strip.detail_panel.is_visible_in_tree() and strip.detail_label.text.contains("沈青") and strip.detail_label.text.contains("0") and strip.detail_label.text.contains("2"), "keyboard focus gives readable real downed details")
	check_values("focused")
	unchanged(before, "focus/details preserve live and disk state")
	await key(KEY_TAB); check(strip.cards.tang.button.has_focus(), "Tab advances along actual reordered companion list")
	await key(KEY_TAB, true); check(strip.cards.shen.button.has_focus(), "Shift-Tab reverses only active controls")
	# Arrows are world controls, deliberately releasing condition focus first.
	var pos: Vector2 = app.world.player_pos
	await event_key(KEY_RIGHT, true); app.world._process(.05); sync()
	check(not strip.cards.shen.button.has_focus() and not strip.detail_panel.is_visible_in_tree(), "movement arrow releases strip focus/details before world movement")
	check(app.world.player_pos.x > pos.x, "movement arrow still moves the world after focus release")
	await event_key(KEY_RIGHT, false)
	# Actual pointer events show and dismiss the same exact resource details.
	var hover = InputEventMouseMotion.new(); hover.position = strip.cards.qin.button.get_global_rect().get_center()
	root.push_input(hover, true); await process_frame; sync()
	check(strip.detail_panel.is_visible_in_tree() and strip.detail_label.text.contains("秦禾") and strip.detail_label.text.contains("气血  43 /"), "native pointer hover shows exact Qin condition")
	hover = InputEventMouseMotion.new(); hover.position = Vector2(700, 450)
	root.push_input(hover, true); await process_frame; sync()
	check(not strip.detail_panel.is_visible_in_tree(), "native pointer exit clears hover details")
	# Read-only direct entry and Escape must preserve bytes and unsaved changes.
	for iteration in range(3):
		before = memory_and_disk(); await click(strip.roster_button)
		check(app.overlay.has_meta("party_roster") and app.active_modal, "direct native roster entry")
		var folio = app.overlay.get_meta("party_roster", null)
		if folio == null: break
		check(folio.return_button.text.contains("赶路") or folio.return_button.text.contains("探索"), "direct folio communicates exploration return")
		await key(KEY_ESCAPE)
		check(not app.active_modal and not app.overlay.has_meta("inventory") and not app.overlay.has_meta("party_roster"), "direct Escape returns to exploration exactly once")
		unchanged(before, "direct repeat/view/cancel does not save or mutate")
	# Native Enter on strip cannot also trigger the nearby NPC.
	app.world.nearby_id = "elder"; app.world.nearby_name = "陆伯"
	strip.roster_button.grab_focus(); before = memory_and_disk(); await key(KEY_ENTER)
	check(app.overlay.has_meta("party_roster"), "Enter activates focused strip entry without NPC fall-through")
	unchanged(before, "Enter entry preserves resources and save bytes")
	var folio = app.overlay.get_meta("party_roster", null)
	if folio != null:
		# Held movement is suppressed while any modal is open.
		pos = app.world.player_pos; await event_key(KEY_RIGHT, true); app.world._process(.08); sync()
		check(app.world.player_pos == pos and app.active_modal, "held movement cannot leak through roster modal")
		await event_key(KEY_RIGHT, false); await key(KEY_ESCAPE)
	for activation: int in [KEY_SPACE, KEY_KP_ENTER]:
		strip.roster_button.grab_focus(); before = memory_and_disk(); await key(activation)
		check(app.overlay.has_meta("party_roster"), "native alternate activation opens only roster " + str(activation))
		folio = app.overlay.get_meta("party_roster", null)
		if folio != null:
			await key(KEY_TAB)
			var owner: Control = root.gui_get_focus_owner()
			check(owner != null and folio.is_ancestor_of(owner) and not strip.is_ancestor_of(owner), "modal Tab cannot enter inactive exploration controls")
			await key(KEY_ESCAPE)
		unchanged(before, "alternate activation/cancel does not save")
	strip.cards.shen.button.grab_focus(); app.world.nearby_id = "elder"; app.world.nearby_name = "陆伯"; await key(KEY_E)
	check(app.active_modal and not app.overlay.has_meta("party_roster") and app.overlay.find_child("DialogueTitle", true, false).text.contains("陆伯"), "E releases strip focus and retains ordinary NPC interaction")
	app.modal_autosave_on_close = false; app._close_modal(); sync()
	for id: String in ["shen", "tang", "qin"]:
		await click(strip.roster_button); folio = app.overlay.get_meta("party_roster", null)
		if folio == null: check(false, "folio available for story " + id); break
		before = memory_and_disk(); folio.cells[id].story.grab_focus(); await key(KEY_ENTER)
		check(app.active_modal and not app.overlay.has_meta("party_roster"), "story info opens " + id)
		var old_back: Callable = app.modal_actions[0]
		var old_close: Callable = app.modal_actions[1]
		await key(KEY_1); check(app.overlay.has_meta("party_roster"), "story returns to direct folio " + id)
		var returned_generation: int = app.modal_generation
		old_back.call(); old_close.call()
		check(app.modal_generation == returned_generation and app.overlay.has_meta("party_roster"), "stale info back/close callbacks cannot replace returned folio " + id)
		await key(KEY_ESCAPE); check(not app.active_modal, "story round trip returns to exploration " + id)
		old_back.call(); old_close.call()
		check(not app.active_modal, "detached info callbacks cannot reopen exploration " + id)
		unchanged(before, "story view/back is read-only " + id)
	# Resource changes do not depend on the follower membership signature.
	app.state.party_resources.qin.hp = 17; app.state.party_resources.qin.qi = 0; app._refresh(); sync(); check_values("direct resource change")
	app._healer_dialogue(); await key(KEY_1); sync(); check_values("real healer rest freshness")
	app.state.gain_xp(400); app._refresh(); sync(); check_values("level growth freshness")
	check(app.state.save_game() == OK, "owned fixture save prepares load freshness")
	app.state.party_resources.qin.hp = 3; app.state.set_party_roster(["hero", "tang"]); sync()
	app._load(); sync(); check_values("real load freshness")
	check(strip.displayed_ids == ["qin", "shen", "tang"], "actual load restores deployed ordering")
	# Invalid state must clear stale values, then recover when state is corrected.
	var original: Dictionary = app.state.party_resources.shen.duplicate()
	app.state.party_resources.shen.hp = -1; app._refresh(); sync()
	check(strip.displayed_ids.is_empty() and not strip.detail_panel.is_visible_in_tree(), "invalid snapshot removes previous actor values/details")
	app.state.party_resources.shen = original; app._refresh(); sync(); check_values("invalid snapshot recovery")
	# Host guards own modal replacement and pending application quit.
	var callback: Callable = strip.roster_button.pressed.get_connections()[0].callable
	app._show_journal(); var generation: int = app.modal_generation; before = memory_and_disk(); callback.call(); sync()
	check(app.modal_generation == generation and not app.overlay.has_meta("party_roster"), "old strip callback cannot replace an active dialogue")
	unchanged(before, "blocked stale entry has no resource or save effects")
	app.modal_autosave_on_close = false; app._close_modal(); sync()
	app.quit_pending = true; before = memory_and_disk(); callback.call(); sync()
	check(not app.active_modal and strip.roster_button.disabled and not strip.detail_panel.is_visible_in_tree(), "pending quit disables strip and blocks entry")
	unchanged(before, "pending quit stale entry is inert")
	app.quit_pending = false; sync()
	await lifecycle_and_geometry()
	check(not FileAccess.file_exists(Model.SAVE_PATH), "normal player save remains untouched")
	app._stop_audio(); app.queue_free(); await process_frame
	print("%s: %d independent companion-condition checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func lifecycle_and_geometry() -> void:
	# Actual failed deliberate selection still autosaves once; viewing never retries.
	app.state.fail_writes = true
	var before: Dictionary = memory_and_disk()
	await click(strip.roster_button)
	var folio = app.overlay.get_meta("party_roster")
	var resources: Dictionary = app.state.party_resources.duplicate(true)
	folio.cells.tang.toggle.grab_focus(); await key(KEY_ENTER)
	check(app.state.writes == before.writes + 1 and app.save_warning, "deliberate roster change keeps existing one-save semantics")
	check(app.state.party_resources == resources, "failed selection save never heals")
	check(folio.retry_button.visible and folio.notice.text.contains("未存妥"), "direct folio surfaces existing failed-save warning")
	before = memory_and_disk(); await key(KEY_ESCAPE)
	await click(strip.roster_button); folio = app.overlay.get_meta("party_roster")
	check(folio.retry_button.visible and app.save_warning, "read-only reopen preserves warning")
	await key(KEY_ESCAPE); unchanged(before, "read-only reopen/cancel does not retry failed save")
	app.state.fail_writes = false; await click(strip.roster_button); folio = app.overlay.get_meta("party_roster")
	var writes: int = app.state.writes; await click(folio.retry_button)
	check(app.state.writes == writes + 1 and not app.save_warning, "explicit retry persists accepted roster exactly once")
	await key(KEY_ESCAPE); check_values("deliberate roster change return")
	app.state.set_party_roster(["hero", "qin", "shen", "tang"])
	app.state.qi = 0
	for id: String in ["shen", "tang", "qin"]: app.state.party_resources[id].qi = 0
	sync(); resources = app.state.party_resources.duplicate(true)
	var callback: Callable = strip.roster_button.pressed.get_connections()[0].callable
	var panel = UnifiedUI.open_training(app); sync()
	check(not strip.is_visible_in_tree(), "real battle hides exploration condition controls")
	var generation: int = app.modal_generation; callback.call()
	check(app.modal_generation == generation and app.overlay.get_meta("party_battle", null) == panel, "stale strip callback cannot replace actual battle")
	for step in range(8):
		if not app.state.battle_active: break
		UnifiedUI.step(app, false)
	if app.state.battle_active: UnifiedUI.leave(app)
	app._close_modal(); sync()
	check(app.state.party_resources != resources, "actual battle scheduler and settlement changed real companion resources")
	check(strip.is_visible_in_tree(), "battle return restores exploration condition display")
	check_values("actual battle return")
	app._healer_dialogue(); await key(KEY_1); sync(); check_values("actual post-battle healer rest")
	# Practice uses virtual full HP/Qi and returns exact real state/save bytes.
	app.world.change_map("qingwei", app.world.interactables.courtyard_practice.pos)
	app.state.map_id = "qingwei"; app.state.position = app.world.player_pos
	app.state.hp = maxi(1, app.state.max_hp - 17); app.state.qi = 1
	app.state.party_resources.shen = {"hp": 0, "qi": 0}; app._refresh(); sync()
	before = memory_and_disk(); app._practice_dialogue(); await key(KEY_ESCAPE)
	unchanged(before, "practice decline cannot save real unsaved condition changes")
	check(app._start_unified_battle("courtyard_practice"), "actual practice entry accepted")
	panel = app.overlay.get_meta("party_battle"); panel.set_process(false); panel.art.set_process(false); sync()
	check(not strip.is_visible_in_tree(), "practice hides real exploration condition values")
	for step in range(3):
		if app.state.battle_active: UnifiedUI.step(app, false)
	if app.state.battle_active: UnifiedUI.leave(app)
	await key(KEY_ESCAPE); sync()
	unchanged(before, "actual virtual practice scheduler/retreat/cancel preserves real memory and disk")
	check_values("actual virtual-practice return")
	check(strip.cards.shen.status.text.contains("倒下") and strip.cards.shen.hp_bar.value == 0, "virtual practice never revives the real downed companion")
	await geometry_and_occlusion()
func geometry_and_occlusion() -> void:
	app.toast_time = 0; app.hud.quest_notice_time = 0; sync()
	var original_zoom: int = app.view_preferences.zoom_index
	for zoom in range(3):
		app.view_preferences.zoom_index = zoom; app._apply_view_zoom(); sync()
		for id: String in strip.displayed_ids:
			strip.cards[id].button.grab_focus(); await process_frame; sync()
			check(strip.detail_panel.is_visible_in_tree(), "focus details visible at zoom " + str(zoom))
			for rect: Rect2 in strip.reserved_rects():
				check(not app.world._navigation_target_visible(rect.get_center() / app.view_zoom), "strip/detail registered as navigation exclusion without forced refresh")
			check(strip.detail_label.get_minimum_size().y <= strip.detail_label.size.y, "focused detail text fits its panel")
		await key(KEY_ESCAPE)
		if app.active_modal: app.modal_autosave_on_close = false; app._close_modal()
		app.world.teleport(Vector2(600, 450)); sync()
		for control: Button in [strip.cards.shen.button, strip.cards.tang.button, strip.cards.qin.button, strip.roster_button]:
			var rect: Rect2 = control.get_global_rect()
			for id: String in ["shen", "tang", "qin"]:
				var foot: Vector2 = app.world.camera_pos + rect.get_center() / app.view_zoom + Vector2(0, 35)
				Fixture.prepare_render(app.world, [Fixture.render_frame(id, foot)])
				app.hud.tick(1.0)
				check(control.modulate.a < .3, "condition control fades for follower " + id + " at zoom " + str(zoom))
				Fixture.prepare_render(app.world, []); app.hud.tick(1.0)
				check(control.modulate.a == 1.0, "condition control restores contrast after follower clears")
	app.view_preferences.zoom_index = original_zoom; app._apply_view_zoom(); sync()
	root.size = Vector2i(1179, 736); await process_frame; sync()
	check(Rect2(0, 0, 1179, 736).encloses(strip.get_global_rect()), "compact condition strip fits 1179x736 logical bounds")
	for id: String in strip.displayed_ids:
		strip.cards[id].button.grab_focus(); await process_frame; sync()
		check(Rect2(0, 0, 1179, 736).encloses(strip.detail_panel.get_global_rect()), "focus detail fits 1179x736 for " + id)
	check(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE and strip.detail_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative strip and details pass pointer input")
	root.size = Vector2i(1280, 800); await process_frame; sync()
