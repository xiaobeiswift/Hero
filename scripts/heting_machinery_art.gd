class_name HetingMachineryArt
extends RefCounted
## Original atlas. Preserve aspect and authored feet; navigation stays in HetingRegion.
const PATH="res://assets/generated/environment/heting_machinery_atlas.png"
const SPRITES={
	"rope_winch":{"region":Rect2(6, 36, 244, 183),"foot":Vector2(120.016, 159.754),"bounds":Vector2(104, 75)},
	"timber_crane":{"region":Rect2(270, 6, 228, 244),"foot":Vector2(77.9, 217.365),"bounds":Vector2(120, 110)},
	"loaded_grain_cart":{"region":Rect2(518, 27, 244, 201),"foot":Vector2(125.82, 190.797),"bounds":Vector2(34, 32)},
	"sack_stack":{"region":Rect2(774, 35, 244, 186),"foot":Vector2(124.132, 171.765),"bounds":Vector2(30, 26)},
	"grain_basket_full":{"region":Rect2(6, 279, 244, 210),"foot":Vector2(123.537, 195.836),"bounds":Vector2(30, 26)},
	"grain_basket_empty":{"region":Rect2(262, 277, 244, 214),"foot":Vector2(122.0, 206.988),"bounds":Vector2(30, 26)},
	"cargo_hampers_sealed":{"region":Rect2(518, 273, 244, 221),"foot":Vector2(126.136, 205.473),"bounds":Vector2(30, 26)},
}
static var _atlas:Texture2D
static var _frames:Dictionary={}
static func texture_for(id:String)->AtlasTexture:
	if not SPRITES.has(id):return null
	if _frames.has(id):return _frames[id]
	if _atlas==null:
		if not ResourceLoader.exists(PATH):return null
		_atlas=load(PATH)
	var image=AtlasTexture.new()
	image.atlas=_atlas;image.region=SPRITES[id].region;image.filter_clip=true
	_frames[id]=image
	return image
static func factor_for(id:String,scale:float=1.0)->float:
	if not SPRITES.has(id):return 0
	var spec=SPRITES[id]
	return minf(spec.bounds.x/spec.region.size.x,spec.bounds.y/spec.region.size.y)*maxf(0,scale)
static func drawing_rect(id:String,foot:Vector2,scale:float=1.0)->Rect2:
	if not SPRITES.has(id):return Rect2()
	var spec=SPRITES[id]
	var factor=factor_for(id,scale)
	return Rect2(foot-spec.foot*factor,spec.region.size*factor)
static func opacity_for(id:String,foot:Vector2,actors:Array)->float:
	var area=drawing_rect(id,foot)
	for actor:Vector2 in actors:
		if actor.y<foot.y and area.intersects(Rect2(actor-Vector2(16,60),Vector2(32,64))):return .40
	return 1.0
static func draw(canvas:CanvasItem,id:String,foot:Vector2,scale:float=1.0,opacity:float=1.0)->bool:
	var image=texture_for(id)
	if image==null:return false
	canvas.draw_texture_rect(image,drawing_rect(id,foot,scale),false,Color(1,1,1,opacity))
	return true
