class_name PaintedTeaTable
extends RefCounted
## One original table-and-stool arrangement at the two existing courtyard positions.
const PATH="res://assets/generated/environment/qingwei_tea_table.png"
const REGION=Rect2(141,175,1494,604)
const FOOT=Vector2(746,595)
const WIDTH=76.0
const POSITIONS=[Vector2(578,338),Vector2(710,355)]
static var _texture:AtlasTexture
static func texture()->AtlasTexture:
	if _texture==null and ResourceLoader.exists(PATH):
		_texture=AtlasTexture.new();_texture.atlas=load(PATH);_texture.region=REGION;_texture.filter_clip=true
	return _texture
static func drawing_rect(position:Vector2)->Rect2:
	var ratio=WIDTH/REGION.size.x
	return Rect2(position+Vector2(0,8)-FOOT*ratio,REGION.size*ratio)
static func draw(canvas:CanvasItem,position:Vector2)->bool:
	var image=texture()
	if image==null:return false
	canvas.draw_texture_rect(image,drawing_rect(position),false);return true
