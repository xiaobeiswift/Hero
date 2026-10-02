extends RefCounted
## Reuses original village materials; anchored hall and foliage behind the arena.
const VillageEnvironment=preload("res://scripts/qingwei_environment_art.gd")
const Tiles=preload("res://scripts/world_material_tiles.gd")
const Earth=preload("res://assets/generated/environment/qingwei_moss_earth.png")
const COURT=Rect2(0,193,938,162)
const HALL={"type":"hall","pos":Vector2(303,107),"size":Vector2(330,87)}
static var _ring:PackedVector2Array=PackedVector2Array()
static func ring()->PackedVector2Array:
	if _ring.is_empty():
		for i in range(65):
			var a=float(i)*TAU/64.0
			_ring.append(Vector2(473,292)+Vector2(cos(a)*124,sin(a)*27))
	return _ring
static func draw(canvas:CanvasItem,area:Vector2,_time:float)->void:
	canvas.draw_rect(Rect2(Vector2.ZERO,area),Color("263f38"))
	# Limewash remains quiet behind the painted court, never a flat foreground slab.
	canvas.draw_rect(Rect2(0,102,938,104),Color("64755b"))
	Tiles.draw(canvas,Earth,Rect2(0,102,938,104),340,.18)
	canvas.draw_line(Vector2(0,108),Vector2(938,108),Color("425948"),9,true)
	VillageEnvironment.draw_willow(canvas,Vector2(106,205),2.25,.75)
	VillageEnvironment.draw_willow(canvas,Vector2(895,195),1.85,.74)
	canvas.draw_rect(COURT,Color("687564"))
	Tiles.draw(canvas,Earth,COURT,245,.24)
	for y in [215,241,275,320]:
		canvas.draw_line(Vector2(0,y),Vector2(938,y),Color(.22,.31,.26,.35),1.2,true)
	for x in range(-40,1040,84):
		canvas.draw_line(Vector2(469+(x-469)*.7,193),Vector2(x,355),Color(.22,.31,.26,.27),1.2,true)
	VillageEnvironment.draw_building(canvas,HALL,.93)
	var plaque=VillageEnvironment.plaque_rect(HALL)
	canvas.draw_string(preload("res://assets/fonts/NotoSansSC.otf"),plaque.position+Vector2(0,plaque.size.y*.8),"练  武  堂",HORIZONTAL_ALIGNMENT_CENTER,plaque.size.x,10,Color("e4d4aa"))
	canvas.draw_polyline(ring(),Color(.83,.79,.59,.35),1.6,true)
	# One interpolated wash integrates the top edge with the HUD.
	canvas.draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(938,0),Vector2(938,125),Vector2(0,125)]),PackedColorArray([Color(.063,.157,.153,.93),Color(.063,.157,.153,.93),Color(.063,.157,.153,0),Color(.063,.157,.153,0)]))
