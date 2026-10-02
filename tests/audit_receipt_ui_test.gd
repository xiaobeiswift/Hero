extends SceneTree
## Prepared-scene/input audit, not browser or physical desktop-close evidence.
## Every save and preference is isolated by caller XDG dirs plus a routed fixture.
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
const Scene = preload("res://scenes/main.tscn")

class RoutedState extends Model:
	var directory: String
	var writes: int = 0
	var reads: int = 0
	var saved: Dictionary = {}
	func save_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH: path = directory.path_join("hero_save.json")
		assert(path.begins_with(directory+"/"))
		writes += 1
		var result: Error = super.save_game(path)
		if result == OK: saved = to_dict().duplicate(true)
		return result
	func load_game(path: String = SAVE_PATH) -> Error:
		if path == SAVE_PATH: path = directory.path_join("hero_save.json")
		assert(path.begins_with(directory+"/"))
		reads += 1
		return super.load_game(path)
	func has_save() -> bool:
		return FileAccess.file_exists(directory.path_join("hero_save.json"))

class CloseProbe extends Main:
	var exits: int = 0
	var exit_save: bool = true
	func _quit_cleanly(save_progress: bool = true) -> void:
		if quit_pending: return
		exits += 1; exit_save = save_progress; quit_pending = true

var app
var s: RoutedState
var fixture: String
var checks: int = 0
var failures: int = 0

func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Receipt UI: "+label)

func _create(ending: String = "short_ferries", start: bool = true) -> void:
	fixture = "user://receipt-ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture)==OK,"Create isolated fixture")
	s = RoutedState.new(); s.directory = fixture
	app = Scene.instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); app.save_slots.store = Slots.new(fixture)
	await process_frame
	app._stop_audio(); app.audio_on = false
	if not start: return
	app._new_game()
	s.quest_stage=6; s.ending="守望"; s.side_stage=3; s.side_choice="rescue"
	s.side_reward_claimed=true; s.side_found.assign(["boatman","ledger"]); s.side_clues=2
	s.chapter_two_stage=4; s.chapter_two_ending="protect_witness"
	s.archive_clues.assign(["clerk","inscription"]); s.seal_sequence.assign([2,0,1])
	s.mist_stage=4; s.mist_gauges.assign(["rain","stone","basin"])
	s.mist_approach="duel"; s.mist_ending="release_water"
	s.heting_stage=4; s.heting_bridge="east"; s.heting_delivered.assign(["meal","sealed","reserve"])
	s.heting_draft=ending; s.heting_ending=ending; s.map_id="heting"
	app._sync_world_state(); app.world.change_map("heting",Vector2(1150,735))
	app.world.teleport(app.world.interactables.heting_scale.pos+Vector2(-40,0))
	s.position=app.world.player_pos; app._refresh()
	check(app.receipt_story._at_scale(),"Prepared real world is at current scale")

func _dispose() -> void:
	app._stop_audio(); app.queue_free(); await process_frame

func _key(code: int) -> void:
	var event = InputEventKey.new(); event.physical_keycode=code; event.pressed=true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.physical_keycode=code; event.pressed=false
	Input.parse_input_event(event); await process_frame

func _button(node: Node, text: String):
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found = _button(child,text)
		if found!=null: return found
	return null

func _press(text: String) -> void:
	var button = _button(app.overlay,text)
	check(button!=null,"Actual button exists: "+text)
	if button!=null: button.pressed.emit()

func _body() -> String:
	var body = app.overlay.find_child("DialogueBody",true,false)
	return body.text if body!=null else ""

func _title() -> String:
	var title = app.overlay.find_child("DialogueTitle",true,false)
	return title.text if title!=null else ""

func _path() -> String: return fixture.path_join("hero_save.json")
func _bytes() -> PackedByteArray: return FileAccess.get_file_as_bytes(_path())
func _fail_writes() -> void: check(DirAccess.make_dir_absolute(_path()+".tmp")==OK,"Inject real temporary-path write failure")
func _restore_writes() -> void: check(DirAccess.rename_absolute(_path()+".tmp",_path()+".blocker-%d"%Time.get_ticks_usec())==OK,"Restore write path without deleting fixture data")
func _controller(): return app.overlay.get_meta("receipt_battle") if app.overlay.has_meta("receipt_battle") else null
func _request_close() -> void: app._notification(app.NOTIFICATION_WM_CLOSE_REQUEST)
func _xp() -> int: return s.xp+30*s.level*(s.level-1)

func _begin():
	app.receipt_story.open()
	if s.receipt_stage==0: _press("接下取签之事")
	_press("保存后应战")
	var ui = _controller()
	check(ui!=null and s.battle_active and app.current_screen=="receipt_battle","Real controller starts after checkpoint")
	if ui!=null: ui.art.set_process(false)
	return ui

func _finish(ui) -> void:
	check(is_instance_valid(ui) and ui.rules.locked and not ui.pending.is_empty(),"Accepted action owns a pending presentation")
	if is_instance_valid(ui): ui.art._process(2.0)

func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty() or OS.get_environment("XDG_CONFIG_HOME").is_empty():
		push_error("Use isolated XDG_DATA_HOME and XDG_CONFIG_HOME for audit_receipt_ui_test.gd")
		quit(2); return
	await _title_versions()
	await _entry_and_guards()
	await _checkpoint_failures()
	await _input_resources_and_flee()
	await _victory_and_compare()
	await _defeat_recovery()
	await _close_during_action()
	await _close_terminal("win")
	await _close_terminal("defeat")
	await _close_save_failure(false)
	await _close_save_failure(true)
	await _old_save_and_slot_boundaries()
	await _menu_and_stale_guards()
	print("%s: %d prepared-scene receipt UI checks (actual input/signals, checkpoint failures, close/settlement, legacy slots); no browser or physical WM-close claim" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)

func _title_versions() -> void:
	await _create("short_ferries",false)
	var state_before: Dictionary=s.to_dict().duplicate(true)
	var writes:int=s.writes
	var version:String=String(ProjectSettings.get_setting("application/config/version","开发版"))
	var label = app.overlay.find_child("BuildVersion",true,false)
	check(label!=null and label.is_visible_in_tree() and label.text==version,"Visible title version reads real ProjectSettings")
	app.browser_mode=true; app.browser_build_revision="17"; app._show_title()
	label=app.overlay.find_child("BuildVersion",true,false)
	check(label.text==version+" · Web 17","Optional valid Web revision is visible")
	for revision: String in ["", "0", "invalid"]:
		app.browser_build_revision=revision; app._show_title()
		check(app.overlay.find_child("BuildVersion",true,false).text==version,"Invalid Web revision does not appear: "+revision)
	app.browser_mode=false; app.browser_build_revision="17"; app._show_title()
	check(app.overlay.find_child("BuildVersion",true,false).text==version,"Desktop title omits Web revision")
	check(s.to_dict()==state_before and s.writes==writes,"Title version leaves player and saves untouched")
	await _dispose()

func _entry_and_guards() -> void:
	for ending: String in ["short_ferries","open_scale"]:
		await _create(ending)
		var before:Dictionary=s.to_dict(); var writes:int=s.writes
		app._interact("heting_scale")
		check(_button(app.overlay,"谈谈复签（可选）")!=null,"Existing scale conversation exposes optional entry: "+ending)
		_press("谈谈复签（可选）")
		check(_body().contains("次晨") and (_body().contains("没有夜班") if ending=="short_ferries" else _body().contains("守秤")),"Optional prose preserves ending: "+ending)
		check(s.to_dict()==before and s.writes==writes,"Opening optional entry is read-only: "+ending)
		var stale:Callable=app.modal_actions[0]
		_press("先不接下"); app.receipt_story.open(); stale.call()
		check(s.receipt_stage==0 and s.writes==writes,"Declined offer callback cannot accept newer offer")
		var accept:Callable=app.modal_actions[0]
		var near:Vector2=app.world.player_pos
		app.world.player_pos=app.world.interactables.heting_scale.pos+Vector2(75,0)
		accept.call(); check(s.receipt_stage==0 and s.writes==writes,"Acceptance refuses distance boundary")
		app.world.player_pos=near; s.heting_cargo="meal"; accept.call()
		check(s.receipt_stage==0 and s.writes==writes,"Acceptance refuses current cargo")
		s.heting_cargo=""; _press("先不接下")
		app.world.player_pos=near+Vector2(200,0); app.receipt_story.open()
		check(not app.active_modal,"Far scale cannot open encounter")
		app.world.player_pos=near; s.heting_cargo="meal"; app.receipt_story.open()
		check(not app.active_modal,"Cargo cannot open encounter")
		s.heting_cargo=""; app.receipt_story.open(); _press("接下取签之事")
		var start:Callable=app.modal_actions[0]; writes=s.writes
		app.world.player_pos=app.world.interactables.heting_scale.pos+Vector2(75,0); start.call()
		check(not s.battle_active and s.writes==writes and not app._start_receipt_battle(),"Ready callback and main start reject stale distance")
		app.world.player_pos=near; s.heting_cargo="meal"; start.call()
		check(not s.battle_active and s.writes==writes and not app._start_receipt_battle(),"Ready callback and main start reject stale cargo")
		await _dispose()

func _checkpoint_failures() -> void:
	await _create(); _fail_writes(); var original:PackedByteArray=_bytes()
	app.receipt_story.open(); _press("接下取签之事")
	check(s.receipt_stage==1 and app.save_warning and not s.battle_active and _controller()==null,"Failed acceptance persists in memory and cannot start combat")
	check(_bytes()==original and _body().contains("尚未开始"),"Acceptance failure preserves old bytes and explains blocked combat")
	var stale:Callable=app.modal_actions[0]; var writes:int=s.writes
	_press("重试保存"); check(s.writes==writes+1 and not s.battle_active,"Failed checkpoint retry cannot start")
	_restore_writes(); _press("重试保存"); writes=s.writes; stale.call()
	check(s.saved.receipt_stage==1 and not app.save_warning and s.writes==writes,"Acceptance retry saves once; stale retry is inert")
	s.hp=57; s.qi=1; s.medicine=0; _fail_writes(); original=_bytes()
	_press("保存后应战")
	check(not s.battle_active and _controller()==null and s.hp==57 and s.qi==1 and s.medicine==0 and _bytes()==original,"Failed prefight checkpoint cannot heal or launch")
	_press("先回埠内"); _restore_writes(); app.receipt_story.open()
	check(_body().contains("气血57/") and _body().contains("真气1/") and _body().contains("回春散0份"),"Ready page reads current resources after failed checkpoint")
	var start:Callable=app.modal_actions[0]
	_press("保存后应战"); var ui=_controller(); ui.art.set_process(false); writes=s.writes
	start.call(); check(s.writes==writes and ui.rules.hp==57 and ui.rules.qi==1 and ui.rules.medicine==0,"Successful start uses current resource checkpoint; stale launch does not repeat")
	await _key(KEY_5); _finish(ui); await _dispose()

func _input_resources_and_flee() -> void:
	await _create(); s.hp=60; s.qi=s.max_qi; s.medicine=2; s.defense=20
	var ui=_begin(); var saved:PackedByteArray=_bytes()
	check(ui.health.value==60 and ui.qi_text.text.contains("回春散 2包"),"Encounter HUD starts with real HP and medicines")
	ui.target_cards.bracer.button.pressed.emit(); check(ui.rules.selected_id=="bracer","Real target card signal selects bracer")
	var point:Vector2=ui.art.get_global_transform()*ui.art.target_anchor("striker")
	var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true)
	for pressed:bool in [true,false]:
		var mouse=InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=pressed
		mouse.position=point; mouse.global_position=point; root.push_input(mouse,true)
	await process_frame
	check(ui.rules.selected_id=="striker","Actual viewport pointer event hits painted striker body")
	ui.target_cards.bracer.button.pressed.emit()
	await _key(KEY_TAB); check(ui.rules.selected_id=="striker","Tab cycles live target")
	await _key(KEY_TAB); check(ui.rules.selected_id=="bracer","Tab returns to bracer")
	var writes:int=s.writes; var reads:int=s.reads
	for code:int in [KEY_F5,KEY_F6,KEY_F9,KEY_F10]: await _key(code)
	check(_controller()==ui and s.writes==writes and s.reads==reads and _bytes()==saved,"Save/load shortcuts cannot replace combat or touch files")
	await _key(KEY_1)
	var tx:Dictionary=ui.pending; var after:Dictionary=s.to_dict(); var turn:int=ui.rules.turn
	check(tx.action=="attack" and ui.rules.locked and s.hp==tx.after.hp and s.qi==tx.after.qi,"1 accepts actual attack and commits exact resources")
	check(ui.target_cards.bracer.bar.value==tx.before.units[1].hp and ui.health.value==tx.before.hp,"Accepted attack shows pre-impact HP")
	check(ui.action_buttons.all(func(button):return button.disabled) and ui.retreat_button.disabled,"Animation locks every action including escape button")
	await _key(KEY_ESCAPE); await _key(KEY_TAB); await _key(KEY_2); ui.target_cards.striker.button.pressed.emit()
	check(_controller()==ui and ui.rules.locked and ui.rules.turn==turn and ui.rules.selected_id=="bracer" and s.to_dict()==after,"Esc, target signal, Tab and action key cannot abandon or retarget accepted attack")
	ui.art._process(.31); check(ui.target_cards.bracer.bar.value==tx.before.units[1].hp,"HP remains before contact")
	ui.art._process(.02); check(ui.target_cards.bracer.bar.value==int(tx.before.units[1].hp)-int(tx.hero_damage),"Actual impact updates selected target HUD")
	ui.art._process(.54); check(ui.health.value==tx.before.hp and int(tx.counter_damage)>0,"Player HUD retains pre-counter HP despite committed damage")
	ui.art._process(.02); check(ui.health.value==tx.after.hp and ui.health_text.text.contains("%d /"%int(tx.after.hp)),"Counter contact updates health bar and numeric HP together")
	_finish(ui); check(not ui.rules.locked and ui.health.value==s.hp,"Presentation completion unlocks and aligns real HP")
	await _key(KEY_2); check(ui.pending.action=="skill" and s.qi==ui.pending.after.qi,"2 spends real skill qi")
	_finish(ui)
	await _key(KEY_3); check(ui.pending.action=="guard" and s.qi==ui.pending.after.qi,"3 accepts actual guard")
	_finish(ui)
	await _key(KEY_4); tx=ui.pending
	check(tx.action=="item" and s.medicine==1 and ui.health.value==tx.before.hp,"4 commits one medicine while pre-impact display remains")
	ui.art._process(.24); check(ui.health.value==tx.before.hp,"Medicine HP stays before healing contact")
	ui.art._process(.02); check(ui.health.value==mini(int(tx.before.max_hp),int(tx.before.hp)+int(tx.heal)),"Healing contact updates actual HUD")
	_finish(ui); var resources:Array=[s.hp,s.qi,s.medicine,s.coins,_xp()]
	await _key(KEY_ESCAPE); check(ui.pending.action=="flee","Unlocked Escape accepts retreat")
	_finish(ui)
	check(app.current_screen=="explore" and not s.battle_active and s.receipt_stage==1 and [s.hp,s.qi,s.medicine,s.coins,_xp()]==resources,"Retreat preserves accepted costs and grants nothing")
	check(s.saved.medicine==1 and s.saved.qi==s.qi and _body().contains("不另扣钱"),"Normal retreat autosaves current costs and reports outcome")
	_press("先回埠内"); check(not app.active_modal,"Retreat result closes normally")
	await _dispose()

func _victory_and_compare() -> void:
	for ending:String in ["short_ferries","open_scale"]:
		await _create(ending); s.attack=999; s.defense=99
		var coins:int=s.coins; var xp:int=_xp(); var ui=_begin()
		ui.target_cards.bracer.button.pressed.emit(); await _key(KEY_1); _finish(ui)
		check(ui.target_cards.bracer.button.disabled and ui.rules.selected_id=="striker","Defeated target disables and surviving target is selected")
		await _key(KEY_1); var tx:Dictionary=ui.pending; _finish(ui)
		check(s.receipt_stage==2 and s.coins==coins+40 and _xp()==xp+80 and not s.battle_active,"Victory settles one actual reward: "+ending)
		var writes:int=s.writes; ui._finished()
		check(not s.finish_receipt_presentation(tx.epoch,tx.token) and s.writes==writes and s.coins==coins+40,"Repeated completion cannot award or save twice")
		check(_body().contains("80修为、40文") and s.saved.receipt_stage==2,"Victory result reports actual reward after checkpoint")
		_press("与施衡核签"); var stale:Callable=app.modal_actions[0]; _press("并看三处记号"); writes=s.writes
		stale.call(); check(s.receipt_stage==3 and s.saved.receipt_stage==3 and s.coins==coins+40 and _xp()==xp+80 and s.writes==writes,"Comparison advances once without duplicate reward")
		_press("收好记录"); app._interact("heting_scale"); _press("重看复签记录")
		check(_body().contains("安排照旧") and s.heting_ending==ending and s.writes==writes,"Completed revisit preserves original ending and saves")
		await _dispose()

func _defeat_recovery() -> void:
	await _create(); s.hp=1; s.attack=1; s.defense=0; s.qi=0; s.coins=3
	var ui=_begin(); await _key(KEY_1); var tx:Dictionary=ui.pending; _finish(ui)
	check(s.receipt_settlement.outcome=="defeat" and s.coins==0 and s.receipt_stage==1 and s.hp==s.max_hp and s.qi>=2,"Defeat charges bounded coins and restores specified resources")
	check(app.world.player_pos==Vector2(230,735) and s.position==Vector2(230,735) and s.saved.position=={"x":230.0,"y":735.0},"Defeat teleports real world before autosave")
	await process_frame
	check(s.position==Vector2(230,735) and app.world.player_pos==s.position,"Next main frame cannot overwrite safe recovery position")
	check(not app.receipt_story._at_scale() and _button(app.overlay,"在西岸歇脚")!=null,"Defeat result appears away from east scale")
	var resources:Dictionary=s.to_dict(); var writes:int=s.writes
	_press("在西岸歇脚"); check(not app.active_modal and s.to_dict()==resources and s.writes==writes,"Defeat result closes at west shelter without extra writes")
	check(not s.finish_receipt_presentation(tx.epoch,tx.token),"Repeated defeat callback cannot charge again")
	await _dispose()

func _close_during_action() -> void:
	await _create(); s.hp=60; s.medicine=2; s.defense=99
	var ui=_begin(); await _key(KEY_4); var resources:Dictionary=s.to_dict(); var turn:int=ui.rules.turn; var writes:int=s.writes
	_request_close(); _request_close()
	check(ui.close_pending and ui.rules.locked and app.exits==0 and s.writes==writes and s.to_dict()==resources,"Repeated close waits for accepted medicine without writing or duplicating costs")
	await _key(KEY_ESCAPE); await _key(KEY_2); ui.action_buttons[3].pressed.emit()
	check(ui.rules.turn==turn and s.to_dict()==resources,"Close pending blocks further actions")
	_finish(ui); check(ui.pending.action=="flee" and ui.rules.locked and s.medicine==1 and app.exits==0,"Accepted medicine finishes then close requests one retreat")
	_request_close(); _finish(ui)
	check(app.exits==1 and app.quit_pending and not app.exit_save and s.writes==writes+1 and s.saved.medicine==1 and s.receipt_stage==1,"Close retreat saves once and invokes test quit once")
	_request_close(); ui._finished(); check(app.exits==1 and s.writes==writes+1,"Repeated close/completion after quit remains inert")
	await _dispose()

func _close_terminal(outcome:String) -> void:
	await _create(); s.attack=999 if outcome=="win" else 1; s.defense=99 if outcome=="win" else 0
	if outcome=="defeat": s.hp=1; s.coins=3
	var coins:int=s.coins; var xp:int=_xp(); var ui=_begin()
	if outcome=="win": ui.target_cards.bracer.button.pressed.emit(); await _key(KEY_1); _finish(ui)
	await _key(KEY_1); var tx:Dictionary=ui.pending; var writes:int=s.writes
	_request_close(); _request_close(); _finish(ui)
	check(app.exits==1 and s.writes==writes+1 and s.receipt_settlement.outcome==outcome,"Close waits for accepted terminal action and saves once: "+outcome)
	check(not s.finish_receipt_presentation(tx.epoch,tx.token),"Terminal close settlement is single-use: "+outcome)
	if outcome=="win": check(s.coins==coins+40 and _xp()==xp+80 and s.saved.receipt_stage==2,"Close on victory retains one reward and no retreat")
	else: check(s.coins==0 and app.world.player_pos==Vector2(230,735) and s.saved.position=={"x":230.0,"y":735.0},"Close on defeat retains safe world and bounded charge")
	_request_close(); check(app.exits==1,"Repeated terminal close cannot quit twice: "+outcome)
	await _dispose()

func _close_save_failure(discard:bool) -> void:
	await _create(); s.hp=60; s.defense=99; s.medicine=2
	var ui=_begin(); var original:PackedByteArray=_bytes(); _fail_writes()
	await _key(KEY_4); _request_close(); _finish(ui); _finish(ui)
	check(app.exits==0 and not app.quit_pending and app.current_screen=="explore" and _title()=="手记未能落笔","Failed close save keeps settled play session open")
	check(_bytes()==original and s.medicine==1 and s.receipt_stage==1,"Failed close retains old file and accepted costs")
	var stale:Callable=app.modal_actions[0]; var writes:int=s.writes
	_press("返回小憩"); stale.call()
	check(app.overlay.get_meta("pause_menu",false) and app.exits==0 and s.writes==writes,"Cancel close save returns to pause; stale retry cannot act")
	_request_close(); _press("不保存离开")
	check(_title()=="舍下未存的这一程？" and app.exits==0,"Discard requires explicit second choice")
	if discard:
		writes=s.writes; _press("确认不保存离开")
		check(app.exits==1 and not app.exit_save and _bytes()==original and s.writes==writes,"Explicit discard preserves prior save bytes and does not rewrite")
	else:
		_press("继续留在江湖"); _request_close(); _restore_writes(); writes=s.writes; _press("重试保存")
		check(app.exits==1 and not app.exit_save and s.writes==writes+1 and s.saved.medicine==1 and _bytes()!=original,"Retry saves accepted costs and quits exactly once")
	_request_close(); check(app.exits==1,"Repeated close remains single quit after failure recovery")
	await _dispose()

func _old_save_and_slot_boundaries() -> void:
	await _create(); var old:Dictionary=s.to_dict(); old.erase("receipt_stage")
	var old_path:String=fixture.path_join("hero_slot_1.json")
	var file=FileAccess.open(old_path,FileAccess.WRITE); file.store_string(JSON.stringify({"version":10,"player":old})); file.close()
	var original:PackedByteArray=FileAccess.get_file_as_bytes(old_path)
	s.receipt_stage=3; app.save_slots.detail(1); _press("读取当前版本"); _press("确认读取")
	check(s.receipt_stage==0 and s.heting_stage==4 and s.heting_ending=="short_ferries" and FileAccess.get_file_as_bytes(old_path)==original,"Actual old slot loads default receipt stage without modifying old bytes")
	app._interact("heting_scale"); _press("谈谈复签（可选）"); _press("接下取签之事"); _press("保存后应战")
	var ui=_controller(); ui.art.set_process(false); var current:Dictionary=s.to_dict(); var writes:int=s.writes
	check(app.save_slots.store.save_slot(s,2)==ERR_BUSY and app.save_slots.store.load_slot(s,1)==ERR_BUSY,"Actual slot storage rejects transient fight")
	app.save_slots.perform_save(2); app.save_slots.perform_load(1,false)
	check(s.to_dict()==current and s.writes==writes and _controller()==ui,"Direct slot operations cannot change current fight or saves")
	# Invoke each menu gateway separately. A missing guard destroys the live
	# controller even when the underlying slot store correctly refuses the I/O.
	for gateway:String in ["save_page","load_page","detail","request_load"]:
		if gateway=="detail": app.save_slots.detail(1)
		elif gateway=="request_load": app.save_slots.request_load(1,false)
		else: app.save_slots.call(gateway)
		check(_controller()==ui and ui.is_inside_tree() and app.current_screen=="receipt_battle","Direct slot UI gateway keeps receipt controller: "+gateway)
		if _controller()!=ui: break
	await _dispose()

func _menu_and_stale_guards() -> void:
	await _create(); s.defense=99
	app._show_inventory()
	var stale_inventory_actions:Array[Callable]=app.modal_actions.duplicate()
	app._close_modal()
	app._show_journal(); var stale_journal:Callable=app.modal_actions[0]; app._close_modal()
	var ui=_begin()
	for locked:bool in [false,true]:
		if locked: await _key(KEY_1)
		var progress:Dictionary=s.to_dict(); var writes:int=s.writes; var generation:int=app.modal_generation
		for stale:Callable in stale_inventory_actions: stale.call()
		stale_journal.call()
		check(_controller()==ui and s.to_dict()==progress and s.writes==writes,"Stale inventory and journal callbacks cannot replace or mutate combat")
		for method:String in ["_show_inventory","_show_martials","_show_journal","_show_map","_show_workshop","_show_pause","_show_save_slots","_show_load_slots"]:
			app.call(method)
			check(_controller()==ui and app.modal_generation==generation and s.to_dict()==progress and s.writes==writes,"Direct menu cannot replace active/locked receipt: "+method+"/"+str(locked))
			if _controller()!=ui: break
		if _controller()!=ui: break
		app.workshop.show(); app._modal("stray","stray","stray",[])
		check(_controller()==ui and app.modal_generation==generation and s.to_dict()==progress,"Workshop and root modal cannot replace receipt presentation")
		if locked:
			var tx:Dictionary=ui.pending
			app.modal_generation+=1; ui._finished(); ui.submit("item"); ui.select_target("bracer")
			check(ui.rules.locked and s.to_dict()==progress and ui.pending==tx,"Stale generation blocks settlement/actions/selection")
			app.modal_generation=generation
			s.receipt_battle_epoch+=1; ui._finished(); ui.submit("item")
			check(ui.rules.locked and s.to_dict()==progress and ui.pending==tx,"Stale epoch blocks settlement and new actions")
			s.receipt_battle_epoch=tx.epoch
			_finish(ui)
	if _controller()==ui:
		await _key(KEY_5); _finish(ui)
	await _dispose()
