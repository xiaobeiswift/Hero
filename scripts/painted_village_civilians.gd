class_name PaintedVillageCivilians
extends RefCounted
## Original non-combat idle figures, distinct from the named cast.
const PATH="res://assets/generated/characters/painted_village_civilians.png"
const CELL=Vector2(256,256)
const FOOT=Vector2(128,241)
const ROLES={"porter":0,"resident":1,"clerk":2}
static var _atlas:Texture2D
static var _frames:Dictionary={}
static func texture_for(role:String)->AtlasTexture:
	if not ROLES.has(role):return null
	if _frames.has(role):return _frames[role]
	if _atlas==null:
		if not ResourceLoader.exists(PATH):return null
		_atlas=load(PATH)
	var image=AtlasTexture.new();image.atlas=_atlas;image.region=Rect2(ROLES[role]*256,0,256,256);image.filter_clip=true;_frames[role]=image;return image
static func drawing_rect(foot:Vector2,cell_size:float=72)->Rect2:
	return Rect2(foot-FOOT*cell_size/256.0,Vector2.ONE*cell_size)
static func draw_idle(canvas:CanvasItem,foot:Vector2,role:String)->bool:
	var image=texture_for(role)
	if image==null:return false
	canvas.draw_texture_rect(image,drawing_rect(foot),false);return true
