extends SceneTree
const Art=preload("res://scripts/painted_battle_hero.gd")
func _initialize()->void:
	for name in Art.POSES:
		var i:int=Art.POSES[name];var t=Art.texture_for(name)
		assert(t!=null and t.atlas.get_size()==Vector2(1536,1024))
		assert(t.region==Rect2((i%3)*512,(i/3)*512,512,512))
		assert(t==Art.texture_for(name))
	assert(Art.texture_for("unknown")==null)
	var p=Vector2(229,274)
	for size in [160.0,208.0,256.0]:assert((Art.drawing_rect(p,size).position+Art.FOOT*size/512).distance_to(p)<.001)
	for sample in [[{},"idle"],[{"windup":.6},"windup"],[{"strike":.8},"strike"],[{"guard":.9},"guard"],[{"recoil":.6},"hurt"],[{"defeat":.8},"kneel"],[{"defeat":1,"recoil":1,"strike":1},"kneel"]]:assert(Art.pose_for(sample[0])==sample[1])
	print("PASS: six painted combat crops, stable anchors, cached resources and pose priorities");quit()
