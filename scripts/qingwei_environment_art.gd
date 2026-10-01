class_name QingweiEnvironmentArt
extends RefCounted
## Original imagegen atlas, kept byte-for-byte unchanged.
## Atlas layout is intentionally measured rather than assumed equal cells.
## All offsets are visual only: do not use these bounds for navigation/collision.
const PATH := "res://assets/generated/environment/qingwei_environment_atlas.png"
const REGIONS := {
	"clinic": Rect2(18, 114, 486, 330),
	"tea": Rect2(520, 94, 500, 357),
	"inn": Rect2(1020, 56, 499, 401),
	"hall": Rect2(14, 546, 568, 397),
	"shrine": Rect2(612, 563, 345, 379),
	"willow": Rect2(1042, 508, 481, 458),
}
## Door threshold / root position within each measured region.
const ANCHORS := {
	"clinic": Vector2(243, 297),
	"tea": Vector2(239, 317),
	"inn": Vector2(249, 345),
	"hall": Vector2(281, 340),
	"shrine": Vector2(177, 314),
	"willow": Vector2(263, 438),
}
## Blank plaque bounds, local to each source region. Draw names with the game font.
const PLAQUES := {
	"clinic": Rect2(193, 141, 98, 27),
	"tea": Rect2(181, 161, 106, 24),
	"inn": Rect2(198, 166, 111, 27),
	"hall": Rect2(208, 162, 134, 31),
	"shrine": Rect2(136, 154, 83, 23),
}
static var _atlas: Texture2D
static var _regions: Dictionary = {}

static func texture_for(id: String) -> AtlasTexture:
	if not REGIONS.has(id):
		return null
	if _regions.has(id):
		return _regions[id]
	if _atlas == null:
		if not ResourceLoader.exists(PATH):
			return null
		_atlas = load(PATH) as Texture2D
	if _atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = REGIONS[id]
	texture.filter_clip = true
	_regions[id] = texture
	return texture

static func building_rect(b: Dictionary) -> Rect2:
	var id: String = String(b.get("type", ""))
	if not REGIONS.has(id):
		return Rect2()
	var p: Vector2 = b["pos"]
	var size: Vector2 = b["size"]
	var source: Rect2 = REGIONS[id]
	var width := size.x + (28.0 if id == "shrine" else 50.0)
	var scale_factor := width / source.size.x
	var anchor: Vector2 = ANCHORS[id]
	var threshold := p + Vector2(size.x * 0.5, size.y)
	return Rect2(threshold - anchor * scale_factor, source.size * scale_factor)

static func draw_building(canvas: CanvasItem, b: Dictionary) -> bool:
	var id: String = String(b.get("type", ""))
	var texture := texture_for(id)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, building_rect(b), false)
	return true

static func plaque_rect(b: Dictionary) -> Rect2:
	var id: String = String(b.get("type", ""))
	if not PLAQUES.has(id):
		return Rect2()
	var source: Rect2 = REGIONS[id]
	var target := building_rect(b)
	var scale_factor := target.size.x / source.size.x
	var plaque: Rect2 = PLAQUES[id]
	return Rect2(target.position + plaque.position * scale_factor, plaque.size * scale_factor)

static func draw_willow(canvas: CanvasItem, foot: Vector2, scale_factor: float = 1.0) -> bool:
	var texture := texture_for("willow")
	if texture == null:
		return false
	var draw_scale := (132.0 / 481.0) * scale_factor
	var anchor: Vector2 = ANCHORS["willow"]
	var source: Rect2 = REGIONS["willow"]
	canvas.draw_texture_rect(texture, Rect2(foot - anchor * draw_scale, source.size * draw_scale), false)
	return true
