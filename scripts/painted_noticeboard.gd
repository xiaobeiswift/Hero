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
static func opacity_for(foot:Vector2,actors:Array)->float:
	var bounds=drawing_rect(foot)
	for actor:Vector2 in actors:
		# Include the visible body at the sides, not just its ground point.
		var body=Rect2(actor-Vector2(16,60),Vector2(32,64))
		if actor.y<foot.y and bounds.intersects(body):return .38
	return 1.0
static func draw(canvas:CanvasItem,foot:Vector2,opacity:float=1.0)->bool:
	var image=texture()
	if image==null:return false
	canvas.draw_texture_rect(image,drawing_rect(foot),false,Color(1,1,1,opacity))
	return true
