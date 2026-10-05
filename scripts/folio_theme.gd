extends RefCounted
## Presentation-only folio materials, native marks and control treatments.
## This helper deliberately has no game-state, session or persistence dependencies.
const INK = Color("101f22")
const CLOTH = Color("1c3036")
const PAPER = Color("ded7c5")
const BONE = Color("f1e9d8")
const BRASS = Color("b5a078")
const CINNABAR = Color("7d3028")
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
		hover = style(Color("702b23"), BONE, 1)
		pressed = style(Color("63251f"), BRASS, 1)
		disabled = style(DISABLED_BACKING, BRASS.darkened(.35), 1)
		button.add_theme_font_override("font", heading_font())
		button.add_theme_font_size_override("font_size", 24)
		var ornament = PrimaryOrnament.new()
		ornament.name = "FolioPrimaryOrnament"
		ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(ornament)
		ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	if role in ["primary", "header_close", "row", "cloth_disclosure", "auto"]:
		# Inset row focus cannot clip when a middle row touches the scroll edge.
		# Primary/header/Auto focus stays over guaranteed native dark fill.
		# Auto is inset so its ring cannot meet the guidance continuation mark.
		# Surrounding painted paper can contain both light and dark scenery.
		focus.set_expand_margin_all(-4)
	button.add_theme_stylebox_override("focus", focus)

static func scrollbar(bar: VScrollBar, dark: bool = false) -> void:
	bar.focus_mode = Control.FOCUS_NONE
	bar.custom_minimum_size.x = 10
	# Generic button margins and theme arrows can force a 20px minimum width.
	# Keep a 10px native hit area, with a 2px rail and a 4px brass/ink thumb.
	for side: String in ["left", "right", "top", "bottom"]:
		bar.add_theme_constant_override("padding_" + side, 0)
	var blank = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)
	var spacer = ImageTexture.create_from_image(blank)
	for icon: String in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(icon, spacer)
	var track = _scrollbar_style(Color(.71,.63,.47,.20) if dark else Color(.20,.15,.07,.16), 4)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", _scrollbar_style(BRASS if dark else SECONDARY_INK, 3, 24))
	bar.add_theme_stylebox_override("grabber_highlight", _scrollbar_style(BONE if dark else INK, 2, 24))
	bar.add_theme_stylebox_override("grabber_pressed", _scrollbar_style(BONE if dark else INK, 2, 24))

static func _scrollbar_style(color: Color, inset: float, minimum_height: float = 0) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = color
	result.set_content_margin_all(0)
	result.content_margin_top = minimum_height * .5
	result.content_margin_bottom = minimum_height * .5
	result.expand_margin_left = -inset
	result.expand_margin_right = -inset
	result.set_corner_radius_all(1)
	return result

static func scroll_edges(parent: Control, bar: VScrollBar, rect: Rect2, dark: bool = false) -> Control:
	var edges = ScrollEdges.new()
	edges.name = String(bar.get_parent().name) + "ScrollEdges"
	edges.scroll_bar = bar
	edges.ink = BRASS if dark else SECONDARY_INK
	# Marks sit 4–7px outside the viewport, beyond its 3px focus ring.
	# No text, focus border, thumb or hit area is covered by a wash/mask.
	edges.position = rect.position - Vector2(0,7)
	edges.size = rect.size + Vector2(0,14)
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edges.focus_mode = Control.FOCUS_NONE
	parent.add_child(edges)
	return edges

class ScrollEdges extends Control:
	var scroll_bar: VScrollBar
	var ink: Color = BRASS
	var more_above: bool = false
	var more_below: bool = false
	func _ready() -> void:
		scroll_bar.changed.connect(_refresh_edges)
		scroll_bar.value_changed.connect(_value_changed)
		_refresh_edges()
	func _value_changed(_value: float) -> void:
		_refresh_edges()
	func _refresh_edges() -> void:
		if not is_instance_valid(scroll_bar): return
		var lower_limit: float = maxf(scroll_bar.min_value, scroll_bar.max_value - scroll_bar.page)
		var overflow: bool = lower_limit > scroll_bar.min_value + .5
		more_above = overflow and scroll_bar.value > scroll_bar.min_value + .5
		more_below = overflow and scroll_bar.value < lower_limit - .5
		visible = more_above or more_below
		queue_redraw()
	func _draw() -> void:
		var x: float = size.x * .5
		if more_above:
			draw_polyline(PackedVector2Array([Vector2(x-4,3), Vector2(x,0), Vector2(x+4,3)]), ink, 1.5, true)
		if more_below:
			draw_polyline(PackedVector2Array([Vector2(x-4,size.y-3), Vector2(x,size.y), Vector2(x+4,size.y-3)]), ink, 1.5, true)

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
	# The supplied rectangle is the full-strength reading area. Feather only
	# outside it, so the first/last glyphs and scrolled text keep their backing.
	var padded: Rect2 = rect.grow_individual(18, 20, 64, 24)
	wash.position = padded.position
	wash.size = padded.size
	wash.strength = strength
	wash.paper_texture = atlas("paper_sample")
	wash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	return wash

class ReadingWash extends Control:
	var strength: float = .94
	var paper_texture: Texture2D
	var wash_material: ShaderMaterial
	func _init() -> void:
		var shader = Shader.new()
		shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 wash_size = vec2(1.0);
varying vec2 wash_position;
void vertex() {
	wash_position = VERTEX;
}
void fragment() {
	float left = smoothstep(0.0, 18.0, wash_position.x);
	float right = 1.0 - smoothstep(wash_size.x - 64.0, wash_size.x, wash_position.x);
	float top = smoothstep(0.0, 20.0, wash_position.y);
	float bottom = 1.0 - smoothstep(wash_size.y - 24.0, wash_size.y, wash_position.y);
	COLOR.a *= left * right * top * bottom;
}
"""
		wash_material = ShaderMaterial.new()
		wash_material.shader = shader
		material = wash_material
	func _draw() -> void:
		# One sample of the existing paper atlas, with a continuous alpha field.
		# No overlapping strips, doubled alpha seams, or hard rectangular edge.
		if paper_texture == null: return
		wash_material.set_shader_parameter("wash_size", size)
		draw_texture_rect(paper_texture, Rect2(Vector2.ZERO, size), false, Color(1,1,1,strength))

class PrimaryOrnament extends Control:
	func _draw() -> void:
		var button: Button = get_parent() as Button
		var ink: Color = BRASS.darkened(.35) if button != null and button.disabled else BRASS
		for corner: Vector2 in [Vector2(8,8), Vector2(size.x-8,8), Vector2(8,size.y-8), Vector2(size.x-8,size.y-8)]:
			var inward = Vector2(1 if corner.x < size.x*.5 else -1, 1 if corner.y < size.y*.5 else -1)
			draw_line(corner, corner + Vector2(9*inward.x,0), ink, 1, true)
			draw_line(corner, corner + Vector2(0,6*inward.y), ink, 1, true)

class Ribbon extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(0,2), Vector2(w-10,0), Vector2(w-5,h*.18),
			Vector2(w-11,h*.39), Vector2(w,h*.57), Vector2(w-9,h*.76),
			Vector2(w-4,h-2), Vector2(0,h)
		]), Color("7d3028"))
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
