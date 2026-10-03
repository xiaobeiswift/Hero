extends SceneTree
## Draw-call, declared-color and actual font-cache layout contracts only.
## This is not framebuffer contrast, native composition or browser acceptance.
const Harbor=preload("res://scripts/heting_region.gd")
const FONT=preload("res://assets/fonts/NotoSansSC.otf")
const LABELS=[
	{"p":Vector2(1033,316),"text":"北岸横街  ·  板车可绕行","size":14,"width":297.0},
	{"p":Vector2(710,410),"text":"窄步栈  ·  行人通行","size":13,"width":195.0},
	{"p":Vector2(709,426),"text":"板车走侧浮栈","size":13,"width":195.0},
	{"p":Vector2(361,737),"text":"连 舟 浮 栈","size":13,"width":228.0},
	{"p":Vector2(1031,737),"text":"连 舟 浮 栈","size":13,"width":248.0},
]
var checks:int=0
var failures:int=0

class DrawProbe extends RefCounted:
	var ui_font:Font=FONT
	var calls:Array=[]
	func draw_string_outline(font:Font,p:Vector2,text:String,alignment:int,width:float,size:int,outline:int,color:Color)->void:
		calls.append({"kind":"outline","font":font,"p":p,"text":text,"alignment":alignment,"width":width,"size":size,"outline":outline,"color":color})
	func draw_string(font:Font,p:Vector2,text:String,alignment:int,width:float,size:int,color:Color)->void:
		calls.append({"kind":"fill","font":font,"p":p,"text":text,"alignment":alignment,"width":width,"size":size,"color":color})

func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)

func _initialize()->void:
	_source_contract()
	_draw_contract()
	_color_contract()
	_font_layout()
	print("%s: %d Heting route-label draw/color/font-layout checks; native framebuffer contrast/composition remains separate"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)

func _source_contract()->void:
	var source=FileAccess.get_file_as_string("res://scripts/heting_region.gd")
	check(source.count("\t_route_label(")==4,"Only the four approved call sites receive route styling")
	for call in [
		'_route_label(w, Vector2(1033, 316), "北岸横街  ·  板车可绕行", 14, 297, HORIZONTAL_ALIGNMENT_CENTER)',
		'_route_label(w, Vector2(710, 410), "窄步栈  ·  行人通行", 13, 195, HORIZONTAL_ALIGNMENT_CENTER)',
		'_route_label(w, Vector2(709, 426), "板车走侧浮栈", 13, 195, HORIZONTAL_ALIGNMENT_CENTER)',
		'_route_label(w, r.position + Vector2(16, 47), "连 舟 浮 栈", 13, r.size.x - 32, HORIZONTAL_ALIGNMENT_CENTER)',
	]:check(source.contains(call),"Exact original text/anchor/width/alignment and approved size: "+call)
	var helper=source.get_slice("static func _route_label(",1).get_slice("\nstatic func ",0)
	check(helper.count("w.draw_string_outline(")==1 and helper.count("w.draw_string(")==1,"One real outline followed by one unchanged-weight text fill")
	check(helper.find("w.draw_string_outline(")<helper.find("w.draw_string("),"Outline cannot overpaint the dark CJK strokes")
	for forbidden in ["draw_rect(","draw_polygon(","draw_mesh(",".new(",".duplicate(","load(","Image","Texture","set_transform","_label("]:
		check(not helper.contains(forbidden),"Helper has no panel, resource creation, transform or global-label dependency: "+forbidden)
	var painter=source.get_slice("static func draw(",1).get_slice("\nstatic func ",0)
	check(painter.find("_ground(w,")<painter.find("var layers:"),"Road label remains below sorted actors/cart")
	check(painter.find("_foot_pier(w)")<painter.find("var layers:"),"Pier labels remain below sorted actors/cart")
	check(painter.find("_pontoon(w,")<painter.find("var layers:"),"Pontoon label remains below sorted actors/cart")
	check(painter.find("_draw_view_framing()")>painter.find("for layer in layers:"),"World framing/HUD relationship is unchanged")

func _draw_contract()->void:
	var probe=DrawProbe.new()
	for item:Dictionary in LABELS:
		probe.calls.clear()
		Harbor._route_label(probe,item.p,item.text,item.size,item.width,HORIZONTAL_ALIGNMENT_CENTER)
		check(probe.calls.size()==2,"No background/sign geometry for "+item.text)
		var support:Dictionary=probe.calls[0]
		var fill:Dictionary=probe.calls[1]
		check(support.kind=="outline" and support.outline==2 and support.color==Harbor.PAPER,"Restrained opaque PAPER support uses real outline API")
		check(fill.kind=="fill" and fill.color==Color("142b26"),"Stable dark-green navigation ink")
		for call:Dictionary in probe.calls:
			check(call.font==FONT,"Existing shared Noto font resource is reused")
			for key in ["p","text","size","width"]:check(call[key]==item[key],"Drawing preserves "+key+" for "+item.text)
			check(call.alignment==HORIZONTAL_ALIGNMENT_CENTER,"Both passes use identical original centered alignment")
	probe.ui_font=null;probe.calls.clear()
	Harbor._route_label(probe,Vector2.ZERO,"通行",13,100,HORIZONTAL_ALIGNMENT_CENTER)
	check(probe.calls[0].font==ThemeDB.fallback_font and probe.calls[1].font==ThemeDB.fallback_font,"Null-font behavior remains compatible with world label helper")

func _color_contract()->void:
	check(Harbor.ROUTE_INK.a==1.0 and Harbor.PAPER.a==1.0,"Fill and support retain solid interiors for measurable contrast")
	check(_contrast(Harbor.ROUTE_INK,Harbor.PAPER)>=8.0,"Declared ink/PAPER ratio exceeds 8:1")
	# Compact125 east-pontoon native review found this filtered support color.
	# Palette headroom is regression protection, not a new framebuffer pass.
	check(_contrast(Harbor.ROUTE_INK,Color("aba98b"))>=6.0,"Declared ink keeps margin against the captured compact pontoon support")
	for base in [Color("b9b090"),Color("c3b794"),Color("d0c29f")]:
		check(_contrast(Harbor.ROUTE_INK,base)>=5.4,"Declared north-bank bases exceed 5.4:1")
	# Timber alone is insufficient. The real PAPER outline is mandatory there;
	# actual native foreground/support samples still need the >=4.5:1 gate.
	check(_contrast(Harbor.ROUTE_INK,Harbor.WOOD_DARK)<4.5,"Test does not misrepresent dark-timber nominal contrast as a pass")

func _contrast(a:Color,b:Color)->float:
	var light=a.srgb_to_linear().get_luminance()
	var dark=b.srgb_to_linear().get_luminance()
	return (maxf(light,dark)+.05)/(minf(light,dark)+.05)

func _font_layout()->void:
	# Sample the actual cached Noto glyph alpha, excluding transparent atlas
	# padding. This establishes line bounds, not final scaled framebuffer pixels.
	for oversampling in [0.0,2.0]:
		var font:FontFile=FONT.duplicate()
		font.oversampling=oversampling
		var supported:Array[Rect2]=[]
		var filled:Array[Rect2]=[]
		for item:Dictionary in LABELS:
			var width=font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,item.size).x
			check(width+Harbor.ROUTE_OUTLINE_SIZE*2<item.width,"Full text and outline fit the preserved width: "+item.text)
			var offset:Vector2=item.p+Vector2((item.width-width)*.5,0)
			var ink=_glyph_bounds(font,item.text,item.size,0)
			var outline=_glyph_bounds(font,item.text,item.size,Harbor.ROUTE_OUTLINE_SIZE)
			check(ink.has_area() and outline.has_area(),"Actual Noto raster-cache glyphs exist: "+item.text)
			check(outline.position.x>=-Harbor.ROUTE_OUTLINE_SIZE and outline.end.x<=width+Harbor.ROUTE_OUTLINE_SIZE,"Glyph support stays within declared horizontal margins")
			ink.position+=offset;outline.position+=offset
			filled.append(ink);supported.append(outline)
		check(supported[2].position.y-supported[1].end.y>=.5,"Two fixed pier lines retain a visible support gap at 16px baseline spacing")
		check(filled[2].position.y-filled[1].end.y>=2.0,"Pier CJK fills remain separately spaced")
		check(supported[2].end.y<Harbor.FOOT_PIER.position.y,"Cart qualifier remains above the physical bridge deck")
		for index in [3,4]:
			var deck=Harbor.WEST_PONTOON if index==3 else Harbor.EAST_PONTOON
			check(deck.encloses(supported[index]),"Pontoon support fits inside either unchanged deck")
		print("Noto oversampling %.1f: pier ink gap %.2fpx, support gap %.2fpx; qualifier support bottom %.2f"%[oversampling,filled[2].position.y-filled[1].end.y,supported[2].position.y-supported[1].end.y,supported[2].end.y])

func _glyph_bounds(font:FontFile,text:String,size:int,outline:int)->Rect2:
	var cache_size=Vector2i(size,outline)
	var result=Rect2()
	var first=true
	var cursor:float=0
	for character:String in text:
		check(font.has_char(character.unicode_at(0)),"Noto contains exact route character: "+character)
	var line=TextLine.new()
	line.add_string(text,font,size)
	for shaped:Dictionary in TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid()):
		# CJK shaping includes zero-advance virtual word-break markers.
		if int(shaped.flags)&TextServer.GRAPHEME_IS_VIRTUAL:continue
		check(shaped.font_rid==font.get_rids()[0] and shaped.repeat==1,"Shaped route glyph uses the existing Noto face once")
		var glyph:int=shaped.index
		font.render_glyph(0,cache_size,glyph)
		var texture_index=font.get_glyph_texture_idx(0,cache_size,glyph)
		if texture_index>=0:
			var bitmap=font.get_texture_image(0,cache_size,texture_index)
			var uv=font.get_glyph_uv_rect(0,cache_size,glyph)
			var extent=font.get_glyph_size(0,cache_size,glyph)
			var origin=Vector2(cursor,0)+shaped.offset+font.get_glyph_offset(0,cache_size,glyph)
			for y in range(int(uv.size.y)):
				for x in range(int(uv.size.x)):
					if bitmap.get_pixel(int(uv.position.x)+x,int(uv.position.y)+y).a<.05:continue
					var pixel=Rect2(origin+Vector2(x,y)*extent/uv.size,extent/uv.size)
					result=pixel if first else result.merge(pixel);first=false
		cursor+=float(shaped.advance)
	return result
