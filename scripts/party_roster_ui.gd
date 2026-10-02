class_name PartyRosterUI
extends Control
## A projection of schema12's real recruited actors. Opening the folio never
## recruits, heals, changes selection, or advances a personal quest.
## Mount full-rect in the modal overlay. The host owns save/navigation callbacks
## and should supply a modal-generation guard to invalidate replaced folios.
const Portraits = preload("res://scripts/character_portraits.gd")
const IDS: Array[String] = ["hero", "shen", "tang", "qin"]
const TITLES: Dictionary = {"hero": "行路人", "shen": "沈青", "tang": "唐栖", "qin": "秦禾"}
const ROLES: Dictionary = {"hero": "主角", "shen": "药师", "tang": "修桥匠", "qin": "旧监水吏"}
const HINTS: Dictionary = {
	"shen": "青苇药铺\n与沈青相识后，亲口邀请同行。",
	"tang": "霜桥南桥\n修桥、查清原账后，问问他的旧事。",
	"qin": "雾竹坡\n水势之事落定后，听她说尺绳与轮值。",
}
const INK = Color("304a42")
const MUTED = Color("647567")
const PAPER = Color("e7dfc6")
const TEAL = Color("173b3b")
const GOLD = Color("bd9e61")
const RED = Color("994e3f")

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

class PaperSurface extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), PAPER)
		if size.x <= 0 or size.y <= 0: return
		for index: int in range(160):
			var spot = Vector2(fmod(13 + index * 83.71, size.x), fmod(11 + index * 57.31, size.y))
			draw_line(spot, spot + Vector2(2 + index % 4, 0), Color(.35, .38, .25, .055), 1)


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
	ui_theme.default_font = load("res://assets/fonts/NotoSansSC.otf")
	ui_theme.default_font_size = 16
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
	frame.add_theme_stylebox_override("panel", _style(TEAL, GOLD, 2, 9))
	add_child(frame)
	var paper = PaperSurface.new()
	paper.name = "RosterPaper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(paper)
	_label(frame, "RosterTitle", "同行册", 31, PAPER)
	_label(frame, "RosterSubtitle", "一路相照，各有担当", 14, Color("b8c4aa"))
	summary = _label(frame, "RosterSummary", "", 20, Color("e5c580"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for id: String in IDS: _build_cell(id)
	_label(frame, "FormationTitle", "行阵", 18, INK)
	for formation: String in ["并肩", "护后"]:
		var button = _button(frame, "Formation_" + formation, formation, _choose_formation.bind(formation))
		button.toggle_mode = true
		formation_buttons[formation] = button
	formation_help = _label(frame, "FormationHelp", "", 14, MUTED)
	formation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice = _label(frame, "RosterNotice", "", 14, Color("e0c792"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_button = _button(frame, "RosterRetrySave", "重试保存", retry_save)
	retry_button.visible = false
	return_button = _button(frame, "RosterReturn", "返回行囊", close)
	_label(frame, "RosterKeyboardHelp", "Tab / 方向键选项  ·  Enter / 空格确认  ·  Esc 返回", 12, Color("b8c4aa"))
	_built = true


func _build_cell(id: String) -> void:
	var cell = Panel.new()
	cell.name = "PartyCell_" + id
	cell.set_meta("actor_id", id)
	frame.add_child(cell)
	var portrait = TextureRect.new()
	portrait.name = "Portrait_" + id
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(portrait)
	var empty = _label(cell, "EmptySlot", "待结缘", 27, Color("849180"))
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title = _label(cell, "ActorName", TITLES[id], 24, INK)
	var role = _label(cell, "ActorRole", ROLES[id], 13, MUTED)
	var status = _label(cell, "ActorStatus", "", 14, INK)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var health = _label(cell, "HealthValue", "", 15, INK)
	var qi = _label(cell, "QiValue", "", 15, INK)
	var health_bar = _bar(cell, "HealthBar", Color("738860"))
	var qi_bar = _bar(cell, "QiBar", Color("598e93"))
	var actions = _label(cell, "ActorActions", "", 14, INK)
	actions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint = _label(cell, "RecruitmentHint", HINTS.get(id, ""), 15, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toggle = _button(cell, "Toggle_" + id, "", _toggle_actor.bind(id))
	toggle.toggle_mode = true
	var story = _button(cell, "Story_" + id, "人物近况", _open_story.bind(id), true)
	cells[id] = {"panel": cell, "portrait": portrait, "empty": empty, "name": title,
		"role": role, "status": status, "hp": health, "qi": qi, "hp_bar": health_bar,
		"qi_bar": qi_bar, "actions": actions, "hint": hint, "toggle": toggle, "story": story}


func _layout() -> void:
	if not _built: return
	# Root canvas remains 1280x800 with ordinary canvas_items window stretch;
	# this also fits a directly resized 1179x737 logical canvas without scrolling.
	var available = size if size.x > 0 and size.y > 0 else Vector2(1280, 800)
	frame.size = Vector2(minf(1128, available.x - 48), 668)
	frame.position = (available - frame.size) * .5
	var width: float = frame.size.x
	_rect(frame.get_node("RosterPaper"), Rect2(12, 97, width - 24, 463))
	_rect(frame.get_node("RosterTitle"), Rect2(30, 17, 340, 43))
	_rect(frame.get_node("RosterSubtitle"), Rect2(32, 64, 420, 23))
	_rect(summary, Rect2(width - 370, 29, 336, 36))
	var card_width: float = (width - 68) / 4
	for index: int in IDS.size():
		var c: Dictionary = cells[IDS[index]]
		_rect(c.panel, Rect2(24 + index * (card_width + 7), 112, card_width, 349))
		_rect(c.portrait, Rect2(19, 10, card_width - 38, 120))
		_rect(c.empty, Rect2(19, 10, card_width - 38, 120))
		_rect(c.name, Rect2(15, 127, card_width - 30, 33))
		_rect(c.role, Rect2(16, 162, 80, 21))
		_rect(c.status, Rect2(97, 162, card_width - 113, 21))
		_rect(c.hp, Rect2(16, 189, card_width - 32, 24))
		_rect(c.hp_bar, Rect2(16, 215, card_width - 32, 5))
		_rect(c.qi, Rect2(16, 224, card_width - 32, 24))
		_rect(c.qi_bar, Rect2(16, 250, card_width - 32, 5))
		_rect(c.actions, Rect2(16, 263, card_width - 32, 30))
		_rect(c.hint, Rect2(16, 197, card_width - 32, 93))
		_rect(c.toggle, Rect2(12, 300, (card_width - 30) * .57, 38))
		_rect(c.story, Rect2(18 + (card_width - 30) * .57, 300, (card_width - 30) * .43, 38))
		if IDS[index] == "hero": c.toggle.size.x = card_width - 24
	_rect(frame.get_node("FormationTitle"), Rect2(30, 483, 62, 28))
	_rect(formation_buttons["并肩"], Rect2(96, 477, 108, 40))
	_rect(formation_buttons["护后"], Rect2(212, 477, 108, 40))
	_rect(formation_help, Rect2(342, 476, width - 375, 70))
	_rect(notice, Rect2(32, 577, width - (460 if retry_button.visible else 264), 45))
	_rect(retry_button, Rect2(width - 406, 579, 180, 43))
	_rect(return_button, Rect2(width - 214, 579, 180, 43))
	_rect(frame.get_node("RosterKeyboardHelp"), Rect2(32, 637, width - 64, 21))
	frame.get_node("RosterPaper").queue_redraw()


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
		c.panel.add_theme_stylebox_override("panel", _style(Color("f0e9d5") if recruited else Color("dad7c0"), GOLD if selected else Color("b2b79a"), 2 if selected else 1, 5))
		c.name.text = String(actor.get("name", TITLES[id]))
		c.name.tooltip_text = c.name.text
		c.portrait.texture = Portraits.texture_for(id) if recruited else null
		c.portrait.modulate = Color(.75, .72, .68) if down else Color.WHITE
		c.portrait.visible = recruited
		c.empty.visible = not recruited
		c.hint.visible = not recruited
		c.status.text = ("在队 %d" % order if selected else "候阵") + (" · 倒下" if down else "") if recruited else "尚未招募"
		c.status.tooltip_text = "出战队列第%d位" % order if selected else "未编入当前出战队伍"
		c.status.add_theme_color_override("font_color", RED if down else INK)
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
		if id == "hero": c.toggle.size.x = c.panel.size.x - 24
	summary.text = "出战 %d / 4 人  ·  %s" % [selected_count, String(state.formation)] if valid else "同行资料暂不可用"
	for formation: String in ["并肩", "护后"]:
		var button: Button = formation_buttons[formation]
		button.disabled = not valid or in_battle or selected_count < 2
		button.set_pressed_no_signal(state != null and state.formation == formation)
		button.tooltip_text = "至少一名同伴入队后可调整行阵" if selected_count < 2 else "探索时选用" + formation
	formation_help.text = "卡片「在队」后的数字为出战顺序。并肩按轮次轮换敌方攻击目标。\n护后由队列中首位仍站立的人先承受来击。"
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
	notice.add_theme_color_override("font_color", Color("f0b594") if not _save_notice.is_empty() else Color("e0c792"))
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
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label


static func _bar(parent: Node, title: String, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.name = title; bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("cccbb0"), Color.TRANSPARENT, 0, 2))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 0, 2))
	parent.add_child(bar)
	return bar


static func _button(parent: Node, title: String, caption: String, action: Callable, secondary: bool = false) -> Button:
	var button = Button.new()
	button.name = title; button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK if secondary else PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(Color("dfdcc2") if secondary else TEAL, Color("a9b095")))
	button.add_theme_stylebox_override("hover", _style(Color("356057"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("476752"), GOLD, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("d3d3bb"), Color("b5b99c")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("a5712f"), 3))
	button.pressed.connect(action)
	parent.add_child(button)
	return button
