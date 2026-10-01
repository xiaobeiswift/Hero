extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func run()->void:
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	app.toast_time=0;app.hud.quest_notice_time=0;app._process(0)
	assert(not app.world._navigation_target_covered(Vector2(520,220)))
	app._toast("手记已写入");app._process(0)
	assert(app.world._navigation_target_covered(Vector2(520,220)))
	for target in [Vector2(-100,-100),Vector2(640,-100),Vector2(1600,-100),Vector2(640,1200)]:
		var edge:Vector2=app.world._compass_edge(target)
		var bubble=Rect2(edge-Vector2(58,21),Vector2(116,72))
		for rect:Rect2 in app.world.hud_exclusion_rects:assert(not bubble.intersects(rect))
	app._show_inventory()
	var body=""
	for node in app.overlay.find_children("*","RichTextLabel",true,false):body+=node.text
	assert(body.contains("攻击 16") and body.contains("防御 4") and body.contains("修为 0 / 60"))
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: HUD compass avoidance, transient-region release and inventory stat access");quit()
