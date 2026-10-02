extends "res://tests/visual_heting_chapter.gd"
## Prepared scene matrix, separate evidence after machinery integration.
func capture(name:String)->void:
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	var target="res://screenshots/%d-heting-machinery-%s.png" % [int(name.substr(0,3))+16,name.substr(11)]
	assert(root.get_texture().get_image().save_png(target)==OK)
