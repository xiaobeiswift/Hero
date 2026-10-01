class_name QingweiFerryProps
extends RefCounted
## Original deck material and skiff sprite; collision remains owned by VillageWorld.
const WOOD_PATH="res://assets/generated/environment/qingwei_deck_wood.png"
const SKIFF_PATH="res://assets/generated/environment/qingwei_moored_skiff.png"
const SKIFF_REGION=Rect2(51,205,1693,498)
const FISHING_DECK=Rect2(823,435,117,34)
const FERRY_DECK=Rect2(1353,746,184,65)
const SKIFF_CENTER=Vector2(1540,831)
static var _wood:Texture2D
static var _boat:AtlasTexture
static var _deck_cache:Dictionary={}
static func wood_texture()->Texture2D:
	if _wood==null and ResourceLoader.exists(WOOD_PATH):_wood=load(WOOD_PATH)
	return _wood
static func skiff_texture()->AtlasTexture:
	if _boat==null and ResourceLoader.exists(SKIFF_PATH):
		_boat=AtlasTexture.new();_boat.atlas=load(SKIFF_PATH);_boat.region=SKIFF_REGION;_boat.filter_clip=true
	return _boat
static func deck_geometry(area:Rect2)->Dictionary:
	if _deck_cache.has(area):return _deck_cache[area]
	var points=PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
	var uvs=PackedVector2Array()
	for p in points:uvs.append((p-area.get_center())/maxf(area.size.x,area.size.y)+Vector2(.5,.5))
	var data={"points":points,"uvs":uvs};_deck_cache[area]=data;return data
static func draw_deck(canvas:CanvasItem,area:Rect2)->bool:
	var image=wood_texture()
	if image==null:return false
	var data=deck_geometry(area);canvas.draw_polygon(data.points,PackedColorArray([Color(1,1,1,.90)]),data.uvs,image)
	return true
static func skiff_rect()->Rect2:
	var extent=Vector2(110,SKIFF_REGION.size.y*110/SKIFF_REGION.size.x)
	return Rect2(SKIFF_CENTER-extent*.5,extent)
static func draw_skiff(canvas:CanvasItem)->bool:
	var image=skiff_texture()
	if image==null:return false
	canvas.draw_texture_rect(image,skiff_rect(),false)
	return true
