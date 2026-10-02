extends Control
## Real finite encounter. HeroState commits costs; this controller only presents
## accepted facts and exits through the normal save-failure gate.
const Arena = preload("res://scripts/heting_receipt_art.gd")
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color("102827"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	art = Arena.new(); art.position = Vector2(0,175); art.size = Vector2(938,355); art.scale = Vector2.ONE * (1280.0 / 938.0)
	add_child(art)
	art.target_requested.connect(select_target)
	art.impact_presented.connect(_impact)
	art.presentation_finished.connect(_finished)
	host._label(self,"复 签 不 撤",Rect2(38,20,500,40),27,host.GOLD)
	host._label(self,"鹤汀公秤外栈桥  /  看清援护与来招",Rect2(40,62,590,28),15,host.MUTED)
	retreat_button=host._button(self,"Esc  退开",Rect2(1080,22,160,40),leave)
	host._label(self,"真实气血与用药 · 退开保留已消耗资源",Rect2(555,29,495,28),14,host.PAPER)
	health_text = host._label(self,"",Rect2(40,102,360,30),20,host.PAPER)
	health = host._bar(self,Rect2(40,142,320,10),host.JADE)
	qi_text = host._label(self,"",Rect2(40,161,470,28),15,host.GOLD)
	turn_text = host._label(self,"",Rect2(40,192,490,29),14,host.MUTED)
	for i in range(2):
		var id: String = ["striker","bracer"][i]
		var card = host._button(self,"",Rect2(710+i*270,93,258,130),select_target.bind(id))
		var title = host._label(card,"",Rect2(15,9,230,27),18,host.PAPER)
		var bar = host._bar(card,Rect2(15,43,228,7),Color("bb9274"))
		var value = host._label(card,"",Rect2(15,56,228,21),13,host.PAPER)
		var intent = host._label(card,"",Rect2(15,80,230,42),13,host.GOLD)
		for child in card.get_children():
			if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_cards[id] = {"button":card,"title":title,"bar":bar,"value":value,"intent":intent}
	notice = host._label(self,"",Rect2(355,232,610,36),18,host.GOLD)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._panel(self,Rect2(37,601,1206,83),Color(.035,.105,.105,.96),Color("537367"))
	log_text = RichTextLabel.new(); log_text.position=Vector2(54,611); log_text.size=Vector2(1168,60)
	log_text.add_theme_font_size_override("normal_font_size",15); log_text.scroll_following=true
	log_text.mouse_filter=Control.MOUSE_FILTER_PASS; add_child(log_text)
	for i in range(5):
		var button: Button = host._button(self,"",Rect2(38+i*244,702,230,52),submit.bind(ACTIONS[i]))
		button.add_theme_font_size_override("font_size",17)
		button.add_theme_stylebox_override("normal",host._style(Color("1a403a"),Color("8d855e")))
		button.add_theme_stylebox_override("hover",host._style(Color("2b5a4e"),host.GOLD))
		button.add_theme_stylebox_override("disabled",host._style(Color("1c2e2b"),Color("3d4b40")))
		button.add_theme_color_override("font_disabled_color",Color("849184"))
		button.mouse_entered.connect(_describe.bind(ACTIONS[i]))
		action_buttons.append(button)
	details=host._label(self,"",Rect2(42,760,1194,31),13,host.MUTED)
	display=rules.snapshot(); art.set_snapshot(display)
	refresh()

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
	health.max_value=display.max_hp; health.value=display.hp
	health_text.text="%s  ·  气血  %d / %d" % [rules.hero_snapshot.player_name,display.hp,display.max_hp]
	qi_text.text="真气 %d / %d  ·  回春散 %d包  ·  %s" % [display.qi,display.max_qi,display.medicine,rules.equipped_art]
	var move_number: int=maxi(1,rules.turn) if rules.locked or not rules.active else rules.turn+1
	turn_text.text="第%d招  ·  %s" % [move_number,"独行" if rules.companion.is_empty() else rules.companion+" / "+rules.formation]
	for unit: Dictionary in display.units:
		var card: Dictionary=target_cards[unit.id]
		var selected: bool=rules.selected_id==unit.id
		card.title.text=("◇  " if selected else "")+String(unit.name)
		card.bar.max_value=unit.max_hp; card.bar.value=unit.hp
		card.value.text="气血 %d / %d%s" % [unit.hp,unit.max_hp,"  ·  卸劲" if int(unit.weaken_strikes)>0 else ""]
		card.button.tooltip_text="已停手" if int(unit.hp)<=0 else String(unit.intent)
		var intent: Dictionary=unit.intent_data
		card.intent.text="已停手" if int(unit.hp)<=0 else ("护住刀客 · 来伤减半\n向上取整，本轮不攻击" if intent.kind=="protect" else ("%s · 基础%d\n再扣防御与卸劲" % [intent.name,int(intent.damage)] if intent.kind=="attack" else "已停手"))
		card.button.disabled=rules.locked or not rules.active or int(unit.hp)<=0
		var border: Color=host.GOLD if selected else Color("527364")
		for style in ["normal","hover","disabled"]:card.button.add_theme_stylebox_override(style,host._style(Color("263f33") if selected else Color("172e2a"),border))
	if close_pending:
		notice.text="收招后退开并保存 · 请稍候"
	elif rules.locked:
		notice.text="正在收招 · 目标已锁定"
	else:
		notice.text="点击对手或上方牌签 · Tab 切换目标"
	retreat_button.disabled=rules.locked or close_pending
	var names:Array[String]=["1  平击  +%d气" % mini(2,rules.max_qi-rules.qi),"2  %s  −%d气" % [rules.equipped_art,int(rules.skill_definition().cost)],"3  守势  +%d气" % mini(1,rules.max_qi-rules.qi),"4  回春散  ×%d" % int(display.medicine),"5  退开"]
	for i in action_buttons.size():
		var button:Button=action_buttons[i]
		button.text=names[i]
		button.disabled=rules.locked or close_pending or not rules.active or not rules.action_unavailable_reason(ACTIONS[i]).is_empty()
		button.tooltip_text=rules.action_unavailable_reason(ACTIONS[i]) if button.disabled else rules.action_description(ACTIONS[i])
	log_text.text="\n".join(rules.battle_log.slice(maxi(0,rules.battle_log.size()-3))) if not rules.locked else "\n".join(rules.battle_log.slice(maxi(0,rules.battle_log.size()-pending.logs.size()-2),maxi(0,rules.battle_log.size()-pending.logs.size())))
	if rules.locked or close_pending:
		details.text="已接受的招式仍会结算；退开不恢复已用药品或真气。"
	elif host.browser_mode:
		details.text="1–5 出招 · Tab 换目标 · Esc 退开后存卷；直接刷新网页可能丢失未存进度。"
	else:
		details.text=rules.action_description("attack")
