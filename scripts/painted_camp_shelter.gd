class_name PaintedCampShelter
extends RefCounted
## Original canvas shelter, aligned to the existing riverside campsite.
const PATH="res://assets/generated/environment/qingwei_camp_shelter.png"
const REGION=Rect2(57,48,1455,941)
const FOOT=Vector2(727,932)
const WIDTH=108.0
const WORLD_FOOT=Vector2(1339,735)
static var _texture:AtlasTexture
static func texture()->AtlasTexture:
	if _texture==null and ResourceLoader.exists(PATH):
		_texture=AtlasTexture.new();_texture.atlas=load(PATH);_texture.region=REGION;_texture.filter_clip=true
	return _texture
static func drawing_rect()->Rect2:
	var ratio=WIDTH/REGION.size.x
	return Rect2(WORLD_FOOT-FOOT*ratio,REGION.size*ratio)
static func opacity_for(actors:Array)->float:
	var bounds=drawing_rect()
	for actor:Vector2 in actors:
		if actor.y<WORLD_FOOT.y and bounds.has_point(actor):return .45
	return 1.0
static func draw(canvas:CanvasItem,opacity:float=1.0)->bool:
	var image=texture()
	if image==null:return false
	canvas.draw_texture_rect(image,drawing_rect(),false,Color(1,1,1,opacity));return true
