class_name PaintedBamboo
extends RefCounted
## One painted clump replaces the village's many per-leaf primitives.
const PATH="res://assets/generated/environment/qingwei_bamboo_clump.png"
const SOURCE_SIZE=Vector2(1286,1223)
const REGION=Rect2(65,2,1204,1198)
const FOOT=Vector2(485,1176)
static var _texture:Texture2D
static var _cache:Dictionary={}
static func texture()->Texture2D:
	if _texture==null and ResourceLoader.exists(PATH):_texture=load(PATH)
	return _texture
static func base_geometry(height:float)->Dictionary:
	if _cache.has(height):return _cache[height]
	var ratio=height/REGION.size.y
	var area=Rect2(-FOOT*ratio,REGION.size*ratio)
	var points=PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
	var source=PackedVector2Array([REGION.position,Vector2(REGION.end.x,REGION.position.y),REGION.end,Vector2(REGION.position.x,REGION.end.y)])
	var uvs=PackedVector2Array()
	for p in source:uvs.append(p/SOURCE_SIZE)
	var data={"points":points,"uvs":uvs};_cache[height]=data;return data
static func geometry(foot:Vector2,height:float,phase:float,mirror:bool=false)->Dictionary:
	var data=base_geometry(height);var points=PackedVector2Array()
	var anchor_y=FOOT.y/REGION.size.y
	var sway=sin(phase)*1.4
	for i in range(4):
		var p:Vector2=data.points[i]
		if mirror:p.x=-p.x
		p.x+=sway*(anchor_y if i<2 else anchor_y-1.0)
		points.append(p+foot)
	return {"points":points,"uvs":data.uvs}
static func draw(canvas:CanvasItem,foot:Vector2,count:int,time:float)->bool:
	var image=texture()
	if image==null:return false
	var data=geometry(foot,146.0 if count>=10 else 132.0,time*.6+foot.x*.01,count<10)
	canvas.draw_polygon(data.points,PackedColorArray([Color.WHITE]),data.uvs,image)
	return true
