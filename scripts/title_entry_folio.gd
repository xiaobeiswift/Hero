extends Control
## The opening folio uses existing artwork and supplied text/actions only.
## No file reads, journey projection, save writes, or automatic action selection.
const Folio = preload("res://scripts/folio_theme.gd")
const FERRY = preload("res://assets/generated/qingwei_ferry_title.png")

var host_ref: WeakRef
var generation: int
var kind: String = "home"
var page_title: String
var subtitle: String
var body: String
var data: Dictionary
var options: Array
var buttons: Array[Button] = []
var cover: Control
var chapter: RichTextLabel
var story: RichTextLabel
var motto: Label
var notice: Label
var feedback: Label
var feedback_band: Panel
var consequence_paper: Control
var _built: bool = false


static func build(host, title_text: String, subtitle_text: String, body_text: String, choices: Array, projection: Dictionary) -> void:
	var page = load("res://scripts/title_entry_folio.gd").new()
	page.name = "TitleEntryPage"
	page.host_ref = weakref(host)
	page.generation = host.modal_generation
	page.kind = String(projection.get("kind", "home"))
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
	var art = TextureRect.new()
	art.name = "TitleFerryArtwork"
	art.texture = FERRY
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = TextureRect.new()
	shade.name = "TitleMottoShade"
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025,0.055,0.065,0), Color(0.025,0.055,0.065,.88)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(0,1)
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	cover = CoverSurface.new()
	cover.name = "TitleEntryCover"
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	_heading(cover, "TitleEntryHeading", page_title, 64 if kind == "home" else 43, Folio.BONE)
	_label(cover, "TitleEntrySubtitle", subtitle, 16, Folio.BRASS)
	Folio.rule(cover, Rect2(), Folio.BRASS.darkened(.1)).name = "TitleEntryRule"
	if kind == "home":
		var fragments = body.split("\n\n", false)
		chapter = _rich(cover, "TitleEntryChapter", String(fragments[0]) if fragments.size() >= 4 else "", 19, Folio.BRASS)
		story = _rich(cover, "TitleEntryStory", String(fragments[1]) if fragments.size() >= 4 else body, 18, Folio.BONE)
		motto = _label(self, "TitleEntryMotto", String(fragments[2]) if fragments.size() >= 4 else "", 23, Folio.BONE)
		motto.add_theme_font_override("font", Folio.HEADING_FONT)
	else:
		consequence_paper = PaperSurface.new()
		consequence_paper.name = "TitleConsequencesPaper"
		consequence_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(consequence_paper)
		story = _rich(cover, "TitleEntryConsequences", body, 20, Folio.INK)
		Folio.scrollbar(story.get_v_scroll_bar(), false)
	for index: int in options.size(): _build_action(index)
	feedback_band = Panel.new()
	feedback_band.name = "TitleEntryFeedbackBand"
	feedback_band.add_theme_stylebox_override("panel", Folio.style(Color("253036"), Folio.BRASS, 1))
	feedback_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(feedback_band)
	feedback = _label(feedback_band, "TitleEntryFeedback", "", 17, Folio.BONE)
	feedback_band.hide()
	notice = _label(cover, "TitleEntrySaveNotice", String(data.get("save_notice", "")), 17, Folio.BONE)
	var host = host_ref.get_ref()
	var version = _label(cover, "BuildVersion", host._version_caption(), 15, Folio.BRASS)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var key_help = _label(cover, "TitleEntryKeyboardHelp", "数字键选项 · Tab 聚焦 · Enter / 空格确认", 15, Folio.BRASS)
	key_help.tooltip_text = "未聚焦按钮时，Enter / 空格执行首项；本页 Esc 不关闭。"
	_built = true
	_link_focus()


func _live() -> bool:
	var host = host_ref.get_ref()
	return is_instance_valid(host) and not host.quit_pending and host.active_modal and host.current_screen == "title" and host.modal_generation == generation and is_inside_tree() and is_visible_in_tree() and not is_queued_for_deletion()


func _build_action(index: int) -> void:
	var host = host_ref.get_ref()
	var page_ref = weakref(self)
	var action: Callable = options[index][1]
	var action_caption: String = String(options[index][0])
	var guarded = func():
		var page = page_ref.get_ref()
		if not is_instance_valid(page) or not page._live(): return
		action.call()
		# A successful Continue changes screen/generation. A failed read leaves
		# this same page open; expose its existing production message in place.
		if action_caption == "续写前缘" and is_instance_valid(page) and page._live():
			page.show_feedback(host.status_label.text)
	host.modal_actions.append(guarded)
	var button = Button.new()
	button.name = "TitleEntryChoice" + str(index + 1)
	button.text = action_caption
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(guarded)
	cover.add_child(button)
	var has_continue: bool = false
	for choice: Array in options:
		if String(choice[0]) == "续写前缘": has_continue = true
	var primary: bool = index == 0
	if kind == "home" and has_continue: primary = action_caption == "续写前缘"
	Folio.skin_button(button, "primary" if primary else "cloth_quiet")
	button.add_theme_font_size_override("font_size", 21)
	var number = _label(button, "ShortcutNumber", str(index + 1), 17, Folio.BRASS)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buttons.append(button)


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
	# Opening a page never focuses or activates even its first/destructive action.


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_TAB or not _live(): return
	if buttons.is_empty() or buttons.has(get_viewport().gui_get_focus_owner()): return
	get_viewport().set_input_as_handled()
	buttons[-1 if event.shift_pressed else 0].grab_focus()


func show_feedback(message: String) -> void:
	if not _live(): return
	feedback.text = message
	feedback.tooltip_text = message
	feedback_band.visible = not message.is_empty()


func _layout() -> void:
	if not _built: return
	var available: Vector2 = size if size.x > 0 and size.y > 0 else Vector2(1280,800)
	var width: float = minf(502, available.x * .45)
	var height: float = minf(716, available.y - 56)
	cover.position = Vector2(maxf(28, available.x * .045), (available.y - height) * .5)
	cover.size = Vector2(width, height)
	cover.queue_redraw()
	var left: float = 44
	var content: float = width - 88
	_rect(cover.get_node("TitleEntryHeading"), Rect2(left,24,content,84))
	_rect(cover.get_node("TitleEntrySubtitle"), Rect2(left,108,content,43))
	_rect(cover.get_node("TitleEntryRule"), Rect2(left,157,content,1))
	var first_action: float = 306
	var action_height: float = 52
	var action_gap: float = 8
	if kind == "home":
		_rect(chapter,Rect2(left,170,content,31))
		_rect(story,Rect2(left,208,content,92))
		if buttons.size() > 3: action_height = 44; action_gap = 6
		_rect(motto,Rect2(available.x*.51,available.y-169,available.x*.445,96))
	else:
		_rect(consequence_paper,Rect2(31,176,width-62,205))
		consequence_paper.queue_redraw()
		_rect(story,Rect2(left+6,192,content-12,174))
		first_action = 405
	for index: int in buttons.size():
		_rect(buttons[index],Rect2(left,first_action+index*(action_height+action_gap),content,action_height))
		_rect(buttons[index].get_node("ShortcutNumber"),Rect2(12,0,30,action_height))
	var feedback_top: float = first_action + buttons.size()*(action_height+action_gap)-action_gap+6
	_rect(feedback_band,Rect2(left,feedback_top,content,56))
	_rect(feedback,Rect2(10,4,content-20,48))
	_rect(notice,Rect2(left,height-112,content,64))
	_rect(cover.get_node("BuildVersion"),Rect2(width-186,34,148,23))
	_rect(cover.get_node("TitleEntryKeyboardHelp"),Rect2(left,height-43,content,23))
	_rect(get_node("TitleMottoShade"),Rect2(0,available.y-250,available.x,250))


func _heading(parent: Node, node_name: String, value: String, font_size: int, ink: Color) -> Label:
	var label = _label(parent,node_name,value,font_size,ink)
	label.add_theme_font_override("font",Folio.HEADING_FONT)
	return label


func _label(parent: Node, node_name: String, value: String, font_size: int, ink: Color) -> Label:
	var label = Label.new()
	label.name = node_name
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",Folio.BODY_FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",ink)
	parent.add_child(label)
	return label


func _rich(parent: Node, node_name: String, value: String, font_size: int, ink: Color) -> RichTextLabel:
	var text = RichTextLabel.new()
	text.name = node_name
	text.text = value
	text.bbcode_enabled = true
	text.scroll_active = kind != "home"
	text.mouse_filter = Control.MOUSE_FILTER_STOP if kind != "home" else Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font",Folio.BODY_FONT)
	text.add_theme_font_size_override("normal_font_size",font_size)
	text.add_theme_color_override("default_color",ink)
	parent.add_child(text)
	return text


func _rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


class CoverSurface extends Control:
	func _draw() -> void:
		draw_rect(Rect2(12,11,size.x-12,size.y-11),Folio.PAPER)
		for offset: int in [5,8]:
			draw_line(Vector2(size.x-offset,18),Vector2(size.x-offset,size.y-5),Color("a29374"),1)
		var area = Rect2(0,0,size.x-14,size.y-14)
		var sample: Rect2 = Folio.ATLAS_REGIONS.textile_sample
		# Repeat original texels at native density; never enlarge a small cloth crop.
		for y: int in range(int(ceil(area.size.y/sample.size.y))):
			for x: int in range(int(ceil(area.size.x/sample.size.x))):
				var origin = Vector2(x,y)*sample.size
				var extent = Vector2(minf(sample.size.x,area.size.x-origin.x),minf(sample.size.y,area.size.y-origin.y))
				draw_texture_rect_region(Folio.BACKING,Rect2(origin,extent),Rect2(sample.position,extent))
		draw_rect(area,Color(.015,.035,.045,.32))
		draw_rect(area.grow(-9),Folio.BRASS.darkened(.4),false,1)
		draw_line(Vector2(20,18),Vector2(20,area.end.y-18),Folio.BRASS.darkened(.2),1)
		for y: int in range(28,int(area.end.y-20),18):
			draw_line(Vector2(15,y),Vector2(24,y+3),Color(.71,.63,.47,.55),1)


class PaperSurface extends Control:
	func _draw() -> void:
		var sample: Rect2 = Folio.ATLAS_REGIONS.paper_sample
		for y: int in range(int(ceil(size.y/sample.size.y))):
			for x: int in range(int(ceil(size.x/sample.size.x))):
				var origin = Vector2(x,y)*sample.size
				var extent = Vector2(minf(sample.size.x,size.x-origin.x),minf(sample.size.y,size.y-origin.y))
				draw_texture_rect_region(Folio.BACKING,Rect2(origin,extent),Rect2(sample.position,extent))
		draw_rect(Rect2(Vector2.ZERO,size).grow(-5),Folio.BRASS.darkened(.25),false,1)
