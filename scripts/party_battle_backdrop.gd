class_name PartyBattleBackdrop
extends RefCounted
## Paint-only location choice for the existing 1280 x 685 party arena.
## The caller owns its original floor mesh, feet, actor paths and all battle facts.
const Ferry = preload("res://scripts/ferry_battle_backdrop.gd")
const Lantern = preload("res://scripts/painted_lantern_post.gd")
const VillageEnvironment = preload("res://scripts/qingwei_environment_art.gd")
const Tiles = preload("res://scripts/world_material_tiles.gd")
const WOOD = preload("res://assets/generated/environment/qingwei_deck_wood.png")
const EARTH = preload("res://assets/generated/environment/qingwei_moss_earth.png")
const FONT = preload("res://assets/fonts/NotoSansSC.otf")

# An explicit, bounded visual mapping. The seven other accepted encounters,
# a missing encounter and any future unknown ID retain the existing ferry.
const ENCOUNTER_STYLES = {
	"training": "courtyard",
	"sect_trial": "courtyard",
	"courtyard_practice": "courtyard",
	"heting_consignee": "warehouse",
}
const CAPSTONE_ENCOUNTER = "capstone_authorizer"
const ARCHIVE_PLAQUE = "霜桥印台"
const FIELD = Rect2(0, 0, 1280, 685)
const APRON = Rect2(0, 278, 1280, 407)
# Keep the original hall's steps behind y=320, with the left party silhouettes
# clear of its plaster walls. These are decoration coordinates, never nav data.
const HALL = {"type": "hall", "pos": Vector2(653, 201), "size": Vector2(380, 74)}
const WAREHOUSE = {"type":"hall", "pos":Vector2(676,173), "size":Vector2(435,110)}
const FLOOR_BASE = Color(.88, .87, .76)
const FLOOR_DETAIL = Color(1, 1, 1, .50)
const HALL_TINT = Color(.81, .86, .76)
const FAR_WILLOW_TINT = Color(.66, .78, .66, .52)
const NEAR_WILLOW_TINT = Color(.76, .84, .69, .93)

static var _prepared: bool = false
static var _hall_texture: Texture2D
static var _willow_texture: Texture2D
static var _hall_rect: Rect2
static var _plaque_rect: Rect2
static var _warehouse_rect: Rect2
static var _warehouse_plaque: Rect2
static var _apron_mesh: ArrayMesh
static var _far_willows: Array[Rect2] = []
static var _near_willows: Array[Rect2] = []
# Persistent draw arrays: court animation never builds geometry or resources.
static var _sky_points = PackedVector2Array([Vector2(0,0), Vector2(1280,0), Vector2(1280,320), Vector2(0,320)])
static var _sky_colors = PackedColorArray([Color("304b3e"), Color("304b3e"), Color("81927b"), Color("81927b")])
static var _ground_points = PackedVector2Array([Vector2(0,278), Vector2(1280,278), Vector2(1280,685), Vector2(0,685)])
static var _ground_colors = PackedColorArray([Color("596b52"), Color("596b52"), Color("82906d"), Color("82906d")])
static var _horizon_points = PackedVector2Array([Vector2(0,278), Vector2(1280,278), Vector2(1280,338), Vector2(0,338)])
static var _horizon_colors = PackedColorArray([Color(.22,.34,.25,.42), Color(.22,.34,.25,.42), Color(.22,.34,.25,0), Color(.22,.34,.25,0)])
static var _top_points = PackedVector2Array([Vector2(0,0), Vector2(1280,0), Vector2(1280,156), Vector2(0,156)])
static var _top_colors = PackedColorArray([Color(.07,.14,.11,.78), Color(.07,.14,.11,.78), Color(.07,.14,.11,0), Color(.07,.14,.11,0)])
# Warehouse-only paint caches. The earth keeps its original 512-unit mirrored
# sampling; the extra row changes only opacity, never the shared combat floor.
const WAREHOUSE_APRON_FADE = 64.0
const WAREHOUSE_APRON_OPACITY = .28
static var _warehouse_sky_points = PackedVector2Array([Vector2(0,0), Vector2(1280,0), Vector2(1280,685), Vector2(0,685)])
static var _warehouse_sky_colors = PackedColorArray([Color("637f75"), Color("637f75"), Color("858f77"), Color("858f77")])
# One subdued irregular shore borrows Heting's distant-shore silhouette. Its
# bottom fades away before the apron; no hard full-width horizon is introduced.
static var _warehouse_shore_points = PackedVector2Array([Vector2(0,207), Vector2(120,219), Vector2(276,203), Vector2(448,222), Vector2(604,208), Vector2(746,222), Vector2(944,203), Vector2(1123,219), Vector2(1280,208), Vector2(1280,266), Vector2(0,266)])
static var _warehouse_shore_colors = PackedColorArray()
static var _warehouse_apron_mesh: ArrayMesh

static func _prepare_warehouse() -> void:
	for i: int in _warehouse_shore_points.size():
		_warehouse_shore_colors.append(Color(.29,.40,.37,.12 if i < 9 else 0.0))
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	var rows = PackedFloat32Array([APRON.position.y, APRON.position.y + WAREHOUSE_APRON_FADE, 512.0, APRON.end.y])
	for row: int in range(rows.size() - 1):
		for column: int in range(3):
			var left: float = column * 512.0
			var right: float = minf(left + 512.0, APRON.end.x)
			var tile_y: int = int(floor(rows[row] / 512.0))
			var corners = PackedVector2Array([Vector2(left,rows[row]), Vector2(right,rows[row]), Vector2(right,rows[row+1]), Vector2(left,rows[row+1])])
			for index: int in [0,1,2,0,2,3]:
				var point: Vector2 = corners[index]
				var uv: Vector2 = (point - Vector2(left,tile_y * 512.0)) / 512.0
				if column % 2 != 0: uv.x = 1.0 - uv.x
				if tile_y % 2 != 0: uv.y = 1.0 - uv.y
				vertices.append(Vector3(point.x,point.y,0))
				uvs.append(uv)
				colors.append(Color(1,1,1,WAREHOUSE_APRON_OPACITY * clampf((point.y - APRON.position.y) / WAREHOUSE_APRON_FADE,0.0,1.0)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	_warehouse_apron_mesh = ArrayMesh.new()
	_warehouse_apron_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

static func style_for(encounter_id: String) -> String:
	if encounter_id == CAPSTONE_ENCOUNTER: return "archive"
	return String(ENCOUNTER_STYLES.get(encounter_id, "ferry"))

static func floor_texture_for(encounter_id: String) -> Texture2D:
	return EARTH if style_for(encounter_id) in ["courtyard","warehouse","archive"] else WOOD

static func prepare() -> void:
	if _prepared: return
	_hall_texture = VillageEnvironment.texture_for("hall")
	_willow_texture = VillageEnvironment.texture_for("willow")
	_hall_rect = VillageEnvironment.building_rect(HALL)
	_plaque_rect = VillageEnvironment.plaque_rect(HALL)
	_warehouse_rect = VillageEnvironment.building_rect(WAREHOUSE)
	_warehouse_plaque = VillageEnvironment.plaque_rect(WAREHOUSE)
	_apron_mesh = Tiles.geometry(APRON, 512.0).mesh
	_prepare_warehouse()
	_far_willows.append(_willow_rect(Vector2(386,292), 1.92))
	_far_willows.append(_willow_rect(Vector2(602,298), 1.68))
	_near_willows.append(_willow_rect(Vector2(96,307), 3.12))
	_near_willows.append(_willow_rect(Vector2(1190,306), 2.86))
	Ferry.texture()
	Lantern.post_texture()
	_prepared = true

static func _willow_rect(foot: Vector2, scale_factor: float) -> Rect2:
	var draw_scale: float = (132.0 / 481.0) * scale_factor
	return Rect2(foot - Vector2(VillageEnvironment.ANCHORS.willow) * draw_scale, Vector2(VillageEnvironment.REGIONS.willow.size) * draw_scale)

static func draw(canvas: CanvasItem, floor_mesh: ArrayMesh, encounter_id: String, clock: float) -> void:
	prepare()
	if style_for(encounter_id) == "archive":
		_draw_warehouse(canvas, floor_mesh, ARCHIVE_PLAQUE)
	elif style_for(encounter_id) == "warehouse":
		_draw_warehouse(canvas, floor_mesh)
	elif style_for(encounter_id) == "courtyard":
		_draw_courtyard(canvas, floor_mesh)
	else:
		_draw_ferry(canvas, floor_mesh, clock)

static func _draw_courtyard(canvas: CanvasItem, floor_mesh: ArrayMesh) -> void:
	canvas.draw_rect(FIELD, Color("596b52"))
	canvas.draw_polygon(_sky_points, _sky_colors)
	# A textured side apron continues beneath the exact existing floor, so the
	# fixed choreography never appears suspended above an unrelated backdrop.
	canvas.draw_polygon(_ground_points, _ground_colors)
	if _apron_mesh:
		canvas.draw_mesh(_apron_mesh, EARTH, Transform2D.IDENTITY, Color(1,1,1,.20))
	if floor_mesh:
		# The existing six mirrored UV patches and vertex depth shade are reused.
		# A pale base keeps detail subdued without resampling the original earth.
		canvas.draw_mesh(floor_mesh, null, Transform2D.IDENTITY, FLOOR_BASE)
		canvas.draw_mesh(floor_mesh, EARTH, Transform2D.IDENTITY, FLOOR_DETAIL)
	canvas.draw_polygon(_horizon_points, _horizon_colors)
	if _willow_texture:
		for bounds: Rect2 in _far_willows:
			canvas.draw_texture_rect(_willow_texture, bounds, false, FAR_WILLOW_TINT)
		for bounds: Rect2 in _near_willows:
			canvas.draw_texture_rect(_willow_texture, bounds, false, NEAR_WILLOW_TINT)
	if _hall_texture:
		canvas.draw_texture_rect(_hall_texture, _hall_rect, false, HALL_TINT)
		canvas.draw_string(FONT, _plaque_rect.position + Vector2(0, _plaque_rect.size.y * .79), "练 武 堂", HORIZONTAL_ALIGNMENT_CENTER, _plaque_rect.size.x, 15, Color("e2d2a7"))
	canvas.draw_polygon(_top_points, _top_colors)

static func ground_point(x: float, y: float) -> Vector2:
	return Vector2(lerpf(110.0 - 150.0*y,1170.0 + 150.0*y,x),lerpf(320.0,682.0,y))

static func _draw_ferry(canvas: CanvasItem, floor_mesh: ArrayMesh, clock: float) -> void:
	# This is the original party renderer's pre-actor draw block, with only the
	# canvas/mesh/clock ownership changed. Its ferry pixels and prop order remain.
	canvas.draw_rect(Rect2(0,0,1280,685),Color("10272a"))
	var background = Ferry.texture()
	if background: canvas.draw_texture_rect(background,Rect2(0,-25,1280,486),false,Color(.83,.92,.94))
	if floor_mesh: canvas.draw_mesh(floor_mesh,WOOD)
	canvas.draw_line(ground_point(0,0),ground_point(1,0),Color("4a5046"),13,true)
	canvas.draw_line(ground_point(0,0)+Vector2(0,3),ground_point(1,0)+Vector2(0,3),Color("92927a"),2,true)
	for y: float in [.32,.68]: canvas.draw_line(ground_point(0,y),ground_point(1,y),Color(.05,.12,.13,.25),2,true)
	for foot: Vector2 in [Vector2(115,337),Vector2(1165,337)]:
		canvas.draw_set_transform(foot,0,Vector2.ONE*2.05); Lantern.draw(canvas,Vector2.ZERO,clock); canvas.draw_set_transform(Vector2.ZERO)

static func _draw_warehouse(canvas: CanvasItem, floor_mesh: ArrayMesh, plaque: String = "北 仓 交 割") -> void:
	# Reuse the actual harbor warehouse's original hall art, earth and deck.
	# All combat floor geometry/feet remain the shared controller's coordinates.
	canvas.draw_polygon(_warehouse_sky_points, _warehouse_sky_colors)
	canvas.draw_polygon(_warehouse_shore_points, _warehouse_shore_colors)
	if _warehouse_apron_mesh: canvas.draw_mesh(_warehouse_apron_mesh, EARTH)
	if floor_mesh:
		canvas.draw_mesh(floor_mesh,null,Transform2D.IDENTITY,Color(.85,.83,.69))
		canvas.draw_mesh(floor_mesh,EARTH,Transform2D.IDENTITY,Color(1,1,1,.54))
	if _hall_texture:
		canvas.draw_texture_rect(_hall_texture,_warehouse_rect,false,Color(.93,.94,.85))
		canvas.draw_string(FONT,_warehouse_plaque.position+Vector2(0,_warehouse_plaque.size.y*.79),plaque,HORIZONTAL_ALIGNMENT_CENTER,_warehouse_plaque.size.x,15,Color("e7d8b5"))
	# Bound papers and low loading boards identify a working store, not a hall.
	for x: float in [610,1142]:
		canvas.draw_rect(Rect2(x,249,54,40),Color("635e47"))
		canvas.draw_rect(Rect2(x+7,253,39,27),Color("d8cfb1"))
		for line: int in range(3): canvas.draw_line(Vector2(x+13,260+line*6),Vector2(x+39,260+line*6),Color("647568"),1.0)
