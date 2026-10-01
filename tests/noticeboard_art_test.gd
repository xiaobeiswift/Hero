extends SceneTree
const Art=preload("res://scripts/painted_noticeboard.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await process_frame
func run()->void:
	var image=Art.texture();assert(image!=null and image==Art.texture())
	assert(image.atlas.get_size()==Vector2(1254,1254) and Rect2(Vector2.ZERO,image.atlas.get_size()).encloses(image.region))
	assert(image.filter_clip and image.region==Rect2(35,139,1201,992))
	var foot=Vector2(720,480);var draw:Rect2=Art.drawing_rect(foot)
	assert((draw.position+Art.FOOT*Art.WIDTH/Art.REGION.size.x).distance_to(foot)<.001)
	assert(draw.size.x==84 and is_equal_approx(draw.size.x/draw.size.y,Art.REGION.size.x/Art.REGION.size.y))
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(715,540));await create_timer(.1).timeout
	assert(app.world.nearby_id=="board" and app.world.interactables.board.pos==foot)
	var prompt:Rect2=app.world._interaction_prompt_rect(foot)
	assert(not prompt.intersects(Rect2(app.world.player_pos-Vector2(20,62),Vector2(40,70))))
	assert(Rect2(app.world.camera_pos,app.world.viewport_rect.size).encloses(prompt))
	app.world.companion_active=true;app.world.companion_pos=Vector2(785,520)
	prompt=app.world._interaction_prompt_rect(foot)
	assert(not prompt.intersects(Rect2(app.world.player_pos-Vector2(20,62),Vector2(40,70))))
	assert(not prompt.intersects(Rect2(app.world.companion_pos-Vector2(20,62),Vector2(40,70))))
	app.world.companion_active=false
	var progress=app.state.to_dict();var before=[]
	for p in [Vector2(715,540),Vector2(720,460),Vector2(720,480)]:before.append(app.world._can_walk(p))
	app.world.painted_board_enabled=false
	for i in range(3):assert(before[i]==app.world._can_walk([Vector2(715,540),Vector2(720,460),Vector2(720,480)][i]))
	app.world.painted_board_enabled=true;await key(KEY_E)
	assert(app.active_modal)
	var words=""
	for n in app.overlay.find_children("*","Label",true,false):words+=n.text
	for n in app.overlay.find_children("*","RichTextLabel",true,false):words+=n.text
	assert(words.contains("青苇渡告示") and words.contains("过河不问来处"))
	await key(KEY_ESCAPE);assert(not app.active_modal and app.state.to_dict()==progress)
	app.queue_free();await create_timer(.25).timeout
	print("PASS: painted board asset, cached crop/ground anchor, party-visible interaction prompt, unchanged traversal and real E notice interaction");quit()
