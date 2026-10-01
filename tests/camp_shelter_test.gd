extends SceneTree
const Art=preload("res://scripts/painted_camp_shelter.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func run()->void:
	var image=Art.texture();assert(image!=null and image==Art.texture() and image.filter_clip)
	assert(image.atlas.get_size()==Vector2(1536,1024) and image.region==Rect2(57,48,1455,941))
	assert(Rect2(Vector2.ZERO,image.atlas.get_size()).encloses(image.region))
	var rect:Rect2=Art.drawing_rect();assert(rect.size.x==108)
	assert((rect.position+Art.FOOT*Art.WIDTH/Art.REGION.size.x).distance_to(Art.WORLD_FOOT)<.001)
	assert(is_equal_approx(rect.size.x/rect.size.y,Art.REGION.size.x/Art.REGION.size.y))
	assert(Art.opacity_for([Vector2(1315,785)])==1 and Art.opacity_for([Vector2(1339,720)])==.45)
	assert(Art.opacity_for([Vector2(1315,785),Vector2(1339,720)])==.45)
	assert(Art.opacity_for([Vector2(1100,700)])==1)
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.state.quest_stage=6;app.world.quest_stage=6
	var points=[Vector2(1315,785),Vector2(1339,720),Vector2(1450,780),Vector2(1260,740)];var before=[]
	for point in points:before.append(app.world._can_walk(point))
	app.world.painted_camp_enabled=false
	for i in range(points.size()):assert(app.world._can_walk(points[i])==before[i])
	app.world.painted_camp_enabled=true;app.world.teleport(points[0]);await create_timer(.1).timeout;assert(app.world.nearby_id=="bandit")
	var e=InputEventKey.new();e.physical_keycode=KEY_E;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.physical_keycode=KEY_E;e.pressed=false;Input.parse_input_event(e);await process_frame
	assert(app.active_modal and app.modal_actions.size()==2)
	var words=""
	for n in app.overlay.find_children("*","Label",true,false):words+=n.text
	assert(words.contains("蒲横"));app._close_modal()
	app.queue_free();await create_timer(.25).timeout
	print("PASS: painted shelter asset/cache/foot, party occlusion, unchanged campsite routes and real nearby interaction");quit()
