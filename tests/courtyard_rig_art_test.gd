extends SceneTree
const Art = preload("res://scripts/courtyard_training_rigs.gd")
class DrawProbe extends Node2D:
	var draws: int = 0
	func _draw() -> void:
		for role: String in Art.ROLES:
			for pose: Dictionary in [{},{"windup":1.0},{"strike":1.0},{"recoil":1.0},{"bracing":1.0},{"defeat":1.0}]:
				assert(Art.draw(self,Vector2(160+draws*30,200),role,pose,.8))
				draws += 1
		assert(not Art.draw(self,Vector2.ZERO,"unknown"))
var checks: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(false,message)
func _initialize() -> void:
	var wood: Texture2D = Art.texture_for("timber")
	var hemp: Texture2D = Art.texture_for("hemp")
	check(wood != null and wood.get_size() == Vector2(1254,1254),"Existing painted wood is readable")
	check(hemp != null and hemp.get_size() == Vector2(1024,512),"Existing painted machinery is readable")
	check(wood == Art.texture_for("timber") and hemp == Art.texture_for("hemp"),"Material resources must be cached")
	check(Art.texture_for("unknown") == null,"Unknown material is safe")
	check(Art.canonical_role("strike") == "striker" and Art.canonical_role("brace") == "bracer","Documented role aliases")
	var raw: Dictionary = {"strike":4.0,"windup":-2.0,"recoil":NAN,"bracing":"invalid"}
	var clean: Dictionary = Art.normalized_pose(raw)
	check(clean.strike == 1.0 and clean.windup == 0.0 and clean.recoil == 0.0 and clean.bracing == 0.0,"Clamp and sanitize presentation input")
	check(raw.strike == 4.0 and is_nan(raw.recoil),"Pose input stays untouched")
	var broken: Dictionary = Art.normalized_pose({"strike":1,"windup":1,"recoil":1,"bracing":1,"defeat":1})
	check(broken.defeat == 1 and broken.strike == 0 and broken.windup == 0 and broken.recoil == 0 and broken.bracing == 0,"Defeat has visual priority")
	for role: String in Art.ROLES:
		var foot := Vector2(650,250) if role == "striker" else Vector2(790,285)
		check(Art.foot_anchor(foot,role) == foot,"Authored foot stays on its floor anchor")
		var idle: Rect2 = Art.drawing_rect(foot,role)
		check(idle.size.y >= 125 and idle.size.y <= 142,"Rig stays in requested 110–135 px body scale plus base envelope")
		for pose: Dictionary in [{},{"windup":1.0},{"strike":1.0},{"recoil":1.0},{"bracing":1.0},{"defeat":1.0},{"defeat":.5,"recoil":1}]:
			for time: float in [0.0,1.0,20.0]:
				var bounds: Rect2 = Art.drawing_rect(foot,role,pose,time)
				var impact: Vector2 = Art.target_anchor(foot,role,pose,time)
				check(bounds.has_point(impact),"Impact point remains inside posed visual envelope")
				check(bounds.has_point(foot),"Ground contact remains inside posed envelope")
				var transform: Transform2D = Art.body_transform(foot,role,pose,time)
				check((transform*Vector2(0,-9)).distance_to(foot+Vector2(0,-9))<.001,"Low hinge remains mechanically grounded")
		var live_anchor: Vector2 = Art.target_anchor(foot,role)
		var down_anchor: Vector2 = Art.target_anchor(foot,role,{"defeat":1})
		check(down_anchor.y > live_anchor.y+25,"Defeat settles the frame visibly toward the ground")
	check(Art.drawing_rect(Vector2.ZERO,"unknown") == Rect2(),"Unknown rig has no accidental hit target")
	var probe := DrawProbe.new()
	root.add_child.call_deferred(probe)
	await process_frame
	await process_frame
	check(probe.draws == 12,"Actual canvas drawing accepts both roles in all six poses")
	check(wood == Art.texture_for("timber") and hemp == Art.texture_for("hemp"),"Draw path keeps the same texture instances")
	print("PASS: %s rig resource, pose, ground-anchor, target-envelope and draw-smoke checks" % checks)
	quit()
