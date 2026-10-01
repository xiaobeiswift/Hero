extends SceneTree
## External PCK test driver: never bundled in the release PCK. Requires isolated XDG paths.
## The editor loads the exported PCK; release-template binaries do not support --script.
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Export smoke: " + message)

func _run() -> void:
	_check(FileAccess.file_exists("res://project.binary"), "Must load the exported binary project")
	_check(not DirAccess.dir_exists_absolute("res://tests"), "Test scripts excluded")
	_check(not DirAccess.dir_exists_absolute("res://tools"), "Build tools excluded")
	_check(not DirAccess.dir_exists_absolute("res://screenshots"), "Screenshots excluded")
	_check(not DirAccess.dir_exists_absolute("res://builds"), "Build outputs excluded")
	_check(FileAccess.file_exists("res://assets/fonts/LICENSE.txt"), "Font license retained")
	_check(FileAccess.file_exists("res://licenses/GODOT-LICENSE.txt"), "Engine license retained")
	_check(FileAccess.file_exists("res://licenses/GODOT-THIRD-PARTY-NOTICES.txt"), "Engine third-party notices retained")
	_check(ResourceLoader.exists("res://assets/fonts/NotoSansSC.otf"), "Chinese font retained")
	_check(ResourceLoader.exists("res://assets/generated/qingwei_ferry_title.png"), "Title artwork retained")
	_check(ResourceLoader.exists("res://assets/river_theme.wav"), "Music retained")
	var scene = load("res://scenes/main.tscn")
	_check(scene != null, "Packed main scene loads")
	if scene == null:
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.has_method("_new_game"), "Packed gameplay script loads")
	_check(game.current_screen == "title", "Release opens at title")
	game._new_game()
	_check(game.current_screen == "explore" and not game.active_modal, "New game enters exploration")
	game._interact("elder")
	_check(game.active_modal, "Dialogue opens")
	game._close_modal()
	game._show_inventory()
	_check(game.active_modal, "Inventory opens")
	game._close_modal()
	game._show_martials()
	_check(game.active_modal, "Martial arts panel opens")
	game._close_modal()
	game._show_map()
	_check(game.active_modal, "Map opens")
	game._close_modal()
	game._start_battle("story")
	_check(game.state.battle_active and game.current_screen == "battle", "Battle opens")
	game._battle_action("attack")
	_check(game.state.battle_active, "Battle turn resolves")
	game._battle_action("flee")
	_check(not game.state.battle_active and game.current_screen == "explore", "Retreat returns to exploration")
	game.state.quest_stage = 6
	game.state.choose_sect("听潮阁")
	game._travel("sluice", Vector2(190, 520))
	_check(game.state.map_id == "sluice", "Second region loads")
	_check(game.state.save_game() == OK, "Release writes isolated local save")
	_check(game.state.load_game() == OK, "Release reads isolated local save")
	game.state.side_stage=3
	game.state.side_choice="rescue"
	game.state.side_reward_claimed=true
	game.state.side_found.assign(["boatman","ledger"])
	game.state.side_clues=2
	_check(game.state.begin_chapter_two(), "Packed second chapter starts")
	game._travel("frostbridge",Vector2(190,500))
	_check(game.world.map_id=="frostbridge" and game.state.chapter_two_stage==1, "Third region and story load from PCK")
	_check(not game.world._can_walk(Vector2(835,800)), "Packed south bridge starts closed")
	_check(game.state.gather_resource("frost_timber").valid, "Packed resource gathering works")
	_check(game.state.repair_bridge(), "Packed bridge transaction works")
	game._sync_world_state()
	_check(game.world._can_walk(Vector2(835,800)), "Packed bridge repair changes collision")
	game._interact("chapter_clerk")
	_check(game.active_modal and game.modal_actions.size()==2, "Packed clerk dialogue opens")
	game.modal_actions[0].call()
	_check(game.state.archive_clues.has("clerk"), "Packed clerk choice records evidence")
	game._interact("chapter_inscription")
	game.modal_actions[0].call()
	_check(game.state.archive_clues.size()==2, "Packed inscription records second clue")
	game._interact("chapter_archive")
	_check(game.modal_actions.size()==4, "Packed seal controls appear")
	game.modal_actions[2].call()
	game.modal_actions[0].call()
	game.modal_actions[1].call()
	_check(game.state.chapter_two_stage==2, "Packed seal puzzle opens archive")
	game._close_modal()
	_check(game.state.save_game()==OK and game.state.load_game()==OK and game.state.bridge_repaired, "Packed schema2 chapter progress saves and reloads")
	# Keep the original 37 assertions above intact. All later checks use only
	# shipped resources; no test adapters or production classes are preloaded here.
	_test_modules()
	await _test_mentor_trials()
	await _test_companion_route("teach", false)
	await _test_companion_route("preserve", true)
	await _test_advanced_martials()
	await _test_mistwood()
	game.music.stop()
	game.sfx.stop()
	game.music.stream = null
	game.sfx.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	print("%s: %d exported-pack checks; %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _test_modules() -> void:
	for module in ["sect_rules", "sect_progress_ui", "companion_rules", "companion_story",
		"advanced_martial_rules", "advanced_martial_ui", "mistwood_rules", "mistwood_story", "mistwood_region", "battle_patterns"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "New packed module retained: " + module)
	_check(game.sect_progress != null and game.companion_story != null, "New packed story controllers instantiated")
	_check(game.advanced_martial != null and game.mist_story != null, "Advanced learning and Mistwood controllers instantiated")

func _test_mentor_trials() -> void:
	game._new_game()
	game._interact("mentor")
	_check(_find_button(game.overlay, "开始受试") == null, "Packed mentor gates unjoined hero")
	game._close_modal()
	for school in ["听潮阁", "照野堂", "问石门"]:
		game._new_game()
		game.state.gain_xp(180)
		game.state.choose_sect(school)
		game.state.quest_stage = 6
		game.state.ending = "守望"
		game.world.teleport(Vector2(650, 720))
		game._refresh()
		await _key(KEY_E)
		_press("开始受试")
		_check(game.state.battle_active and game.state.battle_kind == "sect_trial" and game.state.equipped_art == game.state.sect_art(), "Packed mentor starts and equips trial: " + school)
		_check(game.battle_title.text.contains("验"), "Packed trial displays mentor heading: " + school)
		game._battle_action("attack")
		game._battle_action("skill")
		for step in range(80):
			if not game.state.battle_active:
				break
			if game.state.hp < 45 and game.state.medicine > 0:
				game._battle_action("item")
			elif game.state.qi >= game.state.active_art_cost() and game.state.skill_cooldown == 0:
				game._battle_action("skill")
			elif game.state.turn % 2 == 1:
				game._battle_action("guard")
			else:
				game._battle_action("attack")
		_check(not game.state.battle_active and game.state.sect_trial_won and game.state.sect_rank == 1, "Packed battle earns unclaimed promotion: " + school)
		var proof: bool = game.state._trial_art_used if school == "听潮阁" else (game.state._trial_healing > 0 if school == "照野堂" else game.state._trial_guarded_heavy)
		_check(proof, "Packed trial requires actual school-specific evidence: " + school)
		_press("稍后领取")
		game._load()
		_check(game.state.sect_rank == 1 and game.state.sect_trial_won, "Packed earned promotion survives deferral and reload: " + school)
		_check(game.world._quest_target_id() == "mentor" and game.quest_label.text.contains("荐记"), "Packed pending promotion retains navigation: " + school)
		var defense: int = game.state.defense
		var qi: int = game.state.max_qi
		var merit: int = game.state.sect_merit
		game._interact("mentor")
		_press("领取内门荐记")
		_check(game.state.sect_rank == 2 and game.state.defense == defense + 1 and game.state.max_qi == qi + 1 and game.state.sect_merit == merit + 3, "Packed promotion grants exact permanent rewards: " + school)
		_check(game.sect_label.text.contains("内门"), "Packed character panel reflects promoted rank: " + school)
		var before: Dictionary = game.state.to_dict()
		game._interact("mentor")
		_check(_find_button(game.overlay, "开始受试") == null and _find_button(game.overlay, "领取内门荐记") == null, "Packed completed mentor cannot duplicate rewards: " + school)
		_press("研读武学")
		_check(_gather_text(game.overlay).contains("内门") and _gather_text(game.overlay).contains("考绩3"), "Packed martial panel displays rank and merit: " + school)
		game._close_modal()
		game._load()
		_check(game.state.to_dict() == before, "Packed promoted state persists without duplication: " + school)
	game._new_game()
	game.state.gain_xp(180)
	game.state.choose_sect("照野堂")
	game.state.attack = 999
	game._interact("mentor")
	_press("开始受试")
	for step in range(8):
		if not game.state.battle_active:
			break
		game._battle_action("attack")
	_check(not game.state.sect_trial_won and game.state.sect_rank == 1, "Packed brute-force victory does not earn rank")
	_press("再试一次")
	_check(game.state.battle_active and game.state.hp == game.state.max_hp, "Packed failed proof supports a restored retry")
	game._battle_action("flee")
	_check(not game.state.battle_active and not game.state.sect_trial_won and game.state.sect_rank == 1, "Packed retreat cannot promote")

func _prepare_companion_chapter(shen: bool, school: String = "听潮阁") -> void:
	game._new_game()
	var s = game.state
	s.quest_stage = 6
	s.ending = "守望"
	s.choose_sect(school)
	s.side_stage = 3
	s.side_choice = "rescue"
	s.side_reward_claimed = true
	s.side_found.assign(["boatman", "ledger"])
	s.side_clues = 2
	s.chapter_two_stage = 4
	s.chapter_two_ending = "protect_witness"
	s.archive_clues.assign(["clerk", "inscription"])
	s.seal_sequence.assign([2, 0, 1])
	s.bridge_repaired = true
	s.level = 5
	s.xp = 0
	if shen:
		s.recruit_companion()
	game._travel("frostbridge", Vector2(650, 760))
	game._process(0)
	game._refresh()

func _test_companion_route(choice: String, shen: bool) -> void:
	_prepare_companion_chapter(shen)
	game.state.chapter_two_stage = 3
	game._interact("bridge_worker")
	_check(_find_button(game.overlay, "去找旧工册") == null, "Packed personal quest requires chapter completion: " + choice)
	game._close_modal()
	game.state.chapter_two_stage = 4
	await _key(KEY_E)
	_press("以后再谈")
	_check(game.state.tangqi_stage == 0 and not game.active_modal, "Packed initial quest offer can be deferred: " + choice)
	await _key(KEY_E)
	_press("去找旧工册")
	game._load()
	_check(game.state.tangqi_stage == 1 and game.state.xp == 0 and game.world.map_id == "frostbridge", "Packed accepted quest saves without reward: " + choice)
	_check(game.world._quest_target_id() == "return_sluice", "Packed personal quest points back to sluice: " + choice)
	game._interact("return_sluice")
	_check(game.world.map_id == "sluice" and game.world._quest_target_id() == "sluice_cache", "Packed quest uses actual inter-region exit: " + choice)
	game.world.teleport(Vector2(570, 320))
	await _key(KEY_E)
	await _key(KEY_ESCAPE)
	_check(game.state.tangqi_stage == 1, "Packed notebook dismissal does not collect: " + choice)
	await _key(KEY_E)
	_press("收好工册")
	game._load()
	_check(game.state.tangqi_stage == 2 and game.world.map_id == "sluice", "Packed notebook collection persists: " + choice)
	game._interact("sluice_cache")
	_check(_find_button(game.overlay, "收好工册") == null and _find_button(game.overlay, "静坐调息") != null, "Packed notebook cannot be collected twice: " + choice)
	game._close_modal()
	game._interact("exit_frostbridge")
	_press("前往霜桥驿")
	game.world.teleport(Vector2(650, 760))
	await _key(KEY_E)
	_check(_find_button(game.overlay, "传给学徒") != null and _find_button(game.overlay, "留存原稿") != null, "Packed notebook offers both resolutions: " + choice)
	_press("再想想")
	game._load()
	_check(game.state.tangqi_stage == 2 and game.state.tangqi_choice == "", "Packed decision deferral remains unresolved after reload: " + choice)
	game._interact("bridge_worker")
	_press("传给学徒" if choice == "teach" else "留存原稿")
	_check(game.state.tangqi_stage == 3 and game.state.tangqi_choice == choice and game.state.xp == 50, "Packed personal quest grants exact one-time XP: " + choice)
	_check(game.state.resources.cloth == (2 if choice == "teach" else 0) and game.state.resources.iron == (2 if choice == "preserve" else 0), "Packed personal quest grants branch-specific materials: " + choice)
	_press("稍后再说")
	game._load()
	_check(not game.state.tangqi_unlocked and game.state.tangqi_stage == 3 and game.state.tangqi_choice == choice, "Packed recruitment deferral persists: " + choice)
	game._show_journal()
	_check(_gather_text(game.overlay).contains("尺上旧痕") and _gather_text(game.overlay).contains("邀请唐栖"), "Packed journal retains pending invitation: " + choice)
	game._close_modal()
	game._interact("bridge_worker")
	_press("邀请同行")
	game._load()
	await process_frame
	_check(game.state.tangqi_unlocked and game.state.current_companion() == "唐栖" and game.world.companion_active and game.world.companion_name == "唐栖", "Packed recruitment and follower identity survive reload: " + choice)
	var before: Dictionary = game.state.to_dict()
	game._interact("bridge_worker")
	_check(_find_button(game.overlay, "邀请同行") == null and _find_button(game.overlay, "传给学徒") == null, "Packed completed quest cannot replay rewards: " + choice)
	game._close_modal()
	_check(game.state.to_dict() == before, "Packed completed quest revisit is resource-neutral: " + choice)
	game._show_inventory()
	await _key(KEY_5)
	_check(_find_button(game.overlay, "与唐栖同行") != null and (_find_button(game.overlay, "与沈青同行") != null) == shen, "Packed roster contains only recruited companions: " + choice)
	_press("返回行囊")
	await _key(KEY_4)
	_check(not game.active_modal, "Packed original fourth inventory shortcut still closes: " + choice)
	game._travel("qingwei", Vector2(330, 330))
	game._process(0)
	_check(game.world.nearby_name == "沈青", "Packed inactive Shen remains at clinic: " + choice)
	if not shen:
		await _key(KEY_E)
		_press("邀请同行")
		_check(game.state.current_companion() == "唐栖" and game.state.available_companions() == ["沈青", "唐栖"], "Packed later Shen recruitment preserves active Tang")
	game._show_inventory()
	_press("切换阵型")
	await _key(KEY_5)
	var hp: int = game.state.hp
	var qi: int = game.state.qi
	_press("与沈青同行")
	game._process(0)
	await process_frame
	await process_frame
	_check(game.state.current_companion() == "沈青" and game.state.hp == hp and game.state.qi == qi, "Packed roster selection preserves resources: " + choice)
	_check(game.world.nearby_name == "药铺伙计" and game.near_label.text.contains("药铺伙计"), "Packed selection refreshes clinic prompt: " + choice)
	game._show_inventory()
	await _key(KEY_5)
	_press("与唐栖同行")
	game._save()
	game._load()
	game._process(0)
	await process_frame
	_check(game.state.current_companion() == "唐栖" and game.state.formation == "护后" and game.world.nearby_name == "沈青", "Packed selected companion, formation and clinic identity persist: " + choice)
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://hero_save.json"))
	_check(saved is Dictionary and saved.get("version") == 6 and saved.get("player", {}).get("active_companion") == "唐栖", "Packed save writes schema6 and active party identity: " + choice)
	game._show_inventory()
	_press("切换阵型")
	game._close_modal()
	game._start_battle("spar")
	game.state.enemy_hp = 1000
	game.state.enemy_max_hp = 1000
	game.state.hp = 1000
	game.state.max_hp = 1000
	game.state.qi = 0
	_check(game.battle_art.companion_active and game.battle_art.companion_name == "唐栖", "Packed combat art follows selected Tang: " + choice)
	await _key(KEY_I)
	_check(not game.active_modal and not game.state.select_companion("沈青") and game.state.current_companion() == "唐栖", "Packed combat locks roster and inventory: " + choice)
	game._battle_action("attack")
	game._battle_action("attack")
	_check(game.state.qi == 5 and game.state.battle_log.any(func(line): return line.contains("唐栖") and line.contains("4点伤害")), "Packed Tang support grants distinct damage and qi: " + choice)
	game._battle_action("flee")
	game._show_journal()
	_check(_gather_text(game.overlay).contains("工册已传给学徒" if choice == "teach" else "原稿与水令一同留存"), "Packed journal preserves personal quest ending: " + choice)
	game._close_modal()

func _test_advanced_martials() -> void:
	# Later-chapter prerequisites are seeded, but all six purchases, deed receipts,
	# equipment choices and transient effects run through shipped UI and rules.
	for school in ["听潮阁", "照野堂", "问石门"]:
		_prepare_companion_chapter(false, school)
		game.state.sect_trial_won = true
		game.state.complete_sect_trial()
		game._travel("qingwei", Vector2(650, 720))
		var arts = game.state.school_art_ids()
		_check(arts.size() == 4 and game.state.available_arts().size() == 2, "Packed school exposes two locked advanced pages: " + school)
		var cheap: String = arts[2]
		var costly: String = arts[3]
		var equipped: String = game.state.equipped_art
		await _key(KEY_E)
		_press("研习藏页")
		_check(_gather_text(game.overlay).contains(cheap) and _gather_text(game.overlay).contains(costly), "Packed learning menu identifies both advanced arts: " + school)
		_press("查看" + cheap)
		_check(game.state.learned_arts.is_empty() and game.state.sect_merit == 3, "Packed browsing does not purchase: " + school)
		_press("研习 · 2考绩")
		_check(game.state.learned_arts == [cheap] and game.state.sect_merit == 1 and game.state.equipped_art == equipped, "Packed first learning charges exactly two without auto-equipping: " + school)
		var before: Dictionary = game.state.to_dict()
		game.advanced_martial.learn(cheap)
		game.advanced_martial.learn(costly)
		_check(game.state.to_dict() == before, "Packed duplicate and unaffordable purchases leave state unchanged: " + school)
		_press("江湖复命")
		_press("复命·废闸水令查证")
		_press("复命·霜桥原账归处")
		_check(game.state.sect_merit == 3 and game.state.claimed_deeds == ["sluice", "archive"], "Packed two completed deeds each grant one merit: " + school)
		before = game.state.to_dict()
		game.advanced_martial.claim("archive")
		_check(game.state.to_dict() == before, "Packed deed callback cannot grant duplicate merit: " + school)
		_press("返回藏页")
		_press("查看" + costly)
		_press("研习 · 3考绩")
		_check(game.state.learned_arts == [cheap, costly] and game.state.sect_merit == 0 and game.state.equipped_art == equipped, "Packed second learning spends remaining three merit: " + school)
		await _key(KEY_ESCAPE)
		await _key(KEY_K)
		_check(game.modal_actions.size() == 5, "Packed martial panel fits four arts and close: " + school)
		await _key(KEY_4)
		_check(game.state.equipped_art == costly and not game.active_modal, "Packed fourth shortcut equips learned focus art: " + school)
		game._save()
		before = game.state.to_dict()
		game._load()
		_check(game.state.to_dict() == before, "Packed learned arts, deeds, equipment and merit persist: " + school)
		game.state.heal_rest()
		game._start_battle("spar")
		game.state.enemy_hp = 1000
		game.state.enemy_max_hp = 1000
		await _key(KEY_2)
		var focus: int = game.state.focused_damage
		_check(focus > 0 and game.battle_status.text.contains("蓄锋") and game.battle_status.text.contains(str(focus)), "Packed focus effect and displayed amount agree: " + school)
		await _key(KEY_K)
		game.advanced_martial.learning()
		_check(not game.active_modal and game.state.focused_damage == focus, "Packed battle blocks learning and equipment menus: " + school)
		await _key(KEY_3)
		_check(game.state.focused_damage == focus, "Packed guard preserves stored focus: " + school)
		await _key(KEY_1)
		_check(game.state.focused_damage == 0 and not game.battle_status.text.contains("蓄锋"), "Packed basic attack spends focus and clears status: " + school)
		game._battle_action("flee")
		game._close_modal()
		game.state.equip_art(cheap)
		game.state.heal_rest()
		game._start_battle("spar")
		game.state.enemy_hp = 1000
		game.state.enemy_max_hp = 1000
		await _key(KEY_2)
		_check(game.state.enemy_weaken_strikes == 1 and game.battle_status.text.contains("卸劲") and game.battle_status.text.contains(str(game.state.enemy_weaken_amount)), "Packed first incoming strike consumes one weaken charge: " + school)
		await _key(KEY_3)
		_check(game.state.enemy_weaken_strikes == 0 and not game.battle_status.text.contains("卸劲"), "Packed second incoming strike clears weaken: " + school)
		game._battle_action("flee")
		game._close_modal()
		_check(game.state.enemy_weaken_amount == 0 and game.state.focused_damage == 0, "Packed encounter exit clears transient effects: " + school)

func _test_mistwood() -> void:
	_prepare_companion_chapter(false, "问石门")
	game.state.level = 1
	game.state.gain_xp(600)
	game.state.equip_art(game.state.sect_art())
	game._travel("frostbridge", Vector2(1450, 220))
	game.state.chapter_two_stage = 3
	await _talk("exit_mistwood")
	_check(_find_button(game.overlay, "走入雾竹坡") == null, "Packed Mistwood entry requires completed prior chapter")
	game._close_modal()
	game.state.chapter_two_stage = 4
	await _talk("exit_mistwood")
	_press("走入雾竹坡")
	_check(game.state.map_id == "mistwood" and game.world.map_id == "mistwood" and game.state.mist_stage == 1, "Packed entrance opens fourth region and third chapter")
	_check(game.region_header.text.contains("雾竹坡") and game.chapter_header.text.contains("第三章"), "Packed fourth-region heading and chapter agree")
	_check(game.world.interactables.size() == 8 and not game.world._can_walk(Vector2(277, 242)), "Packed vector region contains eight landmarks and solid pond collision")
	await _key(KEY_M)
	var chart := _find_chart(game.overlay)
	_check(chart != null and chart.map_id == "mistwood" and chart.markers.size() == 8 and chart.current_target == "mist_rain_gauge", "Packed map chart loads fourth geography and current objective")
	await _key(KEY_ESCAPE)
	await _talk("mist_stone_gauge")
	_check(_find_button(game.overlay, "拓下读数") == null, "Packed stone gauge requires patrol permission")
	game._close_modal()
	for id in ["mist_rain_gauge", "mist_basin"]:
		await _talk(id)
		_press("拓下读数")
	game._load()
	_check(game.state.mist_gauges.size() == 2 and game.world.map_id == "mistwood" and game.world._quest_target_id() == "mist_scout", "Packed readings autosave and navigation advances to patrol")
	await _talk("mist_scout")
	var before: Dictionary = game.state.to_dict()
	_press("修亭 · 木1布1")
	_check(game.state.to_dict() == before and game.active_modal, "Packed insufficient repair materials cause no partial payment")
	game.state.buy_material("timber")
	game.state.buy_material("cloth")
	_press("修亭 · 木1布1")
	_check(game.state.mist_approach == "repair" and game.state.resources.timber == 0 and game.state.resources.cloth == 0, "Packed repair permission consumes exactly one timber and cloth")
	game._load()
	_check(game.state.mist_approach == "repair", "Packed patrol permission persists")
	before = game.state.to_dict()
	await _talk("mist_scout")
	_check(_find_button(game.overlay, "较量过关") == null and game.state.to_dict() == before, "Packed completed patrol cannot replay costs or rewards")
	game._close_modal()
	await _talk("mist_stone_gauge")
	_press("拓下读数")
	game._load()
	_check(game.state.mist_stage == 2 and game.state.mist_gauges.size() == 3 and game.world._quest_target_id() == "mist_gate", "Packed final reading unlocks and targets keeper after reload")
	await _talk("mist_camp")
	_press("避雨调息")
	_check(game.state.hp == game.state.max_hp and game.state.qi == game.state.max_qi, "Packed camp restores both resources without payment")
	await _talk("mist_gate")
	_press("请他交出底稿")
	_check(game.state.battle_active and game.state.battle_kind == "mist_keeper" and game.state.enemy_intent.contains("受击减半"), "Packed keeper starts in guarded phase with explicit intent")
	var enemy_hp: int = game.state.enemy_hp
	game._battle_action("attack")
	_check(enemy_hp - game.state.enemy_hp == int(ceil(game.state.attack * 0.5)) and game.battle_info.text.contains("重击"), "Packed guarded phase halves actual damage and advertises heavy follow-up")
	game._battle_action("guard")
	_check(game.state.exposed_turns == 0 and game.battle_info.text.contains("+8"), "Packed defending heavy avoids exposure and reveals opening")
	enemy_hp = game.state.enemy_hp
	game._battle_action("attack")
	_check(enemy_hp - game.state.enemy_hp == game.state.attack + 8, "Packed recovery phase adds eight to actual player damage")
	game._battle_action("flee")
	game._close_modal()
	game._load()
	_check(game.state.mist_stage == 2, "Packed keeper retreat and reload keep encounter retryable")
	await _talk("mist_camp")
	_press("避雨调息")
	await _talk("mist_gate")
	_press("请他交出底稿")
	for step in range(120):
		if not game.state.battle_active:
			break
		if game.state.hp < 45 and game.state.medicine > 0:
			game._battle_action("item")
		elif game.state.Patterns.phase(game.state.battle_kind, game.state.turn).heavy:
			game._battle_action("guard")
		elif game.state.qi >= game.state.active_art_cost() and game.state.skill_cooldown == 0:
			game._battle_action("skill")
		else:
			game._battle_action("attack")
	_check(not game.state.battle_active and game.state.enemy_hp == 0 and game.state.mist_stage == 3 and _gather_text(game.overlay).contains("底稿"), "Packed phased keeper is winnable and grants story evidence")
	await _key(KEY_ESCAPE)
	game._load()
	_check(game.state.mist_stage == 3 and game.world._quest_target_id() == "mist_guide", "Packed victory evidence autosaves and points back to guide")
	await _talk("mist_guide")
	var coins: int = game.state.coins
	var cloth: int = game.state.resources.cloth
	_press("先鸣渡船钟")
	_check(game.state.mist_stage == 4 and game.state.mist_ending == "warn_ferries" and game.state.coins == coins + 60 and game.state.resources.cloth == cloth + 2, "Packed third chapter resolves one ending with exact currency and branch reward")
	before = game.state.to_dict()
	await _talk("mist_guide")
	_check(_find_button(game.overlay, "先鸣渡船钟") == null and game.state.to_dict() == before, "Packed completed ending cannot replay rewards")
	game._close_modal()
	await _key(KEY_J)
	_check(_gather_text(game.overlay).contains("听雨辨令") and _gather_text(game.overlay).contains("先鸣渡船钟"), "Packed journal records third chapter and chosen ending")
	await _key(KEY_ESCAPE)
	game._save()
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://hero_save.json"))
	_check(saved is Dictionary and saved.get("version") == 6 and saved.get("player", {}).get("mist_ending") == "warn_ferries", "Packed local save writes schema6 and Mistwood ending")
	before = game.state.to_dict()
	game._load()
	_check(game.state.to_dict() == before and game.world.map_id == "mistwood", "Packed complete Mistwood state round-trips locally")
	game.state.position = Vector2(277, 242)
	game.state.save_game()
	game._load()
	_check(game.world._can_walk(game.world.player_pos), "Packed reload repairs unsafe pond spawn")
	await _talk("return_frostbridge")
	_check(game.world.map_id == "frostbridge" and game.state.mist_stage == 4 and game.state.mist_ending == "warn_ferries", "Packed return exit preserves third-chapter completion")

func _talk(id: String) -> void:
	if game.active_modal:
		game._close_modal()
	game.world.teleport(game.world.interactables[id].pos)
	await _key(KEY_E)

func _find_chart(node: Node) -> Control:
	if node.get_script() == load("res://scripts/map_chart.gd"):
		return node
	for child in node.get_children():
		var chart := _find_chart(child)
		if chart != null:
			return chart
	return null

func _press(text: String) -> void:
	var button := _find_button(game.overlay, text)
	_check(button != null, "Packed dialogue button exists: " + text)
	if button != null:
		button.pressed.emit()

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var button := _find_button(child, text)
		if button != null:
			return button
	return null

func _gather_text(node: Node) -> String:
	var result := ""
	if node is Label or node is RichTextLabel:
		result += node.text
	for child in node.get_children():
		result += _gather_text(child)
	return result

func _key(key: Key) -> void:
	game._process(0)
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
