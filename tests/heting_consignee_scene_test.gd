extends "res://tests/audit_heting_scene_test.gd"
## Prepared completed-old-chapter fixtures, not earned balance or playtime.
## Reuses the independent collision-grid navigator: real movement actions and
## E/number/Esc input, actual main/PartyUI, isolated durable save/reload paths.
const ConsigneeRules = preload("res://scripts/heting_consignee_rules.gd")
const ConsigneeStory = preload("res://scripts/heting_consignee_story.gd")

func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture = "user://consignee-scene-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(fixture) == OK,"Create isolated chapter scene fixture")
	probe = PortAuditState.new(); probe.fixture = fixture; store = Slots.new(fixture)
	game = load("res://scenes/main.tscn").instantiate(); game.state = probe
	root.add_child(game); await process_frame; game._stop_audio(); game.audio_on = false; game.world.set_process(false)
	var receipt: int = 0
	for harbor: String in ["short_ferries","open_scale"]:
		for plan: String in ConsigneeRules.PLANS:
			await _new_route(harbor,plan,receipt); receipt += 1
	await _scene_guards_and_failures()
	await _leave_and_resume()
	await _scene_defeat()
	_check(walked_distance > 10000 and real_interactions > 40,"Chapter scenes traverse real terrain with repeated actual E input")
	_check(not FileAccess.file_exists(BaseState.SAVE_PATH),"No player autosave created")
	for path: String in probe.paths: _check(path.begins_with(fixture+"/"),"Every I/O path stays in fixture")
	game._stop_audio(); game.queue_free(); await process_frame; _remove_port_fixture(fixture)
	print("%s: %d consignee real-scene checks; %.0fpx walked, %d E interactions (synthetic old-chapter fixtures)" % ["PASS" if failures == 0 else "FAIL",checks,walked_distance,real_interactions])
	quit(0 if failures == 0 else 1)

func _prepare_new(harbor: String = "short_ferries", receipt: int = 0) -> void:
	_prepare("release_water")
	probe.heting_stage = 4; probe.heting_delivered.assign(["meal","sealed","reserve"])
	probe.heting_draft = harbor; probe.heting_ending = harbor; probe.heting_bridge = "east"; probe.receipt_stage = receipt
	# Isolate scene/settlement mechanics; organic stats are tested separately.
	probe.attack = 900; probe.defense = 900
	game._travel("heting",Port.ENTRY); game._process(0)
	_check(game.world.interactables.has(ConsigneeRules.SOURCE),"New actual site appears after old chapter completion")
	_check(probe._stage_save_data(probe.to_dict(),14).ok,"Whole prepared scene is schema14 canonical")

func _choice_key(label: String) -> void:
	var button: Button = _find_button(game.overlay,label)
	_check(button != null,"Actual keyboard choice exists: "+label)
	if button == null: return
	var number: int = String(button.name).trim_prefix("DialogueChoice").to_int()
	_check(number >= 1 and number <= 5,"Every new choice has reachable1–5 number")
	await _key(KEY_1 + number - 1)

func _new_site(site: String) -> void:
	await _talk_port(site)
	if site != ConsigneeRules.SOURCE: await _choice_key(game.consignee_story.link_label(site))

func _investigate_scene(reverse: bool = false) -> void:
	await _new_site("heting_dispatch"); await _choice_key("接下本批核查")
	_assert_saved("new acceptance")
	var order: Array = ["southern_counterfoil","lot_seals","removal_order"] if reverse else ["removal_order","southern_counterfoil","lot_seals"]
	for observation: String in order:
		var site: String = ConsigneeStory.OBSERVATION_SITES[observation]
		await _new_site(site)
		_check(game.world.nearby_id == site and game.world.player_pos.distance_to(game.world.interactables[site].pos)<75,"Evidence selected only at real nearby site")
		await _choice_key("亲自核验"); _assert_saved("accepted " + observation)
		_check(probe.consignee_observations.has(observation),"Actual numeric input records " + observation)
	await _choice_key("核对三处矛盾")
	_check(game.modal_actions.size() == 5,"Bounded deduction exposes exactly five key-accessible choices")
	for window: Vector2i in [Vector2i(1280,800),Vector2i(800,500)]:
		root.size = window; await process_frame
		var page: Control = game.overlay.find_child("DialogueSheet",true,false)
		var body: Control = page.find_child("DialogueBody",true,false)
		var previous: Array[Rect2] = []
		for index: int in range(5):
			var button: Control = page.find_child("DialogueChoice%d" % (index+1),true,false)
			_check(Rect2(Vector2.ZERO,page.size).encloses(button.get_rect()) and not body.get_rect().intersects(button.get_rect()),"Small-window deduction buttons remain inside sheet/outside scroll body")
			for rect: Rect2 in previous: _check(not rect.intersects(button.get_rect()),"All five choice targets stay disjoint")
			previous.append(button.get_rect())
	root.size = Vector2i(1280,800); await process_frame
	var write_count: int = probe.writes
	var obsolete: Callable = game.modal_actions[0]
	await _key(KEY_5); obsolete.call()
	_check(not game.active_modal and probe.consignee_stage == 1 and probe.writes == write_count,"Key5 closes with no save; stale deduction cannot advance")
	await _new_site(ConsigneeStory.OBSERVATION_SITES[order[-1]]); await _choice_key("核对三处矛盾")
	await _key(KEY_2)
	_check(_modal_text().contains("不能") and probe.consignee_stage == 1 and probe.writes == write_count,"Wrong real key answer explains bounded proof with no write")
	await _choice_key("重新核对"); await _key(KEY_1)
	_check(probe.consignee_stage == 2,"Correct key alone accepts deduction")
	_assert_saved("accepted deduction")

func _receipt_access(receipt: int) -> void:
	await _talk_port("heting_scale")
	var label: String = ["谈谈复签（可选）","复签应战准备","查看待核副签","重看复签记录"][receipt]
	var before: Dictionary = probe.to_dict(); var writes: int = probe.writes
	await _choice_key(label)
	_check(_modal_text().contains("复签") or _modal_text().contains("副签"),"Old optional receipt remains reachable from shared scale")
	await _key(KEY_ESCAPE)
	_check(probe.to_dict() == before and probe.writes == writes,"Old receipt inspection/Esc changes no new/old progress or save")

func _battle_scene() -> void:
	await _new_site(ConsigneeRules.SOURCE)
	var coins: int = probe.coins; var xp: int = _total_xp()
	await _choice_key("保存后阻止强提")
	_check(game.current_screen == "party_battle" and probe.battle_active,"Warehouse real input enters current PartyUI")
	if game.current_screen != "party_battle": return
	var panel = game.overlay.get_meta("party_battle"); panel.set_process(false); panel.art.set_process(false)
	var snapshot: Dictionary = probe.party_battle_snapshot()
	_check(snapshot.enemies.size() == 2 and snapshot.enemies[0].max_hp == 260 and snapshot.enemies[1].max_hp == 160,"Scene uses distinct fixed260/160 actual opponents")
	_check(panel.commands.context.title.contains("未损先收") and panel.commands.context.location.contains("北仓"),"Actual combat heading/location never falls back to old encounter")
	for id: String in panel.unit_plates:
		var plate = panel.unit_plates[id]
		_check(plate.get_rect() == panel.art.unit_label_rect(id),"UnitPlate follows rendered moving label rect")
		if plate.facts.team == "enemy":
			var text: String = "%s  %d/%d" % [plate.facts.name,plate.facts.hp,plate.facts.max_hp]
			_check(plate.FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x <= plate.size.x,"Opponent full name and HP fit widened label")
			_check(plate.FONT.get_string_size(plate.status_caption(),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x <= plate.size.x,"Existing guard/opening status fits label")
			# Detached displayed facts only: measure every cadence/weakening pair,
			# including the narrower helper plate, without modifying combat state.
			var actual: Dictionary = plate.facts.duplicate(true)
			for guarded: bool in [false,true]:
				for opening: int in [0,6,8]:
					for remaining: int in [0,1,2]:
						plate.facts.brace = guarded; plate.facts.opening_bonus = opening
						plate.facts.status.weaken_amount = 3; plate.facts.status.weaken_strikes = remaining
						_check(plate.FONT.get_string_size(plate.status_caption(),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+8 <= plate.size.x,"Combined cadence and Tang weakening fit actual label width")
			plate.facts = actual
	for step: int in range(40):
		if not probe.battle_active: break
		panel._process(1.0)
		if panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(not probe.battle_active and probe.consignee_stage == 3 and game.current_screen == "explore","Actual automatic presentation terminal secures lot")
	_check(probe.coins == coins and _total_xp() == xp and _modal_text().contains("没有发修为或铜钱"),"Victory gives no early chapter reward or ending")
	_assert_saved("actual battle secured")

func _new_route(harbor: String, plan: String, receipt: int) -> void:
	_prepare_new(harbor,receipt)
	await _receipt_access(receipt)
	await _investigate_scene(plan == "return_to_owner")
	await _choice_key("拟作" + ConsigneeStory.PLAN_NAMES[plan]); _assert_saved("reversible plan")
	_check(game.heting_story.title() == "未损先收" and game.heting_story.hint().contains("复签"),"New objective stays useful while reminding old receipt remains")
	await _battle_scene()
	await _choice_key("查看北仓这一车"); await _choice_key("押本批两篓封粮")
	_assert_saved("finite cart taken")
	_check(probe.consignee_stage == 4 and probe.heting_cargo.is_empty() and game.world.heting_cart_loaded(),"New cart physically loads without rewriting old cargo")
	_check(not game.world._can_step(Vector2(805,420),Vector2(805,595)),"New loaded cart obeys existing narrow-pier restriction")
	await _choice_key("继续押送")
	var map_writes: int = probe.writes
	await _key(KEY_M)
	var chart = game.overlay.find_child("RegionChart",true,false)
	_check(chart != null and chart.consignee_cargo_location == "cart" and chart.current_target == ("heting_scale" if plan == "hold_for_inspection" else "heting_cargo"),"Actual map route targets real receiver marker and new cart")
	await _key(KEY_ESCAPE)
	_check(probe.writes == map_writes,"Read-only map open/Esc does not write a save")
	var site: String = "heting_scale" if plan == "hold_for_inspection" else "heting_cargo"
	await _new_site(site)
	var old: Callable = game.modal_actions[0]; var writes: int = probe.writes; var before: Dictionary = probe.to_dict()
	await _key(KEY_ESCAPE); old.call()
	_check(probe.to_dict() == before and probe.writes == writes and probe.consignee_stage == 4,"Interrupted final confirmation does not hand over or save")
	await _new_site(site); var coins: int = probe.coins; var xp: int = _total_xp()
	var finish: Callable = game.modal_actions[0]; await _choice_key("确认交下本批"); finish.call()
	_check(probe.consignee_stage == 5 and probe.consignee_ending == plan and probe.coins == coins+60 and _total_xp() == xp+120,"Only final local confirmation pays equal120XP60coins once")
	_check(probe.heting_ending == harbor and probe.receipt_stage == receipt and probe.heting_delivered == ["meal","sealed","reserve"],"Actual new completion preserves old allocation and optional receipt exactly")
	_assert_saved("new final reward before dismissal")
	_check(game.heting_story.hint().contains("交接已经记定") if receipt in [0,3] else game.heting_story.hint() == probe.Receipt.hint(probe),"Completed chapter hint records outcome or restores pending receipt")
	await _cancel_reload("new complete ending " + plan)
	await _new_site(site)
	_check(_modal_text().contains("平川粮栈") and _modal_text().contains("上游") and _find_button(game.overlay,"确认交下本批") == null,"Receiver aftermath records bounded local finding and blocks repeat payout")
	await _key(KEY_ESCAPE); var journal_writes: int = probe.writes; await _key(KEY_J)
	_check(_modal_text().contains("未损先收") and _modal_text().contains("一秤两岸") and _modal_text().contains("昨夜"),"Journal retains both chapters and unchanged night allocation")
	await _key(KEY_ESCAPE)
	_check(probe.writes == journal_writes,"Read-only journal open/Esc does not write a save")
	await _receipt_access(receipt)

func _scene_guards_and_failures() -> void:
	_prepare_new(); await _new_site("heting_dispatch")
	var stale: Callable = game.modal_actions[0]; await _key(KEY_ESCAPE); await _new_site("heting_dispatch")
	var writes: int = probe.writes; stale.call(); _check(probe.consignee_stage == 0 and probe.writes == writes,"Old scene acceptance cannot act on newly opened modal")
	var remote: Callable = game.modal_actions[0]; game.world.teleport(Port.ENTRY); game._process(0); remote.call()
	_check(probe.consignee_stage == 0 and probe.writes == writes,"Live world proximity rejects captured acceptance")
	await _key(KEY_ESCAPE); await _new_site("heting_dispatch")
	var temp: String = ProjectSettings.globalize_path(fixture.path_join("hero_save.json.tmp"))
	_check(DirAccess.make_dir_absolute(temp) == OK,"Create isolated blocked-save path")
	await _choice_key("接下本批核查")
	_check(probe.consignee_stage == 1 and game.save_warning and _modal_text().contains("未成功"),"Actual filesystem failure leaves accepted stage and truthful retry")
	DirAccess.remove_absolute(temp); await _choice_key("重试保存"); _assert_saved("acceptance retry")
	await _key(KEY_ESCAPE)
	# Complete the actual remaining observations through their local pages.
	for observation: String in ConsigneeRules.OBSERVATIONS:
		await _new_site(ConsigneeStory.OBSERVATION_SITES[observation]); await _choice_key("亲自核验")
	await _choice_key("核对三处矛盾"); await _choice_key("未验先撤，理由倒置"); await _choice_key("拟作封粮留验")
	await _new_site(ConsigneeRules.SOURCE); DirAccess.make_dir_absolute(temp)
	await _choice_key("保存后阻止强提")
	_check(game.current_screen == "explore" and not probe.battle_active and probe.consignee_stage == 2 and _modal_text().contains("交锋尚未开始"),"Actual pre-entry write failure refuses battle")
	DirAccess.remove_absolute(temp); await _choice_key("重试保存"); _check(not probe.battle_active,"Retry only saves checkpoint and does not auto-start")
	await _choice_key("保存后阻止强提")
	var panel = game.overlay.get_meta("party_battle"); panel.set_process(false); panel.art.set_process(false)
	await _key(KEY_5)
	if panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(probe.consignee_stage == 2 and not probe.battle_active and probe.consignee_ending.is_empty(),"Actual retreat key/presentation retains draft and investigation")
	await _battle_scene(); await _choice_key("查看北仓这一车"); await _choice_key("押本批两篓封粮"); await _choice_key("继续押送")
	await _new_site("heting_cargo"); await _choice_key("改作撤运还粮")
	_check(probe.consignee_stage == 4 and probe.consignee_draft == "return_to_owner" and _find_button(game.overlay,"确认交下本批") != null,"Wrong receiver draft change requires separate final confirmation")
	var coins: int = probe.coins; DirAccess.make_dir_absolute(temp); await _choice_key("确认交下本批")
	_check(probe.consignee_stage == 5 and probe.coins == coins+60 and game.save_warning,"Actual final failed write retains one settled payout")
	DirAccess.remove_absolute(temp); await _choice_key("重试保存"); _check(probe.coins == coins+60,"Actual final write retry never pays twice"); _assert_saved("final filesystem retry")

func _leave_and_resume() -> void:
	_prepare_new(); await _investigate_scene(); await _choice_key("拟作撤运还粮"); await _battle_scene()
	await _choice_key("查看北仓这一车"); await _choice_key("押本批两篓封粮"); await _choice_key("继续押送")
	await _talk_port("return_mistwood"); var writes: int = probe.writes; await _key(KEY_ESCAPE)
	_check(probe.consignee_stage == 4 and probe.map_id == "heting" and probe.writes == writes,"Escape at loaded exit neither parks nor saves")
	await _talk_port("return_mistwood"); await _choice_key("停回北仓后离开")
	_check(probe.map_id == "mistwood" and probe.consignee_stage == 3 and probe.consignee_cargo_location == "warehouse","Explicit park-and-leave retains exact finite lot")
	_check(game._track_heting() and game.heting_story.target_id() == "exit_heting" and game.world._quest_target_id() == "exit_heting" and game.heting_story.hint().contains("返回鹤汀"),"Parked unfinished chapter keeps existing off-map return compass and truthful hint")
	await _talk_port("exit_heting",false); _press("返回鹤汀埠")
	await _new_site(ConsigneeRules.SOURCE); await _choice_key("押本批两篓封粮")
	_check(probe.consignee_stage == 4 and probe.consignee_draft == "return_to_owner","Returning can retake same secured lot and unchanged draft")
	await _choice_key("把本批停回北仓"); _assert_saved("manual parking")
	_check(probe.consignee_stage == 3 and probe.consignee_cargo_location == "warehouse","Local explicit parking restores one source lot")

func _scene_defeat() -> void:
	_prepare_new(); await _investigate_scene(); await _choice_key("拟作封粮留验")
	await _new_site(ConsigneeRules.SOURCE)
	probe.hp = 1; probe.qi = 0; probe.attack = 1; probe.defense = 0; probe.medicine = 0
	var coins: int = probe.coins; await _choice_key("保存后阻止强提")
	var panel = game.overlay.get_meta("party_battle"); panel.set_process(false); panel.art.set_process(false)
	for step: int in range(20):
		if not probe.battle_active: break
		panel._process(1.0)
		if panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(not probe.battle_active and probe.consignee_stage == 2 and probe.consignee_ending.is_empty(),"Actual all-down scene cannot secure cargo or fix ending")
	_check(probe.hp == probe.max_hp and probe.qi >= 2 and probe.medicine == 0 and probe.coins == coins-mini(coins,8),"Actual defeat restores according to current rule and retains used resources")
	_check(game.world.player_pos.distance_to(game.world.interactables.heting_relief.pos)<75 and _modal_text().contains("西岸"),"Actual defeat scene returns to existing free-rest site")
	_assert_saved("actual defeat recovery")
