class_name TravelerVisual
extends RefCounted
## Original articulated, direction-aware exploration figures. Coordinates remain visual only.
const Painted=preload("res://scripts/painted_traveler_sprite.gd")
const INK=Color("203a38")
const SKIN=Color("e2bc91")
const GOLD=Color("d9b570")

static func direction_index(direction:Vector2)->int:
	if absf(direction.x)>absf(direction.y)*0.78:return 1 if direction.x>0 else 3
	return 2 if direction.y<0 else 0

static func pose(direction:Vector2,clock:float,walking:bool)->Dictionary:
	var gait=sin(clock) if walking else 0.0
	return {"view":direction_index(direction),"gait":gait,"lift":absf(gait)*1.2 if walking else sin(clock*0.35)*0.35,"flutter":sin(clock-0.7)*(3.5 if walking else 1.0)}

static func draw_actor(c:CanvasItem,foot:Vector2,robe:Color,direction:Vector2,clock:float,walking:bool,kind:String="hero",scale_factor:float=1.12)->void:
	var data=pose(direction,clock,walking)
	var view:int=data.view
	var gait:float=data.gait
	var flutter:float=data.flutter
	var q=foot+Vector2(0,-float(data.lift))
	var side=view in [1,3]
	var back=view==2
	var sign_x=-1.0 if view==3 else 1.0
	_ellipse(c,foot+Vector2(1,2),Vector2(13,5),Color(0.05,0.14,0.12,0.27))
	if kind=="hero" and Painted.draw(c,foot,direction,walking,clock,72.0*scale_factor/1.12):return
	if kind=="hero":
		_ellipse(c,foot+Vector2(0,2),Vector2(17,6),Color(0.85,0.72,0.37,0.09))
	# Feet alternate clear contact/lift; the foot origin remains the collision anchor.
	for i in [-1,1]:
		var swing=gait*i
		var ankle=Vector2((4.5*i if not side else swing*5.0),-2-maxf(0,swing)*2.8)
		_line(c,q,Vector2(3*i,-12),ankle,INK,5,scale_factor)
		_line(c,q,ankle,ankle+Vector2(3.5*sign_x,1),Color("263733"),4,scale_factor)
	# Trailing shoulder cape, asymmetric split robe and moving pale sash.
	_poly(c,q,[Vector2(-8,-34),Vector2(7,-31),Vector2(14+flutter,-7),Vector2(4,-12),Vector2(-15+flutter,-6)],robe.darkened(.32),scale_factor)
	var width=7.0 if side else 9.0
	_poly(c,q,[Vector2(-width,-34),Vector2(width,-34),Vector2(width+4,-9+gait),Vector2(2,-6),Vector2(-width-3,-9-gait)],robe,scale_factor)
	_poly(c,q,[Vector2(-width+2,-33),Vector2(2,-27),Vector2(0,-10),Vector2(-width,-9)],robe.lightened(.22),scale_factor)
	_line(c,q,Vector2(-width+1,-32),Vector2(2,-25),Color("e4d7b4"),2,scale_factor)
	_line(c,q,Vector2(width-1,-33),Vector2(-3,-24),Color("d2c5a3"),1.5,scale_factor)
	_line(c,q,Vector2(-width,-20),Vector2(width,-20),GOLD if kind=="hero" else Color("617b61"),3,scale_factor)
	_poly(c,q,[Vector2(3,-20),Vector2(8,-19),Vector2(12+flutter,-2),Vector2(7+flutter,-5)],Color("c9c7a1"),scale_factor)
	for i in [-1,1]:
		var arm_end=Vector2((10+i*2)*i,-17+gait*i*3)
		_line(c,q,Vector2(width*i,-30),arm_end,robe.darkened(.08) if i<0 else robe.lightened(.10),6,scale_factor)
		c.draw_circle(q+(arm_end+Vector2(0,2))*scale_factor,2.2*scale_factor,SKIN)
	var head=Vector2(1 if side else 0,-40)
	c.draw_circle(q+head*scale_factor,7.2*scale_factor,INK)
	if not back:
		c.draw_circle(q+(head+Vector2(sign_x*1.4 if side else 0,1.4))*scale_factor,5.5*scale_factor,SKIN)
		_line(c,q,head+Vector2(-6,-2),head+Vector2(4,-4),INK,3,scale_factor)
		if side:
			c.draw_circle(q+(head+Vector2(sign_x*5.5,1))*scale_factor,1.0*scale_factor,INK)
		else:
			for x in [-2.4,2.4]:c.draw_circle(q+(head+Vector2(x,1.5))*scale_factor,.75*scale_factor,INK)
	c.draw_circle(q+Vector2(-2,-49)*scale_factor,3.5*scale_factor,INK)
	_line(c,q,Vector2(-5,-47),Vector2(3,-47),GOLD,1.5,scale_factor)
	if back or side:
		_line(c,q,Vector2(-4,-45),Vector2(-8+flutter,-29),INK,4,scale_factor)
	# Equipment silhouettes distinguish each traveller even from behind.
	if kind=="hero":
		_line(c,q,Vector2(-10,-8),Vector2(10,-38),Color("183e3d"),4.2,scale_factor)
		_line(c,q,Vector2(-9,-8),Vector2(10,-38),Color("5b8b7b"),1.4,scale_factor)
		_line(c,q,Vector2(6,-37),Vector2(13,-32),GOLD,2,scale_factor)
		_line(c,q,Vector2(10,-36),Vector2(15,-43),Color("e5d7b0"),2.5,scale_factor)
	elif kind=="tang":
		_line(c,q,Vector2(-7,-31),Vector2(10,-12),Color("776347"),2,scale_factor)
		_poly(c,q,[Vector2(7,-23),Vector2(12,-23),Vector2(12,-7),Vector2(7,-7)],Color("c7ae77"),scale_factor)
		for y in range(-21,-8,3):_line(c,q,Vector2(7,y),Vector2(10,y),INK,.7,scale_factor)
	elif kind=="shen":
		_poly(c,q,[Vector2(-8,-34),Vector2(7,-30),Vector2(5,-25),Vector2(-7,-30),Vector2(-11+flutter,-15),Vector2(-12,-25)],Color("5e9d88"),scale_factor)
		_line(c,q,Vector2(-6,-32),Vector2(11,-14),Color("87724d"),1.8,scale_factor)
		_poly(c,q,[Vector2(6,-20),Vector2(18,-20),Vector2(18,-8),Vector2(6,-8)],Color("e3d9b7"),scale_factor)
		_line(c,q,Vector2(9,-14),Vector2(15,-14),Color("4b8470"),1.6,scale_factor)
		_line(c,q,Vector2(12,-17),Vector2(12,-11),Color("4b8470"),1.6,scale_factor)

	elif kind=="elder":
		_line(c,q,Vector2(17,1),Vector2(17,-34),Color("8c6f42"),2.4,scale_factor)
		_poly(c,q,[Vector2(-4,-38),Vector2(5,-38),Vector2(1,-26)],Color("dbd8c2"),scale_factor)
		_line(c,q,Vector2(-5,-45),Vector2(5,-45),Color("c3cab5"),3,scale_factor)
	elif kind=="bandit":
		_poly(c,q,[Vector2(-13,-42),Vector2(0,-53),Vector2(14,-42)],Color("947f4f"),scale_factor)
		_line(c,q,Vector2(-12,-42),Vector2(13,-42),Color("d4bc79"),1.5,scale_factor)
		_line(c,q,Vector2(16,-9),Vector2(22,-31),Color("c8d1ba"),3,scale_factor)

static func _line(c:CanvasItem,q:Vector2,a:Vector2,b:Vector2,color:Color,width:float,s:float)->void:
	c.draw_line(q+a*s,q+b*s,color,width*s,true)
static func _poly(c:CanvasItem,q:Vector2,points:Array,color:Color,s:float)->void:
	var packed=PackedVector2Array()
	for p:Vector2 in points:packed.append(q+p*s)
	c.draw_colored_polygon(packed,color)
static func _ellipse(c:CanvasItem,p:Vector2,r:Vector2,color:Color)->void:
	var points=PackedVector2Array()
	for i in range(24):points.append(p+Vector2(cos(i*TAU/24.0),sin(i*TAU/24.0))*r)
	c.draw_colored_polygon(points,color)
