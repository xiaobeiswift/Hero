extends "res://tests/audit_second_region_test.gd"
## Real-scene companion quest, roster, navigation and persistence audit.
func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.state=AuditState.new();game._new_game()
	await _test_ui_gates()
	for choice in ["teach","preserve"]:
		await _test_personal_route(choice,choice=="preserve")
	game._stop_audio();DirAccess.remove_absolute(ProjectSettings.globalize_path(AuditState.AUDIT_PATH))
	game.queue_free();await process_frame
	if failures==0:print("PASS: %d independent companion scene checks" % checks)
	else:push_error("FAIL: %d of %d independent companion scene checks" % [failures,checks])
	quit(0 if failures==0 else 1)
func _prepare_companion_chapter(shen:bool=false) -> void:
	game._new_game()
	var s=game.state
	s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁")
	s.side_stage=3;s.side_choice="rescue";s.side_reward_claimed=true;s.side_found.assign(["boatman","ledger"]);s.side_clues=2
	s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1]);s.bridge_repaired=true
	s.level=5;s.xp=0
	if shen:s.recruit_companion()
	game._travel("frostbridge",Vector2(650,760));game._process(0);game._refresh()
func _test_ui_gates() -> void:
	_prepare_companion_chapter()
	game.state.chapter_two_stage=3
	game._interact("bridge_worker")
	_check(_find_button(game.overlay,"去找旧工册")==null and game.state.tangqi_stage==0,"Unresolved chapter cannot offer personal quest")
	game._close_modal();game.state.chapter_two_stage=4;game.state.bridge_repaired=false
	game._interact("bridge_worker")
	_check(_find_button(game.overlay,"去找旧工册")==null and _find_button(game.overlay,"交出木料 ×2")!=null,"Unrepaired bridge offers repair before personal quest")
	game._close_modal();game._travel("sluice",Vector2(570,320));game._interact("sluice_cache")
	_check(_find_button(game.overlay,"收好工册")==null and _find_button(game.overlay,"静坐调息")!=null,"Notebook cannot be collected before its quest; old rest station works")
	game._close_modal();game._show_inventory()
	await _key(KEY_5)
	var roster=game.overlay.get_meta("party_roster",null)
	_check(roster!=null and roster.displayed_snapshot.actors.size()==1 and roster.cells.tang.toggle.disabled and roster.cells.shen.toggle.disabled and roster.cells.qin.toggle.disabled,"Fifth inventory shortcut opens four cells with only the real hero and locked companions")
	_press("返回行囊");await _key(KEY_4)
	_check(not game.active_modal,"Existing fourth inventory shortcut still returns to exploration")
func _test_personal_route(choice:String,shen:bool) -> void:
	_prepare_companion_chapter(shen)
	_check(game.world._can_walk(game.world.player_pos),"Tang quest giver has a safe interaction coordinate")
	await _key(KEY_E)
	_check(_find_button(game.overlay,"去找旧工册")!=null,"Actual E dispatch opens available Tang quest")
	await _key(KEY_2)
	_check(game.state.tangqi_stage==0 and not game.active_modal,"Postponing the initial offer leaves the quest available")
	await _key(KEY_E);await _key(KEY_ENTER)
	_check(game.state.tangqi_stage==1 and game.state.xp==0,"Enter accepts quest without granting rewards")
	await _check_pending_target("return_sluice")
	_check(game.hint_label.text.contains("旧工册") or game.hint_label.text.contains("工册"),"Sidebar explains the personal quest objective")
	game._load()
	_check(game.state.tangqi_stage==1 and game.world.map_id=="frostbridge","Accepted quest persists through immediate reload")
	game._interact("return_sluice")
	_check(game.world.map_id=="sluice","Quest return trip uses the actual region exit")
	await _check_pending_target("sluice_cache")
	_check_notebook_reachability()
	game.world.teleport(Vector2(570,320));game._process(0)
	await _key(KEY_E)
	_check(_find_button(game.overlay,"收好工册")!=null,"Notebook can be found through actual E interaction")
	await _key(KEY_ESCAPE)
	_check(game.state.tangqi_stage==1,"Closing notebook dialogue does not collect it")
	await _key(KEY_E);_press("收好工册")
	_check(game.state.tangqi_stage==2 and not game.active_modal,"Notebook collected once through UI")
	game._load()
	_check(game.state.tangqi_stage==2 and game.world.map_id=="sluice","Notebook survives reload before return")
	await _check_pending_target("exit_frostbridge")
	game._interact("sluice_cache")
	_check(_find_button(game.overlay,"收好工册")==null and _find_button(game.overlay,"静坐调息")!=null,"Collected notebook cannot be repeated and rest service returns")
	game._close_modal()
	game._travel("qingwei",Vector2(460,430));await _check_pending_target("exit_sluice")
	game._interact("exit_sluice");_press("前往废闸")
	game._interact("exit_frostbridge");_press("前往霜桥驿")
	await _check_pending_target("bridge_worker")
	game.world.teleport(Vector2(650,760));game._process(0);await _key(KEY_E)
	_check(_find_button(game.overlay,"传给学徒")!=null and _find_button(game.overlay,"留存原稿")!=null,"Both notebook decisions are available after returning")
	_press("再想想");game._load()
	_check(game.state.tangqi_stage==2 and game.state.tangqi_choice=="","Decision postponement persists without choosing a branch")
	game._interact("bridge_worker");_press("传给学徒" if choice=="teach" else "留存原稿")
	_check(game.state.tangqi_stage==3 and game.state.tangqi_choice==choice and game.state.xp==50,"Selected notebook decision grants exact one-time XP")
	_check(game.state.resources.cloth==(2 if choice=="teach" else 0) and game.state.resources.iron==(2 if choice=="preserve" else 0),"Both UI branches grant their distinct material reward")
	if not shen:_check(not _modal_text().contains("沈青保留在同行册"),"Tang-first invitation does not claim unrecruited Shen is already owned")
	_press("稍后再说");game._load()
	_check(game.state.tangqi_stage==3 and not game.state.tangqi_unlocked,"Recruitment can be deferred and reloaded after receiving quest reward")
	await _check_pending_target("bridge_worker")
	game._show_journal()
	_check(_modal_text().contains("尺上旧痕") and _modal_text().contains("邀请唐栖"),"Journal records pending final invitation")
	game._close_modal();game._interact("bridge_worker");_press("邀请同行")
	game._process(0)
	_check(game.state.tangqi_unlocked and game.state.current_companion()=="唐栖" and game.world.companion_active,"Recruitment immediately enables active Tang follower")
	game._load()
	_check(game.state.tangqi_unlocked and game.state.current_companion()=="唐栖" and game.state.xp==50,"Active Tang and quest reward survive reload")
	await process_frame;await process_frame
	_check(game.world.companion_name=="唐栖" and game.world.nearby_name=="修桥工位" and game.near_label.text.contains("修桥工位"),"Active Tang has correct follower identity and worksite prompt after reload")
	var before=game.state.to_dict()
	game._interact("bridge_worker")
	_check(_find_button(game.overlay,"去找旧工册")==null and _find_button(game.overlay,"邀请同行")==null and _find_button(game.overlay,"传给学徒")==null,"Completed NPC revisit offers no replay or duplicate reward")
	game._close_modal()
	_check(game.state.to_dict()==before,"Completed NPC revisit is resource-neutral")
	game._show_inventory()
	_check(_modal_text().contains("唐栖"),"Inventory identifies active Tang")
	_press("切换阵型")
	_check(game.state.formation=="护后" and game.status_label.text.contains("重击") and game.status_label.text.contains("5"),"Formation switch explains selected Tang support")
	await _key(KEY_5)
	var roster=game.overlay.get_meta("party_roster",null)
	_check(roster!=null and not roster.cells.tang.toggle.disabled and roster.cells.shen.toggle.disabled==not shen and roster.cells.qin.toggle.disabled,"Roster toggles only genuinely recruited companions")
	_press("返回行囊");await _key(KEY_4)
	game._travel("qingwei",Vector2(330,330));game._process(0)
	_check(game.world.nearby_name=="沈青","Inactive or unrecruited Shen is present at the clinic while Tang follows")
	if not shen:
		await _key(KEY_E)
		_check(_find_button(game.overlay,"邀请同行")!=null,"Shen remains recruitable after Tang joins first")
		_press("邀请同行");game._process(0)
		_check(game.state.available_companions()==["沈青","唐栖"] and game.state.current_companion()=="唐栖","Later Shen recruitment preserves Tang selection")
	game._show_inventory();await _key(KEY_5)
	var hp=game.state.hp;var qi=game.state.qi
	var party_resources=game.state.party_resources.duplicate(true)
	roster=game.overlay.get_meta("party_roster")
	_check(game.state.party_roster.has("shen") and game.state.party_roster.has("tang"),"Both actual invitations retain their own party membership")
	roster.cells.tang.toggle.pressed.emit();_press("返回行囊");await _key(KEY_4)
	game._process(0);await process_frame;await process_frame
	_check(game.state.current_companion()=="沈青" and game.state.hp==hp and game.state.qi==qi,"Party selection spends no resources and changes active companion")
	_check(game.state.party_resources==party_resources,"Benched companion keeps exact resources")
	_check(game.world.nearby_name=="药铺伙计","Clinic stand-in appears when active Shen travels")
	_check(game.near_label.text.contains("药铺伙计"),"Stationary nearby interaction prompt refreshes after selecting Shen")
	game._show_inventory();await _key(KEY_5);roster=game.overlay.get_meta("party_roster")
	roster.cells.tang.toggle.pressed.emit();roster.cells.shen.toggle.pressed.emit()
	_press("返回行囊");await _key(KEY_4);game._process(0);await process_frame;await process_frame
	_check(game.world.nearby_name=="沈青","Switching back restores inactive Shen's clinic identity")
	_check(game.near_label.text.contains("沈青"),"Stationary nearby interaction prompt refreshes after selecting Tang")
	game._save();game._load()
	_check(game.state.current_companion()=="唐栖" and game.state.formation=="护后","Selected companion and formation survive UI save/load")
	game._show_inventory();_press("切换阵型");game._close_modal()
	var controller = UnifiedDriver.open_training(game)
	_check(controller.unit_plates.has("tang") and controller.unit_plates.tang.facts.name=="唐栖","Current battle presents the selected independent Tang actor")
	await _key(KEY_I)
	_check(UnifiedDriver.active(game),"Inventory cannot replace current combat to change party")
	var tang_acted: bool = false
	for index: int in range(12):
		if not game.state.battle_active: break
		var tx:Dictionary=UnifiedDriver.step(game,false)
		if tx.source_id=="tang" and tx.action_id=="attack": tang_acted=true;break
	_check(tang_acted and controller.logs.any(func(line):return line.contains("唐栖")),"Actual automatic Tang action and renderer event log identify the independently acting companion")
	if game.state.battle_active: UnifiedDriver.leave(game)

	game._show_journal()
	_check(_modal_text().contains("工册已传给学徒" if choice=="teach" else "原稿与水令一同留存"),"Completed journal preserves chosen ending text")
	game._close_modal()
func _check_pending_target(target:String) -> void:
	game._process(0)
	_check(game.world._quest_target_id()==target,"World guide targets next companion objective: "+target)
	await _key(KEY_M)
	var chart=_find_chart(game.overlay)
	_check(chart!=null and chart.current_target==target and chart.markers.has(target),"M chart agrees with current companion target: "+target)
	await _key(KEY_ESCAPE)
func _check_notebook_reachability() -> void:
	var queue:Array[Vector2]=[Vector2(190,520)];var visited={queue[0]:true};var cursor=0;var found=false
	while cursor<queue.size():
		var p=queue[cursor];cursor+=1
		if p.distance_to(game.world.interactables.sluice_cache.pos)<65:found=true;break
		for offset in [Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20)]:
			var next=p+offset
			if not visited.has(next) and game.world._can_walk(next):visited[next]=true;queue.append(next)
	_check(found,"Notebook interaction range is reachable from the actual sluice entry")
