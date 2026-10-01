extends RefCounted
## A readable paper folio shared by conversations, notices and decision pages.
const Portraits=preload("res://scripts/character_portraits.gd")
const INK=Color("304a42")
const PAPER=Color("e7dfc6")
const MUTED=Color("687668")
class PaperSurface extends Control:
	func _ready()->void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw()->void:
		draw_rect(Rect2(Vector2.ZERO,size),PAPER)
		for i in range(95):
			var p=Vector2(fmod(17+i*91.13,size.x),fmod(13+i*57.71,size.y))
			draw_line(p,p+Vector2(2+fmod(i,5),0),Color(.34,.36,.23,.045),1)
		draw_line(Vector2(18,12),Vector2(18,size.y-12),Color("b9b597"),1)

static func build(host,title:String,subtitle:String,body:String,options:Array,wide:bool)->void:
	var generation:int=host.modal_generation
	if options.is_empty():options=[["继续行走",host._close_modal]]
	var side_choices=options.size()>=3
	var width=1000.0 if side_choices else (960.0 if wide else 900.0)
	var height=570.0 if side_choices or wide else 500.0
	var frame=host._panel(host.overlay,Rect2((1280-width)/2,(800-height)/2,width,height),Color("163a3b"),Color("b49e69"))
	frame.name="DialogueSheet"
	var paper=PaperSurface.new();paper.position=Vector2(10,112);paper.size=Vector2(width-20,height-122);frame.add_child(paper)
	var portrait_id=Portraits.id_for_title(title)
	if not portrait_id.is_empty():Portraits.attach(frame,portrait_id,Rect2(width-154,-6,142,122))
	var heading_width=width-(206 if not portrait_id.is_empty() else 68)
	label(host,frame,subtitle,Rect2(34,19,heading_width,25),13,Color("d1b780"))
	var heading=label(host,frame,title,Rect2(32,49,heading_width,52),29,Color("eee4c9"));heading.name="DialogueTitle"
	var body_width=width-68-(296 if side_choices else 0)
	var body_height=height-197 if side_choices else height-237
	var text=RichTextLabel.new();text.name="DialogueBody";text.position=Vector2(35,139);text.size=Vector2(body_width,body_height)
	text.bbcode_enabled=true;text.scroll_active=true;text.selection_enabled=true
	text.text=body.replace("[color=#d3b276]","[color=#7c5726]")
	text.add_theme_color_override("default_color",INK);text.add_theme_font_size_override("normal_font_size",19);text.add_theme_constant_override("line_separation",5)
	frame.add_child(text)
	var divider:ColorRect
	if side_choices:
		divider=ColorRect.new();divider.position=Vector2(width-307,136);divider.size=Vector2(1,height-193);divider.color=Color("bdb799");divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(divider)
		label(host,frame,"此刻如何作答",Rect2(width-284,133,248,25),13,MUTED)
	var buttons:Array[Button]=[]
	for i in range(options.size()):
		var rect:Rect2
		if side_choices:rect=Rect2(width-284,169+i*65,250,54)
		else:
			var bw=340.0 if options.size()==1 else (width-80)/2
			rect=Rect2(width-34-bw if options.size()==1 else 34+i*(bw+12),height-92,bw,52)
		var action=guarded(host,generation,options[i][1]);host.modal_actions.append(action)
		var button=host._button(frame,options[i][0],rect,action);button.name="DialogueChoice"+str(i+1)
		buttons.append(button)
		# Keep the semantic button text for accessibility and input tests; paint a
		# wrapping label so longer choices never disappear beyond the button edge.
		for property in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(property,Color.TRANSPARENT)
		button.tooltip_text=options[i][0]
		label(host,button,str(i+1),Rect2(10,13,27,26),15,Color("d8bd80"))
		var caption=label(host,button,options[i][0],Rect2(43,3,rect.size.x-56,rect.size.y-6),16,Color("eee4c9"));caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.name="ChoiceCaption"
	var help=label(host,frame,"数字键选择  ·  Enter / 空格选首项  ·  Esc 返回",Rect2(35,height-32,width-70,20),12,MUTED);help.name="DialogueHelp"
	fit_page.call_deferred(frame,paper,text,help,buttons,divider,height)

static func label(host,parent:Node,value:String,rect:Rect2,pixels:int,color:Color)->Label:
	var node=host._label(parent,value,rect,pixels,color);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;return node

static func fit_page(frame:Control,paper:Control,body:RichTextLabel,help:Label,buttons:Array[Button],divider:ColorRect,max_height:float)->void:
	if not is_instance_valid(frame) or not frame.is_inside_tree():return
	var side_choices=buttons.size()>=3
	var required_height=body.get_content_height()+(197 if side_choices else 237)
	if side_choices:required_height=maxf(required_height,buttons[-1].position.y+buttons[-1].size.y+62)
	var height=clampf(required_height,365,max_height)
	frame.size.y=height;frame.position.y=(800-height)/2;paper.size.y=height-122
	body.size.y=height-(197 if side_choices else 237)
	help.position.y=height-32
	if is_instance_valid(divider):divider.size.y=height-193
	if not side_choices:
		for button in buttons:button.position.y=height-92
	if body.get_content_height()>body.size.y:help.text="滚轮翻阅正文  ·  "+help.text

static func guarded(host,generation:int,action:Callable)->Callable:
	return func():
		if is_instance_valid(host) and host.active_modal and host.modal_generation==generation:action.call()
