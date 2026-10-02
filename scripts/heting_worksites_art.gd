class_name HetingWorksitesArt
extends RefCounted
const PATH="res://assets/generated/environment/heting_worksites_atlas.png"
const SPRITES={
	"public_scale":{"region":Rect2(8, 8, 256, 200),"foot":Vector2(128.1818, 197.7401),"bounds":Vector2(128, 100)},
	"soup_pot_hot":{"region":Rect2(272, 8, 140, 120),"foot":Vector2(70.1994, 118.3911),"bounds":Vector2(70, 60)},
	"soup_pot_cold":{"region":Rect2(272, 136, 140, 120),"foot":Vector2(70.1994, 118.3911),"bounds":Vector2(70, 60)},
	"folded_tarpaulin":{"region":Rect2(8, 224, 192, 76),"foot":Vector2(95.9509, 74.3772),"bounds":Vector2(96, 38)},
	"rope_coil":{"region":Rect2(208, 224, 52, 24),"foot":Vector2(26.0, 23.5082),"bounds":Vector2(26, 12)},
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

static func scale_pan_positions(foot:Vector2)->Array[Vector2]:
	var origin=drawing_rect("public_scale",foot).position
	var scale=factor_for("public_scale")
	return [origin+Vector2(42.9091, 114.1243)*scale,origin+Vector2(213.4545, 114.1243)*scale]

static func steam_origin(foot:Vector2)->Vector2:
	return drawing_rect("soup_pot_hot",foot).position+Vector2(69.9335, 22.9274)*factor_for("soup_pot_hot")

static func pot_id(cooked:bool)->String:return "soup_pot_hot" if cooked else "soup_pot_cold"
static func draw_coil(canvas:CanvasItem,center:Vector2)->bool:
	var foot=center+(SPRITES.rope_coil.foot-Vector2(26,12))*factor_for("rope_coil")
	return draw(canvas,"rope_coil",foot)
