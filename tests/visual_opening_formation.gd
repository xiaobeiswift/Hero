extends "res://tests/visual_heting_chapter.gd"
## Prepared quest-stage-three opening, unchanged level-one stats; real E, dialogue
## and battle key dispatch. Timed source-render captures, not a browser playtest.
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false;app.battle_presentation_enabled=true;app.battle_art.set_process(false)
	app.state.quest_stage=3;app.world.teleport(app.world.interactables.bandit.pos+Vector2(-40,0));app._refresh();await process_frame
	await key(KEY_E);press("拔剑 · 迎战");assert(app.battle_art.uses_formation())
	await capture("292-opening-formation-solo-ready")
	await key(KEY_1);app.battle_art._process(.33)
	await capture("293-opening-formation-sword-contact")
	app.battle_art._process(.56)
	await capture("294-opening-formation-counter-contact")
	app.battle_art._process(3);await key(KEY_5);app.battle_art._process(3)
	assert(app.current_screen=="explore")
	app.state.companion_unlocked=true;app.state.active_companion="沈青";app.state.formation="护后";app.state.heal_rest()
	app._interact("bandit");press("拔剑 · 迎战")
	await capture("295-opening-formation-shen-cover")
	await key(KEY_5);app.battle_art._process(3)
	app.state.formation="并肩";app.state.heal_rest();app._interact("bandit");press("拔剑 · 迎战")
	root.size=Vector2i(1180,737)
	await capture("296-opening-formation-compact-pair")
	await key(KEY_5);app.battle_art._process(3)
	root.size=Vector2i(1280,800);app._start_battle("sluice_scout")
	assert(not app.battle_art.uses_formation())
	await capture("297-opening-formation-other-opponent-fallback")
	await key(KEY_5);app.battle_art._process(3)
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: six native opening-formation captures; prepared stage-three level-one state, actual E/dialogue/keys and unchanged fallback")
	quit()
func capture(name:String)->void:
	app._refresh();app.toast_time=0;app.hud.quest_notice_time=0;app.hud.tick(0)
	await create_timer(.35).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
func key(code:int)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func press(text:String)->void:
	var button=find_button(app.overlay,text);assert(button!=null,"Missing button: "+text);button.pressed.emit()
func find_button(node:Node,text:String):
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null:return found
	return null
