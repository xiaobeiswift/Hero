class_name FrostbridgeRegion
extends RefCounted
## Region III: an original winter post town. Pure geometry/data, no scene mutation.
const BUILDINGS=[
	{"pos":Vector2(290,205),"size":Vector2(248,110),"name":"霜 桥 驿 馆","type":"inn"},
	{"pos":Vector2(1030,205),"size":Vector2(246,120),"name":"文 书 房","type":"tea"},
	{"pos":Vector2(1160,565),"size":Vector2(250,132),"name":"封 仓 印 台","type":"hall"},
]
const TREES=[Vector2(155,230),Vector2(220,390),Vector2(185,725),Vector2(484,855),Vector2(585,530),Vector2(652,190),Vector2(975,210),Vector2(1432,268),Vector2(1490,538),Vector2(1040,955),Vector2(1350,905)]
static func points() -> Dictionary:
	return {
		"exit_mistwood":{"pos":Vector2(1450,200),"name":"雾竹坡古道","kind":"exit"},
		"return_sluice":{"pos":Vector2(140,500),"name":"返回废闸","kind":"exit"},
		"chapter_host":{"pos":Vector2(405,365),"name":"温行舟","kind":"elder"},
		"chapter_clerk":{"pos":Vector2(1150,385),"name":"纪小砚","kind":"healer"},
		"chapter_inscription":{"pos":Vector2(685,320),"name":"旧桥碑文","kind":"board"},
		"chapter_archive":{"pos":Vector2(1320,745),"name":"封仓印台","kind":"bandit"},
		"bridge_worker":{"pos":Vector2(650,760),"name":"唐栖","kind":"elder"},
		"frost_ore":{"pos":Vector2(980,255),"name":"露头铁矿","kind":"resource"},
		"frost_timber":{"pos":Vector2(335,805),"name":"散落木料","kind":"resource"},
		"frost_herb":{"pos":Vector2(1400,425),"name":"耐寒药草","kind":"resource"},
	}
static func walkable(p:Vector2,repaired:bool) -> bool:
	if not p.is_finite() or p.x<30 or p.x>1570 or p.y<155 or p.y>1015:return false
	for b in BUILDINGS:
		if Rect2(b.pos,b.size).grow(9).has_point(p):return false
	var north=Rect2(702,349,265,81).has_point(p)
	var south=repaired and Rect2(702,759,265,81).has_point(p)
	if absf(p.x-835)<91 and not north and not south:return false
	for t in TREES:
		if p.distance_to(t)<13:return false
	return true
static func draw(w) -> void:
	w.draw_rect(Rect2(Vector2.ZERO,w.viewport_rect.size),Color("a7b8b2"))
	w.draw_set_transform(-w.camera_pos)
	w.draw_rect(Rect2(0,0,1600,1050),Color("b7c5ba"))
	w._draw_mountains()
	for i in range(48):
		var p=Vector2(fmod(i*317.0,1600),155+fmod(i*193.0,880))
		w._ellipse(p,Vector2(38+float(i%4)*13,12),Color(0.87,0.9,0.82,0.16))
	for pair in [[Vector2(30,500),Vector2(405,500),Vector2(405,365),Vector2(820,388),Vector2(1150,385),Vector2(1490,385)],[Vector2(405,500),Vector2(405,760),Vector2(650,800),Vector2(835,800),Vector2(1080,800),Vector2(1320,745)],[Vector2(1080,385),Vector2(1080,800)]]:
		w.draw_polyline(PackedVector2Array(pair),Color("92a79a"),52,true)
		w.draw_polyline(PackedVector2Array(pair),Color("d0ccb5"),43,true)
	w.draw_rect(Rect2(733,120,204,960),Color("879f9d"))
	w.draw_rect(Rect2(746,120,178,960),Color("648b8c"))
	for i in range(24):
		var y=130+i*41
		var x=792+sin(i*1.4+w.time_passed*.3)*38
		w.draw_line(Vector2(x,y),Vector2(x+52,y),Color(0.75,0.86,0.8,0.28),2,true)
		if i%4==0:_poly(w,[Vector2(754,y),Vector2(780,y+6),Vector2(767,y+25),Vector2(750,y+18)],Color("b9d0c4"))
	_bridge(w,Rect2(703,350,264,80),true)
	_bridge(w,Rect2(703,760,264,80),w.bridge_repaired)
	w._draw_region_sign(Vector2(140,500),"废闸古道",-1)
	w._draw_region_sign(Vector2(1450,200),"雾竹坡",1)
	w._draw_board(Vector2(685,320))
	var layers:Array=[]
	for b in BUILDINGS:layers.append({"y":b.pos.y+b.size.y,"kind":"building","data":b})
	for t in TREES:layers.append({"y":t.y,"kind":"tree","p":t})
	for id in ["chapter_host","chapter_clerk","chapter_archive","bridge_worker"]:layers.append({"y":w.interactables[id].pos.y,"kind":"npc","id":id})
	for id in ["frost_ore","frost_timber","frost_herb"]:layers.append({"y":w.interactables[id].pos.y,"kind":"resource","id":id})
	layers.append({"y":w.player_pos.y,"kind":"player"})
	if w.companion_active:layers.append({"y":w.companion_pos.y,"kind":"companion"})
	layers.sort_custom(func(a,b):return a.y<b.y)
	for layer in layers:
		match layer.kind:
			"building":w._draw_building(layer.data)
			"tree":_pine(w,layer.p)
			"npc":
				var colors={"chapter_host":Color("977c5e"),"chapter_clerk":Color("b5c5ad"),"chapter_archive":Color("8d665e"),"bridge_worker":Color("81947d")}
				if layer.id=="bridge_worker" and w.companion_active and w.companion_name=="唐栖":
					w.draw_rect(Rect2(w.interactables[layer.id].pos-Vector2(20,15),Vector2(40,16)),Color("796b50"))
					w.draw_line(w.interactables[layer.id].pos+Vector2(-12,-18),w.interactables[layer.id].pos+Vector2(15,-14),Color("c7b38a"),4)
				else:w._draw_person(w.interactables[layer.id].pos,colors[layer.id],false,"tang" if layer.id=="bridge_worker" else w.interactables[layer.id].kind)
			"resource":_resource(w,layer.id,w.interactables[layer.id].pos,w.resource_depleted.has(layer.id))
			"player":w._draw_person(w.player_pos,Color("326e69"),true,"player")
			"companion":w._draw_companion()
	w._label(Vector2(180,920),"霜 桥 驿  ·  印 下 有 声",24,Color("66867e"),480,HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(35):
		var p=Vector2(fmod(i*117+w.time_passed*5,1600),fmod(i*73+w.time_passed*11,1050))
		w.draw_circle(p,1.3,Color(0.93,0.95,0.87,0.55))
	if w.chapter_stage>=4:
		w._label(Vector2(290,340),"原账已经公示" if w.chapter_ending=="open_records" else "证人姓名已封存",13,Color("526f64"),248,HORIZONTAL_ALIGNMENT_CENTER)
	w._draw_nameplates()
	w.draw_set_transform(Vector2.ZERO)
	w._draw_view_framing()
static func _bridge(w,r:Rect2,whole:bool) -> void:
	for side in [0,1]:
		w.draw_rect(Rect2(r.position+Vector2(side*(r.size.x-32),-10),Vector2(32,r.size.y+20)),Color("6f8580"))
	if whole:
		w.draw_rect(r,Color("b8b79f"))
		for x in range(int(r.position.x),int(r.end.x),22):w.draw_line(Vector2(x,r.position.y+4),Vector2(x,r.end.y-4),Color("91a297"),2)
		for y in [r.position.y,r.end.y]:w.draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color("e2e0c6"),6)
	else:
		w.draw_rect(Rect2(r.position,Vector2(66,r.size.y)),Color("a5ab94"))
		w.draw_rect(Rect2(r.end-Vector2(66,r.size.y),Vector2(66,r.size.y)),Color("a5ab94"))
		w.draw_line(r.position+Vector2(20,7),r.end-Vector2(20,r.size.y-16),Color("6d7461"),2)
static func _pine(w,p:Vector2) -> void:
	w._ellipse(p+Vector2(0,3),Vector2(30,10),Color(0.23,0.35,0.32,0.18))
	w.draw_rect(Rect2(p+Vector2(-4,-28),Vector2(8,31)),Color("6e7562"))
	for i in range(3):
		var y=-25-i*18;var width=34-i*7
		_poly(w,[p+Vector2(-width,y),p+Vector2(0,y-40),p+Vector2(width,y)],Color("73968a"))
		w.draw_line(p+Vector2(-width+6,y-4),p+Vector2(-2,y-34),Color("d1dbc7"),3,true)
static func _resource(w,id:String,p:Vector2,depleted:bool) -> void:
	var tint=Color("93a595") if depleted else Color("cebc87")
	match id:
		"frost_ore":
			_poly(w,[p+Vector2(-22,5),p+Vector2(-15,-17),p+Vector2(10,-23),p+Vector2(25,-1),p+Vector2(15,10)],Color("788a85"))
			w.draw_line(p+Vector2(-10,-8),p+Vector2(13,-15),tint,4)
		"frost_timber":
			for i in range(3):w.draw_line(p+Vector2(-23,i*7-13),p+Vector2(23,i*7-5),Color("978764"),7)
		"frost_herb":
			for i in range(5):
				var a=i*TAU/5;w.draw_line(p,p+Vector2(cos(a)*18,sin(a)*12-9),Color("5b8b77"),4)
	if not depleted:
		w._ellipse_arc(p+Vector2(0,7),Vector2(26,10),Color(0.89,0.75,0.4,0.65))

static func _poly(w,points:Array,color:Color) -> void:
	w.draw_colored_polygon(PackedVector2Array(points),color)
