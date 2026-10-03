extends "res://tests/audit_second_region_test.gd"
func _run()->void:
	game=load("res://scenes/main.tscn").instantiate()
	if not game.has_method("_new_game"):game.free();quit(2);return
	root.add_child(game);await process_frame;game.state=AuditState.new()
	for old_route in ["rescue","pursuit"]:
		for ending in ["守望","秉公"]:
			for choice in ["shore","mobile"]:await _story_route(old_route,ending,choice)
	await _shared_shed(false)
	await _shared_shed(true)
	await _navigation_priority()
	game._stop_audio();await create_timer(0.25).timeout;game.queue_free();await process_frame
	if failures==0:print("PASS: %d Shen care scene checks" % checks)
	else:push_error("FAIL: %d of %d Shen care scene checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func _prepare_shen(route:String="rescue",ending:String="守望")->void:
	game._new_game();game.state.quest_stage=6;game.state.ending=ending;game.state.choose_sect("听潮阁")
	game.state.recruit_companion();game.state.side_stage=3;game.state.side_choice=route;game.state.side_reward_claimed=true;game.state.side_clues=2;game.state.side_found.assign(["boatman","ledger"])
	game._travel("qingwei",Vector2(330,365));game._refresh()
func _talk_shen(id:String)->void:
	if game.active_modal:game._close_modal()
	game.world.teleport(game.world.interactables[id].pos);game._process(0)
	await _key(KEY_E)
	_check(game.active_modal,"Actual E opens "+id)
func _step_saved(stage:int)->void:
	await _key(KEY_ESCAPE)
	game._load()
	_check(game.state.shen_care_stage==stage,"Esc/reload preserves story stage "+str(stage))
func _story_route(old_route:String,ending:String,choice:String)->void:
	_prepare_shen(old_route,ending)
	game.companion_story.roster();_open_shen_roster_story()
	_check(game.state.shen_care_stage==0 and _modal_text().contains("青苇药铺"),"Roster hint cannot remotely start story")
	game._close_modal()
	await _talk_shen("healer")
	_check(_find_button(game.overlay,"免费调息")!=null and _find_button(game.overlay,"买药 · 12 文")!=null,"Personal story retains normal healer services")
	_press("药箱之外")
	_check(_modal_text().contains("可以行走") and _modal_text().contains("不用另买"),"Opening presents personal stakes and free investigation")
	var expired:Callable=game.modal_actions[0]
	await _key(KEY_ESCAPE);expired.call()
	_check(game.state.shen_care_stage==0,"Cancelled/stale acceptance cannot start story")
	await _talk_shen("healer");_press("药箱之外");await _key(KEY_ENTER)
	game._process(0)
	_check(game.state.shen_care_stage==1 and game.world._quest_target_id()=="exit_sluice","Accepting points toward sluice")
	await _step_saved(1)
	game._travel("sluice",Vector2(560,790));await _talk_shen("stranded_boatman")
	_check(_modal_text().contains("先割断") if old_route=="rescue" else _modal_text().contains("不是补证言"),"Consultation respects earlier rescue/pursuit")
	_press("再听水令旧事")
	_check(game.state.shen_care_stage==1 and _modal_text().contains("逆流时入港"),"Old testimony remains readable without progressing personal story")
	_press("谈谈近况");_press("记下他的难处")
	game._process(0)
	_check(game.state.shen_care_stage==2 and game.world._quest_target_id()=="sluice_cache","Consultation points to existing shelter")
	await _step_saved(2)
	await _talk_shen("sluice_cache");game.state.hp=1
	_press("在此免费调息")
	_check(game.state.hp==game.state.max_hp and game.state.shen_care_stage==2,"Free rest remains available and does not auto-inspect")
	await _talk_shen("sluice_cache");_press("记下药棚情形")
	game._process(0)
	_check(game.state.shen_care_stage==3 and game.world._quest_target_id()=="return_village","Inspection points back to pharmacy")
	await _step_saved(3)
	game._travel("qingwei",Vector2(330,365));await _talk_shen("healer");_press("药箱之外")
	_check(_modal_text().contains("远埠仍须等靠岸") and _modal_text().contains("暂缺固定照看"),"Both options state their opportunity cost")
	_press("随船问诊" if choice=="shore" else "留岸照护")
	_check(game.state.shen_care_stage==4 and game.state.ShenCare.mobile_heal(game.state)==0 and game.state.ShenCare.shore_bonus(game.state)==0,"Unposted draft has no support reward")
	_press("重新商议")
	_press("留岸照护" if choice=="shore" else "随船问诊")
	_check(game.state.shen_care_choice==choice and game.state.xp==0,"Draft revision changes no XP or reward")
	await _step_saved(4)
	_check(game.world._quest_target_id()=="board" and game.quest_label.text=="药箱之外","HUD and world agree on notice objective")
	await _talk_shen("board")
	_check(_modal_text().contains("抄过账页") if ending=="守望" else _modal_text().contains("县衙收账"),"Notice sponsor respects opening choice")
	_check(_modal_text().contains("不张贴病人的姓名") and _modal_text().contains("不再改换"),"Commitment screen states privacy and finality")
	_press("看看原告示")
	_check(_modal_text().contains("点灯不收借火钱") and game.state.shen_care_stage==4,"Original board stays accessible without posting")
	_press("查看照护约")
	var post:Callable=game.modal_actions[0]
	await _key(KEY_ESCAPE);post.call()
	_check(game.state.shen_care_stage==4,"Esc and expired posting callback do not finalize")
	await _talk_shen("board");await _key(KEY_ENTER)
	_check(game.state.shen_care_stage==5 and game.state.xp==40,"Actual confirmation grants exactly one completion")
	_check(_modal_text().contains("他的恢复还没有结束"),"Conclusion does not promise instant cure")
	await _step_saved(5)
	var before=game.state.to_dict()
	post.call()
	_check(game.state.to_dict()==before,"Old posting callback cannot replay completed reward")
	await _talk_shen("board")
	_check(_modal_text().contains("照护约") and _modal_text().contains("留岸照护" if choice=="shore" else "随船问诊"),"Board retains route-specific aftermath")
	game._close_modal();game._travel("sluice",Vector2(560,790));await _talk_shen("stranded_boatman")
	_check(_modal_text().contains("记轮值") if choice=="shore" else _modal_text().contains("远处的人"),"Xu has a lasting distinct response")
	_press("告辞");await _talk_shen("sluice_cache")
	_check(_modal_text().contains("轮值纸") if choice=="shore" else _modal_text().contains("短渡停泊"),"Shelter scene reflects finite volunteer allocation")
	game._close_modal();game._show_journal()
	var journal_history=game.overlay.get_meta("journal_ui",null)
	_check(is_instance_valid(journal_history),"Earned history is reachable through dedicated J")
	journal_history.action_buttons.history.pressed.emit();await process_frame
	_check(journal_history.page=="history" and journal_history.body.is_visible_in_tree() and journal_history.body.scroll_active,"Real detailed-history control opens a visible scrollable earned record")
	_check(_modal_text().contains("药箱之外") and _modal_text().contains("✓ 把照护约"),"Journal records complete personal history")
	game._close_modal();game.companion_story.roster()
	var folio=game.overlay.get_meta("party_roster",null)
	var shen:Dictionary={}
	if is_instance_valid(folio):
		for actor:Dictionary in folio.displayed_snapshot.actors:
			if actor.id=="shen":shen=actor
	_check(not shen.is_empty() and shen.care_defense_bonus==(1 if choice=="shore" else 0) and shen.care_healing_bonus==(2 if choice=="mobile" else 0),"Actual Shen card projects the agreed independent defense/healing benefit")
	if is_instance_valid(folio):
		_check(folio.cells.shen.actions.tooltip_text.contains(str(30 if choice=="mobile" else 28)),"Native Shen martial tooltip displays the actual derived healing amount")
	_open_shen_roster_story()
	_check(_modal_text().contains("留岸照护" if choice=="shore" else "随船问诊"),"Native Shen story callback preserves the agreed care branch")
	_check(_modal_text().contains("自身防御提高1") if choice=="shore" else (_modal_text().contains("青灯渡脉") and _modal_text().contains("治疗提高2点") and _modal_text().contains("目标气血上限")),"Native story description matches independent actor benefits and target healing cap")
	_press("回到同行册")
	_check(game.overlay.has_meta("party_roster"),"Native story return reopens the real folio")
	_check(game.state.xp==40 and game.state.coins==24,"Revisits do not regrant rewards or require purchases")
func _prepare_tang()->void:
	game.state.chapter_two_stage=4;game.state.chapter_two_ending="protect_witness";game.state.bridge_repaired=true;game.state.archive_clues.assign(["clerk","inscription"]);game.state.seal_sequence.assign([2,0,1])
func _shared_shed(tang_first:bool)->void:
	_prepare_shen();_prepare_tang();game.state.begin_tangqi_quest()
	game.state.begin_shen_care();game.state.consult_shen_patient()
	game._travel("sluice",Vector2(570,350));await _talk_shen("sluice_cache")
	_check(_find_button(game.overlay,"查看照护场地")!=null and _find_button(game.overlay,"寻找旧工册")!=null and _find_button(game.overlay,"免费调息")!=null,"Shared shelter exposes both quests and normal rest")
	if tang_first:
		_press("寻找旧工册");_press("收好工册")
		_check(game.state.tangqi_stage==2 and game.state.shen_care_stage==2,"Notebook does not inspect shelter")
		await _talk_shen("sluice_cache");_press("记下药棚情形")
	else:
		_press("查看照护场地");_press("记下药棚情形")
		_check(game.state.tangqi_stage==1 and game.state.shen_care_stage==3,"Inspection does not steal Tang notebook")
		await _talk_shen("sluice_cache");_press("收好工册")
	_check(game.state.tangqi_stage==2 and game.state.shen_care_stage==3,"Both task orders remain completable")
	await _step_saved(3)
func _navigation_priority()->void:
	_prepare_shen();_prepare_tang()
	game.state.tangqi_stage=3;game.state.tangqi_choice="teach";game.state.recruit_tangqi()
	game.state.begin_shen_care()
	for stage in [1,2,3,4]:
		game.state.shen_care_stage=stage;game.state.shen_care_choice="shore" if stage==4 else ""
		for map_id in ["qingwei","sluice","frostbridge","mistwood"]:
			game.state.mist_stage=4;game.state.mist_approach="records";game.state.chapter_two_ending="open_records";game.state.mist_ending="release_water";game.state.mist_gauges.assign(["rain","stone","basin"])
			game._travel(map_id,Vector2(460,430));game._process(0)
			_check(game.world.interactables.has(game.shen_story.target_id()) and game.world._quest_target_id()==game.shen_story.target_id(),"Story target exists and HUD/world agree: "+map_id+" stage"+str(stage))
			_check(game.quest_label.text=="药箱之外" and game.state.current_companion()=="唐栖","Tang can remain active during personal story")
	game.state.mist_stage=1;game.state.mist_gauges.clear();game.state.mist_approach="";game.state.mist_ending=""
	game._process(0);game._refresh()
	_check(game.world._quest_target_id()=="mist_rain_gauge" and game.quest_label.text==game.mist_story.title(),"Unfinished local Mistwood still has consistent priority")
	game._travel("qingwei",Vector2(650,720));game.state.sect_trial_won=true;game.state.sect_rank=1;game._process(0);game._refresh()
	_check(game.world._quest_target_id()=="mentor" and game.quest_label.text=="待领门中荐记","Pending mentor reward remains visible in village")

func _open_shen_roster_story()->bool:
	var folio=game.overlay.get_meta("party_roster",null)
	var valid:bool=is_instance_valid(folio) and folio.cells.has("shen")
	if valid:
		var cell:Dictionary=folio.cells.shen
		valid=cell.panel.get_meta("actor_id","")=="shen" and cell.name.text=="沈青" and cell.story.name=="Story_shen" and cell.story.visible and not cell.story.disabled
	_check(valid,"Native Story_shen button belongs to the actual Shen card")
	if not valid:return false
	var before:Dictionary=game.state.to_dict()
	folio.cells.shen.story.pressed.emit()
	_check(game.state.to_dict()==before and game.active_modal and not game.overlay.has_meta("party_roster"),"Native Shen story callback is read-only and opens its actual story page")
	return true
