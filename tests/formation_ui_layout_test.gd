extends "res://tests/audit_receipt_ui_test.gd"
## Real GUI controls, pointer dispatch, visibility and resource timing at two sizes.
func _run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty() or OS.get_environment("XDG_CONFIG_HOME").is_empty():quit(2);return
	for window:Vector2i in [Vector2i(1280,800),Vector2i(1180,737)]:
		root.size=window
		for mode:String in ["并肩","护后"]:
			for companion:String in ["","沈青","唐栖"]:
				await _create();s.formation=mode;s.companion_unlocked=companion=="沈青";s.tangqi_unlocked=companion=="唐栖";s.active_companion=companion;s.defense=20
				if companion=="唐栖":s.bridge_repaired=true;s.tangqi_stage=3;s.tangqi_choice="teach"
				s._apply_party_plan(s.PartyRoster.load_plan(s,{"active_companion":companion},11))
				var ui=_begin();await process_frame
				var before:Dictionary=s.to_dict().duplicate(true);var writes:int=s.writes
				check(not ui.art.draw_labels,"Live stage uses real GUI labels instead of duplicated painted text")
				check(ui.support_card.visible==not companion.is_empty(),"Support visibility follows actual party")
				check(ui.hero_card.modulate.a==1 and ui.target_cards.bracer.button.modulate.a==1 and ui.target_cards.striker.button.modulate.a==1,"Idle health cards are visible")
				if not companion.is_empty():check(ui.support_card.modulate.a==1,"Idle support label remains visible")
				for id:String in ["striker","bracer"]:
					var card:Button=ui.target_cards[id].button
					check(card.get_rect()==ui.art.unit_label_rect(id) and card.size.y<=65,"Compact real target card tracks stage label rectangle")
					check(Rect2(0,65,1280,569).encloses(card.get_rect()),"Target card fits the battlefield")
					await click_at(card.get_global_rect().get_center())
					check(ui.rules.selected_id==id,"Actual compact card click selects target at window size "+str(window))
				for button:Button in ui.action_buttons:check(Rect2(0,670,1280,130).encloses(button.get_rect()),"Action belt control fits reserved footer")
				check(ui.qi_text.text.contains("气血") and ui.qi_text.text.contains("真气") and ui.qi_text.text.contains("回春散"),"Persistent footer exposes actual resources during actor motion")
				ui._process(.01);check(s.to_dict()==before and s.writes==writes,"Layout synchronization cannot mutate gameplay or saves")
				await _key(KEY_1);var tx:Dictionary=ui.pending
				ui.art._process(.16);await process_frame
				check(ui.hero_card.modulate.a==0,"Moving hero card fades instead of covering another actor")
				check(ui.qi_text.is_visible_in_tree() and ui.qi_text.text.contains("%d/%d"%[tx.before.hp,tx.before.max_hp]),"Footer retains pre-counter HP while hero lunges")
				check(ui.notice.text.contains("气血%d/%d"%[tx.before.units[1].hp,tx.before.units[1].max_hp]),"Selected enemy HP remains readable when actor labels fade")
				ui.art._process(.18);await process_frame
				check(ui.notice.text.contains("气血%d/%d"%[int(tx.before.units[1].hp)-int(tx.hero_damage),tx.before.units[1].max_hp]),"Compact target HP changes at real contact")
				ui.art._process(2);await process_frame
				check(ui.hero_card.modulate.a==1 and ui.health.value==s.hp,"After return the real HP card reappears with settled health")
				check(ui.log_text.size.y<=24 and not ui.log_text.tooltip_text.is_empty(),"Visible battle log is one compact line with recent detail available")
				await _dispose()
	print("%s: %d formation GUI viewport/pointer/resource/label checks"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)

func click_at(point:Vector2)->void:
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for pressed:bool in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
	await process_frame
