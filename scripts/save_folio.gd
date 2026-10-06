extends Control
## Presentation only. The save controller supplies validated summaries and the
## existing actions; this page never opens a save file or mutates the journey.
const Folio = preload("res://scripts/folio_theme.gd")

var host_ref: WeakRef
var generation: int
var page_title: String
var subtitle: String
var body: String
var data: Dictionary
var options: Array
var buttons: Array[Button] = []
var numbers: Array[Label] = []
var rows: Array[Dictionary] = []
var frame: Panel
var guidance: RichTextLabel
var detail_note: RichTextLabel
var feedback: Label
var feedback_band: Panel
var back_index: int = -1
var _built: bool = false


static func build(host, title_text: String, subtitle_text: String, body_text: String, choices: Array, projection: Dictionary) -> void:
	var page = load("res://scripts/save_folio.gd").new()
	page.name = "SaveFolioPage"
	page.host_ref = weakref(host)
	page.generation = host.modal_generation
	page.page_title = title_text
	page.subtitle = subtitle_text
	page.body = body_text
	page.options = choices.duplicate()
	page.data = projection.duplicate(true)
	host.overlay.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var page_theme = Theme.new()
	page_theme.default_font = Folio.BODY_FONT
	page_theme.default_font_size = 18
	theme = page_theme
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
	frame = Panel.new()
	frame.name = "SaveFolioFrame"
	frame.add_theme_stylebox_override("panel", Folio.style(Color.TRANSPARENT))
	add_child(frame)
	Folio.backing(frame, Rect2(0, 0, 1200, 714))
	var wash = Folio.reading_wash(frame, Rect2(438, 106, 744, 608), .94)
	wash.name = "SaveReadingPaper"
	_heading(frame, "SaveBookTitle", "旅途手记", 34, Folio.BONE)
	_label(frame, "SaveBookSubtitle", "留一卷前缘，续一程江湖", 18, Folio.BRASS)
	Folio.mark(frame, "book", Rect2(0, 0, 52, 52), Folio.BRASS).name = "SaveBookMark"
	_heading(frame, "SaveClothHeading", _cloth_heading(), 25, Folio.BONE)
	guidance = _rich(frame, "SaveGuidance", String(data.get("guidance", "")), 18, Folio.BONE)
	_rule("SaveClothRule", Folio.BRASS)
	_label(frame, "SaveLocalHeading", "本地留卷", 20, Folio.BRASS)
	var local_note = "手动手记各自留存。\n开始新旅程不会删除它们。"
	if data.get("browser_mode", false):
		local_note = "保存在此浏览器与当前网站。\n不同设备不会自动同步。"
		if not data.get("browser_storage_available", true):
			local_note = "当前浏览器未提供持久存储。\n刷新或关闭可能丢失手记。\n请保留当前页面。"
	_label(frame, "SaveLocalNote", local_note, 18, Folio.BONE)
	_label(frame, "SavePageEyebrow", subtitle, 18, Folio.SECONDARY_INK)
	_heading(frame, "SavePageTitle", _paper_heading(), 34, Folio.INK)
	_rule("SavePageRule", Folio.BRASS)
	for entry: Dictionary in data.get("rows", []): _build_row(entry)
	if data.get("kind", "") in ["detail", "confirm_save", "confirm_load"]:
		detail_note = _rich(frame, "SaveConsequences", String(data.get("consequences", body)), 19, Folio.INK)
	for index: int in options.size(): _build_action(index)
	feedback_band = Panel.new()
	feedback_band.name = "SaveFeedbackBand"
	feedback_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_band.add_theme_stylebox_override("panel", Folio.style(Color("e5ddc9"), Folio.BRASS.darkened(.18), 1))
	frame.add_child(feedback_band)
	feedback = _label(feedback_band, "SaveFolioFeedback", "", 18, Folio.INK)
	feedback_band.visible = false
	var keyboard_backing = ColorRect.new()
	keyboard_backing.name = "SaveKeyboardBacking"
	keyboard_backing.color = Color("132226")
	keyboard_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(keyboard_backing)
	var ending = "用返回离开" if data.get("title_context", false) else "Esc 返回"
	_label(frame, "SaveKeyboardHelp", "数字键 / Tab 选项 · Enter / 空格确认；无焦点选首项 · " + ending, 16, Folio.BONE)
	_built = true
	_link_focus()


func _build_row(entry: Dictionary) -> void:
	var row = Control.new()
	row.name = "SaveSlotRow" + str(rows.size())
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)
	var status: String = String(entry.get("status", "empty"))
	var status_text: String = {"valid": "可续写", "empty": "空白", "incompatible": "版本较新", "corrupt": "无法读取"}.get(status, "无法读取")
	var color: Color = Folio.CINNABAR if status in ["corrupt", "incompatible"] else Folio.SECONDARY_INK
	var heading = _heading(row, "SlotHeading", String(entry.get("title", "")), 25, Folio.INK)
	var status_label = _label(row, "SlotStatus", status_text, 17, color)
	var summary = _label(row, "SlotSummary", String(entry.get("summary", "")), 17, Folio.SECONDARY_INK)
	var rule = Folio.rule(row, Rect2(), Color(.36, .29, .17, .28))
	rows.append({"panel": row, "title": heading, "status": status_label, "summary": summary, "rule": rule, "action_index": int(entry.get("action_index", -1))})


func _build_action(index: int) -> void:
	var host = host_ref.get_ref()
	var action: Callable = options[index][1]
	var generation_at_build: int = generation
	var guarded = func():
		if is_instance_valid(host) and not host.quit_pending and host.active_modal and host.modal_generation == generation_at_build: action.call()
	host.modal_actions.append(guarded)
	var button = Button.new()
	button.name = "SaveChoice" + str(index + 1)
	button.text = String(options[index][0])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(guarded)
	frame.add_child(button)
	var is_back: bool = button.text in ["返回江湖", "返回", "返回列表", "返回手记", "返回详情"]
	var is_list: bool = data.get("kind", "") in ["save", "load"]
	var role = "header_close" if is_back and is_list else ("paper_quiet" if is_back or button.text == "读取备份" else "primary")
	Folio.skin_button(button, role)
	button.add_theme_font_size_override("font_size", 20)
	if is_back: back_index = index
	buttons.append(button)
	var number = _label(frame, "SaveChoiceNumber" + str(index + 1), str(index + 1), 17, Folio.BRASS if is_back and is_list else Folio.SECONDARY_INK)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numbers.append(number)


func _link_focus() -> void:
	for index: int in buttons.size():
		var previous = buttons[(index + buttons.size() - 1) % buttons.size()]
		var following = buttons[(index + 1) % buttons.size()]
		buttons[index].focus_previous = buttons[index].get_path_to(previous)
		buttons[index].focus_next = buttons[index].get_path_to(following)
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(previous)
		buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(following)
		buttons[index].focus_neighbor_left = buttons[index].get_path_to(previous)
		buttons[index].focus_neighbor_right = buttons[index].get_path_to(following)
	# No automatic focus: the existing unfocused Enter/Space first-choice
	# behavior remains explicit. Tab enters the new native focus chain.


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_TAB: return
	var host = host_ref.get_ref()
	if not is_instance_valid(host) or host.quit_pending or not host.active_modal or host.modal_generation != generation or is_queued_for_deletion() or not is_visible_in_tree(): return
	if buttons.is_empty() or buttons.has(get_viewport().gui_get_focus_owner()): return
	# The first intentional Tab enters this page's actions. Subsequent keys use
	# native Button navigation; opening a page alone never claims focus.
	get_viewport().set_input_as_handled()
	buttons[-1 if event.shift_pressed else 0].grab_focus()


func _layout() -> void:
	if not _built: return
	var available: Vector2 = size if size.x > 0 and size.y > 0 else Vector2(1280, 800)
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
	_rect(frame.get_node("SaveReadingPaper"), Rect2(right - 18, 106 * scale_factor, paper_width + 82, 608 * scale_factor))
	_rect(frame.get_node("SaveBookTitle"), Rect2(left, 30 * scale_factor, cloth_width, 48))
	_rect(frame.get_node("SaveBookSubtitle"), Rect2(left, 83 * scale_factor, cloth_width, 60))
	_rect(frame.get_node("SaveBookMark"), Rect2(left, 156 * scale_factor, 46, 46))
	_rect(frame.get_node("SaveClothHeading"), Rect2(left + 58, 159 * scale_factor, cloth_width - 58, 42))
	_rect(guidance, Rect2(left, 225 * scale_factor, cloth_width, 224 * scale_factor))
	_rect(frame.get_node("SaveClothRule"), Rect2(left, 476 * scale_factor, cloth_width, 1))
	_rect(frame.get_node("SaveLocalHeading"), Rect2(left, 495 * scale_factor, cloth_width, 30))
	_rect(frame.get_node("SaveLocalNote"), Rect2(left, 536 * scale_factor, cloth_width, art_height - 536 * scale_factor - 22))
	_rect(frame.get_node("SavePageEyebrow"), Rect2(right, 34 * scale_factor, paper_width - 170, 30))
	_rect(frame.get_node("SavePageTitle"), Rect2(right, 76 * scale_factor, paper_width, 49))
	_rect(frame.get_node("SavePageRule"), Rect2(right, 136 * scale_factor, paper_width, 1))
	var kind: String = data.get("kind", "")
	if kind in ["save", "load"]:
		_layout_list(right, paper_width, scale_factor, width)
	elif kind == "detail":
		_layout_detail(right, paper_width, scale_factor)
	else:
		_layout_confirmation(right, paper_width, scale_factor)
	_rect(feedback_band, Rect2(right, 612 * scale_factor, paper_width, 72))
	_rect(feedback, Rect2(14, 9, paper_width - 28, 54))
	_rect(frame.get_node("SaveKeyboardBacking"), Rect2(left - 10, art_height + 2, width - left - 34, 32))
	_rect(frame.get_node("SaveKeyboardHelp"), Rect2(left, art_height + 4, width - left - 54, 28))
	frame.get_node("SaveReadingPaper").queue_redraw()


func _layout_list(right: float, paper_width: float, scale_factor: float, width: float) -> void:
	var row_height: float = (144 if rows.size() == 3 else 108) * scale_factor
	for index: int in rows.size():
		_layout_row(rows[index], Rect2(right, 158 * scale_factor + index * row_height, paper_width, row_height), true)
	for index: int in buttons.size():
		if index == back_index:
			_place_action(index, Rect2(width - 192 * scale_factor, 24 * scale_factor, 166 * scale_factor, 44))
		elif index >= rows.size():
			# The pre-existing transfer choice is reachable only when its separate
			# production feature flag is explicitly enabled; no new entry is added.
			_place_action(index, Rect2(138 * scale_factor, 419 * scale_factor, 250 * scale_factor, 44))


func _layout_detail(right: float, paper_width: float, scale_factor: float) -> void:
	var row_height: float = 144 * scale_factor
	for index: int in rows.size():
		_layout_row(rows[index], Rect2(right, 158 * scale_factor + index * row_height, paper_width, row_height), true)
	if detail_note != null:
		_rect(detail_note, Rect2(right, (174 + rows.size() * 144) * scale_factor, paper_width, 72 * scale_factor))
	if back_index >= 0: _place_action(back_index, Rect2(right + paper_width - 178, 550 * scale_factor, 178, 44))


func _layout_confirmation(right: float, paper_width: float, scale_factor: float) -> void:
	for index: int in rows.size():
		_layout_row(rows[index], Rect2(right, 158 * scale_factor, paper_width, 119 * scale_factor), false)
	if detail_note != null: _rect(detail_note, Rect2(right, (294 if not rows.is_empty() else 164) * scale_factor, paper_width, 210 * scale_factor))
	var action_width: float = (paper_width - 54) * .5
	for index: int in buttons.size():
		_place_action(index, Rect2(right + (paper_width - action_width if index == 0 else 0), 548 * scale_factor, action_width, 46))


func _layout_row(row: Dictionary, rect: Rect2, with_action: bool) -> void:
	_rect(row.panel, rect)
	var action_width: float = 178
	var has_action: bool = with_action and row.action_index >= 0
	var text_width: float = rect.size.x - (action_width + 32 if has_action else 0)
	_rect(row.title, Rect2(0, 4, minf(text_width, 235), 36))
	_rect(row.status, Rect2(245 if text_width > 330 else text_width - 91, 11, 90, 26))
	_rect(row.summary, Rect2(0, 44, text_width, rect.size.y - 50))
	_rect(row.rule, Rect2(0, floorf(rect.size.y) - 1, rect.size.x, 1))
	if has_action: _place_action(row.action_index, Rect2(rect.position + Vector2(rect.size.x - action_width, 34), Vector2(action_width, 46)))


func _place_action(index: int, rect: Rect2) -> void:
	_rect(buttons[index], rect)
	# One shortcut number lives inside its own hit area, distinct from the
	# brass corners. Match the action's ink on both primary and quiet buttons.
	_rect(numbers[index], Rect2(rect.position + Vector2(8, 11), Vector2(18, 25)))
	numbers[index].add_theme_color_override("font_color", buttons[index].get_theme_color("font_color"))


func show_feedback(message: String, failed: bool) -> void:
	var host = host_ref.get_ref()
	if not is_instance_valid(host) or not host.active_modal or host.modal_generation != generation or is_queued_for_deletion(): return
	feedback.text = message
	feedback.add_theme_color_override("font_color", Folio.CINNABAR if failed else Folio.INK)
	feedback_band.visible = true
	_layout()


func _cloth_heading() -> String:
	match data.get("kind", ""):
		"save": return "择卷落笔"
		"load": return "续写前缘"
		"detail": return page_title
		_: return "落笔之前"


func _paper_heading() -> String:
	match data.get("kind", ""):
		"save": return "存一段江湖"
		"load": return "选一卷手记"
		_: return page_title


func _label(parent: Node, node_name: String, text: String, pixels: int, color: Color) -> Label:
	var label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Folio.BODY_FONT)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _heading(parent: Node, node_name: String, text: String, pixels: int, color: Color) -> Label:
	var label = _label(parent, node_name, text, pixels, color)
	label.add_theme_font_override("font", Folio.heading_font())
	return label


func _rich(parent: Node, node_name: String, text: String, pixels: int, color: Color) -> RichTextLabel:
	var label = RichTextLabel.new()
	label.name = node_name
	label.text = text
	label.selection_enabled = true
	label.scroll_active = true
	label.bbcode_enabled = false
	label.add_theme_font_override("normal_font", Folio.BODY_FONT)
	label.add_theme_font_size_override("normal_font_size", pixels)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_selected_color", Folio.BONE)
	label.add_theme_color_override("selection_color", Folio.INK)
	label.add_theme_constant_override("line_separation", 5)
	parent.add_child(label)
	Folio.scrollbar(label.get_v_scroll_bar(), color == Folio.BONE)
	return label


func _rule(node_name: String, color: Color) -> void:
	Folio.rule(frame, Rect2(), color).name = node_name


func _rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
