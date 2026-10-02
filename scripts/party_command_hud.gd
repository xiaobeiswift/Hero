extends Control
## Views only real party snapshots and host-provided target/phase presentation.
## Never creates absent actors, inferred commands, rule effects or target choices.
signal actor_requested(actor_id:String)
signal command_requested(actor_id:String,action_id:String)
const FONT=preload("res://assets/fonts/NotoSansSC.otf")
const COMMAND_ATLAS=preload("res://assets/ui/martial_commands_painted_atlas.png")
const QIN_ATLAS=preload("res://assets/ui/qin_commands_painted_atlas.png")
const COMPANION_ATLAS=preload("res://assets/ui/companion_commands_painted_atlas.png")
const PORTRAITS={
	"hero":preload("res://assets/generated/characters/painted_hero_combat.png"),
	"shen":preload("res://assets/generated/characters/painted_shen_combat.png"),
	"tang":preload("res://assets/generated/characters/painted_tang_combat.png"),
	"qin":preload("res://assets/generated/characters/painted_qin_combat.png")
}
const CROP={"hero":Rect2(168,145,172,206),"shen":Rect2(121,70,180,212),"tang":Rect2(164,53,177,216),"qin":Rect2(186,18,164,210)}
const IVORY=Color("e8dbc1")
const GOLD=Color("d8ba7f")
const MUTED=Color("a7a995")
const INK=Color("171b19")
const CLUSTER_WIDTH=350.0
const MAX_ACTORS=4
const COMPACT_CLUSTER_WIDTH=299.0
const COMPACT_SLOT_SIZE=66.0
const CLUSTER_Y=632.0
var snapshot:Dictionary={}
var context:Dictionary={}
var buttons:Dictionary={}
var actor_buttons:Dictionary={}
var groups:Dictionary={}
var command_rects:Dictionary={}
var descriptors:Dictionary={}
var portraits:Dictionary={}
var icons:Dictionary={}
var hover_key:String=""
var focus_key:String=""
var journal_open:bool=false
var journal_button:Button
var journal_text:RichTextLabel
var _style_cache:Dictionary={}
var revision:int=0
var _signature:String=""

func _ready()->void:
	size=Vector2(1280,800);mouse_filter=Control.MOUSE_FILTER_IGNORE
	for id:String in PORTRAITS:
		var crop=AtlasTexture.new();crop.atlas=PORTRAITS[id];crop.region=CROP[id];crop.filter_clip=true;portraits[id]=crop
	for atlas_key:String in ["common","companion"]:
		var atlas:Texture2D=COMMAND_ATLAS if atlas_key=="common" else COMPANION_ATLAS
		for i in range(4):
			var tex=AtlasTexture.new();tex.atlas=atlas;tex.region=Rect2(Vector2(i%2,i/2)*atlas.get_size()*.5,atlas.get_size()*.5);tex.filter_clip=true
			icons[atlas_key+str(i)]=tex
	for i in range(2):
		var tex=AtlasTexture.new();tex.atlas=QIN_ATLAS;tex.region=Rect2(Vector2(i*QIN_ATLAS.get_width()*.5,0),Vector2(QIN_ATLAS.get_width()*.5,QIN_ATLAS.get_height()));tex.filter_clip=true;icons["qin"+str(i)]=tex
	journal_button=_button(Rect2(1135,744,118,48))
	journal_button.pressed.connect(_toggle_journal)
	journal_button.mouse_entered.connect(_hover.bind("journal"));journal_button.mouse_exited.connect(_hover.bind(""))
	journal_button.focus_entered.connect(_focus.bind("journal"));journal_button.focus_exited.connect(_focus.bind(""))
	journal_text=RichTextLabel.new();journal_text.position=Vector2(886,486);journal_text.size=Vector2(343,140)
	journal_text.add_theme_font_override("normal_font",FONT);journal_text.add_theme_font_size_override("normal_font_size",13)
	journal_text.add_theme_color_override("default_color",IVORY);journal_text.bbcode_enabled=false;journal_text.visible=false;add_child(journal_text)
	if not snapshot.is_empty():_sync_controls()
	queue_redraw()

func set_snapshot(value:Dictionary,view_context:Dictionary={})->void:
	if snapshot==value and context==view_context:return
	snapshot=value.duplicate(true);context=view_context.duplicate(true);revision+=1
	if is_inside_tree():_sync_controls()
	queue_redraw()

func _allies()->Array:return snapshot.get("actors",[])
func _actor(id:String)->Dictionary:
	for actor:Dictionary in _allies():
		if String(actor.get("id",""))==id:return actor
	return {}
func _slots(actor:Dictionary)->Array:
	var result:Array=[]
	for action:Dictionary in actor.get("actions",[]):
		if String(action.get("id","")) not in ["item","flee"]:result.append(action)
	return result
func _unit(id:String)->Dictionary:
	var ally=_actor(id)
	if not ally.is_empty():return ally
	for enemy:Dictionary in snapshot.get("enemies",[]):
		if String(enemy.get("id",""))==id:return enemy
	return {}
func _acting_id()->String:
	return String(context.get("acting_unit_id",snapshot.get("acting_unit_id","")))

func _action(actor:Dictionary,id:String)->Dictionary:
	for action:Dictionary in actor.get("actions",[]):
		if String(action.get("id",""))==id:return action
	return {}
func _key(actor_id:String,action_id:String)->String:return actor_id+"::"+action_id

func action_reason(actor_id:String,action_id:String)->String:
	var actor=_actor(actor_id);var action=_action(actor,action_id)
	if actor.is_empty() or action.is_empty():return "此招不可用"
	if not bool(snapshot.get("active",true)):return "交锋已结束"
	if bool(snapshot.get("locked",false)):return "交锋演绎中"
	if bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0:return "已倒下"
	if bool(actor.get("acted",false)):return "本回合已行动"
	if not bool(action.get("available",false)):
		var reason=String(action.get("reason",""))
		return reason if not reason.is_empty() else "此招不可用"
	return ""

func is_compact()->bool:return _allies().size()>3
func utility_geometry(action_id:String)->Rect2:
	if action_id=="flee":return Rect2(1120,25,130,50)
	if is_compact():return Rect2(819,25,166,50) if action_id=="item" else Rect2(999,25,105,50)
	return Rect2(1135,651,118,82) if action_id=="item" else Rect2(1135,744,118,48)

func _sync_controls()->void:
	groups.clear();command_rects.clear();descriptors.clear()
	var actors:Array=_allies()
	var compact:bool=is_compact()
	var cluster_width:float=COMPACT_CLUSTER_WIDTH if compact else CLUSTER_WIDTH
	var total:float=actors.size()*cluster_width+maxi(0,actors.size()-1)*12
	var x:float=22 if compact else maxf(22,(1120-total)*.5)
	journal_button.position=utility_geometry("journal").position
	journal_button.size=utility_geometry("journal").size
	var signature_parts:Array[String]=[]
	for actor:Dictionary in actors:
		var id=String(actor.get("id",""));if id.is_empty():continue
		groups[id]=Rect2(x,CLUSTER_Y,cluster_width,160)
		var actions:Array=_slots(actor)
		# Current core provides3 true illustrated commands. More are not silently
		# invented; later expansion needs a deliberate paging contract.
		for i in range(actions.size()):
			var action:Dictionary=actions[i];var action_id=String(action.get("id",""))
			var key=_key(id,action_id)
			command_rects[key]=Rect2(x+74+i*73,666,COMPACT_SLOT_SIZE,100) if compact else Rect2(x+84+i*85,661,76,104)
			descriptors[key]=action
			signature_parts.append(key)
		x+=cluster_width+12
	var active=String(snapshot.get("active_actor_id",""))
	var active_actor=_actor(active)
	for utility in ["item","flee"]:
		var action=_action(active_actor,utility)
		if not action.is_empty():
			var key=_key(active,utility)
			command_rects[key]=utility_geometry(utility)
			descriptors[key]=action;signature_parts.append(key)
	var signature="|".join(signature_parts)+str(groups)
	if signature!=_signature:
		var keep_focus:String=focus_key
		for button:Button in buttons.values():remove_child(button);button.queue_free()
		for button:Button in actor_buttons.values():remove_child(button);button.queue_free()
		buttons.clear();actor_buttons.clear()
		for id:String in groups:
			var r:Rect2=groups[id]
			var pick=_button(Rect2(r.position+Vector2(8,6),Vector2(58 if compact else 67,147)))
			pick.pressed.connect(_request_actor.bind(id))
			pick.mouse_entered.connect(_hover.bind("actor::"+id));pick.mouse_exited.connect(_hover.bind(""))
			pick.focus_entered.connect(_focus.bind("actor::"+id));pick.focus_exited.connect(_focus.bind(""))
			actor_buttons[id]=pick
		for key:String in command_rects:
			var button=_button(command_rects[key]);button.name=key.replace(":","_")
			button.pressed.connect(_request_command.bind(key))
			button.mouse_entered.connect(_hover.bind(key));button.mouse_exited.connect(_hover.bind(""))
			button.focus_entered.connect(_focus.bind(key));button.focus_exited.connect(_focus.bind(""))
			buttons[key]=button
		_signature=signature
		if buttons.has(keep_focus):buttons[keep_focus].grab_focus()
		elif keep_focus.begins_with("actor::") and actor_buttons.has(keep_focus.trim_prefix("actor::")):actor_buttons[keep_focus.trim_prefix("actor::")].grab_focus()
	for key:String in buttons:
		var pair=key.split("::")
		buttons[key].mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if action_reason(pair[0],pair[1]).is_empty() else Control.CURSOR_ARROW
	var logs=snapshot.get("log",[])
	journal_text.text="\n".join(logs) if logs is Array else String(logs)
	_sync_journal()

func _button(rect:Rect2)->Button:
	var button=Button.new();button.position=rect.position;button.size=rect.size;button.flat=true;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_child(button);return button
func focus_actor_commands(actor_id:String)->bool:
	for action:Dictionary in _slots(_actor(actor_id)):
		var key=_key(actor_id,String(action.id))
		if buttons.has(key):buttons[key].grab_focus();return true
	return false
func focus_actor_selector(actor_id:String)->bool:
	if not actor_buttons.has(actor_id):return false
	actor_buttons[actor_id].grab_focus();return true

func _request_actor(id:String)->void:
	var actor=_actor(id)
	if actor.is_empty() or not bool(snapshot.get("active",true)) or bool(snapshot.get("locked",false)) or bool(actor.get("acted",false)) or bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0:return
	actor_requested.emit(id)
func _request_command(key:String)->void:
	if not descriptors.has(key):return
	var pair=key.split("::")
	if not action_reason(pair[0],pair[1]).is_empty():return
	command_requested.emit(pair[0],pair[1])
func _hover(key:String)->void:hover_key=key;_sync_journal();queue_redraw()
func _focus(key:String)->void:focus_key=key;_sync_journal();queue_redraw()
func _toggle_journal()->void:journal_open=not journal_open;_sync_journal();queue_redraw()
func _sync_journal()->void:
	if journal_text!=null:journal_text.visible=journal_open or hover_key=="journal" or focus_key=="journal"

func _draw()->void:
	if snapshot.is_empty():return
	_gradient(Rect2(0,0,1280,140),Color(.015,.02,.025,.82),Color(.015,.02,.025,0))
	_gradient(Rect2(0,582,1280,218),Color(.015,.02,.025,0),Color(.01,.018,.02,.98))
	_text(String(context.get("location","")),Vector2(35,34),12,MUTED)
	_ink_text(String(context.get("title","交锋")),Vector2(35,65),24,IVORY)
	_header()
	for actor:Dictionary in _allies():
		var id=String(actor.get("id",""))
		if groups.has(id):_cluster(actor,groups[id])
	_utilities()
	var focused:String=hover_key if not hover_key.is_empty() else focus_key
	if descriptors.has(focused):_tooltip(focused)
	if journal_open or focused=="journal":
		_frame(Rect2(868,441,380,204),INK,true);_ink_text("战报",Vector2(886,472),18,IVORY)
		_text("点击固定 · 可滚动",Vector2(1230,471),11,MUTED,false,true)
	var notice=String(context.get("target_prompt",context.get("notice","")))
	if not notice.is_empty():
		var area=notice_geometry(notice)
		_frame(area,Color(.09,.085,.07,.96),false)
		draw_multiline_string(FONT,area.position+Vector2(18,25),notice,HORIZONTAL_ALIGNMENT_LEFT,area.size.x-36,14,-1,GOLD)

func notice_geometry(message:String)->Rect2:
	var width=minf(380,FONT.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+36)
	var height=FONT.get_multiline_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,width-36,14,-1).y+26
	return Rect2(1254-width,103,width,height)

func _header()->void:
	var rect=Rect2(487,20,306,65);_frame(rect,Color("211f1a"),false)
	_ink_text("回合",Vector2(506,52),18,Color("c6b993"))
	_ink_text("%02d"%int(snapshot.get("round",1)),Vector2(566,57),31,GOLD)
	var label=String(context.get("phase_label",""))
	if label.is_empty():
		var phase=String(snapshot.get("phase",""))
		label={"ally":"我方行动","allies":"我方行动","player":"我方行动","enemy":"敌方行动","enemies":"敌方行动","resolve":"收招结算","finished":"交锋结束","ended":"交锋结束"}.get(phase,"交锋")
	_ink_text(label,Vector2(624,49),16,IVORY)
	var current=_unit(_acting_id()) if bool(snapshot.get("locked",false)) else _actor(String(snapshot.get("active_actor_id","")))
	var second=String(current.get("name","")) if not current.is_empty() else ""
	_text(second,Vector2(624,69),12,GOLD)

func _cluster(actor:Dictionary,rect:Rect2)->void:
	var id=String(actor.id)
	var active:bool=id==String(snapshot.get("active_actor_id","")) and not bool(snapshot.get("locked",false))
	var acting:bool=bool(snapshot.get("locked",false)) and id==_acting_id()
	var dead:bool=bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0
	var done:bool=bool(actor.get("acted",false))
	if active or acting:_box(rect.grow(3),Color(.4,.28,.10,.14),Color(.87,.7,.38,.58),1)
	_frame(rect,Color(.085,.08,.065,.88),active or acting or hover_key=="actor::"+id or focus_key=="actor::"+id)
	_ink_text(String(actor.get("name","")),rect.position+Vector2(13,25),15,IVORY if not dead else MUTED)
	var badge="倒下" if dead else ("出招中" if acting else ("已行动" if done else ("当前" if active else "待行动")))
	_text(badge,rect.position+Vector2(rect.size.x-19,20),11,Color("dcb974") if active or acting else MUTED,false,true)
	if portraits.has(id):draw_texture_rect(portraits[id],Rect2(rect.position+Vector2(11,34),Vector2(54,77)),false,Color(.5,.5,.5) if dead else Color.WHITE)
	var barrier=int(actor.get("status",{}).get("barrier",0))
	var vulnerability=int(actor.get("status",{}).get("vulnerability_hits",0))
	if barrier>0:
		_box(Rect2(rect.position+Vector2(11,99),Vector2(54,17)),Color("102c2d"),Color("9eac7c"),1)
		_ink_text("护%d"%barrier,rect.position+Vector2(38,112),11,Color("dceabb"),true)
	if vulnerability>0:
		var badge_y=82 if barrier>0 else 99
		_box(Rect2(rect.position+Vector2(11,badge_y),Vector2(54,17)),Color("3b2320"),Color("bc8568"),1)
		_ink_text("破绽%d"%vulnerability,rect.position+Vector2(38,badge_y+13),11,Color("f0b798"),true)
	var maximum=maxi(1,int(actor.get("max_hp",1)));var hp=maxi(0,int(actor.get("hp",0)))
	var bar=Rect2(rect.position+Vector2(11,118),Vector2(54,5))
	draw_rect(bar.grow(1),Color("595345"));draw_rect(bar,Color("311b19"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*float(hp)/maximum,bar.size.y)),Color("bd4b38"))
	_text("%d/%d"%[hp,maximum],rect.position+Vector2(38,141),11,Color("cfbfa5"),true)
	for action:Dictionary in _slots(actor):_slot(actor,action)
	_qi(actor,rect.position+Vector2(74 if is_compact() else 84,142),rect.size.x-(74 if is_compact() else 84)-19)

func _slot(actor:Dictionary,action:Dictionary)->void:
	var key=_key(String(actor.id),String(action.id))
	var area:Rect2=command_rects[key]
	var rect=Rect2(area.position,Vector2.ONE*area.size.x)
	var reason=action_reason(String(actor.id),String(action.id))
	var available=reason.is_empty()
	var focus=key==hover_key or key==focus_key
	var selected=String(context.get("selected_actor_id",""))==String(actor.id) and String(context.get("selected_action_id",""))==String(action.id)
	_frame(rect,Color("181b1d"),focus or selected)
	var texture=_icon_for(String(actor.id),action)
	if texture!=null:draw_texture_rect(texture,rect.grow(-5),false,Color.WHITE if available else Color(.62,.62,.62))
	draw_rect(rect.grow(-4),Color(0,0,0,.8),false,1.5)
	if String(actor.id)==String(snapshot.get("active_actor_id","")):
		var shortcut=_shortcut(action)
		if not shortcut.is_empty():
			_box(Rect2(rect.position+Vector2(4,4),Vector2(17,17)),Color(.03,.03,.025,.94),Color("a58f63"),1)
			_ink_text(shortcut,rect.position+Vector2(12.5,17),11,IVORY,true)
	if int(action.get("cost",0))>0:
		_box(Rect2(rect.end.x-31,rect.position.y+4,27,18),Color("44251a"),Color("a68d52"),1)
		_ink_text("%d气"%int(action.cost),Vector2(rect.end.x-17.5,rect.position.y+17),10,Color("edcb8c"),true)
	if not available:
		if bool(actor.get("acted",false)) or bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0 or bool(snapshot.get("locked",false)):
			draw_rect(rect.grow(-5),Color(0,0,0,.42))
			_ink_text("倒下" if bool(actor.get("incapacitated",false)) or int(actor.get("hp",0))<=0 else ("已行动" if bool(actor.get("acted",false)) else "交锋中"),rect.get_center()+Vector2(0,6),13,IVORY,true)
		elif int(action.get("cooldown_remaining",0))>0:
			draw_rect(rect.grow(-5),Color(.015,.02,.03,.55))
			_ink_text(str(action.cooldown_remaining),rect.get_center()+Vector2(0,8),27,IVORY,true)
			_ink_text("调息",Vector2(rect.get_center().x,rect.end.y-9),9,IVORY,true)
		else:
			draw_rect(Rect2(rect.position+Vector2(5,rect.size.y-23),Vector2(rect.size.x-10,18)),Color(.12,.06,.02,.93))
			_ink_text("真气不足" if reason.contains("真气") else ("无可治疗目标" if reason.contains("治疗") and reason.contains("目标") else ("无目标" if reason.contains("目标") else "不可用")),Vector2(rect.get_center().x,rect.end.y-10),10,Color("d5aa7b"),true)
	var name=String(action.get("name",""))
	var name_size=13
	while name_size>10 and FONT.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x>rect.size.x+4:name_size-=1
	_ink_text(name,Vector2(rect.get_center().x,rect.end.y+20),name_size,IVORY if available else MUTED,true)

func _qi(actor:Dictionary,at:Vector2,available_width:float)->void:
	var maximum=maxi(1,int(actor.get("max_qi",1)));var qi=int(actor.get("qi",0))
	var width=available_width-45;var segment=(width-4*(maximum-1))/maximum
	for i in range(maximum):
		var rect=Rect2(at+Vector2(i*(segment+4),0),Vector2(segment,8))
		_box(rect.grow(1),Color("0a1013"),Color("625b48"),1)
		if i<qi:_gradient(rect,Color("82edf2"),Color("15698e"))
		else:draw_rect(rect,Color("12212b"))
	_text("%d/%d"%[qi,maximum],at+Vector2(available_width,9),11,Color("acd0d4"),false,true)

func _utilities()->void:
	var actor_id=String(snapshot.get("active_actor_id",""));var actor=_actor(actor_id)
	var item=_action(actor,"item");var flee=_action(actor,"flee")
	if not item.is_empty():
		var key=_key(actor_id,"item");var r=utility_geometry("item")
		var available=action_reason(actor_id,"item").is_empty()
		var item_color=IVORY if available else Color("7f8277")
		var item_caption=utility_caption(actor_id,"item")
		_frame(r,Color(.09,.09,.075,.92),key==hover_key or key==focus_key)
		if is_compact():
			draw_texture_rect(icons.common3,Rect2(r.position+Vector2(5,5),Vector2(40,40)),false,Color.WHITE if available else Color(.28,.28,.28))
			_ink_text("4" if available else "×",r.position+Vector2(10,18),10,item_color)
			_ink_text("×%d"%int(snapshot.get("medicine",0)),r.position+Vector2(150,21),16,item_color,true)
			_text(String(item.get("name","回春散")),r.position+Vector2(52,21),13,item_color)
			_text(item_caption,r.position+Vector2(52,40),11,MUTED)
		else:
			draw_texture_rect(icons.common3,Rect2(r.position+Vector2(7,6),Vector2(50,50)),false,Color.WHITE if available else Color(.28,.28,.28))
			_ink_text("4" if available else "×",r.position+Vector2(15,19),10,item_color)
			_ink_text("×%d"%int(snapshot.get("medicine",0)),r.position+Vector2(83,31),17,item_color,true)
			_text(item_caption,r.position+Vector2(83,53),10,MUTED,true)
			_text(String(item.get("name","回春散")),r.position+Vector2(59,70),12,item_color,true)
	if not flee.is_empty():
		var key=_key(actor_id,"flee");var r=utility_geometry("flee")
		_frame(r,Color(.09,.09,.08,.87),key==hover_key or key==focus_key)
		var enabled=action_reason(actor_id,"flee").is_empty()
		_ink_text("5  退开" if enabled else "收招中",r.get_center()+Vector2(0,7),16,IVORY if enabled else Color("7f8277"),true)
	var journal=utility_geometry("journal")
	_frame(journal,Color(.09,.09,.08,.9),journal_open or hover_key=="journal" or focus_key=="journal")
	_ink_text("战报",journal.get_center()+Vector2(0,7),15,IVORY,true)

func utility_caption(actor_id:String,action_id:String)->String:
	var reason=action_reason(actor_id,action_id)
	if reason.is_empty():return String(_actor(actor_id).get("name",""))+"自用"
	if bool(snapshot.get("locked",false)):return "交锋中 · 暂不可用"
	if reason.contains("已行动"):return "本回合已行动"
	if reason.contains("气血"):return "气血充盈"
	if reason.contains("回春散"):return "药品不足"
	return reason

func _icon_for(actor_id:String,action:Dictionary)->Texture2D:
	var id=String(action.get("id",""))
	if id=="guard":return icons.common2
	if id=="item":return icons.common3
	if actor_id=="shen":return icons.companion0 if id=="attack" else icons.companion1
	if actor_id=="tang":return icons.companion2 if id=="attack" else icons.companion3
	if actor_id=="qin":return icons.qin0 if id=="attack" else icons.qin1
	return icons.common0 if id=="attack" else icons.common1
func _shortcut(action:Dictionary)->String:
	var id=String(action.get("id",""))
	if id=="attack":return "1"
	if id.begins_with("art:"):return "2"
	if id=="guard":return "3"
	return ""

func _tooltip(key:String)->void:
	var action:Dictionary=descriptors[key];var pair=key.split("::")
	var description=String(action.get("description",""))
	var effect_height:float=FONT.get_multiline_string_size(description,HORIZONTAL_ALIGNMENT_LEFT,320,13,-1).y
	var reason=action_reason(pair[0],pair[1]);var height=87+effect_height+(24 if not reason.is_empty() else 0)
	var anchor:Rect2=command_rects[key]
	var origin=Vector2(clampf(anchor.get_center().x-178,24,900),96 if anchor.position.y<100 else 620-height)
	_frame(Rect2(origin,Vector2(356,height)),INK,true)
	_ink_text(String(action.get("name","")),origin+Vector2(17,29),18,IVORY)
	draw_multiline_string(FONT,origin+Vector2(17,55),description,HORIZONTAL_ALIGNMENT_LEFT,320,13,-1,Color("d6d4bf"))
	var team=String(action.get("target_team",""))
	var target_label={"enemy":"敌方目标","ally":"我方目标","self":"自身","none":"无需目标"}.get(team,team)
	_text(target_label,origin+Vector2(17,71+effect_height),12,MUTED)
	if not reason.is_empty():_text(reason,origin+Vector2(17,95+effect_height),12,Color("dfa275"))

func _frame(rect:Rect2,fill:Color,highlight:bool)->void:
	var light=Color("ecd194") if highlight else Color("8f7d5d")
	_box(rect.grow(2),Color(0,0,0,.6),Color("070a0b"),1);_box(rect,fill,Color("4f483a"),1)
	draw_line(rect.position+Vector2(2,2),Vector2(rect.end.x-2,rect.position.y+2),light,1.7,true)
	draw_line(rect.position+Vector2(2,2),Vector2(rect.position.x+2,rect.end.y-2),Color(light,.6),1.6,true)
	draw_line(Vector2(rect.position.x+2,rect.end.y-2),rect.end-Vector2(2,2),Color("332b21"),2.5,true)
	draw_line(Vector2(rect.end.x-2,rect.position.y+2),rect.end-Vector2(2,2),Color("332b21"),2.5,true)
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var dir=Vector2(1 if corner.x==rect.position.x else -1,1 if corner.y==rect.position.y else -1)
		draw_polyline(PackedVector2Array([corner+Vector2(0,9*dir.y),corner,corner+Vector2(9*dir.x,0)]),light,1.8,true)
func _box(rect:Rect2,color:Color,border:Color,radius:int)->void:
	var key=color.to_html()+border.to_html()+str(radius)
	if not _style_cache.has(key):
		var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(1);style.set_corner_radius_all(radius);_style_cache[key]=style
	draw_style_box(_style_cache[key],rect)
func _gradient(rect:Rect2,top:Color,bottom:Color)->void:
	draw_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),PackedColorArray([top,top,bottom,bottom]))
func _text(value:String,at:Vector2,font_size:int,color:Color,center:bool=false,right:bool=false)->void:
	var width=FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	if center:at.x-=width*.5
	elif right:at.x-=width
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _ink_text(value:String,at:Vector2,font_size:int,color:Color,center:bool=false)->void:
	if center:at.x-=FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(.015,.015,.01,.96))
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
