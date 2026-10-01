class_name PaintedLanternPost
extends RefCounted
## Separate original support and lantern keep the wood still while the lamp swings.
const PATH="res://assets/generated/environment/qingwei_lantern_post.png"
const SOURCE_SIZE=Vector2(1774,887)
const POST_REGION=Rect2(343,34,404,821)
const POST_FOOT=Vector2(100,812)
const POST_HOOK=Vector2(365,170)
const POST_HEIGHT=68.0
const LAMP_REGION=Rect2(1235,240,179,494)
const LOOP=Vector2(89,8)
const LAMP_HEIGHT=32.0
const POSITIONS=[Vector2(429,343),Vector2(782,350),Vector2(366,687),Vector2(808,846)]
static var _atlas:Texture2D
static var _post:AtlasTexture
static var _lamp_points=PackedVector2Array()
static var _lamp_uvs=PackedVector2Array()
static func texture()->Texture2D:
	if _atlas==null and ResourceLoader.exists(PATH):_atlas=load(PATH)
	return _atlas
static func post_texture()->AtlasTexture:
	if _post==null and texture()!=null:
		_post=AtlasTexture.new();_post.atlas=texture();_post.region=POST_REGION;_post.filter_clip=true
	return _post
static func post_rect(foot:Vector2)->Rect2:
	var ratio=POST_HEIGHT/POST_REGION.size.y
	return Rect2(foot-POST_FOOT*ratio,POST_REGION.size*ratio)
static func lamp_pivot(foot:Vector2)->Vector2:
	return foot+(POST_HOOK-POST_FOOT)*(POST_HEIGHT/POST_REGION.size.y)
static func _prepare()->void:
	if not _lamp_points.is_empty():return
	var ratio=LAMP_HEIGHT/LAMP_REGION.size.y
	var area=Rect2(-LOOP*ratio,LAMP_REGION.size*ratio)
	_lamp_points=PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
	for p in [LAMP_REGION.position,Vector2(LAMP_REGION.end.x,LAMP_REGION.position.y),LAMP_REGION.end,Vector2(LAMP_REGION.position.x,LAMP_REGION.end.y)]:_lamp_uvs.append(p/SOURCE_SIZE)
static func lamp_geometry(foot:Vector2,time:float)->Dictionary:
	_prepare();var pivot=lamp_pivot(foot);var angle=sin(time*1.5+foot.x*.02)*.07
	var points=PackedVector2Array()
	for p in _lamp_points:points.append(p.rotated(angle)+pivot)
	return {"points":points,"uvs":_lamp_uvs,"pivot":pivot}
static func draw(canvas:CanvasItem,foot:Vector2,time:float)->bool:
	var post=post_texture()
	if post==null:return false
	canvas.draw_texture_rect(post,post_rect(foot),false)
	var lamp=lamp_geometry(foot,time)
	canvas.draw_polygon(lamp.points,PackedColorArray([Color.WHITE]),lamp.uvs,texture())
	return true
