class_name PaintedBattleDuHui
extends RefCounted
## Original Du Hui combat keys. Presentation only: no battle rules or damage.
## Coordinates measured on the untouched imagegen v4 atlas, in atlas pixels.
## This helper intentionally supplies no walking cycle; idle can be stationary.

const PATH := "res://assets/generated/characters/painted_duhui_combat.png"
const CELL := Vector2(512, 512)
const DEFAULT_CELL_SIZE := 236.0
const POSES := {"idle": 0, "windup": 1, "strike": 2, "guard": 3, "hurt": 4, "kneel": 5}
const FOOT_ANCHORS := {
	"idle": Vector2(330, 472), "windup": Vector2(786, 474),
	"strike": Vector2(1336, 455), "guard": Vector2(300, 936),
	"hurt": Vector2(842, 936), "kneel": Vector2(1288, 928)
}
const CHEST_ANCHORS := {
	"idle": Vector2(300, 212), "windup": Vector2(770, 236),
	"strike": Vector2(1320, 240), "guard": Vector2(294, 710),
	"hurt": Vector2(795, 711), "kneel": Vector2(1282, 766)
}
const WEAPON_ANCHORS := {
	"idle": Vector2(99, 360), "windup": Vector2(780, 86),
	"strike": Vector2(1088, 226), "guard": Vector2(182, 582),
	"hurt": Vector2(571, 861), "kneel": Vector2(1236, 918)
}
## Conservative visible bounds: all source pixels with alpha > 2/255.
## Untouched PNG retains original <=2/255 fringe; no alpha cleanup or cut/paste.
const OPAQUE_BOUNDS := {
	"idle": Rect2(81, 78, 399, 398), "windup": Rect2(588, 70, 374, 408),
	"strike": Rect2(1072, 136, 421, 326), "guard": Rect2(116, 564, 367, 377),
	"hurt": Rect2(552, 574, 442, 366), "kneel": Rect2(1131, 604, 326, 333)
}
static var _atlas: Texture2D
static var _frames: Dictionary = {}

static func source_rect(pose: String) -> Rect2:
	if not POSES.has(pose):
		return Rect2()
	var index: int = POSES[pose]
	return Rect2(Vector2(index % 3, index / 3) * CELL, CELL)

static func texture_for(pose: String) -> AtlasTexture:
	if not POSES.has(pose):
		return null
	if _frames.has(pose):
		return _frames[pose]
	if _atlas == null:
		if not ResourceLoader.exists(PATH):
			return null
		_atlas = load(PATH)
	if _atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _atlas
	texture.region = source_rect(pose)
	texture.filter_clip = true
	_frames[pose] = texture
	return texture

static func pose_for(pose: Dictionary) -> String:
	if float(pose.get("defeat", 0)) > 0.25:
		return "kneel"
	if float(pose.get("recoil", 0)) > 0.12:
		return "hurt"
	if float(pose.get("guard", 0)) > 0.12:
		return "guard"
	if float(pose.get("strike", 0)) > 0.005:
		return "strike"
	if float(pose.get("windup", 0)) > 0.005:
		return "windup"
	return "idle"

static func drawing_rect(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Rect2:
	if not POSES.has(pose):
		return Rect2()
	var factor := cell_size / CELL.x
	var source := source_rect(pose)
	return Rect2(foot - (FOOT_ANCHORS[pose] - source.position) * factor, source.size * factor)

static func opaque_rect(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Rect2:
	if not OPAQUE_BOUNDS.has(pose):
		return Rect2()
	var factor := cell_size / CELL.x
	var bounds: Rect2 = OPAQUE_BOUNDS[pose]
	return Rect2(foot + (bounds.position - FOOT_ANCHORS[pose]) * factor, bounds.size * factor)

static func chest_point(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Vector2:
	if not CHEST_ANCHORS.has(pose):
		return foot
	return foot + (CHEST_ANCHORS[pose] - FOOT_ANCHORS[pose]) * (cell_size / CELL.x)

static func weapon_point(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Vector2:
	if not WEAPON_ANCHORS.has(pose):
		return foot
	return foot + (WEAPON_ANCHORS[pose] - FOOT_ANCHORS[pose]) * (cell_size / CELL.x)

static func draw(canvas: CanvasItem, foot: Vector2, pose: Dictionary, alpha: float = 1.0, cell_size: float = DEFAULT_CELL_SIZE) -> bool:
	var key := pose_for(pose)
	var texture := texture_for(key)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, drawing_rect(foot, cell_size, key), false, Color(1, 1, 1, clampf(alpha, 0, 1)))
	return true
