class_name MistwoodRegion
extends RefCounted
## Region IV: rain-washed bamboo uplands. Original vector art and pure geometry.
## Every landmark is approachable without a companion, learned art, or story flag.
const POND_CENTER=Vector2(277,242)
const POND_RADII=Vector2(126,63)
const TERRACES=[Rect2(648,266,200,73),Rect2(654,568,247,71),Rect2(1090,835,250,70)]
const CAMP_FOOTPRINT=Rect2(238,693,106,52)
const GATE_POSTS=[Vector2(1255,472),Vector2(1385,472)]
const BAMBOO=[
	Vector2(92,213),Vector2(132,325),Vector2(422,235),Vector2(463,207),
	Vector2(626,185),Vector2(867,222),Vector2(1115,198),Vector2(1193,248),
	Vector2(1448,241),Vector2(1502,336),Vector2(1422,606),Vector2(1518,720),
	Vector2(1449,841),Vector2(1478,968),Vector2(1288,970),Vector2(1030,951),
	Vector2(899,938),Vector2(741,856),Vector2(639,968),Vector2(531,938),
	Vector2(357,952),Vector2(156,901),Vector2(82,779),Vector2(136,649),
	Vector2(405,655),Vector2(479,553),Vector2(601,677),Vector2(883,514),
	Vector2(1140,643),Vector2(1161,380),Vector2(1124,410),Vector2(955,195),
]
const PATHS=[
	[Vector2(30,550),Vector2(150,550),Vector2(288,550),Vector2(380,470),Vector2(350,360)],
	[Vector2(380,470),Vector2(488,423),Vector2(557,347),Vector2(550,245)],
	[Vector2(488,423),Vector2(667,433),Vector2(817,420),Vector2(926,364),Vector2(1000,300)],
	[Vector2(817,420),Vector2(955,475),Vector2(1030,560),Vector2(1190,580),Vector2(1320,500),Vector2(1480,483)],
	[Vector2(288,550),Vector2(228,642),Vector2(198,725),Vector2(210,775),Vector2(290,790),Vector2(463,856),Vector2(589,735),Vector2(744,735),Vector2(852,785),Vector2(1040,790),Vector2(1250,765)],
	[Vector2(1030,560),Vector2(997,692),Vector2(1040,790)],
]
static func points() -> Dictionary:
	return {
		"return_frostbridge":{"pos":Vector2(150,550),"name":"返回霜桥驿","kind":"exit"},
		"mist_guide":{"pos":Vector2(350,360),"name":"秦禾","kind":"healer"},
		"mist_rain_gauge":{"pos":Vector2(550,245),"name":"雨痕竹尺","kind":"clue"},
		"mist_stone_gauge":{"pos":Vector2(1000,300),"name":"叠石刻度","kind":"clue"},
		"mist_basin":{"pos":Vector2(1250,765),"name":"分水石盂","kind":"clue"},
		"mist_camp":{"pos":Vector2(290,790),"name":"避雨营地","kind":"rest"},
		"mist_scout":{"pos":Vector2(1030,560),"name":"巡坡斥候","kind":"bandit"},
		"mist_gate":{"pos":Vector2(1320,500),"name":"守令使","kind":"bandit"},
		"exit_heting":{"pos":Vector2(1470,485),"name":"鹤汀下埠道","kind":"exit"},
	}

static func walkable(p:Vector2,_optional_flag:bool=false) -> bool:
	if not p.is_finite() or p.x<30 or p.x>1570 or p.y<155 or p.y>1015:return false
	# The damp pale lip is solid shoreline; only the blue-green water is impassable.
	if _inside_ellipse(p,POND_CENTER,POND_RADII+Vector2(5,5)):return false
	for terrace in TERRACES:
		if terrace.grow(7).has_point(p):return false
	if CAMP_FOOTPRINT.grow(7).has_point(p):return false
	for post in GATE_POSTS:
		if p.distance_to(post)<19:return false
	for bamboo in BAMBOO:
		if p.distance_to(bamboo)<13:return false
	return true

static func draw(w) -> void:
	w.draw_rect(Rect2(Vector2.ZERO,w.viewport_rect.size),Color("899e87"))
	w.draw_set_transform(-w.camera_pos)
	w.draw_rect(Rect2(0,0,1600,1050),Color("a0b68e"))
	_uplands(w)
	_ground(w)
	_paths(w)
	_pond(w)
	# Shallow terrace-edge rain runnels are decorative, not a second river barrier.
	for p in [Vector2(633,351),Vector2(655,657),Vector2(1110,918)]:
		w.draw_polyline(PackedVector2Array([p,p+Vector2(80,13),p+Vector2(132,2)]),Color("819e87"),7,true)
		w.draw_polyline(PackedVector2Array([p,p+Vector2(80,13),p+Vector2(132,2)]),Color("b5c9ac"),2,true)
	w._label(Vector2(494,940),"雾 竹 坡  ·  雨 过 留 痕",24,Color("627f63"),490,HORIZONTAL_ALIGNMENT_CENTER)
	var layers:Array=[]
	for terrace in TERRACES:layers.append({"y":terrace.end.y,"kind":"terrace","rect":terrace})
	for i in range(BAMBOO.size()):layers.append({"y":BAMBOO[i].y,"kind":"bamboo","p":BAMBOO[i],"index":i})
	layers.append({"y":CAMP_FOOTPRINT.end.y,"kind":"camp"})
	layers.append({"y":472,"kind":"gate"})
	var locations=points()
	for id in locations:
		layers.append({"y":locations[id].pos.y,"kind":"landmark","id":id,"p":locations[id].pos})
	layers.append({"y":w.player_pos.y,"kind":"player"})
	w.append_follower_layers(layers)
	# Preserve insertion order when feet and scenery share a y coordinate.
	for i in range(layers.size()):layers[i]["draw_order"]=i
	layers.sort_custom(func(a,b):return a.y<b.y if a.y!=b.y else a.draw_order<b.draw_order)
	for layer in layers:
		match layer.kind:
			"terrace":_terrace(w,layer.rect)
			"bamboo":_bamboo(w,layer.p,layer.index)
			"camp":_camp(w)
			"gate":_gate(w)
			"landmark":_landmark(w,layer.id,layer.p)
			"player":w._draw_person(w.player_pos,Color("326e69"),true,"player")
			"follower":
				w._draw_follower(layer.id)
				w.draw_set_transform(-w.camera_pos)
	_weather(w)
	w._draw_nameplates()
	w.draw_set_transform(Vector2.ZERO)
	w._draw_view_framing()

static func _inside_ellipse(p:Vector2,center:Vector2,radii:Vector2) -> bool:
	return ((p-center)/radii).length_squared()<1.0

static func _uplands(w) -> void:
	# Low asymmetric ridges replace the winter town's river and roof silhouettes.
	_poly(w,[Vector2(0,175),Vector2(0,61),Vector2(180,96),Vector2(365,31),Vector2(585,98),Vector2(805,49),Vector2(1095,109),Vector2(1320,58),Vector2(1600,112),Vector2(1600,207)],Color("829f8b"))
	_poly(w,[Vector2(0,199),Vector2(0,120),Vector2(232,171),Vector2(474,92),Vector2(722,153),Vector2(934,121),Vector2(1249,174),Vector2(1440,125),Vector2(1600,175),Vector2(1600,230)],Color("94ac91"))
	for i in range(14):
		var p=Vector2(40+i*119,165+sin(i*2.6)*21)
		w._ellipse(p,Vector2(107,15),Color(0.86,0.91,0.8,0.20))

static func _ground(w) -> void:
	for i in range(80):
		var p=Vector2(30+fmod(i*317.0,1540),166+fmod(i*193.0,834))
		w._ellipse(p,Vector2(28+(i%6)*8,11+(i%3)*4),Color(0.36,0.53,0.36,0.06))
	for i in range(280):
		var p=Vector2(36+fmod(i*179.0,1522),161+fmod(i*251.0,845))
		if not walkable(p):continue
		var covered=false
		for path in PATHS:
			for j in range(path.size()-1):
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1]))<35:covered=true;break
			if covered:break
		if covered:continue
		var tint=Color(0.31,0.48,0.29,0.23)
		w.draw_line(p,p+Vector2(-3,-6),tint,1,true)
		w.draw_line(p,p+Vector2(3,-9),tint,1,true)
	for p in [Vector2(431,742),Vector2(1060,412),Vector2(774,693),Vector2(1333,649)]:
		w._ellipse(p,Vector2(32,9),Color("8ca790"))
		w._ellipse_arc(p+Vector2(4,0),Vector2(20,5),Color(0.77,0.85,0.73,0.45))

static func _paths(w) -> void:
	for path in PATHS:
		w.draw_polyline(PackedVector2Array(path),Color("839b77"),57,true)
		w.draw_polyline(PackedVector2Array(path),Color("b8baa0"),44,true)
		w.draw_polyline(PackedVector2Array(path),Color(0.8,0.8,0.66,0.30),22,true)
		for j in range(path.size()-1):
			var start:Vector2=path[j];var finish:Vector2=path[j+1]
			var delta=finish-start;var count=maxi(1,int(delta.length()/33))
			for step in range(count):
				var p=start.lerp(finish,(step+0.5)/count)
				var side=delta.normalized().orthogonal()*13
				w.draw_line(p-side,p+side,Color(0.44,0.52,0.40,0.21),2,true)
	# Wide, low steps connect the higher northeast path to the gauge clearing.
	for i in range(6):
		var p=Vector2(947+i*7,349-i*6)
		w.draw_line(p+Vector2(-16,-10),p+Vector2(16,10),Color("899883"),4,true)
		w.draw_line(p+Vector2(-16,-12),p+Vector2(16,8),Color("d0d1b7"),2,true)

static func _pond(w) -> void:
	w._ellipse(POND_CENTER+Vector2(2,3),POND_RADII+Vector2(18,12),Color("8da483"))
	w._ellipse(POND_CENTER,POND_RADII+Vector2(7,6),Color("c4c6a8"))
	w._ellipse(POND_CENTER,POND_RADII,Color("6f9891"))
	w._ellipse(POND_CENTER-Vector2(13,8),POND_RADII-Vector2(22,15),Color("82aaa0"))
	for i in range(10):
		var p=POND_CENTER+Vector2(sin(i*2.5)*95,cos(i*3.7)*43)
		var phase=fmod(w.time_passed*0.35+i*0.37,1.0)
		w._ellipse_arc(p,Vector2(3+phase*11,1.6+phase*4),Color(0.82,0.89,0.78,(1-phase)*0.45))
	for i in range(7):
		var p=POND_CENTER+Vector2(-69+i*18,35+sin(i)*8)
		w._ellipse(p,Vector2(8,3),Color("6c9470"))
		w.draw_line(p,p+Vector2(7,-1),Color("a3b58e"),1,true)
	for p in [Vector2(163,258),Vector2(368,284),Vector2(395,224)]:
		for i in range(5):
			var q=p+Vector2(i*4-8,sin(i*2.5)*4)
			w.draw_line(q,q+Vector2(i-2,-21-i%3*5),Color("66885c"),2,true)
	w._label(Vector2(185,170),"听 雨 潭",15,Color("466d5c"),180,HORIZONTAL_ALIGNMENT_CENTER)

static func _terrace(w,r:Rect2) -> void:
	# Rectangular ground footprint is identical to collision; the elevated front
	# face stays inside it so no invisible retaining wall extends into a path.
	w._ellipse(r.position+r.size*Vector2(0.5,0.96),Vector2(r.size.x*0.51,10),Color(0.2,0.34,0.24,0.16))
	w.draw_rect(r,Color("768c75"))
	w.draw_rect(Rect2(r.position,r.size-Vector2(0,23)),Color("a4b097"))
	w.draw_rect(Rect2(r.position+Vector2(0,r.size.y-25),Vector2(r.size.x,5)),Color("c0c5a5"))
	for row in range(2):
		var y=r.end.y-20+row*11
		w.draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color("5c7664"),1.5)
		for column in range(7):
			var x=r.position.x+fmod(column*37.0+row*18,r.size.x)
			w.draw_line(Vector2(x,y),Vector2(x,y+10),Color("5c7664"),1.5)
	for i in range(9):
		var p=r.position+Vector2(13+fmod(i*47.0,r.size.x-22),10+fmod(i*13.0,23))
		w.draw_line(p,p+Vector2(13,-1),Color("7b9a6b"),5,true)
		w.draw_line(p+Vector2(4,0),p+Vector2(4,-6),Color("668456"),1,true)
	for i in range(4):
		var x=r.position.x+26+i*43
		w.draw_polyline(PackedVector2Array([Vector2(x,r.end.y-24),Vector2(x-4,r.end.y-12),Vector2(x+3,r.end.y-3)]),Color("70996b"),3,true)

static func _bamboo(w,p:Vector2,index:int) -> void:
	w._ellipse(p+Vector2(2,1),Vector2(19,7),Color(0.2,0.37,0.25,0.15))
	for stem in range(5):
		var root=p+Vector2((stem-2)*4,sin(stem*2.8)*3)
		var height=72+fmod(index*13+stem*19,48)
		var lean=sin(w.time_passed*0.55+index+stem)*2+(stem-2)*3
		var top=root+Vector2(lean,-height)
		w.draw_line(root,top,Color("456f4f"),3,true)
		w.draw_line(root+Vector2(1,0),top+Vector2(1,0),Color("91ad75"),1,true)
		for joint in range(1,5):
			var q=root.lerp(top,joint/5.0)
			w.draw_line(q-Vector2(2,0),q+Vector2(3,0),Color("bdc6a0"),1,true)
			if joint<2:continue
			var side=1 if (stem+joint+index)%2==0 else -1
			var tip=q+Vector2(side*29,-14)
			w.draw_line(q,tip,Color("426f4e"),1,true)
			_poly(w,[q+Vector2(side*7,-5),q+Vector2(side*35,-13),q+Vector2(side*17,-2)],Color("60895a"))
			_poly(w,[q+Vector2(side*15,-9),q+Vector2(side*19,-31),q+Vector2(side*23,-14)],Color("779961"))

static func _camp(w) -> void:
	var r=CAMP_FOOTPRINT
	w._ellipse(Vector2(290,739),Vector2(62,13),Color(0.25,0.36,0.23,0.2))
	w.draw_rect(r,Color("817d5e"))
	_poly(w,[Vector2(238,742),Vector2(258,686),Vector2(306,686),Vector2(344,742)],Color("b5b88c"))
	_poly(w,[Vector2(258,686),Vector2(290,742),Vector2(238,742)],Color("80916b"))
	_poly(w,[Vector2(274,735),Vector2(266,701),Vector2(290,735)],Color("465f4e"))
	for x in [238,344]:w.draw_line(Vector2(x,744),Vector2(x,701),Color("665f46"),3,true)
	w.draw_line(Vector2(258,687),Vector2(306,687),Color("d5cc9d"),3,true)
	for i in range(4):w.draw_line(Vector2(308+i*7,743),Vector2(302+i*7,720),Color("778465"),1,true)
	# Warm coals are sheltered by the tent; no fire or hard obstacle on the rest spot.
	w._ellipse(Vector2(336,768),Vector2(13,6),Color("78806a"))
	w._ellipse(Vector2(336,767),Vector2(7,3),Color("bf9961"))
	w.draw_line(Vector2(327,767),Vector2(343,770),Color("6d614a"),3,true)

static func _gate(w) -> void:
	for p in GATE_POSTS:
		w._ellipse(p+Vector2(2,2),Vector2(24,8),Color(0.24,0.36,0.25,0.18))
		w.draw_rect(Rect2(p+Vector2(-14,-98),Vector2(28,104)),Color("7d8c72"))
		w.draw_rect(Rect2(p+Vector2(-10,-98),Vector2(8,98)),Color("b4b59b"))
		for y in range(0,4):w.draw_line(p+Vector2(-14,-y*23),p+Vector2(14,-y*23),Color("627e68"),1.5)
		w.draw_rect(Rect2(p+Vector2(-20,-103),Vector2(40,9)),Color("b8bda0"))
	w.draw_line(Vector2(1235,369),Vector2(1405,369),Color("4e7358"),14,true)
	w.draw_line(Vector2(1232,360),Vector2(1408,360),Color("809971"),8,true)
	w.draw_rect(Rect2(1280,370,80,28),Color("496b52"))
	w._label(Vector2(1280,391),"守 雨 关",15,Color("d6d4ae"),80,HORIZONTAL_ALIGNMENT_CENTER)
	for x in [1273,1367]:
		w.draw_line(Vector2(x,378),Vector2(x,422),Color("9ca87b"),2,true)
		_poly(w,[Vector2(x-9,399),Vector2(x+10,399),Vector2(x+8,423),Vector2(x-7,419)],Color("b5b88c"))

static func _landmark(w,id:String,p:Vector2) -> void:
	match id:
		"return_frostbridge":w._draw_region_sign(p,"霜桥古道",-1)
		"exit_heting":w._draw_region_sign(p,"鹤汀埠",1)
		"mist_guide":
			if not w.has_follower("qin"):
				w._draw_person(p,Color("a5b98e"),false,"healer")
			# The umbrella marks Qin He's original station while she travels with us.
			w.draw_line(p+Vector2(10,-8),p+Vector2(10,-55),Color("777352"),2,true)
			_poly(w,[p+Vector2(-19,-49),p+Vector2(10,-67),p+Vector2(40,-49),p+Vector2(25,-45),p+Vector2(10,-48),p+Vector2(-5,-45)],Color("cec49b"))
			for x in [-16,1,23,37]:w.draw_line(p+Vector2(10,-65),p+Vector2(x,-49),Color("a8a17c"),1,true)
		"mist_rain_gauge":
			w._ellipse(p-Vector2(0,17),Vector2(24,10),Color("849d7d"))
			w.draw_line(p+Vector2(0,-17),p+Vector2(0,-76),Color("638b5c"),9,true)
			w.draw_line(p+Vector2(-2,-18),p+Vector2(-2,-74),Color("b5c494"),2,true)
			for i in range(6):w.draw_line(p+Vector2(-5,-27-i*8),p+Vector2(5,-27-i*8),Color("dde0b9"),1.5,true)
			_poly(w,[p+Vector2(-22,-76),p+Vector2(22,-76),p+Vector2(9,-60),p+Vector2(-9,-60)],Color("7a9476"))
			w._ellipse(p-Vector2(0,76),Vector2(22,6),Color("aebda0"))
			w._ellipse(p-Vector2(0,76),Vector2(17,3),Color("739c8c"))
		"mist_stone_gauge":
			w._ellipse(p-Vector2(0,10),Vector2(34,10),Color("7e937b"))
			_poly(w,[p+Vector2(-21,-13),p+Vector2(-18,-65),p+Vector2(16,-70),p+Vector2(23,-13)],Color("9ba891"))
			w.draw_line(p+Vector2(-17,-63),p+Vector2(15,-68),Color("d0d0b1"),3,true)
			for i in range(4):w.draw_line(p+Vector2(-10,-25-i*9),p+Vector2(10-i%2*6,-25-i*9),Color("536f61"),2,true)
			w.draw_line(p+Vector2(-23,-17),p+Vector2(23,-17),Color("6d8e69"),4,true)
		"mist_basin":
			w._ellipse(p-Vector2(0,16),Vector2(47,18),Color("7a8d78"))
			w.draw_rect(Rect2(p+Vector2(-39,-31),Vector2(78,17)),Color("8f9d88"))
			w._ellipse(p-Vector2(0,33),Vector2(43,17),Color("c1c4a6"))
			w._ellipse(p-Vector2(0,34),Vector2(34,11),Color("638e83"))
			w._ellipse_arc(p-Vector2(0,34),Vector2(20+sin(w.time_passed)*3,6),Color("a8c2a7"))
			for i in range(3):w.draw_line(p+Vector2(-22+i*22,-47),p+Vector2(-22+i*22,-40),Color("5b7868"),3,true)
		"mist_camp":
			w._ellipse_arc(p,Vector2(28,11),Color(0.83,0.77,0.55,0.6))
			w.draw_line(p+Vector2(-20,-6),p+Vector2(20,-6),Color("899073"),5,true)
		"mist_scout":w._draw_person(p,Color("89936d"),false,"bandit")
		"mist_gate":w._draw_person(p,Color("687f70"),false,"bandit")

static func _weather(w) -> void:
	# Sparse diagonal rain and drifting veils leave the route and actors readable.
	for i in range(68):
		var p=Vector2(fmod(i*173.0-w.time_passed*20+3200,1600),fmod(i*137.0+w.time_passed*145,1050))
		w.draw_line(p,p+Vector2(-3,9+i%5),Color(0.86,0.93,0.83,0.23),1,true)
	for i in range(7):
		var p=Vector2(120+i*238+sin(w.time_passed*0.10+i)*24,201+fmod(i*173.0,770))
		w._ellipse(p,Vector2(133,13),Color(0.87,0.93,0.84,0.11))

static func _poly(w,vertices:Array,color:Color) -> void:
	w.draw_colored_polygon(PackedVector2Array(vertices),color)
