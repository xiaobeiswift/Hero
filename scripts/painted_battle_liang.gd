class_name PaintedBattleLiang
extends RefCounted
## Original presentation helper for six independently authored combat keys.
## Source PNG bytes are untouched. Only runtime regions and anchors are used.
## No walk cycle. Idle may be used as a stationary exploration NPC.

const PATH := "res://assets/generated/characters/painted_liang_combat_v4.png"
const REFERENCE_SIZE := 512.0
const DEFAULT_CELL_SIZE := 204.0
const NPC_CELL_SIZE := 72.0 * REFERENCE_SIZE / 455.0
const POSES := {"idle": 0, "windup": 1, "strike": 2, "guard": 3, "hurt": 4, "kneel": 5}
## Independent regions, not a uniform 2x3 grid. Wide strike has its own extent.
## Kneel excludes 44 detached corner pixels (max alpha 12/255); PNG stays untouched.
const SOURCE_REGIONS := {
	"idle": Rect2(0, 0, 690, 474), "windup": Rect2(690, 0, 564, 474),
	"strike": Rect2(0, 474, 750, 366), "guard": Rect2(750, 474, 504, 366),
	"hurt": Rect2(0, 840, 700, 414), "kneel": Rect2(700, 840, 530, 395)
}
const FOOT_ANCHORS := {
	"idle": Vector2(372, 464), "windup": Vector2(982, 465),
	"strike": Vector2(457, 828), "guard": Vector2(1040, 829),
	"hurt": Vector2(447, 1223), "kneel": Vector2(1030, 1211)
}
const CHEST_ANCHORS := {
	"idle": Vector2(373, 157), "windup": Vector2(965, 188),
	"strike": Vector2(396, 592), "guard": Vector2(1008, 607),
	"hurt": Vector2(409, 964), "kneel": Vector2(997, 1018)
}
const WEAPON_ANCHORS := {
	"idle": Vector2(169, 370), "windup": Vector2(1050, 33),
	"strike": Vector2(83, 558), "guard": Vector2(865, 524),
	"hurt": Vector2(195, 1157), "kneel": Vector2(828, 1172)
}
## Exact bounds of pixels whose alpha > 2/255, inclusive origin/exclusive end.
## Sub-threshold fringe is retained in the source, without alpha cleanup.
const OPAQUE_BOUNDS := {
	"idle": Rect2(137, 13, 339, 455), "windup": Rect2(772, 18, 400, 449),
	"strike": Rect2(28, 477, 655, 355), "guard": Rect2(821, 478, 376, 355),
	"hurt": Rect2(150, 846, 444, 380), "kneel": Rect2(794, 893, 410, 322)
}
static var _atlas: Texture2D
static var _frames: Dictionary = {}

static func source_rect(pose: String) -> Rect2:
	return SOURCE_REGIONS.get(pose, Rect2())

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
	var factor := cell_size / REFERENCE_SIZE
	var source := source_rect(pose)
	return Rect2(foot - (FOOT_ANCHORS[pose] - source.position) * factor, source.size * factor)

static func opaque_rect(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Rect2:
	if not OPAQUE_BOUNDS.has(pose):
		return Rect2()
	var factor := cell_size / REFERENCE_SIZE
	var bounds: Rect2 = OPAQUE_BOUNDS[pose]
	return Rect2(foot + (bounds.position - FOOT_ANCHORS[pose]) * factor, bounds.size * factor)

static func chest_point(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Vector2:
	if not CHEST_ANCHORS.has(pose):
		return foot
	return foot + (CHEST_ANCHORS[pose] - FOOT_ANCHORS[pose]) * (cell_size / REFERENCE_SIZE)

static func weapon_point(foot: Vector2, cell_size: float = DEFAULT_CELL_SIZE, pose: String = "idle") -> Vector2:
	if not WEAPON_ANCHORS.has(pose):
		return foot
	return foot + (WEAPON_ANCHORS[pose] - FOOT_ANCHORS[pose]) * (cell_size / REFERENCE_SIZE)

static func draw(canvas: CanvasItem, foot: Vector2, pose: Dictionary, alpha: float = 1.0, cell_size: float = DEFAULT_CELL_SIZE) -> bool:
	var key := pose_for(pose)
	var texture := texture_for(key)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, drawing_rect(foot, cell_size, key), false, Color(1, 1, 1, clampf(alpha, 0, 1)))
	return true
