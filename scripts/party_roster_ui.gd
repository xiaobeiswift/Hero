class_name PartyRosterUI
extends Control
## A projection of schema12's real recruited actors. Opening the folio never
## recruits, heals, changes selection, or advances a personal quest.
## Mount full-rect in the modal overlay. The host owns save/navigation callbacks
## and should supply a modal-generation guard to invalidate replaced folios.
const Portraits = preload("res://scripts/character_portraits.gd")
const Folio = preload("res://scripts/folio_theme.gd")
const IDS: Array[String] = ["hero", "shen", "tang", "qin"]
const TITLES: Dictionary = {"hero": "行路人", "shen": "沈青", "tang": "唐栖", "qin": "秦禾"}
const ROLES: Dictionary = {"hero": "主角", "shen": "药师", "tang": "修桥匠", "qin": "旧监水吏"}
const HINTS: Dictionary = {
	"shen": "青苇药铺\n与沈青相识后，亲口邀请同行。",
	"tang": "霜桥南桥\n修桥、查清原账后，问问他的旧事。",
	"qin": "雾竹坡\n水势之事落定后，听她说尺绳与轮值。",
}
const INK = Folio.INK
const MUTED = Folio.SECONDARY_INK
const PAPER = Folio.BONE
const TEAL = Folio.CLOTH
const GOLD = Folio.BRASS
const RED = Folio.CINNABAR

var state
var story_callbacks: Dictionary = {}
var return_callback: Callable
var changed_callback: Callable
var active_guard: Callable
var displayed_snapshot: Dictionary = {}
var cells: Dictionary = {}
var formation_buttons: Dictionary = {}
var frame: Panel
var summary: Label
var notice: Label
var formation_help: Label
var return_button: Button
var retry_button: Button
var _save_notice: String = ""
var _active: bool = true
var _built: bool = false

func bind_state(value, stories: Dictionary = {}, back: Callable = Callable(), changed: Callable = Callable(), guard: Callable = Callable()) -> void:
	state = value
	story_callbacks = stories.duplicate()
	return_callback = back
	changed_callback = changed
	active_guard = guard
	_active = true
	if _built: refresh()


func _ready() -> void:
	name = "PartyRosterUI"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ui_theme = Theme.new()
	ui_theme.default_font = Folio.BODY_FONT
	ui_theme.default_font_size = 18
	theme = ui_theme
	_build()
	resized.connect(_layout)
	_layout()
	refresh()
	focus_first.call_deferred()


func _build() -> void:
	var veil = ColorRect.new()
	veil.name = "RosterVeil"
	veil.color = Color(.01, .04, .04, .78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	frame = Panel.new()
	frame.name = "PartyRosterFrame"
	frame.add_theme_stylebox_override("panel", Folio.style(Color.TRANSPARENT))
	add_child(frame)
	Folio.backing(frame, Rect2(0, 0, 1200, 714))
	var paper = Folio.reading_wash(frame, Rect2(456, 126, 662, 564), .94)
	paper.name = "RosterPaper"
	_heading(frame, "RosterTitle", "同行册", 34, PAPER)
	_label(frame, "RosterSubtitle", "一路相照，各有担当", 18, GOLD)
	_label(frame, "RosterPageEyebrow", "同路相照 / 人物名录", 18, MUTED)
	_heading(frame, "RosterPageTitle", "结伴行路", 34, INK)
	_rule(frame, "RosterPageRule", GOLD)
	summary = _label(frame, "RosterSummary", "", 20, PAPER)
	for id: String in IDS: _build_cell(id)
	_rule(frame, "FormationRule", GOLD.darkened(.2))
	_heading(frame, "FormationTitle", "行阵", 24, PAPER)
	for formation: String in ["并肩", "护后"]:
		var button = _button(frame, "Formation_" + formation, formation, _choose_formation.bind(formation))
		button.toggle_mode = true
		Folio.skin_button(button, "cloth_quiet")
		button.add_theme_stylebox_override("normal", Folio.style(Color(.05, .09, .10, .18), GOLD.darkened(.30), 1))
		var selected = Folio.style(Color(.71, .63, .47, .17), GOLD, 1)
		selected.border_width_bottom = 3
		button.add_theme_stylebox_override("pressed", selected)
		formation_buttons[formation] = button
	formation_help = _label(frame, "FormationHelp", "", 18, PAPER)
	formation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule(frame, "RosterNoticeRule", GOLD)
	notice = _label(frame, "RosterNotice", "", 18, MUTED)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_button = _button(frame, "RosterRetrySave", "重试保存", retry_save)
	Folio.skin_button(retry_button, "primary")
	retry_button.add_theme_font_size_override("font_size", 19)
	retry_button.visible = false
	return_button = _button(frame, "RosterReturn", "返回行囊", close)
	Folio.skin_button(return_button, "header_close")
	var keyboard_backing = ColorRect.new()
	keyboard_backing.name = "RosterKeyboardBacking"
	keyboard_backing.color = Color("132226")
	keyboard_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(keyboard_backing)
	_label(frame, "RosterKeyboardHelp", "Tab / 方向键选项  ·  Enter / 空格确认  ·  Esc 返回", 16, PAPER)
	_built = true


func _build_cell(id: String) -> void:
	var cell = Panel.new()
	cell.name = "PartyCell_" + id
	cell.set_meta("actor_id", id)
	cell.add_theme_stylebox_override("panel", Folio.style(Color.TRANSPARENT))
	frame.add_child(cell)
	var on_cloth: bool = id == "hero"
	var foreground: Color = PAPER if on_cloth else INK
	var secondary: Color = GOLD if on_cloth else MUTED
	var portrait = TextureRect.new()
	portrait.name = "Portrait_" + id
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(portrait)
	var empty = _label(cell, "EmptySlot", "待结缘", 22, secondary)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title = _heading(cell, "ActorName", TITLES[id], 24 if on_cloth else 26, foreground)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var role = _label(cell, "ActorRole", ROLES[id], 18, secondary)
	var status = _label(cell, "ActorStatus", "", 18, foreground)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var health = _label(cell, "HealthValue", "", 18, foreground)
	var qi = _label(cell, "QiValue", "", 18, foreground)
	var health_bar = _bar(cell, "HealthBar", Color("aab68d") if on_cloth else Color("60774e"))
	var qi_bar = _bar(cell, "QiBar", Color("8ebfc2") if on_cloth else Color("507d82"))
	if on_cloth:
		for bar: ProgressBar in [health_bar, qi_bar]:
			bar.add_theme_stylebox_override("background", _style(Color("34494c"), Color.TRANSPARENT, 0, 0))
	var actions = _label(cell, "ActorActions", "", 18, foreground)
	actions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint = _label(cell, "RecruitmentHint", HINTS.get(id, ""), 18, secondary)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toggle = _button(cell, "Toggle_" + id, "", _toggle_actor.bind(id))
	toggle.toggle_mode = true
	Folio.skin_button(toggle, "cloth_quiet" if on_cloth else "primary")
	toggle.add_theme_font_size_override("font_size", 19)
	if on_cloth:
		toggle.add_theme_color_override("font_disabled_color", GOLD)
		var resting = Folio.style(Color.TRANSPARENT, GOLD.darkened(.35), 1)
		toggle.add_theme_stylebox_override("disabled", resting)
	var story = _button(cell, "Story_" + id, "人物近况", _open_story.bind(id), true)
	if not on_cloth: _rule(cell, "ActorRule", Color(.36, .29, .17, .25))
	cells[id] = {"panel": cell, "portrait": portrait, "empty": empty, "name": title,
		"role": role, "status": status, "hp": health, "qi": qi, "hp_bar": health_bar,
		"qi_bar": qi_bar, "actions": actions, "hint": hint, "toggle": toggle, "story": story}


func _layout() -> void:
	if not _built: return
	# Ordinary windows use the 1280x800 canvas_items canvas, including 960x600
	# physical windows. A directly resized 1179x737 canvas keeps the same ink
	# sizes while the complete folio art scales uniformly at its original ratio.
	var available = size if size.x > 0 and size.y > 0 else Vector2(1280, 800)
	var width: float = minf(1200, available.x - 40)
	var scale_factor: float = width / 1200.0
	var art_height: float = width * 890.0 / 1496.0
	frame.size = Vector2(width, art_height + 34)
	frame.position = (available - frame.size) * .5
	var left: float = 138 * scale_factor
	var cloth_width: float = 250 * scale_factor
	var right: float = 456 * scale_factor
	var paper_width: float = 662 * scale_factor
	_rect(frame.get_node("FolioDecorativeBacking"), Rect2(0, 0, width, art_height))
	# The reading wash feathers outside the ink area; it never covers the spine.
	_rect(frame.get_node("RosterPaper"), Rect2(right - 18, 126 * scale_factor - 20, paper_width + 82, 564 * scale_factor + 44))
	_rect(frame.get_node("RosterTitle"), Rect2(left, 26 * scale_factor, cloth_width, 47))
	_rect(frame.get_node("RosterSubtitle"), Rect2(left, 79 * scale_factor, cloth_width, 28))
	_rect(frame.get_node("RosterPageEyebrow"), Rect2(right, 34 * scale_factor, paper_width - 185, 28))
	_rect(frame.get_node("RosterPageTitle"), Rect2(right, 74 * scale_factor, paper_width, 48))
	_rect(frame.get_node("RosterPageRule"), Rect2(right, 132 * scale_factor, paper_width, 1))
	_rect(return_button, Rect2(width - 192 * scale_factor, 24 * scale_factor, 166 * scale_factor, 44))
	_layout_hero(Rect2(left, 118 * scale_factor, cloth_width, 286))
	_rect(frame.get_node("FormationRule"), Rect2(left, 409 * scale_factor, cloth_width, 1))
	_rect(summary, Rect2(left, 423 * scale_factor, cloth_width, 31))
	var formation_y: float = 474 * scale_factor
	_rect(frame.get_node("FormationTitle"), Rect2(left, formation_y + 4, 56, 34))
	var formation_width: float = (cloth_width - 76) * .5
	_rect(formation_buttons["并肩"], Rect2(left + 64, formation_y, formation_width, 42))
	_rect(formation_buttons["护后"], Rect2(left + 76 + formation_width, formation_y, formation_width, 42))
	_rect(formation_help, Rect2(left, formation_y + 55, cloth_width, art_height - (formation_y + 55) - 23))
	var row_height: float = 154 * scale_factor
	for index: int in range(1, IDS.size()):
		_layout_companion(cells[IDS[index]], Rect2(right, (148 + (index - 1) * 154) * scale_factor, paper_width, row_height))
	_rect(frame.get_node("RosterNoticeRule"), Rect2(right, 620 * scale_factor, paper_width, 1))
	_rect(notice, Rect2(right, 635 * scale_factor, paper_width - (160 if retry_button.visible else 0), 62))
	_rect(retry_button, Rect2(right + paper_width - 144, 638 * scale_factor, 144, 46))
	_rect(frame.get_node("RosterKeyboardBacking"), Rect2(left - 10, art_height + 2, width - left - 34, 32))
	_rect(frame.get_node("RosterKeyboardHelp"), Rect2(left, art_height + 4, width - left - 54, 28))
	frame.get_node("RosterPaper").queue_redraw()


func _layout_hero(rect: Rect2) -> void:
	var c: Dictionary = cells.hero
	_rect(c.panel, rect)
	var width: float = rect.size.x
	# Measure the native wrapped label at its real width before positioning
	# the role and resources. This includes the font and theme line spacing.
	_rect(c.name, Rect2(0, 0, width, 36))
	var name_height: float = maxf(36, ceilf(c.name.get_combined_minimum_size().y))
	c.name.size.y = name_height
	_rect(c.role, Rect2(0, name_height + 2, 58, 28))
	_rect(c.status, Rect2(64, name_height + 2, width - 64, 28))
	_rect(c.portrait, Rect2(0, name_height + 36, 82, 82))
	_rect(c.empty, Rect2(0, name_height + 36, 82, 82))
	_rect(c.hp, Rect2(90, name_height + 35, width - 90, 28))
	_rect(c.hp_bar, Rect2(90, name_height + 66, width - 90, 4))
	_rect(c.qi, Rect2(90, name_height + 76, width - 90, 28))
	_rect(c.qi_bar, Rect2(90, name_height + 107, width - 90, 4))
	_rect(c.actions, Rect2(0, name_height + 123, width, 28))
	_rect(c.hint, Rect2(0, name_height + 123, width, 28))
	_rect(c.toggle, Rect2(0, name_height + 159, width, 42))
	_rect(c.story, Rect2(0, name_height + 159, width, 42))


func _layout_companion(c: Dictionary, rect: Rect2) -> void:
	_rect(c.panel, rect)
	var width: float = rect.size.x
	var portrait_width: float = 114
	var text_x: float = 132
	var resource_width: float = (width - text_x - 24) * .5
	var action_y: float = rect.size.y - 48
	_rect(c.portrait, Rect2(0, 6, portrait_width, 128))
	_rect(c.empty, Rect2(0, 6, portrait_width, 128))
	_rect(c.name, Rect2(text_x, 0, 90, 38))
	_rect(c.role, Rect2(text_x + 100, 6, 110, 28))
	_rect(c.status, Rect2(width - 180, 6, 180, 28))
	_rect(c.hp, Rect2(text_x, 43, resource_width, 28))
	_rect(c.hp_bar, Rect2(text_x, 74, resource_width, 4))
	_rect(c.qi, Rect2(text_x + resource_width + 24, 43, resource_width, 28))
	_rect(c.qi_bar, Rect2(text_x + resource_width + 24, 74, resource_width, 4))
	_rect(c.actions, Rect2(text_x, action_y + 7, width - text_x - 262, 28))
	_rect(c.hint, Rect2(text_x, 42, width - text_x, 55))
	_rect(c.toggle, Rect2(width - 250, action_y, 120, 42))
	_rect(c.story, Rect2(width - 124, action_y, 124, 42))
	_rect(c.panel.get_node("ActorRule"), Rect2(0, floorf(rect.size.y) - 1, width, 1))


func refresh() -> void:
	if not _built: return
	displayed_snapshot = {} if state == null else state.party_resource_snapshot().duplicate(true)
	var valid: bool = bool(displayed_snapshot.get("ok", false))
	var actors: Dictionary = {}
	if valid:
		for actor: Dictionary in displayed_snapshot.get("actors", []): actors[String(actor.id)] = actor
	var in_battle: bool = state != null and bool(state.battle_active)
	var selected_count: int = 0
	for id: String in IDS:
		var c: Dictionary = cells[id]
		var recruited: bool = actors.has(id)
		var actor: Dictionary = actors.get(id, {})
		var selected: bool = recruited and bool(actor.get("selected", false))
		var down: bool = recruited and int(actor.hp) <= 0
		var roster: Array = displayed_snapshot.get("roster", [])
		var order: int = roster.find(id) + 1 if selected else 0
		if selected: selected_count += 1
		c.panel.set_meta("recruited", recruited)
		c.panel.set_meta("selected", selected)
		c.panel.set_meta("downed", down)
		c.panel.set_meta("roster_order", order)
		# Membership stays explicit in the status text and native toggle state;
		# the shared paper remains visible behind every row, including locked rows.
		c.name.text = String(actor.get("name", TITLES[id]))
		c.name.tooltip_text = c.name.text
		c.portrait.texture = Portraits.texture_for(id) if recruited else null
		c.portrait.modulate = Color(.75, .72, .68) if down else Color.WHITE
		c.portrait.visible = recruited
		c.empty.visible = not recruited
		c.hint.visible = not recruited
		c.status.text = ("在队 %d" % order if selected else "候阵") + (" · 倒下" if down else "") if recruited else "尚未招募"
		c.status.tooltip_text = "出战队列第%d位" % order if selected else "未编入当前出战队伍"
		c.status.add_theme_color_override("font_color", (Color("f0b594") if id == "hero" else RED) if down else (PAPER if id == "hero" else INK))
		for key: String in ["hp", "qi", "hp_bar", "qi_bar", "actions"]: c[key].visible = recruited
		if recruited:
			c.hp.text = "气血  %d / %d" % [actor.hp, actor.max_hp]
			c.qi.text = "真气  %d / %d" % [actor.qi, actor.max_qi]
			c.hp_bar.max_value = maxi(1, int(actor.max_hp)); c.hp_bar.value = int(actor.hp)
			c.qi_bar.max_value = maxi(1, int(actor.max_qi)); c.qi_bar.value = int(actor.qi)
			var martial: Dictionary = {}
			for action: Dictionary in actor.get("actions", []):
				if action.get("category") == "martial": martial = action; break
			c.actions.text = "招式 · " + String(martial.get("name", "—"))
			c.actions.tooltip_text = String(martial.get("description", ""))
		c.toggle.text = "主角在队" if id == "hero" else ("移出队伍" if selected else ("加入队伍" if recruited else "尚未招募"))
		c.toggle.disabled = not valid or in_battle or id == "hero" or not recruited
		c.toggle.set_pressed_no_signal(selected)
		c.toggle.tooltip_text = "主角始终在队" if id == "hero" else ("只可在探索时调整队伍" if in_battle else ("调整名单不会恢复气血或真气" if recruited else "请在故事中亲口邀请同行"))
		c.story.visible = id != "hero"
		c.story.text = "人物近况" if recruited else "结识线索"
		c.story.disabled = in_battle or not _story_for(id).is_valid()
		c.story.tooltip_text = "查看" + String(TITLES[id]) + ("的近况" if recruited else "的结识线索")
	summary.text = "出战 %d / 4 人  ·  %s" % [selected_count, String(state.formation)] if valid else "同行资料暂不可用"
	for formation: String in ["并肩", "护后"]:
		var button: Button = formation_buttons[formation]
		button.disabled = not valid or in_battle or selected_count < 2
		button.set_pressed_no_signal(state != null and state.formation == formation)
		button.tooltip_text = "至少一名同伴入队后可调整行阵" if selected_count < 2 else "探索时选用" + formation
	formation_help.text = "名录「在队」后的数字为出战顺序。并肩按轮次轮换敌方攻击目标。\n护后由队列中首位仍站立的人先承受来击。"
	if not valid: notice.text = "同行资料未能读取。请返回行囊后重试。"
	elif in_battle: notice.text = "交锋中不能调整队伍或行阵。"
	else: notice.text = "主角与三名同伴各自行动。入队、候阵保留当前气血与真气。"
	_apply_save_notice()
	_link_focus()


func set_save_notice(message: String) -> void:
	_save_notice = message
	if _built: refresh()


func _apply_save_notice() -> void:
	var retry_had_focus: bool = retry_button.has_focus()
	retry_button.visible = not _save_notice.is_empty()
	retry_button.disabled = state == null or state.battle_active
	if not _save_notice.is_empty(): notice.text = _save_notice
	notice.add_theme_color_override("font_color", RED if not _save_notice.is_empty() else MUTED)
	notice.tooltip_text = notice.text
	_layout()
	if retry_had_focus and not retry_button.visible: return_button.grab_focus()


func retry_save() -> void:
	if not _can_change() or _save_notice.is_empty(): return
	if changed_callback.is_valid(): changed_callback.call()


func _live() -> bool:
	return _active and state != null and is_inside_tree() and is_visible_in_tree() and not is_queued_for_deletion() and (not active_guard.is_valid() or bool(active_guard.call()))


func _can_change() -> bool:
	return _live() and not state.battle_active


func _toggle_actor(id: String) -> void:
	if not _can_change():
		if _live(): refresh()
		return
	if id == "hero" or not IDS.has(id): return
	var snapshot: Dictionary = state.party_resource_snapshot()
	if not snapshot.get("ok", false): refresh(); return
	var found: bool = false
	for actor: Dictionary in snapshot.actors:
		if actor.id == id: found = true; break
	if not found: refresh(); return
	var selected: Array = snapshot.roster.duplicate()
	if selected.has(id): selected.erase(id)
	else: selected.append(id)
	var applied: bool = state.set_party_roster(selected)
	refresh()
	if applied and changed_callback.is_valid(): changed_callback.call()


func _choose_formation(formation: String) -> void:
	if not _can_change():
		if _live(): refresh()
		return
	if not formation_buttons.has(formation): return
	var snapshot: Dictionary = state.party_resource_snapshot()
	if not snapshot.get("ok", false) or snapshot.roster.size() < 2: refresh(); return
	# Native toggle buttons emit even when reselecting the active formation.
	# Reproject the model so that a second click cannot visually deselect it.
	if state.formation == formation: refresh(); return
	var applied: bool = state.set_formation(formation)
	refresh()
	if applied and changed_callback.is_valid(): changed_callback.call()


func _story_for(id: String) -> Callable:
	var callback: Variant = story_callbacks.get(id, Callable())
	return callback if callback is Callable else Callable()


func _open_story(id: String) -> void:
	if not _can_change() or not IDS.has(id): return
	var callback: Callable = _story_for(id)
	if not callback.is_valid(): return
	_active = false
	callback.call()


func close() -> void:
	if not _live(): return
	_active = false
	if return_callback.is_valid(): return_callback.call()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and _live():
		get_viewport().set_input_as_handled()
		close()


func focus_first() -> void:
	if not _live(): return
	for id: String in IDS:
		var button: Button = cells[id].toggle
		if not button.disabled: button.grab_focus(); return
	return_button.grab_focus()


func _link_focus() -> void:
	var buttons: Array[Button] = []
	for id: String in IDS:
		for key: String in ["toggle", "story"]:
			var button: Button = cells[id][key]
			if not button.disabled and button.visible: buttons.append(button)
	for formation: String in ["并肩", "护后"]:
		if not formation_buttons[formation].disabled: buttons.append(formation_buttons[formation])
	if retry_button.visible and not retry_button.disabled: buttons.append(retry_button)
	buttons.append(return_button)
	for index: int in buttons.size():
		var previous: NodePath = buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())])
		var next: NodePath = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = previous; buttons[index].focus_next = next
		buttons[index].focus_neighbor_left = previous; buttons[index].focus_neighbor_top = previous
		buttons[index].focus_neighbor_right = next; buttons[index].focus_neighbor_bottom = next


static func _rect(node: Control, rect: Rect2) -> void:
	node.position = rect.position; node.size = rect.size


static func _style(fill: Color, border: Color, width: int = 1, radius: int = 5) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill; style.border_color = border
	style.set_border_width_all(width); style.set_corner_radius_all(radius)
	return style


static func _label(parent: Node, title: String, value: String, pixels: int, color: Color) -> Label:
	var label = Label.new()
	label.name = title; label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Folio.BODY_FONT)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	parent.add_child(label)
	return label


static func _bar(parent: Node, title: String, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.name = title; bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("c8bea8"), Color.TRANSPARENT, 0, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 0, 0))
	parent.add_child(bar)
	return bar


static func _heading(parent: Node, title: String, value: String, pixels: int, color: Color) -> Label:
	var label: Label = _label(parent, title, value, pixels, color)
	label.add_theme_font_override("font", Folio.heading_font())
	return label


static func _rule(parent: Control, title: String, color: Color) -> ColorRect:
	var line: ColorRect = Folio.rule(parent, Rect2(), color)
	line.name = title
	return line


static func _button(parent: Node, title: String, caption: String, action: Callable, secondary: bool = false) -> Button:
	var button = Button.new()
	button.name = title; button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	Folio.skin_button(button, "paper_quiet")
	if secondary:
		button.add_theme_stylebox_override("normal", Folio.style(Color.TRANSPARENT, Color(.36, .29, .17, .30), 1))
	button.pressed.connect(action)
	parent.add_child(button)
	return button
