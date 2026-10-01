class_name PaintedBattleHero
extends RefCounted
## Original combat key poses; presentation only, never battle state or damage.
const PATH="res://assets/generated/characters/painted_hero_combat.png"
const CELL=Vector2(512,512)
const FOOT=Vector2(224,470)
const POSES={"idle":0,"windup":1,"strike":2,"guard":3,"hurt":4,"kneel":5}
static var _atlas:Texture2D
static var _frames:Dictionary={}
static func texture_for(name:String)->AtlasTexture:
	if not POSES.has(name):return null
	if _frames.has(name):return _frames[name]
	if _atlas==null:
		if not ResourceLoader.exists(PATH):return null
		_atlas=load(PATH)
	if _atlas==null:return null
	var i:int=POSES[name]
	var texture=AtlasTexture.new();texture.atlas=_atlas
	texture.region=Rect2(Vector2((i%3)*512,(i/3)*512),CELL);texture.filter_clip=true
	_frames[name]=texture
	return texture
static func pose_for(pose:Dictionary)->String:
	if float(pose.get("defeat",0))>.25:return "kneel"
	if float(pose.get("recoil",0))>.12:return "hurt"
	if float(pose.get("guard",0))>.12:return "guard"
	if float(pose.get("strike",0))>.14:return "strike"
	if float(pose.get("windup",0))>.18:return "windup"
	return "idle"
static func drawing_rect(foot:Vector2,cell_size:float=208)->Rect2:
	return Rect2(foot-FOOT*(cell_size/512.0),Vector2.ONE*cell_size)
static func draw(canvas:CanvasItem,foot:Vector2,pose:Dictionary,alpha:float=1.0,cell_size:float=208)->bool:
	var texture=texture_for(pose_for(pose))
	if texture==null:return false
	canvas.draw_texture_rect(texture,drawing_rect(foot,cell_size),false,Color(1,1,1,clampf(alpha,0,1)))
	return true
