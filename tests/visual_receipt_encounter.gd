extends "res://tests/visual_heting_chapter.gd"
## Prepared completed-harbor loadout, real E/Tab/1–5 and dialogue callbacks.
## Isolated no-write saves; native rendering evidence, not a fresh playthrough.
var panel
func run()->void:
	root.size=Vector2i(1280,800)
	app=Scene.instantiate();app.state=NoSave.new();app.view_preferences=NoWritePrefs.new()
	root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false
	await capture("272-receipt-title-version")
	app._new_game();prepare()
	await key(KEY_E);press("谈谈复签（可选）")
	await capture("273-receipt-optional-offer")
	press("接下取签之事");await capture("274-receipt-real-stakes")
	press("保存后应战");panel=app.overlay.get_meta("receipt_battle");panel.art.set_process(false)
	await capture("275-receipt-waterfront-ready")
	await key(KEY_TAB);assert(panel.rules.selected_id=="bracer")
	await key(KEY_2);panel.art._process(.34)
	await capture("276-receipt-skill-contact")
	panel.art._process(3.0)
	var turns=0
	while app.current_screen=="receipt_battle" and turns<45:
		var rules=panel.rules
		var action=KEY_1
		if rules.hp<55 and rules.medicine>0:action=KEY_4
		elif rules.action_unavailable_reason("skill").is_empty():action=KEY_2
		elif rules.units[0].hp>0 and rules.units[0].intent_data.damage>=30:action=KEY_3
		await key(action);panel.art._process(3.0);turns+=1
	assert(app.state.receipt_stage==2 and app.current_screen=="explore")
	await capture("277-receipt-first-victory")
	press("与施衡核签");press("并看三处记号")
	assert(app.state.receipt_stage==3);await capture("278-receipt-compared-record")
	app._close_modal();app.state.receipt_stage=1;app.state.hp=1;app.state.qi=0
	app.receipt_story.open();press("保存后应战");panel=app.overlay.get_meta("receipt_battle");panel.art.set_process(false)
	await key(KEY_1);panel.art._process(3.0)
	assert(app.state.receipt_settlement.outcome=="defeat")
	await capture("279-receipt-west-recovery")
	app._close_modal();app.world.teleport(app.world.interactables.heting_scale.pos+Vector2(-40,0));app.state.position=app.world.player_pos
	root.size=Vector2i(1180,737);app.receipt_story.open();press("保存后应战")
	panel=app.overlay.get_meta("receipt_battle");panel.art.set_process(false)
	await capture("280-receipt-compact-two-targets")
	await key(KEY_ESCAPE);panel.art._process(3.0)
	app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: nine native receipt scene captures; prepared loadout, real key input and accepted state transitions; no browser or physical-close claim")
	quit()
func prepare()->void:
	var s=app.state
	s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(600);s.equip_art(s.sect_art())
	s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1])
	s.mist_stage=4;s.mist_gauges.assign(["rain","stone","basin"]);s.mist_approach="duel";s.mist_ending="release_water"
	s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries"
	s.companion_unlocked=true;s.active_companion="沈青";s.hp=s.max_hp;s.qi=s.max_qi
	s.map_id="heting";app._sync_world_state();app.world.change_map("heting",Vector2(1150,735))
	app.world.teleport(app.world.interactables.heting_scale.pos+Vector2(-40,0));s.position=app.world.player_pos;app._refresh()
func press(text:String)->void:
	var button=find_button(app.overlay,text);assert(button!=null,"Missing button: "+text);button.pressed.emit()
func find_button(node:Node,text:String):
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null:return found
	return null
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
