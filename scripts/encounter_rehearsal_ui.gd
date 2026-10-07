extends Control
## A read-only folio over model-earned encounters and acknowledged results.
## The model owns isolation; this page owns scene identity and explicit entry.
const Folio = preload("res://scripts/folio_theme.gd")
const Portraits = preload("res://scripts/character_portraits.gd")
const DuHui = preload("res://scripts/painted_battle_duhui.gd")
const Skills = preload("res://scripts/combat_skill_catalog.gd")
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
const POLICY = "encounter_rehearsal"
var host
var source_state
var generation: int
var encounter_id: String = ""
var page: String = "preview"
var baseline: Dictionary = {}
var metadata: Dictionary = {}
var options: Array = []
var result_rows: Array = []
var card_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var frame: Control
var scroll: ScrollContainer
var content: VBoxContainer
var footer_notice: Label
var retired: bool = false
var starting: bool = false
var _built: bool = false


static func courtyard_ready(owner) -> bool:
	if not is_instance_valid(owner) or not is_instance_valid(owner.world) or not is_instance_valid(owner.state): return false
	if owner.current_screen != "explore" or owner.quit_pending or owner.state.battle_active: return false
	if owner.state._party_gate() or owner.state._party_pending_token >= 0: return false
	if owner.state.map_id != "qingwei" or owner.world.map_id != "qingwei": return false
	if not owner.world.interactables.has("courtyard_practice"): return false
	var place: Variant = owner.world.interactables.courtyard_practice.get("pos")
	return place is Vector2 and place.is_finite() and owner.world.player_pos.is_finite() and owner.world.player_pos.distance_to(place) < 85.0


static func open(owner, selected: String = "", view: String = "preview") -> Control:
	if not courtyard_ready(owner) or view not in ["preview", "results"]: return null
	var catalog: Dictionary = owner.state.rehearsal_options()
	if not catalog.get("ok", false): return null
	var earned: Array = catalog.get("options", [])
	if selected.is_empty() and not earned.is_empty(): selected = String(earned[0].encounter_id)
	if not selected.is_empty():
		var found: bool = false
		for entry: Dictionary in earned:
			if entry.encounter_id == selected: found = true
		if not found: return null
	var preview: Dictionary = {} if selected.is_empty() else owner.state.rehearsal_preview(selected)
	if not selected.is_empty() and not preview.get("ok", false): return null
	owner._begin_rehearsal_position_hold()
	owner.modal_generation += 1
	owner._clear_overlay()
	owner.active_modal = true
	owner.modal_autosave_on_close = false
	var panel = load("res://scripts/encounter_rehearsal_ui.gd").new()
	panel.host = owner; panel.source_state = owner.state; panel.generation = owner.modal_generation
	panel.encounter_id = selected; panel.page = view; panel.options = earned.duplicate(true)
	panel.baseline = owner.state.PartyCatalog.immutable(owner.state.to_dict())
	panel.metadata = preview.get("metadata", {}).duplicate(true)
	if view == "results":
		var history: Dictionary = owner.state.rehearsal_comparison_snapshot()
		if history.get("comparison_key", "") == panel.metadata.get("comparison_key", ""):
			for result: Dictionary in history.get("results", []):
				if result.get("metadata", {}).get("comparison_key", "") == panel.metadata.get("comparison_key", "") and result.get("metrics", {}).get("outcome", "") in ["win", "defeat", "flee"]:
					panel.result_rows.append(result.duplicate(true))
		while panel.result_rows.size() > 2: panel.result_rows.pop_front()
	owner.overlay.set_meta("encounter_rehearsal", panel)
	owner.overlay.add_child(panel)
	panel.build()
	owner._refresh()
	return panel


func owns_page() -> bool:
	return not retired and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) \
		and not host.quit_pending and host.current_screen == "explore" and host.active_modal \
		and host.state == source_state and host.modal_generation == generation \
		and host.overlay.get_meta("encounter_rehearsal", null) == self


func valid() -> bool:
	return owns_page() and not source_state.battle_active and source_state._same_save_value(source_state.to_dict(), baseline)


func entry_ready(id: String) -> bool:
	if starting or not valid() or id != encounter_id or metadata.is_empty() or not courtyard_ready(host): return false
	var current: Dictionary = source_state.rehearsal_preview(id)
	return current.get("ok", false) and current.metadata.get("comparison_key", "") == metadata.get("comparison_key", "")


func invalidate_callbacks() -> void:
	retired = true
	set_process(false)
	set_process_input(false)


func choose(id: String) -> void:
	if not valid() or starting: return
	var next = open(host, id)
	if next != null and next.card_buttons.has(id): next.card_buttons[id].grab_focus()


func start() -> void:
	if not entry_ready(encounter_id): return
	# PartyUI checks this same controller identity before the model starts.
	host.PartyUI.open_rehearsal(host, self, encounter_id)


func back() -> void:
	if not owns_page() or starting: return
	if page == "results" and valid(): open(host, encounter_id)
	else: close()


func close() -> void:
	if not owns_page() or starting: return
	host.modal_autosave_on_close = false
	host._close_modal()


func _input(event: InputEvent) -> void:
	if not owns_page() or not event is InputEventKey or not event.pressed: return
	var code: int = event.physical_keycode
	if code not in [KEY_ESCAPE, KEY_1, KEY_2, KEY_F5]: return
	get_viewport().set_input_as_handled()
	if event.echo: return
	if code == KEY_ESCAPE: back()
	elif code in [KEY_1, KEY_2] and page == "preview":
		var index: int = code - KEY_1
		if index < options.size(): choose(String(options[index].encounter_id))
	# Native Tab/Enter/Space own the actual focused control. F5 cannot save browsing.


func _process(_delta: float) -> void:
	if not _built or not owns_page(): return
	# The authoritative factory is rechecked on entry, not rebuilt every frame.
	var ready: bool = not starting and valid() and not metadata.is_empty() and courtyard_ready(host)
	if action_buttons.has("start"): action_buttons.start.disabled = not ready
	if not valid(): footer_notice.text = "旅程已改变，请返回南庭后重新打开。"
	elif not courtyard_ready(host): footer_notice.text = "请回到南庭木人旁再开始。"


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil = ColorRect.new(); veil.color = Color(.01, .04, .04, .78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(veil)
	frame = Control.new(); frame.name = "RehearsalFrame"; add_child(frame)
	Folio.backing(frame, Rect2(0, 0, 1200, 714))
	var wash = Folio.reading_wash(frame, Rect2(456, 145, 662, 465), .90)
	wash.name = "RehearsalReadingPaper"
	_label(frame, "RehearsalTitle", "旧 战 复 演", 29, Folio.BONE, true)
	_label(frame, "RehearsalSubtitle", "南庭手记 · 已历交锋", 16, Folio.BRASS)
	_label(frame, "RehearsalEarnedCount", "已收录 %d 场" % options.size(), 17, Folio.BONE)
	for entry: Dictionary in options:
		var id: String = entry.encounter_id
		var button = _button(frame, "RehearsalCard_" + id, String(entry.name), choose.bind(id), "row")
		button.text += "\n" + ("双敌 · 拦护与急攻" if id == "heting_consignee" else "单敌 · 守势与露隙")
		button.text += "\n" + ("正在查阅" if id == encounter_id else "查看这场交锋")
		button.add_theme_font_size_override("font_size", 18)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Folio.skin_button(button, "row", id == encounter_id)
		if id == encounter_id:
			var ribbon = Folio.Ribbon.new(); ribbon.show_behind_parent = true
			ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE; button.add_child(ribbon)
		card_buttons[id] = button
	_label(frame, "RehearsalScopeTitle", "借一场交锋，试眼下功夫", 18, Folio.BONE, true)
	_label(frame, "RehearsalScope", "当前等级与出战队伍\n保留阵法、已学与已装招式\n\n演练内满气血、满真气\n借用3份药，每份恢复40气血\n\n真实资源、修为、剧情不变\n不发奖励", 16, Folio.BONE)
	action_buttons.close = _button(frame, "RehearsalClose", "回到南庭 ×", close, "header_close")
	_label(frame, "RehearsalEyebrow", "同条件再试 · 本次会话" if page == "results" else "依当前功夫复演 · 不还原当年等级", 16, Folio.SECONDARY_INK)
	var title: String = "还没有可复演的交锋" if metadata.is_empty() else String(metadata.name).replace("复演", "")
	_label(frame, "RehearsalHeading", "本次演练记" if page == "results" else title, 32, Folio.INK, true)
	var scenario: String = "在旅途中亲自战胜对手后，回南庭翻开这页。" if metadata.is_empty() else _scenario_text()
	_label(frame, "RehearsalScenario", scenario, 17, Folio.SECONDARY_INK)
	if not metadata.is_empty():
		var portrait = TextureRect.new(); portrait.name = "RehearsalOpponent"
		portrait.texture = DuHui.texture_for("idle") if encounter_id == "heting_consignee" else Portraits.texture_for("liang_zhen")
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(portrait)
	var rule = Folio.rule(frame, Rect2(), Folio.BRASS); rule.name = "RehearsalPageRule"
	scroll = ScrollContainer.new(); scroll.name = "RehearsalContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true; frame.add_child(scroll)
	Folio.scrollbar(scroll.get_v_scroll_bar())
	# Reserve a real layout gutter: wrapped ink must end before the scrollbar,
	# including the final Chinese glyph on a line at compact physical sizes.
	var reading_margin = MarginContainer.new(); reading_margin.name = "RehearsalReadingMargin"
	reading_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_margin.add_theme_constant_override("margin_right", 24)
	scroll.add_child(reading_margin)
	content = VBoxContainer.new(); content.name = "RehearsalContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4 if page == "preview" else 12)
	reading_margin.add_child(content)
	if metadata.is_empty():
		_body("RehearsalEmpty", "已完成的交锋才会收入手记。继续赶路，见过的招式自会留下。", 20)
	elif page == "results": _build_results()
	else: _build_preview()
	Folio.scroll_edges(frame, scroll.get_v_scroll_bar(), Rect2())
	if not metadata.is_empty():
		action_buttons.start = _button(frame, "RehearsalStart", "同条件再试" if page == "results" else "开始复演", start, "primary")
		action_buttons.start.disabled = not entry_ready(encounter_id)
	action_buttons.back = _button(frame, "RehearsalBack", "查看队伍与招式" if page == "results" else "回到南庭", back, "paper_quiet")
	footer_notice = _label(frame, "RehearsalFooterNotice", "仅保留本次会话最近两次同条件结果" if page == "results" else "开始后使用演练资源 · 不自动保存", 15, Folio.SECONDARY_INK)
	var help_backing = ColorRect.new(); help_backing.name = "RehearsalKeyboardBacking"
	help_backing.color = Color(.04,.08,.09,.88); help_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(help_backing)
	var keyboard_help = _label(frame, "RehearsalKeyboardHelp", "Tab 移动焦点 · Enter / 空格选择 · Esc 返回 · 滚轮阅读", 15, Folio.BONE)
	keyboard_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	keyboard_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_built = true
	resized.connect(_layout)
	_layout()
	# Standalone wrapped labels first measure at their assigned width, then
	# shrink from the temporary zero-width minimum created during construction.
	_layout.call_deferred()
	action_buttons.close.grab_focus()


func _scenario_text() -> String:
	var names: Array[String] = []
	for enemy: Dictionary in metadata.get("enemy_specs", []): names.append(String(enemy.get("name", "")))
	var site: String = "北仓提货位" if encounter_id == "heting_consignee" else "霜桥印台"
	return "%s · %s\n沿用已历交锋的招式与节奏" % [site, " / ".join(names)]


func _build_preview() -> void:
	var team: Dictionary = metadata.team
	_body("RehearsalPartySummary", "当前出战 %d 人 · %s · 主角 %d 级" % [team.actors.size(), team.formation, metadata.level], 22, true)
	for actor: Dictionary in team.actors:
		var row = HBoxContainer.new(); row.name = "RehearsalActor_" + String(actor.id)
		row.add_theme_constant_override("separation", 14); content.add_child(row)
		var portrait = TextureRect.new(); portrait.name = "PartyPortrait"
		portrait.texture = Portraits.texture_for(String(actor.id)); portrait.custom_minimum_size = Vector2(64, 68)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(portrait)
		var ink = VBoxContainer.new(); ink.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ink.add_theme_constant_override("separation", 0); row.add_child(ink)
		var name_line = _label(ink, "PartyActorName", String(actor.name), 19, Folio.INK, true)
		name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(ink, "PartyActorStats", "气血 %d / %d · 真气 %d / %d · 攻 %d / 防 %d" % [actor.max_hp, actor.max_hp, actor.max_qi, actor.max_qi, actor.attack, actor.defense], 17, Folio.INK)
		var skills: Array[String] = []
		for skill: Dictionary in Skills.manual_actions(actor): skills.append(String(skill.name))
		_label(ink, "PartyActorSkills", " / ".join(skills), 16, Folio.SECONDARY_INK)
	var hero: Dictionary = team.actors[0]
	_body("RehearsalEquipment", "当前装束：%s / %s\n已装配：%s · 主动武学熟练 %d 阶" % [hero.equipment, hero.armor, Fittings.LABELS.get(metadata.installed_fitting, metadata.installed_fitting), hero.art_rank], 17)
	_body("RehearsalCombatRules", "每位存活队员每轮自动普攻一次。武学、内功、轻功仍为三个固定槽位；未习得的招式保持未习。\n可按 P 收招后暂停，再安排技能或用药。", 17)


func _build_results() -> void:
	if result_rows.is_empty():
		_body("RehearsalNoResults", "当前条件下还没有已完成的演练记录。", 20)
		return
	var latest: Dictionary = result_rows[-1]
	_body("RehearsalOutcome", "本次 · " + _outcome(String(latest.metrics.outcome)), 24, true)
	_body("RehearsalMetrics", _metrics_text(latest.metrics), 20)
	var losses: Array[String] = []
	for actor: Dictionary in latest.metadata.team.actors:
		losses.append("%s %d" % [actor.name, int(latest.metrics.actual_hp_lost_by_actor.get(actor.id, 0))])
	_body("RehearsalActorLosses", "实际失血：" + " · ".join(losses), 17)
	_body("RehearsalMetricsMeaning", "失血按实际扣除气血累计，治疗不会抵销；已被防御、护势和轻功抵消的伤害不计。敌方攻击只统计实际执行的攻击。", 16)
	_body("RehearsalRoundMeaning", "完整回合为已经走完的回合；结束所在回合可能尚未走完。退避会如实记录为退避。", 16)
	_body("RehearsalComparisonHeading", "最近两次 · 相同条件" if result_rows.size() == 2 else "同条件对照", 21, true)
	if result_rows.size() == 2:
		_body("RehearsalPreviousMetrics", "上次 · %s\n%s" % [_outcome(String(result_rows[0].metrics.outcome)), _metrics_text(result_rows[0].metrics)], 17)
	else:
		_body("RehearsalFirstResult", "这是本次会话的首份记录。再试一次，就能对照相同队伍与招式下的结果。", 17)
	_body("RehearsalComparisonScope", "仅比较相同对手、队伍、阵法、等级、已学招式、装配与演练规则；条件变化后重新记录。结果不会写入真实旅程。", 16)


static func _outcome(value: String) -> String:
	return {"win": "演练获胜", "defeat": "演练失利", "flee": "中途退避"}.get(value, "未完成")


static func _metrics_text(metrics: Dictionary) -> String:
	return "全队实际失血 %d · 用药 %d / 3\n敌方实际攻击 %d 次\n完整回合 %d · 结束于第 %d 回合" % [int(metrics.total_actual_hp_lost), int(metrics.medicine_used), int(metrics.enemy_attacks_executed), int(metrics.completed_rounds), int(metrics.terminal_round)]


func _body(node_name: String, text: String, font_size: int, heading: bool = false) -> Label:
	var label = _label(content, node_name, text, font_size, Folio.INK if heading or font_size >= 17 else Folio.SECONDARY_INK, heading)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _label(parent: Node, node_name: String, text: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label = Label.new(); label.name = node_name; label.text = text
	label.add_theme_font_override("font", Folio.heading_font() if heading else Folio.BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, action: Callable, role: String) -> Button:
	var button = Button.new(); button.name = node_name; button.text = text
	button.focus_mode = Control.FOCUS_ALL; button.pressed.connect(action); parent.add_child(button)
	Folio.skin_button(button, role)
	return button


func _rect(node_name: String, rect: Rect2) -> void:
	var control = frame.get_node_or_null(node_name)
	if control != null: control.position = rect.position; control.size = rect.size


func _layout() -> void:
	if not _built: return
	var available: Vector2 = size if size.x > 0 and size.y > 0 else Vector2(1280, 800)
	var width: float = minf(1200, minf(available.x - 40, (available.y - 58) * 1496.0 / 890.0))
	var factor: float = width / 1200.0
	var height: float = width * 890.0 / 1496.0
	frame.size = Vector2(width, height); frame.position = (available - frame.size) * .5
	var left: float = 138 * factor; var cloth: float = 250 * factor
	var right: float = 456 * factor; var paper: float = 662 * factor
	_rect("FolioDecorativeBacking", Rect2(0, 0, width, height))
	_rect("RehearsalTitle", Rect2(left, 25 * factor, cloth, 44))
	_rect("RehearsalSubtitle", Rect2(left, 78 * factor, cloth, 30))
	_rect("RehearsalEarnedCount", Rect2(left, 124 * factor, cloth, 28))
	for index: int in range(options.size()):
		_rect("RehearsalCard_" + String(options[index].encounter_id), Rect2(left, (171 + 114 * index) * factor, cloth, 102 * factor))
	_rect("RehearsalScopeTitle", Rect2(left, 414 * factor, cloth, 34))
	_rect("RehearsalScope", Rect2(left, 460 * factor, cloth, height - 460 * factor - 45))
	frame.get_node("RehearsalScope").add_theme_font_size_override("font_size", 16)
	_rect("RehearsalClose", Rect2(width - 177 * factor, 20 * factor, 150 * factor, 44))
	_rect("RehearsalEyebrow", Rect2(right, 30 * factor, paper - 180 * factor, 28))
	_rect("RehearsalHeading", Rect2(right, 74 * factor, paper - 112 * factor, 49))
	_rect("RehearsalScenario", Rect2(right, 121 * factor, paper - 114 * factor, 52))
	_rect("RehearsalOpponent", Rect2(right + paper - 108 * factor, 71 * factor, 108 * factor, 100 * factor))
	_rect("RehearsalPageRule", Rect2(right, 179 * factor, paper, 1))
	var footer: float = height - 125 * factor
	var reading: Rect2 = Rect2(right, 192 * factor, paper, footer - 205 * factor)
	_rect("RehearsalContentScroll", reading)
	_rect("RehearsalContentScrollScrollEdges", reading.grow_individual(0, 7, 0, 7))
	_rect("RehearsalReadingPaper", Rect2(right - 18, 174 * factor, paper + 64, height - 192 * factor))
	_rect("RehearsalStart", Rect2(right, footer, 220 * factor, 50))
	_rect("RehearsalBack", Rect2(right + 241 * factor, footer, paper - 241 * factor, 50))
	_rect("RehearsalFooterNotice", Rect2(right, footer + 55, paper, 24))
	_rect("RehearsalKeyboardBacking", Rect2(left - 10, height - 35, width - left - 18, 29))
	_rect("RehearsalKeyboardHelp", Rect2(left, height - 33, width - left - 38, 24))
	frame.get_node("RehearsalReadingPaper").queue_redraw()
