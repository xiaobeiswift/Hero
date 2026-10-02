class_name PaintedBattleQin
extends RefCounted
## Original Qin He key poses. Crops preserve the long staff, never equal-cell cutoffs.
## Pose/foot/weapon anchors are presentation metadata; no gameplay state changes.
const PATH="res://assets/generated/characters/painted_qin_combat.png"
const NORMALIZATION=0.86
const SOURCE_RECTS={
	"idle":Rect2(96,16,320,496),"strike":Rect2(538,52,553,452),
	"protect":Rect2(1092,34,424,469),"hurt":Rect2(96,538,354,454),
	"down":Rect2(548,664,500,330),"recover":Rect2(1116,503,398,496)
}
const FOOT_ANCHORS={"idle":Vector2(260,507),"strike":Vector2(748,496),"protect":Vector2(1296,500),"hurt":Vector2(310,977),"down":Vector2(755,978),"recover":Vector2(1320,989)}
const WEAPON_ANCHORS={"idle":Vector2(349,122),"strike":Vector2(1076,155),"protect":Vector2(1482,185),"hurt":Vector2(322,969),"down":Vector2(1022,949),"recover":Vector2(1174,513)}
const OPAQUE_BOUNDS={"idle":Rect2(107,22,301,489),"strike":Rect2(544,60,543,440),"protect":Rect2(1095,44,407,459),"hurt":Rect2(105,545,336,436),"down":Rect2(555,672,484,315),"recover":Rect2(1124,503,379,489)}
const ALIASES={"attack":"strike","assist":"strike","guard":"protect","cover":"protect","hit":"hurt","fallen":"down"}
static var _atlas:Texture2D
static var _frames:Dictionary={}
static func canonical(pose:String)->String:return ALIASES.get(pose,pose)
static func texture_for(pose:String)->AtlasTexture:
	pose=canonical(pose)
	if not SOURCE_RECTS.has(pose):return null
	if _frames.has(pose):return _frames[pose]
	if _atlas==null:
		if not ResourceLoader.exists(PATH):return null
		_atlas=load(PATH)
	if _atlas==null:return null
	var texture=AtlasTexture.new();texture.atlas=_atlas;texture.region=SOURCE_RECTS[pose];texture.filter_clip=true
	_frames[pose]=texture;return texture
static func drawing_rect(foot:Vector2,cell_size:float=245,pose:String="idle")->Rect2:
	pose=canonical(pose)
	if not SOURCE_RECTS.has(pose):return Rect2()
	var factor=cell_size/512.0*NORMALIZATION
	var source:Rect2=SOURCE_RECTS[pose]
	return Rect2(foot-(FOOT_ANCHORS[pose]-source.position)*factor,source.size*factor)
static func opaque_rect(foot:Vector2,cell_size:float=245,pose:String="idle")->Rect2:
	pose=canonical(pose)
	if not OPAQUE_BOUNDS.has(pose):return Rect2()
	var factor=cell_size/512.0*NORMALIZATION;var source:Rect2=OPAQUE_BOUNDS[pose]
	return Rect2(foot+(source.position-FOOT_ANCHORS[pose])*factor,source.size*factor)
static func weapon_point(foot:Vector2,cell_size:float=245,pose:String="idle")->Vector2:
	pose=canonical(pose)
	if not WEAPON_ANCHORS.has(pose):return foot
	return foot+(WEAPON_ANCHORS[pose]-FOOT_ANCHORS[pose])*(cell_size/512.0*NORMALIZATION)
static func draw(canvas:CanvasItem,foot:Vector2,pose:String,alpha:float=1.0,cell_size:float=245)->bool:
	var texture=texture_for(pose)
	if texture==null:return false
	canvas.draw_texture_rect(texture,drawing_rect(foot,cell_size,pose),false,Color(1,1,1,clampf(alpha,0,1)));return true
