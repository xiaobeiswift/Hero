extends "res://scripts/courtyard_practice_art.gd"
## Original formation stage. Inherits only detached accepted-transaction playback;
## actors, effects, labels and picking share the same measured stage geometry.
const Hero=preload("res://scripts/painted_battle_hero.gd")
const Shen=preload("res://scripts/painted_battle_shen.gd")
const Tang=preload("res://scripts/painted_battle_tang.gd")
const Rival=preload("res://scripts/painted_battle_puheng.gd")
const Backdrop=preload("res://scripts/ferry_battle_backdrop.gd")
const Lantern=preload("res://scripts/painted_lantern_post.gd")
const WOOD=preload("res://assets/generated/environment/qingwei_deck_wood.png")
const HERO_FOOT=Vector2(395,580)
const ENEMY_FEET={"bracer":Vector2(865,580),"striker":Vector2(1045,460)}
const ACTOR_SIZE={"hero":290.0,"support":245.0,"bracer":280.0,"striker":265.0}
const GOLD=Color("d4b477")
# Coordinates measured in the original 512px pose cells. Blade tips register
# actual contact; body hit bounds exclude the blade and empty atlas corners.
const HERO_BLADE=Vector2(495,286)
const RIVAL_BLADE=Vector2(22,272)
const HERO_CHEST={"idle":Vector2(238,283),"windup":Vector2(237,282),"strike":Vector2(292,290),"guard":Vector2(245,288),"hurt":Vector2(238,290),"kneel":Vector2(251,355)}
const RIVAL_CHEST={"idle":Vector2(288,294),"windup":Vector2(287,287),"strike":Vector2(326,312),"guard":Vector2(278,305),"hurt":Vector2(282,287),"kneel":Vector2(314,369)}
const RIVAL_BODY={"idle":Rect2(145,174,313,299),"windup":Rect2(137,166,307,307),"strike":Rect2(149,226,311,247),"guard":Rect2(138,174,311,299),"hurt":Rect2(153,155,285,318),"kneel":Rect2(190,219,292,254)}
# Original alpha > .08 bounds, measured from the supplied combat atlas pixels.
const ALPHA_BOUNDS={
	"hero":{"idle":Rect2(94,153,299,319),"windup":Rect2(54,152,288,320),"strike":Rect2(62,213,437,259),"guard":Rect2(76,135,274,337),"hurt":Rect2(25,167,312,304),"kneel":Rect2(75,230,312,244)},
	"rival":{"idle":Rect2(146,174,312,298),"windup":Rect2(113,153,324,319),"strike":Rect2(21,226,439,246),"guard":Rect2(137,152,319,319),"hurt":Rect2(154,156,271,320),"kneel":Rect2(179,216,305,258)},
	"沈青":{"idle":Rect2(74,68,269,403),"assist":Rect2(58,79,402,391),"cover":Rect2(57,83,317,388),"heal":Rect2(52,73,295,397)},
	"唐栖":{"idle":Rect2(110,61,227,410),"assist":Rect2(57,91,390,380),"cover":Rect2(68,72,311,399),"recover":Rect2(97,52,248,419)},
}
var formation:String="护后":
	set(value):
		if not _presenting: formation=value
var selected:String:
	get: return selected_id
	set(value): selected_id=value
var draw_labels:bool=true
var floor_mesh:ArrayMesh
var plate_box:StyleBoxFlat

func _ready()->void:
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP
	floor_mesh=_make_floor()
	for pose:String in Hero.POSES:Hero.texture_for(pose)
	for pose:String in Rival.POSES:Rival.texture_for(pose)
	for pose:String in Shen.POSES:Shen.texture_for(pose)
	for pose:String in Tang.POSES:Tang.texture_for(pose)
	Backdrop.texture()

func set_snapshot(value:Dictionary)->void:
	if _presenting:return
	super.set_snapshot(value)
	formation=String(value.get("formation","护后"))
	region_style="qingwei"

func support_home()->Vector2:
	return Vector2(235,470) if formation=="护后" else Vector2(300,515)

func hero_home()->Vector2:
	return HERO_FOOT if formation=="护后" else Vector2(455,580)

func hero_foot()->Vector2:
	var p:Dictionary=_pose()
	return hero_home()+Vector2(float(p.x),float(p.y))

func support_foot()->Vector2:
	var step:float=0.0
	if _presenting and _amount("support_damage")>0:
		step=(30.0 if companion_name=="唐栖" else 16.0)*_pulse(.36,.46,.66,action_time)
	return support_home()+Vector2(step,0)

func _pose(enemy:bool=false)->Dictionary:
	if enemy:return fighter_pose(locked_target_id if _presenting else selected_id)
	var p:Dictionary=super._pose(false)
	# Shared pose weights retain the accepted guard/hurt/kneel beats. Replace
	# its practice coordinates with an entirely grounded formation trajectory.
	p.x=0.0;p.y=0.0
	if not _presenting:return p
	if action in ["attack","skill"]:
		var id:String=locked_target_id
		var initial_pose:String="guard" if float(super.rig_pose(id).bracing)>0 else "idle"
		var target:Vector2=ENEMY_FEET[id]+(Vector2(RIVAL_CHEST[initial_pose])-Rival.FOOT)*(float(ACTOR_SIZE[id])/512.0)
		var contact:Vector2=target-(HERO_BLADE-Hero.FOOT)*(ACTOR_SIZE.hero/512.0)
		var approach:float=_ease(.13,.30,action_time)*(1-_ease(.43,.66,action_time))
		var travel:Vector2=(contact-hero_home())*approach
		p.x=travel.x-20*float(p.windup);p.y=travel.y
	elif action=="flee":p.x=-210*_ease(.05,.68,action_time)
	# Recoil is a short deck slide. No vertical bob moves registered feet off
	# the ground, and a completed action returns exactly to the formation slot.
	var recoil:float=0.0
	for i in range(presentation_result.get("counters",[]).size()):
		var at:float=COUNTER_AT+i*COUNTER_GAP
		recoil=maxf(recoil,_pulse(at-.005,at+.02,at+.23,action_time))
	p.x-=recoil*(11 if bool(presentation_details.get("guarded",false)) else 27)
	return p

func fighter_pose(id:String)->Dictionary:
	var p:Dictionary=super.rig_pose(id)
	p.x=float(p.recoil)*14.0;p.y=0.0;p.guard=float(p.bracing)
	if not _presenting or float(p.defeat)>0:return p
	var counters:Array=presentation_result.get("counters",[])
	for i in range(counters.size()):
		if String(counters[i].get("unit_id",""))!=id:continue
		var at:float=COUNTER_AT+i*COUNTER_GAP
		var approach:float=_ease(at-.16,at-.015,action_time)*(1-_ease(at+.08,at+.35,action_time))
		var contact:Vector2=event_anchor("counter")-(RIVAL_BLADE-Rival.FOOT)*(float(ACTOR_SIZE[id])/512.0)
		var travel:Vector2=(contact-Vector2(ENEMY_FEET[id]))*approach
		p.x+=travel.x;p.y=travel.y
		if action_time>=at-.28 and action_time<at+.35:p.guard=0.0
	return p

func fighter_visual_pose(id:String)->String:
	return Rival.pose_for(fighter_pose(id))

func fighter_foot(id:String)->Vector2:
	var p:Dictionary=fighter_pose(id)
	return Vector2(ENEMY_FEET[id])+Vector2(float(p.x),float(p.y))

func fighter_rect(id:String)->Rect2:
	return Rival.drawing_rect(fighter_foot(id),float(ACTOR_SIZE[id]))

func fighter_hit_rect(id:String)->Rect2:
	var bounds:Rect2=RIVAL_BODY[fighter_visual_pose(id)]
	var factor:float=float(ACTOR_SIZE[id])/512.0
	return Rect2(fighter_rect(id).position+bounds.position*factor,bounds.size*factor)

func target_anchor(id:String)->Vector2:
	return fighter_rect(id).position+Vector2(RIVAL_CHEST[fighter_visual_pose(id)])*(float(ACTOR_SIZE[id])/512.0)

func event_anchor(kind:String,source_id:String="")->Vector2:
	if kind in ["hero","support"]:return target_anchor(locked_target_id if _presenting else selected_id)
	if kind=="counter_source":return target_anchor(source_id)
	return Hero.drawing_rect(hero_foot(),ACTOR_SIZE.hero).position+Vector2(HERO_CHEST[hero_visual_pose()])*(ACTOR_SIZE.hero/512.0)

func blade_tip(id:String)->Vector2:
	if id=="hero":return Hero.drawing_rect(hero_foot(),ACTOR_SIZE.hero).position+HERO_BLADE*(ACTOR_SIZE.hero/512.0)
	return fighter_rect(id).position+RIVAL_BLADE*(float(ACTOR_SIZE[id])/512.0)

func support_visual_pose()->String:
	if not _presenting or not companion_active:return "idle"
	var t:float=action_time
	var counters:Array=presentation_result.get("counters",[])
	for i in range(counters.size()):
		var at:float=COUNTER_AT+i*COUNTER_GAP
		if int(counters[i].get("cover",0))>0 and t>=at-.20 and t<at+.24:return "cover"
	if companion_name=="沈青" and _amount("support_heal")>0 and t>=.51 and t<.80:return "heal"
	if companion_name=="唐栖" and _amount("support_qi")>0 and t>=.60 and t<.82:return "recover"
	if _amount("support_damage")>0 and t>=.36 and t<.65:return "assist"
	return "idle"

func actor_foot(id:String)->Vector2:
	if id=="hero":return hero_foot()
	if id=="support":return support_foot()
	return fighter_foot(id)

func actor_home(id:String)->Vector2:
	if id=="hero":return hero_home()
	if id=="support":return support_home()
	return ENEMY_FEET[id]

func actor_order()->Array[String]:
	var ids:Array[String]=["hero","bracer","striker"]
	if companion_active:ids.append("support")
	# Stable input order resolves ties; otherwise the actual ground Y controls
	# occlusion while a lunge crosses from a rear slot into the foreground.
	ids.sort_custom(func(a:String,b:String)->bool:return actor_foot(a).y<actor_foot(b).y)
	return ids

func actor_alpha_rect(id:String)->Rect2:
	var kind:String="rival"
	var pose:String
	var origin:Vector2
	var factor:float=float(ACTOR_SIZE[id])/512.0
	if id=="hero":
		kind="hero";pose=hero_visual_pose();origin=Hero.drawing_rect(hero_foot(),ACTOR_SIZE.hero).position
	elif id=="support":
		kind=companion_name if companion_active else "沈青";pose=support_visual_pose();origin=Shen.drawing_rect(support_foot(),ACTOR_SIZE.support).position
	else:pose=fighter_visual_pose(id);origin=fighter_rect(id).position
	var bounds:Rect2=ALPHA_BOUNDS[kind][pose]
	return Rect2(origin+bounds.position*factor,bounds.size*factor)

func unit_label_rect(id:String)->Rect2:
	var box:Rect2=label_rect(id,actor_foot(id))
	box.position.y=minf(box.position.y,actor_alpha_rect(id).position.y-box.size.y-8)
	return box

func unit_label_alpha(id:String)->float:
	if id=="support" and not companion_active:return 0.0
	if actor_foot(id).distance_to(actor_home(id))>3.0:return 0.0
	var box:Rect2=unit_label_rect(id)
	for other:String in actor_order():
		if box.intersects(actor_alpha_rect(other).grow(4)):return 0.0
	return 1.0

func target_at(point:Vector2)->String:
	var ids:Array[String]=actor_order();ids.reverse()
	for id:String in ids:
		if not ENEMY_FEET.has(id) or int(_shown_unit(id).get("hp",0))<=0:continue
		var foot:Vector2=fighter_foot(id)
		var ring:Vector2=(point-foot-Vector2(0,4))/Vector2(61,12)
		if fighter_hit_rect(id).has_point(point) or ring.length_squared()<=1:return id
	return ""

func _shown_unit(id:String)->Dictionary:
	return _unit(display_snapshot,id)

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
	_draw_stage()
	var target:String=locked_target_id if _presenting else selected_id
	if ENEMY_FEET.has(target) and int(_shown_unit(target).get("hp",0))>0:
		var start:Vector2=hero_foot()+Vector2(48,4);var end:Vector2=fighter_foot(target)-Vector2(49,-4)
		if not _presenting:
			for i in range(13):
				var t:float=float(i)/13
				draw_line(start.lerp(end,t),start.lerp(end,minf(1,t+.025)),Color(GOLD,.25),1.2,true)
	var actors:Array[String]=actor_order()
	# All shadows/rings live on the floor below every painted body.
	for id:String in actors:
		var foot:Vector2=actor_foot(id)
		_ellipse(foot+Vector2(0,5),Vector2(54,10),Color(.015,.05,.055,.5))
		if ENEMY_FEET.has(id) and int(_shown_unit(id).get("hp",0))>0:
			var color:Color=GOLD if id==target else Color(.65,.77,.78,.25)
			for i in range(44):
				var angle:float=float(i)*TAU/44
				draw_line(foot+Vector2(cos(angle)*61,sin(angle)*12+4),foot+Vector2(cos(angle+.10)*61,sin(angle+.10)*12+4),color,1.9 if id==target else 1.1,true)
	for id:String in actors:_actor(id,actor_foot(id))
	if _presenting:_draw_formation_effects()
	if draw_labels:
		for id:String in actors:_label_actor(id,actor_foot(id))

func _draw_stage()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("10272a"))
	var background=Backdrop.texture()
	if background:draw_texture_rect(background,Rect2(0,-25,1280,486),false,Color(.83,.92,.94))
	if floor_mesh:draw_mesh(floor_mesh,WOOD)
	# The dock edge and depth bands are structural timber, not selectable cells.
	draw_line(ground_point(0,0),ground_point(1,0),Color("4a5046"),13,true)
	draw_line(ground_point(0,0)+Vector2(0,3),ground_point(1,0)+Vector2(0,3),Color("92927a"),2,true)
	for y in [.32,.68]:draw_line(ground_point(0,y),ground_point(1,y),Color(.05,.12,.13,.25),2,true)
	for foot:Vector2 in [Vector2(115,337),Vector2(1165,337)]:
		draw_set_transform(foot,0,Vector2.ONE*2.05);Lantern.draw(self,Vector2.ZERO,phase);draw_set_transform(Vector2.ZERO)

func _actor(id:String,foot:Vector2)->void:
	if id=="hero":Hero.draw(self,foot,_pose(),1,ACTOR_SIZE.hero)
	elif id=="support":
		if companion_name=="唐栖":Tang.draw(self,foot,support_visual_pose(),1,ACTOR_SIZE.support)
		else:Shen.draw(self,foot,support_visual_pose(),1,ACTOR_SIZE.support)
	else:
		var pose:String=fighter_visual_pose(id)
		var texture:AtlasTexture=Rival.texture_for(pose)
		var tint:Color=Color(.70,.88,.91) if id=="bracer" else Color(1,.88,.76)
		if pose=="kneel":tint=tint.darkened(.22)
		if texture:draw_texture_rect(texture,fighter_rect(id),false,tint)

func _draw_formation_effects()->void:
	var t:float=action_time
	var hero:Vector2=hero_foot()
	var support:Vector2=support_foot()
	if action in ["attack","skill"] and _amount("hero_damage")>0:
		var contact:Vector2=event_anchor("hero")
		var cut:float=_pulse(.285,.335,.53,t)
		_draw_slash(contact+Vector2(-34,16),-1.95+_ease(.255,.37,t)*1.2,1.20,59,Color(.95,.89,.64,cut),action=="skill")
		_draw_impact(contact,.32,Color("e7d499"),action=="skill")
		if action=="skill":
			var aura:float=_pulse(.15,.32,.57,t)
			draw_arc(hero+Vector2(0,3),53,PI,TAU,28,Color(.50,.85,.79,aura*.60),3,true)
			_draw_word(String(presentation_details.get("art_name","")),hero_home()+Vector2(0,-219),Color("dfdec1"),.06,18,.66)
		_draw_number("enemy_damage",contact+Vector2(24,-51),.32,Color("f4dea0"),"−",26 if action=="skill" else 23)
	if _amount("support_damage")>0:
		var target:Vector2=event_anchor("support")
		var start:Vector2=support+Vector2(73,-98)
		var tip:Vector2=start.lerp(target,_ease(.38,.49,t))
		var strength:float=_pulse(.38,.49,.66,t)
		if companion_name=="沈青":
			var direction:Vector2=(target-start).normalized()
			for offset in [-4,0,4]:draw_line(tip-direction*24+Vector2(0,offset),tip+Vector2(0,offset),Color(.86,.95,.80,strength*.86),1.3,true)
		else:draw_line(start,tip,Color(.68,.85,.64,strength*.60),2,true)
		_draw_impact(target,.49,Color("a6cfa5"),false)
		_draw_number("companion_damage",target+Vector2(51,-24),.49,Color("b8d9ae"),"−",18)
	if _amount("heal")>0 or _amount("support_heal")>0:
		var at:float=.25 if _amount("heal")>0 else .56
		var glow:float=_pulse(at-.16,at,at+.30,t)
		draw_arc(hero+Vector2(0,-62),49,-PI,0,30,Color(.62,.87,.65,glow*.5),3,true)
	_draw_number("self_healing",hero+Vector2(-40,-188),.25,Color("b8e2a0"),"+",22)
	_draw_number("support_healing",hero+Vector2(-38,-163),.56,Color("b8e2a0"),"+",18)
	if _amount("support_heal")>0:_draw_word(companion_name+"照应",support+Vector2(0,28),Color("c5dab4"),.52,14,.35)
	if _amount("support_qi")>0:_draw_word("回气 +%d"%_amount("support_qi"),support+Vector2(0,28),Color("d5d6a0"),.49,14,.40)
	var qi_delta:int=int(presentation_result.get("hero_qi_delta",0))
	if qi_delta>0:_draw_word("真气 +%d"%qi_delta,hero_home()+Vector2(-30,-211),Color("d5d6a0"),.25,15,.6)
	var counters:Array=presentation_result.get("counters",[])
	for i in range(counters.size()):_draw_counter(counters[i],i)

func _draw_counter(counter:Dictionary,index:int)->void:
	var id:String=String(counter.get("unit_id",""))
	if not ENEMY_FEET.has(id):return
	var at:float=COUNTER_AT+index*COUNTER_GAP
	var finish:Vector2=event_anchor("counter")
	var strength:float=_pulse(at-.055,at+.005,at+.18,action_time)
	var guarded:bool=bool(counter.get("guarded",false))
	if strength>.001:
		draw_line(blade_tip(id)+Vector2(26,3),finish,Color(.91,.82,.65,strength*.38),3,true)
		_draw_slash(finish+Vector2(28,3),1.7,5.0,40,Color(.98,.69,.47,strength),bool(counter.get("heavy",false)))
	_draw_impact(finish,at,Color("b8eedc") if guarded else Color("d9b080"),bool(counter.get("heavy",false)))
	_draw_number("counter_%d"%index,hero_foot()+Vector2(-28-index*19,-177+index*14),at,Color("f1ba8f"),"−",23)
	if guarded:_draw_word("格挡",hero_foot()+Vector2(43,-137),Color("a8e2c6"),at,16,.36)
	if int(counter.get("cover",0))>0:
		var cover:float=_pulse(at-.18,at,at+.25,action_time)
		draw_arc(finish,49,-1.3,1.3,24,Color(.65,.85,.64,cover*.65),2.5,true)
		draw_line(support_foot()+Vector2(42,-91),finish,Color(.65,.85,.64,cover*.18),2,true)
		_draw_word(companion_name+"分担 %d"%int(counter.cover),support_foot()+Vector2(0,28),Color("c5dab4"),at,14,.42)

func _label_actor(id:String,_foot:Vector2)->void:
	if unit_label_alpha(id)<=0: return
	# Measured alpha bounds, not the transparent 512px cell, keep labels above hair.
	var box=unit_label_rect(id)
	var pos=box.position+Vector2(6,4)
	var name="无名客" if id=="hero" else (String(display_snapshot.get("companion","")) if id=="support" else String(_shown_unit(id).get("name","")))
	var width=148.0
	draw_style_box(_plate(),box)
	_text(name,pos+Vector2(width*.5,15),17,Color("f0e6ce"),true)
	if id=="support":
		_text("护后照应" if formation=="护后" else "并肩协击",pos+Vector2(width*.5,35),12,Color("b9d1bd"),true);return
	var hp=int(display_snapshot.get("hp",0)) if id=="hero" else int(_shown_unit(id).get("hp",0))
	var maximum=int(display_snapshot.get("max_hp",1)) if id=="hero" else int(_shown_unit(id).get("max_hp",1))
	draw_rect(Rect2(pos+Vector2(0,22),Vector2(width,5)),Color("253a38"))
	draw_rect(Rect2(pos+Vector2(0,22),Vector2(width*float(hp)/maxi(1,maximum),5)),Color("72af98") if id=="hero" else Color("bd7b62"))
	_text("%d / %d"%[hp,maximum],pos+Vector2(0,43),12,Color("dbd7c4"))
	var role="真气 %d/%d"%[int(display_snapshot.get("qi",0)),int(display_snapshot.get("max_qi",1))] if id=="hero" else ("援护" if id=="bracer" else "截签 · 将攻")
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
