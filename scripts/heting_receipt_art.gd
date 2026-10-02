class_name HetingReceiptArt
extends "res://scripts/courtyard_practice_art.gd"
## Real two-opponent presentation. Only the courtyard's detached transaction,
## target lock, impact timing and display snapshots are inherited.
## The original river-gang combat sheet is deliberately reused as uniform art,
## not new portraits or Pu Heng identities. No rule/state method is called here.
const FIGHTER_FEET = {"striker": Vector2(626,279), "bracer": Vector2(793,302)}
const FIGHTER_SIZE = {"striker":216.0, "bracer":196.0}
const FIGHTER_TINT = {"striker":Color(1.0,.87,.73), "bracer":Color(.69,.88,.91)}
# Torso centers and body bounds measured within the reused 512px pose cells.
# The click area excludes the surrounding transparent atlas cell and blade.
const CHEST = {"idle":Vector2(288,294),"windup":Vector2(287,287),"strike":Vector2(326,312),"guard":Vector2(278,305),"hurt":Vector2(282,287),"kneel":Vector2(314,369)}
const BODY = {"idle":Rect2(145,174,313,299),"windup":Rect2(137,166,307,307),"strike":Rect2(67,221,402,252),"guard":Rect2(138,174,311,299),"hurt":Rect2(153,155,285,318),"kneel":Rect2(190,219,292,254)}

func _ready() -> void:
	# Avoid the practice initializer, which loads its timber/hemp prop textures.
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	region_style = "qingwei"
	painted_backdrop_enabled = true
	for name: String in PaintedHero.POSES: PaintedHero.texture_for(name)
	for name: String in PaintedShen.POSES: PaintedShen.texture_for(name)
	for name: String in PaintedTang.POSES: PaintedTang.texture_for(name)
	for name: String in PaintedPuHeng.POSES: PaintedPuHeng.texture_for(name)
	FerryBackdrop.texture()

func set_snapshot(snapshot: Dictionary) -> void:
	super.set_snapshot(snapshot)
	region_style = "qingwei"

func fighter_pose(id: String) -> Dictionary:
	var p: Dictionary = super.rig_pose(id)
	p["x"] = float(p.recoil)*14.0
	p["y"] = 0.0
	p["guard"] = float(p.bracing)
	if not _presenting or float(p.defeat)>0: return p
	var counters: Array = presentation_result.get("counters",[])
	for i in range(counters.size()):
		if String(counters[i].get("unit_id",""))!=id: continue
		var at: float = COUNTER_AT+i*COUNTER_GAP
		var approach: float = _ease(at-.16,at-.015,action_time)*(1-_ease(at+.08,at+.35,action_time))
		# The left-facing sword tip meets the hero's chest at contact. Feet move
		# along the deck; there are no projectile or rig mechanics in this draw.
		var scale_factor: float = float(FIGHTER_SIZE[id])/512.0
		var contact_foot: Vector2 = HERO_HOME+Vector2(279*scale_factor,196*scale_factor-65)
		var home: Vector2 = FIGHTER_FEET[id]
		p.x += (contact_foot.x-home.x)*approach
		p.y = (contact_foot.y-home.y)*approach
		p.guard = 0.0
	return p

func fighter_visual_pose(id: String) -> String:
	return PaintedPuHeng.pose_for(fighter_pose(id))

func fighter_foot(id: String) -> Vector2:
	var p: Dictionary = fighter_pose(id)
	return FIGHTER_FEET.get(id,FIGHTER_FEET.striker)+Vector2(float(p.x),float(p.y))

func fighter_rect(id: String) -> Rect2:
	return PaintedPuHeng.drawing_rect(fighter_foot(id),float(FIGHTER_SIZE.get(id,216.0)))

func fighter_hit_rect(id: String) -> Rect2:
	var bounds: Rect2 = BODY[fighter_visual_pose(id)]
	var scale_factor: float = float(FIGHTER_SIZE.get(id,216.0))/512.0
	return Rect2(fighter_rect(id).position+bounds.position*scale_factor,bounds.size*scale_factor)

func target_anchor(id: String) -> Vector2:
	return fighter_rect(id).position+Vector2(CHEST[fighter_visual_pose(id)])*(float(FIGHTER_SIZE.get(id,216.0))/512.0)

func event_anchor(kind: String, source_id: String = "") -> Vector2:
	# Both the renderer and presentation contract tests use these actor anchors.
	if kind=="hero" or kind=="support":
		return target_anchor(locked_target_id if _presenting else selected_id)
	if kind=="counter_source": return target_anchor(source_id)
	var hero: Dictionary = _pose()
	return HERO_HOME+Vector2(float(hero.x),float(hero.y))+Vector2(34 if bool(presentation_details.get("guarded",false)) else 0,-65)

func target_at(position: Vector2) -> String:
	for id: String in ["bracer","striker"]:
		if int(_unit(display_snapshot,id).get("hp",0))<=0: continue
		if fighter_hit_rect(id).has_point(position): return id
	return ""

func _pose(enemy: bool = false) -> Dictionary:
	if enemy: return fighter_pose(locked_target_id if _presenting else selected_id)
	var p: Dictionary = super._pose(false)
	if not _presenting or action not in ["attack","skill"]: return p
	var t: float = action_time
	var foot: Vector2 = FIGHTER_FEET.get(locked_target_id,FIGHTER_FEET.striker)
	var approach: float = _ease(.13,.30,t)*(1-_ease(.43,.66,t))
	p.x = (foot.x-106-HERO_HOME.x)*approach-20*float(p.windup)
	p.x -= float(p.recoil)*(11 if presentation_details.get("guarded",false) else 27)
	p.y = (foot.y-HERO_HOME.y)*approach-9*_pulse(.14,.25,.34,t)
	return p

func _draw() -> void:
	_draw_stage()
	var hero: Dictionary = _pose()
	var hero_pos: Vector2 = HERO_HOME+Vector2(float(hero.x),float(hero.y))
	var target: String = locked_target_id if _presenting else selected_id
	for id: String in FIGHTER_FEET: _draw_target_marker(id,id==target)
	if _presenting:
		_draw_ground_motion(hero_pos,fighter_foot(target))
		_draw_auras(hero_pos)
		if action in ["attack","skill"] and action_time>.17 and action_time<.55:
			for i in range(3,0,-1):
				_draw_fighter(hero_pos-Vector2(i*25,0),Color("6bb3a6"),true,phase,hero,false,(.10-i*.02)*(1-_ease(.35,.55,action_time)),1.0,"hero")
	_draw_support()
	_draw_receipt_fighter("striker")
	_draw_receipt_fighter("bracer")
	_draw_fighter(hero_pos,Color("4f9c8b"),true,phase,hero,false,1,1,"hero")
	if _presenting: _draw_receipt_effects(hero_pos)
	_draw_ambient()

func _draw_stage() -> void:
	FerryBackdrop.draw(self,size,phase)

func _draw_receipt_fighter(id: String) -> void:
	var foot: Vector2 = fighter_foot(id)
	var pose: String = fighter_visual_pose(id)
	var texture: AtlasTexture = PaintedPuHeng.texture_for(pose)
	var tint: Color = FIGHTER_TINT[id]
	if pose=="kneel": tint = tint.darkened(.22)
	_ellipse(foot+Vector2(0,3),Vector2(53 if id=="striker" else 48,7),Color(.02,.06,.07,.38))
	if texture!=null: draw_texture_rect(texture,fighter_rect(id),false,tint)

func _draw_target_marker(id: String, selected: bool) -> void:
	if int(_unit(display_snapshot,id).get("hp",0))<=0: return
	var foot: Vector2 = fighter_foot(id)
	var color: Color = Color("dfbd77") if selected else Color("9cb8bd")
	color.a = .82 if selected else .25
	for i in range(24):
		var angle: float = TAU*i/24
		draw_line(foot+Vector2(cos(angle)*56,sin(angle)*8+4),foot+Vector2(cos(angle+.17)*56,sin(angle+.17)*8+4),color,1.3,true)
	if selected:
		var center: Vector2 = Vector2(foot.x,fighter_hit_rect(id).position.y-10-sin(phase*3)*1.3)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-5,-5),center+Vector2(5,-5),center+Vector2(0,2)]),color)

func _draw_receipt_effects(hero_pos: Vector2) -> void:
	var t: float = action_time
	var foot: Vector2 = fighter_foot(locked_target_id)
	var target: Vector2 = event_anchor("hero")
	if action in ["attack","skill"] and _amount("hero_damage")>0:
		var cut: float = _pulse(.255,.335,.53,t)
		var swing: float = _ease(.255,.37,t)
		_draw_slash(target+Vector2(-34,16),-1.95+swing*1.2,.9+swing*.34,59,Color(.95,.89,.64,cut),action=="skill")
		_draw_impact(target,.32,Color("e7d499"),action=="skill")
		if action=="skill":
			var beam: float = _pulse(.23,.32,.53,t)
			for width in [13,6,2]: draw_line(hero_pos+Vector2(60,-72),target,Color(.59,.92,.85,beam*(.10 if width==13 else .30)),width,true)
		if bool(_unit(before_snapshot,locked_target_id).get("brace",false)):
			_draw_word("架刀护伴",fighter_foot("bracer")+Vector2(0,-133),Color("b0c6c8"),.32,14,.36)
	if _amount("support_damage")>0:
		var support: float = _pulse(.40,.49,.68,t)
		var tip: Vector2 = (SUPPORT_HOME+Vector2(31,-45)).lerp(event_anchor("support"),_ease(.38,.49,t))
		if companion_name=="沈青":
			for offset in [-4,0,4]: draw_line(tip+Vector2(-19,offset),tip+Vector2(0,offset),Color(.86,.95,.80,support*.86),1.3,true)
		else: draw_line(SUPPORT_HOME+Vector2(31,-45),tip,Color(.68,.85,.64,support*.6),2,true)
		_draw_impact(event_anchor("support"),.49,Color("a6cfa5"),false)
	_draw_number("enemy_damage",foot+Vector2(-3,-146),.32,Color("f4dea0"),"−",26 if action=="skill" else 23)
	_draw_number("companion_damage",foot+Vector2(36,-117),.49,Color("b8d9ae"),"−",18)
	_draw_number("self_healing",HERO_HOME+Vector2(-25,-124),.25,Color("b8e2a0"),"+",22)
	_draw_number("support_healing",HERO_HOME+Vector2(-28,-105),.56,Color("b8e2a0"),"+",18)
	var counters: Array = presentation_result.get("counters",[])
	for i in range(counters.size()): _draw_counter(counters[i],i)
	if action=="skill": _draw_word(String(presentation_details.get("art_name","")),Vector2(440,120),Color("dfdec1"),.06,18,.66)
	var qi_delta: int = int(presentation_result.get("hero_qi_delta",0))
	if qi_delta>0: _draw_word("真气 +%d"%qi_delta,HERO_HOME+Vector2(-25,-149),Color("d5d6a0"),.25,15,.6)
	if _amount("support_qi")>0: _draw_word("回气 +%d"%_amount("support_qi"),SUPPORT_HOME+Vector2(0,27),Color("d5d6a0"),.49,14,.4)
	if _amount("support_heal")>0: _draw_word(companion_name+"照应",SUPPORT_HOME+Vector2(0,27),Color("c5dab4"),.52,14,.35)

func _draw_counter(counter: Dictionary, index: int) -> void:
	var id: String = String(counter.get("unit_id",""))
	if not FIGHTER_FEET.has(id): return
	var at: float = COUNTER_AT+index*COUNTER_GAP
	var guarded: bool = bool(counter.get("guarded",false))
	var finish: Vector2 = event_anchor("counter")
	var source: Vector2 = event_anchor("counter_source",id)
	var strength: float = _pulse(at-.075,at+.005,at+.19,action_time)
	# A blade streak joins the lunging fighter's hand to the hero contact point.
	# Its source follows the actual countering unit, independent of selection.
	if strength>.001:
		draw_line(source+Vector2(-22,-1),finish,Color(.91,.82,.65,strength*.32),3,true)
		_draw_slash(finish+Vector2(30,3),1.7,5.0,40,Color(.98,.69,.47,strength),bool(counter.get("heavy",false)))
	_draw_impact(finish,at,Color("b8eedc") if guarded else Color("d9b080"),bool(counter.get("heavy",false)))
	_draw_number("counter_%d"%index,HERO_HOME+Vector2(-9-index*19,-128+index*14),at,Color("f1ba8f"),"−",23)
	if guarded: _draw_word("格挡",HERO_HOME+Vector2(39,-98),Color("a8e2c6"),at,16,.36)
	if int(counter.get("cover",0))>0:
		var cover: float = _pulse(at-.18,at,at+.25,action_time)
		draw_arc(HERO_HOME+Vector2(0,-55),47,-1.3,1.3,22,Color(.65,.85,.64,cover*.55),2,true)
		_draw_word(companion_name+"分担 %d"%int(counter.cover),SUPPORT_HOME+Vector2(1,28),Color("c5dab4"),at-.06,14,.42)
