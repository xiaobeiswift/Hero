extends RefCounted
## Compact presentation for the original Pu Heng encounter. Existing command
## buttons, health tweens, rules and result callbacks remain owned by main.
const IVORY=Color("f1e6ca")
const GOLD=Color("dfbd7a")
const SOFT=Color("b4c4b6")
var host
var root:Control
var active:bool=false
var hero_card:Control
var enemy_card:Control
var support_card:Control
var hero_bar:ProgressBar
var enemy_bar:ProgressBar
var hero_value:Label
var enemy_value:Label
var hero_title:Label
var enemy_title:Label
var support_title:Label
var support_role:Label
var title:Label
var round_text:Label
var status:Label
var resources:Label
var brief_log:Label
var prior_visible:Dictionary={}
var prior_buttons:Array=[]
var prior_scale:Vector2=Vector2.ONE
var prior_size:Vector2=Vector2.ZERO
var round_number:int=1

func build(game)->void:
	host=game
	root=Control.new();root.name="OpeningDuelHUD";root.size=Vector2(1280,800);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.battle_layer.add_child(root)
	_panel(root,Rect2(0,0,1280,65),Color("102a2a"))
	_panel(root,Rect2(0,635,1280,165),Color("102a2a"))
	title=_text(root,"",Rect2(26,14,850,35),22,GOLD)
	round_text=_text(root,"",Rect2(1035,18,218,28),17,IVORY);round_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hero_card=_panel(root,Rect2(0,0,160,65),Color(0.025,.08,.07,.90))
	enemy_card=_panel(root,Rect2(0,0,160,65),Color(0.025,.08,.07,.90))
	support_card=_panel(root,Rect2(0,0,160,47),Color(0.025,.08,.07,.90))
	hero_title=_text(hero_card,"",Rect2(6,2,148,23),16,IVORY)
	enemy_title=_text(enemy_card,"蒲横",Rect2(6,2,148,23),16,IVORY)
	enemy_title.mouse_filter=Control.MOUSE_FILTER_PASS
	hero_bar=_bar(hero_card,Color("72af98"));enemy_bar=_bar(enemy_card,Color("bd7b62"))
	hero_value=_text(hero_card,"",Rect2(6,34,148,23),12,IVORY)
	enemy_value=_text(enemy_card,"",Rect2(6,34,148,23),12,IVORY)
	support_title=_text(support_card,"",Rect2(6,0,148,23),16,IVORY)
	support_role=_text(support_card,"",Rect2(6,23,148,20),12,SOFT)
	status=_text(root,"",Rect2(26,640,1228,31),16,GOLD)
	resources=_text(root,"",Rect2(26,683,238,80),15,IVORY)
	brief_log=_text(root,"",Rect2(280,744,974,28),14,SOFT);brief_log.clip_text=true
	brief_log.mouse_filter=Control.MOUSE_FILTER_PASS
	for label in [hero_title,enemy_title,support_title,support_role]:label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	root.visible=false

func tick()->void:
	var wanted:bool=host.current_screen=="battle" and host.battle_art.uses_formation()
	if wanted!=active:_set_active(wanted)
	if not active:return
	var shown:Dictionary=host.battle_art.display_snapshot
	if not host.battle_busy:round_number=host.state.turn+1
	_write_text(title,host.battle_title.text.replace(" ",""))
	_write_text(round_text,"第 %d 回合"%round_number)
	_write_text(hero_title,host.state.player_name)
	hero_bar.max_value=host.battle_player_hp.max_value;hero_bar.value=host.battle_player_hp.value
	enemy_bar.max_value=host.battle_hp.max_value;enemy_bar.value=host.battle_hp.value
	_write_text(hero_value,"气血  %d / %d"%[roundi(hero_bar.value),roundi(hero_bar.max_value)])
	_write_text(enemy_value,"气血  %d / %d"%[roundi(enemy_bar.value),roundi(enemy_bar.max_value)])
	enemy_title.tooltip_text=host.state.enemy_name
	var companion:String=String(shown.get("companion",""))
	_write_text(support_title,companion)
	_write_text(support_role,("护后照应" if shown.get("formation","")=="护后" else "并肩协击")+" · 援手")
	_write_text(resources,"气血 %d/%d   真气 %d/%d\n回春散 ×%d · %s"%[roundi(hero_bar.value),roundi(hero_bar.max_value),int(shown.get("qi",host.state.qi)),host.state.max_qi,int(shown.get("medicine",host.state.medicine)),"独行" if companion.is_empty() else String(shown.get("formation",""))])
	if host.battle_busy:
		_write_text(status,"交锋中 · 本招结束后可再择招")
	else:
		var extra:String=host.battle_status.text
		var intent:String=host.state.enemy_intent
		if host.state.exposed_turns>0:intent+=" · 破绽%d（守势可解）"%host.state.exposed_turns
		_write_text(status,"蒲横 · "+intent+("    |    "+extra if not extra.is_empty() else ""))
	var lines:PackedStringArray=host.battle_log.text.split("\n",false)
	_write_text(brief_log,lines[-1] if not lines.is_empty() else "1—5 择招 · 对手蓄力时可用守势")
	brief_log.tooltip_text=host.battle_log.text
	for pair in [[hero_card,"hero"],[enemy_card,"enemy"],[support_card,"support"]]:
		var card:Control=pair[0]
		card.position=host.battle_art.unit_label_rect(pair[1]).position
		card.modulate.a=host.battle_art.unit_label_alpha(pair[1])
		card.visible=pair[1]!="support" or not companion.is_empty()

func _set_active(value:bool)->void:
	active=value
	root.visible=value
	if value:
		prior_visible.clear();prior_buttons.clear();prior_scale=host.battle_art.scale;prior_size=host.battle_art.size
		for child in host.battle_layer.get_children():
			if child==root or child==host.battle_art or (child is Button and child in host.battle_buttons):continue
			if child is CanvasItem:prior_visible[child]=child.visible;child.visible=false
		for i in range(host.battle_buttons.size()):
			var button:Button=host.battle_buttons[i]
			prior_buttons.append({"position":button.position,"size":button.size})
			button.position=Vector2(280+i*190,686);button.size=Vector2(178,53)
			host.battle_layer.move_child(button,host.battle_layer.get_child_count()-1)
		host.battle_art.scale=Vector2.ONE
		host.battle_art.size=Vector2(1280,685)
	else:
		for child in prior_visible:
			if is_instance_valid(child):child.visible=prior_visible[child]
		for i in range(prior_buttons.size()):
			host.battle_buttons[i].position=prior_buttons[i].position
			host.battle_buttons[i].size=prior_buttons[i].size
		host.battle_art.scale=prior_scale
		host.battle_art.size=prior_size
		prior_visible.clear();prior_buttons.clear()

func _write_text(label:Label,value:String)->void:
	if label.text!=value:label.text=value

func _text(parent:Node,value:String,rect:Rect2,font_size:int,color:Color)->Label:
	var label:Label=host._label(parent,value,rect,font_size,color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	return label

func _panel(parent:Node,rect:Rect2,color:Color)->Panel:
	var panel:=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=color;style.border_color=Color("807556");style.border_width_bottom=1
	panel.add_theme_stylebox_override("panel",style);parent.add_child(panel);return panel

func _bar(parent:Node,color:Color)->ProgressBar:
	var bar:=ProgressBar.new();bar.position=Vector2(6,28);bar.size=Vector2(148,5);bar.show_percentage=false;bar.step=.01;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_theme_font_size_override("font_size",1)
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("253a38")
	var fill:=StyleBoxFlat.new();fill.bg_color=color
	bar.add_theme_stylebox_override("background",bg);bar.add_theme_stylebox_override("fill",fill);parent.add_child(bar);bar.size=Vector2(148,5);return bar
