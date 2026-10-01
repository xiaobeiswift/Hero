extends Control
## The original playable opening chapter of Hero: 渡灯录.
const ViewPreferences=preload("res://scripts/view_preferences.gd")
const PauseMenu=preload("res://scripts/pause_menu.gd")
const InventoryPanel=preload("res://scripts/inventory_panel.gd")
const GameHUD=preload("res://scripts/game_hud.gd")
const StateModel = preload("res://scripts/game_state.gd")
const WorldScene = preload("res://scripts/world.gd")
const BattleArt = preload("res://scripts/battle_art.gd")
const Portraits=preload("res://scripts/character_portraits.gd")
const SaveSlotsUI=preload("res://scripts/save_slots_ui.gd")
const MistwoodStory=preload("res://scripts/mistwood_story.gd")
const AdvancedMartialUI=preload("res://scripts/advanced_martial_ui.gd")
const LightnessStory=preload("res://scripts/lightness_story.gd")
const ShenCareStory=preload("res://scripts/shen_care_story.gd")
const CompanionStory=preload("res://scripts/companion_story.gd")
const SectProgress = preload("res://scripts/sect_progress_ui.gd")
const ChapterStory = preload("res://scripts/frostbridge_story.gd")
const Workshop = preload("res://scripts/workshop_ui.gd")
const Chart = preload("res://scripts/map_chart.gd")
const INK = Color("102e32")
const DEEP = Color("0b2026")
const PAPER = Color("e8dec4")
const GOLD = Color("d3b276")
const MUTED = Color("8caaa6")
const JADE = Color("69b6a3")
var state = StateModel.new()
var view_preferences=ViewPreferences.new()
var view_zoom:float=1.0
var workshop
var chapter_story
var sect_progress
var lightness_story
var shen_story
var companion_story
var advanced_martial
var mist_story
var save_slots
var hud
var _hud_navigation_flags:int=-1
var world
var world_view: SubViewport
var font: Font
var ui: Theme
var hp_caption: Label
var qi_caption: Label
var location_label: Label
var weather_label: Label
var region_header: Label
var chapter_header: Label
var hp_bar: ProgressBar
var qi_bar: ProgressBar
var stat_label: Label
var name_label: Label
var sect_label: Label
var quest_label: Label
var hint_label: Label
var status_label: Label
var near_label: Label
var exp_label: Label
var portrait: Label
var overlay: Control
var battle_layer: Control
var battle_art
var battle_presentation_generation:=0
var battle_busy:=false
var battle_presentation_enabled:=DisplayServer.get_name()!="headless"
var _battle_health_generation: int = -1
var _battle_health_values: Dictionary = {}
var _battle_health_tweens: Dictionary = {}
var battle_hp: ProgressBar
var battle_player_hp: ProgressBar
var battle_status:Label
var battle_info: Label
var battle_log: RichTextLabel
var battle_buttons: Array[Button] = []
var modal_generation:int=0
var active_modal = false
var modal_actions: Array[Callable] = []
var current_screen = "explore"
var toast_time = 0.0
var elapsed = 0.0
var story_battle = false
var encounter_kind = "story"
var enemy_title: Label
var battle_title: Label
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var audio_on = true
var last_near = ""
var save_warning = false
var quit_pending = false
var screenshot_pending := false
var screenshot_sequence := 0
var last_screenshot_path := ""

func _ready() -> void:
	get_tree().auto_accept_quit = false
	view_preferences.load_settings()
	font = load("res://assets/fonts/NotoSansSC.otf")
	_setup_inputs()
	_build_theme()
	_build_interface()
	_apply_view_zoom()
	workshop=Workshop.new(self)
	chapter_story=ChapterStory.new(self)
	sect_progress=SectProgress.new(self)
	companion_story=CompanionStory.new(self)
	shen_story=ShenCareStory.new(self)
	lightness_story=LightnessStory.new(self)
	advanced_martial=AdvancedMartialUI.new(self)
	mist_story=MistwoodStory.new(self)
	save_slots=SaveSlotsUI.new(self)
	_setup_audio()
	_refresh()
	_show_title()

func _setup_inputs() -> void:
	var actions = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "interact": [KEY_E, KEY_ENTER]}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _build_theme() -> void:
	ui = Theme.new()
	ui.default_font = font
	ui.default_font_size = 16
	ui.set_color("font_color", "Label", PAPER)
	ui.set_color("default_color", "RichTextLabel", PAPER)
	ui.set_color("font_color", "Button", PAPER)
	ui.set_color("font_hover_color", "Button", Color.WHITE)
	ui.set_color("font_disabled_color", "Button", Color("61716f"))
	ui.set_stylebox("normal", "Button", _style(Color("20494a"), Color("51736b"), 6))
	ui.set_stylebox("hover", "Button", _style(Color("2c6360"), GOLD, 6))
	ui.set_stylebox("pressed", "Button", _style(Color("397568"), GOLD, 6))
	ui.set_stylebox("focus", "Button", _style(Color(0,0,0,0), GOLD, 6, 2))
	ui.set_stylebox("disabled", "Button", _style(Color("203435"), Color("334648"), 6))
	ui.set_stylebox("background", "ProgressBar", _style(Color("183638"), Color("294d4e"), 3))
	ui.set_stylebox("fill", "ProgressBar", _style(JADE, JADE, 3))
	theme = ui

func _style(bg: Color, border: Color, radius: int = 8, width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _panel(parent: Node, rect: Rect2, color: Color = INK, border: Color = Color("41605b")) -> Panel:
	var panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(color, border))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, rect: Rect2, size_px: int = 16, color: Color = PAPER) -> Label:
	var label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.position = rect.position
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size",1)
	var fill = _style(color,color,3)
	var background = _style(Color("183638"),Color("294d4e"),3)
	for style in [fill,background]:
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	parent.add_child(bar)
	bar.size = rect.size
	bar.set_deferred("size",rect.size)
	return bar

func _build_interface() -> void:
	hud=GameHUD.new()
	hud.build(self)
	_build_battle_ui()
	hud.reflow_battle()

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	if DisplayServer.get_name()!="headless" and ResourceLoader.exists("res://assets/river_theme.wav"):
		music.stream = load("res://assets/river_theme.wav")
		music.volume_db = -14
		music.finished.connect(func(): music.play())
		music.play()
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	if DisplayServer.get_name()!="headless" and ResourceLoader.exists("res://assets/chime.wav"): sfx.stream = load("res://assets/chime.wav")
	sfx.volume_db = -14

func _toggle_audio() -> void:
	audio_on = not audio_on
	music.stream_paused = not audio_on
	for child in get_children():
		if child is Button and child.text.begins_with("♫"):
			child.text = "♫  开" if audio_on else "♫  关"

func _process(delta: float) -> void:
	elapsed += delta
	# Opaque title/combat layers must not redraw an invisible village underneath.
	world.visible=current_screen=="explore"
	world.active = not quit_pending and not active_modal and current_screen == "explore"
	_sync_world_state()
	state.position = world.player_pos
	if world.nearby_id+"|"+world.nearby_name != last_near:
		last_near = world.nearby_id+"|"+world.nearby_name
		near_label.text = "[ E ]  " + world.nearby_name if not world.nearby_id.is_empty() else "WASD / 方向键行走，靠近人物或物品按 E 交互"
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0: status_label.text = "⚠ 自动存档失败，请按 F5 重试。" if save_warning else "青苇晚照，灯火将明。循着线索，走一段自己的江湖。"

	if hud!=null:
		hud.tick(delta)
		_sync_hud_navigation()

func _unhandled_key_input(event: InputEvent) -> void:
	if quit_pending: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_F12:
		_capture_screenshot()
		return
	if event.physical_keycode == KEY_ESCAPE and not active_modal and current_screen=="explore":
		_show_pause();get_viewport().set_input_as_handled();return
	if event.physical_keycode == KEY_ESCAPE and active_modal and current_screen != "title":
		_close_modal()
		return
	if active_modal:
		if overlay.get_meta("inventory",false):
			if event.physical_keycode==KEY_K:_show_martials();get_viewport().set_input_as_handled();return
			if event.physical_keycode==KEY_B:workshop.show();get_viewport().set_input_as_handled();return
		var choice = -1
		if event.physical_keycode in [KEY_ENTER,KEY_SPACE]: choice = 0
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5: choice = event.physical_keycode-KEY_1
		if choice>=0 and choice<modal_actions.size():
			var selected = modal_actions[choice]
			selected.call()
			get_viewport().set_input_as_handled()
		return
	if current_screen == "battle":
		var combat_actions = ["attack","skill","guard","item","flee"]
		if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_5:
			_battle_action(combat_actions[event.physical_keycode-KEY_1])
		return
	if current_screen != "explore": return
	match event.physical_keycode:
		KEY_E, KEY_ENTER:
			if not world.nearby_id.is_empty():
				_interact(world.nearby_id)
				get_viewport().set_input_as_handled()
		KEY_B: _show_workshop()
		KEY_M: _show_map()
		KEY_K: _show_martials()
		KEY_I: _show_inventory()
		KEY_J: _show_journal()
		KEY_F6: _show_save_slots()
		KEY_F10: _show_load_slots()
		KEY_F5: _save()
		KEY_F9: _load()
		KEY_EQUAL,KEY_PLUS,KEY_KP_ADD: _change_view_zoom(1)
		KEY_MINUS,KEY_KP_SUBTRACT: _change_view_zoom(-1)

func _refresh() -> void:
	world.visible=current_screen=="explore"
	region_header.text = state.current_region_name()
	weather_label.text="暮春  /  山风  /  薄霜" if state.map_id=="frostbridge" else "暮春  /  酉时  /  微风"
	chapter_header.text = "第二章  ·  印下有声" if state.map_id=="frostbridge" else ("江湖行纪  ·  废闸疑云" if state.map_id=="sluice" else "第一章  ·  灯火不问归人")
	if state.map_id=="mistwood":
		weather_label.text="暮春  /  竹风  /  细雨"
		chapter_header.text="第三章  ·  听雨辨令"
	name_label.text = state.player_name + "  " + str(state.level) + "级"
	sect_label.text = ("初入江湖" if state.sect=="未入门" else state.sect_rank_name())+" · "+state.sect
	hp_bar.max_value = state.max_hp
	hp_bar.value = state.hp
	qi_bar.max_value = state.max_qi
	qi_bar.value = state.qi
	hp_caption.text = "气血  %d / %d" % [state.hp,state.max_hp]
	qi_caption.text = "真气  %d / %d" % [state.qi,state.max_qi]
	stat_label.text = "攻击 %d    防御 %d    铜钱 %d" % [state.attack,state.defense,state.coins]
	exp_label.text = "修为  %d / %d      回春散 ×%d" % [state.xp,state.xp_to_next(),state.medicine]
	quest_label.text = state.quest_title()
	hint_label.text = state.quest_hint()
	if state.quest_stage >= 6:
		quest_label.text = "废闸疑云" if state.side_stage<3 else "水令留痕"
		var side_hints = ["沿村东古道前往废闸，追查账册上的水纹印记。", "救下船工，并夺回传令人的账页。行动先后将改变收获。", "证言与账页已齐，去旧闸东南找闸首对质。", "旧闸的水令已寻回。回村休整，继续切磋与修行。"]
		hint_label.text = side_hints[state.side_stage]
		if state.map_id=="sluice" and state.side_stage==0: hint_label.text = "南岸有人呼救，东北有人携卷而去。先救人，还是先追线索？"
	if state.chapter_two_stage>0 or (state.quest_stage>=6 and state.side_stage>=3):
		quest_label.text=chapter_story.quest_title()
		hint_label.text=chapter_story.quest_hint()
	if companion_story.pending():
		quest_label.text="尺上旧痕"
		hint_label.text=companion_story.hint()
	if state.mist_stage>0 and (state.map_id=="mistwood" or (state.mist_stage<4 and not companion_story.pending())):
		quest_label.text=mist_story.title();hint_label.text=mist_story.hint()
	if _track_shen():
		quest_label.text="药箱之外";hint_label.text=shen_story.hint()
	if state.sect_trial_won and state.sect_rank==1 and state.map_id=="qingwei":
		quest_label.text="待领门中荐记"
		hint_label.text="岑远已验明考绩。到练武堂南庭领取内门荐记。"

	if hud!=null:
		hud.refresh()
		_sync_hud_navigation(true)

func _sync_hud_navigation(force:bool=false)->void:
	var flags=int(hud.toast_wash.visible)+2*int(hud.quest_notice.visible)
	if not force and flags==_hud_navigation_flags:return
	_hud_navigation_flags=flags
	var reserved:Array[Rect2]=[hud.identity_wash.get_rect(),hud.place_wash.get_rect(),hud.quest_wash.get_rect().merge(weather_label.get_rect()),Rect2(0,660,1280,140)]
	if hud.toast_wash.visible:reserved.append(hud.toast_wash.get_rect())
	if hud.quest_notice.visible:reserved.append(hud.quest_notice.get_rect())
	var projected:Array[Rect2]=[]
	for area in reserved:projected.append(Rect2(area.position/view_zoom,area.size/view_zoom))
	world.hud_exclusion_rects=projected
	world.queue_redraw()

func _toast(text: String) -> void:
	status_label.text = text + ("  ⚠ 自动存档失败，请按 F5 重试。" if save_warning else "")
	toast_time = 7.0

func _clear_overlay() -> void:
	if overlay.has_meta("inventory"):overlay.remove_meta("inventory")
	if overlay.has_meta("pause_menu"):overlay.remove_meta("pause_menu")
	modal_actions.clear()
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()

func _close_modal() -> void:
	if current_screen=="title":
		_show_title();return
	modal_generation+=1
	_clear_overlay()
	active_modal = false
	if current_screen == "title": current_screen = "explore"
	_refresh()
	if current_screen == "explore": _autosave()

func _modal(title: String, subtitle: String, body: String, options: Array = [], wide: bool = false) -> void:
	modal_generation+=1
	_clear_overlay()
	active_modal = true
	var veil = ColorRect.new()
	veil.color = Color(0.01,0.06,0.08,0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	if current_screen == "title" and ResourceLoader.exists("res://assets/generated/qingwei_ferry_title.png"):
		var art = TextureRect.new()
		art.texture = load("res://assets/generated/qingwei_ferry_title.png")
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(art)
	var width = 840 if wide else 710
	var x = (1280-width)/2.0
	var panel = _panel(overlay,Rect2(x,140 if wide else 185,width,520 if wide else 430),Color("112f33"),GOLD)
	var portrait_id=Portraits.id_for_title(title)
	if not portrait_id.is_empty():Portraits.attach(panel,portrait_id,Rect2(width-156,-6,142,122))
	_label(panel,subtitle,Rect2(30,22,width-60,24),12,GOLD)
	_label(panel,title,Rect2(30,55,width-60,45),28,PAPER)
	var text = RichTextLabel.new()
	text.position = Vector2(30,120)
	text.size = Vector2(width-60,297 if wide else 207)
	text.bbcode_enabled = true
	text.text = body
	text.add_theme_font_size_override("normal_font_size",17)
	panel.add_child(text)
	if options.is_empty(): options = [["继续行走",_close_modal]]
	var gap = 12.0
	var button_width = (width-60-gap*(options.size()-1))/options.size()
	for i in range(options.size()):
		modal_actions.append(options[i][1])
		_button(panel,options[i][0],Rect2(30+i*(button_width+gap),443 if wide else 353,button_width,48),options[i][1])

func _apply_view_zoom()->void:
	view_zoom=view_preferences.zoom()
	var dimensions:Vector2i=view_preferences.canvas_size()
	world_view.size=dimensions
	var container:SubViewportContainer=world_view.get_parent()
	container.size=Vector2(dimensions);container.scale=Vector2.ONE*view_zoom
	world.viewport_rect=Rect2(Vector2.ZERO,Vector2(dimensions));world.ui_scale=view_zoom
	world.camera_pos=world._camera_target();world.queue_redraw()
	if hud!=null:
		hud.tick(0);_sync_hud_navigation(true)

func _change_view_zoom(step:int,cycle:bool=false)->void:
	if current_screen!="explore" or quit_pending:return
	if active_modal and not overlay.get_meta("pause_menu",false):return
	var next=(view_preferences.zoom_index+1)%3 if cycle else clampi(view_preferences.zoom_index+step,0,2)
	if next==view_preferences.zoom_index:return
	view_preferences.zoom_index=next;_apply_view_zoom()
	var error=view_preferences.save_settings()
	_toast("视野 · "+view_preferences.caption() if error==OK else "视野已调整，本次设置未能保存。")
	if active_modal:PauseMenu.show(self)

func _show_pause()->void:
	PauseMenu.show(self)

func _show_title() -> void:
	current_screen = "title"
	var choices: Array = [["踏入江湖",_request_new_game]]
	if state.has_save(): choices.append(["续写前缘",_load])
	if save_slots.store.has_manual_saves():choices.append(["查阅手记",_show_load_slots])
	_modal("渡灯录", "H E R O  ·  原创武侠角色扮演", "[color=#d3b276]第一章 · 灯火不问归人[/color]\n\n你带着一封没有署名的旧信，来到水路尽头的青苇渡。\n今夜，渡口的引航灯没有亮。\n\n江湖未必始于名山大派，也可能始于一盏被人摘走的灯。", choices)

func _request_new_game() -> void:
	if state.has_save():
		_modal("另启一段江湖", "新旅程 / 将替换当前本地存档", "继续新旅程将替换当前自动存档，三份手动手记不会删除。\n\n若要接着之前的经历，请选择返回，再点‘续写前缘’。",[["确认新旅程",_new_game],["返回",_show_title]])
	else:
		_new_game()

func _new_game() -> void:
	state.reset_game()
	_sync_world_state()
	world.change_map(state.map_id,state.position)
	current_screen = "explore"
	_close_modal()
	_toast("先去前方找守灯人陆伯聊聊。靠近后按 E / Enter。")

func _interact(id: String) -> void:
	if active_modal or current_screen != "explore": return
	if audio_on: sfx.play()
	match id:
		"mentor": sect_progress.show()
		"elder": _elder_dialogue()
		"reed_cross": lightness_story.shore()
		"reed_return": lightness_story.return_bank()
		"reed_relic": lightness_story.relic()
		"healer": _healer_dialogue()
		"herb": _herb_dialogue()
		"bandit": _bandit_dialogue()
		"board": _show_board()
		"shrine": _shrine_dialogue()
		"exit_sluice": _exit_sluice_dialogue()
		"return_village": _travel("qingwei",Vector2(1390,560))
		"stranded_boatman": _boatman_dialogue()
		"ledger_runner": _runner_dialogue()
		"sluice_boss": _sluice_boss_dialogue()
		"sluice_cache": _sluice_cache_dialogue()
		_:
			if not mist_story.handle(id):chapter_story.handle(id)

func _elder_dialogue() -> void:
	if state.quest_stage == 5 and state.sect == "未入门":
		_choose_sect()
		return
	match state.quest_stage:
		0:
			_modal("陆伯 · 守灯人","机缘 / 渡口失灯","灯绳是被利刃割断的。灯不亮，运粮的船便不敢进港，偏偏有人要收一笔‘借火钱’。\n\n药师沈青认得绳上留下的药味，可她还在照看受伤的船工。劳烦你去东北苇岸，采一株青穗草。",[["这盏灯，我来找",func(): state.quest_stage=1; _close_modal(); _autosave(); _toast("新机缘：沿北侧土路向东，寻找发光的青穗草。")]])
		1:
			_modal("陆伯","渡口失灯","青穗草长在东北苇岸。沿村中土路向东，再往北，便能看到那丛淡青色的草。\n\n别急着与人动刀，先问清这条河上的事。")
		2,3:
			_modal("陆伯","渡口失灯","沈青的药铺就在村西。查明缘由后，再去东南旧渡口。\n\n老夫守了三十年的灯，只盼它照见归人，不替任何人照见银子。")
		4:
			_modal("陆伯","抉择 / 灯火归处","你带回了灯芯和私收渡税的账页。账页上的印章，竟与旧信上的水纹一致。\n\n陆伯沉默良久：‘这账，是交给县衙，还是留给渡口的船家？’\n\n[color=#d3b276]你的选择将留在青苇渡，也会写入往后的江湖。[/color]",[["交给县衙",func(): _finish_quest("秉公")],["交给船家",func(): _finish_quest("守望")]],true)
		_:
			_modal("陆伯","灯已归来","渡口的灯又亮了。"+("县衙已收下账页，往后还须有人盯着。" if state.ending=="秉公" else "船家们把账页抄成了三份，谁也不能轻易夺走。")+"\n\n你的旧信指向上游的霜桥城。等一切准备妥当，就顺流去看看吧。")

func _healer_dialogue() -> void:
	if state.quest_stage >= 3 and not state.companion_unlocked:
		_modal("沈青 · 药师", "同行 / 一程风雨", "蒲横的刀快，我的药箱也不慢。\n\n沈青收好药箱：‘治伤不能只等伤者上门。你若愿意，这一程我们同行。’\n\n并肩时，每两次出招，沈青以银针相助；护后时，为你减轻来袭伤害。", [["邀请同行",func(): state.recruit_companion(); state.heal_rest(); _close_modal(); _autosave(); _toast("沈青加入队伍，可在行囊切换阵型。")],["先疗伤",func(): state.heal_rest(); _close_modal(); _toast("沈青为你疗伤。想好后可再来邀请同行。")]])
		return
	if state.quest_stage == 2 and state.herbs > 0:
		_modal("沈青 · 药师","线索 / 绳上的药味","正是青穗草，多谢。船工醒后说，河帮的人把灯藏在旧渡口。\n\n绳上的不是毒，是常见的止血膏。有人一边替船工包扎，一边收他过河的钱。\n\n带上这两包回春散。刀剑无眼，记得守势。",[["收下药，前往旧渡口",func(): state.herbs-=1; state.medicine+=2; state.quest_stage=3; state.gain_xp(20); _close_modal(); _autosave(); _toast("获得回春散 ×2、修为 +20。前往东南旧渡口。")]])
	else:
		var choices:Array=[["免费调息",func(): state.heal_rest(); _close_modal(); _toast("气血与真气已恢复。")],["买药 · 12 文",_buy_medicine],["告辞",_close_modal]]
		if shen_story.visible():choices.append(["药箱之外",shen_story.pharmacy])
		_modal("药铺伙计" if state.current_companion()=="沈青" else "沈青 · 药师","青苇药铺","行走江湖，先学会照顾自己。\n\n我可以替你调息疗伤，也能卖你一份回春散（12 铜钱）。\n回春散通常恢复45点气血，照野堂弟子为55点；战斗中使用也算一回合。",choices,true)

func _buy_medicine() -> void:
	if state.coins < 12:
		_toast("铜钱不足，还差 %d 文。" % (12-state.coins))
		return
	state.coins -= 12
	state.medicine += 1
	_refresh()
	_toast("购得回春散 ×1，花费 12 铜钱。")

func _herb_dialogue() -> void:
	if state.quest_stage == 1:
		_modal("青穗草","采集 / 东北苇岸","细长的叶子贴着河岸生长，叶尖泛着温润的青光。\n\n你小心采下几片成熟的叶，留下根须，等下一季春水。",[["收入行囊",func(): state.herbs+=1; state.quest_stage=2; state.gain_xp(10); _close_modal(); _autosave(); _toast("获得青穗草 ×1。回村西药铺交给沈青。")]])
	else:
		_modal("一丛青穗草","东北苇岸","河水微凉，草木自有时节。眼下无事，不必多采。")

func _bandit_dialogue() -> void:
	if state.quest_stage < 3:
		_modal("蒲横 · 河帮执事","旧渡口","今晚这条渡口不开。\n\n你看见他腰间挂着半截灯绳，却还没有足够的线索说明来意。先问问村里的人。")
	elif state.quest_stage == 3:
		_modal("蒲横 · 河帮执事","交锋 / 一盏灯的价钱","‘灯是我摘的，过河的价钱却不是我定的。’\n\n蒲横横刀挡住栈桥：‘想拿回灯，就让我看看，你凭什么替这条河讲道理。’\n\n[color=#d3b276]普攻积攒真气，绝招消耗 3 点。敌人蓄力时，用守势化解。[/color]",[["拔剑 · 迎战",func(): _start_battle("story")],["暂且离开",_close_modal]],true)
	else:
		_modal("蒲横","切磋 / 不争渡税，只论武艺","‘那天的事，我欠船家一句交代。’\n\n蒲横已不再拦路，愿与你过招。切磋可以获得修为和少量铜钱；落败后仍可重新挑战。",[["友好切磋",func(): _start_battle("spar")],["下次再来",_close_modal]])

func _finish_quest(choice: String) -> void:
	state.ending = choice
	state.quest_stage = 5
	state.coins += 60
	state.gain_xp(90)
	state.heal_rest()
	_close_modal()
	_choose_sect()
	_autosave()

func _choose_sect() -> void:
	_modal("一封荐帖，三条来路","修行 / 江湖不止一个答案","陆伯取出三封荐帖。你所做的事，已有人听闻。\n\n[color=#d3b276]听潮阁[/color]  借势出剑，攻击提升\n[color=#d3b276]照野堂[/color]  医武相济，气血提升\n[color=#d3b276]问石门[/color]  守拙如山，防御提升\n\n选择此行的修习方向，仍可留在青苇渡继续探索。",[["听潮阁",func(): _join_sect("听潮阁")],["照野堂",func(): _join_sect("照野堂")],["问石门",func(): _join_sect("问石门")]],true)

func _join_sect(id: String) -> void:
	state.choose_sect(id)
	state.quest_stage = 6
	_close_modal()
	_autosave()
	_toast("第一章完成 · 已获 %s 荐帖。可向练武堂南庭的岑远受试，或继续探索。" % id)

func _show_board() -> void:
	if state.shen_care_stage==4:shen_story.board()
	else:_show_board_base()

func _show_board_base() -> void:
	_modal("青苇渡告示","村中见闻","[color=#d3b276]渡口地图[/color]\n西北：沈青药铺  /  中央：陆伯与告示牌\n东北：青穗草苇岸  /  东南：旧渡口与蒲横\n南边：无名碑，可免费调息\n练武堂南庭：岑远，代验门派考法\n\n[color=#d3b276]乡约[/color]\n过河不问来处，点灯不收借火钱。"+shen_story.board_append(),[["查看照护约",shen_story.board],["收起告示",_close_modal]] if state.shen_care_stage==4 else [],true)

func _shrine_dialogue() -> void:
	_modal("无名碑","见闻 / 此心安处","碑上的字早被雨水磨平，只剩一个浅浅的‘归’字。\n\n你坐在碑边，听见远处船橹破水的声音。许多故事没有写在史书里，只留在愿意记得的人心中。",[["静坐调息",func(): state.heal_rest(); _close_modal(); _toast("你在碑前调息，气血与真气已恢复。")],["起身离开",_close_modal]])

func _show_inventory() -> void:
	InventoryPanel.show(self)

func _switch_formation() -> void:
	if state.current_companion().is_empty():
		_toast("尚无同行人。调查药铺后，可再次与沈青交谈。")
		return
	state.set_formation("护后" if state.formation=="并肩" else "并肩")
	_show_inventory()
	_toast("阵型改为"+state.formation+"："+state.companion_description())

func _buy_sword() -> void:
	if state.buy_equipment():
		_show_inventory()
		_toast("获得青钢剑，攻击 +4。已自动装备。")
	else:
		_toast("已拥有青钢剑，或铜钱不足45文。")

func _use_medicine() -> void:
	if state.use_medicine():
		_close_modal()
		_toast("服用回春散，恢复气血。")
	else:
		_toast("气血已满，或行囊中没有回春散。")

func _show_journal() -> void:
	if current_screen == "battle": return
	var lines = ["与村中央的陆伯交谈", "到东北苇岸采集青穗草", "回村西药铺，将草药交给沈青", "前往东南旧渡口，夺回引航灯", "向陆伯交还灯芯与账页", "决定证据归处，选择修行方向"]
	var body = "[color=#d3b276]主线 · 渡口失灯[/color]\n"
	for i in range(lines.size()):
		var mark = "✓" if state.quest_stage > i or (state.quest_stage>=5 and state.sect!="未入门") else ("◇" if state.quest_stage==i else "·")
		body += "%s  %s\n" % [mark, lines[i]]
	if not state.ending.is_empty(): body += "\n你的抉择：[color=#d3b276]"+state.ending+"[/color]。这条河会记得。"
	if state.quest_stage>=6:
		body = "[color=#d3b276]主线 · 渡口失灯：已完成[/color]\n证据归处：%s  /  修行方向：%s\n\n[color=#d3b276]江湖行纪 · 废闸疑云[/color]\n%s 船工的证言（南岸）\n%s 传令人的账页（东北）\n%s 闸首罗沉与伪造水令（东南）\n\n先行之路：%s" % [state.ending,state.sect,"✓" if state.side_found.has("boatman") else "◇","✓" if state.side_found.has("ledger") else "◇","✓" if state.side_stage>=3 else "◇","先救船工" if state.side_choice=="rescue" else ("先追账页" if state.side_choice=="pursuit" else "尚未决定")]
	if state.chapter_two_stage>0:body=chapter_story.journal()
	if state.chapter_two_stage>=4:body+=companion_story.journal()
	if state.mist_stage>0:body+=mist_story.journal()
	body+=shen_story.journal()
	body+=lightness_story.journal()
	_modal("江湖志","机缘 / 因果与见闻",body,[],true)

func _save() -> void:
	if current_screen == "battle" or current_screen == "title":
		_toast("请在探索时存档。")
		return
	state.position = world.player_pos
	var error = state.save_game()
	save_warning = error != OK
	_toast("已存档 · 下次可从这里继续江湖。" if error==OK else "存档失败，请检查存储空间。错误："+str(error))

func _autosave() -> void:
	state.position = world.player_pos
	var error = state.save_game()
	save_warning = error != OK
	if save_warning: _toast("自动存档未成功，可按 F5 重试。")

func _load() -> void:
	if current_screen == "battle":
		_toast("请结束战斗后读档。")
		return
	var error = state.load_game()
	if error != OK:
		_toast("存档版本不受支持，请使用兼容的新版本。" if error==ERR_FILE_UNRECOGNIZED else "未能读取存档：文件不存在或格式损坏。")
		return
	_apply_loaded_state()

func _apply_loaded_state(message:String="前缘已续 · 读档成功。")->void:
	current_screen = "explore"
	_sync_world_state()
	world.change_map(state.map_id,state.position)
	_close_modal()
	_toast(message)
	if state.quest_stage==5 and state.sect=="未入门": _choose_sect()

func _build_battle_ui() -> void:
	battle_art = BattleArt.new()
	battle_art.size = Vector2(938,568)
	battle_layer.add_child(battle_art)
	battle_art.impact_presented.connect(_present_battle_health_impact)
	battle_title = _label(battle_layer,"旧 渡 口  ·  问 剑",Rect2(24,14,600,32),22,GOLD)
	_label(battle_layer,"回合制交锋   /   观势、蓄气、出剑",Rect2(26,50,700,25),13,MUTED)
	battle_player_hp = _bar(battle_layer,Rect2(75,116,245,10),JADE)
	battle_hp = _bar(battle_layer,Rect2(609,116,245,10),Color("c68a76"))
	battle_player_hp.step = 0.01
	hp_bar.step = 0.01
	battle_hp.step = 0.01
	_label(battle_layer,"无名客",Rect2(76,83,245,24),18,PAPER)
	enemy_title = _label(battle_layer,"蒲横 · 河帮执事",Rect2(609,83,245,24),18,PAPER)
	_panel(battle_layer,Rect2(25,309,888,47),Color(0.025,0.09,0.11,0.94),Color("3f6260"))
	battle_info = _label(battle_layer,"",Rect2(43,313,855,23),15,GOLD)
	battle_status=_label(battle_layer,"",Rect2(43,335,855,18),13,JADE)
	var log_panel = _panel(battle_layer,Rect2(25,357,888,100),Color(0.025,0.09,0.11,0.94),Color("3f6260"))
	battle_log = RichTextLabel.new()
	battle_log.position = Vector2(15,9)
	battle_log.size = Vector2(855,83)
	battle_log.bbcode_enabled = true
	battle_log.scroll_following = true
	battle_log.add_theme_font_size_override("normal_font_size",14)
	log_panel.add_child(battle_log)
	var names = ["1 出剑  +2气", "2 照夜一线  -3气", "3 守势  +1气", "4 回春散", "5 撤离"]
	var actions = ["attack","skill","guard","item","flee"]
	for i in range(names.size()):
		battle_buttons.append(_button(battle_layer,names[i],Rect2(25+i*180,476,167,56),_battle_action.bind(actions[i])))

func _start_battle(kind: String) -> void:
	battle_presentation_generation+=1
	_stop_battle_health_tweens()
	battle_busy=false
	battle_art.reset_presentation()
	_close_modal()
	current_screen = "battle"
	# Exploration tips must not cover a new duel; persistent save failures survive.
	toast_time=0
	if not save_warning:status_label.text=""
	story_battle = kind=="story"
	encounter_kind = kind
	state.start_battle(kind)
	if not state.battle_active:
		current_screen="explore"
		battle_layer.visible=false
		_toast("此刻尚不满足交锋条件。")
		return
	enemy_title.text = state.enemy_name
	battle_art.enemy_identity=state.enemy_name
	battle_title.text = "南 庭  ·  验 艺" if kind=="sect_trial" else ("霜 桥  ·  封 仓" if kind=="archive_boss" else ("废 闸  ·  断 流" if kind.begins_with("sluice") else "旧 渡 口  ·  问 剑"))
	if kind.begins_with("mist_"):battle_title.text="雾 竹 坡  ·  听 雨"
	battle_art.companion_active = not state.current_companion().is_empty()
	battle_art.companion_name=state.current_companion()
	battle_art.region_style="training" if kind=="sect_trial" else state.map_id
	battle_layer.visible = true
	battle_busy=false
	battle_art.reset_presentation()
	_refresh_battle()

func _stop_battle_health_tweens() -> void:
	# Killed tweens cannot write old health into a refreshed or replacement battle.
	for tween: Tween in _battle_health_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_battle_health_tweens.clear()
	_battle_health_values.clear()
	_battle_health_generation = -1

func _begin_battle_health_presentation(before: Dictionary) -> void:
	_stop_battle_health_tweens()
	_battle_health_generation = battle_presentation_generation
	_battle_health_values = before.duplicate()
	# Rules can already have restored health after defeat or increased its maximum
	# after leveling. Those changes belong to the final reconciliation, not a hit.
	battle_hp.max_value = float(before.enemy_max)
	battle_hp.value = float(before.enemy)
	battle_player_hp.max_value = float(before.player_max)
	battle_player_hp.value = float(before.player)
	hp_bar.max_value=float(before.player_max)
	_set_presented_player_hp(float(before.player))

func _present_battle_health_impact(target: String, amount: int) -> void:
	if not battle_presentation_enabled or not battle_busy or current_screen != "battle":
		return
	if _battle_health_generation != battle_presentation_generation or _battle_health_values.is_empty() or amount <= 0:
		return
	var key: String
	var bar: ProgressBar
	match target:
		"enemy", "companion":
			key = "enemy"
			bar = battle_hp
			_battle_health_values[key] = maxf(0.0, float(_battle_health_values[key]) - amount)
		"player":
			key = "player"
			bar = battle_player_hp
			_battle_health_values[key] = maxf(0.0, float(_battle_health_values[key]) - amount)
		"healing", "support_healing":
			key = "player"
			bar = battle_player_hp
			_battle_health_values[key] = minf(float(_battle_health_values.player_max), float(_battle_health_values[key]) + amount)
		_:
			return
	# Accumulate on exact presentation targets, never on a half-finished tween.
	# This keeps support damage correct even when a slow frame crosses both hits.
	var previous: Tween = _battle_health_tweens.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween: Tween = create_tween()
	_battle_health_tweens[key] = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if key=="player":
		tween.tween_method(_set_presented_player_hp,battle_player_hp.value,float(_battle_health_values[key]),0.16)
	else:
		tween.tween_property(bar,"value",float(_battle_health_values[key]),0.16)

func _set_presented_player_hp(value:float)->void:
	battle_player_hp.value=value
	hp_bar.value=value
	hp_caption.text="气血  %d / %d"%[roundi(value),roundi(battle_player_hp.max_value)]

func _refresh_battle() -> void:
	_stop_battle_health_tweens()
	for button in battle_buttons:button.disabled=false
	battle_hp.max_value = state.enemy_max_hp
	battle_hp.value = state.enemy_hp
	battle_player_hp.max_value = state.max_hp
	battle_player_hp.value = state.hp
	battle_info.text = "第 %d 回合    你的真气 %d/%d    ·    敌方意图：%s" % [state.turn+1,state.qi,state.max_qi,state.enemy_intent]
	if state.exposed_turns > 0: battle_info.text += "  破绽%d（守势可解）" % state.exposed_turns
	var statuses:Array[String]=[]
	if state.enemy_weaken_strikes>0:statuses.append("敌方卸劲 -%d · 余%d次来击" % [state.enemy_weaken_amount,state.enemy_weaken_strikes])
	if state.focused_damage>0:statuses.append("蓄锋 +%d · 下次平击" % state.focused_damage)
	battle_status.text="    |    ".join(statuses)
	battle_log.text = "\n".join(state.battle_log.slice(maxi(0,state.battle_log.size()-4)))
	battle_buttons[1].disabled = state.qi<state.active_art_cost() or state.skill_cooldown>0
	battle_buttons[1].text = "2 %s -%d气" % [state.equipped_art,state.active_art_cost()] if state.skill_cooldown==0 else "%s 冷却%d" % [state.equipped_art,state.skill_cooldown]
	battle_buttons[3].text = "4 回春散 ×%d" % state.medicine
	battle_buttons[3].disabled = state.medicine <= 0 or state.hp>=state.max_hp
	_refresh()

func _battle_action(action: String) -> void:
	if not state.battle_active or active_modal or battle_busy: return
	var health_before: Dictionary = {
		"player": state.hp, "player_max": state.max_hp,
		"enemy": state.enemy_hp, "enemy_max": state.enemy_max_hp,
	}
	var result = state.battle_action(action)
	if not result.get("valid",false):
		_toast(result.get("message","此刻无法使用。"))
		return
	battle_art.hit(action,result)
	if audio_on: sfx.play()
	if battle_presentation_enabled and battle_art.is_presenting():
		_begin_battle_health_presentation(health_before)
		var generation=battle_presentation_generation
		battle_busy=true
		for button in battle_buttons:button.disabled=true
		battle_status.text="招式演绎中 · 稍候片刻"
		await battle_art.presentation_finished
		if generation!=battle_presentation_generation:return
		battle_busy=false
	_refresh_battle()
	if result.get("finished",false):
		current_screen = "explore"
		battle_layer.visible = false
		if result.get("won",false):
			if encounter_kind=="sect_trial":
				sect_progress.victory()
			elif encounter_kind.begins_with("mist_"):
				mist_story.battle_victory(encounter_kind)
			elif encounter_kind == "archive_boss":
				chapter_story.battle_victory()
			elif encounter_kind == "sluice_scout":
				state.find_side_clue("ledger")
				_modal("半页水令", "废闸疑云 / 线索已得", "传令人仓促间遗下账页。上面记录的不是渡税，而是开闸时辰。\n\n有人故意把放水的时刻改到了粮船入港之后。你收好账页。"+("证言与账页已经齐备，可以找东南闸首对质。" if state.side_found.has("boatman") else "接下来需要听听南岸船工的证言。"), [["收起账页",func(): _close_modal(); _autosave()]])
			elif encounter_kind == "sluice_boss":
				_finish_sluice()
			elif story_battle:
				state.quest_stage=4
				_modal("灯芯重见天光","战斗胜利 / 渡口失灯","蒲横收起刀，把灯芯和一本薄薄的账册交给你。\n\n‘替我带句话给陆伯。那夜他救的船工，是我弟弟。’\n\n账页上的水纹印记，与你带来的旧信一模一样。事情并未止于一场争斗。\n\n[color=#d3b276]获得修为与铜钱。回到村中央，找陆伯交还物证。[/color]",[["收剑，回村",func(): _close_modal(); _autosave()]])
			else:
				_modal("点到为止","切磋胜利","你与蒲横互相抱拳。熟悉的剑式在几次拆招之间，又有了新的体会。\n\n修为与铜钱已收入行囊。",[["继续行走",func(): _close_modal(); _autosave()]])
		elif action=="flee":
			_toast("你抽身退开。整备之后，随时可以再战。")
		else:
			state.map_id = "qingwei"
			world.change_map("qingwei",Vector2(420,450))
			_modal("胜负之外，江湖仍在","暂败 / 可再次挑战","你力竭倒下，被路过的船工带回村中。休息后已恢复气血，途中遗失了少量铜钱。\n\n先在药铺或无名碑调息；面对敌人蓄力时使用守势。用普攻蓄气，再以绝招破敌。\n\n机缘与已得物品不会丢失。")
		_refresh()

func _stop_audio() -> void:
	for player in [music,sfx]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null

func _exit_tree() -> void:
	_stop_battle_health_tweens()
	_stop_audio()

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_cleanly()

func _quit_cleanly(save_progress:bool=true) -> void:
	if quit_pending: return
	quit_pending=true
	world.active=false
	if save_progress and current_screen=="explore": _autosave()
	_stop_audio()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()

func _screenshot_target(folder:String,stamp:String)->String:
	# Keep two deliberate captures in the same second; never overwrite an existing image.
	var safe_stamp=stamp.replace(":","-")
	while true:
		screenshot_sequence+=1
		var target=folder+"/hero-"+safe_stamp+"-%03d.png"%screenshot_sequence
		if not FileAccess.file_exists(target):return target
	return ""

func _capture_screenshot() -> void:
	if screenshot_pending or quit_pending:return
	if DisplayServer.get_name()=="headless":
		_toast("当前无图形画面，无法截图。")
		return
	screenshot_pending=true
	await RenderingServer.frame_post_draw
	if quit_pending:
		screenshot_pending=false
		return
	var folder = "res://screenshots" if OS.has_feature("editor") else "user://screenshots"
	var error=DirAccess.make_dir_recursive_absolute(folder)
	if error==OK:
		var target=_screenshot_target(folder,Time.get_datetime_string_from_system())
		error=get_viewport().get_texture().get_image().save_png(target)
		if error==OK:last_screenshot_path=ProjectSettings.globalize_path(target)
	screenshot_pending=false
	# A long filesystem path used to cover the combat action with two lines of debug text.
	_toast("截图已保存 · 本地 screenshots 文件夹" if error==OK else "截图保存失败，请检查可用空间。")

func _travel(destination: String, spawn: Vector2) -> void:
	_close_modal()
	state.map_id = destination
	_sync_world_state()
	world.change_map(destination,spawn)
	state.position = world.player_pos
	location_label.text = world.current_location
	_autosave()
	_refresh()
	_toast("抵达"+state.current_region_name()+"。留心路旁的人与事。")

func _exit_sluice_dialogue() -> void:
	if state.quest_stage < 6:
		_modal("废闸古道", "道路 / 东去三里", "草木遮住了通往旧闸的石阶。先把青苇渡的失灯之事查清，再去追寻旧信上的水纹印记。")
		return
	_modal("沿水纹而行", "新机缘 / 废闸疑云", "蒲横的账册里夹着一张水纹印。陆伯认得，那是三里外旧闸的调水凭证。\n\n古道尽头，一边传来船工的呼救，一边有传令人带着纸卷匆匆离去。先救人，还是先追线索？\n\n两边都能调查，行动先后将改变这一程的收获。", [["前往废闸",func(): _travel("sluice",Vector2(190,520))],["留在村中",_close_modal]],true)

func _boatman_dialogue() -> void:
	if state.shen_care_stage>0:
		shen_story.patient();return
	if state.side_found.has("boatman"):
		_modal("许照川 · 船工", "废闸 / 已得证言", "‘那天有人换了水令，命我们在逆流时入港。不是天灾，是有人在等粮船翻。’\n\n他的证言你已记下。沈青留下的药，让他能撑着走回村里。")
		return
	var body = "年轻船工被断缆困住了腿，身旁的木板随着水流晃动。\n\n你可以先救他，也可以先向东北追去。无论选哪条路，都要记得回头。"
	if state.side_choice == "pursuit": body = "你追查账页后赶来，船工仍在等援手。伤口虽已肿起，索幸还有气力开口。\n\n救下他，就能听到那夜被人更换水令的真相。"
	_modal("水边的呼救", "抉择 / 人命与线索",body,[["割断缆绳救人",_rescue_boatman],["暂且离开",_close_modal]])

func _rescue_boatman() -> void:
	if state.side_choice.is_empty(): state.choose_side_route("rescue")
	state.find_side_clue("boatman")
	_modal("许照川的证言", "线索 / 改过的水令", "‘有人把开闸时辰改了。我们的粮船，本不该在那个时候进港。’\n\n"+("你先伸出援手，保住了他药箱中的回春散。他答应事后送你两包。" if state.side_choice=="rescue" else "你替他包扎妥当。船工明白你的苦衷，只盼夺回的账页没有白费。"),[["记下证言",func(): _close_modal(); _autosave()]])

func _runner_dialogue() -> void:
	if state.side_found.has("ledger"):
		_modal("空下来的石阶", "废闸 / 已得账页", "传令人已退走。石阶上只余一角被风吹干的墨迹。你所得的账页已妥善收入行囊。")
		return
	_modal("携卷的传令人", "抉择 / 半页水令", "黑衣传令人把纸卷收入袖中：‘这不是你该管的河。’\n\n他看向东南闸楼，伸手去碰刀柄。\n\n"+("先截住账页，也许能保住更多细节；南边的船工仍在等援手。" if not state.side_found.has("boatman") else "船工已经获救，眼下该轮到纸上的秘密了。"),[["截住传令人",func():
		if state.side_choice.is_empty(): state.choose_side_route("pursuit")
		_start_battle("sluice_scout")],["暂且退开",_close_modal]],true)

func _sluice_boss_dialogue() -> void:
	if state.side_stage < 2:
		_modal("旧闸守门人", "废闸 / 证据未齐", "闸楼里的人没有应声。要让对方开口，你需要船工的证言，以及传令人的水令账页。")
		return
	if state.side_stage >= 3:
		_modal("闸门归静", "废闸 / 已了因果", "水流恢复了往常的节律。你找到的那份伪造水令，指向上游的霜桥城。\n\n这段路已走完，另一段江湖尚待展开。")
		return
	_modal("闸首 · 罗沉", "交锋 / 逆水而行", "证言与账页摆在面前，罗沉再无借口。\n\n‘开闸的印是我的，改时辰的手却不在这里。你能赢我，也未必能赢那条粮路。’\n\n[color=#d3b276]罗沉的重击会造成破绽。守势可清除破绽并防止再次施加。备好药，再来迎战。[/color]",[["问个明白",func(): _start_battle("sluice_boss")],["先行整备",_close_modal]],true)

func _finish_sluice() -> void:
	var awarded = state.finish_side_quest()
	var reward = "修为 +80、铜钱 +45、回春散 ×2" if state.side_choice=="rescue" else "修为 +80、铜钱 +65"
	_modal("水令留痕", "支线完成 / 废闸疑云", "罗沉交出原本的水令。两份命令只差一个时辰，却足以让整船的粮沉入河底。\n\n你把证据收入旧信。霜桥城的名字，终于有了重量。\n\n[color=#d3b276]"+reward+"[/color]"+("\n先救人留下的是人情；往后的路，会有人记得。" if state.side_choice=="rescue" else "\n先追账册保住的是细节；往后的路，还需更多印证。"),[["收好水令",func(): _close_modal(); _autosave()]],true)
	if not awarded: _toast("此机缘奖励已领取，不会重复结算。")

func _sluice_cache_dialogue() -> void:
	if state.shen_care_stage==2:
		if state.tangqi_stage==1:shen_story.shared_shelter()
		else:shen_story.shelter()
		return
	if state.tangqi_stage==1:
		companion_story.notebook();return
	_modal("旧仓药棚", "休整 / 江湖救急", "废弃药棚里还留着一张干净的草席。墙上写着：‘行水路者，留一处避雨之地。’\n\n你可以在这里恢复气血与真气。"+shen_story.shelter_append(),[["静坐调息",func(): state.heal_rest(); _close_modal(); _toast("调息完毕，可以继续调查。")],["离开",_close_modal]])

func _show_map() -> void:
	if current_screen=="battle": return
	_modal("江湖舆图",state.current_region_name()+" / 北在上 · 不提供传送","",[["收起舆图",_close_modal]],true)
	var panel = overlay.get_child(overlay.get_child_count()-1)
	var chart = Chart.new()
	chart.position = Vector2(30,105)
	chart.size = Vector2(780,330)
	chart.map_id = state.map_id
	chart.player_position = world.player_pos
	chart.markers = world.interactables
	chart.ui_font = font
	chart.current_target = world._quest_target_id()
	chart.bridge_repaired=state.bridge_repaired
	panel.add_child(chart)

func _show_martials() -> void:
	if current_screen=="battle": return
	var body = "[color=#d3b276]当前修习：%s[/color]\n%s · 考绩%d\n5次熟习，15次通明。卸劲减来击；蓄锋强化下次平击。\n\n" % [state.equipped_art,state.sect_rank_name(),state.sect_merit]
	var options: Array = []
	for art in state.available_arts():
		var rank_names = ["初窥","熟习","通明"]
		body += "[color=#d3b276]%s · %s[/color]（已施展%d次）\n%s\n" % [art,rank_names[state.art_rank(art)-1],int(state.art_uses.get(art,0)),advanced_martial.summary(art)]
		options.append(["修习 "+art,_equip_art.bind(art)])
	if state.sect=="未入门": body += "完成青苇渡机缘后，门派荐帖将带来新的武学。"
	options.append(["返回江湖",_close_modal])
	_modal("武学与心得","修行 / 各有所长，皆可成路",body,options,true)

func _equip_art(id: String) -> void:
	if state.equip_art(id):
		_close_modal()
		_toast("已修习"+id+"，战斗中按2施展。")
	else:
		_toast("暂未习得这门武学。")

func _show_workshop() -> void:
	if current_screen=="battle": return
	workshop.show()

func _sync_world_state() -> void:
	world.quest_stage = state.quest_stage
	world.companion_active = not state.current_companion().is_empty()
	world.companion_name=state.current_companion()
	world.personal_target_id=companion_story.target_id()
	world.shen_target_id=shen_story.target_id() if _track_shen() else ""
	world.mist_target_id=mist_story.target_id()
	world.mentor_pending=state.sect_trial_won and state.sect_rank==1
	world.chapter_stage=state.chapter_two_stage
	world.chapter_ending=state.chapter_two_ending
	world.chapter_target_id=chapter_story.target_id()
	world.bridge_repaired=state.bridge_repaired
	world.resource_depleted=state.gathered_nodes
	world.side_stage = state.side_stage
	world.side_target_id = ("ledger_runner" if state.side_found.has("boatman") else "stranded_boatman") if state.side_stage<2 else ""

func _show_save_slots()->void:save_slots.save_page()
func _show_load_slots()->void:save_slots.load_page()

func _track_shen()->bool:
	return shen_story.pending() and not companion_story.pending() and not (state.map_id=="mistwood" and state.mist_stage<4) and not (state.map_id=="qingwei" and state.sect_trial_won and state.sect_rank==1)
