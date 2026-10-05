extends RefCounted
## Original cloth-and-paper inventory; rules and transactions remain in HeroState.
const HeroArt=preload("res://scripts/painted_traveler_sprite.gd")
const Items=preload("res://scripts/item_catalog.gd")
const Folio=preload("res://scripts/folio_theme.gd")
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

class InventoryReadingPaper extends Folio.ReadingWash:
	func _draw()->void:
		# A single continuous native wash preserves the original painted paper.
		wash_material.set_shader_parameter("wash_size",size)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.933,.890,.800,strength))

static func show(host)->void:
	if host.current_screen in ["battle","receipt_battle"] or host.state.battle_active:return
	host.modal_generation+=1;host._clear_overlay();host.active_modal=true
	host.overlay.set_meta("inventory",true)
	var generation:int=host.modal_generation
	var veil=ColorRect.new();veil.color=Color(.01,.04,.04,.78);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.overlay.add_child(veil)
	var frame=host._panel(host.overlay,Rect2(40,46,1200,714),Color.TRANSPARENT,Color.TRANSPARENT);frame.name="InventoryFrame"
	frame.add_theme_stylebox_override("panel",Folio.style(Color.TRANSPARENT))
	Folio.backing(frame,Rect2(0,0,1200,714))
	var wash=InventoryReadingPaper.new();wash.name="InventoryReadingPaper";wash.position=Vector2(438,130);wash.size=Vector2(744,560);wash.strength=.84;wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(wash)
	folio_heading(host,frame,"行 囊",Rect2(138,26,250,45),34,Folio.BONE,"InventoryTitle")
	folio_text(host,frame,"衣剑随身，药草留心。",Rect2(138,82,250,30),18,Folio.BRASS)
	var identity=folio_heading(host,frame,"%s  ·  %d级"%[host.state.player_name,host.state.level],Rect2(138,131,250,38),24,Folio.BONE,"InventoryIdentity")
	# Preserve the full validated name; let native wrapping move the school and
	# shorten only the decorative portrait, never overlap or truncate identity.
	var identity_height:float=maxf(38,identity.get_combined_minimum_size().y)
	identity.size.y=identity_height
	var school_y:float=135+identity_height
	folio_text(host,frame,host.state.sect,Rect2(138,school_y,250,30),19,Folio.BRASS)
	var figure=TextureRect.new();figure.name="InventoryTraveller";figure.texture=HeroArt.texture_for("front",0);figure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;figure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;figure.position=Vector2(156,school_y+34);figure.size=Vector2(216,maxf(0,391-(school_y+34)));figure.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(figure)
	folio_text(host,frame,"绝招 · "+host.state.equipped_art,Rect2(138,401,250,49),18,Folio.BONE,"InventoryEquippedArt")
	Folio.rule(frame,Rect2(138,456,250,1),Folio.BRASS.darkened(.2))
	var stats=RichTextLabel.new();stats.name="InventoryActualStats";stats.position=Vector2(138,470);stats.size=Vector2(250,157);stats.bbcode_enabled=true;stats.scroll_active=false;stats.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stats.add_theme_font_override("normal_font",Folio.BODY_FONT);stats.add_theme_color_override("default_color",Folio.BONE);stats.add_theme_font_size_override("normal_font_size",18)
	stats.text="[font_size=24]攻击 %d   防御 %d[/font_size]\n\n气血 %d / %d\n真气 %d / %d\n修为 %d / %d"%[host.state.effective_attack(),host.state.effective_defense(),host.state.hp,host.state.max_hp,host.state.qi,host.state.max_qi,host.state.xp,host.state.xp_to_next()];frame.add_child(stats)
	var exp=host._bar(frame,Rect2(138,632,250,4),Folio.BRASS);exp.max_value=host.state.xp_to_next();exp.value=host.state.xp;exp.name="InventoryExperience"
	var learn=host._button(frame,"修习 K",Rect2(138,652,115,40),guarded(host,generation,host._show_martials));learn.name="InventoryMartials";learn.tooltip_text="查看并调整当前武学";Folio.skin_button(learn,"cloth_quiet")
	var craft=host._button(frame,"工艺 B",Rect2(270,652,118,40),guarded(host,generation,host.workshop.show));craft.name="InventoryWorkshop";craft.tooltip_text="制作与材料买卖";Folio.skin_button(craft,"cloth_quiet")
	folio_text(host,frame,"随身实物 / 当前装备",Rect2(456,38,510,28),18,Folio.SECONDARY_INK)
	folio_heading(host,frame,"行装随身",Rect2(456,78,420,49),36,Folio.INK,"InventoryPageTitle")
	folio_text(host,frame,"铜钱  %d 文"%host.state.coins,Rect2(866,87,260,34),22,Folio.SECONDARY_INK,"InventoryCoins")
	Folio.rule(frame,Rect2(456,135,662,1),Folio.BRASS)
	folio_item(host,frame,Rect2(456,151,310,91),"sword","佩剑 · 已装备",host.state.equipment,"兵刃随成长与工艺提升")
	folio_item(host,frame,Rect2(808,151,310,91),"armor","衣甲 · 已装备",host.state.armor,"历战 %d 次"%host.state.victories)
	folio_text(host,frame,"备料",Rect2(456,323,662,32),21,Folio.SECONDARY_INK)
	Folio.rule(frame,Rect2(456,358,662,1),Folio.BRASS)
	for i in range(4):
		var id=Items.material_ids()[i]
		var x=456+i*174
		folio_text(host,frame,Items.material_name(id),Rect2(x,362,145,29),19,Folio.SECONDARY_INK,"InventoryMaterial_"+id)
		folio_heading(host,frame,"× %d"%host.state.resources.get(id,0),Rect2(x,395,145,38),26,Folio.INK)
	folio_item(host,frame,Rect2(456,440,310,67),"medicine","回春散 ×%d"%host.state.medicine,"恢复45气血；照野堂55","")
	folio_item(host,frame,Rect2(808,440,310,67),"herb","青穗草 ×%d"%host.state.herbs,"任务物品","")
	folio_text(host,frame,"单独保管，不用于交易或制作",Rect2(808,515,310,42),18,Folio.SECONDARY_INK)
	var companion:String=host.state.current_companion()
	var party=host.state.party_resource_snapshot()
	var selected_names:Array[String]=[]
	for actor:Dictionary in party.actors:
		if actor.selected and actor.id!="hero":selected_names.append(actor.name)
	Folio.rule(frame,Rect2(456,565,662,1),Folio.BRASS)
	folio_text(host,frame,"同行："+(("、".join(selected_names))+" · "+host.state.formation if not selected_names.is_empty() else "独行"),Rect2(456,575,662,31),20,Folio.INK,"InventoryParty")
	var detail="出战%d/4人 · 各自保留气血与真气"%host.state.party_roster.size() if not companion.is_empty() else "调查药铺后，可再次与沈青交谈并邀请同行。"
	folio_text(host,frame,detail,Rect2(456,609,662,28),17,Folio.SECONDARY_INK,"InventoryPartyDetail")
	# Index order, callbacks, generation guard and close policy are unchanged.
	# The controls live beside their subjects instead of in one identical row.
	var options=[["回春散",host._use_medicine],["切换阵型",host._switch_formation],["青钢剑 · 45文",host._buy_sword],["返回江湖",host._close_modal],["同行册",host.companion_story.roster]]
	var rects=[Rect2(456,514,310,43),Rect2(456,640,250,40),Rect2(456,250,310,43),Rect2(1008,20,166,45),Rect2(832,633,286,47)]
	var roles=["paper_quiet","paper_quiet","paper_quiet","header_close","primary"]
	for i in range(options.size()):
		var callback=inventory_action(host,generation,i,options[i][1]);host.modal_actions.append(callback)
		var b=host._button(frame,options[i][0],rects[i],callback);b.name="InventoryAction%d"%(i+1)
		Folio.skin_button(b,roles[i]);b.add_theme_font_size_override("font_size",20 if i==4 else 19)
		if i in [0,1,2]:
			b.add_theme_stylebox_override("normal",Folio.style(Color(.12,.15,.12,.025),Folio.BRASS,1))
		var reason=unavailable_reason(host,i)
		b.disabled=not reason.is_empty()
		b.tooltip_text=reason if not reason.is_empty() else ["恢复气血","切换并肩承敌与前位护后","购买后自动装备，攻击+4","返回探索","查看已结识同行人、编队与招式近况"][i]
		folio_text(host,b,str(i+1),Rect2(22 if i==4 else 10,10 if i==4 else 8,23,27),17,Folio.BONE if i in [3,4] else Folio.SECONDARY_INK,"InventoryShortcut%d"%(i+1))
		if b.disabled and i==2:folio_text(host,frame,reason,Rect2(rects[i].position+Vector2(0,46),Vector2(310,25)),17,Folio.SECONDARY_INK,"InventoryUnavailable%d"%(i+1))
		if b.disabled and i==1:b.tooltip_text=reason
	var help_back=ColorRect.new();help_back.name="InventoryHelpBacking";help_back.position=Vector2(128,715);help_back.size=Vector2(1018,32);help_back.color=Color("132226");help_back.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(help_back)
	folio_text(host,frame,"1–5 对应动作 · Enter / 空格服药 · K 修习 / B 工艺 · Esc 返回",Rect2(138,719,995,26),16,Folio.BONE,"InventoryHelp")

static func folio_text(host,parent:Node,value:String,rect:Rect2,pixels:int,color:Color,node_name:String="")->Label:
	var result=text(host,parent,value,rect,pixels,color)
	result.add_theme_font_override("font",Folio.BODY_FONT)
	result.size=rect.size;result.set_deferred("size",rect.size)
	if not node_name.is_empty():result.name=node_name
	return result

static func folio_heading(host,parent:Node,value:String,rect:Rect2,pixels:int,color:Color,node_name:String="")->Label:
	var result=folio_text(host,parent,value,rect,pixels,color,node_name)
	result.add_theme_font_override("font",Folio.heading_font())
	return result

static func folio_item(host,parent:Node,rect:Rect2,kind:String,caption:String,title:String,detail:String)->void:
	var glyph=ItemGlyph.new();glyph.kind=kind;glyph.position=rect.position+Vector2(0,17);glyph.size=Vector2(48,55);parent.add_child(glyph)
	folio_text(host,parent,caption,Rect2(rect.position+Vector2(64,0),Vector2(rect.size.x-64,28)),18,Folio.SECONDARY_INK)
	folio_heading(host,parent,title,Rect2(rect.position+Vector2(64,32),Vector2(rect.size.x-64,52 if kind in ["sword","armor"] else 33)),25 if kind in ["sword","armor"] else 18,Folio.INK)
	if not detail.is_empty():folio_text(host,parent,detail,Rect2(rect.position+Vector2(64,75),Vector2(rect.size.x-64,30)),16,Folio.SECONDARY_INK)

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
