extends "res://tests/visual_heting_chapter.gd"
func capture(name:String)->void:
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/%d-heting-worksites-%s.png" % [int(name.substr(0,3))+24,name.substr(11)])==OK)
