extends "res://tests/audit_progression_test.gd"
func _run() -> void:
	var scene=load("res://scenes/main.tscn")
	game=scene.instantiate()
	root.add_child(game)
	await process_frame
	game.state=AuditState.new()
	game._new_game()
	game.state.coins=300
	game.state.level=3
	game.state.buy_equipment()
	await key(KEY_B)
	_check(game.active_modal and _find_button(game.overlay,"精锻青钢剑")!=null,"B opens workshop")
	_press("材料买卖")
	_press("买入材料")
	for i in range(3):_press("铁矿 8文")
	_press("木料 5文")
	_check(game.state.resources.iron==3 and game.state.resources.timber==1,"Actual shop buttons purchase exact quantities")
	await key(KEY_5)
	_check(_find_button(game.overlay,"返回工艺")!=null,"Fifth modal key returns from stock page")
	_press("返回工艺")
	var attack_before=game.state.attack
	_press("精锻青钢剑")
	_check(game.state.equipment=="精锻青钢剑" and game.state.attack==attack_before+5,"Real crafting button applies upgrade")
	_check(game.state.resources.iron==0 and game.state.resources.timber==0,"Craft consumes exact materials")
	var before=game.state.to_dict()
	_press("精锻青钢剑")
	_check(game.state.to_dict()==before,"Double crafting cannot duplicate bonuses/charges")
	game._close_modal()
	game._load()
	_check(game.state.to_dict()==before,"Craft result autosaved and reloads")
	game.state.resources.cloth=3
	game.state.resources.herb=3
	game._show_workshop()
	var hp_before=game.state.max_hp
	_press("轻纱内甲")
	_check(game.state.armor=="轻纱内甲" and game.state.max_hp==hp_before+10,"Armor crafted from UI")
	var medicine_before=game.state.medicine
	_press("制回春散")
	_check(game.state.medicine==medicine_before+1 and game.state.resources.herb==0,"Repeatable medicine recipe uses remaining herbs")
	_press("材料买卖")
	_press("卖出材料")
	before=game.state.to_dict()
	_press("铁矿 4文")
	_check(game.state.to_dict()==before,"Selling absent resources leaves state unchanged")
	game._close_modal()
	game._show_inventory()
	var all_text=""
	for child in game.overlay.get_children():
		for part in child.get_children():
			if part is RichTextLabel:all_text+=part.text
	_check(all_text.contains("轻纱内甲") and all_text.contains("精锻青钢剑"),"Inventory reflects crafted gear")
	game._close_modal()
	game._start_battle("training")
	await key(KEY_B)
	_check(not game.active_modal and game.current_screen=="battle","Cannot open trading mid-battle")
	game._battle_action("flee")
	game._stop_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	game.queue_free()
	await process_frame
	if failures==0:print("PASS: %d workshop UI checks" % checks)
	else:push_error("FAIL: %d of %d workshop UI checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func key(value:Key) -> void:
	game._process(0)
	var event=InputEventKey.new()
	event.physical_keycode=value;event.keycode=value;event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
