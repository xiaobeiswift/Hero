extends Control
## Original ink-and-jade duel choreography. Presentation never changes battle rules.
## hit(kind, result) accepts the exact accepted HeroState result; missing values
## remain absent instead of fabricating damage from post-level-up health deltas.
signal presentation_finished
signal impact_presented(target: String, amount: int)

const SupportFeedback=preload("res://scripts/companion_battle_feedback.gd")
const PaintedShen=preload("res://scripts/painted_battle_shen.gd")
const SUPPORT_HOME=Vector2(126,266)
const FerryBackdrop=preload("res://scripts/ferry_battle_backdrop.gd")
const PaintedPuHeng=preload("res://scripts/painted_battle_puheng.gd")
const PaintedHero=preload("res://scripts/painted_battle_hero.gd")
const ACTION_DURATION: float = 1.34
const FINISH_DURATION: float = 1.18
const HERO_HOME = Vector2(229, 274)
const ENEMY_HOME = Vector2(721, 274)
const FONT = preload("res://assets/fonts/NotoSansSC.otf")
var painted_support_enabled:bool=true
var painted_backdrop_enabled:bool=true
var painted_hero_enabled:bool=true
var painted_enemy_enabled:bool=true
var enemy_identity:String=""
var phase: float = 0.0
var flash: float = 0.0
var action: String = ""
var companion_active: bool = false
var companion_name: String = "沈青"
var region_style: String = "qingwei"
var action_time: float = 0.0
var presentation_duration: float = 0.0
var presentation_details: Dictionary = {}
var _presenting: bool = false
var _emitted_impacts: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func hit(kind: String, details: Dictionary = {}) -> void:
	if details.has("valid") and not bool(details["valid"]):
		return
	action = kind
	presentation_details = _read_details(kind, details)
	action_time = 0.0
	presentation_duration = 0.72 if kind == "flee" else (ACTION_DURATION if presentation_details.get("counter", false) else FINISH_DURATION)
	_emitted_impacts.clear()
	_presenting = true
	flash = 1.0
	queue_redraw()

func is_presenting() -> bool:
	return _presenting

func get_presentation_duration() -> float:
	return presentation_duration

func reset_presentation() -> void:
	# Release any waiter on interruption. The caller owns a battle-generation
	# token so a cancelled turn cannot finish or refresh the next encounter.
	var was_presenting: bool = _presenting
	_presenting = false
	action = ""
	action_time = 0.0
	flash = 0.0
	presentation_details.clear()
	_emitted_impacts.clear()
	queue_redraw()
	if was_presenting:
		presentation_finished.emit()

func _process(delta: float) -> void:
	phase += maxf(0.0, delta)
	if _presenting:
		var previous: float = action_time
		action_time = minf(action_time + maxf(0.0, delta), presentation_duration)
		flash = 1.0 - action_time / maxf(0.001, presentation_duration)
		_emit_impact("healing", "self_healing", 0.25, previous)
		_emit_impact("enemy", "enemy_damage", 0.32, previous)
		_emit_impact("companion", "companion_damage", 0.49, previous)
		_emit_impact("support_healing", "support_healing", 0.56, previous)
		_emit_impact("player", "player_damage", 0.88, previous)
		if action_time >= presentation_duration:
			_presenting = false
			flash = 0.0
			presentation_finished.emit()
	queue_redraw()

func _emit_impact(target: String, key: String, at: float, previous: float) -> void:
	if previous < at and action_time >= at and not _emitted_impacts.has(target):
		_emitted_impacts[target] = true
		if presentation_details.has(key) and int(presentation_details[key]) > 0:
			impact_presented.emit(target, int(presentation_details[key]))

func _read_details(kind: String, details: Dictionary) -> Dictionary:
	var parsed: Dictionary = {"counter": false, "guarded": kind == "guard", "enemy_defeated": false, "player_defeated": false}
	var patterns: Dictionary = {
		"enemy_damage": "造成\\s*(\\d+)\\s*点伤害",
		"player_damage": "你受到\\s*(\\d+)\\s*点伤害",
		"healing": "恢复\\s*(\\d+)\\s*点气血",
		"companion_damage": "追加\\s*(\\d+)\\s*点伤害",
	}
	for entry in details.get("log", []):
		var line: String = str(entry)
		for key in patterns:
			var expression = RegEx.new()
			expression.compile(patterns[key])
			var matched = expression.search(line)
			if matched:
				parsed[key] = int(parsed.get(key, 0)) + int(matched.get_string(1))
		if line.contains("进入守势"):
			parsed["guarded"] = true
		if kind == "skill" and line.contains("！造成"):
			parsed["art_name"] = line.get_slice("！", 0)
	parsed["counter"] = int(parsed.get("player_damage", 0)) > 0
	parsed["enemy_defeated"] = bool(details.get("finished", false)) and bool(details.get("won", false))
	parsed["player_defeated"] = bool(details.get("finished", false)) and not bool(details.get("won", false)) and kind != "flee"
	for key in ["enemy_damage", "player_damage", "healing", "companion_damage", "counter", "guarded", "art_name", "enemy_defeated", "player_defeated"]:
		if details.has(key):
			parsed[key] = details[key]
	# An explicit damage payload is enough to request the matching counter beat.
	if details.has("player_damage") and not details.has("counter"):
		parsed["counter"] = int(details["player_damage"]) > 0
	if parsed["enemy_defeated"] or kind == "flee":
		parsed["counter"] = false
	parsed["support"]=SupportFeedback.read(details)
	parsed["support_healing"]=mini(int(parsed.get("healing",0)),int(parsed.support.healing))
	parsed["self_healing"]=maxi(0,int(parsed.get("healing",0))-int(parsed.support_healing))
	return parsed

func support_visual_pose()->String:
	return SupportFeedback.pose_for(presentation_details.get("support",{}),action_time,_presenting)

func _ease(a: float, b: float, t: float) -> float:
	var x: float = clampf((t-a)/maxf(0.001,b-a), 0.0, 1.0)
	return x*x*(3.0-2.0*x)

func _pulse(a: float, peak: float, b: float, t: float) -> float:
	return _ease(a, peak, t) * (1.0-_ease(peak,b,t))

func _pose(enemy: bool = false) -> Dictionary:
	var p: Dictionary = {"x": 0.0, "y": 0.0, "lean": 0.0, "strike": 0.0, "windup": 0.0, "guard": 0.0, "heal": 0.0, "recoil": 0.0, "defeat": 0.0}
	if not _presenting:
		return p
	var t: float = action_time
	if not enemy:
		if action in ["attack", "skill"]:
			p["windup"] = _pulse(0.0, 0.13, 0.26, t)
			var approach: float = _ease(0.13, 0.30, t) * (1.0 - _ease(0.43, 0.66, t))
			p["x"] = -20.0*float(p["windup"]) + 374.0*approach
			p["y"] = -12.0*_pulse(0.14,0.25,0.34,t)
			p["strike"] = _ease(0.26,0.325,t) * (1.0-_ease(0.42,0.58,t))
			p["lean"] = 0.20*approach - 0.15*float(p["windup"])
		elif action == "flee":
			p["x"] = -340.0*_ease(0.05,0.68,t)
			p["lean"] = -0.28
		p["guard"] = _ease(0.0,0.20,t)*(1.0-_ease(1.1,1.34,t)) if presentation_details.get("guarded",false) else 0.0
		p["heal"] = _pulse(0.02,0.25,0.59,t) if action == "item" else 0.0
		if presentation_details.get("counter",false):
			p["recoil"] = _pulse(0.875,0.90,1.12,t)
			p["x"] = float(p["x"]) - float(p["recoil"])*(11.0 if presentation_details.get("guarded",false) else 27.0)
		if presentation_details.get("player_defeated",false):
			p["defeat"] = _ease(0.94,1.22,t)
	else:
		p["recoil"] = _pulse(0.32,0.355,0.58,t) if action in ["attack","skill"] else 0.0
		if int(presentation_details.get("companion_damage",0))>0:p["recoil"]=maxf(float(p["recoil"]),_pulse(.49,.52,.71,t))
		p["x"] = float(p["recoil"])*22.0
		if presentation_details.get("counter",false):
			p["windup"] = _pulse(0.60,0.71,0.84,t)
			var approach: float = _ease(0.72,0.865,t)*(1.0-_ease(0.97,1.24,t))
			p["x"] = float(p["x"]) + 12.0*float(p["windup"]) - 366.0*approach
			p["y"] = -6.0*_pulse(0.73,0.80,0.875,t)
			p["strike"] = _ease(0.82,0.88,t)*(1.0-_ease(0.97,1.10,t))
			p["lean"] = 0.20*approach - 0.12*float(p["windup"])
		if presentation_details.get("enemy_defeated",false):
			p["defeat"] = _ease(.53 if int(presentation_details.get("companion_damage",0))>0 else .43,1.06,t)
	return p

func uses_painted_enemy()->bool:
	return painted_enemy_enabled and enemy_identity in ["蒲横","蒲横 · 切磋","蒲横 · 河帮执事"]

func enemy_visual_pose()->String:
	return PaintedPuHeng.pose_for(_pose(true))

func hero_visual_pose()->String:
	return PaintedHero.pose_for(_pose())

func _draw() -> void:
	_draw_stage()
	var hero: Dictionary = _pose()
	var enemy: Dictionary = _pose(true)
	var hero_pos: Vector2 = HERO_HOME + Vector2(hero.x, hero.y)
	var enemy_pos: Vector2 = ENEMY_HOME + Vector2(enemy.x, enemy.y)
	if _presenting:
		_draw_ground_motion(hero_pos, enemy_pos)
		_draw_auras(hero_pos)
		if action in ["attack","skill"] and action_time > 0.17 and action_time < 0.55:
			# Hand-painted motion echoes follow the actual dash, rather than a flash.
			for i in range(3,0,-1):
				var echo: Dictionary = hero.duplicate()
				_draw_fighter(hero_pos-Vector2(i*31,0), Color("6bb3a6"), true, phase, echo, false, (0.11-i*0.022)*(1.0-_ease(0.35,0.55,action_time)),1.0,"hero")
	if companion_active:
		var support: Dictionary = _pose()
		for key in support: support[key] = 0.0
		if _presenting and int(presentation_details.get("companion_damage",0)) > 0:
			support["strike"] = _pulse(0.36,0.46,0.66,action_time)
			support["x"] = float(support["strike"])*35.0
		if painted_support_enabled and companion_name=="沈青":
			_ellipse(SUPPORT_HOME+Vector2(0,4),Vector2(30,6),Color(.02,.06,.06,.30))
			PaintedShen.draw(self,SUPPORT_HOME+Vector2(0,sin(phase*2.4)*.65),support_visual_pose(),.96)
		else:
			_draw_fighter(SUPPORT_HOME+Vector2(float(support.x),0),Color("82978c") if companion_name=="唐栖" else Color("9cba9d"),true,phase+1,support,companion_name=="唐栖",0.90,0.91)
	_draw_fighter(enemy_pos, Color("aa7864"), false, phase+2, enemy,false,1.0,1.0,"enemy")
	_draw_fighter(hero_pos, Color("4f9c8b"), true, phase, hero,false,1.0,1.0,"hero")
	if _presenting:
		_draw_action_effects(hero_pos, enemy_pos)
	_draw_ambient()

func _draw_stage() -> void:
	if painted_backdrop_enabled and FerryBackdrop.applies(region_style) and FerryBackdrop.draw(self,size,phase):return
	var frost: bool = region_style == "frostbridge"
	draw_rect(Rect2(Vector2.ZERO,size),Color("172f3a") if frost else Color("0c252d"))
	for i in range(10):
		draw_rect(Rect2(0,126+i*15,938,16),Color(0.16,0.33,0.34,0.07+i*0.017))
	for i in range(7):
		var points = PackedVector2Array([Vector2(-50,210+i*13),Vector2(140+i*23,130+i*9),Vector2(270+i*35,190+i*6),Vector2(480+i*21,125+i*11),Vector2(940,185+i*13),Vector2(940,360),Vector2(-50,360)])
		draw_colored_polygon(points,Color(0.10+i*0.008,0.24+i*0.007,0.25+i*0.007,0.24))
	for radius in [57,41,27]:
		draw_circle(Vector2(488,154),radius,Color(0.91,0.82,0.59,0.045))
	draw_circle(Vector2(488,154),17,Color(0.91,0.85,0.68,0.13))
	for i in range(18):
		var x: float = fmod(i*89.0+phase*6,1000)-40
		var y: float = 203+i*5.8
		draw_line(Vector2(x,y),Vector2(x+38,y),Color(0.40,0.62,0.58,0.13),1)
	draw_colored_polygon(PackedVector2Array([Vector2(0,275),Vector2(938,275),Vector2(938,355),Vector2(0,355)]),Color("738a89") if frost else Color("596051"))
	for i in range(24):
		var x: int = i*41
		draw_line(Vector2(x,278),Vector2(x-14,354),Color("506b70") if frost else Color("343f3a"),2)
		for j in range(2):
			draw_line(Vector2(x+9+j*9,292+j*28),Vector2(x+22+j*8,291+j*28),Color(0.75,0.75,0.59,0.12),1)
	draw_line(Vector2(0,281),Vector2(938,281),Color("cbd3c6") if frost else Color("a29b75"),3)
	for x in [39,450,894]:
		draw_rect(Rect2(x,219,9,86),Color("3e453d"))
		draw_circle(Vector2(x+4,219),7,Color("958664"))
	draw_line(Vector2(43,233),Vector2(899,233),Color("807956"),2)
	if region_style=="training": _draw_training_court()
	if region_style=="mistwood": _draw_mistwood_stage()
	# Reflected low fog, under the actors and above the waterline.
	for i in range(3):
		_ellipse(Vector2(150+i*300+sin(phase*0.15+i)*18,257-i*8),Vector2(204,8),Color(0.66,0.81,0.73,0.025))

func _ink(hex: String, alpha: float) -> Color:
	var c: Color = Color(hex)
	c.a *= alpha
	return c

func _draw_fighter(p: Vector2, robe: Color, facing_right: bool, t: float, pose: Dictionary, short_ruler: bool = false, alpha: float = 1.0, actor_scale: float = 1.0, actor_id:String="") -> void:
	var dir: float = 1.0 if facing_right else -1.0
	var strike: float = float(pose.get("strike",0.0))
	var windup: float = float(pose.get("windup",0.0))
	var recoil: float = float(pose.get("recoil",0.0))
	var guard_pose: float = float(pose.get("guard",0.0))
	var heal: float = float(pose.get("heal",0.0))
	var defeat: float = float(pose.get("defeat",0.0))
	var lean: float = float(pose.get("lean",0.0)) - recoil*0.18 - defeat*0.5
	var bob: float = sin(t*2.4)*1.2*(1.0-strike)
	var flow: float = sin(t*3.6)*3.0+strike*19.0+windup*6.0
	robe.a = alpha
	draw_set_transform(p,0.0,Vector2(actor_scale,actor_scale))
	_ellipse(Vector2(0,3),Vector2(36+strike*13,7),Color(0.02,0.06,0.07,0.42*alpha))
	if (painted_hero_enabled and actor_id=="hero") or (uses_painted_enemy() and actor_id=="enemy"):
		# Key poses already contain anatomical lean; retain only subtle stage breathing.
		draw_set_transform(p+Vector2(0,bob),dir*(float(pose.get("lean",0))-recoil*.10)*.25,Vector2.ONE*actor_scale)
		var drawn=PaintedHero.draw(self,Vector2.ZERO,pose,alpha) if actor_id=="hero" else PaintedPuHeng.draw(self,Vector2.ZERO,pose,alpha)
		draw_set_transform(Vector2.ZERO)
		if drawn:return
	draw_set_transform(p+Vector2(0,bob+defeat*17),dir*lean,Vector2(dir*actor_scale,actor_scale))
	# Articulated feet, layered split robe and trailing sash.
	var back_foot: Vector2 = Vector2(-16-strike*19,-1-defeat*9)
	var front_foot: Vector2 = Vector2(14+strike*22,1-defeat*2)
	draw_line(Vector2(-8,-31),back_foot,_ink("172b2d",alpha),10,true)
	draw_line(Vector2(8,-30),front_foot,_ink("203435",alpha),11,true)
	draw_line(back_foot-Vector2(3,0),back_foot+Vector2(12,0),_ink("15292c",alpha),6,true)
	draw_line(front_foot-Vector2(3,0),front_foot+Vector2(13,0),_ink("15292c",alpha),6,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-12,-67),Vector2(-31,-54),Vector2(-49-flow,-18),Vector2(-34-flow,-25),Vector2(-22,-13)]),robe.darkened(0.24))
	draw_polyline(PackedVector2Array([Vector2(-12,-64),Vector2(-28-flow*0.3,-47),Vector2(-43-flow,-26)]),_ink("9ab6a0",alpha*0.47),1.3,true)
	var robe_points = PackedVector2Array([Vector2(-15,-65),Vector2(12,-65),Vector2(21+strike*9,-18),Vector2(28+strike*9,-10),Vector2(5,-14),Vector2(-8,-7),Vector2(-28-flow*0.20,-14)])
	draw_colored_polygon(robe_points,robe)
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-62),Vector2(6,-60),Vector2(8,-16),Vector2(-8,-11)]),robe.darkened(0.31))
	draw_line(Vector2(-11,-64),Vector2(1,-51),_ink("d5d4ac",alpha*0.84),3,true)
	draw_line(Vector2(11,-62),Vector2(1,-51),_ink("c4c6a0",alpha*0.84),3,true)
	draw_line(Vector2(-18,-37),Vector2(17,-38),_ink("d7c79e",alpha),5,true)
	draw_line(Vector2(9,-37),Vector2(10-flow*0.50,-13),_ink("d7c79e",alpha*0.90),3,true)
	draw_circle(Vector2(8,-37),3,_ink("b59760",alpha))
	var back_hand: Vector2 = Vector2(-29-strike*18,-33+strike*8-windup*8)
	draw_line(Vector2(-13,-57),back_hand,robe.darkened(0.17),13,true)
	draw_circle(back_hand,4,_ink("c9ab82",alpha))
	# Sword wrist moves through windup, cut, block and medicine poses.
	var hand: Vector2 = Vector2(36,-39).lerp(Vector2(-15,-79),windup)
	hand = hand.lerp(Vector2(50,-41),strike)
	hand = hand.lerp(Vector2(28,-57),guard_pose)
	hand = hand.lerp(Vector2(8,-64),heal)
	var elbow: Vector2 = Vector2(24,-49).lerp(Vector2(7,-67),windup).lerp(Vector2(31,-54),strike)
	draw_line(Vector2(10,-57),elbow,robe.lightened(0.06),13,true)
	draw_line(elbow,hand,robe.lightened(0.13),11,true)
	draw_line(hand-Vector2(6,1),hand,_ink("c3c8a5",alpha),7,true)
	draw_circle(hand,4.6,_ink("dfc49b",alpha))
	# Hairline, cheek, eye, topknot and loose ribbon retain an original silhouette.
	draw_circle(Vector2(0,-77),12.5,_ink("dec49d",alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(7,-80),Vector2(14,-75),Vector2(9,-73),Vector2(9,-69),Vector2(4,-66),Vector2(-7,-69)]),_ink("dec49d",alpha))
	draw_arc(Vector2(-1,-79),12,PI*0.96,PI*1.98,14,_ink("1b2b2e",alpha),8,true)
	draw_circle(Vector2(-6,-93),7,_ink("1b2b2e",alpha))
	draw_line(Vector2(-11,-83),Vector2(9,-83),_ink("2d4440",alpha),4,true)
	draw_circle(Vector2(7,-77),1.25,_ink("21332e",alpha))
	draw_line(Vector2(-8,-91),Vector2(1,-92),_ink("b9ab72",alpha),2,true)
	draw_polyline(PackedVector2Array([Vector2(-9,-84),Vector2(-21-flow*0.2,-80),Vector2(-30-flow*0.7,-85+sin(t*3.0)*3)]),_ink("bbc9a9",alpha*0.75),2.5,true)
	var angle: float = lerpf(-0.67,-2.30,windup)
	angle = lerpf(angle,0.37,strike)
	angle = lerpf(angle,-1.37,guard_pose)
	angle = lerpf(angle,1.05,heal)
	var blade: Vector2 = Vector2(cos(angle),sin(angle))
	var crossguard: Vector2 = Vector2(-blade.y,blade.x)
	var blade_length: float = 29.0 if short_ruler else 61.0
	var tip: Vector2 = hand + blade*blade_length
	draw_line(hand-blade*10,hand,_ink("473d32",alpha),5,true)
	draw_line(hand-crossguard*8,hand+crossguard*8,_ink("c1a46d",alpha),4,true)
	var metal: String = "baa57b" if short_ruler or (region_style=="training" and not facing_right) else "e2e7cf"
	draw_colored_polygon(PackedVector2Array([hand+blade*3-crossguard*2.3,tip,hand+blade*3+crossguard*2.3]),_ink(metal,alpha))
	draw_line(hand+blade*5,tip,_ink("f7f4d9",alpha*0.82),1,true)
	if heal>0.2:
		draw_circle(hand-Vector2(0,2),5,_ink("a6c6a4",alpha))
		draw_line(hand-Vector2(0,7),hand-Vector2(0,10),_ink("dbc293",alpha),5,true)
	draw_set_transform(Vector2.ZERO)

func _draw_ground_motion(hero_pos: Vector2, enemy_pos: Vector2) -> void:
	var t: float = action_time
	for center in [hero_pos, enemy_pos]:
		_ellipse(center+Vector2(0,6),Vector2(54,8),Color(0.02,0.09,0.10,0.08))
	if action in ["attack","skill"]:
		var dust: float = _pulse(0.10,0.30,0.68,t)
		for i in range(9):
			var travel: float = clampf((t-0.12)*2.0,0.0,1.0)
			var p: Vector2 = HERO_HOME+Vector2(-15-i*6-travel*40,3-sin(float(i))*3-travel*8)
			draw_circle(p,2.0+float(i%3),Color(0.76,0.75,0.57,dust*0.15))
		for i in range(5):
			draw_line(Vector2(272+i*32,266-i%2*6),Vector2(hero_pos.x-27,266-i%2*6),Color(0.68,0.81,0.67,dust*0.12),1,true)

func _draw_auras(hero_pos: Vector2) -> void:
	var t: float = action_time
	if action=="skill":
		var charge: float = _pulse(0.0,0.19,0.47,t)
		for i in range(3):
			draw_arc(hero_pos+Vector2(0,-45),31+i*10,-PI*0.92+t*8,PI*0.53+t*8,32,Color(0.44,0.85,0.77,charge*(0.30-i*0.07)),2,true)
		_ellipse(hero_pos+Vector2(0,2),Vector2(46,10),Color(0.45,0.83,0.75,charge*0.20))
	if presentation_details.get("guarded",false):
		var strength: float = _ease(0.03,0.22,t)*(1.0-_ease(1.05,1.30,t))
		var impact: float = _pulse(0.875,0.9,1.08,t) if presentation_details.get("counter",false) else 0.0
		var center: Vector2 = hero_pos+Vector2(6,-48)
		for i in range(3):
			draw_arc(center,43+i*5,-1.42,1.42,28,Color(0.53,0.91,0.83,strength*(0.47-i*0.13)+impact*0.13),2.0+impact*2,true)
		draw_line(center+Vector2(16,-40),center+Vector2(37,-25),Color(0.81,0.96,0.84,strength*0.7),2,true)
	if action=="item" or int(presentation_details.get("self_healing",0))>0:
		var strength: float = _pulse(0.05,0.32,0.83,t)
		for i in range(12):
			var a: float = i*2.4+t*3.0
			var rise: float = fmod(i*13.0+t*105.0,95.0)
			var p: Vector2 = HERO_HOME+Vector2(sin(a)*29,-rise)
			var c: Color = Color(0.64,0.91,0.58,strength*0.7)
			draw_line(p-Vector2(0,3),p+Vector2(0,3),c,1.5,true)
			draw_line(p-Vector2(3,0),p+Vector2(3,0),c,1.5,true)
		_ellipse(HERO_HOME+Vector2(0,3),Vector2(40,9),Color(0.62,0.89,0.53,strength*0.28))

func _draw_action_effects(hero_pos: Vector2, enemy_pos: Vector2) -> void:
	var t: float = action_time
	if action in ["attack","skill"]:
		var cut: float = _pulse(0.255,0.335,0.53,t)
		var swing: float = _ease(0.255,0.37,t)
		_draw_slash(Vector2(652,217),-1.95+swing*1.20,0.9+swing*0.34,82,Color(0.95,0.89,0.64,cut),action=="skill")
		_draw_impact(ENEMY_HOME+Vector2(0,-51),0.32,Color("e7d499"),action=="skill")
		if action=="skill":
			var beam: float = _pulse(0.23,0.32,0.53,t)
			for width in [18,8,2]:
				draw_line(Vector2(360,250),Vector2(775,188),Color(0.59,0.92,0.85,beam*(0.09 if width==18 else (0.29 if width==8 else 0.88))),width,true)
			_draw_slash(Vector2(686,227),-2.1+swing*0.4,1.48,62,Color(0.50,0.90,0.81,cut*0.60),true)
	if int(presentation_details.get("companion_damage",0))>0:
		var support: float = _pulse(0.40,0.49,0.68,t)
		if companion_name=="沈青":
			var tip:Vector2=(SUPPORT_HOME+Vector2(31,-45)).lerp(ENEMY_HOME+Vector2(1,-35),_ease(.38,.49,t))
			for offset in [-4,0,4]:draw_line(tip+Vector2(-19,offset),tip+Vector2(0,offset),Color(.86,.95,.80,support*.86),1.3,true)
		else:draw_line(Vector2(167,220),ENEMY_HOME+Vector2(1,-35),Color(0.68,0.85,0.64,support*0.6),2,true)
		_draw_impact(ENEMY_HOME+Vector2(6,-34),0.49,Color("a6cfa5"),false)
	if presentation_details.get("counter",false):
		var swing: float = _ease(0.82,0.94,t)
		var cut: float = _pulse(0.82,0.885,1.04,t)
		_draw_slash(Vector2(282,221),1.7+swing*0.5,4.5+swing*0.65,72,Color(0.98,0.69,0.47,cut),false)
		var guarded: bool = presentation_details.get("guarded",false)
		_draw_impact(HERO_HOME+Vector2(34 if guarded else 0,-51),0.88,Color("b8eedc") if guarded else Color("edab82"),not guarded)
		if guarded and t>=0.88:
			_draw_word("格挡",HERO_HOME+Vector2(43,-105),Color("a8e2c6"),0.88,17,0.39)
	_draw_number("enemy_damage",ENEMY_HOME+Vector2(2,-113),0.32,Color("f4dea0"),"−",27 if action=="skill" else 24)
	_draw_number("companion_damage",ENEMY_HOME+Vector2(38,-87),0.49,Color("b8d9ae"),"−",18)
	_draw_number("self_healing",HERO_HOME+Vector2(-25,-111),0.25,Color("b8e2a0"),"+",23)
	_draw_number("support_healing",HERO_HOME+Vector2(-27,-97),0.56,Color("b8e2a0"),"+",19)
	var support_fact:Dictionary=presentation_details.get("support",{})
	var covered:int=int(support_fact.get("cover",0))
	if covered>0:
		var strength:float=_pulse(.67,.88,1.2,t)
		draw_arc(HERO_HOME+Vector2(0,-45),47,-1.3,1.3,22,Color(.65,.85,.64,strength*.55),2,true)
		_draw_word(companion_name+"分担 "+str(covered),SUPPORT_HOME+Vector2(6,32),Color("c5dab4"),.82,14,.48)
	if int(support_fact.get("healing",0))>0:
		_draw_word(companion_name+"照应",SUPPORT_HOME+Vector2(1,29),Color("c5dab4"),.52,14,.35)
	if int(support_fact.get("qi",0))>0:
		_draw_word("回气 +"+str(support_fact.qi),SUPPORT_HOME+Vector2(1,29),Color("d5d6a0"),.49,14,.40)
	_draw_number("player_damage",HERO_HOME+Vector2(-9,-111),0.88,Color("f1ba8f"),"−",23)
	if action=="skill" and presentation_details.has("art_name"):
		_draw_word(String(presentation_details.art_name),Vector2(470,163),Color("dfdec1"),0.06,18,0.66)
	if action=="flee":
		for i in range(3):
			var strength: float = _pulse(0.06,0.18,0.55,t)
			draw_line(hero_pos+Vector2(20+i*7,-45+i*9),hero_pos+Vector2(78+i*11,-45+i*9),Color(0.62,0.79,0.71,strength*0.28),2,true)

func _draw_slash(center: Vector2, start: float, finish: float, radius: float, color: Color, empowered: bool) -> void:
	if color.a<=0.001: return
	# Tapered curved blade ribbon, with a soft broad halo and a sharp bright edge.
	var points = PackedVector2Array()
	for i in range(25):
		var f: float = float(i)/24.0
		var a: float = lerpf(start,finish,f)
		points.append(center+Vector2(cos(a),sin(a))*(radius+sin(f*PI)*(13.0 if empowered else 8.0)))
	for i in range(24,-1,-1):
		var f: float = float(i)/24.0
		var a: float = lerpf(start,finish,f)
		points.append(center+Vector2(cos(a),sin(a))*(radius-sin(f*PI)*3.0))
	var halo: Color = color
	halo.a *= 0.12
	draw_arc(center,radius,start,finish,36,halo,19.0 if empowered else 13.0,true)
	var body: Color = color
	body.a *= 0.52
	draw_colored_polygon(points,body)
	draw_arc(center,radius+2,start+0.15,finish-0.05,36,color,2.0,true)

func _draw_impact(center: Vector2, at: float, color: Color, strong: bool) -> void:
	var elapsed: float = action_time-at
	if elapsed<0.0 or elapsed>0.34: return
	var fade: float = 1.0-elapsed/0.34
	var expansion: float = _ease(0.0,0.34,elapsed)
	for i in range(11 if strong else 8):
		var angle: float = float(i)*2.399+0.27
		var ray: Vector2 = Vector2(cos(angle),sin(angle))
		var from: Vector2 = center+ray*(7+expansion*13)
		var to: Vector2 = center+ray*(20+expansion*(37 if strong else 23))
		var spark: Color = color
		spark.a = fade*(0.95 if i%2==0 else 0.45)
		draw_line(from,to,spark,2.4 if i%3==0 else 1.2,true)
	var flare: Color = color
	flare.a = fade*fade*0.14
	draw_circle(center,27+expansion*8,flare)
	flare.a = fade*fade*0.87
	draw_line(center-Vector2(12,0),center+Vector2(12,0),flare,3,true)
	draw_line(center-Vector2(0,17),center+Vector2(0,17),flare,2,true)

func _draw_number(key: String, origin: Vector2, at: float, color: Color, prefix: String, font_size: int) -> void:
	if not presentation_details.has(key) or int(presentation_details[key])<=0: return
	_draw_word(prefix+str(int(presentation_details[key])),origin,color,at,font_size,minf(0.72,presentation_duration-at-0.02))

func _draw_word(value: String, origin: Vector2, color: Color, at: float, font_size: int, lifetime: float) -> void:
	var elapsed: float = action_time-at
	if elapsed<0.0 or elapsed>lifetime: return
	var alpha: float = 1.0-_ease(lifetime*0.65,lifetime,elapsed)
	var y: float = -19*_ease(0.0,lifetime,elapsed)
	var width: float = FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var position: Vector2 = origin+Vector2(-width*0.5,y)
	var shadow: Color = Color(0.035,0.095,0.11,alpha*0.94)
	draw_string_outline(FONT,position,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,shadow)
	color.a = alpha
	draw_string(FONT,position,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_ambient() -> void:
	for i in range(13):
		var pos: Vector2 = Vector2(fmod(i*107+phase*9,938),168+sin(i+phase*0.4)*66)
		draw_circle(pos,1.2,Color(0.90,0.75,0.46,0.20+sin(phase+i)*0.12))

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(32):
		var a: float = TAU*i/32.0
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

func _draw_mistwood_stage()->void:
	draw_rect(Rect2(0,260,938,96),Color("49664f"))
	for i in range(8):
		var x=i*117.0
		draw_colored_polygon(PackedVector2Array([Vector2(x,285),Vector2(x+61,278),Vector2(x+83,305),Vector2(x+12,313)]),Color("788c70"))
	for base in [45,108,815,884]:
		for offset in [0,16,29]:
			var x=base+offset
			draw_line(Vector2(x,273),Vector2(x-7,126+offset),Color("4c7757"),6)
			for y in [160,194,226]:
				draw_line(Vector2(x-8,y),Vector2(x+4,y),Color("a4b28a"),2)
				draw_line(Vector2(x,y),Vector2(x+27,y-19),Color("709767"),3)
	for i in range(14):
		var x=fmod(i*83+phase*17,938)
		var y=144+fmod(i*53+phase*47,170)
		draw_line(Vector2(x,y),Vector2(x-4,y+13),Color(0.74,0.85,0.72,0.24),1)
