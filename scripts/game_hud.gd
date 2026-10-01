extends RefCounted
## Original full-world wuxia interface. This layer owns presentation only.
## Host fields and action callbacks stay intact for saves, stories and combat.
const Portraits = preload("res://scripts/character_portraits.gd")
const WorldScene = preload("res://scripts/world.gd")
const IVORY = Color("f1e6ca")
const GOLD = Color("dfbd7a")
const SOFT = Color("b4c4b6")
const JADE = Color("80c8ac")
const INK = Color("102b2b")

class InkWash extends Control:
	var variant: String = "side"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if variant in ["top", "bottom"]:
			var top_color := Color(0.018, 0.055, 0.05, .63 if variant=="top" else 0.0)
			var bottom_color := Color(0.022, 0.07, 0.07, .83 if variant=="bottom" else 0.0)
			draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w,h),Vector2(0,h)]),PackedColorArray([top_color,top_color,bottom_color,bottom_color]))
			return
		var edge: PackedVector2Array = PackedVector2Array([
			Vector2(0, 2), Vector2(w - 15, 0), Vector2(w - 4, h * .2),
			Vector2(w - 8, h * .48), Vector2(w, h * .76), Vector2(w - 13, h - 2),
			Vector2(9, h), Vector2(0, h - 8)])
		draw_colored_polygon(edge, Color(0.025, 0.085, 0.079, .88))
		draw_line(Vector2(1, 1), Vector2(w * .57, 1), Color(.83, .69, .43, .65), 1)
		if variant == "quest":
			draw_line(Vector2(4, 15), Vector2(4, h - 17), Color(.83, .69, .43, .8), 2)
			draw_colored_polygon(PackedVector2Array([Vector2(4, 5), Vector2(8, 10), Vector2(4, 15), Vector2(0, 10)]), GOLD)

class ActionGlyph extends Control:
	var kind: String = "map"
	var ink: Color = GOLD
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Color = ink
		match kind:
			"map":
				draw_polyline(PackedVector2Array([Vector2(3,6),Vector2(12,3),Vector2(22,7),Vector2(31,4),Vector2(31,25),Vector2(22,28),Vector2(12,24),Vector2(3,27),Vector2(3,6)]), c, 1.6, true)
				draw_line(Vector2(12,3),Vector2(12,24),c,1.2,true);draw_line(Vector2(22,7),Vector2(22,28),c,1.2,true)
			"sword":
				draw_polyline(PackedVector2Array([Vector2(10,22),Vector2(25,3),Vector2(29,2),Vector2(28,7),Vector2(13,25)]),c,1.8,true)
				draw_line(Vector2(6,18),Vector2(17,28),c,2,true);draw_line(Vector2(10,24),Vector2(4,30),c,3,true)
			"bag":
				draw_polyline(PackedVector2Array([Vector2(10,4),Vector2(23,4),Vector2(20,10),Vector2(27,18),Vector2(27,25),Vector2(22,29),Vector2(10,29),Vector2(5,25),Vector2(5,18),Vector2(13,10),Vector2(10,4)]),c,1.8,true)
				draw_line(Vector2(10,11),Vector2(23,11),c,2,true);draw_line(Vector2(16,17),Vector2(16,24),c,1,true)
			"journal":
				draw_style_box(_book_style(),Rect2(6,3,22,27));draw_line(Vector2(11,4),Vector2(11,29),c,1.6,true)
				for y in [10,15,20]:draw_line(Vector2(16,y),Vector2(23,y),c,1.1,true)
			"craft":
				draw_line(Vector2(10,26),Vector2(25,7),c,3,true)
				draw_polyline(PackedVector2Array([Vector2(17,4),Vector2(21,1),Vector2(32,10),Vector2(28,15),Vector2(17,4)]),c,1.8,true)
				draw_line(Vector2(4,29),Vector2(27,29),c,1.6,true)
	func _book_style() -> StyleBoxFlat:
		var s := StyleBoxFlat.new();s.bg_color=Color.TRANSPARENT;s.border_color=ink;s.set_border_width_all(1);return s

var host
var identity_wash: Control
var exploration: Control
var backdrop: Control
var system_bar: Control
var interaction: Control
var movement_hint: Label
var toast_wash: Control
var place_wash: Control
var quest_wash: Control
var music_button: Button
var nav_buttons: Array[Button] = []
var battle_player_value: Label
var battle_enemy_value: Label
var battle_qi: Label
var battle_hint: Label
var battle_chrome: Control
var quest_notice: Label
var quest_notice_time: float = 0.0
var previous_quest: String = ""
var last_warning: int = -1
var last_audio: int = -1
var last_near_hint: String = ""
var last_status_text: String = ""
var toast_in_battle:bool=false

func build(game) -> void:
	host = game
	var bg := ColorRect.new();bg.color=INK;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.add_child(bg)
	var container := SubViewportContainer.new()
	container.name="WorldViewportContainer";container.size=Vector2(1280,800);container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.add_child(container)
	host.world_view=SubViewport.new();host.world_view.size=Vector2i(1280,800);host.world_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(host.world_view)
	host.world=WorldScene.new();host.world.viewport_rect=Rect2(0,0,1280,800);host.world.ui_font=host.font
	host.world.interacted.connect(host._interact);host.world_view.add_child(host.world)
	exploration=_group(host,"ExplorationHUD")
	_wash(exploration,Rect2(0,0,1280,165),"top")
	_wash(exploration,Rect2(0,660,1280,140),"bottom")
	_build_identity()
	_build_place()
	_build_quest()
	_build_actions()
	interaction=_group(exploration,"InteractionHint")
	interaction.position=Vector2(25,695);interaction.size=Vector2(430,34)
	host.near_label=_text(interaction,"",Rect2(0,0,430,32),17,IVORY)
	quest_notice=_text(exploration,"",Rect2(430,117,420,30),16,GOLD);quest_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.world.location_changed.connect(func(place):
		if is_instance_valid(host.location_label):host.location_label.text=place)
	host.battle_layer=_group(host,"BattleHUD");host.battle_layer.size=Vector2(1280,800);host.battle_layer.visible=false
	toast_wash=_wash(host,Rect2(330,182,620,56),"side")
	host.status_label=_text(toast_wash,"",Rect2(18,9,584,40),15,GOLD);host.status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.status_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	toast_wash.visible=false
	host.overlay=_group(host,"ModalLayer");host.overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_identity() -> void:
	var identity := _wash(exploration,Rect2(20,23,353,154),"side")
	identity_wash=identity;identity.mouse_filter=Control.MOUSE_FILTER_PASS
	Portraits.attach(identity,"hero",Rect2(-9,-9,105,107))
	host.portrait=_text(identity,"侠",Rect2(21,13,45,45),32,GOLD);host.portrait.visible=false
	host.name_label=_text(identity,"无名客",Rect2(96,11,246,31),22,IVORY)
	host.sect_label=_text(identity,"",Rect2(97,43,242,21),13,SOFT)
	host.hp_bar=host._bar(identity,Rect2(99,96,219,7),JADE)
	host.qi_bar=host._bar(identity,Rect2(99,135,219,5),GOLD)
	host.hp_caption=_text(identity,"",Rect2(99,70,226,22),13,IVORY)
	host.qi_caption=_text(identity,"",Rect2(99,109,226,22),13,GOLD)
	host.stat_label=_text(exploration,"",Rect2(25,163,350,22),13,SOFT);host.stat_label.visible=false
	host.exp_label=_text(exploration,"",Rect2(25,190,350,22),13,GOLD);host.exp_label.visible=false
	# Secondary statistics belong in the existing inventory, not permanent chrome.
	identity.tooltip_text="I · 查看行囊、修为与装备"

func _build_place() -> void:
	place_wash=_group(exploration,"PlaceCaption")
	place_wash.position=Vector2(461,23);place_wash.size=Vector2(358,89)
	host.region_header=_text(place_wash,"青苇渡",Rect2(24,5,310,33),24,IVORY);host.region_header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.chapter_header=_text(place_wash,"",Rect2(12,40,334,23),13,GOLD);host.chapter_header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.location_label=_text(place_wash,"",Rect2(12,65,334,18),12,SOFT);host.location_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.weather_label=_text(exploration,"",Rect2(923,218,330,21),12,SOFT);host.weather_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func _build_quest() -> void:
	quest_wash=_wash(exploration,Rect2(971,24,284,190),"quest")
	quest_wash.mouse_filter=Control.MOUSE_FILTER_PASS
	_text(quest_wash,"行 纪",Rect2(22,10,108,22),12,GOLD)
	var open_journal: Button = host._button(quest_wash,"J  展卷",Rect2(202,6,67,27),host._show_journal)
	_flat_button(open_journal,12)
	host.quest_label=_text(quest_wash,"",Rect2(22,39,242,32),21,IVORY)
	host.hint_label=_text(quest_wash,"",Rect2(22,81,242,94),15,SOFT)

func _build_actions() -> void:
	movement_hint=_text(exploration,"W A S D  行走    ·    E  交互",Rect2(25,700,354,25),13,SOFT)
	system_bar=_group(exploration,"SystemActions")
	var save: Button = host._button(system_bar,"存卷  F6",Rect2(21,745,87,30),host._show_save_slots);_flat_button(save,13)
	var load_save: Button = host._button(system_bar,"读卷  F10",Rect2(114,745,95,30),host._show_load_slots);_flat_button(load_save,13)
	music_button=host._button(system_bar,"乐音 开",Rect2(216,745,77,30),host._toggle_audio);_flat_button(music_button,13)
	var rest:Button=host._button(system_bar,"小憩 Esc",Rect2(312,745,107,30),host._show_pause);_flat_button(rest,13)
	rest.tooltip_text="休整、手记与安全离开"
	var items: Array = [["舆图","M","map",host._show_map],["武学","K","sword",host._show_martials],["行囊","I","bag",host._show_inventory],["行纪","J","journal",host._show_journal],["工艺","B","craft",host._show_workshop]]
	for i in range(items.size()):
		var button: Button = host._button(exploration,"",Rect2(821+i*88,713,80,73),items[i][3])
		_flat_button(button,16);button.tooltip_text=items[i][0]+" · "+items[i][1]
		var glyph := ActionGlyph.new();glyph.kind=items[i][2];glyph.position=Vector2(8,5);glyph.size=Vector2(34,34);button.add_child(glyph)
		var key := _text(button,items[i][1],Rect2(49,7,24,21),12,SOFT);key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		_text(button,items[i][0],Rect2(10,42,60,25),16,IVORY)
		nav_buttons.append(button)

func reflow_battle() -> void:
	# Existing actor choreography uses a 938-wide stage. Preserve its coordinates
	# and scale its canvas only; HP/control hitboxes are independently laid out.
	host.battle_art.position=Vector2.ZERO;host.battle_art.scale=Vector2.ONE*(1280.0/938.0)
	battle_chrome=_group(host.battle_layer,"BattleChrome")
	_wash(battle_chrome,Rect2(0,0,1280,170),"top")
	_wash(battle_chrome,Rect2(0,503,1280,297),"bottom")
	host.battle_layer.move_child(battle_chrome,1)
	var old_log_panel: Control = host.battle_log.get_parent()
	for child in host.battle_layer.get_children():
		if child is Panel:
			child.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		elif child is Label and child not in [host.battle_title,host.enemy_title,host.battle_info,host.battle_status]:
			if child.text.begins_with("回合制"):
				child.visible=false
			elif child.text=="无名客":
				child.position=Vector2(64,52);child.size=Vector2(280,32);child.add_theme_font_size_override("font_size",23)
	host.battle_title.position=Vector2(387,32);host.battle_title.size=Vector2(506,39);host.battle_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.battle_title.add_theme_font_size_override("font_size",24)
	host.battle_player_hp.position=Vector2(64,97);host.battle_player_hp.size=Vector2(283,9)
	host.battle_hp.position=Vector2(933,97);host.battle_hp.size=Vector2(283,9)
	host.enemy_title.position=Vector2(910,52);host.enemy_title.size=Vector2(305,32);host.enemy_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;host.enemy_title.add_theme_font_size_override("font_size",23)
	battle_player_value=_text(host.battle_layer,"",Rect2(64,118,175,25),14,IVORY)
	battle_enemy_value=_text(host.battle_layer,"",Rect2(933,118,283,25),14,IVORY)
	battle_enemy_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	host.battle_player_hp.value_changed.connect(_sync_player_battle_hp)
	host.battle_player_hp.changed.connect(_sync_player_battle_hp)
	host.battle_hp.value_changed.connect(_sync_enemy_battle_hp)
	host.battle_hp.changed.connect(_sync_enemy_battle_hp)
	battle_qi=_text(host.battle_layer,"",Rect2(239,118,160,25),14,GOLD)
	_sync_player_battle_hp();_sync_enemy_battle_hp()
	host.battle_info.position=Vector2(104,504);host.battle_info.size=Vector2(1072,34);host.battle_info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;host.battle_info.add_theme_font_size_override("font_size",18)
	host.battle_status.position=Vector2(144,545);host.battle_status.size=Vector2(992,25);host.battle_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;host.battle_status.add_theme_font_size_override("font_size",15)
	old_log_panel.position=Vector2(164,590);old_log_panel.size=Vector2(952,91)
	host.battle_log.position=Vector2(12,0);host.battle_log.size=Vector2(928,85);host.battle_log.add_theme_font_size_override("normal_font_size",15)
	battle_hint=_text(host.battle_layer,"观敌势，择一招",Rect2(487,665,306,30),13,SOFT);battle_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for i in range(host.battle_buttons.size()):
		var button: Button=host.battle_buttons[i]
		button.position=Vector2(58+i*235,706);button.size=Vector2(224,65)
		button.add_theme_font_size_override("font_size",17)
		var normal := _action_style(Color("163b39"),Color("8c805e"))
		button.add_theme_stylebox_override("normal",normal)
		button.add_theme_stylebox_override("hover",_action_style(Color("28574e"),GOLD))
		button.add_theme_stylebox_override("pressed",_action_style(Color("477662"),IVORY))
		button.add_theme_stylebox_override("disabled",_action_style(Color("182b29"),Color("3c4b40")))
		button.add_theme_color_override("font_disabled_color",Color("768679"))

func _sync_player_battle_hp(_value:float=0) -> void:
	if is_instance_valid(battle_player_value):battle_player_value.text="气血  %d / %d" % [roundi(host.battle_player_hp.value),roundi(host.battle_player_hp.max_value)]

func _sync_enemy_battle_hp(_value:float=0) -> void:
	if is_instance_valid(battle_enemy_value):battle_enemy_value.text="气血  %d / %d" % [roundi(host.battle_hp.value),roundi(host.battle_hp.max_value)]

func refresh() -> void:
	if host==null:return
	var next_quest: String=host.quest_label.text+"|"+host.hint_label.text
	if not previous_quest.is_empty() and previous_quest!=next_quest and host.current_screen=="explore":
		quest_notice.text="◇  行纪有续 · "+host.quest_label.text;quest_notice_time=4.5
	previous_quest=next_quest
	var hint_height: float=maxf(42.0,host.hint_label.get_minimum_size().y)
	host.hint_label.size.y=hint_height
	quest_wash.size.y=host.hint_label.position.y+hint_height+16
	quest_wash.queue_redraw()
	host.weather_label.position.y=quest_wash.position.y+quest_wash.size.y+5
	identity_wash.tooltip_text=host.stat_label.text+"\n"+host.exp_label.text+"\nI · 查看行囊与装备"
	quest_wash.tooltip_text=host.quest_label.text+"\n"+host.hint_label.text+"\nJ · 展开完整行纪"
	battle_qi.text="真气  %d / %d" % [host.state.qi,host.state.max_qi]
	for i in range(host.battle_buttons.size()):
		var button: Button=host.battle_buttons[i]
		if i==1:
			button.tooltip_text=("尚需真气：%d" % host.state.active_art_cost()) if host.state.qi<host.state.active_art_cost() else ("冷却：%d回合" % host.state.skill_cooldown if host.state.skill_cooldown>0 else "施展已装备武学")
		elif i==3:button.tooltip_text="气血已满" if host.state.hp>=host.state.max_hp else ("回春散不足" if host.state.medicine<=0 else "服药恢复气血")
	tick(0.0)

func tick(delta: float) -> void:
	if host==null:return
	exploration.visible=host.current_screen=="explore"
	host.location_label.visible=host.location_label.text!=host.region_header.text
	if exploration.visible:
		var point: Vector2=host.world.player_pos-host.world.camera_pos
		var actor_rect:=Rect2(point-Vector2(27,80),Vector2(54,90))
		for item in [identity_wash,quest_wash,place_wash]:
			var target_alpha: float=.23 if Rect2(item.position,item.size).intersects(actor_rect) else 1.0
			item.modulate.a=move_toward(item.modulate.a,target_alpha,delta*5.0)
		for item in nav_buttons:
			var target_alpha: float=.23 if item.get_rect().intersects(actor_rect) else 1.0
			item.modulate.a=move_toward(item.modulate.a,target_alpha,delta*5.0)
	interaction.visible=exploration.visible and not host.world.nearby_id.is_empty() and not host.active_modal
	movement_hint.visible=not interaction.visible
	quest_notice_time=maxf(0,quest_notice_time-delta)
	quest_notice.visible=quest_notice_time>0 and not host.active_modal
	quest_notice.modulate.a=minf(1.0,quest_notice_time)
	if last_audio!=int(host.audio_on):
		music_button.text="乐音 开" if host.audio_on else "乐音 关"
		last_audio=int(host.audio_on)
	toast_wash.visible=host.current_screen!="title" and not host.active_modal and (host.toast_time>0 or host.save_warning)
	if last_warning!=int(host.save_warning):
		host.status_label.add_theme_color_override("font_color",Color("f0b594") if host.save_warning else GOLD)
		last_warning=int(host.save_warning)
	if host.save_warning and host.toast_time<=0:host.status_label.text="自动存档失败 · 按 F5 重试；离开前请确认存档"
	var next_toast_battle:bool=host.current_screen=="battle"
	if next_toast_battle!=toast_in_battle:
		toast_in_battle=next_toast_battle
		toast_wash.position=Vector2(140,774) if toast_in_battle else Vector2(330,182)
		toast_wash.size=Vector2(1000,26) if toast_in_battle else Vector2(620,58)
		host.status_label.position=Vector2(10,3) if toast_in_battle else Vector2(18,9)
		host.status_label.size=Vector2(980,20) if toast_in_battle else Vector2(584,40)
		host.status_label.autowrap_mode=TextServer.AUTOWRAP_OFF if toast_in_battle else TextServer.AUTOWRAP_WORD_SMART
		host.status_label.clip_text=toast_in_battle
		host.status_label.mouse_filter=Control.MOUSE_FILTER_PASS if toast_in_battle else Control.MOUSE_FILTER_IGNORE
		host.status_label.add_theme_font_size_override("font_size",13 if toast_in_battle else 15)
		last_status_text=""
		toast_wash.queue_redraw()
	if last_status_text!=host.status_label.text:
		last_status_text=host.status_label.text
		host.status_label.tooltip_text=host.status_label.text
		host.status_label.size.y=20.0 if toast_in_battle else maxf(40.0,host.status_label.get_minimum_size().y)
		toast_wash.size.y=26.0 if toast_in_battle else host.status_label.size.y+18
		toast_wash.queue_redraw()
	toast_wash.modulate.a=1.0 if host.save_warning else minf(1.0,host.toast_time)
	battle_hint.text="剑招未尽 · 请稍候" if host.battle_busy else "观敌势，择一招  ·  1—5"
	# Reassert thin dimensions after deferred legacy bar sizing from _bar().
	if host.battle_player_hp.size.x<282:host.battle_player_hp.size=Vector2(283,9)
	if host.battle_hp.size.x<282:host.battle_hp.size=Vector2(283,9)

func _group(parent: Node, title: String) -> Control:
	var result := Control.new();result.name=title;result.size=Vector2(1280,800);result.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(result);return result

func _wash(parent: Node, rect: Rect2, variant: String) -> Control:
	var result := InkWash.new();result.variant=variant;result.position=rect.position;result.size=rect.size;result.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(result);return result

func _text(parent: Node, value: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var result: Label=host._label(parent,value,rect,font_size,color)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result.add_theme_color_override("font_shadow_color",Color(0.015,0.04,0.03,.85))
	result.add_theme_constant_override("shadow_offset_x",1);result.add_theme_constant_override("shadow_offset_y",1)
	return result

func _flat_button(button: Button, font_size: int) -> void:
	button.add_theme_font_size_override("font_size",font_size)
	button.add_theme_stylebox_override("normal",_action_style(Color(0,0,0,0),Color(0,0,0,0)))
	button.add_theme_stylebox_override("hover",_action_style(Color(.25,.37,.28,.76),Color(.75,.64,.43,.65)))
	button.add_theme_stylebox_override("pressed",_action_style(Color(.38,.48,.32,.9),GOLD))

func _action_style(background: Color, edge: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new();result.bg_color=background;result.border_color=edge
	result.border_width_bottom=1;result.border_width_top=1
	result.corner_radius_top_left=2;result.corner_radius_bottom_right=2
	result.content_margin_left=3;result.content_margin_right=3;result.content_margin_top=3;result.content_margin_bottom=3
	return result
