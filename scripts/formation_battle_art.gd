extends Control
## New presentation study. Original assets only; no combat rules or state writes.
const Hero=preload("res://scripts/painted_battle_hero.gd")
const Shen=preload("res://scripts/painted_battle_shen.gd")
const Tang=preload("res://scripts/painted_battle_tang.gd")
const Rival=preload("res://scripts/painted_battle_puheng.gd")
const Backdrop=preload("res://scripts/ferry_battle_backdrop.gd")
const Lantern=preload("res://scripts/painted_lantern_post.gd")
const FONT=preload("res://assets/fonts/NotoSansSC.otf")
const WOOD=preload("res://assets/generated/environment/qingwei_deck_wood.png")
const HERO_FOOT=Vector2(395,580)
const ENEMY_FEET={"bracer":Vector2(865,580),"striker":Vector2(1045,460)}
const GOLD=Color("d4b477")
var snapshot:Dictionary={}
var formation:String="护后"
var selected:String="bracer"
var phase:float=0
var floor_mesh:ArrayMesh
var plate_box:StyleBoxFlat

func _ready()->void:
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_IGNORE
	floor_mesh=_make_floor()
	for pose in Hero.POSES:Hero.texture_for(pose)
	for pose in Rival.POSES:Rival.texture_for(pose)
	Shen.texture_for("idle");Tang.texture_for("idle")

func _process(delta:float)->void:
	phase+=delta;queue_redraw()

func set_snapshot(value:Dictionary)->void:
	snapshot=value.duplicate(true);formation=String(value.get("formation","护后"));selected=String(value.get("selected_id","bracer"));queue_redraw()

func support_foot()->Vector2:
	return Vector2(235,470) if formation=="护后" else Vector2(300,515)

func hero_foot()->Vector2:
	return HERO_FOOT if formation=="护后" else Vector2(455,580)

func ground_point(x:float,y:float)->Vector2:
	return Vector2(lerpf(110.0-150.0*y,1170.0+150.0*y,x),lerpf(320.0,682.0,y))

func _make_floor()->ArrayMesh:
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
	for y in range(2):
		for x in range(3):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var depth=(y+corner.y)/2.0
				var p=ground_point((x+corner.x)/3.0,depth)
				vertices.append(Vector3(p.x,p.y,0))
				uvs.append(Vector2(1-corner.x if x%2 else corner.x,1-corner.y if y%2 else corner.y))
				colors.append(Color(.60,.66,.65).lerp(Color(.88,.91,.88),depth))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("10272a"))
	var background=Backdrop.texture()
	if background:draw_texture_rect(background,Rect2(0,-25,1280,486),false,Color(.83,.92,.94))
	if floor_mesh:draw_mesh(floor_mesh,WOOD)
	# The dock edge and depth bands are structural timber, not selectable cells.
	draw_line(ground_point(0,0),ground_point(1,0),Color("4a5046"),13,true)
	draw_line(ground_point(0,0)+Vector2(0,3),ground_point(1,0)+Vector2(0,3),Color("92927a"),2,true)
	for y in [.32,.68]:draw_line(ground_point(0,y),ground_point(1,y),Color(.05,.12,.13,.25),2,true)
	for foot in [Vector2(115,337),Vector2(1165,337)]:
		draw_set_transform(foot,0,Vector2.ONE*2.05);Lantern.draw(self,Vector2.ZERO,phase);draw_set_transform(Vector2.ZERO)
	var target:Vector2=ENEMY_FEET[selected]
	var start=hero_foot()+Vector2(48,4);var end=target-Vector2(49,-4)
	for i in range(13):
		var t=float(i)/13;draw_line(start.lerp(end,t),start.lerp(end,minf(1,t+.025)),Color(GOLD,.25),1.2,true)
	var actors=[{"id":"hero","foot":hero_foot()},{"id":"bracer","foot":ENEMY_FEET.bracer},{"id":"striker","foot":ENEMY_FEET.striker}]
	if not String(snapshot.get("companion","")).is_empty():actors.append({"id":"support","foot":support_foot()})
	actors.sort_custom(func(a,b):return a.foot.y<b.foot.y)
	for actor in actors:_actor(actor.id,actor.foot)
	for actor in actors:_label_actor(actor.id,actor.foot)

func _ellipse(center:Vector2,radius:Vector2,color:Color)->void:
	var points=PackedVector2Array()
	for i in range(40):points.append(center+Vector2(cos(i*TAU/40)*radius.x,sin(i*TAU/40)*radius.y))
	draw_colored_polygon(points,color)

func _actor(id:String,foot:Vector2)->void:
	_ellipse(foot+Vector2(0,5),Vector2(54,10),Color(.015,.05,.055,.5))
	if id==selected:
		for i in range(44):
			var a=float(i)*TAU/44
			draw_line(foot+Vector2(cos(a)*61,sin(a)*12+4),foot+Vector2(cos(a+.10)*61,sin(a+.10)*12+4),GOLD,1.9,true)
	if id=="hero":Hero.draw(self,foot,{},1,290)
	elif id=="support":
		if snapshot.get("companion","")=="唐栖":Tang.draw(self,foot,"idle",1,245)
		else:Shen.draw(self,foot,"idle",1,245)
	else:
		var texture=Rival.texture_for("guard" if id=="bracer" else "idle")
		var tint=Color(.70,.88,.91) if id=="bracer" else Color(1,.88,.76)
		draw_texture_rect(texture,Rival.drawing_rect(foot,280 if id=="bracer" else 265),false,tint)

func _unit(id:String)->Dictionary:
	for unit:Dictionary in snapshot.get("units",[]):
		if unit.id==id:return unit
	return {}

func _label_actor(id:String,foot:Vector2)->void:
	# Measured alpha bounds, not the transparent 512px cell, keep labels above hair.
	var box=label_rect(id,foot)
	var pos=box.position+Vector2(6,4)
	var name="无名客" if id=="hero" else (String(snapshot.get("companion","")) if id=="support" else String(_unit(id).get("name","")))
	var width=148.0
	draw_style_box(_plate(),box)
	_text(name,pos+Vector2(width*.5,15),17,Color("f0e6ce"),true)
	if id=="support":
		_text("护后照应" if formation=="护后" else "并肩协击",pos+Vector2(width*.5,35),12,Color("b9d1bd"),true);return
	var hp=int(snapshot.get("hp",0)) if id=="hero" else int(_unit(id).get("hp",0))
	var maximum=int(snapshot.get("max_hp",1)) if id=="hero" else int(_unit(id).get("max_hp",1))
	draw_rect(Rect2(pos+Vector2(0,22),Vector2(width,5)),Color("253a38"))
	draw_rect(Rect2(pos+Vector2(0,22),Vector2(width*float(hp)/maxi(1,maximum),5)),Color("72af98") if id=="hero" else Color("bd7b62"))
	_text("%d / %d"%[hp,maximum],pos+Vector2(0,43),12,Color("dbd7c4"))
	var role="真气 %d/%d"%[int(snapshot.get("qi",0)),int(snapshot.get("max_qi",1))] if id=="hero" else ("援护" if id=="bracer" else "截签 · 将攻")
	_text(role,pos+Vector2(width,43),12,GOLD,false,true)

func label_rect(id:String,foot:Vector2)->Rect2:
	var height:float={"hero":180.0,"support":193.0,"bracer":174.0,"striker":154.0}[id]
	return Rect2(foot-Vector2(80,height+(55 if id=="support" else 76)),Vector2(160,47 if id=="support" else 65))

func _plate()->StyleBoxFlat:
	if plate_box==null:
		plate_box=StyleBoxFlat.new();plate_box.bg_color=Color(.045,.105,.11,.76);plate_box.corner_radius_top_left=4;plate_box.corner_radius_top_right=4;plate_box.corner_radius_bottom_left=4;plate_box.corner_radius_bottom_right=4
	return plate_box

func _text(value:String,pos:Vector2,font_size:int,color:Color,center:bool=false,right:bool=false)->void:
	var width=FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	if center:pos.x-=width*.5
	elif right:pos.x-=width
	draw_string(FONT,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
