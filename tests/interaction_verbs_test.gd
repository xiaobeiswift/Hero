extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func words(node:Node)->String:
	var value=node.text if node is Label or node is RichTextLabel else ""
	for child in node.get_children():value+=words(child)
	return value
func run()->void:
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	assert(app.world.interaction_verb("herb")=="查看")
	app.state.quest_stage=1;app._sync_world_state();app.world.teleport(Vector2(1240,370));await process_frame
	assert(app.world.nearby_id=="herb" and app.world.interaction_verb("herb")=="采集")
	await key(KEY_E);await key(KEY_1)
	assert(app.state.quest_stage==2 and app.state.herbs==1 and app.world.interaction_verb("herb")=="查看")
	await key(KEY_E);assert(words(app.overlay).contains("不必多采"));await key(KEY_ESCAPE)
	assert(app.state.herbs==1)
	for region in ["qingwei","sluice","frostbridge","mistwood"]:
		app.state.map_id=region;app.world.change_map(region,Vector2(600,480));app._sync_world_state()
		for id in app.world.interactables:
			var kind:String=app.world.interactables[id].get("kind","")
			if kind=="exit":assert(app.world.interaction_verb(id)=="前往")
			elif kind in ["board","shrine","cache","clue","rest","relic"]:assert(app.world.interaction_verb(id)=="查看")
			elif kind=="lightness":assert(app.world.interaction_verb(id)=="轻身")
			elif kind in ["elder","healer","bandit","villager"]:assert(app.world.interaction_verb(id)=="交谈")
	app.state.map_id="frostbridge";app.world.change_map("frostbridge",Vector2(1400,425));app._sync_world_state();await process_frame
	assert(app.world.nearby_id=="frost_herb" and app.world.interaction_verb("frost_herb")=="采集")
	await key(KEY_E);assert(words(app.overlay).contains("三份"));await key(KEY_1)
	assert(app.state.gathered_nodes.has("frost_herb") and app.world.interaction_verb("frost_herb")=="查看")
	var before=app.state.to_dict();await key(KEY_E)
	assert(words(app.overlay).contains("已采集"))
	for button in app.overlay.find_children("*","Button",true,false):assert(button.text!="小心采集")
	await key(KEY_1);assert(app.state.to_dict()==before)
	app.chapter_story.collect("frost_herb");assert(app.state.to_dict()==before)
	app.queue_free();await create_timer(.25).timeout
	print("PASS: actual herb/material collection updates action verbs; depleted sources, all-map exits/clues and replay-safe gathering stay coherent");quit()
