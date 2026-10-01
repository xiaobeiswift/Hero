extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func texts(node:Node)->String:
	var result=node.text if node is Label or node is RichTextLabel else ""
	for child in node.get_children():result+=texts(child)
	return result
func button(text:String)->Button:
	for node in app.overlay.find_children("*","Button",true,false):
		if node.text==text:return node
	return null
func click(caption:String)->void:
	var target=button(caption);assert(target!=null)
	var motion=InputEventMouseMotion.new();motion.position=target.get_global_rect().get_center();root.push_input(motion,true);await process_frame
	var event=InputEventMouseButton.new();event.position=motion.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event,true);await process_frame
	event.pressed=false;root.push_input(event,true);await process_frame
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.audio_on=false
	await key(KEY_I)
	assert(app.active_modal and app.overlay.get_meta("inventory",false) and app.modal_actions.size()==5)
	var frame=app.overlay.find_child("InventoryFrame",true,false)
	assert(frame!=null and Rect2(0,0,1280,800).encloses(frame.get_rect()))
	assert(app.overlay.find_child("InventoryTraveller",true,false)!=null)
	assert(texts(frame).contains("旧铁剑") and texts(frame).contains("粗布行衣") and texts(frame).contains("照夜一线"))
	assert(texts(frame).contains("攻击 16") and texts(frame).contains("防御 4") and texts(frame).contains("修为 0 / 60"))
	for node in frame.find_children("*","RichTextLabel",true,false):assert(not node.scroll_active)
	for text in ["回春散","切换阵型","青钢剑 · 45文","返回江湖","同行册"]:assert(button(text)!=null and button(text).is_visible_in_tree())
	assert(button("回春散").disabled and button("回春散").tooltip_text=="气血已满")
	assert(button("切换阵型").disabled and button("青钢剑 · 45文").disabled)
	assert(texts(frame).contains("还需 21 文"))
	var old_purchase:Callable=app.modal_actions[2];var before=app.state.to_dict()
	await key(KEY_3);assert(app.state.to_dict()==before and app.overlay.find_child("InventoryHelp",true,false).text=="还需 21 文")
	await key(KEY_2);assert(app.state.to_dict()==before and app.overlay.find_child("InventoryHelp",true,false).text=="尚无同行人")
	await key(KEY_ESCAPE);old_purchase.call();assert(app.state.to_dict()==before)
	app._show_inventory();await key(KEY_K)
	assert(app.active_modal and not app.overlay.get_meta("inventory",false) and texts(app.overlay).contains("武学"))
	app._close_modal();app._show_inventory();await key(KEY_B)
	assert(texts(app.overlay).contains("工艺") and not app.overlay.get_meta("inventory",false))
	app._close_modal();app.state.quest_stage=6;app.state.recruit_companion();app.state.coins=70
	app._show_inventory();await click("青钢剑 · 45文")
	assert(app.state.equipment=="青钢剑" and app.state.coins==25 and texts(app.overlay).contains("青钢剑"))
	assert(button("青钢剑 · 45文").disabled)
	await key(KEY_3);assert(app.state.coins==25)
	await click("切换阵型");assert(app.state.formation=="护后" and texts(app.overlay).contains("护后"))
	await key(KEY_4);assert(not app.active_modal)
	app.state.hp=50;var medicine:int=app.state.medicine;app._show_inventory();await key(KEY_1)
	assert(app.state.hp==95 and app.state.medicine==medicine-1 and not app.active_modal)
	app._start_battle("spar");before=app.state.to_dict();app._show_inventory()
	assert(not app.active_modal and app.state.to_dict()==before and app.current_screen=="battle")
	app.queue_free();await create_timer(.25).timeout
	print("PASS: structured inventory, retained actions/keys, stale callback safety and battle gate");quit()
