extends RefCounted
## Original cloth-and-paper inventory; rules and transactions remain in HeroState.
const HeroArt=preload("res://scripts/painted_traveler_sprite.gd")
const Items=preload("res://scripts/item_catalog.gd")
const INK=Color("263e39")
const MUTED=Color("687668")
const GOLD=Color("b3975c")
const PAPER=Color("e5dfc6")
class PaperSurface extends Control:
	func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw()->void:
		draw_rect(Rect2(Vector2.ZERO,size),PAPER)
		for i in range(190):
			var x=fmod(i*71.31+13,size.x);var y=fmod(i*43.71+9,size.y)
			draw_line(Vector2(x,y),Vector2(x+2+fmod(i,4),y),Color(.35,.38,.24,.045),1)
		draw_line(Vector2(291,18),Vector2(291,size.y-18),Color(.43,.45,.32,.30),1)
		draw_line(Vector2(294,20),Vector2(294,size.y-20),Color(1,.98,.87,.50),1)
class ItemGlyph extends Control:
	var kind="sword"
	func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw()->void:
		var c=Color("526c5c")
		match kind:
			"sword":
				draw_colored_polygon(PackedVector2Array([Vector2(17,38),Vector2(38,5),Vector2(43,2),Vector2(42,9),Vector2(22,42)]),Color("a6b7ad"))
				draw_line(Vector2(12,33),Vector2(27,44),c,3,true);draw_line(Vector2(18,40),Vector2(10,51),Color("816645"),5,true)
			"armor":
				draw_colored_polygon(PackedVector2Array([Vector2(15,7),Vector2(22,13),Vector2(29,7),Vector2(42,16),Vector2(36,29),Vector2(31,25),Vector2(33,49),Vector2(11,49),Vector2(13,25),Vector2(7,29),Vector2(2,16)]),Color("7c927d"))
				draw_polyline(PackedVector2Array([Vector2(16,9),Vector2(27,25),Vector2(17,48)]),Color("d9d0ac"),2,true)
				draw_line(Vector2(12,31),Vector2(31,31),Color("725f43"),3,true)
			"medicine":
				draw_colored_polygon(PackedVector2Array([Vector2(10,12),Vector2(33,12),Vector2(40,44),Vector2(34,51),Vector2(8,49),Vector2(3,41)]),Color("a9956c"))
				draw_line(Vector2(9,15),Vector2(34,15),c,3,true);draw_circle(Vector2(22,33),10,Color("dcd4ae"));draw_line(Vector2(22,25),Vector2(22,41),c,2);draw_line(Vector2(15,33),Vector2(29,33),c,2)
			"herb":
				draw_line(Vector2(20,50),Vector2(24,10),c,2,true)
				for i in range(3):
					var y=17+i*10
					draw_colored_polygon(PackedVector2Array([Vector2(23,y+8),Vector2(9,y),Vector2(7,y-5),Vector2(17,y-3)]),Color("7d9877"))
					draw_colored_polygon(PackedVector2Array([Vector2(23,y+8),Vector2(34,y+1),Vector2(38,y-4),Vector2(28,y)]),Color("668c72"))

static func show(host)->void:
	if host.current_screen=="battle":return
	host.modal_generation+=1;host._clear_overlay();host.active_modal=true
	host.overlay.set_meta("inventory",true)
	var generation:int=host.modal_generation
	var veil=ColorRect.new();veil.color=Color(.01,.04,.04,.76);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.overlay.add_child(veil)
	var frame=host._panel(host.overlay,Rect2(72,55,1136,690),Color("133333"),Color("c5aa70"));frame.name="InventoryFrame"
	var sheet=PaperSurface.new();sheet.position=Vector2(18,91);sheet.size=Vector2(1100,482);frame.add_child(sheet)
	text(host,frame,"行囊 · 修行",Rect2(34,18,540,44),30,Color("efe4c8"))
	text(host,frame,"衣剑随身，药草留心。",Rect2(36,60,550,22),14,Color("b8c4aa"))
	text(host,frame,"铜钱  %d 文"%host.state.coins,Rect2(678,25,200,29),20,Color("e5c580"))
	var learn=host._button(frame,"修习 K",Rect2(887,28,99,43),guarded(host,generation,host._show_martials));learn.tooltip_text="查看并调整当前武学"
	var craft=host._button(frame,"工艺 B",Rect2(996,28,103,43),guarded(host,generation,host.workshop.show));craft.tooltip_text="制作与材料买卖"
	text(host,frame,"%s  ·  %d级"%[host.state.player_name,host.state.level],Rect2(39,112,252,32),23,INK)
	text(host,frame,host.state.sect,Rect2(40,148,249,25),15,MUTED)
	text(host,frame,"绝招 · "+host.state.equipped_art,Rect2(40,175,249,22),13,MUTED)
	var figure=TextureRect.new();figure.name="InventoryTraveller";figure.texture=HeroArt.texture_for("front",0);figure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;figure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;figure.position=Vector2(44,200);figure.size=Vector2(248,220);figure.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(figure)
	var stats=RichTextLabel.new();stats.position=Vector2(41,425);stats.size=Vector2(249,80);stats.bbcode_enabled=true;stats.scroll_active=false;stats.add_theme_color_override("default_color",INK);stats.add_theme_font_size_override("normal_font_size",17)
	stats.text="攻击 %d   ·   防御 %d\n修为 %d / %d"%[host.state.attack,host.state.defense,host.state.xp,host.state.xp_to_next()];frame.add_child(stats)
	var exp=host._bar(frame,Rect2(42,493,232,5),Color("94844f"));exp.max_value=host.state.xp_to_next();exp.value=host.state.xp
	text(host,frame,"气血 %d / %d\n真气 %d / %d"%[host.state.hp,host.state.max_hp,host.state.qi,host.state.max_qi],Rect2(42,512,248,47),15,MUTED)
	item(host,frame,Rect2(333,115,337,110),"sword","佩剑 · 已装备",host.state.equipment,"兵刃随成长与工艺提升")
	item(host,frame,Rect2(690,115,407,110),"armor","衣甲 · 已装备",host.state.armor,"门派：%s  ·  历战 %d 次"%[host.state.sect,host.state.victories])
	text(host,frame,"备料",Rect2(334,245,500,24),15,MUTED)
	for i in range(4):
		var id=Items.material_ids()[i]
		var x=334+i*193
		var slot=host._panel(frame,Rect2(x,275,180,58),Color("d7d4b9"),Color("b7bd9f"))
		text(host,slot,Items.material_name(id),Rect2(12,7,100,22),16,INK)
		text(host,slot,"× %d"%host.state.resources.get(id,0),Rect2(100,7,67,36),22,Color("627b60"))
		text(host,slot,"工艺材料",Rect2(12,32,150,18),11,MUTED)
	item(host,frame,Rect2(333,353,337,89),"medicine","回春散 ×%d"%host.state.medicine,"药包随身","恢复45气血；照野堂55")
	item(host,frame,Rect2(690,353,407,89),"herb","青穗草 ×%d"%host.state.herbs,"任务物品","单独保管，不用于交易或制作")
	var companion:String=host.state.current_companion()
	text(host,frame,"同行："+(companion+" · "+host.state.formation if not companion.is_empty() else "独行"),Rect2(334,463,652,30),20,INK)
	var detail=host.state.companion_description() if not companion.is_empty() else "调查药铺后，可再次与沈青交谈并邀请同行。"
	text(host,frame,detail,Rect2(335,502,738,48),15,MUTED)
	var options=[["回春散",host._use_medicine],["切换阵型",host._switch_formation],["青钢剑 · 45文",host._buy_sword],["返回江湖",host._close_modal],["同行册",host.companion_story.roster]]
	for i in range(options.size()):
		var callback=inventory_action(host,generation,i,options[i][1]);host.modal_actions.append(callback)
		var b=host._button(frame,options[i][0],Rect2(36+i*215,600,203,45),callback)
		var reason=unavailable_reason(host,i)
		b.disabled=not reason.is_empty()
		b.tooltip_text=reason if not reason.is_empty() else ["恢复气血","切换并肩助攻与护后减伤","购买后自动装备，攻击+4","返回探索","查看已结识同行人"][i]
		text(host,b,str(i+1),Rect2(8,12,21,21),13,Color("788d80") if b.disabled else Color("bfcaad"))
		if b.disabled:text(host,frame,reason,Rect2(40+i*215,650,199,18),11,Color("d3ba89"))
	var help=text(host,frame,"数字键 1—5  ·  K 修习  /  B 工艺  ·  Esc 返回",Rect2(40,671,1050,17),12,Color("9caf99"))
	help.name="InventoryHelp"

static func unavailable_reason(host,index:int)->String:
	match index:
		0:
			if host.state.medicine<=0:return "行囊中没有回春散"
			if host.state.hp>=host.state.max_hp:return "气血已满"
		1:
			if host.state.current_companion().is_empty():return "尚无同行人"
		2:
			if host.state.equipment!="旧铁剑":return "已持有更好的佩剑"
			if host.state.coins<45:return "还需 %d 文"%(45-host.state.coins)
	return ""

static func inventory_action(host,generation:int,index:int,action:Callable)->Callable:
	return func():
		if not host.active_modal or host.modal_generation!=generation:return
		var reason=unavailable_reason(host,index)
		if not reason.is_empty():
			var help=host.overlay.find_child("InventoryHelp",true,false)
			if help!=null:help.text=reason;help.add_theme_color_override("font_color",Color("edc88d"))
			return
		action.call()

static func guarded(host,generation:int,action:Callable)->Callable:
	return func():
		if host.active_modal and host.modal_generation==generation:action.call()

static func text(host,parent:Node,value:String,rect:Rect2,size_px:int,color:Color)->Label:
	var result=host._label(parent,value,rect,size_px,color);result.mouse_filter=Control.MOUSE_FILTER_IGNORE;return result

static func item(host,parent:Node,rect:Rect2,kind:String,caption:String,title:String,detail:String)->void:
	var line=ColorRect.new();line.position=rect.position+Vector2(0,rect.size.y-1);line.size=Vector2(rect.size.x,1);line.color=Color("bcc0a1");line.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(line)
	var glyph=ItemGlyph.new();glyph.kind=kind;glyph.position=rect.position+Vector2(2,18);glyph.size=Vector2(48,55);parent.add_child(glyph)
	text(host,parent,caption,Rect2(rect.position+Vector2(65,2),Vector2(rect.size.x-67,23)),14,MUTED)
	text(host,parent,title,Rect2(rect.position+Vector2(65,27),Vector2(rect.size.x-67,31)),22,INK)
	text(host,parent,detail,Rect2(rect.position+Vector2(65,64),Vector2(rect.size.x-67,34)),13,MUTED)
