extends RefCounted
## Presentation only. Main supplies the existing guidance, chart and sole action.
const Folio = preload("res://scripts/folio_theme.gd")
const PAGE_SIZE = Vector2(1240,744)
const CAPTION_RECT = Rect2(154,100,1042,106)
const FOOTER_Y = 668.0

static func build(host, title: String, subtitle: String, options: Array) -> void:
	var generation: int = host.modal_generation
	var frame = host._panel(host.overlay,Rect2(Vector2(20,28),PAGE_SIZE),Color.TRANSPARENT,Color.TRANSPARENT)
	frame.name = "DialogueSheet"
	frame.set_meta("map_folio",true)
	frame.add_theme_stylebox_override("panel",Folio.style(Color.TRANSPARENT))
	var cover = ClothSurface.new()
	cover.name = "MapClothCover"
	cover.size = PAGE_SIZE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cover)
	var spine = TextureRect.new()
	spine.name = "MapFolioBinding"
	spine.texture = Folio.atlas("spine")
	spine.position = Vector2(0,0)
	spine.size = Vector2(121,744)
	spine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(spine)
	var paper = PaperSurface.new()
	paper.name = "MapAtlasPaper"
	paper.position = Vector2(126,14)
	paper.size = Vector2(1096,712)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(paper)
	var heading = host._label(frame,title,Rect2(154,23,410,57),39,Folio.INK)
	heading.name = "DialogueTitle"
	heading.add_theme_font_override("font",Folio.HEADING_FONT)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var region = host._label(frame,subtitle,Rect2(629,42,567,28),18,Folio.SECONDARY_INK)
	region.name = "MapRegionCaption"
	region.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Folio.rule(frame,Rect2(154,86,1042,1),Folio.BRASS)
	Folio.rule(frame,Rect2(142,102,3,26),Folio.CINNABAR)
	var action: Callable = options[0][1]
	var host_ref = weakref(host)
	var frame_ref = weakref(frame)
	var guarded = func():
		var current_host = host_ref.get_ref()
		var current_frame = frame_ref.get_ref()
		if not is_instance_valid(current_host) or not is_instance_valid(current_frame): return
		if current_host.quit_pending or current_host.current_screen != "explore" or current_host.state.battle_active: return
		if not current_host.active_modal or current_host.modal_generation != generation or not current_host.overlay.get_meta("journal_map",false): return
		if current_frame.is_queued_for_deletion() or not current_frame.is_inside_tree() or current_frame.get_parent() != current_host.overlay: return
		action.call()
	host.modal_actions.append(guarded)
	var close = host._button(frame,options[0][0],Rect2(950,FOOTER_Y,246,44),guarded)
	close.name = "DialogueChoice1"
	Folio.skin_button(close,"primary")
	close.add_theme_font_size_override("font_size",21)
	var key = host._label(close,"1",Rect2(12,8,26,28),17,Folio.BONE)
	key.name = "MapCloseShortcut"
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var help = host._label(frame,"数字键 1 · Enter / 空格收起 · Esc 返回",Rect2(154,676,748,26),16,Folio.SECONDARY_INK)
	help.name = "DialogueHelp"
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func layout(frame: Control) -> void:
	var caption = frame.find_child("MapGuidanceCaption",true,false)
	var chart = frame.find_child("RegionChart",true,false)
	if not is_instance_valid(caption) or not is_instance_valid(chart): return
	frame.size = PAGE_SIZE
	frame.position = Vector2(20,28)
	caption.position = CAPTION_RECT.position
	caption.size.x = CAPTION_RECT.size.x
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_color",Folio.INK)
	# Preserve every line, including a loaded departure/parking note. The chart
	# grows uniformly in the remaining space; its geographic projection is fixed.
	caption.size.y = maxf(94,caption.get_combined_minimum_size().y)
	var chart_y: float = maxf(214,caption.position.y+caption.size.y+8)
	var magnification: float = minf(1.36,(FOOTER_Y-12-chart_y)/chart.CHART_SIZE.y)
	chart.scale = Vector2.ONE * maxf(.01,magnification)
	chart.position = Vector2(674-chart.CHART_SIZE.x*chart.scale.x*.5,chart_y)
	chart.queue_redraw()

class ClothSurface extends Control:
	func _draw() -> void:
		var sample: Rect2 = Folio.ATLAS_REGIONS.textile_sample
		for y: int in range(int(ceil(size.y/sample.size.y))):
			for x: int in range(int(ceil(size.x/sample.size.x))):
				var origin = Vector2(x,y)*sample.size
				var extent = Vector2(minf(sample.size.x,size.x-origin.x),minf(sample.size.y,size.y-origin.y))
				draw_texture_rect_region(Folio.BACKING,Rect2(origin,extent),Rect2(sample.position,extent))
		draw_rect(Rect2(Vector2.ZERO,size),Color(.015,.035,.045,.20))
		draw_rect(Rect2(Vector2(7,7),size-Vector2(14,14)),Folio.BRASS.darkened(.30),false,1)

class PaperSurface extends Control:
	func _draw() -> void:
		var sample: Rect2 = Folio.ATLAS_REGIONS.paper_sample
		for y: int in range(int(ceil(size.y/sample.size.y))):
			for x: int in range(int(ceil(size.x/sample.size.x))):
				var origin = Vector2(x,y)*sample.size
				var extent = Vector2(minf(sample.size.x,size.x-origin.x),minf(sample.size.y,size.y-origin.y))
				# Native-density reflected tiles join the same source edge texels.
				# A simple repeat reset the sample's lighting at every row and
				# produced visible wash bands in the first actual native frame.
				var flip = Vector2(-1 if x%2 else 1,-1 if y%2 else 1)
				var source_offset = Vector2(sample.size.x-extent.x if flip.x<0 else 0,sample.size.y-extent.y if flip.y<0 else 0)
				var anchor = origin+Vector2(extent.x if flip.x<0 else 0,extent.y if flip.y<0 else 0)
				draw_set_transform(anchor,0,flip)
				draw_texture_rect_region(Folio.BACKING,Rect2(Vector2.ZERO,extent),Rect2(sample.position+source_offset,extent))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.96,.93,.86,.25))
		draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),Folio.BRASS.darkened(.15),false,1)
		for x: int in range(9,int(size.x-9),37):
			draw_line(Vector2(x,size.y-2),Vector2(x+13,size.y-3),Color(.36,.27,.15,.20),1)
