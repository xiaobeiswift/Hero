class_name PaintedNoticeboard
extends RefCounted
## Original painted prop; coordinates are visual and do not alter interaction reach.
const PATH="res://assets/generated/environment/qingwei_noticeboard.png"
const REGION=Rect2(35,139,1201,992)
const FOOT=Vector2(600,983)
const WIDTH=84.0
static var _texture:AtlasTexture
static func texture()->AtlasTexture:
	if _texture==null and ResourceLoader.exists(PATH):
		_texture=AtlasTexture.new()
		_texture.atlas=load(PATH)
		_texture.region=REGION
		_texture.filter_clip=true
	return _texture
static func drawing_rect(foot:Vector2)->Rect2:
	var ratio=WIDTH/REGION.size.x
	return Rect2(foot-FOOT*ratio,REGION.size*ratio)
static func draw(canvas:CanvasItem,foot:Vector2)->bool:
	var image=texture()
	if image==null:return false
	canvas.draw_texture_rect(image,drawing_rect(foot),false)
	return true
