extends "res://tests/audit_second_region_test.gd"
var chosen=-1
func _run()->void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.state=AuditState.new();game._new_game();game._interact("elder");await process_frame
	var frame=game.overlay.find_child("DialogueSheet",true,false)
	_check(frame!=null,"Exploration dialogue uses the paper folio")
	var body=frame.find_child("DialogueBody",true,false)
	_check(body.get_theme_font_size("normal_font_size")==19 and body.scroll_active,"Body is larger and scrollable")
	_check(body.text.contains("青穗草"),"Original quest text remains present")
	_check(frame.size.y<500,"Short dialogue removes unused page height")
	await _key(KEY_ENTER)
	_check(game.state.quest_stage==1 and not game.active_modal,"Actual Enter accepts the quest once")
	var old_action:Callable
	for count in range(1,6):
		var options=[]
		for i in range(count):options.append(["选项%d · 一段较长的决定文字"%i,choose.bind(i)])
		game._modal("沈青 · 药师","一程风雨","保留完整对白。\n\n[color=#d3b276]选择会留在这一程。[/color]",options,count%2==0);await process_frame
		frame=game.overlay.find_child("DialogueSheet",true,false);body=frame.find_child("DialogueBody",true,false)
		var portrait=frame.find_child("Portrait_shen",true,false)
		_check(portrait!=null and not portrait.get_rect().intersects(body.get_rect()),"Portrait stays outside body for %d choices"%count)
		_check(body.text.contains("[color=#7c5726]"),"Emphasis remains legible on paper")
		var rectangles=[]
		for i in range(count):
			var button=frame.find_child("DialogueChoice"+str(i+1),true,false)
			_check(Rect2(Vector2.ZERO,frame.size).encloses(button.get_rect()),"Choice remains inside the page")
			_check(not body.get_rect().intersects(button.get_rect()),"Choice remains outside scroll body")
			for previous in rectangles:_check(not button.get_rect().intersects(previous),"Choices do not overlap")
			rectangles.append(button.get_rect())
			_check(button.text==options[i][0] and button.tooltip_text==button.text,"Semantic choice text preserved")
			_check(Rect2(Vector2.ZERO,button.size).encloses(button.get_node("ChoiceCaption").get_rect()),"Wrapped choice caption stays inside its button")
		old_action=game.modal_actions[count-1];chosen=-1;await _key(KEY_1+count-1)
		_check(chosen==count-1,"Actual numeric key dispatches the matching choice")
	game._close_modal();chosen=-1;old_action.call();_check(chosen==-1,"Closed-page callback cannot act")
	game._modal("新一页","页面替换","新的内容",[["继续",choose.bind(7)]]);old_action.call();_check(chosen==-1,"Replaced-page callback cannot act")
	await _key(KEY_SPACE);_check(chosen==7,"Actual Space keeps first-choice shortcut")
	var button=game.overlay.find_child("DialogueChoice1",true,false);chosen=-1
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var mouse=InputEventMouseButton.new();mouse.position=point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed;root.push_input(mouse,true);await process_frame
	_check(chosen==7,"Actual mouse input passes through the wrapped choice caption")
	game._modal("长卷","阅读",("一行江湖故事，完整保留。\n\n").repeat(45));await process_frame;await process_frame
	body=game.overlay.find_child("DialogueBody",true,false)
	_check(body.get_content_height()>body.size.y,"Long journal content remains scrollable")
	_check(game.overlay.find_child("DialogueHelp",true,false).text.contains("滚轮"),"Overflow pages explain scrolling")
	motion=InputEventMouseMotion.new();motion.position=body.get_global_rect().get_center();root.push_input(motion,true);await process_frame
	for i in range(4):
		var wheel=InputEventMouseButton.new();wheel.position=motion.position;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;root.push_input(wheel,true);await process_frame
	_check(body.get_v_scroll_bar().value>0,"Actual wheel input scrolls the long body")
	_check(game.overlay.find_child("DialogueChoice1",true,false).is_visible_in_tree(),"Scrolling leaves the decision button visible")
	await _key(KEY_ESCAPE);_check(not game.active_modal,"Actual Escape closes the page")
	game._stop_audio();await create_timer(.25).timeout;game.queue_free();await process_frame
	if failures==0:print("PASS: %d paper dialogue readability/layout/keyboard/lifecycle checks"%checks)
	else:push_error("FAIL: paper dialogue checks")
	quit(0 if failures==0 else 1)
func choose(value:int)->void:chosen=value
