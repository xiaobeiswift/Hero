class_name PaintedQinSprite
extends RefCounted
## Four original authored walking keys per direction; no mirror, mesh warp or bob.
## API follows the other exploration actors. The 72px argument is the logical cell
## height, as in Shen/Tang, with a fixed ground/pelvis anchor and fixed pixel scale.
const CELL := Vector2(672, 672)
const FOOT := Vector2(336, 633)
const FRAME_COUNT := 4
const DIRECTIONS := ["front", "right", "back", "left"]
const FRAME_ORDER := {"front": [0, 3, 2, 1], "right": [0, 1, 2, 3],
    "back": [0, 3, 2, 1], "left": [0, 1, 2, 3]}
const REGIONS := {
    "front": [
        Rect2(192, 8, 392, 602),
        Rect2(752, 5, 381, 610),
        Rect2(195, 634, 374, 596),
        Rect2(781, 633, 377, 601),
    ],
    "right": [
        Rect2(115, 12, 537, 606),
        Rect2(725, 14, 378, 606),
        Rect2(120, 630, 564, 597),
        Rect2(788, 630, 358, 600),
    ],
    "back": [
        Rect2(156, 12, 369, 606),
        Rect2(718, 10, 359, 608),
        Rect2(178, 623, 347, 607),
        Rect2(719, 624, 356, 606),
    ],
    "left": [
        Rect2(107, 11, 501, 603),
        Rect2(837, 11, 308, 603),
        Rect2(107, 619, 501, 595),
        Rect2(800, 621, 398, 606),
    ],
}
const MARGINS := {
    "front": [Vector2(163, 39), Vector2(149, 31), Vector2(161, 45), Vector2(170, 40)],
    "right": [Vector2(66, 35), Vector2(81, 35), Vector2(58, 44), Vector2(136, 41)],
    "back": [Vector2(127, 35), Vector2(133, 33), Vector2(150, 34), Vector2(140, 35)],
    "left": [Vector2(88, 38), Vector2(203, 38), Vector2(91, 46), Vector2(168, 35)],
}
const IDLE_PATH := "res://assets/generated/characters/painted_qin_idle.png"
const IDLE_SCALE := 1.125
const IDLE_REGIONS := {
    "front": Rect2(233, 49, 289, 553),
    "left": Rect2(799, 53, 259, 551),
    "back": Rect2(234, 646, 288, 546),
    "right": Rect2(798, 649, 254, 542),
}
const IDLE_MARGINS := {
    "front": Vector2(191, 88),
    "left": Vector2(207, 90),
    "back": Vector2(190, 95),
    "right": Vector2(201, 99),
}
static var _idle_atlas: Texture2D
static var _idle_frames: Dictionary = {}
static var _atlases: Dictionary = {}
static var _frames: Dictionary = {}

static func direction_for(facing: Vector2) -> String:
    if absf(facing.x) > absf(facing.y):
        return "right" if facing.x > 0 else "left"
    return "back" if facing.y < 0 else "front"

static func texture_for(direction: String, frame: int) -> AtlasTexture:
    if not REGIONS.has(direction):
        return null
    var index := posmod(frame, FRAME_COUNT)
    var key := direction + str(index)
    if _frames.has(key):
        return _frames[key]
    if not _atlases.has(direction):
        var path := "res://assets/generated/characters/painted_qin_walk_%s.png" % direction
        if not ResourceLoader.exists(path):
            return null
        _atlases[direction] = load(path) as Texture2D
    if _atlases[direction] == null:
        return null
    var source_index: int = FRAME_ORDER[direction][index]
    var region: Rect2 = REGIONS[direction][source_index]
    var texture := AtlasTexture.new()
    texture.atlas = _atlases[direction]
    texture.region = region
    texture.margin = Rect2(MARGINS[direction][source_index], CELL - region.size)
    texture.filter_clip = true
    _frames[key] = texture
    return texture

static func idle_texture_for(direction: String) -> AtlasTexture:
    if not IDLE_REGIONS.has(direction):
        return null
    if _idle_frames.has(direction):
        return _idle_frames[direction]
    if _idle_atlas == null:
        if not ResourceLoader.exists(IDLE_PATH):
            return null
        _idle_atlas = load(IDLE_PATH) as Texture2D
    if _idle_atlas == null:
        return null
    var region: Rect2 = IDLE_REGIONS[direction]
    var texture := AtlasTexture.new()
    texture.atlas = _idle_atlas
    texture.region = region
    texture.margin = Rect2(IDLE_MARGINS[direction], CELL - region.size)
    texture.filter_clip = true
    _idle_frames[direction] = texture
    return texture

static func drawing_rect(foot_position: Vector2, height: float = 72.0) -> Rect2:
    var scale_factor := height / CELL.y
    return Rect2(foot_position - FOOT * scale_factor, CELL * scale_factor)

static func draw_frame(canvas: CanvasItem, foot_position: Vector2, facing: Vector2,
        frame: int, height: float = 72.0) -> bool:
    var texture := texture_for(direction_for(facing), frame)
    if texture == null:
        return false
    canvas.draw_texture_rect(texture, drawing_rect(foot_position, height), false)
    return true

## Caller owns radians. Each authored key spans one quarter of the walk cycle.
## Idle uses separate neutral standing art, with one fixed source-scale correction.
static func draw(canvas: CanvasItem, foot_position: Vector2, facing: Vector2,
        moving: bool, walk_phase: float, height: float = 72.0) -> bool:
    if not moving:
        var texture := idle_texture_for(direction_for(facing))
        if texture == null:
            return false
        canvas.draw_texture_rect(texture, drawing_rect(foot_position, height * IDLE_SCALE), false)
        return true
    var frame := posmod(floori(walk_phase * float(FRAME_COUNT) / TAU), FRAME_COUNT)
    return draw_frame(canvas, foot_position, facing, frame, height)
