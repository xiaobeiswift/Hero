extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
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
	var release_repro=Vector2(720.63916015625,469.580535888672)
	assert(Art.opacity_for(foot,[release_repro])==.38)
	assert(Art.opacity_for(foot,[Vector2(770,470)])==.38) # body overlaps at the side
	assert(Art.opacity_for(foot,[Vector2(780,470)])==1.0)
	assert(Art.opacity_for(foot,[Vector2(720,400)])==1.0)
	assert(Art.opacity_for(foot,[Vector2(720,480)])==1.0)
	assert(Art.opacity_for(foot,[Vector2(720,520)])==1.0)
	assert(Art.opacity_for(foot,[])==1.0)
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.teleport(Vector2(715,540));await create_timer(.1).timeout
	assert(app.world.nearby_id=="board" and app.world.interactables.board.pos==foot)
	var prompt:Rect2=app.world._interaction_prompt_rect(foot)
	assert(not prompt.intersects(Rect2(app.world.player_pos-Vector2(20,62),Vector2(40,70))))
	assert(Rect2(app.world.camera_pos,app.world.viewport_rect.size).encloses(prompt))
	# Prepared render fixtures: prompt/opacity only, not following or recruitment.
	for id in ["shen","tang","qin"]:
		PartyFixture.prepare_render(app.world,[PartyFixture.render_frame(id,Vector2(785,520))])
		prompt=app.world._interaction_prompt_rect(foot)
		assert(not prompt.intersects(Rect2(app.world.player_pos-Vector2(20,62),Vector2(40,70))))
		assert(not prompt.intersects(Rect2(app.world.follower_view(id).position-Vector2(20,62),Vector2(40,70))))
	PartyFixture.prepare_render(app.world,[PartyFixture.render_frame("shen",Vector2(900,540)),PartyFixture.render_frame("tang",Vector2(1000,540)),PartyFixture.render_frame("qin",Vector2(785,520))])
	prompt=app.world._interaction_prompt_rect(foot)
	for position in app.world.exploration_actor_positions():
		assert(not prompt.intersects(Rect2(position-Vector2(20,62),Vector2(40,70))))
	PartyFixture.prepare_render(app.world,[])
	app.world.teleport(release_repro);await process_frame
	assert(app.world.player_pos.distance_to(release_repro)<.01)
	assert(app.world._noticeboard_opacity(foot)==.38 and app.world.nearby_id=="board")
	app.world.teleport(Vector2(715,540))
	assert(app.world._noticeboard_opacity(foot)==1.0)
	for id in ["shen","tang","qin"]:
		PartyFixture.prepare_render(app.world,[PartyFixture.render_frame(id,release_repro)])
		assert(app.world._noticeboard_opacity(foot)==.38)
	PartyFixture.prepare_render(app.world,[PartyFixture.render_frame("shen",Vector2(900,540)),PartyFixture.render_frame("tang",Vector2(1000,540)),PartyFixture.render_frame("qin",release_repro)])
	assert(app.world._noticeboard_opacity(foot)==.38)
	PartyFixture.prepare_render(app.world,[])
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
	app.world.teleport(release_repro);await process_frame
	app._autosave();progress=app.state.to_dict()
	await key(KEY_E);assert(app.active_modal)
	await key(KEY_ESCAPE);assert(not app.active_modal and app.state.to_dict()==progress)
	assert(app.world._noticeboard_opacity(foot)==.38)
	Input.action_press("move_down");await create_timer(.15).timeout;Input.action_release("move_down")
	assert(app.world.player_pos.y>480 and app.world._noticeboard_opacity(foot)==1.0)
	app.queue_free();await create_timer(.25).timeout
	print("PASS: painted board crop/anchor, released-position party occlusion, front/side/absent-party cases, prompt avoidance, unchanged traversal and real E/ESC reading from both sides");quit()
