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

static func build(host,title:String,subtitle:String,body:String,options:Array,wide:bool,npc_folio:bool=false)->void:
	if npc_folio:
		_build_npc(host,title,subtitle,body,options,wide)
		return
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
	# Embedded maps reserve their own paper area despite having no prose body.
	required_height=maxf(required_height,float(frame.get_meta("minimum_page_height",365.0)))
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

# This compact presentation is opt-in only. Generic prompts and embedded maps
# retain the original PaperSurface/build/fit_page path below.
const Folio=preload("res://scripts/folio_theme.gd")
class ReadingPaper extends Folio.ReadingWash:
	func _draw()->void:
		# One continuous native tint, preserving the original backing's grain.
		wash_material.set_shader_parameter("wash_size",size)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.933,.890,.800,strength))

static func _build_npc(host,title:String,subtitle:String,body:String,options:Array,wide:bool)->void:
	var generation:int=host.modal_generation
	if options.is_empty():options=[["继续行走",host._close_modal]]
	var width=1000.0 if options.size()>=3 else (960.0 if wide else 900.0)
	var height=570.0
	var paper_start=roundf(364.0*width/1350.0)
	var frame=host._panel(host.overlay,Rect2((1280-width)/2,(800-height-36)/2,width,height),Color.TRANSPARENT,Color.TRANSPARENT)
	frame.name="DialogueSheet";frame.set_meta("npc_folio",true)
	frame.add_theme_stylebox_override("panel",Folio.style(Folio.CLOTH))
	# Crop the original index + page vertically at one uniform scale. Neither
	# a stretched material swatch nor a rescaled squat book replaces the art.
	var art_clip=Control.new();art_clip.name="DialogueArtClip";art_clip.clip_contents=true
	art_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;art_clip.focus_mode=Control.FOCUS_NONE;frame.add_child(art_clip);art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art=TextureRect.new();art.name="DialogueFolioBacking"
	var atlas=AtlasTexture.new();atlas.atlas=Folio.BACKING;atlas.region=Rect2(190,52,1350,890);atlas.filter_clip=true
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture=atlas;art.size=Vector2(width,890.0*width/1350.0)
	art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.focus_mode=Control.FOCUS_NONE
	art_clip.add_child(art)
	var paper=ReadingPaper.new();paper.name="DialogueReadingPaper";paper.strength=.82
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE;paper.focus_mode=Control.FOCUS_NONE;art_clip.add_child(paper)
	var answers=label(host,frame,"此刻如何作答",Rect2(24,34,paper_start-48,24),13,Folio.BRASS);answers.name="DialogueAnswersHeading"
	answers.add_theme_font_override("font",Folio.BODY_FONT)
	Folio.rule(frame,Rect2(24,68,paper_start-48,1))
	var body_width=width-paper_start-60
	var portrait_id=Portraits.id_for_title(title)
	if not portrait_id.is_empty():Portraits.attach(frame,portrait_id,Rect2(width-158,14,132,116))
	var heading_width=body_width-(144 if not portrait_id.is_empty() else 0)
	var subtitle_label=label(host,frame,subtitle,Rect2(paper_start+28,30,heading_width,24),15,Folio.SECONDARY_INK);subtitle_label.name="DialogueSubtitle"
	subtitle_label.add_theme_font_override("font",Folio.BODY_FONT)
	var heading=label(host,frame,title,Rect2(paper_start+28,59,heading_width,48),32,Folio.INK);heading.name="DialogueTitle"
	heading.add_theme_font_override("font",Folio.heading_font())
	Folio.rule(frame,Rect2(paper_start+28,118,heading_width,1))
	var text=RichTextLabel.new();text.name="DialogueBody";text.position=Vector2(paper_start+28,140);text.size=Vector2(body_width,height-170)
	text.bbcode_enabled=true;text.scroll_active=true;text.selection_enabled=true
	text.text=body.replace("[color=#d3b276]","[color=#543719]")
	text.add_theme_font_override("normal_font",Folio.BODY_FONT)
	text.add_theme_color_override("default_color",Folio.INK);text.add_theme_font_size_override("normal_font_size",19);text.add_theme_constant_override("line_separation",5)
	text.add_theme_color_override("font_selected_color",Folio.BONE);text.add_theme_color_override("selection_color",Folio.INK)
	frame.add_child(text);Folio.scrollbar(text.get_v_scroll_bar())
	var edges=Folio.scroll_edges(frame,text.get_v_scroll_bar(),text.get_rect())
	var buttons:Array[Button]=[]
	for i in range(options.size()):
		var rect=Rect2(24,84+i*64,paper_start-48,54)
		var action=guarded(host,generation,options[i][1]);host.modal_actions.append(action)
		var button=host._button(frame,options[i][0],rect,action);button.name="DialogueChoice"+str(i+1)
		button.clip_text=true;Folio.skin_button(button,"row");button.size=rect.size;buttons.append(button)
		for property in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(property,Color.TRANSPARENT)
		button.tooltip_text=options[i][0]
		var number=label(host,button,str(i+1),Rect2(10,14,24,26),15,Folio.BONE);number.name="ChoiceNumber";number.add_theme_font_override("font",Folio.BODY_FONT)
		var caption=label(host,button,options[i][0],Rect2(42,3,rect.size.x-54,48),17,Folio.BONE);caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.name="ChoiceCaption"
		caption.add_theme_font_override("font",Folio.BODY_FONT);caption.size=Vector2(rect.size.x-54,48)
	var border=Panel.new();border.name="DialogueFolioBorder";border.mouse_filter=Control.MOUSE_FILTER_IGNORE;border.focus_mode=Control.FOCUS_NONE
	border.add_theme_stylebox_override("panel",Folio.style(Color.TRANSPARENT,Folio.BRASS,1));frame.add_child(border);border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var help_backing=ColorRect.new();help_backing.name="DialogueHelpBacking";help_backing.color=Color(Folio.INK,.96)
	help_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;help_backing.focus_mode=Control.FOCUS_NONE;host.overlay.add_child(help_backing)
	var help=label(host,host.overlay,"数字键选择  ·  Enter / 空格选首项  ·  Esc 返回",Rect2(0,0,width-24,24),13,Folio.BONE);help.name="DialogueHelp"
	help.add_theme_font_override("font",Folio.BODY_FONT)
	_fit_npc.call_deferred(host,generation,frame,paper,text,edges,help_backing,help,buttons)

static func _fit_npc(host,generation:int,frame:Control,paper:Control,body:RichTextLabel,edges:Control,help_backing:Control,help:Label,buttons:Array[Button])->void:
	if not is_instance_valid(host) or not host.active_modal or host.modal_generation!=generation:return
	if not is_instance_valid(frame) or frame.is_queued_for_deletion() or not frame.is_inside_tree() or frame.get_parent()!=host.overlay:return
	if not is_instance_valid(body) or body.get_parent()!=frame or not is_instance_valid(paper) or paper.get_parent().get_parent()!=frame:return
	if not is_instance_valid(edges) or edges.get_parent()!=frame or not is_instance_valid(help) or help.get_parent()!=host.overlay or not is_instance_valid(help_backing) or help_backing.get_parent()!=host.overlay:return
	# Native CJK metrics can make a wrapped caption taller than the nominal
	# 48px. Measure it; never shrink, elide or draw text beyond its hit area.
	var next_y=84.0
	for button:Button in buttons:
		if not is_instance_valid(button) or button.get_parent()!=frame:return
		var caption:Label=button.get_node("ChoiceCaption")
		var row_height=maxf(54.0,caption.get_minimum_size().y+6.0)
		button.position.y=next_y;button.size.y=row_height;caption.size.y=row_height-6.0
		next_y+=row_height+10.0
	var required_height=maxf(365.0,maxf(body.get_content_height()+170.0,next_y+20.0))
	var height=clampf(ceilf(required_height/4.0)*4.0,365.0,570.0)
	frame.size.y=height;frame.position.y=(800-height-36)/2
	body.size.y=height-170
	paper.position=body.position-Vector2(18,20);paper.size=body.size+Vector2(82,44)
	edges.position=body.position-Vector2(0,7);edges.size=body.size+Vector2(0,14)
	help_backing.position=frame.position+Vector2(0,height+8);help_backing.size=Vector2(frame.size.x,24)
	help.position=help_backing.position+Vector2(12,0)
	if body.get_content_height()>body.size.y:help.text="滚轮翻阅正文  ·  "+help.text
