class_name ReedIslet
extends RefCounted
const L=preload("res://scripts/lightness_rules.gd")
static func draw(w)->void:
	var c=L.ISLET_CENTER
	w._ellipse(c+Vector2(0,6),L.ISLET_RADIUS+Vector2(5,3),Color("617e71"))
	w._ellipse(c,L.ISLET_RADIUS,Color("a8af88"))
	w._ellipse(c+Vector2(-3,-3),L.ISLET_RADIUS-Vector2(7,7),Color("c0bb91"))
	for i in range(3):
		var p=L.SHORE.lerp(L.LANDING,0.3+i*0.22)+Vector2(0,-6+i*2)
		w._ellipse(p+Vector2(1,3),Vector2(8,3),Color("668474"))
		w._ellipse(p,Vector2(6,3),Color("a2af99"))
	for offset in [Vector2(-23,-18),Vector2(23,-20),Vector2(-22,17)]:
		var p=c+offset
		for j in range(3):
			w.draw_line(p+Vector2(j*3,0),p+Vector2(j*4-5,-20-j*4),Color("647e55"),1.5,true)
	var stone=L.RELIC_POSITION
	w._ellipse(stone+Vector2(3,1),Vector2(14,5),Color("889477"))
	var shape:Array[Vector2]=[stone+Vector2(-9,0),stone+Vector2(-10,-26),stone+Vector2(-5,-32),stone+Vector2(10,-28),stone+Vector2(9,0)]
	w._poly(shape,Color("788a73"))
	w.draw_line(stone+Vector2(-5,-22),stone+Vector2(6,-22),Color("bfc1a0"),1.3)
	w.draw_line(stone+Vector2(-5,-16),stone+Vector2(5,-16),Color("bfc1a0"),1.3)
	w._label(c+Vector2(-52,-49),"苇心小洲",14,Color("e0d8b0"),104,HORIZONTAL_ALIGNMENT_CENTER)
	w.draw_circle(L.SHORE,6,Color("c3b575"))
