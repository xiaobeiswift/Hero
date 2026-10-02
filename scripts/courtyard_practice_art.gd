class_name CourtyardPracticeArt
extends "res://scripts/battle_art.gd"
## Presentation consumes accepted exercise facts. It never calls game rules.
## display_snapshot is advanced before each impact signal; HUDs must not apply
## the damage a second time. The accepted target and before/after remain frozen
## during the whole animation, even if a caller attempts to change selection.
signal target_requested(id: String)

const Rigs = preload("res://scripts/courtyard_training_rigs.gd")
const PracticeBackdrop = preload("res://scripts/courtyard_practice_backdrop.gd")
const RIG_FEET = {"striker": Vector2(650,250), "bracer": Vector2(790,285)}
const COUNTER_AT: float = .88
const COUNTER_GAP: float = .18
var selected_id: String = "striker":
	set(value):
		if not _presenting: selected_id = value
var locked_target_id: String = ""
var display_snapshot: Dictionary = {}
var before_snapshot: Dictionary = {}
var after_snapshot: Dictionary = {}
var presentation_result: Dictionary = {}

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	region_style = "training"
	painted_backdrop_enabled = false
	# Cache all possible frames up front, not on an impact frame.
	for name: String in PaintedHero.POSES: PaintedHero.texture_for(name)
	for name: String in PaintedShen.POSES: PaintedShen.texture_for(name)
	for name: String in PaintedTang.POSES: PaintedTang.texture_for(name)
	Rigs.texture_for("timber")
	Rigs.texture_for("hemp")

func set_snapshot(snapshot: Dictionary) -> void:
	if _presenting: return
	display_snapshot = snapshot.duplicate(true)
	selected_id = String(snapshot.get("selected_id", "striker"))
	companion_name = String(snapshot.get("companion", ""))
	companion_active = companion_name in ["沈青", "唐栖"]
	region_style = "training"
	queue_redraw()

func present(result: Dictionary) -> bool:
	if _presenting or not bool(result.get("accepted",false)) or not bool(result.get("ok",false)): return false
	var incoming_action: String = String(result.get("action",""))
	if incoming_action not in ["attack","skill","guard","item","flee"]: return false
	if not result.get("before",{}) is Dictionary or not result.get("after",{}) is Dictionary: return false
	if incoming_action in ["attack","skill"] and not RIG_FEET.has(String(result.get("target_id",""))): return false
	presentation_result = result.duplicate(true)
	before_snapshot = presentation_result.get("before",{}).duplicate(true)
	after_snapshot = presentation_result.get("after",{}).duplicate(true)
	set_snapshot(before_snapshot)
	locked_target_id = String(presentation_result.get("target_id",""))
	selected_id = locked_target_id
	display_snapshot["selected_id"] = locked_target_id
	display_snapshot["locked"] = true
	action = incoming_action
	action_time = 0.0
	var counters: Array = presentation_result.get("counters",[])
	presentation_duration = .72 if action == "flee" else maxf(1.18, COUNTER_AT + maxf(0,counters.size()-1)*COUNTER_GAP + .46)
	var support: Dictionary = {"name":companion_name,"damage":_amount("support_damage"),"healing":_amount("support_heal"),"qi":_amount("support_qi"),"cover":0}
	for counter: Dictionary in counters: support.cover += int(counter.get("cover",0))
	presentation_details = {
		"enemy_damage":_amount("hero_damage"),"companion_damage":_amount("support_damage"),
		"player_damage":_amount("counter_damage"),"self_healing":_amount("heal"),
		"support_healing":_amount("support_heal"),"healing":_amount("heal")+_amount("support_heal"),
		"counter":not counters.is_empty(),"guarded":bool(result.get("guarded",false)),
		"player_defeated":String(after_snapshot.get("outcome",""))=="defeat",
		"support":support,"art_name":String(before_snapshot.get("equipped_art","")),
	}
	for i in range(counters.size()): presentation_details["counter_%d"%i] = int(counters[i].get("damage",0))
	_emitted_impacts.clear()
	_presenting = true
	flash = 1.0
	queue_redraw()
	return true

func _process(delta: float) -> void:
	phase += maxf(0,delta)
	if _presenting:
		action_time = minf(action_time+maxf(0,delta),presentation_duration)
		_advance_display()
		flash = 1.0-action_time/maxf(.001,presentation_duration)
		if action_time >= presentation_duration:
			display_snapshot = after_snapshot.duplicate(true)
			_presenting = false
			flash = 0.0
			presentation_finished.emit()
	queue_redraw()

func reset_presentation() -> void:
	var was_presenting: bool = _presenting
	if was_presenting and not after_snapshot.is_empty(): display_snapshot = after_snapshot.duplicate(true)
	_presenting = false
	action = ""
	action_time = 0.0
	presentation_duration = 0.0
	flash = 0.0
	presentation_result.clear()
	presentation_details.clear()
	before_snapshot.clear()
	after_snapshot.clear()
	locked_target_id = ""
	_emitted_impacts.clear()
	queue_redraw()
	if was_presenting: presentation_finished.emit()

func _amount(key: String) -> int:
	return maxi(0,int(presentation_result.get(key,0)))

func _due(key: String, at: float) -> bool:
	if action_time < at or _emitted_impacts.has(key): return false
	_emitted_impacts[key] = true
	return true

func _advance_display() -> void:
	# All data changes are bounded by actual accepted facts, never net HP deltas.
	if _due("hero_qi",.08 if action=="skill" else .25):
		var qi_change: int = int(presentation_result.get("hero_qi_delta",0))
		display_snapshot["qi"] = clampi(int(display_snapshot.get("qi",0))+qi_change,0,int(display_snapshot.get("max_qi",0)))
		if action=="item": display_snapshot["medicine"] = int(after_snapshot.get("medicine",0))
		if qi_change != 0: impact_presented.emit("qi",qi_change)
	if _due("healing",.25):
		_heal_display(_amount("heal"))
		if _amount("heal")>0: impact_presented.emit("healing",_amount("heal"))
	if _due("enemy",.32):
		_damage_display_target(_amount("hero_damage"))
		if _amount("hero_damage")>0: impact_presented.emit("enemy",_amount("hero_damage"))
	if _due("companion",.49):
		_damage_display_target(_amount("support_damage"))
		display_snapshot["qi"] = mini(int(display_snapshot.get("max_qi",0)),int(display_snapshot.get("qi",0))+_amount("support_qi"))
		if _amount("support_damage")>0: impact_presented.emit("companion",_amount("support_damage"))
		elif _amount("support_qi")>0: impact_presented.emit("support_qi",_amount("support_qi"))
	if _due("support_healing",.56):
		_heal_display(_amount("support_heal"))
		if _amount("support_heal")>0: impact_presented.emit("support_healing",_amount("support_heal"))
	var counters: Array = presentation_result.get("counters",[])
	for i in range(counters.size()):
		if _due("counter_%d"%i,COUNTER_AT+i*COUNTER_GAP):
			var damage: int = maxi(0,int(counters[i].get("damage",0)))
			display_snapshot["hp"] = maxi(0,int(display_snapshot.get("hp",0))-damage)
			if damage>0: impact_presented.emit("player",damage)

func _heal_display(amount: int) -> void:
	display_snapshot["hp"] = mini(int(display_snapshot.get("max_hp",0)),int(display_snapshot.get("hp",0))+amount)

func _damage_display_target(amount: int) -> void:
	var unit: Dictionary = _unit(display_snapshot,locked_target_id)
	if not unit.is_empty(): unit["hp"] = maxi(0,int(unit.get("hp",0))-amount)

func _unit(snapshot: Dictionary, id: String) -> Dictionary:
	for unit: Dictionary in snapshot.get("units",[]):
		if String(unit.get("id",""))==id: return unit
	return {}

func target_at(position: Vector2) -> String:
	# Front-most rig wins overlapping hits. This is a request, not a state write.
	for id: String in ["bracer","striker"]:
		if int(_unit(display_snapshot,id).get("hp",0))<=0: continue
		if Rigs.drawing_rect(RIG_FEET[id],id,rig_pose(id),phase).has_point(position): return id
	return ""

func _gui_input(event: InputEvent) -> void:
	if _presenting: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var id: String = target_at(event.position)
		if not id.is_empty():
			target_requested.emit(id)
			accept_event()

func rig_pose(id: String) -> Dictionary:
	var source: Dictionary = before_snapshot if _presenting else display_snapshot
	var unit: Dictionary = _unit(source,id)
	var p: Dictionary = {"windup":0.0,"strike":0.0,"recoil":0.0,"defeat":0.0,"bracing":0.0}
	if int(unit.get("hp",0))<=0:
		p.defeat = 1.0
		return p
	var intent: Dictionary = unit.get("intent_data",{})
	if id=="bracer" and String(intent.get("kind",""))=="protect": p.bracing = .65
	if not _presenting: return p
	var t: float = action_time
	if id==locked_target_id:
		if _amount("hero_damage")>0: p.recoil = _pulse(.32,.36,.57,t)
		if _amount("support_damage")>0: p.recoil = maxf(p.recoil,_pulse(.49,.53,.71,t))
		if int(_unit(after_snapshot,id).get("hp",0))<=0:
			var last_hit: float = .32 if _amount("hero_damage")>=int(unit.get("hp",0)) else .49
			p.defeat = _ease(last_hit+.05,last_hit+.50,t)
	if id=="bracer" and float(p.bracing)>0:
		p.bracing = maxf(p.bracing,_pulse(.17,.32,.61,t))
	var counters: Array = presentation_result.get("counters",[])
	for i in range(counters.size()):
		if String(counters[i].get("unit_id",""))!=id: continue
		var at: float = COUNTER_AT+i*COUNTER_GAP
		p.windup = maxf(p.windup,_pulse(at-.28,at-.16,at-.04,t))
		p.strike = maxf(p.strike,_ease(at-.07,at,t)*(1-_ease(at+.06,at+.25,t)))
	return p

func _pose(enemy: bool = false) -> Dictionary:
	if enemy: return rig_pose(locked_target_id if _presenting else selected_id)
	var p: Dictionary = {"x":0.0,"y":0.0,"lean":0.0,"strike":0.0,"windup":0.0,"guard":0.0,"heal":0.0,"recoil":0.0,"defeat":0.0}
	if not _presenting:
		p.defeat = 1.0 if String(display_snapshot.get("outcome",""))=="defeat" else 0.0
		return p
	var t: float = action_time
	if action in ["attack","skill"]:
		var foot: Vector2 = RIG_FEET.get(locked_target_id,RIG_FEET.striker)
		var approach: float = _ease(.13,.30,t)*(1-_ease(.43,.66,t))
		p.windup = _pulse(0,.13,.26,t)
		p.x = (foot.x-102-HERO_HOME.x)*approach-20*float(p.windup)
		p.y = (foot.y+4-HERO_HOME.y)*approach-12*_pulse(.14,.25,.34,t)
		p.strike = _ease(.26,.325,t)*(1-_ease(.42,.58,t))
		p.lean = .20*approach-.15*float(p.windup)
	elif action=="flee":
		p.x = -340*_ease(.05,.68,t)
		p.lean = -.28
	p.guard = _ease(0,.2,t)*(1-_ease(presentation_duration-.20,presentation_duration,t)) if bool(presentation_details.get("guarded",false)) else 0.0
	p.heal = _pulse(.02,.25,.59,t) if action=="item" else 0.0
	var counters: Array = presentation_result.get("counters",[])
	for i in range(counters.size()):
		var at: float = COUNTER_AT+i*COUNTER_GAP
		p.recoil = maxf(p.recoil,_pulse(at-.005,at+.02,at+.23,t))
	p.x -= float(p.recoil)*(11 if presentation_details.get("guarded",false) else 27)
	# Keep the painted block readable during mitigated contact; retain the short
	# knockback above without letting the shared hurt-first crop override guard.
	if bool(presentation_details.get("guarded",false)): p.recoil *= .10
	if bool(presentation_details.get("player_defeated",false)):
		var last: float = COUNTER_AT+maxi(0,counters.size()-1)*COUNTER_GAP
		p.defeat = _ease(last+.05,last+.34,t)
	return p

func _draw() -> void:
	_draw_stage()
	var hero: Dictionary = _pose()
	var hero_pos: Vector2 = HERO_HOME+Vector2(hero.x,hero.y)
	var target: String = locked_target_id if _presenting else selected_id
	for id: String in Rigs.ROLES: _draw_target_marker(id,id==target)
	if _presenting:
		_draw_ground_motion(hero_pos,RIG_FEET.get(target,RIG_FEET.striker))
		_draw_auras(hero_pos)
		if action in ["attack","skill"] and action_time>.17 and action_time<.55:
			for i in range(3,0,-1):
				_draw_fighter(hero_pos-Vector2(i*25,0),Color("6bb3a6"),true,phase,hero,false,(.10-i*.02)*(1-_ease(.35,.55,action_time)),1.0,"hero")
	_draw_support()
	Rigs.draw(self,RIG_FEET.striker,"striker",rig_pose("striker"),phase)
	Rigs.draw(self,RIG_FEET.bracer,"bracer",rig_pose("bracer"),phase)
	_draw_fighter(hero_pos,Color("4f9c8b"),true,phase,hero,false,1,1,"hero")
	if _presenting: _draw_practice_effects(hero_pos)
	_draw_ambient()

func _draw_stage() -> void:
	PracticeBackdrop.draw(self,size,phase)

func _draw_target_marker(id: String, selected: bool) -> void:
	if int(_unit(display_snapshot,id).get("hp",0))<=0: return
	var foot: Vector2 = RIG_FEET[id]
	var color := Color("d1bd7f") if selected else Color("91aa8c")
	color.a = .76 if selected else .23
	_ellipse(foot+Vector2(0,5),Vector2(43 if id=="striker" else 50,8),Color(color,.075))
	for i in range(24):
		var a: float = TAU*i/24
		var b: float = a+.17
		draw_line(foot+Vector2(cos(a)*43,sin(a)*8+5),foot+Vector2(cos(b)*43,sin(b)*8+5),color,1.3,true)
	if selected:
		var center: Vector2 = foot+Vector2(0,-139-sin(phase*3)*1.3)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-5,-5),center+Vector2(5,-5),center+Vector2(0,2)]),color)

func _draw_support() -> void:
	if not companion_active: return
	var pose: String = support_visual_pose()
	var offset: float = 30*_pulse(.36,.46,.66,action_time) if _presenting and companion_name=="唐栖" and _amount("support_damage")>0 else 0.0
	var foot: Vector2 = SUPPORT_HOME+Vector2(offset,sin(phase*2.4)*.65)
	_ellipse(foot+Vector2(0,4),Vector2(30,6),Color(.02,.06,.06,.30))
	if companion_name=="唐栖": PaintedTang.draw(self,foot,pose,.96)
	else: PaintedShen.draw(self,foot,pose,.96)

func _draw_practice_effects(_hero_pos: Vector2) -> void:
	var t: float = action_time
	var target_foot: Vector2 = RIG_FEET.get(locked_target_id,RIG_FEET.striker)
	var target: Vector2 = Rigs.target_anchor(target_foot,locked_target_id,rig_pose(locked_target_id),phase)
	if action in ["attack","skill"] and _amount("hero_damage")>0:
		var cut: float = _pulse(.255,.335,.53,t)
		var swing: float = _ease(.255,.37,t)
		_draw_slash(target+Vector2(-34,16),-1.95+swing*1.2,.9+swing*.34,59,Color(.95,.89,.64,cut),action=="skill")
		_draw_impact(target,.32,Color("e7d499"),action=="skill")
		if action=="skill":
			var beam: float = _pulse(.23,.32,.53,t)
			for width in [13,6,2]: draw_line(HERO_HOME+Vector2(60,-43),target+Vector2(12,-7),Color(.59,.92,.85,beam*(.10 if width==13 else .30)),width,true)
		if bool(_unit(before_snapshot,locked_target_id).get("brace",false)):
			_draw_word("护伴",RIG_FEET.bracer+Vector2(-35,-132),Color("b0c6a1"),.32,14,.36)
	if _amount("support_damage")>0:
		var support: float = _pulse(.40,.49,.68,t)
		var tip: Vector2 = (SUPPORT_HOME+Vector2(31,-45)).lerp(target,_ease(.38,.49,t))
		if companion_name=="沈青":
			for offset in [-4,0,4]: draw_line(tip+Vector2(-19,offset),tip+Vector2(0,offset),Color(.86,.95,.80,support*.86),1.3,true)
		else: draw_line(SUPPORT_HOME+Vector2(31,-45),tip,Color(.68,.85,.64,support*.6),2,true)
		_draw_impact(target+Vector2(6,8),.49,Color("a6cfa5"),false)
	_draw_number("enemy_damage",target_foot+Vector2(-3,-138),.32,Color("f4dea0"),"−",26 if action=="skill" else 23)
	_draw_number("companion_damage",target_foot+Vector2(36,-111),.49,Color("b8d9ae"),"−",18)
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
	if not RIG_FEET.has(id): return
	var at: float = COUNTER_AT+index*COUNTER_GAP
	var t: float = action_time
	var guarded: bool = bool(counter.get("guarded",false))
	var start: Vector2 = Rigs.target_anchor(RIG_FEET[id],id,rig_pose(id),phase)+Vector2(-22,0)
	var finish: Vector2 = HERO_HOME+Vector2(34 if guarded else 0,-62)
	if t>=at-.16 and t<at:
		var progress: float = _ease(at-.16,at,t)
		var point: Vector2 = start.lerp(finish,progress)+Vector2(0,-sin(progress*PI)*22)
		var direction: Vector2 = (finish-start).normalized()
		draw_line(point-direction*31,point,Color(.65,.64,.43,.22),2,true)
		draw_line(point-direction*15,point+direction*5,Color("c3a775"),4,true)
		draw_line(point-direction*11+Vector2(0,-2),point-direction*9+Vector2(0,2),Color("d6c9a6"),2,true)
	_draw_impact(finish,at,Color("b8eedc") if guarded else Color("d9b080"),bool(counter.get("heavy",false)))
	_draw_number("counter_%d"%index,HERO_HOME+Vector2(-9-index*19,-128+index*14),at,Color("f1ba8f"),"−",23)
	if guarded: _draw_word("格挡",HERO_HOME+Vector2(39,-98),Color("a8e2c6"),at,16,.36)
	if int(counter.get("cover",0))>0:
		var cover: float = _pulse(at-.18,at,at+.25,t)
		draw_arc(HERO_HOME+Vector2(0,-55),47,-1.3,1.3,22,Color(.65,.85,.64,cover*.55),2,true)
		_draw_word(companion_name+"分担 %d"%int(counter.cover),SUPPORT_HOME+Vector2(1,28),Color("c5dab4"),at-.06,14,.42)
