extends "res://tests/capstone_independent_earned_test.gd"
## API-earned history at one explicit transfer boundary, then actual six-stop
## main scene. Inputs go through Input.parse_input_event/action_press; combat is
## automatically presented by the actual PartyUI, never manually acknowledged.
const MainScene = preload("res://scenes/main.tscn")
const Prefs = preload("res://scripts/view_preferences.gd")
const Harbor = preload("res://scripts/heting_region.gd")
class SceneProbeState extends State:
	var writes: int = 0
	var fail_save: bool = false
	var save_path: String = ""
	func save_game(_path: String = SAVE_PATH) -> Error:
		writes += 1
		if fail_save: return ERR_CANT_CREATE
		return super.save_game(save_path)
	func load_game(_path: String = SAVE_PATH) -> Error: return super.load_game(save_path)
	func has_save() -> bool: return FileAccess.file_exists(save_path)
class NoPrefs extends Prefs:
	func load_settings(_path:String=PATH)->Error:return OK
	func save_settings(_path:String=PATH)->Error:return OK
var app
var trace: Array = []
var scene_cases: Array = []
var interruption_checks: Array = []
var ticks: int = 0
var walked_pixels: float = 0
var held: String = ""
var real_started: int = 0
var selected_case: String = ""
var command_count: int = 0
var first_case: bool = false
var combat_tokens: Dictionary = {}
var current_scenario: Dictionary = {}

func _run() -> void:
	if not prepare_run_output():quit(2);return
	real_started=Time.get_ticks_msec();minimal_build=true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--case="):selected_case=argument.trim_prefix("--case=")
	var case_index: int = 0
	for school: String in ["听潮阁","照野堂","问石门"]:
		for full_party: bool in [false,true]:
			case_id=school+("/four" if full_party else "/solo")
			if not selected_case.is_empty() and not selected_case.begins_with(case_id):continue
			var base=earn_harbor(school,full_party)
			if base==null or failures>0:_finish();return
			if full_party:_earn_full_party(base,school=="照野堂")
			for plan: String in ["pause_batch","cancel_proven"]:
				case_id=school+("/four/" if full_party else "/solo/")+plan
				if not selected_case.is_empty() and selected_case!=case_id:continue
				var old_plan: String="hold_for_inspection" if plan=="pause_batch" else "return_to_owner"
				var earned=earn_consignee(base,old_plan)
				if earned==null or failures>0:_finish();return
				if full_party and school=="问石门" and plan=="cancel_proven":
					rest(earned,"optional_receipt_before_scene")
					check(earned.Receipt.begin(earned),"Optional receipt separately accepted by existing API")
					if not _journey_win(earned,"heting_receipt",case_id+"/optional_receipt"):_finish();return
					check(earned.Receipt.compare(earned) and earned.receipt_stage==3,"Optional receipt genuinely compared; never a capstone gate")
				current_scenario={"school":school,"party":full_party,"plan":plan,"old_plan":old_plan,"zoom_index":case_index%3,"receipt":earned.receipt_stage}
				first_case=scene_cases.is_empty()
				await _scene_case(earned)
				if failures>0:_finish();return
				case_index+=1
	_finish()

func _earn_full_party(s,alternate:bool)->void:
	check(s.recruit_companion(),"Explicitly recruit Shen without fabricating actor flags")
	check(s.begin_shen_care() and s.consult_shen_patient() and s.inspect_shen_shelter() and s.choose_shen_care("mobile" if alternate else "shore") and s.post_shen_notice(),"Earn Shen care through actual APIs")
	travel(s,"frostbridge")
	check(s.gather_resource("frost_timber").valid and s.repair_bridge(),"Four-party route earns real optional bridge materials")
	check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("preserve" if alternate else "teach") and s.recruit_tangqi(),"Earn Tang history and actual recruitment")
	travel(s,"mistwood")
	check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Earn Qin handoff and actual recruitment")
	travel(s,"heting")
	check(s.learn_internal_skill() and s.learn_lightness(),"Four-party optional lessons are explicit and separately earned")
	check(s.set_party_roster(["hero","shen","tang","qin"]),"Deploy only four genuinely earned actors")

func _frame(count:int=1)->void:
	for i:int in count:
		await process_frame;ticks+=1
func _tap(code:int)->void:
	var down=InputEventKey.new();down.keycode=code;down.physical_keycode=code;down.pressed=true;Input.parse_input_event(down)
	await _frame()
	var up=InputEventKey.new();up.keycode=code;up.physical_keycode=code;up.pressed=false;Input.parse_input_event(up)
	await _frame(2)
func _hold(next:String)->void:
	if held==next:return
	if not held.is_empty():Input.action_release(held)
	held=next
	if not held.is_empty():Input.action_press(held)
func _walk(to:Vector2)->void:
	check(not app.active_modal and app.current_screen=="explore","Movement starts outside modal")
	if failures>0:return
	for i:int in 5000:
		var previous:Vector2=app.world.player_pos;var difference:Vector2=to-previous
		if absf(difference.x)<=3 and absf(difference.y)<=3:
			_hold("");await _frame(2);_record_scene("walk");return
		_hold(("move_right" if difference.x>0 else "move_left") if absf(difference.x)>3 else ("move_down" if difference.y>0 else "move_up"))
		await _frame();walked_pixels+=previous.distance_to(app.world.player_pos)
		check(app.world._can_walk(app.world.player_pos),"Held input stays on live collision topology")
		if failures>0:break
	_hold("");check(false,"Walking route stuck toward %s at %s on %s"%[to,app.world.player_pos,app.state.map_id])
func _waypoints(points:Array)->void:
	for p:Vector2 in points:
		await _walk(p)
		if failures>0:return
func _record_scene(what:String)->void:
	if not is_instance_valid(app):return
	trace.append({"case":case_id,"input":what,"frame":ticks,"map":app.state.map_id,"pos":[app.world.player_pos.x,app.world.player_pos.y],"nearby":app.world.nearby_id,"stage":app.state.capstone_stage,"draft":app.state.capstone_draft,"ending":app.state.capstone_ending,"writes":app.state.writes})
func _buttons()->Array:
	var found:Array=[]
	for i:int in range(1,7):
		var b=app.overlay.find_child("DialogueChoice"+str(i),true,false)
		if b!=null:found.append(b)
	check(found.size()<=5,"Authored pages never exceed five visible choices")
	return found
func _choices()->Array:return _buttons().map(func(b):return b.text)
func _callback(fragment:String)->Callable:
	var buttons:Array=_buttons()
	for i:int in buttons.size():
		if String(buttons[i].text).contains(fragment):return app.modal_actions[i]
	check(false,"Missing callback for adversarial replay: "+fragment);return Callable()
func _click(button:Control)->void:
	var rect:Rect2=button.get_global_rect()
	check(rect.has_area() and root.get_visible_rect().encloses(rect),"Real mouse target fits logical viewport "+button.name)
	var center:Vector2=rect.get_center()
	var motion=InputEventMouseMotion.new();motion.position=center;motion.global_position=center;Input.parse_input_event(motion);await _frame()
	var down=InputEventMouseButton.new();down.position=center;down.global_position=center;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await _frame()
	var up=InputEventMouseButton.new();up.position=center;up.global_position=center;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up);await _frame(3)
func _choose(fragment:String,mouse:bool=false)->void:
	if failures>0:return
	var buttons:Array=_buttons()
	for i:int in buttons.size():
		if String(buttons[i].text).contains(fragment):
			check(root.get_visible_rect().encloses(buttons[i].get_global_rect()),"Choice fully inside actual logical viewport:"+fragment)
			if mouse:await _click(buttons[i])
			else:await _tap(KEY_1+i)
			_record_scene(("mouse:" if mouse else "key:")+fragment);return
	check(false,"Missing dialogue choice:"+fragment+" actual="+str(_choices()))
func _interact(site:String,opens:bool=true)->void:
	if failures>0:return
	check(app.world.nearby_id==site,"Live nearby E site:"+site+" got "+app.world.nearby_id)
	await _tap(KEY_E)
	if opens:check(app.active_modal,"Actual E opens dialogue:"+site)
	_record_scene("E:"+site)
func _close_readonly()->void:
	var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
	await _tap(KEY_ESCAPE)
	check(not app.active_modal and app.state.to_dict()==before and app.state.writes==writes,"Escape cancels reading with no mutations or save")
func _disk()->String:
	return FileAccess.get_file_as_string(app.state.save_path) if FileAccess.file_exists(app.state.save_path) else ""
func _mutation(fragment:String,stage:int,fail:bool=false,mouse:bool=false)->void:
	var disk:String=_disk();var oldpos:Vector2=app.world.player_pos
	app.state.fail_save=fail
	await _choose(fragment,mouse)
	check(app.state.capstone_stage==stage,"Explicit scene acceptance reaches stage%d:"%stage+fragment)
	check(app.world.player_pos==oldpos,"Acceptance does not transport player:"+fragment)
	if fail:
		check(app.save_warning and _disk()==disk,"Failed save retains old exact disk:"+fragment)
		var accepted:Dictionary=app.state.to_dict().duplicate(true)
		app.state.fail_save=false;await _choose("重试保存",true)
		check(not app.save_warning and app.state.to_dict()==accepted,"Retry serializes accepted state only:"+fragment)
		interruption_checks.append({"case":case_id,"save_failure":fragment,"stage":stage})
	_roundtrip_current("stage"+str(stage))
func _roundtrip_current(label:String)->void:
	var s=State.new()
	check(s.load_game(app.state.save_path)==OK and s.to_dict()==app.state.to_dict(),"Current isolated autosave exact canonical roundtrip:"+label)
func _stale_noop(stale:Callable,label:String)->void:
	var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
	stale.call()
	check(app.state.to_dict()==before and app.state.writes==writes,"Stale scene callback rejected:"+label)
	interruption_checks.append({"case":case_id,"stale":label,"stage":app.state.capstone_stage})
func _reload_current(label:String)->void:
	var before:Dictionary=app.state.to_dict().duplicate(true);var pos:Vector2=app.world.player_pos
	await _tap(KEY_F9)
	check(app.current_screen=="explore" and not app.active_modal and app.state.to_dict()==before and app.world.player_pos==pos,"Actual F9 reload restores exact accepted scene state:"+label)
	_record_scene("F9:"+label)
	interruption_checks.append({"case":case_id,"real_F9_reload":label,"stage":app.state.capstone_stage})
func _read_panels()->void:
	for code:int in [KEY_M,KEY_J]:
		var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
		await _tap(code);check(app.active_modal,"Map/journal opens with actual key");await _close_readonly()
		check(app.state.to_dict()==before and app.state.writes==writes,"Map/journal is read-only at stage%d"%app.state.capstone_stage)

func _scene_case(earned)->void:
	root.size=Vector2i(1280,800)
	app=MainScene.instantiate();app.state=SceneProbeState.new();app.state._copy_persistent_from(earned)
	app.state.save_path=isolated_root+"/scene-%d.json"%scene_cases.size()
	app.view_preferences=NoPrefs.new();app.view_preferences.zoom_index=current_scenario.zoom_index
	app.view_preferences.sound_enabled=false
	root.add_child(app);app._stop_audio();app.audio_on=false;app.current_screen="explore";app.modal_autosave_on_close=false;app._close_modal();app._sync_world_state()
	var startpoint:Vector2=Vector2(1390,600) if current_scenario.old_plan=="hold_for_inspection" else Vector2(665,620)
	app.world.change_map("heting",startpoint);await _frame(3)
	var start:Dictionary=app.state.to_dict().duplicate(true);var oldhistory:Dictionary=preserved_story(app.state)
	var start_ticks:int=ticks;var start_distance:float=walked_pixels;var start_commands:int=command_count
	if not current_scenario.party:
		check(app.state.party_roster==["hero"] and not app.state.companion_unlocked and not app.state.tangqi_unlocked and not app.state.qin_unlocked,"Genuine never-recruited solo enters main scene")
		check(not app.state.internal_unlocked and not app.state.lightness_unlocked and app.state.equipment=="旧铁剑" and app.state.armor=="粗布行衣" and app.state.receipt_stage==0 and not app.state.bridge_repaired,"Solo never borrows optional lessons/gear/receipt XP or repaired south bridge")
	# This is the only prepared position transfer. Every subsequent region exit
	# and site visit is reached through held movement and actual E/choice input.
	if current_scenario.old_plan=="hold_for_inspection":await _waypoints([Vector2(1290,600),Vector2(1290,400),Vector2(535,400),Vector2(535,350)])
	else:await _waypoints([Vector2(805,620),Vector2(805,400),Vector2(535,400),Vector2(535,350)])
	await _interact("heting_dispatch");var stale:Callable=_callback("接下查册引介");await _close_readonly();_stale_noop(stale,"closed invitation")
	await _interact("heting_dispatch");await _mutation("接下查册引介",1,first_case,true)
	await _read_panels()
	await _waypoints([Vector2(150,350),Vector2(150,335)]);await _interact("return_mistwood",false)
	check(app.state.map_id=="mistwood","Actual exit returns to Mistwood")
	await _waypoints([Vector2(1190,505),Vector2(1190,580),Vector2(1030,580),Vector2(1030,450),Vector2(500,450),Vector2(500,500),Vector2(380,500),Vector2(380,550),Vector2(150,550)])
	await _interact("return_frostbridge",false)
	check(app.state.map_id=="frostbridge","Actual exit returns to Frostbridge")
	await _waypoints([Vector2(1380,235),Vector2(1380,388),Vector2(1000,388),Vector2(700,388),Vector2(405,388),Vector2(405,365)])
	await _interact("chapter_host");var before_rest:Dictionary=resources(app.state)
	await _choose("借榻调息",true)
	check(app.state.hp==app.state.max_hp and app.state.qi==app.state.max_qi and app.state.medicine==before_rest.medicine and total_xp(app.state)==before_rest.xp and app.state.coins==before_rest.coins,"Explicit real Wen free rest only; no granted stock/XP/coins")
	await _interact("chapter_host");await _choose("展开原信");await _close_readonly()
	await _interact("chapter_host");await _choose("展开原信");await _choose("听他说明作者");await _choose("这封信要我做到哪里")
	var before_letter:Dictionary=resources(app.state)
	await _mutation("收回原信",2,first_case,true)
	check(resources(app.state)==before_letter,"Letter reveal neither heals nor grants any resource")
	await _waypoints([Vector2(405,388),Vector2(1000,388),Vector2(1150,388),Vector2(1150,385)])
	await _interact("chapter_clerk");await _choose("继续核两次鹤汀授权");await _choose("核看经办与分存")
	if current_scenario.party:await _evidence_helper()
	else:await _choose("自己核清")
	var before_wrong:Dictionary=app.state.to_dict().duplicate(true);var wrong_writes:int=app.state.writes
	await _choose("先赢过他")
	check(app.state.to_dict()==before_wrong and app.state.writes==wrong_writes,"Wrong responsibility claim never progresses or charges")
	await _choose("重新判断");await _mutation("梁缜须对",3,first_case)
	await _waypoints([Vector2(1080,385),Vector2(1080,745),Vector2(1320,745)])
	await _interact("chapter_archive");await _choose("查看应战准备")
	if first_case:
		var before_entry:Dictionary=app.state.to_dict().duplicate(true);var disk:String=_disk()
		app.state.fail_save=true;await _choose("保存后阻止交发")
		check(app.current_screen=="explore" and not app.state.battle_active and app.state.to_dict()==before_entry and _disk()==disk,"Entry save failure starts no battle or resource cost")
		app.state.fail_save=false;await _choose("重试保存")
		check(app.current_screen=="explore" and not app.state.battle_active,"Successful entry-save retry still awaits explicit battle choice")
	var before_fight:Dictionary=app.state.to_dict().duplicate(true)
	await _choose("保存后阻止交发",true)
	check(app.current_screen=="party_battle" and app.state.battle_active,"Actual dialogue opens current real PartyUI")
	check(app.state.hp==before_fight.hp and app.state.qi==before_fight.qi and app.state.medicine==before_fight.medicine,"Capstone battle entry adds no healing or stock")
	var fight_start:int=ticks
	await _scene_battle(first_case)
	if failures>0:return
	check(app.state.capstone_stage==4 and app.state.capstone_draft.is_empty() and app.state.capstone_ending.is_empty(),"Naturally presented victory only secures dispatch book")
	check(total_xp(app.state)==_dict_total_xp(before_fight) and app.state.coins==before_fight.coins,"Actual victory pays zero XP/coins")
	await _choose("记下守闸桌去处")
	await _read_panels()
	await _waypoints([Vector2(1080,745),Vector2(1080,388),Vector2(700,388),Vector2(405,388),Vector2(405,500),Vector2(140,500)])
	await _interact("return_sluice",false);check(app.state.map_id=="sluice","Real map exit reaches Sluice")
	await _waypoints([Vector2(1110,290),Vector2(1110,650),Vector2(1340,650),Vector2(1340,690)])
	await _interact("capstone_order_desk")
	if current_scenario.party:await _classification_helper()
	else:await _choose("自行核定四号")
	before_wrong=app.state.to_dict().duplicate(true);wrong_writes=app.state.writes
	await _choose("同册四号都算")
	check(app.state.to_dict()==before_wrong and app.state.writes==wrong_writes,"Incorrect four-order partition never progresses or charges")
	await _choose("重新分类");await _mutation("001、002证伪",5,first_case,true)
	check(app.state.capstone_draft.is_empty(),"Accepted classification does not choose draft")
	await _close_readonly();await _read_panels();await _reload_current("stage5_empty_draft")
	await _interact("capstone_order_desk");await _choose("商议处置草案")
	await _choose("拟作整班暂缓")
	await _choose("查看最后确认");stale=_callback("确认执行")
	await _choose("返回核对");await _choose("更改草案");await _choose("拟作逐号撤销")
	await _choose("更改草案");await _choose("拟作整班暂缓")
	await _choose("查看最后确认");_stale_noop(stale,"A→B→A draft old confirmation")
	await _choose("返回核对");await _choose("撤下草案")
	check(app.state.capstone_stage==5 and app.state.capstone_draft.is_empty(),"Cleared draft keeps accepted classification and pending orders")
	await _choose("重新商议草案")
	await _choose("拟作整班暂缓" if current_scenario.plan=="pause_batch" else "拟作逐号撤销",true)
	await _choose("查看最后确认")
	var before_cancel:Dictionary=app.state.to_dict().duplicate(true);var cancel_writes:int=app.state.writes
	await _choose("先不确认")
	check(app.state.to_dict()==before_cancel and app.state.writes==cancel_writes,"Final desk cancel leaves draft and four pending orders untouched")
	await _frame(90)
	for row:Dictionary in Finale.order_rows(app.state):check(row.disposition=="pending","No timed automatic dispatch after cancellation")
	await _interact("capstone_order_desk");await _choose("查看当前草案");await _choose("查看最后确认")
	stale=_callback("确认执行")
	await _mutation("确认执行",6,first_case,true);_stale_noop(stale,"accepted desk confirmation")
	check(app.state.capstone_ending==current_scenario.plan,"Requested two-plan disposition accepted only at physical desk")
	for i:int in 4:
		var row:Dictionary=Finale.order_rows(app.state)[i]
		check(row.id=="capstone_pending_%03d"%(i+1) and row.disposition==("cancelled" if i<2 else ("held" if current_scenario.plan=="pause_batch" else "continuing")),"Exact four finite orders retain their two-subset disposition")
	await _choose("收好处置回条");await _reload_current("stage6_unpaid")
	await _waypoints([Vector2(1110,690),Vector2(1110,765),Vector2(565,765),Vector2(565,520),Vector2(150,520)])
	await _interact("return_village",false);check(app.state.map_id=="qingwei","Old south stone bridge route and real exit reach village")
	await _waypoints([Vector2(1220,560),Vector2(1220,350),Vector2(800,350),Vector2(800,440),Vector2(520,440)])
	check(app.state.capstone_stage==6 and total_xp(app.state)==_dict_total_xp(before_fight) and app.state.coins==before_fight.coins,"Travelling home cannot finish volume or award reward")
	await _interact("elder");await _choose("先看回条");await _choose("回到灯下")
	var before_home:Dictionary=app.state.to_dict().duplicate(true);stale=_callback("交回回条")
	await _mutation("交回回条",7,first_case,true);_stale_noop(stale,"homecoming reward accepted")
	check(total_xp(app.state)==_dict_total_xp(before_home)+160 and app.state.coins==before_home.coins+80,"Actual elder confirmation pays exactly once160XP80coins")
	check(app.state.party_resources==before_home.party_resources,"Homecoming never restores companion resources")
	await _choose("继续行走");await _reload_current("stage7_rewarded");await _interact("elder");await _choose("继续行走")
	check(total_xp(app.state)==_dict_total_xp(before_home)+160 and app.state.coins==before_home.coins+80,"Elder repeat never pays again")
	check(preserved_story(app.state)==oldhistory,"Whole capstone preserves earned old endings, cargo, receipt and bridge state")
	check(Finale.goal(app.state).is_empty(),"Completion releases capstone navigation ownership")
	await _read_panels()
	var final:Dictionary=app.state.to_dict().duplicate(true)
	scene_cases.append({"case":case_id,"scenario":current_scenario.duplicate(true),"start":start,"before_fight":before_fight,"before_home":before_home,"final":final,"walked_pixels":walked_pixels-start_distance,"fixed_step_seconds":(ticks-start_ticks)/60.0,"combat_and_aftermath_seconds":(ticks-fight_start)/60.0,"real_input_commands":command_count-start_commands,"token_count":combat_tokens.size()})
	print("CAPSTONE_SCENE "+JSON.stringify(scene_cases[-1]))
	app.queue_free();await _frame(3)

func _evidence_helper()->void:
	await _choose("选择同行核对方法")
	var label:String="请唐栖另纸标注" if app.state.tangqi_choice=="preserve" else "请唐栖逐项复读"
	check(_choices().has(label) and _choices().has("请秦禾并看时刻"),"Actual recruited standing Tang and Qin methods offered")
	await _choose(label,true);await _choose("作出责任判断")
	var stale:Callable=_callback("梁缜须对")
	check(app.state.set_party_roster(["hero"]),"Adversarial in-flight bench uses public validated roster API")
	var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
	stale.call();await _frame(2)
	check(app.state.to_dict()==before and app.state.writes==writes and app.state.capstone_stage==2,"Actual scene refuses a now-benched helper before submission")
	await _choose("重新选择核对方法")
	check(_choices()==["自己逐项核对","回到留底册"],"Benched evidence helpers disappear; independent route stays")
	check(app.state.set_party_roster(["hero","shen","tang","qin"]),"Restore genuinely earned four-person roster")
	await _choose("回到留底册");await _choose("展开已发留底");await _choose("继续核两次鹤汀授权");await _choose("核看经办与分存");await _choose("选择同行核对方法")
	await _choose("请秦禾并看时刻" if current_scenario.plan=="cancel_proven" else label,true);await _choose("作出责任判断")
	interruption_checks.append({"case":case_id,"benched_evidence":true})
func _classification_helper()->void:
	await _choose("选择同行核对方法")
	var label:String="请沈青看往返交接" if app.state.shen_care_choice=="mobile" else "请沈青看留岸等候"
	if not Finale.available_methods(app.state,"classification").has("shen_"+app.state.shen_care_choice):
		check(not _choices().has(label),"Actually downed Shen is absent from live classification choices")
		await _choose("自己列明依据与后果");await _choose("作出四号分类");return
	check(_choices().has(label),"Genuinely earned standing Shen helper offered")
	await _choose(label,true);await _choose("作出四号分类")
	var stale:Callable=_callback("001、002证伪")
	check(app.state.set_party_roster(["hero"]),"Adversarial in-flight Shen bench uses public roster API")
	var before:Dictionary=app.state.to_dict().duplicate(true);var writes:int=app.state.writes
	stale.call();await _frame(2)
	check(app.state.to_dict()==before and app.state.writes==writes and app.state.capstone_stage==4,"Actual scene rejects now-benched Shen without classification")
	await _choose("重新选择核对方法")
	check(_choices()==["自己列明依据与后果","回到四号目录"],"Benched classification helper disappears without blocking solo")
	check(app.state.set_party_roster(["hero","shen","tang","qin"]),"Restore genuine roster after guard check")
	await _choose("回到四号目录");await _choose("选择同行核对方法");await _choose(label,true);await _choose("作出四号分类")
	interruption_checks.append({"case":case_id,"benched_classification":true})
func _dict_total_xp(d:Dictionary)->int:return int(d.xp)+30*int(d.level)*(int(d.level)-1)

func _scene_battle(fail_terminal:bool)->void:
	var panel=app.overlay.get_meta("party_battle")
	var opening:Dictionary=app.state.party_battle_snapshot()
	check(opening.enemies.size()==1 and opening.enemies[0].id=="liang_zhen" and opening.enemies[0].max_hp==620,"One real fixed620HP Liang; no player-count scaling")
	check(panel.commands.is_compact()==bool(current_scenario.party),"Actual full/compact battle HUD agrees with real roster")
	check(panel.commands.context.title=="截令归灯","Actual PartyUI uses approved new encounter title")
	var start:int=ticks;combat_tokens={}
	var disk:String=_disk()
	app.state.fail_save=fail_terminal
	while app.current_screen=="party_battle" and ticks-start<60*700:
		if not panel.pending.is_empty():
			var tx:Dictionary=panel.pending
			var key:String=str(tx.epoch)+":"+str(tx.token)
			if not combat_tokens.has(key):combat_tokens[key]={"source":tx.source_id,"action":tx.action_id,"before_round":tx.before.round,"outcome":tx.after.outcome}
		if panel._safe_boundary():await _battle_input(panel)
		await _frame()
		if failures>0:break
	check(app.current_screen=="explore" and not app.state.battle_active and app.state.capstone_stage==4,"Actual PartyUI naturally acknowledges exact tokens through a win")
	if fail_terminal:
		check(app.save_warning and _disk()==disk,"Terminal save failure keeps old disk and accepted book in memory")
		var accepted:Dictionary=app.state.to_dict().duplicate(true)
		app.state.fail_save=false;await _choose("重试保存",true)
		check(app.state.to_dict()==accepted and not app.save_warning,"Terminal retry only persists, never replays battle settlement")
		interruption_checks.append({"case":case_id,"save_failure":"actual_terminal","stage":4})
	_roundtrip_current("actual_battle_terminal")
func _battle_input(panel)->void:
	# Choose one visible legal command per input turn, recomputing after every
	# key/mouse event. Damage waits for recovery; Tang weakens heavy; medicines
	# are finite and chosen only at displayed danger. No model or adapter call.
	var view:Dictionary=app.state.party_battle_snapshot();var phase:String=view.enemies[0].cadence_phase
	for actor:Dictionary in view.actors:
		if actor.hp<=0 or actor.basic_done:continue
		var budget:int=actor.qi;var incoming:Dictionary=_incoming(view,actor.id)
		for action:Dictionary in actor.actions:
			if action.queued:budget-=int(action.cost)
		for action:Dictionary in actor.actions:
			if not Rules.CATEGORIES.has(String(action.category)) or not action.available or action.queued or budget<int(action.cost):continue
			var target:String=actor.id if action.target_team=="self" else "liang_zhen"
			if action.target_team=="ally":
				var need:int=0
				for ally:Dictionary in view.actors:
					var measure:int=int(ally.max_hp)-int(ally.hp) if int(action.effects.get("healing",0))>0 else int(_incoming(view,ally.id).damage)
					if ally.hp>0 and measure>need:need=measure;target=ally.id
				if need<mini(20,int(action.effects.get("healing",1))):continue
			if bool(action.effects.get("guard",false)) and not incoming.heavy:continue
			if action.category=="martial" and action.target_team=="enemy" and not bool(action.effects.get("guard",false)):
				if int(action.effects.get("weaken_amount",0))>0:
					if phase!="heavy":continue
				elif phase!="recovery":continue
			if action.category=="internal" and actor.max_hp-actor.hp<int(action.effects.get("healing",0)) and not (phase=="recovery" and int(action.effects.get("focus_bonus",0))>int(actor.status.focused_damage)):continue
			if action.category=="lightness" and not incoming.heavy and not (phase=="recovery" and int(action.effects.get("focus_bonus",0))>int(actor.status.focused_damage)):continue
			var key:String=panel.commands.slot_key(actor.id,action.category)
			check(panel.commands.buttons.has(key),"Live battle HUD has requested legal skill")
			if not current_scenario.party and action.category=="martial":await _tap(KEY_1)
			else:await _click(panel.commands.buttons[key])
			if not panel.pending_action.is_empty():await _click(panel.unit_plates[target])
			command_count+=1;return
	for actor:Dictionary in view.actors:
		if actor.hp<=0:continue
		for action:Dictionary in actor.actions:
			if action.id=="item" and action.available and (actor.hp<=_incoming(view,actor.id).damage or actor.hp*100<actor.max_hp*35):
				if view.selected_actor_id!=actor.id:await _click(panel.commands.actor_buttons[actor.id])
				await _tap(KEY_4);command_count+=1;return

func _finish()->void:
	_hold("")
	var report:Dictionary={"checks":checks,"failures":failures,"failure_labels":failure_labels,"selected_case":selected_case,"cases":scene_cases,"trace":trace,"interruptions":interruption_checks,"api_journey":journey,"api_operations":operations,"wall_seconds":(Time.get_ticks_msec()-real_started)/1000.0,"ticks":ticks,"scope":"Genuine production API/token-earned predecessors; old opening scene-local effects replayed exactly by existing helpers. Initial canonical state/position transferred once. Entire six-stop capstone uses actual main-scene held walking, E, numeric keys, mouse events and real PartyUI natural presentation/settlement. Combat commands are genuine key/mouse events, not adapter/model mutation calls. Adversarial bench calls use production roster API. Headless fixed60Hz, not native pixels/browser/manual-real-time/performance/playtime proof. No user saves or credentials touched."}
	var f=FileAccess.open(output,FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(report,"\t"));f.close()
	print("%s independent capstone earned scene: %d checks, %d failures, %d routes"%["PASS" if failures==0 else "FAIL",checks,failures,scene_cases.size()])
	if is_instance_valid(app):app.queue_free()
	await process_frame
	quit(0 if failures==0 and scene_cases.size()==(1 if not selected_case.is_empty() else 12) else 1)
