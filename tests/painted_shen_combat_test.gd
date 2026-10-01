extends SceneTree
const Art=preload("res://scripts/painted_battle_shen.gd")
const Hero=preload("res://scripts/painted_battle_hero.gd")
func _initialize()->void:
	assert(Art.texture_for("unknown")==null and Art.POSES.size()==4)
	for pose in Art.POSES:
		var frame=Art.texture_for(pose);var i:int=Art.POSES[pose]
		assert(frame!=null and frame.atlas.get_size()==Vector2(1024,1024))
		assert(frame.region==Rect2((i%2)*512,(i/2)*512,512,512) and frame.filter_clip)
		assert(frame==Art.texture_for(pose))
	assert(Art.texture_for("idle")!=Hero.texture_for("idle"))
	for scale in [130,184,230]:
		var foot=Vector2(126,266);assert((Art.drawing_rect(foot,scale).position+Art.FOOT*scale/512.0).distance_to(foot)<.001)
	print("PASS: four Shen combat crops, independent cache and fixed support foot");quit()
