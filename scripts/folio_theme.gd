extends RefCounted
## Presentation-only folio materials, native marks and control treatments.
## This helper deliberately has no game-state, session or persistence dependencies.
const INK = Color("101f22")
const CLOTH = Color("1c3036")
const PAPER = Color("ded7c5")
const BONE = Color("f1e9d8")
const BRASS = Color("b5a078")
const CINNABAR = Color("9c4234")
const SECONDARY_INK = Color("3d3428")
const DISABLED_BACKING = Color("283337")
const DISABLED_TEXT = Color("b7b3a8")
const BODY_FONT = preload("res://assets/fonts/NotoSansSC.otf")
const HEADING_FONT = preload("res://assets/fonts/NotoSerifSC-Regular.woff2")
const BACKING = preload("res://assets/generated/ui/hero_folio_backing_v1.png")
const ATLAS_REGIONS = {
	"folio": Rect2(44,52,1496,890),
	"spine": Rect2(44,52,145,890),
	"index": Rect2(190,62,360,870),
	"textile_sample": Rect2(260,110,240,340),
	"page": Rect2(554,80,968,840),
	"paper_sample": Rect2(605,100,370,165),
	"decorative_scene": Rect2(900,270,615,540),
}
static func heading_font() -> Font:
	return HEADING_FONT

static func atlas(region_name: String) -> AtlasTexture:
	var texture = AtlasTexture.new()
	texture.atlas = BACKING
	texture.region = ATLAS_REGIONS[region_name]
	texture.filter_clip = true
	return texture

static func backing(parent: Control, rect: Rect2) -> TextureRect:
	var art = TextureRect.new()
	art.name = "FolioDecorativeBacking"
	art.position = rect.position
	art.size = rect.size
	art.texture = atlas("folio")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The complete 1496:890 folio keeps its proportion, including the right-hand scene.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func material(parent: Control, rect: Rect2, region_name: String, opacity: float = 1.0) -> NinePatchRect:
	var surface = NinePatchRect.new()
	surface.name = "FolioMaterial_" + region_name
	surface.position = rect.position
	surface.size = rect.size
	surface.texture = atlas(region_name)
	surface.patch_margin_left = 16
	surface.patch_margin_right = 16
	surface.patch_margin_top = 16
	surface.patch_margin_bottom = 16
	surface.modulate.a = opacity
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
	return surface

static func style(background: Color, edge: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = edge
	result.set_border_width_all(width)
	result.set_corner_radius_all(0)
	result.content_margin_left = 10
	result.content_margin_right = 10
	result.content_margin_top = 6
	result.content_margin_bottom = 6
	return result

static func focus_style(dark: bool) -> StyleBoxFlat:
	var ring = style(Color.TRANSPARENT, BONE if dark else INK, 2)
	ring.set_expand_margin_all(3)
	return ring

static func skin_button(button: Button, role: String = "paper_quiet", selected: bool = false) -> void:
	var dark: bool = role in ["row", "cloth_quiet", "cloth_disclosure", "header_close", "auto", "primary"]
	var foreground: Color = BONE if dark else INK
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 17 if role == "auto" else 19)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, foreground)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT if dark else SECONDARY_INK)
	var normal: StyleBoxFlat = style(Color.TRANSPARENT)
	var hover: StyleBoxFlat = style(Color(1, .96, .85, .075) if dark else Color(.20, .13, .05, .06))
	var pressed: StyleBoxFlat = style(Color(1, .96, .85, .13) if dark else Color(.20, .13, .05, .11))
	var disabled: StyleBoxFlat = style(Color.TRANSPARENT)
	if role == "primary":
		normal = style(CINNABAR, BRASS, 1)
		hover = style(Color("8f382d"), BONE, 1)
		pressed = style(Color("81372d"), BRASS, 1)
		disabled = style(DISABLED_BACKING, BRASS.darkened(.35), 1)
		button.add_theme_font_override("font", heading_font())
		button.add_theme_font_size_override("font_size", 24)
	elif role == "header_close":
		# The text-free painting has no baked close strip; this backing is native.
		normal = style(Color("1b2c30"))
		hover = style(Color("2a4147"), BRASS, 1)
		pressed = style(INK, BRASS, 1)
	elif role == "auto":
		normal = style(Color(.06,.11,.12,.75), BRASS.darkened(.28), 1)
		hover = style(CLOTH.lightened(.08), BRASS, 1)
		pressed = style(CLOTH, BRASS, 1)
		disabled = style(DISABLED_BACKING, Color("61685f"), 1)
	elif role == "row":
		# Row labels are native children with their own ink, so never wash them out
		# by lightening their cloth/ribbon ground on hover or press.
		hover = style(Color.TRANSPARENT if selected else Color(.02,.04,.05,.18))
		pressed = style(Color.TRANSPARENT if selected else Color(.02,.04,.05,.32))
		hover.border_color = BONE if selected else BRASS
		hover.border_width_left = 1
		pressed.border_color = BONE
		pressed.border_width_left = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	var focus: StyleBoxFlat = focus_style(dark)
	if role in ["primary", "header_close", "row", "cloth_disclosure"]:
		# Inset row focus cannot clip when a middle row touches the scroll edge.
		# Primary/header focus stays over their guaranteed native dark fill.
		# Surrounding painted paper can contain both light and dark scenery.
		focus.set_expand_margin_all(-4)
	button.add_theme_stylebox_override("focus", focus)

static func scrollbar(bar: VScrollBar, dark: bool = false) -> void:
	bar.focus_mode = Control.FOCUS_NONE
	bar.custom_minimum_size.x = 10
	var track = style(Color(.03,.07,.08,.12) if dark else Color(.20,.15,.07,.10))
	var thumb = style(BRASS if dark else SECONDARY_INK)
	thumb.content_margin_left = 3
	thumb.content_margin_right = 3
	thumb.content_margin_top = 12
	thumb.content_margin_bottom = 12
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", thumb)
	bar.add_theme_stylebox_override("grabber_highlight", style(BONE if dark else INK))
	bar.add_theme_stylebox_override("grabber_pressed", style(BONE if dark else INK))

static func rule(parent: Control, rect: Rect2, color: Color = BRASS) -> ColorRect:
	var line = ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line

static func mark(parent: Control, kind: String, rect: Rect2, color: Color = BRASS) -> Control:
	var glyph = FolioMark.new()
	glyph.name = "FolioMark_" + kind
	glyph.kind = kind
	glyph.ink = color
	glyph.position = rect.position
	glyph.size = rect.size
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glyph)
	return glyph

static func reading_wash(parent: Control, rect: Rect2, strength: float = .94) -> Control:
	var wash = ReadingWash.new()
	wash.name = "FolioReadingWash"
	wash.position = rect.position
	wash.size = rect.size
	wash.strength = strength
	wash.paper_texture = atlas("paper_sample")
	wash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	return wash

class ReadingWash extends Control:
	var strength: float = .94
	var paper_texture: Texture2D
	func _draw() -> void:
		# A feathered paper wash, not an opaque rectangular card over the scene.
		# The reading column receives a calm backing; art beyond its edge remains clear.
		if paper_texture == null: return
		var columns: int = 48
		var source_size: Vector2 = paper_texture.get_size()
		for i: int in columns:
			var left: float = float(i) / columns
			var edge: float = clampf((1.0 - left) / .08, 0.0, 1.0)
			var tint = Color(1,1,1,strength * edge)
			var target = Rect2(left * size.x, 0, size.x / columns + 1, size.y)
			var source = Rect2(left * source_size.x, 0, source_size.x / columns, source_size.y)
			draw_texture_rect_region(paper_texture, target, source, tint)

class Ribbon extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(0,2), Vector2(w-10,0), Vector2(w-5,h*.18),
			Vector2(w-11,h*.39), Vector2(w,h*.57), Vector2(w-9,h*.76),
			Vector2(w-4,h-2), Vector2(0,h)
		]), Color("9c4234"))
		draw_line(Vector2(3,7), Vector2(3,h-7), Color("b5a078"), 1, true)
		draw_line(Vector2(3,7), Vector2(14,7), Color("b5a078"), 1, true)
		draw_line(Vector2(3,h-7), Vector2(14,h-7), Color("b5a078"), 1, true)

class FolioMark extends Control:
	var kind: String = "diamond"
	var ink: Color = Color("b5a078")
	func _draw() -> void:
		var center: Vector2 = size * .5
		var radius: float = minf(size.x,size.y) * .37
		if kind == "compass":
			draw_arc(center, radius, 0, TAU, 32, ink, 1.4, true)
			draw_line(center-Vector2(0,radius*1.34), center+Vector2(0,radius*1.34), ink, 1.4, true)
			draw_line(center-Vector2(radius*1.34,0), center+Vector2(radius*1.34,0), ink, 1.4, true)
			draw_colored_polygon(PackedVector2Array([
				center+Vector2(0,-radius), center+Vector2(radius*.24,0),
				center+Vector2(0,radius), center+Vector2(-radius*.24,0)
			]), ink)
		elif kind == "book":
			var x: float = size.x
			var y: float = size.y
			draw_polyline(PackedVector2Array([
				Vector2(x*.08,y*.19), Vector2(x*.30,y*.14), Vector2(x*.5,y*.25),
				Vector2(x*.70,y*.14), Vector2(x*.92,y*.19), Vector2(x*.92,y*.83),
				Vector2(x*.70,y*.78), Vector2(x*.5,y*.89), Vector2(x*.30,y*.78),
				Vector2(x*.08,y*.83), Vector2(x*.08,y*.19)
			]), ink, 1.6, true)
			draw_line(Vector2(x*.5,y*.25),Vector2(x*.5,y*.89),ink,1.3,true)
			for i: int in 3:
				var y_line: float = y * (.34 + i * .14)
				draw_line(Vector2(x*.19,y_line),Vector2(x*.38,y_line+.02*y),ink,1,true)
				draw_line(Vector2(x*.62,y_line+.02*y),Vector2(x*.81,y_line),ink,1,true)
		else:
			draw_polyline(PackedVector2Array([
				center+Vector2(0,-radius),center+Vector2(radius,0),
				center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)
			]),ink,1.6,true)
