class_name PaintedVillageSprite
extends RefCounted
## Original painted idle artwork. Caller owns movement, shadow, layers and time.
## Four Shen directions are distinct authored poses, NOT a walk cycle.
const CAST_PATH := "res://assets/generated/characters/painted_village_idle.png"
const SHEN_PATH := "res://assets/generated/characters/painted_shen_directions.png"
const CELL := Vector2(256, 256)
const FOOT := Vector2(128, 241)
const CAST := {"elder": 0, "lubo": 0, "shen": 1, "healer": 1, "bandit": 2, "puheng": 2, "mentor": 3, "cenyuan": 3}
static var _atlases: Dictionary = {}
static var _frames: Dictionary = {}

static func direction_column(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 1 if facing.x > 0 else 3
	return 2 if facing.y < 0 else 0

static func texture_for(role: String, facing: Vector2 = Vector2.DOWN) -> AtlasTexture:
	if not CAST.has(role):
		return null
	var is_shen := role in ["shen", "healer"]
	var path := SHEN_PATH if is_shen else CAST_PATH
	var column: int = direction_column(facing) if is_shen else int(CAST[role])
	var key := path + ":" + str(column)
	if _frames.has(key):
		return _frames[key]
	if not _atlases.has(path):
		if not ResourceLoader.exists(path):
			return null
		_atlases[path] = load(path) as Texture2D
	if _atlases[path] == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _atlases[path]
	texture.region = Rect2(Vector2(column * 256, 0), CELL)
	texture.filter_clip = true
	_frames[key] = texture
	return texture

static func drawing_rect(foot_position: Vector2, cell_size: float = 72.0) -> Rect2:
	return Rect2(foot_position - FOOT * (cell_size / CELL.x), CELL * (cell_size / CELL.x))

static func draw_idle(canvas: CanvasItem, foot_position: Vector2, role: String,
		facing: Vector2 = Vector2.DOWN, cell_size: float = 72.0) -> bool:
	var texture := texture_for(role, facing)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, drawing_rect(foot_position, cell_size), false)
	return true
