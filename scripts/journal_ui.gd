extends Control
## Read-only earned folio. Browsing and the session's explicit tracking are separate.
## Each signal owns a frozen view token; rebuilding never lends old signals a new one.
const Folio = preload("res://scripts/folio_theme.gd")
const Objectives = preload("res://scripts/journal_objective_rules.gd")
const INK = Folio.INK
const SECONDARY_INK = Folio.SECONDARY_INK
const GOLD_INK = Folio.BRASS
const PAGE = Folio.PAPER
const FOCUS_INK = Folio.INK
const LIGHT_INK = Folio.BONE
const STATUS_NAMES = {"active":"进行中", "available":"可前往", "completed":"已完成"}
const SCROLL_KEYS = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END]
const BLOCKED_KEYS = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_E, KEY_M, KEY_F5, KEY_F9, KEY_F6, KEY_F10, KEY_B, KEY_I, KEY_K, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]
var host
var source_state
var source_world
var source_session
var generation: int = -1
var browse_arc_id: String = ""
var row_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var body: RichTextLabel
var guidance_body: RichTextLabel
var guidance_snapshot: Dictionary = {}
var guidance_revision: int = -1
var view_revision: int = 0
var page: String = "journal"
var completed_expanded: bool = false
var _catalog: Array[Dictionary] = []
var _list_scroll: ScrollContainer
var _focus_order: Array[Control] = []
var _visible_rows: Array[String] = []
var _footer_order: Array[String] = []
var _view_token: Dictionary = {}
var _closed: bool = false
var _building: bool = false
var _history_text: String = ""
var _history_catalog: Array[Dictionary] = []
var _journal_scroll: int = 0
var _journal_body_scroll: float = 0.0
var _history_scroll: float = 0.0
var _guidance_scroll: float = 0.0

static func open(owner) -> Control:
	if not is_instance_valid(owner) or not owner.has_method("_can_open_journal") or not owner._can_open_journal(): return null
	if not is_instance_valid(owner.state) or not is_instance_valid(owner.world) or not is_instance_valid(owner.journal_session): return null
	owner._begin_journal_position_hold()
	owner.modal_generation += 1
	owner._clear_overlay()
	owner.active_modal = true
	owner.modal_autosave_on_close = false
	owner.world.active = false
	owner._sync_journal_guidance(true, true)
	var panel = load("res://scripts/journal_ui.gd").new()
	panel.host = owner
	panel.source_state = owner.state
	panel.source_world = owner.world
	panel.source_session = owner.journal_session
	panel.generation = owner.modal_generation
	panel.guidance_snapshot = owner.journal_guidance_snapshot.duplicate(true)
	panel.guidance_revision = owner.journal_guidance_revision
	panel._catalog = owner.journal_catalog().duplicate(true)
	panel._choose_browse(true)
	owner.overlay.set_meta("journal_ui", panel)
	owner.overlay.add_child(panel)
	panel._rebuild("row:" + panel.browse_arc_id)
	owner._refresh()
	return panel

func valid() -> bool:
	return not _closed and is_inside_tree() and not is_queued_for_deletion() \
		and is_instance_valid(host) and is_instance_valid(source_state) and is_instance_valid(source_world) \
		and is_instance_valid(source_session) and host.state == source_state and host.world == source_world \
		and host.journal_session == source_session and host.current_screen == "explore" \
		and host._can_open_journal() and not host.quit_pending and not source_state.battle_active and not source_state._party_gate() \
		and source_state._party_pending_token < 0 and host.active_modal and host.modal_generation == generation \
		and host.overlay.get_meta("journal_ui", null) == self and source_state.map_id == source_world.map_id

func invalidate_callbacks() -> void:
	_closed = true
	view_revision += 1
	_view_token = {}

func _capture_token() -> Dictionary:
	var session_token: Dictionary = source_session.token(source_state).duplicate(true)
	session_token.make_read_only()
	var token: Dictionary = {"owner":get_instance_id(), "host":host.get_instance_id(), "state":source_state.get_instance_id(), "world":source_world.get_instance_id(), "generation":generation, "view":view_revision, "page":page, "browse":browse_arc_id, "session":session_token}
	token.make_read_only()
	return token

func _callback_valid(expected: Dictionary, row_id: String = "", require_trackable: bool = false) -> bool:
	if not valid() or expected.is_empty(): return false
	if expected.get("owner", 0) != get_instance_id() or expected.get("host", 0) != host.get_instance_id() \
		or expected.get("state", 0) != source_state.get_instance_id() or expected.get("world", 0) != source_world.get_instance_id() \
		or expected.get("generation", -1) != generation or expected.get("view", -1) != view_revision \
		or expected.get("page", "") != page or expected.get("browse", "") != browse_arc_id \
		or expected.get("session", {}) != source_session.token(source_state): return false
	if not row_id.is_empty():
		var current: Dictionary = Objectives.row(source_state, row_id)
		var displayed: Dictionary = _row(row_id)
		if current.is_empty() or displayed.is_empty() or current != displayed: return false
		if require_trackable and not current.get("trackable", false): return false
	return true

func refresh_guidance(snapshot: Dictionary, revision: int) -> void:
	if not valid() or _building: return
	var rows: Array[Dictionary] = host.journal_catalog().duplicate(true)
	var current_token: Dictionary = source_session.token(source_state)
	if revision == guidance_revision and snapshot == guidance_snapshot and rows == _catalog and _view_token.get("session", {}) == current_token: return
	var focus_key: String = _focused_key()
	_remember_scroll()
	guidance_snapshot = snapshot.duplicate(true)
	guidance_revision = revision
	_catalog = rows
	_choose_browse(false)
	_rebuild(focus_key)

func guidance_copy() -> Dictionary:
	return guidance_snapshot.duplicate(true)

func _row(id: String) -> Dictionary:
	for row: Dictionary in _catalog:
		if String(row.get("id", "")) == id: return row
	return {}

func _choose_browse(initial: bool) -> void:
	if not initial and not _row(browse_arc_id).is_empty(): return
	browse_arc_id = ""
	var effective: String = String(guidance_snapshot.get("arc_id", ""))
	if _row(effective).is_empty(): effective = String(guidance_snapshot.get("source_arc_id", ""))
	if not _row(effective).is_empty(): browse_arc_id = effective
	elif not _catalog.is_empty(): browse_arc_id = String(_catalog[0].get("id", ""))
	# Completed remains collapsed on first opening, even when it supplies onward prose.

func browse(id: String) -> void:
	_browse_bound(id, _view_token)

func _browse_bound(id: String, expected: Dictionary) -> void:
	if page != "journal" or not _callback_valid(expected, id): return
	if id == browse_arc_id:
		_focus_key("row:" + id, expected)
		return
	_remember_scroll()
	browse_arc_id = id
	_journal_body_scroll = 0.0
	_rebuild("row:" + id)

func track_selected() -> void:
	_track_bound(browse_arc_id, _view_token)

func _track_bound(id: String, expected: Dictionary) -> void:
	if page != "journal" or id != browse_arc_id or not _callback_valid(expected, id, true): return
	if not source_session.track(source_state, id, expected.session): return
	# The host publishes once to every consumer. Its callback may rebuild this view.
	host._sync_journal_guidance(true)
	refresh_guidance(host.journal_guidance_snapshot, host.journal_guidance_revision)
	_focus_key.call_deferred(_nearest_footer("track"), _view_token)

func restore_auto() -> void:
	_auto_bound(_view_token)

func _auto_bound(expected: Dictionary) -> void:
	if page != "journal" or not _callback_valid(expected): return
	if not source_session.restore_auto(source_state, expected.session): return
	host._sync_journal_guidance(true)
	refresh_guidance(host.journal_guidance_snapshot, host.journal_guidance_revision)
	_focus_key.call_deferred(_nearest_footer("auto"), _view_token)

func show_history() -> void:
	_history_bound(_view_token)

func _history_bound(expected: Dictionary) -> void:
	if page != "journal" or not _callback_valid(expected): return
	_remember_scroll()
	page = "history"
	_rebuild("body")

func back() -> void:
	_back_bound(_view_token)

func _back_bound(expected: Dictionary) -> void:
	if not _callback_valid(expected): return
	if page != "history":
		_close_bound(expected)
		return
	_remember_scroll()
	page = "journal"
	_rebuild("action:history")

func close() -> void:
	_close_bound(_view_token)

func _close_bound(expected: Dictionary) -> void:
	if not _callback_valid(expected): return
	host.modal_autosave_on_close = false
	source_session.invalidate_callbacks()
	invalidate_callbacks()
	host._close_modal()

func _toggle_completed(expected: Dictionary) -> void:
	if page != "journal" or not _callback_valid(expected): return
	_remember_scroll()
	completed_expanded = not completed_expanded
	_rebuild("action:completed")

func _remember_scroll() -> void:
	if is_instance_valid(guidance_body): _guidance_scroll = guidance_body.get_v_scroll_bar().value
	if is_instance_valid(_list_scroll): _journal_scroll = _list_scroll.scroll_vertical
	if is_instance_valid(body):
		if page == "history": _history_scroll = body.get_v_scroll_bar().value
		else: _journal_body_scroll = body.get_v_scroll_bar().value

func _rebuild(focus_key: String = "") -> void:
	if not valid() or _building: return
	_building = true
	view_revision += 1
	source_session.invalidate_callbacks()
	_view_token = _capture_token()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	row_buttons.clear()
	action_buttons.clear()
	_focus_order.clear()
	_visible_rows.clear()
	_footer_order.clear()
	_list_scroll = null
	body = null
	guidance_body = null
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil = ColorRect.new()
	veil.color = Color(.01, .035, .045, .80)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var frame = Control.new()
	frame.name = "JournalFrame"
	frame.position = Vector2(40,46)
	frame.size = Vector2(1200,714)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	Folio.backing(frame, Rect2(Vector2.ZERO,frame.size))
	_heading(frame, "行\n纪", Rect2(28,58,65,158), 54, LIGHT_INK, "JournalSpineTitle")
	_heading(frame, "渡\n灯\n录", Rect2(45,261,28,93), 20, Folio.BRASS, "JournalSpineImprint")
	Folio.mark(frame, "book", Rect2(47,228,25,25), Folio.CINNABAR.lightened(.10))
	_heading(frame, "行纪 · 选途", Rect2(138,22,265,47), 30, LIGHT_INK, "JournalTitle")
	Folio.rule(frame, Rect2(140,77,245,1), Color("8c7a59"))
	# Both public close identities refer to this one real, reachable header control.
	var close_button: Button = _button(frame, "Esc  收起 ×", Rect2(1038,22,137,48), _close_bound.bind(_view_token), "JournalAction_close", false, "header_close")
	action_buttons["header_close"] = close_button
	action_buttons["close"] = close_button
	_build_guidance(frame)
	if page == "history": _build_history(frame)
	else: _build_journal(frame)
	_build_footer(frame)
	_focus_order.append(close_button)
	_link_focus()
	_text(self, "方向键翻阅   ·   Tab / Shift+Tab 移动焦点   ·   Enter / 空格确认   ·   J 收起   ·   Esc 返回", Rect2(176,768,1060,24), 16, LIGHT_INK, "JournalHelp")
	_building = false
	_restore_scroll.call_deferred(_view_token)
	_focus_key.call_deferred(focus_key, _view_token)

func _build_guidance(frame: Control) -> void:
	# This region is separate from the list: neither its safety prose nor Auto can
	# disappear when the earned catalogue grows. Full prose has its own scrollbar.
	var guidance_top: float = 456 if page == "journal" else 510
	Folio.rule(frame, Rect2(140,guidance_top,244,1), Folio.BRASS)
	Folio.mark(frame, "compass", Rect2(139,guidance_top+14,27,27), Folio.BRASS)
	_text(frame, "当前指引", Rect2(176,guidance_top+15,204,29), 20, Folio.BRASS, "JournalGuidanceHeading")
	guidance_body = _rich(frame, _guidance_text(guidance_snapshot), Rect2(139,guidance_top+51,250,133 if page == "journal" else 130), 16, "JournalCurrentGuidance", true)
	guidance_body.tooltip_text = "完整的当前行动、下一处与行路限制；滚轮或聚焦后用方向键、Home / End 阅读"
	Folio.scroll_edges(frame, guidance_body.get_v_scroll_bar(), guidance_body.get_rect(), true)
	if page == "journal":
		var automatic: Button = _button(frame, "恢复自动指引", Rect2(141,650,248,48), _auto_bound.bind(_view_token), "JournalAction_auto", false, "auto")
		automatic.disabled = source_session.tracked_arc_id.is_empty()
		automatic.tooltip_text = "当前已使用自动指引" if automatic.disabled else "恢复原有自动指引；不会改变故事或保存"
		action_buttons["auto"] = automatic

func _build_journal(frame: Control) -> void:
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "JournalList"
	_list_scroll.position = Vector2(132,87)
	# Leave a quiet lower edge instead of the next title's tiny first sliver.
	_list_scroll.size = Vector2(268,340)
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_scroll.follow_focus = true
	_list_scroll.focus_mode = Control.FOCUS_NONE
	_list_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(_list_scroll)
	_style_scrollbar(_list_scroll.get_v_scroll_bar(), true)
	Folio.scroll_edges(frame, _list_scroll.get_v_scroll_bar(), _list_scroll.get_rect(), true)
	# Six-pixel gutters keep the cloth edges calm; row focus itself is inset.
	var padding = MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 6)
	_list_scroll.add_child(padding)
	var list = VBoxContainer.new()
	list.name = "JournalGroups"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	padding.add_child(list)
	for status: String in ["active", "available", "completed"]:
		var group: Array[Dictionary] = []
		for row: Dictionary in _catalog:
			if row.get("status", "") == status: group.append(row)
		if group.is_empty(): continue
		if status == "completed":
			var toggle: Button = _button(list, ("▾ " if completed_expanded else "▸ ") + "已完成（%d）" % group.size(), Rect2(0,0,244,48), _toggle_completed.bind(_view_token), "JournalCompletedToggle", false, "cloth_disclosure")
			toggle.custom_minimum_size = Vector2(0,48)
			toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.add_theme_color_override("font_color", Folio.BRASS)
			toggle.tooltip_text = "展开或收起已完成见闻；已完成事项不可追踪"
			action_buttons["completed"] = toggle
			_focus_order.append(toggle)
			if not completed_expanded: continue
		else:
			var heading = Label.new()
			heading.text = String(STATUS_NAMES[status])
			heading.custom_minimum_size = Vector2(0,29)
			heading.add_theme_font_override("font", Folio.BODY_FONT)
			heading.add_theme_font_size_override("font_size", 18)
			heading.add_theme_color_override("font_color", Folio.BRASS)
			heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
			list.add_child(heading)
		for row: Dictionary in group: _build_row(list, row)
	if _catalog.is_empty():
		var empty = Label.new()
		empty.text = "暂无已知行纪"
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", LIGHT_INK)
		list.add_child(empty)
	var selected: Dictionary = _row(browse_arc_id)
	var title: String = String(selected.get("display_title", "暂无已知事项"))
	var status_text: String = String(STATUS_NAMES.get(selected.get("status", ""), "暂无记载"))
	if selected.get("status", "") == "completed": status_text += " · 已完成 · 仅供阅读"
	elif browse_arc_id == source_session.tracked_arc_id and not browse_arc_id.is_empty(): status_text += " · 当前手动追踪"
	else: status_text += " · 仅查看"
	Folio.mark(frame, "diamond", Rect2(450,65,22,22), SECONDARY_INK)
	_text(frame, status_text, Rect2(481,66,544,29), 17, SECONDARY_INK, "JournalBrowseStatus")
	var title_height: float = Folio.heading_font().get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, 668, 52, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
	if title_height <= Folio.heading_font().get_height(52) * 2.0 + 4:
		var title_box_height: float = maxf(75,title_height + 4)
		_heading(frame, title, Rect2(453,97,668,title_box_height), 52, INK, "JournalBrowseTitle")
		var rule_y: float = 105 + title_box_height
		Folio.rule(frame, Rect2(455,rule_y,382,1), Color("a39172"))
		var body_y: float = rule_y + 29
		Folio.reading_wash(frame, Rect2(449,body_y-2,404,557-body_y), .93)
		body = _rich(frame, _detail_text(selected), Rect2(454,body_y,391,553-body_y), 22, "JournalBody")
	else:
		# Exceptionally long identities are never clipped or silently abbreviated.
		# Put the actual title into the same real scrolling reading area as its prose.
		Folio.reading_wash(frame, Rect2(449,102,665,454), .98)
		body = _rich(frame, "[font_size=42]" + _bbcode_escape(title) + "[/font_size]\n\n" + _detail_text(selected), Rect2(454,108,652,446), 22, "JournalBody")
	body.bbcode_enabled = true
	body.tooltip_text += "；已得见闻可由下方书页入口阅读"
	_focus_order.append(body)
	_focus_order.append(guidance_body)
	var automatic: Button = action_buttons.get("auto")
	if is_instance_valid(automatic) and not automatic.disabled: _focus_order.append(automatic)

func _build_row(parent: Control, row: Dictionary) -> void:
	var id: String = String(row.id)
	var browsed: bool = id == browse_arc_id
	var tracked: bool = id == source_session.tracked_arc_id
	var effective: bool = id == String(guidance_snapshot.get("arc_id", ""))
	var row_title: String = String(row.display_title)
	var title_height: float = maxf(32,Folio.heading_font().get_multiline_string_size(row_title, HORIZONTAL_ALIGNMENT_LEFT, 192, 24, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y + 2)
	var row_height: float = title_height + 38
	var button: Button = _button(parent, "", Rect2(0,0,244,row_height), _browse_bound.bind(id, _view_token), "JournalRow_" + id, browsed, "row")
	button.custom_minimum_size = Vector2(0,row_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("journal_row", id)
	button.tooltip_text = row_title + "：" + String(STATUS_NAMES.get(row.status, "")) + "；按 Enter 或点击仅查看"
	if browsed:
		var ribbon = Folio.Ribbon.new()
		ribbon.name = "JournalBrowseRibbon"
		ribbon.show_behind_parent = true
		ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ribbon.offset_top = 1
		ribbon.offset_bottom = -1
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(ribbon)
	Folio.mark(button, "diamond" if browsed or not effective else "compass", Rect2(9,12,24,24), LIGHT_INK if browsed else Folio.BRASS)
	_heading(button, row_title, Rect2(41,7,192,title_height), 24, LIGHT_INK, "JournalRowTitle")
	var state_text: String = "查看中" if browsed else String(STATUS_NAMES.get(row.status, ""))
	if effective: state_text += " · 当前指引"
	elif tracked: state_text += " · 追踪中"
	# Browsing and effective guidance can coincide: keep both marks and words.
	if browsed and effective:
		Folio.mark(button, "compass", Rect2(13,title_height+9,17,17), LIGHT_INK)
	_text(button, state_text, Rect2(42,title_height+8,192,24), 16, LIGHT_INK if browsed else Folio.BRASS, "JournalRowStatus")
	row_buttons[id] = button
	_visible_rows.append(id)
	_focus_order.append(button)

func _build_history(frame: Control) -> void:
	Folio.mark(frame, "book", Rect2(190,135,106,106), Folio.BRASS)
	_heading(frame, "已得见闻", Rect2(146,268,240,42), 29, LIGHT_INK, "JournalHistoryIndex")
	_text(frame, "只记已经历的来路。\n\n故事选择、已知结果，\n都留在这一册中。", Rect2(149,327,227,139), 18, LIGHT_INK, "JournalHistoryIntroduction")
	_text(frame, "已得见闻 · 仅收录已经历的记载", Rect2(454,66,640,30), 17, SECONDARY_INK, "JournalHistoryTitle")
	_heading(frame, "详细行纪", Rect2(453,102,668,80), 52, INK, "JournalHistoryHeading")
	Folio.rule(frame, Rect2(455,192,630,1), Color("a39172"))
	if _history_catalog != _catalog or _history_text.is_empty():
		var sections: Array[String] = []
		for row: Dictionary in _catalog:
			var history: String = String(row.get("earned_history", ""))
			if history.is_empty(): continue
			sections.append(String(row.display_title) + " · " + String(STATUS_NAMES.get(row.status, "")) + "\n" + history)
		_history_text = "\n\n────────────────\n\n".join(sections)
		if _history_text.is_empty(): _history_text = "暂无已得见闻。"
		_history_catalog = _catalog.duplicate(true)
	Folio.reading_wash(frame, Rect2(449,219,659,357), .98)
	body = _rich(frame, _history_text, Rect2(454,223,646,351), 19, "JournalHistoryBody")
	_focus_order.append(body)
	_focus_order.append(guidance_body)

func _build_footer(frame: Control) -> void:
	Folio.rule(frame, Rect2(455,580,269,1), Color("b3a083"))
	if page == "history":
		var back_button: Button = _button(frame, "‹ 返回行纪", Rect2(805,604,220,52), _back_bound.bind(_view_token), "JournalAction_back")
		action_buttons["back"] = back_button
		_footer_order.assign(["back", "close"])
		_focus_order.append(back_button)
		_text(frame, "Esc 返回选途  ·  J 收起", Rect2(455,621,320,25), 16, SECONDARY_INK, "JournalHistoryBackHint")
		return
	var earned: Button = _button(frame, "已得见闻  ›", Rect2(454,590,239,48), _history_bound.bind(_view_token), "JournalAction_earned")
	earned.alignment = HORIZONTAL_ALIGNMENT_LEFT
	earned.add_theme_constant_override("outline_size", 0)
	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		var earned_style: StyleBoxFlat = earned.get_theme_stylebox(style_name).duplicate()
		earned_style.content_margin_left = 42
		earned.add_theme_stylebox_override(style_name, earned_style)
	Folio.mark(earned, "book", Rect2(4,11,28,28), INK)
	earned.tooltip_text = "阅读全部已得见闻；与详细行纪打开同一册，Esc 返回选途"
	action_buttons["earned"] = earned
	_focus_order.append(earned)
	_text(frame, "查看不会改变当前指引", Rect2(496,641,288,24), 16, SECONDARY_INK, "JournalBrowseHint")
	var track: Button = _button(frame, "追踪此事", Rect2(804,604,218,52), _track_bound.bind(browse_arc_id, _view_token), "JournalAction_track", false, "primary")
	var row: Dictionary = _row(browse_arc_id)
	track.disabled = not row.get("trackable", false) or browse_arc_id == source_session.tracked_arc_id
	if browse_arc_id == source_session.tracked_arc_id and not browse_arc_id.is_empty(): track.text = "已追踪此事"
	elif row.get("status", "") == "completed": track.text = "已完成 · 仅供阅读"
	elif row.is_empty(): track.text = "暂无可追踪事项"
	if track.disabled: track.add_theme_font_size_override("font_size", 19)
	track.tooltip_text = "此事已完成，仅供阅读" if not row.get("trackable", false) else ("当前已追踪此事" if track.disabled else "明确追踪查看中的事项；不会开始对话、移动或保存")
	action_buttons["track"] = track
	if not track.disabled: _focus_order.append(track)
	var history: Button = _button(frame, "详细行纪", Rect2(1047,604,115,52), _history_bound.bind(_view_token), "JournalAction_history")
	history.add_theme_font_override("font", Folio.heading_font())
	history.add_theme_font_size_override("font_size", 21)
	Folio.rule(history, Rect2(14,43,87,1), Color("a39172"))
	action_buttons["history"] = history
	_focus_order.append(history)
	# Keep the established post-Track/Auto fallback order despite the new placement.
	_footer_order.assign(["track", "auto", "history", "close"])

func _detail_text(row: Dictionary) -> String:
	if row.is_empty(): return "暂没有可供阅读的事项。"
	var lines: Array[String] = []
	lines.append("[font_size=24][color=#5d251e]下一步[/color][/font_size]\n" + _bbcode_escape(String(row.get("next_action", ""))))
	if row.get("trackable", false):
		var preview: Dictionary = host.journal_preview(String(row.id)).duplicate(true)
		lines.append("[font_size=19][color=#3d3428]查看中的行路[/color]\n[/font_size]" + _paragraph_span(_route_text(preview), 19))
	else:
		lines.append(_paragraph_span("已完成事项仅供阅读。\n由下方“已得见闻”阅读完整记载。", 19, "#3d3428"))
	return "\n\n".join(lines)

func _paragraph_span(value: String, pixels: int, color: String = "") -> String:
	var parts: PackedStringArray = value.split("\n", true)
	var result: String = ""
	for i: int in parts.size():
		var piece: String = _bbcode_escape(parts[i])
		if i < parts.size() - 1: piece += "\n"
		result += "[font_size=%d]" % pixels
		if not color.is_empty(): result += "[color=" + color + "]"
		result += piece
		if not color.is_empty(): result += "[/color]"
		result += "[/font_size]"
	return result

func _bbcode_escape(value: String) -> String:
	return value.replace("[", "[lb]")

func _guidance_text(snapshot: Dictionary) -> String:
	var mode: String = "正在追踪" if snapshot.get("mode", "auto") == "manual" else "自动指引"
	if snapshot.get("kind", "") == "exploration": mode += " · 自由行路"
	var lines: Array[String] = [String(snapshot.get("arc_title", "自由行路")) + "  /  " + mode]
	var action: String = String(snapshot.get("next_action", ""))
	if not action.is_empty(): lines.append(action)
	lines.append(_route_text(snapshot))
	return "\n".join(lines)

func _route_text(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	var destination: String = String(snapshot.get("destination_map", ""))
	if not destination.is_empty(): lines.append("目的地：" + String(Objectives.MAP_NAMES.get(destination, "当前地区")))
	var target: String = String(snapshot.get("next_target_name", ""))
	if not target.is_empty():
		var prefix: String = "先往：" if snapshot.get("route_status", "") in ["via_exit", "via_crossing", "departure_confirmation"] else "下一处："
		lines.append(prefix + target)
	var note: String = String(snapshot.get("route_note", ""))
	if not note.is_empty(): lines.append(note)
	if lines.is_empty(): lines.append("暂无可标出的下一处。")
	return "  ·  ".join(lines)

func _button(parent: Control, text: String, rect: Rect2, callback: Callable, node_name: String, selected: bool = false, role: String = "paper_quiet") -> Button:
	var button = Button.new()
	button.name = node_name
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Folio.skin_button(button, role, selected)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _text(parent: Control, text: String, rect: Rect2, pixels: int, color: Color, node_name: String = "") -> Label:
	var label: Label = host._label(parent, text, rect, pixels, color)
	label.add_theme_font_override("font", Folio.BODY_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not node_name.is_empty(): label.name = node_name
	return label

func _heading(parent: Control, text: String, rect: Rect2, pixels: int, color: Color, node_name: String = "") -> Label:
	var label: Label = _text(parent, text, rect, pixels, color, node_name)
	label.add_theme_font_override("font", Folio.heading_font())
	label.add_theme_constant_override("line_spacing", 0)
	return label

func _rich(parent: Control, text: String, rect: Rect2, pixels: int, node_name: String, dark: bool = false) -> RichTextLabel:
	var region = RichTextLabel.new()
	region.name = node_name
	region.position = rect.position
	region.size = rect.size
	region.text = text
	region.bbcode_enabled = false
	region.scroll_active = true
	region.selection_enabled = true
	region.focus_mode = Control.FOCUS_ALL
	region.mouse_filter = Control.MOUSE_FILTER_STOP
	region.add_theme_font_override("normal_font", Folio.BODY_FONT)
	region.add_theme_font_size_override("normal_font_size", pixels)
	region.add_theme_color_override("default_color", LIGHT_INK if dark else INK)
	region.add_theme_color_override("font_selected_color", INK if dark else LIGHT_INK)
	region.add_theme_color_override("selection_color", Folio.BRASS if dark else FOCUS_INK)
	region.add_theme_constant_override("line_separation", 7 if pixels >= 19 else 5)
	region.add_theme_stylebox_override("normal", Folio.style(Color(.025,.06,.07,.55) if dark else Color.TRANSPARENT))
	region.add_theme_stylebox_override("focus", Folio.focus_style(dark))
	region.tooltip_text = "滚轮或滚动条翻阅；Tab 聚焦后用方向键、PageUp / PageDown、Home / End 翻阅"
	region.gui_input.connect(_body_input.bind(region, _view_token))
	parent.add_child(region)
	_style_scrollbar(region.get_v_scroll_bar(), dark)
	return region

func _style_scrollbar(bar: VScrollBar, dark: bool = false) -> void:
	Folio.scrollbar(bar, dark)

func _body_input(event: InputEvent, region: RichTextLabel, expected: Dictionary) -> void:
	if not _callback_valid(expected) or not is_instance_valid(region): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: region.grab_focus()

func _input(event: InputEvent) -> void:
	if not valid() or get_viewport().is_input_handled() or not event is InputEventKey: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if not event.pressed: return
	# Native Buttons alone activate Enter/Space. Repeats must not activate anything.
	if event.echo:
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F12: return
	if key in BLOCKED_KEYS:
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_J, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		if key == KEY_ESCAPE and page == "history": _back_bound(_view_token)
		else: _close_bound(_view_token)
		return
	if key == KEY_TAB:
		get_viewport().set_input_as_handled()
		_cycle_focus(-1 if event.shift_pressed else 1)
		return
	if key in SCROLL_KEYS:
		get_viewport().set_input_as_handled()
		_navigate(key)
		return
	if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not is_ancestor_of(focused):
			get_viewport().set_input_as_handled()
			_focus_key("", _view_token)
		return

func _navigate(key: int) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == body or focused == guidance_body:
		_scroll_region(focused as RichTextLabel, key)
		return
	if page == "journal" and is_instance_valid(focused) and focused.has_meta("journal_row"):
		var index: int = _visible_rows.find(String(focused.get_meta("journal_row")))
		if index < 0 or _visible_rows.is_empty(): return
		match key:
			KEY_HOME: index = 0
			KEY_END: index = _visible_rows.size() - 1
			KEY_PAGEUP: index = _page_row_index(index, -1)
			KEY_PAGEDOWN: index = _page_row_index(index, 1)
			KEY_UP, KEY_LEFT: index -= 1
			KEY_DOWN, KEY_RIGHT: index += 1
		index = clampi(index, 0, _visible_rows.size() - 1)
		_browse_bound(_visible_rows[index], _view_token)
		return
	# Header, disclosure and footer controls follow explicit neighbors, never rows by position.
	_cycle_focus(-1 if key in [KEY_LEFT, KEY_UP, KEY_PAGEUP, KEY_HOME] else 1)

func _page_row_index(index: int, direction: int) -> int:
	# Wrapped titles and section headings make a fixed row pitch inaccurate.
	var start: Control = row_buttons.get(_visible_rows[index])
	if not is_instance_valid(start): return index
	var target_y: float = start.get_global_rect().position.y + direction * _list_scroll.size.y * .85
	var next_index: int = clampi(index + direction, 0, _visible_rows.size() - 1)
	while next_index != index:
		index = next_index
		var candidate: Control = row_buttons.get(_visible_rows[index])
		if not is_instance_valid(candidate): break
		var y: float = candidate.get_global_rect().position.y
		if (direction > 0 and y >= target_y) or (direction < 0 and y <= target_y): break
		next_index = clampi(index + direction, 0, _visible_rows.size() - 1)
	return index

func _scroll_region(region: RichTextLabel, key: int) -> void:
	var bar: VScrollBar = region.get_v_scroll_bar()
	match key:
		KEY_UP, KEY_LEFT: bar.value -= 36.0
		KEY_DOWN, KEY_RIGHT: bar.value += 36.0
		KEY_PAGEUP: bar.value -= region.size.y * .85
		KEY_PAGEDOWN: bar.value += region.size.y * .85
		KEY_HOME: bar.value = bar.min_value
		KEY_END: bar.value = bar.max_value

func _link_focus() -> void:
	for i: int in _focus_order.size():
		var item: Control = _focus_order[i]
		var previous: Control = _focus_order[posmod(i-1, _focus_order.size())]
		var next: Control = _focus_order[(i+1) % _focus_order.size()]
		item.focus_previous = item.get_path_to(previous)
		item.focus_next = item.get_path_to(next)
		item.focus_neighbor_left = item.get_path_to(previous)
		item.focus_neighbor_top = item.get_path_to(previous)
		item.focus_neighbor_right = item.get_path_to(next)
		item.focus_neighbor_bottom = item.get_path_to(next)

func _cycle_focus(direction: int) -> void:
	if _focus_order.is_empty(): return
	var index: int = _focus_order.find(get_viewport().gui_get_focus_owner())
	if index < 0: index = -1 if direction > 0 else 0
	var target: Control = _focus_order[posmod(index + direction, _focus_order.size())]
	target.grab_focus()
	if is_instance_valid(_list_scroll) and _list_scroll.is_ancestor_of(target): _list_scroll.ensure_control_visible(target)

func _focused_key() -> String:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == body: return "body"
	if focused == guidance_body: return "guidance"
	for id: String in row_buttons:
		if focused == row_buttons[id]: return "row:" + id
	for key: String in action_buttons:
		if focused == action_buttons[key]: return "action:" + key
	return ""

func _nearest_footer(key: String) -> String:
	var index: int = _footer_order.find(key)
	if index < 0: index = 0
	for offset: int in _footer_order.size():
		var candidate: String = _footer_order[(index + offset) % _footer_order.size()]
		var button: Button = action_buttons.get(candidate)
		if is_instance_valid(button) and not button.disabled: return "action:" + candidate
	return "action:header_close"

func _focus_key(key: String, expected: Dictionary) -> void:
	if not _callback_valid(expected): return
	var control: Control
	if key == "body": control = body
	elif key == "guidance": control = guidance_body
	elif key.begins_with("row:"): control = row_buttons.get(key.trim_prefix("row:"))
	elif key.begins_with("action:"):
		var action: String = key.trim_prefix("action:")
		control = action_buttons.get(action)
		if control is Button and control.disabled: control = action_buttons.get(_nearest_footer(action).trim_prefix("action:"))
	if not is_instance_valid(control):
		control = row_buttons.get(browse_arc_id)
		if not is_instance_valid(control): control = body
	if not is_instance_valid(control): return
	control.grab_focus()
	if is_instance_valid(_list_scroll) and _list_scroll.is_ancestor_of(control):
		# Restoring the bar queues container sorting. Reveal only after that layout
		# boundary, without retaining a row object or stealing newer GUI focus.
		var reveal: Callable = _reveal_list_focus_after_layout.bind(control.get_instance_id(), _list_scroll.get_instance_id(), expected)
		if not get_tree().process_frame.is_connected(reveal): get_tree().process_frame.connect(reveal, CONNECT_ONE_SHOT)

func _reveal_list_focus_after_layout(control_id: int, scroll_id: int, expected: Dictionary) -> void:
	if not _callback_valid(expected) or not is_instance_valid(_list_scroll) or _list_scroll.get_instance_id() != scroll_id: return
	var control: Control = get_viewport().gui_get_focus_owner()
	if not is_instance_valid(control) or not control.is_inside_tree() or control.get_instance_id() != control_id or not _list_scroll.is_ancestor_of(control): return
	_list_scroll.ensure_control_visible(control)

func _restore_scroll(expected: Dictionary) -> void:
	if not _callback_valid(expected): return
	if is_instance_valid(_list_scroll): _list_scroll.scroll_vertical = _journal_scroll
	if is_instance_valid(guidance_body): guidance_body.get_v_scroll_bar().value = _guidance_scroll
	if is_instance_valid(body): body.get_v_scroll_bar().value = _history_scroll if page == "history" else _journal_body_scroll
