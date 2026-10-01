class_name QingweiWaterMaterial
extends RefCounted
## Static original painting clipped to the existing village water geometry.
const PATH="res://assets/generated/environment/qingwei_water_surface.png"
const POND_CENTER=Vector2(998,484)
const POND_RADIUS=Vector2(163,115)
const POND_RECT=Rect2(835,369,326,230)
const RIVER_RECT=Rect2(1451,558,149,492)
static var _texture:Texture2D
static var _pond_points=PackedVector2Array()
static var _pond_uvs=PackedVector2Array()
static var _river_points=PackedVector2Array([Vector2(1451,620),Vector2(1600,558),Vector2(1600,1050),Vector2(1451,1050)])
static var _river_uvs=PackedVector2Array()
static func texture()->Texture2D:
	if _texture==null and ResourceLoader.exists(PATH):_texture=load(PATH)
	return _texture
static func uv_for(point:Vector2,area:Rect2)->Vector2:
	return (point-area.get_center())/maxf(area.size.x,area.size.y)+Vector2(.5,.5)
static func prepare()->void:
	if not _pond_points.is_empty():return
	for i in range(64):
		var angle=i*TAU/64.0
		var p=POND_CENTER+Vector2(cos(angle),sin(angle))*POND_RADIUS
		_pond_points.append(p);_pond_uvs.append(uv_for(p,POND_RECT))
	for p in _river_points:_river_uvs.append(uv_for(p,RIVER_RECT))
static func pond(canvas:CanvasItem)->bool:
	var image=texture()
	if image==null:return false
	prepare();canvas.draw_polygon(_pond_points,PackedColorArray([Color(1,1,1,.72)]),_pond_uvs,image)
	return true
static func river(canvas:CanvasItem)->bool:
	var image=texture()
	if image==null:return false
	prepare();canvas.draw_polygon(_river_points,PackedColorArray([Color(1,1,1,.66)]),_river_uvs,image)
	return true
