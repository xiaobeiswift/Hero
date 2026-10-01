extends Control
## Original vector stage and hand-drawn duel silhouettes.
var phase = 0.0
var flash = 0.0
var action = ""
var companion_active = false
var companion_name="沈青"
var region_style = "qingwei"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func hit(kind: String) -> void:
	action = kind
	flash = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta
	flash = maxf(0,flash-delta*2.5)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("1a3540") if region_style=="frostbridge" else Color("0e2b32"))
	# Distant water and mountains remain legible under the combat interface.
	for i in range(8):
		var points = PackedVector2Array([Vector2(-50,210+i*13),Vector2(140+i*23,130+i*9),Vector2(270+i*35,190+i*6),Vector2(480+i*21,125+i*11),Vector2(940,185+i*13),Vector2(940,360),Vector2(-50,360)])
		draw_colored_polygon(points,Color(0.10+i*0.008,0.24+i*0.007,0.25+i*0.007,0.24))
	draw_circle(Vector2(488,111),38,Color(0.91,0.82,0.59,0.08))
	draw_circle(Vector2(488,111),25,Color(0.91,0.82,0.59,0.13))
	for i in range(18):
		var x = fmod(i*89.0+phase*6,940)
		var y = 203+i*5.8
		draw_line(Vector2(x,y),Vector2(x+38,y),Color(0.40,0.62,0.58,0.13),1)
	# Weathered old wharf.
	draw_colored_polygon(PackedVector2Array([Vector2(0,275),Vector2(938,275),Vector2(938,355),Vector2(0,355)]),Color("7e9391") if region_style=="frostbridge" else Color("5d604e"))
	for i in range(24):
		var x = i*41
		draw_line(Vector2(x,278),Vector2(x-14,354),Color("506b70") if region_style=="frostbridge" else Color("343f3a"),2)
	draw_line(Vector2(0,281),Vector2(938,281),Color("cbd3c6") if region_style=="frostbridge" else Color("9c9570"),4)
	for x in [39,450,894]:
		draw_rect(Rect2(x,219,9,86),Color("3e453d"))
		draw_circle(Vector2(x+4,219),7,Color("958664"))
	draw_line(Vector2(43,233),Vector2(899,233),Color("807956"),2)
	if region_style=="training":_draw_training_court()
	var lunge = sin(flash*PI)*34 if action in ["attack","skill"] else 0.0
	_draw_fighter(Vector2(229+lunge,274),Color("4f9c8b"),true,phase,flash)
	if companion_active:
		_draw_fighter(Vector2(126,266),Color("82978c") if companion_name=="唐栖" else Color("9cba9d"),true,phase+1,0,companion_name=="唐栖")
	_draw_fighter(Vector2(721,274),Color("aa7864"),false,phase+2,flash)
	if flash>0 and action in ["attack","skill"]:
		var alpha=flash*0.9
		draw_arc(Vector2(690,229),48,-1.4,1.4,24,Color(0.95,0.84,0.52,alpha),3)
		if action=="skill":
			draw_line(Vector2(292,230),Vector2(733,189),Color(0.95,0.93,0.72,alpha),3)
			draw_line(Vector2(310,237),Vector2(723,204),Color(0.48,0.86,0.79,alpha*0.7),8)
	if flash>0 and action=="guard":
		draw_arc(Vector2(228,232),51,-1.4,1.4,24,Color(0.45,0.80,0.78,flash),4)
	for i in range(13):
		var pos = Vector2(fmod(i*107+phase*9,938),165+sin(i+phase*.4)*68)
		draw_circle(pos,1.2,Color(0.90,0.75,0.46,0.3+sin(phase+i)*0.2))

func _draw_fighter(p:Vector2,robe:Color,facing_right:bool,t:float,pulse:float,short_ruler:bool=false) -> void:
	var dir = 1 if facing_right else -1
	var bob = sin(t*2)*1.5
	draw_set_transform(p+Vector2(0,bob))
	_ellipse(Vector2(0,2),Vector2(35,9),Color(0.02,0.07,0.07,0.45))
	draw_line(Vector2(-11,-8),Vector2(-16,2),Color("1e2d2b"),9)
	draw_line(Vector2(9,-8),Vector2(14,2),Color("1e2d2b"),9)
	var robe_points=PackedVector2Array([Vector2(-16,-64),Vector2(14,-64),Vector2(27,-10),Vector2(3,-5),Vector2(-26,-12)])
	draw_colored_polygon(robe_points,robe)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-62),Vector2(6,-59),Vector2(5,-11),Vector2(-9,-9)]),robe.darkened(.28))
	draw_line(Vector2(-18,-37),Vector2(19,-37),Color("d7c79e"),5)
	draw_line(Vector2(-15*dir,-57),Vector2(-30*dir,-30),robe.darkened(.14),12)
	draw_line(Vector2(15*dir,-56),Vector2(39*dir,-38),robe.lightened(.12),12)
	draw_circle(Vector2(40*dir,-38),5,Color("d9b990"))
	draw_circle(Vector2(0,-76),13,Color("dec49d"))
	draw_arc(Vector2(0,-79),13,PI,2*PI,12,Color("202e2d"),8)
	draw_circle(Vector2(-5,-93),7,Color("202e2d"))
	draw_line(Vector2(-10,-82),Vector2(11,-82),Color("283a35"),5)
	draw_circle(Vector2(5*dir,-77),1.4,Color("1e302e"))
	draw_line(Vector2(41*dir,-40),Vector2(63*dir,-47) if short_ruler else Vector2(86*dir,-76),Color("baa57b") if short_ruler or (region_style=="training" and not facing_right) else Color("dbdfc5"),5 if short_ruler else 4)
	draw_line(Vector2(38*dir,-46),Vector2(46*dir,-32),Color("c4a464"),5)
	if facing_right:
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-63),Vector2(-33,-53),Vector2(-47,-10),Vector2(-22,-17)]),robe.darkened(.2))
	draw_set_transform(Vector2.ZERO)

func _ellipse(center:Vector2,radii:Vector2,color:Color) -> void:
	var points=PackedVector2Array()
	for i in range(32):
		var a=TAU*i/32.0
		points.append(center+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)

func _draw_training_court()	-> void:
	# Original south court: slate paving, limewashed boundary and timber racks.
	draw_rect(Rect2(0,130,938,226),Color("3e5952"))
	draw_rect(Rect2(0,130,938,103),Color("83937a"))
	draw_rect(Rect2(0,130,938,12),Color("385b53"))
	for y in [237,272,318,355]:draw_line(Vector2(0,y),Vector2(938,y),Color("465f55"),2)
	for x in range(0,970,94):draw_line(Vector2(469+(x-469)*0.65,231),Vector2(x,356),Color("506a60"),2)
	for side in [70,790]:
		draw_line(Vector2(side,167),Vector2(side,230),Color("544f3b"),6)
		draw_line(Vector2(side+74,167),Vector2(side+74,230),Color("544f3b"),6)
		draw_line(Vector2(side-8,184),Vector2(side+82,184),Color("6d6043"),6)
		for i in range(4):
			draw_line(Vector2(side+9+i*18,157),Vector2(side+3+i*18,220),Color("c2b186"),4)
			draw_line(Vector2(side+3+i*18,171),Vector2(side+16+i*18,173),Color("786b4e"),3)
	draw_arc(Vector2(476,285),69,0,TAU,48,Color("b6b69a"),2)
	draw_arc(Vector2(476,285),64,0,TAU,48,Color("526d60"),1)
