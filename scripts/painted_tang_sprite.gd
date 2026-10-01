class_name PaintedTangSprite
extends RefCounted
## Original painted Tang cutout animation. Only art; no movement, collision or story state.
const PATH := "res://assets/generated/characters/painted_tang_walk.png"
const CELL := Vector2(256, 256)
const FOOT := Vector2(128, 241)
const ROWS := {"front": 0, "right": 1, "back": 2, "left": 3}
static var _atlas: Texture2D
static var _frames: Dictionary = {}

static func direction_for(facing: Vector2) -> String:
	if absf(facing.x) > absf(facing.y):
		return "right" if facing.x > 0 else "left"
	return "back" if facing.y < 0 else "front"

static func texture_for(direction: String, frame: int) -> AtlasTexture:
	if not ROWS.has(direction):
		return null
	var index := posmod(frame, 8)
	var key := direction + str(index)
	if _frames.has(key):
		return _frames[key]
	if _atlas == null:
		if not ResourceLoader.exists(PATH):
			return null
		_atlas = load(PATH) as Texture2D
	if _atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = Rect2(Vector2(index * 256, int(ROWS[direction]) * 256), CELL)
	texture.filter_clip = true
	_frames[key] = texture
	return texture

static func drawing_rect(foot_position: Vector2, cell_size: float = 72.0) -> Rect2:
	var scale_factor := cell_size / CELL.x
	return Rect2(foot_position - FOOT * scale_factor, CELL * scale_factor)

static func draw_frame(canvas: CanvasItem, foot_position: Vector2, facing: Vector2,
		frame: int, cell_size: float = 72.0) -> bool:
	var texture := texture_for(direction_for(facing), frame)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, drawing_rect(foot_position, cell_size), false)
	return true

## Convenience wrapper: walk_phase is radians, one complete walk cycle per TAU.
## Caller owns the phase clock. Idle always uses stable contact frame 0.
static func draw(canvas: CanvasItem, foot_position: Vector2, facing: Vector2,
		moving: bool, walk_phase: float, cell_size: float = 72.0) -> bool:
	var frame := posmod(floori(walk_phase * 8.0 / TAU), 8) if moving else 0
	return draw_frame(canvas, foot_position, facing, frame, cell_size)
