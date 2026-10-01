extends SceneTree
const Art=preload("res://scripts/painted_village_civilians.gd")
const Named=preload("res://scripts/painted_village_sprite.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func run()->void:
	assert(Art.texture_for("elder")==null)
	for role in Art.ROLES:
		var frame=Art.texture_for(role);assert(frame!=null and frame==Art.texture_for(role))
		assert(frame.atlas.get_size()==Vector2(768,256) and frame.region==Rect2(Art.ROLES[role]*256,0,256,256) and frame.filter_clip)
	assert(Art.texture_for("porter")!=Art.texture_for("resident") and Art.texture_for("clerk")!=Named.texture_for("healer"))
	var p=Vector2(330,330);assert((Art.drawing_rect(p).position+Art.FOOT*72.0/256.0).distance_to(p)<.001)
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	for role in Art.ROLES:assert(app.world._painted_civilian_role(role)==role)
	for role in ["healer","elder","bandit","player"]:assert(app.world._painted_civilian_role(role).is_empty())
	assert(app.world._painted_npc_role("healer")=="healer")
	app.state.quest_stage=3;app.state.recruit_companion();app._sync_world_state()
	assert(app.world._painted_npc_role("healer").is_empty() and app.world.get_npc_name("healer")=="药铺伙计")
	app._healer_dialogue();var words=""
	for n in app.overlay.find_children("*","Label",true,false):words+=n.text
	assert(words.contains("药铺伙计") and not words.contains("沈青 · 药师"))
	app._close_modal();app.world.change_map("sluice",Vector2(210,870))
	for role in Art.ROLES:assert(app.world._painted_civilian_role(role).is_empty())
	app.queue_free();await create_timer(.25).timeout
	print("PASS: three civilian identities, independent crops/feet and travelling-Shen clerk presentation");quit()
