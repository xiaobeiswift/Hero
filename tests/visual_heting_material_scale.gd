extends "res://tests/visual_heting_chapter.gd"
## Same prepared scenarios, separate evidence filenames for the texture-scale pass.
func capture(name:String)->void:
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	var sequence=int(name.substr(0,3))+8
	var target="res://screenshots/%d-heting-material-%s.png" % [sequence,name.substr(11)]
	assert(root.get_texture().get_image().save_png(target)==OK)
