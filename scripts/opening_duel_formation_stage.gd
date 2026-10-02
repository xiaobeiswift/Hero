extends "res://scripts/formation_battle_art.gd"
## Paint-only single-opponent variant. "bracer" is solely an existing measured
## stage slot; Pu Heng has no formation-encounter role or protection mechanic.

func _ready()->void:
	super._ready()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(false)

func actor_order()->Array[String]:
	var ids:Array[String]=["hero","bracer"]
	if companion_active:ids.append("support")
	ids.sort_custom(func(a:String,b:String)->bool:return actor_foot(a).y<actor_foot(b).y)
	return ids

func _actor(id:String,foot:Vector2)->void:
	if id=="bracer":
		# Use Pu Heng's original orange clothing, without the receipt guard tint.
		Rival.draw(self,foot,fighter_pose(id),1.0,ACTOR_SIZE.bracer)
	else:super._actor(id,foot)

func support_visual_pose()->String:
	return SupportFeedback.pose_for(presentation_details.get("support",{}),action_time,_presenting)

func _advance_display()->void:
	super._advance_display()
	# Explicit legacy payloads may suppress the counter pose while retaining an
	# incoming-damage fact. Its HP event still follows the legacy .88 beat.
	if presentation_result.get("counters",[]).is_empty() and _due("legacy_player",.88):
		display_snapshot["hp"]=maxi(0,int(display_snapshot.get("hp",0))-_amount("counter_damage"))

func _label_actor(id:String,_foot:Vector2)->void:
	if unit_label_alpha(id)<=0:return
	var box:Rect2=unit_label_rect(id)
	var pos:Vector2=box.position+Vector2(6,4)
	var title:String=String(display_snapshot.get("player_name","无名客")) if id=="hero" else (companion_name if id=="support" else String(_shown_unit(id).get("name","")))
	draw_style_box(_plate(),box)
	_text(title,pos+Vector2(74,15),17,Color("f0e6ce"),true)
	if id=="support":
		_text("护后照应" if formation=="护后" else "并肩协击",pos+Vector2(74,35),12,Color("b9d1bd"),true)
		return
	var hp:int=int(display_snapshot.get("hp",0)) if id=="hero" else int(_shown_unit(id).get("hp",0))
	var maximum:int=int(display_snapshot.get("max_hp",1)) if id=="hero" else int(_shown_unit(id).get("max_hp",1))
	draw_rect(Rect2(pos+Vector2(0,22),Vector2(148,5)),Color("253a38"))
	draw_rect(Rect2(pos+Vector2(0,22),Vector2(148*float(hp)/maxi(1,maximum),5)),Color("72af98") if id=="hero" else Color("bd7b62"))
	_text("%d / %d"%[hp,maximum],pos+Vector2(0,43),12,Color("dbd7c4"))
	if id=="hero":_text("真气 %d/%d"%[int(display_snapshot.get("qi",0)),int(display_snapshot.get("max_qi",1))],pos+Vector2(148,43),12,GOLD,false,true)
