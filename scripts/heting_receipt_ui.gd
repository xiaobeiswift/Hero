extends Control
## Real finite encounter. HeroState commits costs; this controller only presents
## accepted facts and exits through the normal save-failure gate.
const Arena = preload("res://scripts/formation_battle_art.gd")
const Pause = preload("res://scripts/pause_menu.gd")
const ACTIONS = ["attack", "skill", "guard", "item", "flee"]
var host
var generation: int
var rules
var epoch:int
var close_pending:bool=false
var retreat_button:Button
var art
var target_cards: Dictionary = {}
var action_buttons: Array[Button] = []
var health: ProgressBar
var health_text: Label
var qi_text: Label
var turn_text: Label
var notice: Label
var details: Label
var log_text: RichTextLabel
var pending: Dictionary = {}
var display: Dictionary = {}
var hero_card:Control
var support_card:Control
var hero_name:Label
var support_name:Label
var support_role:Label

static func open(owner) -> Control:
	if owner.current_screen != "explore" or owner.quit_pending or not owner.state.start_receipt_battle():
		return null
	owner.modal_generation += 1
	owner._clear_overlay()
	owner.active_modal = true
	owner.modal_autosave_on_close = false
	owner.current_screen="receipt_battle"
	var panel = load("res://scripts/heting_receipt_ui.gd").new()
	panel.host = owner
	panel.generation = owner.modal_generation
	panel.rules=owner.state.receipt_session
	panel.epoch=owner.state.receipt_battle_epoch
	owner.overlay.set_meta("receipt_battle", panel)
	owner.overlay.add_child(panel)
	panel.build()
	owner._refresh()
	return panel

func valid() -> bool:
	return is_instance_valid(host) and is_inside_tree() and not host.quit_pending and host.active_modal and host.current_screen == "receipt_battle" and host.state.receipt_session==rules and host.state.receipt_battle_epoch==epoch and host.modal_generation == generation and host.overlay.get_meta("receipt_battle", null) == self

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	art=Arena.new();art.size=Vector2(1280,685);art.draw_labels=false;add_child(art)
	art.target_requested.connect(select_target);art.impact_presented.connect(_impact);art.presentation_finished.connect(_finished)
	host._panel(self,Rect2(0,0,1280,65),Color(.025,.08,.09,.91),Color(.35,.42,.34,.4))
	host._label(self,"复签不撤",Rect2(28,14,230,34),24,host.PAPER)
	host._label(self,"公秤外栈桥",Rect2(198,23,230,24),14,host.MUTED)
	turn_text=host._label(self,"",Rect2(587,18,200,30),20,host.GOLD)
	host._label(self,"实战 · 真实消耗",Rect2(932,23,166,25),13,host.MUTED)
	retreat_button=host._button(self,"Esc  退开",Rect2(1132,15,120,36),leave)
	hero_card=host._panel(self,Rect2(0,0,160,65),Color(.045,.105,.11,.8),Color(0,0,0,0))
	hero_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hero_name=host._label(hero_card,"",Rect2(6,2,148,27),17,host.PAPER);hero_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hero_name.clip_text=true
	health=host._bar(hero_card,Rect2(6,26,148,5),host.JADE)
	health_text=host._label(hero_card,"",Rect2(6,34,148,24),12,host.PAPER)
	support_card=host._panel(self,Rect2(0,0,160,47),Color(.045,.105,.11,.8),Color(0,0,0,0));support_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	support_name=host._label(support_card,"",Rect2(6,1,148,26),17,host.PAPER);support_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	support_role=host._label(support_card,"",Rect2(6,25,148,20),12,Color("b9d1bd"));support_role.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for id:String in ["striker","bracer"]:
		var card=host._button(self,"",Rect2(0,0,160,65),select_target.bind(id))
		var title=host._label(card,"",Rect2(6,2,148,25),17,host.PAPER);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.clip_text=true
		var bar=host._bar(card,Rect2(6,26,148,5),Color("bd7b62"))
		var value=host._label(card,"",Rect2(6,34,98,22),12,host.PAPER)
		var intent=host._label(card,"",Rect2(98,34,56,22),12,host.GOLD);intent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		for child in card.get_children():
			if child is Control:child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		target_cards[id]={"button":card,"title":title,"bar":bar,"value":value,"intent":intent}
	host._panel(self,Rect2(0,670,1280,130),Color("102727"),Color("596a58"))
	host._panel(self,Rect2(0,634,1280,37),Color(.025,.075,.08,.84),Color(0,0,0,0))
	notice=host._label(self,"",Rect2(30,640,910,28),15,host.GOLD)
	host._label(self,"点击对手换目标 · Tab切换",Rect2(987,644,266,24),12,host.MUTED)
	qi_text=host._label(self,"",Rect2(32,683,245,58),14,host.PAPER)
	for i in range(5):
		var button=host._button(self,"",Rect2(280+i*190,687,177,52),submit.bind(ACTIONS[i]))
		button.add_theme_font_size_override("font_size",16)
		button.add_theme_stylebox_override("normal",host._style(Color("1a403a"),Color("8d855e")))
		button.add_theme_stylebox_override("hover",host._style(Color("2b5a4e"),host.GOLD))
		button.add_theme_stylebox_override("disabled",host._style(Color("162c28"),Color("3d4b40")))
		button.add_theme_color_override("font_disabled_color",Color("849184"))
		button.mouse_entered.connect(_describe.bind(ACTIONS[i]));action_buttons.append(button)
	log_text=RichTextLabel.new();log_text.position=Vector2(32,748);log_text.size=Vector2(1200,23)
	log_text.add_theme_font_size_override("normal_font_size",14);log_text.scroll_following=true;log_text.mouse_filter=Control.MOUSE_FILTER_PASS;add_child(log_text)
	details=host._label(self,"",Rect2(32,774,1210,22),12,host.MUTED)
	display=rules.snapshot();art.set_snapshot(display);refresh()

func _process(_delta:float)->void:
	if valid() and art!=null and hero_card!=null:_sync_actor_cards()

func _sync_actor_cards()->void:
	var cards={"hero":hero_card,"support":support_card,"striker":target_cards.striker.button,"bracer":target_cards.bracer.button}
	for id:String in cards:
		var control:Control=cards[id]
		var area:Rect2=art.unit_label_rect(id)
		control.position=area.position;control.size=area.size
		control.modulate.a=art.unit_label_alpha(id)
	support_card.visible=not rules.companion.is_empty()

func _input(event: InputEvent) -> void:
	if not valid() or not event is InputEventKey or not event.pressed or event.echo:return
	var key:int=event.physical_keycode
	if key not in [KEY_TAB,KEY_ESCAPE,KEY_ENTER,KEY_SPACE,KEY_F5,KEY_F6,KEY_F9,KEY_F10] and not (key>=KEY_1 and key<=KEY_5):return
	get_viewport().set_input_as_handled()
	if key in [KEY_F5,KEY_F6,KEY_F9,KEY_F10]:
		details.text="请先退开，交锋结束后再存卷或读卷。";return
	if close_pending:return
	if key==KEY_TAB:cycle_target()
	elif key==KEY_ESCAPE:leave()
	elif key in [KEY_ENTER,KEY_SPACE]:submit("attack")
	elif key>=KEY_1 and key<=KEY_5:submit(ACTIONS[key-KEY_1])

func select_target(id: String) -> void:
	if not valid() or close_pending or not host.state.select_receipt_target(id):return
	display=rules.snapshot(); art.set_snapshot(display); refresh()

func cycle_target() -> void:
	if not valid() or close_pending or not host.state.cycle_receipt_target():return
	display=rules.snapshot(); art.set_snapshot(display); refresh()

func submit(action: String) -> void:
	if not valid() or close_pending:return
	_accept(action)

func _accept(action:String)->void:
	var result:Dictionary=host.state.receipt_battle_action(action)
	if not result.get("accepted",false):
		details.text=String(result.get("reason","此刻无法出招。"));return
	pending=result;display=result.before
	art.present(result);refresh()
	if host.audio_on:host.sfx.play()

func _impact(_target:String,_amount:int) -> void:
	if not valid() or pending.is_empty():return
	display=art.display_snapshot;refresh()

func _finished() -> void:
	if not valid() or pending.is_empty():return
	if not host.state.finish_receipt_presentation(int(pending.epoch),int(pending.token)):return
	pending={};display=rules.snapshot();art.set_snapshot(display)
	if not rules.active:
		_return_to_world();return
	if close_pending:
		_accept("flee");return
	refresh()

func leave() -> void:
	if not valid() or close_pending:return
	if rules.locked:
		details.text="这一招已经出手，请待收招后再退开。";return
	_accept("flee")

func request_application_close()->void:
	if not valid() or close_pending:return
	close_pending=true
	if rules.locked:
		refresh();return
	if rules.active:_accept("flee")
	else:_return_to_world()

func _return_to_world()->void:
	if not valid() or rules.active or rules.locked:return
	var owner=host
	var close_after:bool=close_pending
	var result:Dictionary=owner.state.receipt_settlement
	# Defeat's safe recovery position must reach the world before main's next
	# process frame synchronizes its player position back into the model.
	if String(result.get("outcome",""))=="defeat":
		owner.world.teleport(owner.state.position)
		owner.state.position=owner.world.player_pos
	owner.current_screen="explore"
	owner.modal_autosave_on_close=false
	owner._close_modal()
	if close_after:
		Pause.save_and_leave(owner,owner.browser_mode)
	else:
		owner._autosave()
		owner.receipt_story.after_battle(result)

func _describe(action:String) -> void:
	if valid() and rules.active:
		var reason: String=rules.action_unavailable_reason(action)
		details.text=reason if not reason.is_empty() else rules.action_description(action)

func refresh() -> void:
	if not valid():return
	health.max_value=display.max_hp;health.value=display.hp
	hero_name.text=String(rules.hero_snapshot.player_name);hero_name.tooltip_text=hero_name.text
	health_text.text="气血 %d / %d"%[display.hp,display.max_hp]
	qi_text.text="气血 %d/%d · 真气 %d/%d\n回春散 %d包 · %s"%[display.hp,display.max_hp,display.qi,display.max_qi,display.medicine,"独行" if rules.companion.is_empty() else rules.companion+" / "+rules.formation]
	support_name.text=rules.companion;support_role.text="护后照应" if rules.formation=="护后" else "并肩协击"
	var move_number:int=maxi(1,rules.turn) if rules.locked or not rules.active else rules.turn+1
	turn_text.text="第 %d 招"%move_number
	var selected_unit:Dictionary={}
	for unit:Dictionary in display.units:
		var card:Dictionary=target_cards[unit.id]
		var selected:bool=rules.selected_id==unit.id
		if selected:selected_unit=unit
		card.title.text=String(unit.name)
		card.bar.max_value=unit.max_hp;card.bar.value=unit.hp
		card.value.text="%d / %d"%[unit.hp,unit.max_hp]
		var intent:Dictionary=unit.intent_data
		card.intent.text="已停手" if int(unit.hp)<=0 else ("援护" if intent.kind=="protect" else ("蓄斩" if int(intent.get("damage",0))>=30 else "将攻"))
		if int(unit.weaken_strikes)>0:card.intent.text="卸劲"
		card.button.tooltip_text="已停手" if int(unit.hp)<=0 else String(unit.intent)
		card.button.disabled=rules.locked or not rules.active or int(unit.hp)<=0
		for style in ["normal","hover","disabled"]:card.button.add_theme_stylebox_override(style,host._style(Color(.045,.105,.11,.8),Color("bfa86f") if selected else Color(0,0,0,0)))
	if close_pending:notice.text="收招后退开并保存 · 请稍候"
	elif rules.locked:
		notice.text="正在收招 · %s 气血%d/%d · 目标已锁定"%[String(selected_unit.get("name","")),int(selected_unit.get("hp",0)),int(selected_unit.get("max_hp",1))]
	elif not selected_unit.is_empty():notice.text=String(selected_unit.name)+" · "+String(selected_unit.intent)
	else:notice.text="点击对手或头顶牌签 · Tab切换目标"
	retreat_button.disabled=rules.locked or close_pending
	var names:Array[String]=["1  平击  +%d气"%mini(2,rules.max_qi-rules.qi),"2  %s  −%d气"%[rules.equipped_art,int(rules.skill_definition().cost)],"3  守势  +%d气"%mini(1,rules.max_qi-rules.qi),"4  回春散 ×%d"%int(display.medicine),"5  退开"]
	for i in action_buttons.size():
		var button:Button=action_buttons[i];button.text=names[i]
		button.disabled=rules.locked or close_pending or not rules.active or not rules.action_unavailable_reason(ACTIONS[i]).is_empty()
		button.tooltip_text=rules.action_unavailable_reason(ACTIONS[i]) if button.disabled else rules.action_description(ACTIONS[i])
	var end_index:int=rules.battle_log.size()-pending.logs.size() if rules.locked else rules.battle_log.size()
	log_text.text=String(rules.battle_log[end_index-1]) if end_index>0 else ""
	log_text.tooltip_text="\n".join(rules.battle_log.slice(maxi(0,end_index-6),end_index))
	if rules.locked or close_pending:details.text="已接受的招式仍会结算；退开不恢复已用药品或真气。"
	elif host.browser_mode:details.text="1–5出招 · Tab换目标 · Esc退开后存卷；刷新网页可能丢失未存进度。"
	else:details.text=rules.action_description("attack")
	_sync_actor_cards()
