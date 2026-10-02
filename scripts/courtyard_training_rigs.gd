class_name CourtyardTrainingRigs
extends RefCounted
## Original mechanical training props, drawn in the 938-wide duel coordinate space.
## Presentation only: no state, damage, targeting rules, timers, or randomness.
## PNG sources are existing painted project assets. Resource objects are cached;
## draw calls create no textures, images, meshes, materials, or scene nodes.

const TIMBER_PATH = "res://assets/generated/environment/qingwei_deck_wood.png"
const HEMP_PATH = "res://assets/generated/environment/heting_machinery_atlas.png"
const FOOT = Vector2.ZERO
const ROLES = ["striker", "bracer"]
const TIMBER_REGIONS = [Rect2(93, 242, 51, 622), Rect2(184, 96, 60, 644), Rect2(361, 326, 61, 666)]
const ROPE_REGION = Rect2(91, 79, 37, 54)
const CLOTH_REGION = Rect2(872, 88, 54, 40)
const INK = Color("302b23")
const IRON = Color("4d514a")
const EDGE = Color("aa9270")
const ROPE = Color("b3a17a")
const JADE = Color("738d77")
const RUSSET = Color("a36e53")
static var _timber: Texture2D
static var _hemp: Texture2D

static func canonical_role(role: String) -> String:
	if role in ["striker", "strike"]: return "striker"
	if role in ["bracer", "brace"]: return "bracer"
	return ""

static func texture_for(material: String) -> Texture2D:
	if material == "timber":
		if _timber == null and ResourceLoader.exists(TIMBER_PATH): _timber = load(TIMBER_PATH)
		return _timber
	if material == "hemp":
		if _hemp == null and ResourceLoader.exists(HEMP_PATH): _hemp = load(HEMP_PATH)
		return _hemp
	return null

static func normalized_pose(pose: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for key in ["windup", "strike", "recoil", "defeat", "bracing"]:
		var value = pose.get(key, 0.0)
		var amount: float = float(value) if value is float or value is int else 0.0
		clean[key] = clampf(amount, 0.0, 1.0) if is_finite(amount) else 0.0
	# A broken rig settles; attack or brace progress cannot resurrect its posture.
	for key in ["windup", "strike", "recoil", "bracing"]:
		clean[key] *= 1.0 - float(clean.defeat)
	return clean

static func body_transform(foot: Vector2, role: String, pose: Dictionary = {}, time: float = 0.0) -> Transform2D:
	var p: Dictionary = normalized_pose(pose)
	var brace: bool = canonical_role(role) == "bracer"
	var settle: float = float(p.defeat)
	var safe_time: float = time if is_finite(time) else 0.0
	var tremble: float = sin(safe_time * 3.1) * 0.004 * (1.0 - settle)
	var angle: float = tremble + float(p.recoil) * 0.10 + settle * (0.62 if brace else 0.82)
	angle += (-0.065 * float(p.bracing)) if brace else (0.018 * float(p.windup) - 0.025 * float(p.strike))
	var pivot: Vector2 = foot + Vector2(0, -9)
	var transform := Transform2D(angle, Vector2(1.0, 1.0 - settle * 0.24), 0.0, pivot)
	transform.origin -= transform.basis_xform(Vector2(0, -9))
	return transform

static func foot_anchor(foot: Vector2, _role: String = "striker") -> Vector2:
	return foot

static func target_anchor(foot: Vector2, role: String, pose: Dictionary = {}, time: float = 0.0) -> Vector2:
	return body_transform(foot, role, pose, time) * Vector2(0, -77 if canonical_role(role) == "bracer" else -84)

static func drawing_rect(foot: Vector2, role: String, pose: Dictionary = {}, time: float = 0.0) -> Rect2:
	var kind: String = canonical_role(role)
	if kind.is_empty(): return Rect2()
	# Conservative visual envelope includes the full arm swing and loose bindings.
	var local := Rect2(-55, -130, 100, 131) if kind == "striker" else Rect2(-53, -129, 110, 133)
	var transform: Transform2D = body_transform(foot, kind, pose, time)
	var bounds := Rect2(transform * local.position, Vector2.ZERO)
	for point in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		bounds = bounds.expand(transform * point)
	# The grounded timber sled stays put while the frame recoils or folds.
	return bounds.merge(Rect2(foot + Vector2(-43, -11), Vector2(87, 17))).grow(2.0)

static func draw(canvas: CanvasItem, foot: Vector2, role: String, pose: Dictionary = {}, time: float = 0.0) -> bool:
	var kind: String = canonical_role(role)
	if kind.is_empty(): return false
	# Prime both resources once, outside the individual component draws.
	texture_for("timber")
	texture_for("hemp")
	var p: Dictionary = normalized_pose(pose)
	var transform: Transform2D = body_transform(foot, kind, pose, time)
	var ground := Transform2D(0.0, foot)
	_shadow(canvas, foot + Vector2(1, 3), Vector2(39 if kind == "striker" else 48, 8))
	_base(canvas, ground, kind == "bracer")
	if kind == "striker": _striker(canvas, transform, p, time)
	else: _bracer(canvas, transform, p, time)
	return true

static func _base(canvas: CanvasItem, transform: Transform2D, broad: bool) -> void:
	var spread: float = 34.0 if broad else 25.0
	_timber_beam(canvas, transform, Vector2(-spread, -3), Vector2(spread + 4, 1), 10.0, 1, Color("aaa18a"))
	_timber_beam(canvas, transform, Vector2(-12, -10), Vector2(16, 4), 8.0, 2, Color("a29984"))
	for x: float in [-spread + 5, spread - 3]:
		_nail(canvas, transform * Vector2(x, -2), 1.8)
	_polygon(canvas, transform, [Vector2(-11,-12),Vector2(8,-12),Vector2(11,-3),Vector2(-12,-4)], IRON)
	_line(canvas, transform, Vector2(-9,-10),Vector2(7,-10),Color("858977"),1.1)

static func _striker(canvas: CanvasItem, transform: Transform2D, p: Dictionary, time: float) -> void:
	# Triangular stay and low counterweight make the silhouette a machine.
	_timber_beam(canvas, transform, Vector2(24,-4),Vector2(4,-57),6.0,2,Color("9f8e74"))
	_line(canvas, transform, Vector2(-18,-6),Vector2(-2,-94),INK,3.7)
	_line(canvas, transform, Vector2(-18,-6),Vector2(-2,-94),ROPE.darkened(.17),1.7)
	_timber_beam(canvas, transform, Vector2(0,-5),Vector2(0,-124),13.0,0,Color("bca687"))
	_polygon(canvas, transform, [Vector2(-7,-124),Vector2(-2,-128),Vector2(9,-126),Vector2(7,-122)],Color("b9a582"))
	_binding(canvas, transform, Vector2(0,-113),18,10)
	_binding(canvas, transform, Vector2(0,-27),18,12)
	# Small chalk calibrations below the hinge, never a face or torso.
	for i in range(4):
		_line(canvas,transform,Vector2(-3,-55-i*5),Vector2(1 if i%2 else 4,-55-i*5),Color(.77,.71,.55,.54),.8)
	var swing: float = -.13 + float(p.windup)*.48 - float(p.strike)*.52 + float(p.recoil)*.25 + float(p.defeat)*.30
	var arm: Transform2D = transform * Transform2D(swing, Vector2(0,-89))
	_timber_beam(canvas, arm, Vector2(-39,0),Vector2(29,0),9.0,2,Color("c0a27b"))
	_binding(canvas, arm, Vector2(-32,0),17,15,true)
	_binding(canvas, arm, Vector2(25,0),12,13,true)
	# Leather stop and its short drop-rope visibly belong to a hinged crossarm.
	_line(canvas,arm,Vector2(24,6),Vector2(26,25),INK,3.0)
	_line(canvas,arm,Vector2(24,6),Vector2(26,25),ROPE,1.2)
	_patch(canvas,arm,[Vector2(19,24),Vector2(29,22),Vector2(33,35),Vector2(21,38)],CLOTH_REGION,Color("a89877"))
	_binding(canvas, arm, Vector2(25,25),10,4)
	_circle(canvas, transform * Vector2(0,-89),8.0,INK)
	_circle(canvas, transform * Vector2(0,-89),6.2,Color("72715e"))
	_circle(canvas, transform * Vector2(-.7,-90),3.5,Color("b1a07a"))
	_nail(canvas,transform*Vector2(0,-89),2.0)
	_tassel(canvas,transform,Vector2(5,-114),RUSSET,time, p)
	_line(canvas,transform,Vector2(-5,-8),Vector2(4,-8),Color("c8b892"),1.0)

static func _bracer(canvas: CanvasItem, transform: Transform2D, p: Dictionary, time: float) -> void:
	# Broad slatted warding gate: open lower frame, three planks, side stays.
	_timber_beam(canvas,transform,Vector2(32,-4),Vector2(17,-103),8,1,Color("a99b7c"))
	_timber_beam(canvas,transform,Vector2(-32,-4),Vector2(-18,-102),8,2,Color("a09578"))
	_timber_beam(canvas,transform,Vector2(43,-4),Vector2(18,-62),7,2,Color("8d836b"))
	_timber_beam(canvas,transform,Vector2(-36,-3),Vector2(-21,-62),7,1,Color("958c73"))
	var shield: Transform2D = transform * Transform2D(-.03-float(p.bracing)*.08,Vector2(-3*float(p.bracing),0))
	# Each plank has its own grain and unequal cap, with dark air gaps between.
	_timber_beam(canvas,shield,Vector2(-26,-34),Vector2(-25,-112),18,0,Color("a2a088"))
	_timber_beam(canvas,shield,Vector2(-5,-28),Vector2(-4,-124),20,1,Color("b4ad8d"))
	_timber_beam(canvas,shield,Vector2(18,-34),Vector2(18,-116),19,2,Color("999c83"))
	_timber_beam(canvas,shield,Vector2(-36,-103),Vector2(31,-104),8,1,Color("c5ac82"))
	_timber_beam(canvas,shield,Vector2(-34,-42),Vector2(33,-43),9,2,Color("b19c77"))
	# Reed-and-hemp impact mat softens the centre; original sack-cloth pixels.
	_patch(canvas,shield,[Vector2(-24,-96),Vector2(22,-98),Vector2(25,-54),Vector2(-24,-51)],CLOTH_REGION,Color("c2b692"))
	for i in range(9):
		var y: float = -94+i*4.5
		_line(canvas,shield,Vector2(-23,y+2),Vector2(23,y),Color(.32,.30,.22,.49),.8)
	_line(canvas,shield,Vector2(-22,-98),Vector2(-22,-50),ROPE.darkened(.20),3.2)
	_line(canvas,shield,Vector2(21,-98),Vector2(24,-51),ROPE.darkened(.20),3.2)
	for y: float in [-103,-43]:
		_binding(canvas,shield,Vector2(-25,y),14,13)
		_binding(canvas,shield,Vector2(23,y),14,13)
		_nail(canvas,shield*Vector2(-11,y),1.5)
		_nail(canvas,shield*Vector2(10,y),1.5)
	# Crossed muted-jade straps, weathered edges, and an offset wooden toggle.
	_strap(canvas,shield,Vector2(-24,-96),Vector2(24,-54),4.0,JADE)
	_strap(canvas,shield,Vector2(21,-96),Vector2(-22,-52),3.6,JADE.darkened(.12))
	_timber_beam(canvas,shield,Vector2(-7,-77),Vector2(4,-70),4,2,Color("c7b18c"))
	_tassel(canvas,shield,Vector2(31,-102),JADE,time+1.2,p)
	# The physical brace reaches toward its partner, with no magical shield dome.
	if float(p.bracing) > .015:
		var support: float = float(p.bracing)
		var stay: Transform2D = transform * Transform2D(support*.25,Vector2(-25,-56))
		_timber_beam(canvas,stay,Vector2(1,0),Vector2(-17-support*11,2),7,0,Color("b5aa89"))
		_binding(canvas,stay,Vector2(-17-support*10,2),10,11,true)

static func _timber_beam(canvas: CanvasItem, transform: Transform2D, a: Vector2, b: Vector2, width: float, grain: int, tint: Color) -> void:
	var axis: Vector2 = (b-a).normalized()
	var n := Vector2(-axis.y,axis.x) * width*.5
	var face := PackedVector2Array([a-n,b-n,b+n,a+n])
	var depth := Vector2(3,-2)
	_polygon(canvas,transform,[face[1],face[1]+depth,face[2]+depth,face[2]],Color("82755d"))
	_polygon(canvas,transform,[face[2],face[2]+depth,face[3]+depth,face[3]],tint.darkened(.44))
	var tex: Texture2D = texture_for("timber")
	if tex != null:
		var region: Rect2 = TIMBER_REGIONS[grain%TIMBER_REGIONS.size()]
		var uv := PackedVector2Array([region.position,Vector2(region.position.x,region.end.y),region.end,Vector2(region.end.x,region.position.y)])
		for i in range(uv.size()): uv[i] /= tex.get_size()
		canvas.draw_polygon(transform*face,PackedColorArray([tint]),uv,tex)
	else: canvas.draw_colored_polygon(transform*face,tint.darkened(.3))
	_outline(canvas,transform,face,INK.lightened(.06),1.2)
	_line(canvas,transform,face[0],face[1],Color(.77,.69,.52,.63),.9)
	_line(canvas,transform,face[3],face[2],Color(.15,.16,.13,.66),1.0)

static func _binding(canvas: CanvasItem, transform: Transform2D, center: Vector2, width: float, height: float, padded: bool = false) -> void:
	var left: float = center.x-width*.5
	var right: float = center.x+width*.5
	var top: float = center.y-height*.5
	var bottom: float = center.y+height*.5
	_patch(canvas,transform,[Vector2(left,top+1),Vector2(right-1,top),Vector2(right,bottom-1),Vector2(left+1,bottom)],ROPE_REGION,Color("cab88b") if padded else Color("b9a77d"))
	for i in range(1,maxi(2,int(height/2.3))):
		var y: float = top+i*2.3
		_line(canvas,transform,Vector2(left+.7,y+1),Vector2(right-.5,y-1),Color("796d50"),1.1)
		_line(canvas,transform,Vector2(left+1.2,y),Vector2(right-1,y-1.8),Color(.82,.77,.57,.59),.7)
	_line(canvas,transform,Vector2(left+2,top),Vector2(right-2,bottom),Color("837351"),1.3)

static func _tassel(canvas: CanvasItem, transform: Transform2D, at: Vector2, color: Color, time: float, p: Dictionary) -> void:
	var safe_time: float = time if is_finite(time) else 0.0
	var flutter: float = sin(safe_time*2.6)*1.8 + float(p.recoil)*3.5 - float(p.strike)*4.0
	_polygon(canvas,transform,[at,at+Vector2(5,-1),at+Vector2(9+flutter,14),at+Vector2(5+flutter,11),at+Vector2(3+flutter,18)],color.darkened(.21))
	_polygon(canvas,transform,[at+Vector2(3,1),at+Vector2(6,-1),at+Vector2(14+flutter,9),at+Vector2(9+flutter,9)],color)
	_line(canvas,transform,at,at+Vector2(5+flutter,12),color.lightened(.24),.8)
	_circle(canvas,transform*at,2.4,ROPE.darkened(.1))

static func _strap(canvas: CanvasItem, transform: Transform2D, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	_line(canvas,transform,a,b,INK,width+1.6)
	_line(canvas,transform,a,b,color,width)
	_line(canvas,transform,a+Vector2(-.6,.5),b+Vector2(-.6,.5),color.lightened(.22),.8)

static func _patch(canvas: CanvasItem, transform: Transform2D, points: Array, region: Rect2, tint: Color) -> void:
	var face := PackedVector2Array(points)
	var tex: Texture2D = texture_for("hemp")
	if tex != null:
		var uv := PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
		for i in range(uv.size()): uv[i] /= tex.get_size()
		canvas.draw_polygon(transform*face,PackedColorArray([tint]),uv,tex)
	else: canvas.draw_colored_polygon(transform*face,tint.darkened(.15))
	_outline(canvas,transform,face,INK.lightened(.11),1.2)

static func _shadow(canvas: CanvasItem, center: Vector2, radius: Vector2) -> void:
	for ring in range(3):
		var points := PackedVector2Array()
		var size: Vector2 = radius*(1.0-ring*.22)
		for i in range(32):
			var angle: float = TAU*i/32.0
			points.append(center+Vector2(cos(angle),sin(angle))*size)
		canvas.draw_colored_polygon(points,Color(.035,.050,.037,.09+ring*.035))

static func _polygon(canvas: CanvasItem, transform: Transform2D, points: Array, color: Color) -> void:
	canvas.draw_colored_polygon(transform*PackedVector2Array(points),color)

static func _outline(canvas: CanvasItem, transform: Transform2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(transform*outline,color,width,true)

static func _line(canvas: CanvasItem, transform: Transform2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(transform*a,transform*b,color,width,true)

static func _circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(center,radius,color,true,-1.0,true)

static func _nail(canvas: CanvasItem, at: Vector2, radius: float) -> void:
	_circle(canvas,at,radius,INK)
	_circle(canvas,at-Vector2(.4,.45),radius*.57,Color("939680"))
