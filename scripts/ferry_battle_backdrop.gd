class_name FerryBattleBackdrop
extends RefCounted
## Original painted ferry plate with a few live water highlights. No gameplay state.
const FIGHTING_HEIGHT:float=356.0
const PATH="res://assets/generated/environment/qingwei_duel_backdrop.png"
static var _texture:Texture2D
static func applies(style:String)->bool:return style=="qingwei"
static func texture()->Texture2D:
	if _texture==null and ResourceLoader.exists(PATH):_texture=load(PATH)
	return _texture
static func cover_rect(source:Vector2,target:Vector2)->Rect2:
	if source.x<=0 or source.y<=0 or target.x<=0 or target.y<=0:return Rect2()
	var factor=maxf(target.x/source.x,target.y/source.y)
	var scaled=source*factor
	return Rect2((target-scaled)*.5,scaled)
static func draw(canvas:CanvasItem,size:Vector2,clock:float)->bool:
	var image=texture()
	if image==null or size.x<=0 or size.y<=0:return false
	# The full canvas includes the lower command/log HUD. The painted fighting
	# plane belongs to the original 938 x 356 choreography area, not that footer.
	canvas.draw_rect(Rect2(Vector2.ZERO,size),Color("10262b"))
	var fighting_size=Vector2(size.x,minf(size.y,FIGHTING_HEIGHT))
	canvas.draw_texture_rect(image,cover_rect(image.get_size(),fighting_size),false)
	var fade_top=330.0
	canvas.draw_polygon(PackedVector2Array([Vector2(0,fade_top),Vector2(size.x,fade_top),Vector2(size.x,380),Vector2(0,380)]),PackedColorArray([Color(0.063,0.149,0.169,0),Color(0.063,0.149,0.169,0),Color("10262b"),Color("10262b")]))
	if size.y>380:canvas.draw_rect(Rect2(0,380,size.x,size.y-380),Color("10262b"))
	# Subtle surface glints remain alive; the expensive material painting is one draw.
	for i in range(8):
		var x=fmod(i*119.0+clock*5.0,size.x+36)-18
		var y=197.0+i*6.3
		canvas.draw_line(Vector2(x,y),Vector2(x+23+i%3*5,y),Color(.65,.79,.71,.038+.018*sin(clock*.7+i)),.65,true)
	return true
