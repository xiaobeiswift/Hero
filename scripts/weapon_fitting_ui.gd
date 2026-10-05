extends Control
## Disposable, identity-bound fitting pages. Only explicit confirmation saves.
const Fittings = preload("res://scripts/weapon_fitting_rules.gd")
const Trials = preload("res://scripts/weapon_fitting_trial_rules.gd")
const Paper = preload("res://scripts/inventory_panel.gd")
const Folio = preload("res://scripts/folio_theme.gd")
const SAVE_NOTICE = "存档提示：本版任何保存（包括原装）均写入格式16，旧版无法读取。升级前请自行保留旧档。自动续写不会额外备份，手动手记沿用原备份规则。"
const TITLE_SAVE_NOTICE = "所有保存均为格式16，旧版无法读取；自动存档不额外备份。"
const PAGES = ["preview", "confirm", "trial", "results"]
var host
var source_state
var generation: int
var candidate: String = "plain"
var profile: String = "ordinary"
var page: String = "preview"
var origin: String = "workshop"
var baseline: Dictionary = {}
var identity: Dictionary = {}
var candidate_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var result_rows: Array = []
var body: RichTextLabel
var details_open: bool = false
var details_button: Button
var overview_blocks: Array[Control] = []

class ReadingPaper extends Folio.ReadingWash:
	func _draw() -> void:
		# One continuous native tint; original folio grain remains underneath.
		# The inherited passive feather shader never repeats or enlarges texture.
		wash_material.set_shader_parameter("wash_size", size)
		draw_rect(Rect2(Vector2.ZERO,size), Color(.933,.890,.800,strength))

class DisclosureEdges extends Folio.ScrollEdges:
	var visibility_owner: Control
	func _refresh_edges() -> void:
		super._refresh_edges()
		visible = visible and is_instance_valid(visibility_owner) and visibility_owner.is_visible_in_tree()

static func open(owner, choice: String = "", view: String = "preview", preset: String = "ordinary", entry: String = "workshop") -> Control:
	if not _owner_ready(owner) or view not in PAGES or preset not in Trials.PROFILES or entry not in ["workshop", "courtyard"]: return null
	if choice.is_empty(): choice = owner.state.weapon_fitting
	if choice not in Fittings.IDS: return null
	owner._begin_fitting_position_hold()
	owner.modal_generation += 1
	owner._clear_overlay()
	owner.active_modal = true
	owner.modal_autosave_on_close = false
	var panel = load("res://scripts/weapon_fitting_ui.gd").new()
	panel.host = owner; panel.source_state = owner.state; panel.generation = owner.modal_generation
	panel.candidate = choice; panel.profile = preset; panel.page = view; panel.origin = entry
	panel.baseline = owner.state.PartyCatalog.immutable(owner.state.to_dict())
	panel.identity = {"candidate": choice, "profile": preset, "page": view, "origin": entry, "installed": owner.state.weapon_fitting}
	panel.identity.make_read_only()
	owner.overlay.set_meta("weapon_fitting", panel)
	owner.overlay.add_child(panel)
	panel.build()
	owner._refresh()
	return panel

static func _owner_ready(owner) -> bool:
	return is_instance_valid(owner) and owner.current_screen == "explore" and not owner.quit_pending \
		and owner.state != null and owner.state.get_script() != null \
		and owner.state.get_script().resource_path == "res://scripts/game_state.gd" \
		and not owner.state.battle_active and not owner.state._party_gate() and owner.state._party_pending_token < 0 \
		and owner.state.preview_weapon_fitting(owner.state.weapon_fitting).get("ok", false)

static func courtyard_ready(owner) -> bool:
	if not _owner_ready(owner) or not is_instance_valid(owner.world): return false
	if owner.state.map_id != "qingwei" or owner.world.map_id != "qingwei": return false
	if not owner.world.interactables.has("courtyard_practice"): return false
	var place: Variant = owner.world.interactables["courtyard_practice"].get("pos")
	return place is Vector2 and place.is_finite() and owner.world.player_pos.is_finite() \
		and owner.world.player_pos.distance_to(place) < 85.0

func valid() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _owner_ready(host) \
		and host.state == source_state and host.active_modal and host.modal_generation == generation \
		and host.overlay.get_meta("weapon_fitting", null) == self \
		and candidate == identity.get("candidate") and profile == identity.get("profile") \
		and page == identity.get("page") and origin == identity.get("origin") \
		and source_state.weapon_fitting == identity.get("installed") \
		and source_state._same_save_value(source_state.to_dict(), baseline)

func trial_entry_ready(choice: String, preset: String) -> bool:
	return valid() and page in ["trial", "results"] and choice == candidate and preset == profile \
		and courtyard_ready(host) and source_state.preview_weapon_fitting(choice).get("ok", false) \
		and source_state.quest_stage == 6 and Fittings.SECTS.has(source_state.sect)

func _replace(view: String, choice: String = "", preset: String = "") -> void:
	if not valid(): return
	open(host, candidate if choice.is_empty() else choice, view, profile if preset.is_empty() else preset, origin)

func choose_candidate(choice: String) -> void:
	if not valid() or choice not in Fittings.IDS: return
	_replace("trial" if page == "trial" else "preview", choice)

func choose_profile(preset: String) -> void:
	if not valid() or preset not in Trials.PROFILES: return
	_replace("trial", "", preset)

func confirm_selection() -> void:
	if not valid() or page not in ["preview", "trial"]: return
	if candidate == source_state.weapon_fitting or not source_state.preview_weapon_fitting(candidate).get("ok", false): return
	_replace("confirm")

func revert_original() -> void:
	if not valid() or source_state.weapon_fitting == "plain": return
	_replace("confirm", "plain")

func confirm_equip() -> void:
	if not valid() or page != "confirm": return
	var owner = host
	var chosen: String = candidate
	var preset: String = profile
	var entry: String = origin
	var result: Dictionary = source_state.set_weapon_fitting(chosen)
	if not result.get("ok", false): owner._toast(String(result.get("reason", "配件未能装配。"))); return
	if result.get("changed", false):
		owner._autosave()
		owner._refresh()
		owner._toast("已装配%s；当前选择尚未保存，请重试保存。" % Fittings.LABELS[chosen] if owner.save_warning else "已装配%s；可随时免费恢复原装。" % Fittings.LABELS[chosen], owner.save_warning)
	open(owner, chosen, "preview", preset, entry)

func retry_save() -> void:
	if not valid() or not host.save_warning: return
	var owner = host
	var chosen: String = candidate
	var preset: String = profile
	var entry: String = origin
	owner._autosave()
	owner._toast("当前旅程仍在内存，保存失败，请稍后重试。" if owner.save_warning else "当前真实旅程已保存；预览与借用不会被装配。", true)
	open(owner, chosen, "preview", preset, entry)

func prepare_trial() -> void:
	if valid(): _replace("trial")

func start_trial() -> void:
	if not trial_entry_ready(candidate, profile): return
	host.PartyUI.open_fitting(host, self, candidate, profile)

func show_results() -> void:
	if valid(): _replace("results")

func back() -> void:
	if not valid(): return
	if page in ["confirm", "trial"]: _replace("preview")
	else: close()

func return_workshop() -> void:
	if not valid(): return
	host.workshop.show(true)

func close() -> void:
	if not valid(): return
	host.modal_autosave_on_close = false
	host._close_modal()

func _input(event: InputEvent) -> void:
	if not valid() or not event is InputEventKey or not event.pressed: return
	var key: int = event.physical_keycode
	var own: bool = key in [KEY_ESCAPE, KEY_F5] or (key >= KEY_1 and key <= KEY_5)
	if not own: return # Native focus owns Tab/Enter/Space; Main skips fitting pages.
	get_viewport().set_input_as_handled()
	if event.echo: return
	if key == KEY_ESCAPE: back(); return
	if key == KEY_F5: retry_save(); return
	if page in ["preview", "trial"]:
		if key >= KEY_1 and key <= KEY_3: choose_candidate(Fittings.IDS[key - KEY_1])
		elif key == KEY_4: confirm_selection()
		elif key == KEY_5: prepare_trial() if page == "preview" else start_trial()
	elif page == "confirm":
		if key == KEY_1: confirm_equip()
		elif key == KEY_2: back()
	elif page == "results":
		if key == KEY_1: start_trial()
		elif key == KEY_2: prepare_trial()
		elif key == KEY_3: _replace("preview")

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil = ColorRect.new(); veil.color = Color(.01, .04, .04, .78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(veil)
	var frame = host._panel(self, Rect2(40,46,1200,714), Color.TRANSPARENT, Color.TRANSPARENT); frame.name = "FittingFrame"
	frame.add_theme_stylebox_override("panel", Folio.style(Color.TRANSPARENT))
	Folio.backing(frame, Rect2(0,0,1200,714))
	var paper = ReadingPaper.new(); paper.name = "FittingReadingPaper"
	paper.position = Vector2(438,156); paper.size = Vector2(744,470); paper.strength = .82
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE; paper.focus_mode = Control.FOCUS_NONE
	frame.add_child(paper)
	_heading(frame, "剑 上 配 件" if page != "results" else "南 庭 试 配 记", Rect2(138,26,250,40), 30, Folio.BONE, "FittingTitle")
	_text(frame, {"preview":"配件预览 / 只改主角攻击与防御", "confirm":"明确确认 / 免费装配与恢复", "trial":"借用试招 / 普通木人默认，可选高压", "results":"本次会话 / 最近两次同条件实测"}[page], Rect2(138,76,250,44), 15, Folio.BRASS)
	_text(frame, "当前已装配：%s  ·  实际攻击%d / 防御%d  ·  %s / %s" % [Fittings.LABELS[source_state.weapon_fitting], source_state.effective_attack(), source_state.effective_defense(), source_state.equipment, source_state.armor], Rect2(138,126,250,72), 16, Folio.BONE, "FittingInstalled")
	var exit_button = host._button(frame,"关闭 ×",Rect2(1038,20,136,48),close); exit_button.name = "FittingClose"; exit_button.focus_mode = Control.FOCUS_ALL
	Folio.skin_button(exit_button, "header_close"); exit_button.add_theme_font_size_override("font_size", 17)
	var status: String = "预览与当前已装配相同" if candidate == source_state.weapon_fitting else "仅预览 · 尚未装配"
	if page == "confirm": status = "明确确认 · 装配并保存当前真实旅程"
	elif page == "trial": status = "本次借用：%s · %s" % [Fittings.LABELS[candidate],"普通木人" if profile == "ordinary" else "进阶高压"]
	elif page == "results": status = "本次会话 / 最近两次同条件实测"
	_text(frame, status, Rect2(456,58,570,26), 16, Folio.SECONDARY_INK, "FittingViewStatus")
	_heading(frame, "南庭试配记" if page == "results" else Fittings.LABELS[candidate], Rect2(456,90,662,60), 42, Folio.INK, "FittingCandidateHeading")
	Folio.rule(frame, Rect2(456,159,662,1), Folio.BRASS)
	if page == "results":
		_text(frame,"本次借用：%s\n%s" % [Fittings.LABELS[candidate],"普通木人" if profile == "ordinary" else "进阶高压"],Rect2(138,234,250,66),18,Folio.BONE,"FittingBorrowedIdentity")
	if page == "results": _build_results(frame)
	elif page == "confirm": _build_confirmation(frame)
	else: _build_preview(frame)
	var warning: String = "当前旅程有未保存的变化；请点击重试保存。\n" if host.save_warning else ""
	_text(frame, warning + SAVE_NOTICE, Rect2(456,510,690,90), 15, Folio.SECONDARY_INK, "FittingSaveNotice")
	var actions: Array = []
	if page == "preview":
		actions = [["equip","装配此项",confirm_selection],["revert","免费恢复原装",revert_original],["trial","借用试招",prepare_trial],["retry_save","重试保存",retry_save] if host.save_warning else ["results","本次会话记录",show_results],["workshop","返回工艺",return_workshop]]
	elif page == "trial":
		actions = [["start","开始借用试招",start_trial],["ordinary","普通木人",choose_profile.bind("ordinary")],["pressure","进阶高压",choose_profile.bind("pressure")],["equip","装配此项",confirm_selection],["back","返回预览",back]]
	elif page == "confirm":
		actions = [["confirm","确认装配" if candidate != "plain" else "确认免费恢复原装",confirm_equip],["cancel","取消，返回预览",back]]
	else:
		actions = [["start","再次借用",start_trial],["trial","更换试配",prepare_trial],["preview","返回预览",_replace.bind("preview")],["workshop","返回工艺",return_workshop],["close","回到南庭",close]]
	for i: int in actions.size():
		var action: Array = actions[i]
		var button = host._button(frame, action[1], _action_rect(action[0]), action[2])
		button.focus_mode = Control.FOCUS_ALL
		button.name = "FittingAction_" + action[0]
		var primary: bool = action[0] == "confirm" or (action[0] == "equip" and page == "preview") or (action[0] == "start" and page in ["trial", "results"])
		var secondary: bool = action[0] == "trial" and page in ["preview", "results"]
		Folio.skin_button(button, "primary" if primary else ("auto" if secondary else "cloth_quiet"))
		button.add_theme_font_size_override("font_size", 24 if primary else (21 if secondary else 16))
		if primary:
			for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
				var style: StyleBox = button.get_theme_stylebox(state).duplicate()
				style.content_margin_top = 5; style.content_margin_bottom = 5
				button.add_theme_stylebox_override(state, style)
		elif page == "trial" and action[0] in ["ordinary", "pressure"]:
			Folio.skin_button(button, "auto"); button.add_theme_font_size_override("font_size", 16)
		elif page == "confirm" and action[0] == "cancel" or page == "results" and action[0] == "preview":
			Folio.skin_button(button, "paper_quiet")
			button.add_theme_font_size_override("font_size", 16)
			button.add_theme_stylebox_override("normal", Folio.style(Color.TRANSPARENT, Folio.BRASS, 1))
			button.add_theme_stylebox_override("disabled", Folio.style(Color(.24,.20,.15,.09), Folio.SECONDARY_INK, 1))
		action_buttons[action[0]] = button
		if action[0] == "equip": button.disabled = candidate == source_state.weapon_fitting or not source_state.preview_weapon_fitting(candidate).get("ok",false)
		if action[0] == "revert": button.disabled = source_state.weapon_fitting == "plain"
		if action[0] == "start": button.disabled = not trial_entry_ready(candidate,profile)
		if action[0] == "ordinary": button.disabled = profile == "ordinary"
		if action[0] == "pressure": button.disabled = profile == "pressure"
	var help: String = "1–3 仅预览配件  ·  4 装配确认  ·  5 借用试招  ·  Tab/Enter 聚焦操作  ·  Esc 返回"
	if page == "confirm": help = "1 明确确认并保存  ·  2 / Esc 取消  ·  关闭不会装配"
	elif page == "results": help = "1 再次借用  ·  2 更换试配  ·  3 返回预览  ·  Esc 回到南庭"
	var help_backing = Folio.rule(self,Rect2(168,760,1048,32),Color(Folio.INK,.92)); help_backing.name = "FittingHelpBacking"
	_text(self, help, Rect2(178,762,1038,26), 14, Folio.BONE, "FittingHelp")

func _build_preview(frame: Control) -> void:
	for i: int in Fittings.IDS.size():
		var id: String = Fittings.IDS[i]
		var projection: Dictionary = source_state.preview_weapon_fitting(id)
		var selected: bool = candidate == id
		var title: String = "%d  %s" % [i+1,Fittings.LABELS[id]]
		var status: String = " · 预览中" if selected else ""
		var delta: String = ["攻防不变 · 免费恢复","攻击 +3 / 防御 −2","攻击 −3 / 防御 +2"][i]
		var button = host._button(frame,title+status+"\n"+delta,Rect2(138,212+i*94,250,86),choose_candidate.bind(id))
		button.name = "FittingCandidate_"+id
		button.focus_mode = Control.FOCUS_ALL
		button.clip_text = true
		Folio.skin_button(button, "row", selected)
		# Keep the semantic caption on the real Button; only native child labels draw it.
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color", "font_shadow_color"]:
			button.add_theme_color_override(key, Color.TRANSPARENT)
		candidate_buttons[id] = button
		if selected:
			var ribbon = Folio.Ribbon.new(); ribbon.name = "FittingPreviewRibbon"
			ribbon.show_behind_parent = true
			ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE; ribbon.focus_mode = Control.FOCUS_NONE
			button.add_child(ribbon)
		var glyph_width: int = 44 if id != "plain" else 0
		if id != "plain":
			var glyph = Paper.ItemGlyph.new(); glyph.kind = "sword" if id == "edge" else "armor"; glyph.position = Vector2(10,8); glyph.size = Vector2(48,55); glyph.scale = Vector2(.75,.75); button.add_child(glyph)
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE; glyph.focus_mode = Control.FOCUS_NONE
		var heading = _text(button, title, Rect2(16+glyph_width,5,216-glyph_width,33),22,Folio.BONE,"FittingCandidateTitle")
		heading.add_theme_font_override("font", Folio.heading_font())
		_text(button, delta, Rect2(16,39,214,24),15,Folio.BONE if selected else Folio.BRASS,"FittingCandidateDelta")
		if selected: _text(button, status, Rect2(16,63,214,22),15,Folio.BONE,"FittingCandidatePreview")
		else: Folio.rule(button, Rect2(16,81,214,1), Folio.BRASS.darkened(.3))
		button.tooltip_text = projection.get("reason", "") if not projection.get("ok",false) else "仅切换预览，不会装配或保存"
	var projection: Dictionary = source_state.preview_weapon_fitting(candidate)
	var caption: String = "预览与当前已装配相同" if candidate == source_state.weapon_fitting else "仅预览 · 尚未装配"
	var text: String = "[b]%s：%s[/b]\n" % [caption,Fittings.LABELS[candidate]]
	if projection.get("ok",false):
		text += "基础攻击 %d / 防御 %d → 预览攻击 %d / 防御 %d\n" % [projection.base_attack,projection.base_defense,projection.attack,projection.defense]
		if page == "preview": text += "只影响主角，不替换佩剑衣甲，不改变气血、真气、同伴或行囊。\n"
	else: text += String(projection.reason)+"\n"
	if page == "preview":
		text += "\n选择配件只作预览；明确确认后才装配。可免费恢复原装。\n"
		text += "借用试招须亲自走到青苇渡练武堂南庭木人旁；不会传送。\n"
		text += "胜负受队伍、招式与操作影响，配件不会保证每一击或每一场更优。"
	else:
		text += "[b]本次借用：%s · %s[/b]\n" % [Fittings.LABELS[candidate],"普通木人" if profile == "ordinary" else "进阶高压"]
		var prepared: Dictionary = Trials.build(source_state,candidate,profile)
		if prepared.ok:
			text += _profile_text(prepared.metadata)+"\n"
			text += "借用满气血、满真气与3份40点药；真实伤势、药品、熟练与进度不变，无奖励。\n"
		else: text += String(prepared.reason)+"\n"
		if not courtyard_ready(host): text += "[b]请先走到青苇渡练武堂南庭木人旁，此处无法开始。[/b]\n"
		if profile == "pressure":
			_text(frame,"高压可能使初入门派者落败；高等级可能触及伤害下限，三种结果也可能相同。",Rect2(456,481,690,24),15,Folio.SECONDARY_INK,"FittingPressureWarning")
	overview_blocks.append(_comparison(frame, projection))
	if page == "preview":
		var scope: String = "选择配件只作预览；明确确认后才装配。可免费恢复原装。\n只影响主角，不替换佩剑衣甲，不改变气血、真气、同伴或行囊。" if projection.get("ok",false) else String(projection.reason)
		overview_blocks.append(_text(frame,scope,Rect2(456,330,662,52),17,Folio.INK,"FittingPreviewScope"))
		overview_blocks.append(_text(frame,"借用试招须亲自走到青苇渡练武堂南庭木人旁；不会传送。",Rect2(456,386,662,48),16,Folio.SECONDARY_INK,"FittingBorrowingLocation"))
	else:
		var prepared: Dictionary = Trials.build(source_state,candidate,profile)
		_text(frame,"借用满气血、满真气与3份40点药；真实伤势、药品、熟练与进度不变，无奖励。" if prepared.ok else String(prepared.reason),Rect2(456,330,690,48),16,Folio.INK,"FittingBorrowedResources")
		_text(frame,"借用试招须亲自走到青苇渡练武堂南庭木人旁；不会传送。" if courtyard_ready(host) else "请先走到青苇渡练武堂南庭木人旁，此处无法开始。",Rect2(456,382,690,34),16,Folio.SECONDARY_INK,"FittingBorrowingLocation")
	details_button = host._button(frame,"配件与试招说明 ▸",Rect2(456,437,310,36),_toggle_details)
	details_button.name = "FittingDetailsToggle"; details_button.focus_mode = Control.FOCUS_ALL
	Folio.skin_button(details_button,"paper_quiet"); details_button.add_theme_font_size_override("font_size",16)
	details_button.add_theme_stylebox_override("normal",Folio.style(Color.TRANSPARENT,Folio.BRASS,1))
	body = _rich(frame,text,Rect2(456,178,662,144) if page == "trial" else Rect2(456,178,662,244),18,"FittingBody")
	body.visible = false
	frame.get_node("FittingBodyScrollEdges").visible = false

func _build_confirmation(frame: Control) -> void:
	var projected: Dictionary = source_state.preview_weapon_fitting(candidate)
	var text: String = "[b]待确认：%s → %s[/b]\n\n" % [Fittings.LABELS[source_state.weapon_fitting],Fittings.LABELS[candidate]]
	if projected.get("ok",false): text += "主角攻击 %d → %d\n主角防御 %d → %d\n\n" % [source_state.effective_attack(),projected.attack,source_state.effective_defense(),projected.defense]
	else: text += String(projected.reason)+"\n\n"
	text += "本次免费，只更换配件。真实资源、成长、同伴、佩剑衣甲均不改变。\n\n"
	text += "点击确认后装配，并按现有规则保存当前真实旅程与位置。\n保存失败时所选配件仍在内存，旧存档保留，可明确重试。\n\n取消、Esc或关闭均不会装配，也不会保存。"
	_comparison(frame, projected)
	body = _rich(frame,text,Rect2(456,326,662,168),21,"FittingBody")

func _build_results(frame: Control) -> void:
	var snapshot: Dictionary = source_state.fitting_comparison_snapshot()
	var prepared: Dictionary = Trials.build(source_state,candidate,profile)
	var current_key: String = String(prepared.metadata.comparison_key) if prepared.ok else ""
	if current_key.is_empty() or current_key != snapshot.comparison_key or snapshot.results.is_empty():
		body = _rich(frame,"当前队伍与档位尚无可并列的试招记录。\n\n更换队伍、阵型、招式、基础能力或档位后，须按新条件重新试招。\n仅保留本次会话最近两次同条件结果；读档或新旅程会清空。\n\n当前已装配仍为%s；本次借用候选为%s。" % [Fittings.LABELS[source_state.weapon_fitting],Fittings.LABELS[candidate]],Rect2(456,176,662,276),20,"FittingResultsEmpty")
		return
	result_rows = snapshot.results.duplicate(true)
	if result_rows.size() == 2: Folio.rule(frame, Rect2(787,176,1,276), Folio.BRASS)
	for i: int in result_rows.size():
		var row: Dictionary = result_rows[i]
		var facts: Dictionary = row.metadata
		var metrics: Dictionary = row.metrics
		var text: String = "[b]%s · 本次借用：%s[/b]\n" % ["最近一次" if i == result_rows.size()-1 else "上一次",Fittings.LABELS[facts.borrowed_fitting]]
		text += "当时已装配：%s\n" % Fittings.LABELS[facts.installed_fitting]
		text += "结果：%s\n" % {"win":"胜出","defeat":"落败","flee":"主动退开（未打完）"}.get(metrics.outcome, "未完成")
		text += "借用气血累计损失 %d  ·  借药用去 %d / 3\n" % [metrics.total_actual_hp_lost,metrics.medicine_used]
		text += "敌方实际攻击 %d 次（不含护势）\n" % metrics.enemy_attacks_executed
		text += "完整经过 %d 轮  ·  结束于第 %d 轮\n" % [metrics.completed_rounds,metrics.terminal_round]
		for actor: Dictionary in facts.original_baseline.team.actors:
			var remaining: Dictionary = metrics.remaining_resources.actors[actor.id]
			text += "%s：借用余血%d / 余气%d，累计失血%d\n" % [String(actor.name).replace("[","[lb]"),remaining.hp,remaining.qi,metrics.actual_hp_lost_by_actor[actor.id]]
		text += "余借药 %d 份\n\n" % metrics.remaining_resources.medicine
		text += _profile_text(facts)
		_rich(frame,text,Rect2(456+i*343,176,319,276),16,"FittingResult"+str(i+1))
	_text(frame,"同条件实测只反映这两次操作；不会保证普遍优势。真实资源与已装配均未因借用改变。",Rect2(456,466,662,34),15,Folio.SECONDARY_INK,"FittingComparisonCaveat")

func _action_rect(action: String) -> Rect2:
	if page == "preview":
		return {"equip":Rect2(456,610,250,52),"revert":Rect2(138,512,250,42),"trial":Rect2(726,610,250,52),"results":Rect2(138,560,250,42),"retry_save":Rect2(138,560,250,42),"workshop":Rect2(138,608,250,42)}[action]
	if page == "trial":
		return {"start":Rect2(456,610,250,52),"ordinary":Rect2(726,610,176,52),"pressure":Rect2(918,610,176,52),"equip":Rect2(138,560,250,42),"back":Rect2(138,608,250,42)}[action]
	if page == "confirm":
		return {"confirm":Rect2(456,610,330,52),"cancel":Rect2(806,610,312,52)}[action]
	return {"start":Rect2(456,610,220,52),"trial":Rect2(692,610,204,52),"preview":Rect2(912,610,206,52),"workshop":Rect2(138,560,250,42),"close":Rect2(138,608,250,42)}[action]

func _comparison(frame: Control, projected: Dictionary) -> Control:
	var group = Control.new(); group.name = "FittingComparisonNumbers"; group.size = frame.size
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE; group.focus_mode = Control.FOCUS_NONE; frame.add_child(group)
	for i: int in 2:
		var x: float = 456 + i*346
		var current: int = source_state.effective_attack() if i == 0 else source_state.effective_defense()
		var after: int = int(projected.get("attack" if i == 0 else "defense", current))
		var stem: String = "FittingAttack" if i == 0 else "FittingDefense"
		_text(group,"攻击" if i == 0 else "防御",Rect2(x,177,296,28),18,Folio.SECONDARY_INK,stem+"Label")
		Folio.rule(group,Rect2(x,209,296,1),Folio.BRASS)
		_text(group,"当前实际",Rect2(x,216,116,23),15,Folio.SECONDARY_INK,stem+"BeforeCaption")
		_text(group,"装配预览",Rect2(x+160,216,136,23),15,Folio.SECONDARY_INK,stem+"AfterCaption")
		_heading(group,str(current),Rect2(x,240,116,53),36,Folio.INK,stem+"Before")
		_text(group,"→",Rect2(x+119,249,36,32),20,Folio.SECONDARY_INK,stem+"Arrow")
		_heading(group,str(after) if projected.get("ok",false) else "—",Rect2(x+160,240,136,53),36,Folio.INK,stem+"After")
		var change: int = after-current
		_text(group,("与已装配相同" if change == 0 else "较已装配 "+("+" if change > 0 else "")+str(change)) if projected.get("ok",false) else "尚不可装配",Rect2(x+160,295,136,23),15,Folio.SECONDARY_INK,stem+"Delta")
	return group

func _toggle_details() -> void:
	if not valid() or not is_instance_valid(details_button) or not is_instance_valid(body) or page not in ["preview","trial"]: return
	var return_focus: bool = details_open and body.has_focus()
	details_open = not details_open
	for block: Control in overview_blocks: block.visible = not details_open
	body.visible = details_open
	details_button.text = "收起说明 ▴" if details_open else "配件与试招说明 ▸"
	var edges = body.get_parent().get_node("FittingBodyScrollEdges")
	if details_open: edges._refresh_edges()
	else: edges.visible = false
	if return_focus and valid() and is_instance_valid(details_button): details_button.grab_focus()

func _heading(parent: Node, value: String, rect: Rect2, pixels: int, color: Color, node_name: String) -> Label:
	var label = _text(parent,value,rect,pixels,color,node_name)
	label.add_theme_font_override("font",Folio.heading_font())
	return label

static func _profile_text(metadata: Dictionary) -> String:
	var enemies: Array = metadata.enemy_specs
	return "%s：木人气血%d / %d；执棍轻/重%d / %d，架盾攻击%d。\n未装配队伍攻击基线%d；木人护势、目标与出招规律不变。" % ["普通木人" if metadata.profile_id == "ordinary" else "进阶高压",enemies[0].hp,enemies[1].hp,enemies[0].attack,enemies[0].heavy_attack,enemies[1].attack,metadata.base_attack_budget]

func _text(parent: Node, value: String, rect: Rect2, pixels: int, color: Color, node_name: String = "") -> Label:
	var label = Paper.text(host,parent,value,rect,pixels,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", Folio.BODY_FONT)
	label.focus_mode = Control.FOCUS_NONE
	# Host creates the Label before configuring its font/wrap; discard the
	# temporary unwrapped minimum width after the real presentation is set.
	label.size = rect.size
	if not node_name.is_empty(): label.name = node_name
	return label

func _rich(parent: Node, value: String, rect: Rect2, pixels: int, node_name: String) -> RichTextLabel:
	var text = RichTextLabel.new(); text.name = node_name; text.position = rect.position; text.size = rect.size
	text.bbcode_enabled = true; text.scroll_active = true; text.selection_enabled = true; text.text = value
	text.focus_mode = Control.FOCUS_ALL
	text.gui_input.connect(_scroll_text.bind(text))
	text.tooltip_text = "滚轮翻阅；Tab聚焦正文后，可用方向键、PageUp/PageDown、Home/End翻阅"
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	text.add_theme_font_override("normal_font", Folio.BODY_FONT)
	text.add_theme_color_override("default_color", Folio.INK); text.add_theme_font_size_override("normal_font_size",pixels)
	text.add_theme_color_override("font_selected_color", Folio.BONE)
	text.add_theme_color_override("selection_color", Folio.INK)
	text.add_theme_stylebox_override("normal", Folio.style(Color.TRANSPARENT))
	text.add_theme_stylebox_override("focus", Folio.focus_style(false))
	text.add_theme_constant_override("line_separation",5); parent.add_child(text)
	Folio.scrollbar(text.get_v_scroll_bar())
	if node_name == "FittingBody" and page in ["preview","trial"]:
		var edges = DisclosureEdges.new(); edges.name = node_name+"ScrollEdges"
		edges.scroll_bar = text.get_v_scroll_bar(); edges.visibility_owner = text; edges.ink = Folio.SECONDARY_INK
		edges.position = rect.position-Vector2(0,7); edges.size = rect.size+Vector2(0,14)
		edges.mouse_filter = Control.MOUSE_FILTER_IGNORE; edges.focus_mode = Control.FOCUS_NONE; parent.add_child(edges)
	else: Folio.scroll_edges(parent, text.get_v_scroll_bar(), rect)
	return text

func _scroll_text(event: InputEvent, region: RichTextLabel) -> void:
	if not valid() or not is_instance_valid(region) or not region.has_focus() or not event is InputEventKey or not event.pressed:return
	var scroll: VScrollBar = region.get_v_scroll_bar()
	match event.physical_keycode:
		KEY_PAGEDOWN:scroll.value += region.size.y * .85
		KEY_PAGEUP:scroll.value -= region.size.y * .85
		KEY_DOWN:scroll.value += 32
		KEY_UP:scroll.value -= 32
		KEY_END:scroll.value = scroll.max_value
		KEY_HOME:scroll.value = scroll.min_value
		_:return
	region.accept_event()
