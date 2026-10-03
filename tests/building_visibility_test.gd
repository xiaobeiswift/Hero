extends SceneTree
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
const Art=preload("res://scripts/qingwei_environment_art.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func run()->void:
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.world.set_process(false)
	var clinic:Dictionary=app.world.buildings[0];var shrine:Dictionary=app.world.buildings[4]
	for building:Dictionary in app.world.buildings:
		var rect:Rect2=Art.building_rect(building);var threshold:float=building.pos.y+building.size.y
		var behind=Vector2(rect.get_center().x,threshold-1)
		assert(Art.building_opacity(building,[behind])==.35)
		assert(Art.building_opacity(building,[Vector2(behind.x,threshold)])==1.0)
		assert(Art.building_opacity(building,[Vector2(behind.x,threshold+60)])==1.0)
		assert(Art.building_opacity(building,[Vector2(rect.position.x-17,threshold-1)])==1.0)
		assert(Art.building_opacity(building,[Vector2(rect.position.x-15,threshold-1)])==.35)
		assert(Art.building_opacity(building,[Vector2(behind.x,rect.position.y-5)])==1.0)
		assert(Art.building_opacity(building,[])==1.0)
	assert(Art.building_opacity({"type":"ruin"},[Vector2.ZERO])==1.0)
	var geometry=app.world.buildings.duplicate(true)
	for row in [[clinic,Vector2(300,185)],[shrine,Vector2(900,695)]]:
		assert(app.world._can_walk(row[1]));app.world.teleport(row[1])
		assert(app.world.player_pos.distance_to(row[1])<.001)
		assert(app.world._building_opacity(row[0])==.35)
		var progress=app.state.to_dict()
		for i in range(20):app.world._building_opacity(row[0])
		assert(app.state.to_dict()==progress and app.world.buildings==geometry)
		app.world.teleport(Vector2(480,440))
		# Prepared render fixtures isolate opacity; they do not simulate movement.
		PartyFixture.prepare_render(app.world,[]);assert(app.world._building_opacity(row[0])==1.0)
		for id in ["shen","tang","qin"]:
			PartyFixture.prepare_render(app.world,[PartyFixture.render_frame(id,row[1])])
			assert(app.world._building_opacity(row[0])==.35)
		PartyFixture.prepare_render(app.world,[PartyFixture.render_frame("shen",Vector2(480,440)),PartyFixture.render_frame("tang",Vector2(490,440)),PartyFixture.render_frame("qin",row[1])])
		assert(app.world._building_opacity(row[0])==.35)
		PartyFixture.prepare_render(app.world,[])
	app.world.teleport(Vector2(900,695));Input.action_press("move_up")
	for i in range(8):app.world._process(.05)
	Input.action_release("move_up")
	assert(app.world.player_pos.y<630 and app.world._building_opacity(shrine)==1.0)
	assert(app.world._can_walk(app.world.player_pos))
	app.world.teleport(Vector2(900,820));app.world._process(0)
	assert(app.world.nearby_id=="shrine" and app.world._building_opacity(shrine)==1.0)
	await key(KEY_E);assert(app.active_modal)
	await key(KEY_ESCAPE);assert(not app.active_modal)
	app.world.teleport(Vector2(330,340));app.world._process(0)
	assert(app.world.nearby_id=="healer" and app.world._building_opacity(clinic)==1.0)
	await key(KEY_E);assert(app.active_modal)
	await key(KEY_ESCAPE);assert(not app.active_modal)
	app.queue_free();await create_timer(.25).timeout
	print("PASS: building party visibility at exact legal roof positions, front/side/absent cases, real movement and unchanged E/ESC interactions");quit()
