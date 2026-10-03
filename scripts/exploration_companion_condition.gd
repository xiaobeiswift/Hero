class_name ExplorationCompanionCondition
extends Control
## Read-only real-resource projection; deliberately independent of follower caches.
## Tab owns navigation here. E/WASD/arrows immediately return to world controls.
const Portraits = preload("res://scripts/character_portraits.gd")
const IDS: Array[String] = ["shen", "tang", "qin"]
const IVORY = Color("f1e6ca")
const GOLD = Color("dfbd7a")
const SOFT = Color("b4c4b6")
const JADE = Color("80c8ac")
const DOWN = Color("e8a38b")
signal entry_requested(generation: int)

var cards: Dictionary = {}
var displayed_ids: Array[String] = []
var displayed_snapshot: Dictionary = {}
var roster_button: Button
var detail_panel: Panel
var detail_label: Label
var navigation_revision: int = 0
var active_guard: Callable
var snapshot_valid: bool = false
var _enabled: bool = false
var _generation: int = -1
var _callbacks: Dictionary = {}
var _hovered: String = ""
var _details: Dictionary = {}
var _built: bool = false

func _ready() -> void:
	name = "ExplorationCompanionCondition"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(304, 112)
	for id: String in IDS:
		var button = Button.new()
		button.name = "Condition_" + id
		button.size = Vector2(98, 83)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _style(Color(.025, .085, .079, .9), Color(.6, .53, .36, .6)))
		button.add_theme_stylebox_override("hover", _style(Color("26483c"), GOLD))
		button.add_theme_stylebox_override("pressed", _style(Color("395a48"), IVORY))
		button.add_theme_stylebox_override("disabled", _style(Color(.025, .085, .079, .7), Color("44554a")))
		button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 2))
		add_child(button)
		var portrait = Portraits.attach(button, id, Rect2(-1, -2, 56, 59))
		var title = _label(button, "ActorName", "", Rect2(53, 5, 42, 23), 14, IVORY)
		var status = _label(button, "ActorStatus", "", Rect2(53, 30, 42, 19), 12, SOFT)
		_label(button, "HealthGlyph", "血", Rect2(6, 49, 14, 20), 11, JADE)
		_label(button, "QiGlyph", "气", Rect2(6, 62, 14, 19), 11, GOLD)
		var hp_bar = _bar(button, "HealthBar", Rect2(23, 59, 66, 5), JADE)
		var qi_bar = _bar(button, "QiBar", Rect2(23, 72, 66, 4), GOLD)
		cards[id] = {"button": button, "portrait": portrait, "name": title, "status": status, "hp_bar": hp_bar, "qi_bar": qi_bar}
		button.mouse_entered.connect(_hover.bind(id))
		button.mouse_exited.connect(_unhover.bind(id))
		button.focus_entered.connect(_update_detail)
		button.focus_exited.connect(_update_detail)
		button.visible = false
	roster_button = Button.new()
	roster_button.name = "OpenCompanionRoster"
	roster_button.text = "同行册  ·  Tab"
	roster_button.size = Vector2(112, 27)
	roster_button.focus_mode = Control.FOCUS_ALL
	roster_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	roster_button.add_theme_font_size_override("font_size", 13)
	roster_button.add_theme_color_override("font_color", GOLD)
	roster_button.add_theme_stylebox_override("normal", _style(Color(.025, .085, .079, .88), Color(.6, .53, .36, .6)))
	roster_button.add_theme_stylebox_override("hover", _style(Color("26483c"), GOLD))
	roster_button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 2))
	add_child(roster_button)
	roster_button.mouse_entered.connect(_hover.bind("roster"))
	roster_button.mouse_exited.connect(_unhover.bind("roster"))
	roster_button.focus_entered.connect(_update_detail)
	roster_button.focus_exited.connect(_update_detail)
	detail_panel = Panel.new()
	detail_panel.name = "CompanionConditionDetail"
	detail_panel.size = Vector2(296, 106)
	detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_panel.add_theme_stylebox_override("panel", _style(Color("102b28"), GOLD))
	add_child(detail_panel)
	detail_label = _label(detail_panel, "ConditionDetail", "", Rect2(12, 8, 272, 91), 15, IVORY)
	detail_panel.visible = false
	_built = true
	refresh_snapshot(displayed_snapshot)

func refresh_snapshot(snapshot: Dictionary) -> void:
	displayed_snapshot = snapshot.duplicate(true)
	if not _built: return
	var actors: Dictionary = _validated_actors(snapshot)
	snapshot_valid = not actors.is_empty()
	var next: Array[String] = []
	if snapshot_valid:
		for id: String in snapshot.roster:
			if id in IDS: next.append(id)
	if next != displayed_ids: navigation_revision += 1
	displayed_ids = next
	_details.clear()
	_details.roster = "同行册\n查看同行与行阵，调整出战名单\nTab 切换  ·  Enter / 空格打开\n方向键 / WASD 继续行走"
	for id: String in IDS:
		var card: Dictionary = cards[id]
		card.button.visible = displayed_ids.has(id)
		if not card.button.visible:
			card.button.release_focus()
			card.hp_bar.value = 0; card.qi_bar.value = 0
			card.status.text = ""; card.button.remove_meta("condition_detail")
			continue
		var actor: Dictionary = actors[id]
		var down: bool = actor.hp == 0
		card.button.position = Vector2(displayed_ids.find(id) * 103, 0)
		card.button.set_meta("actor_id", id)
		card.button.set_meta("roster_order", snapshot.roster.find(id) + 1)
		card.button.set_meta("downed", down)
		card.name.text = actor.name
		card.status.text = "倒下" if down else "在队"
		card.status.add_theme_color_override("font_color", DOWN if down else SOFT)
		card.portrait.modulate = Color(.63, .65, .61) if down else Color.WHITE
		card.hp_bar.max_value = actor.max_hp; card.hp_bar.value = actor.hp
		card.qi_bar.max_value = maxi(1, actor.max_qi); card.qi_bar.value = actor.qi
		card.hp_bar.add_theme_stylebox_override("fill", _style(DOWN if actor.hp * 4 <= actor.max_hp else JADE, Color.TRANSPARENT, 0))
		_details[id] = "%s  ·  %s\n气血  %d / %d\n真气  %d / %d\nEnter / 空格 · 同行册" % [actor.name, "倒下 · 仍随队" if down else "同行中", actor.hp, actor.max_hp, actor.qi, actor.max_qi]
		card.button.set_meta("condition_detail", _details[id])
	roster_button.position = Vector2(0, 87 if not displayed_ids.is_empty() else 0)
	detail_panel.position = Vector2(0, roster_button.position.y + 32)
	roster_button.text = "同行册  ·  Tab" if snapshot_valid else "同行资料不可用"
	_apply_enabled()
	_update_detail()

static func _validated_actors(snapshot: Dictionary) -> Dictionary:
	# Reject the entire projection on inconsistent/invalid input; never retain bars.
	if snapshot.get("ok") != true or not snapshot.get("roster") is Array or not snapshot.get("actors") is Array: return {}
	var roster: Array = snapshot.roster
	if roster.is_empty() or roster.size() > 4 or roster[0] != "hero": return {}
	var seen: Array = []
	for id: Variant in roster:
		if not id is String or (id != "hero" and not id in IDS) or id in seen: return {}
		seen.append(id)
	var actors: Dictionary = {}
	for value: Variant in snapshot.actors:
		if not value is Dictionary: return {}
		var actor: Dictionary = value
		var id: Variant = actor.get("id")
		if not id is String or (id != "hero" and not id in IDS) or actors.has(id): return {}
		if actor.get("recruited") != true or not actor.get("selected") is bool or actor.selected != roster.has(id): return {}
		if not actor.get("name") is String or actor.name.is_empty(): return {}
		for key: String in ["hp", "max_hp", "qi", "max_qi"]:
			if not actor.get(key) is int: return {}
		if actor.max_hp < 1 or actor.max_qi < 0 or actor.hp < 0 or actor.hp > actor.max_hp or actor.qi < 0 or actor.qi > actor.max_qi: return {}
		actors[id] = actor
	for id: String in roster:
		if not actors.has(id): return {}
	return actors

func set_context(on_screen: bool, enabled: bool, generation: int) -> void:
	if visible != on_screen: navigation_revision += 1
	visible = on_screen
	_enabled = enabled and on_screen
	if not _built: return
	if _generation != generation:
		_generation = generation
		for button: Button in _all_buttons():
			if _callbacks.has(button): button.pressed.disconnect(_callbacks[button])
			var callback: Callable = _activate.bind(generation)
			_callbacks[button] = callback
			button.pressed.connect(callback)
	_apply_enabled()
	if not _live():
		_hovered = ""
		for button: Button in _all_buttons(): button.release_focus()
	_update_detail()

func _apply_enabled() -> void:
	for button: Button in _all_buttons():
		button.disabled = not _enabled or not snapshot_valid
		button.focus_mode = Control.FOCUS_ALL if not button.disabled else Control.FOCUS_NONE

func _live() -> bool:
	return _enabled and snapshot_valid and is_visible_in_tree() and (not active_guard.is_valid() or bool(active_guard.call(_generation)))

func _activate(generation: int) -> void:
	if not _live() or generation != _generation: return
	entry_requested.emit(generation)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not _live(): return
	var buttons: Array[Button] = _visible_buttons()
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = buttons.find(focused)
	if event.physical_keycode in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_E]:
		if index >= 0: buttons[index].release_focus()
		_hovered = ""; _update_detail()
		return # Never consume movement or nearby-world E interaction.
	if event.physical_keycode == KEY_TAB:
		var next: int = posmod(index + (-1 if event.shift_pressed else 1), buttons.size())
		if index < 0: next = buttons.size() - 1 if event.shift_pressed else 0
		buttons[next].grab_focus()
		get_viewport().set_input_as_handled()
	elif index >= 0 and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_activate(_generation)

func _all_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for id: String in IDS: result.append(cards[id].button)
	result.append(roster_button)
	return result

func _visible_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for id: String in displayed_ids: result.append(cards[id].button)
	result.append(roster_button)
	return result

func _hover(id: String) -> void:
	_hovered = id; _update_detail()

func _unhover(id: String) -> void:
	if _hovered == id: _hovered = ""
	_update_detail()

func _update_detail() -> void:
	if not _built: return
	var id: String = _hovered
	for actor: String in displayed_ids:
		if cards[actor].button.has_focus(): id = actor; break
	if roster_button.has_focus(): id = "roster"
	var show_detail: bool = _live() and _details.has(id)
	if detail_panel.visible != show_detail: navigation_revision += 1
	detail_panel.visible = show_detail
	if show_detail:
		detail_label.text = _details[id]
		var height: float = maxf(106, detail_label.get_minimum_size().y + 16)
		if not is_equal_approx(detail_panel.size.y, height): navigation_revision += 1
		detail_panel.size.y = height
		detail_label.size = Vector2(272, height - 16)

func reserved_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not visible or not _built: return result
	for button: Button in _visible_buttons(): result.append(Rect2(position + button.position, button.size))
	if detail_panel.visible: result.append(Rect2(position + detail_panel.position, detail_panel.size))
	return result

func update_occlusion(actors: Array[Rect2], delta: float) -> void:
	for button: Button in _visible_buttons():
		var area = Rect2(position + button.position, button.size)
		var overlap: bool = false
		for actor: Rect2 in actors:
			if area.intersects(actor): overlap = true; break
		var inspecting: bool = button.has_focus() or (_hovered == "roster" if button == roster_button else _hovered == String(button.get_meta("actor_id", "")))
		button.modulate.a = move_toward(button.modulate.a, .23 if overlap and not inspecting else 1.0, delta * 5.0)

static func _style(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill; style.border_color = edge
	style.border_width_top = width; style.border_width_bottom = width
	style.corner_radius_top_left = 2; style.corner_radius_bottom_right = 2
	return style

static func _label(parent: Node, title: String, value: String, rect: Rect2, pixels: int, color: Color) -> Label:
	var label = Label.new()
	label.name = title; label.text = value; label.position = rect.position; label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func _bar(parent: Node, title: String, rect: Rect2, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.name = title; bar.position = rect.position; bar.size = rect.size
	bar.show_percentage = false; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ProgressBar reserves themed font height even with percentages hidden.
	bar.add_theme_font_size_override("font_size", 1)
	bar.add_theme_stylebox_override("background", _style(Color("314f46"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	bar.position = rect.position; bar.size = rect.size
	return bar
