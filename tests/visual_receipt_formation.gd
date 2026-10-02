extends "res://tests/visual_receipt_encounter.gd"
## Reuse the prepared real input route while preserving all older evidence images.
func capture(name:String)->void:
	var number=int(name.substr(0,3))+11
	var fresh_name="%03d-formation-%s"%[number,name.substr(4)]
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+fresh_name+".png")==OK)
