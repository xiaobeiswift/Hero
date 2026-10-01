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
	# Fail closed before instantiating gameplay or reading/writing any user data.
	# export_desktop.py creates a fresh platform-specific directory for every label.
	var data_root := OS.get_environment("XDG_DATA_HOME").simplify_path()
	var user_root := ProjectSettings.globalize_path("user://").simplify_path()
	var isolated := data_root.is_absolute_path() and data_root.get_file().ends_with("-smoke-data") and user_root.begins_with(data_root + "/")
	_check(isolated, "PCK audit requires build-owned isolated writable storage")
	if not isolated:
		quit(1)
		return
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
	await _test_manual_slots()
	await _test_portraits()
	print("Retained exported-pack coverage: %d checks" % checks)
	_test_story_traversal_modules()
	await _test_shen_care_route("shore", "rescue", "守望")
	await _test_shen_care_route("mobile", "pursuit", "秉公")
	await _test_lightness_exploration()
	print("Retained story/traversal pack coverage: %d checks"%checks)
	await _test_visual_runtime()
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
	_check(saved is Dictionary and saved.get("version") == 9 and saved.get("player", {}).get("active_companion") == "唐栖", "Packed save writes schema9 and active party identity: " + choice)
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
	_check(saved is Dictionary and saved.get("version") == 9 and saved.get("player", {}).get("mist_ending") == "warn_ferries", "Packed local save writes schema9 and Mistwood ending")
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

func _test_manual_slots() -> void:
	for module in ["local_save_slots", "save_slots_ui", "character_portraits"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "Packed save/portrait module retained: " + module)
	_check(game.save_slots != null and game.save_slots.store != null, "Packed manual-save controller and store instantiated")
	game._new_game()
	var store = game.save_slots.store
	_check(not store.has_manual_saves(), "Fresh isolated pack audit has no pre-existing manual saves")
	_check(store.path_for(0) == "user://hero_save.json", "Packed slot zero points to the existing autosave")
	for id in [1, 2, 3]:
		_check(store.path_for(id) == "user://hero_slot_%d.json" % id and store.describe(id).status == "empty", "Packed manual slot starts empty at its own path: %d" % id)
	_check(store.save_slot(game.state, 0) == ERR_INVALID_PARAMETER, "Packed manual-save API cannot overwrite autosave")
	_check(store.path_for("../escape").is_empty() and store.save_slot(game.state, 4) == ERR_INVALID_PARAMETER, "Packed invalid slot IDs cannot address other paths")
	_check(_find_button(game, "存卷  F6") != null and _find_button(game, "读卷  F10") != null, "Packed HUD save and load buttons are discoverable")
	await _key(KEY_F6)
	_check(game.active_modal and game.modal_actions.size() == 4 and _gather_text(game.overlay).contains("手记三"), "Packed F6 opens all three manual slots and return")
	await _key(KEY_1)
	_check(store.describe(1).status == "valid" and game.status_label.text.contains("已写下"), "Packed empty slot saves through actual keyboard UI")
	var first: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(1))
	var first_doc = JSON.parse_string(first.get_string_from_utf8())
	_check(first_doc is Dictionary and first_doc.get("version") == 9 and first_doc.player.coins == 24, "Packed manual save writes the current schema and branch")
	_check(not FileAccess.file_exists(store.path_for(1) + ".bak"), "Packed first save creates no spurious backup")
	_check(store.describe(1).level == game.state.level and store.describe(1).location == "qingwei" and store.describe(1).modified > 0, "Packed slot preview reports validated level, location and timestamp")
	game.state.coins = 55
	await _key(KEY_1)
	_check(_find_button(game.overlay, "确认重写") != null and _gather_text(game.overlay).contains("备份"), "Packed occupied slot requires informed overwrite confirmation")
	var stale_save: Callable = game.modal_actions[0]
	await _key(KEY_2)
	stale_save.call()
	_check(FileAccess.get_file_as_bytes(store.path_for(1)) == first and not FileAccess.file_exists(store.path_for(1) + ".bak"), "Packed cancelled and stale overwrite cannot change files")
	await _key(KEY_1)
	var used_save: Callable = game.modal_actions[0]
	await _key(KEY_ENTER)
	_check(FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == first, "Packed confirmed overwrite preserves exact preceding bytes")
	var primary: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(1))
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(1) + ".bak")
	_check(JSON.parse_string(primary.get_string_from_utf8()).player.coins == 55 and primary != first, "Packed overwrite writes the changed branch")
	used_save.call()
	_check(FileAccess.get_file_as_bytes(store.path_for(1)) == primary and FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == backup, "Packed repeated confirmation cannot rotate meaningful backup")
	_check(store.save_slot(game.state, 1) == OK and FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == backup, "Packed identical manual save is a backup-preserving no-op")
	await _key(KEY_ESCAPE)
	await _key(KEY_F10)
	_check(game.active_modal and game.modal_actions.size() == 5 and _gather_text(game.overlay).contains("自动续写"), "Packed F10 lists autosave, three manual slots and return")
	await _key(KEY_2)
	_check(_find_button(game.overlay, "读取当前版本") != null and _find_button(game.overlay, "读取备份") != null, "Packed slot detail exposes primary and validated backup")
	await _key(KEY_2)
	_check(_gather_text(game.overlay).contains("替换当前内存") and _gather_text(game.overlay).contains("更新自动存档"), "Packed load confirmation explains replacement and autosave update")
	var stale_load: Callable = game.modal_actions[0]
	await _key(KEY_2)
	stale_load.call()
	_check(game.state.coins == 55 and FileAccess.get_file_as_bytes(store.path_for(1)) == primary, "Packed cancelled and stale load leave the branch unchanged")
	game.state.coins = 99
	_press("读取当前版本")
	_press("确认读取")
	_check(game.state.coins == 55 and game.current_screen == "explore" and not game.active_modal, "Packed confirmed primary load restores exploration")
	_check(JSON.parse_string(FileAccess.get_file_as_string(store.path_for(0))).player.coins == 55, "Packed manual load refreshes autosave with restored branch")
	await _key(KEY_F10)
	await _key(KEY_2)
	_press("读取备份")
	_press("确认读取")
	_check(game.state.coins == 24 and game.world.map_id == "qingwei", "Packed backup UI restores the preceding branch")
	_check(FileAccess.get_file_as_bytes(store.path_for(1)) == primary and FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == backup, "Packed primary and backup reads do not rewrite manual files")
	_check(JSON.parse_string(FileAccess.get_file_as_string(store.path_for(0))).player.coins == 24, "Packed backup recovery updates quick-continue autosave")
	# Later-region prerequisites are fixtures; all file and UI work uses shipped scripts.
	_prepare_companion_chapter(false, "问石门")
	game.state.begin_mistwood()
	game.state.record_mist_gauge("rain")
	game._travel("mistwood", Vector2(410, 425))
	await _key(KEY_F6)
	await _key(KEY_2)
	_check(store.describe(2).status == "valid" and store.describe(2).location == "mistwood", "Packed second slot holds an independent fourth-region branch")
	_check(_gather_text(game.overlay).contains("雾竹坡") and _gather_text(game.overlay).contains("UTC"), "Packed preview translates location and labels timestamp zone")
	var second: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(2))
	await _key(KEY_ESCAPE)
	game.state.coins = 83
	await _key(KEY_F6)
	await _key(KEY_3)
	_check(store.describe(3).status == "valid" and JSON.parse_string(FileAccess.get_file_as_string(store.path_for(3))).player.coins == 83, "Packed third slot stores a distinct branch through UI")
	var third: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(3))
	_check(FileAccess.get_file_as_bytes(store.path_for(1)) == primary and FileAccess.get_file_as_bytes(store.path_for(2)) == second, "Packed third-slot write preserves both other primaries")
	game._show_title()
	_press("踏入江湖")
	_check(_gather_text(game.overlay).contains("手动手记不会删除"), "Packed new-game confirmation explains manual-save preservation")
	_press("确认新旅程")
	_check(game.state.quest_stage == 0 and FileAccess.get_file_as_bytes(store.path_for(1)) == primary and FileAccess.get_file_as_bytes(store.path_for(2)) == second and FileAccess.get_file_as_bytes(store.path_for(3)) == third, "Packed new game preserves all three manual branches")
	# The isolation preflight makes this audit-owned autosave safe to remove.
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path_for(0))) == OK, "Packed audit removes only its isolated autosave for title-discovery test")
	game._show_title()
	_check(_find_button(game.overlay, "续写前缘") == null and _find_button(game.overlay, "查阅手记") != null, "Packed title discovers manual saves without any autosave")
	_press("查阅手记")
	await _key(KEY_3)
	_press("读取当前版本")
	_press("确认读取")
	_check(game.current_screen == "explore" and game.world.map_id == "mistwood" and game.state.mist_gauges.has("rain"), "Packed title load restores actual map and chapter progress")
	_check(game.world._can_walk(game.world.player_pos), "Packed manual restore uses common safe-position recovery")
	var corrupt := FileAccess.open(store.path_for(1), FileAccess.WRITE)
	corrupt.store_string("{bad")
	corrupt.close()
	await _key(KEY_F10)
	await _key(KEY_2)
	_check(store.describe(1).status == "corrupt" and _find_button(game.overlay, "读取当前版本") == null and _find_button(game.overlay, "读取备份") != null, "Packed damaged primary is disabled while valid backup stays selectable")
	var before: Dictionary = game.state.to_dict()
	game.save_slots.perform_load(1, false)
	_check(game.state.to_dict() == before and game.status_label.text.contains("未改变"), "Packed failed primary load preserves active branch and explains failure")
	_press("读取备份")
	_press("确认读取")
	_check(game.state.coins == 24 and game.world.map_id == "qingwei", "Packed valid backup recovers from corrupt primary through confirmation UI")
	_check(FileAccess.get_file_as_string(store.path_for(1)) == "{bad" and FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == backup, "Packed recovery preserves damaged primary and exact good backup")
	game.state.coins = 77
	await _key(KEY_F6)
	await _key(KEY_1)
	_press("确认重写")
	_check(store.describe(1).status == "valid" and FileAccess.get_file_as_bytes(store.path_for(1) + ".bak") == backup, "Packed replacing corrupt primary preserves existing recovery copy")
	var blocked: String = store.path_for(2) + ".bak.tmp"
	_check(DirAccess.make_dir_recursive_absolute(blocked) == OK, "Packed audit creates an isolated backup-failure fixture")
	await _key(KEY_2)
	_press("确认重写")
	_check(FileAccess.get_file_as_bytes(store.path_for(2)) == second and game.status_label.text.contains("未能保存"), "Packed backup-write failure remains visible and preserves primary")
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked)) == OK, "Packed audit releases only its backup-failure fixture")
	await _key(KEY_ESCAPE)
	game.state.coins = 91
	await _key(KEY_F5)
	game.state.coins = 92
	await _key(KEY_F9)
	_check(game.state.coins == 91, "Packed F5 and F9 retain quick-autosave compatibility")
	_check(FileAccess.get_file_as_bytes(store.path_for(2)) == second and FileAccess.get_file_as_bytes(store.path_for(3)) == third, "Packed quick save/load never rewrites independent manual slots")
	game._start_battle("spar")
	var battle_state: Dictionary = game.state.to_dict()
	var battle_files := _manual_file_snapshot(store)
	await _key(KEY_F6)
	await _key(KEY_F10)
	_check(game.state.battle_active and game.current_screen == "battle" and not game.active_modal, "Packed manual shortcuts are blocked in combat")
	game.save_slots.save_page()
	game.save_slots.load_page()
	game.save_slots.detail(1)
	game.save_slots.request_save(1)
	game.save_slots.request_load(1, false)
	game.save_slots.perform_save(1)
	game.save_slots.perform_load(1, true)
	_check(not game.active_modal and game.state.to_dict() == battle_state, "Packed direct slot UI entry points cannot change combat state")
	_check(store.save_slot(game.state, 1) == ERR_BUSY and store.load_slot(game.state, 1) == ERR_BUSY and store.load_backup(game.state, 1) == ERR_BUSY, "Packed storage API blocks battle saves, primary loads and backups")
	_check(_manual_file_snapshot(store) == battle_files, "Packed blocked battle actions leave all primary and backup bytes unchanged")
	game._battle_action("flee")
	game._close_modal()

func _manual_file_snapshot(store) -> Dictionary:
	var result := {}
	for id in [0, 1, 2, 3]:
		for suffix in ["", ".bak"]:
			var path: String = store.path_for(id) + suffix
			result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result

func _test_portraits() -> void:
	const ATLAS_PATH := "res://assets/generated/characters/hero-character-portraits-atlas.png"
	const PROVENANCE_PATH := "res://assets/generated/characters/ART_PROVENANCE.md"
	_check(ResourceLoader.exists(ATLAS_PATH), "Packed original character atlas retained")
	_check(FileAccess.file_exists(PROVENANCE_PATH), "Packed original portrait provenance retained")
	var provenance := FileAccess.get_file_as_string(PROVENANCE_PATH)
	_check(provenance.contains("1254") and provenance.contains("627") and provenance.contains("OpenAI") and provenance.contains("Top-left"), "Packed portrait provenance is readable with generation method and cell layout")
	var portraits = load("res://scripts/character_portraits.gd")
	var atlas = load(ATLAS_PATH)
	_check(atlas is Texture2D and atlas.get_size() == Vector2(1254, 1254), "Packed portrait atlas preserves original resolution")
	var cells := {"hero": Vector2(0, 0), "shen": Vector2(627, 0), "tang": Vector2(0, 627), "qin": Vector2(627, 627)}
	for id in cells:
		var texture = portraits.texture_for(id)
		_check(texture is AtlasTexture and texture.region == Rect2(cells[id], Vector2(627, 627)), "Packed portrait uses correct exact quadrant: " + id)
		_check(texture.atlas == atlas and texture.filter_clip, "Packed portrait shares atlas and clips texture sampling: " + id)
	_check(portraits.texture_for("unknown") == null and portraits.id_for_title("药铺伙计").is_empty(), "Packed unknown characters safely omit portraits")
	# Validate actual shipped pixels at both cuts, not only declared crop geometry.
	var pixels: Image = atlas.get_image()
	if pixels != null and pixels.is_compressed():
		pixels.decompress()
	_check(pixels != null and not pixels.is_empty() and not pixels.is_compressed() and pixels.detect_alpha() != Image.ALPHA_NONE, "Packed atlas retains readable transparent pixels")
	if pixels != null and not pixels.is_empty() and not pixels.is_compressed():
		var clear_cuts := true
		for index in range(1254):
			for edge in [626, 627]:
				clear_cuts = clear_cuts and pixels.get_pixel(index, edge).a <= 8.0 / 255.0 and pixels.get_pixel(edge, index).a <= 8.0 / 255.0
		_check(clear_cuts, "Packed meaningful portrait pixels do not cross either atlas cut")
	else:
		_check(false, "Packed meaningful portrait pixels do not cross either atlas cut")
	var hero = game.find_child("Portrait_hero", true, false)
	_check(hero is TextureRect and hero.texture is AtlasTexture and not game.portrait.visible, "Packed hero card uses original portrait instead of fallback glyph")
	_check(hero.mouse_filter == Control.MOUSE_FILTER_IGNORE and hero.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Packed hero portrait preserves aspect and never intercepts mouse input")
	for pair in [["沈青 · 药师", "shen"], ["唐栖 · 修桥匠", "tang"], ["秦禾 · 旧监水吏", "qin"]]:
		_check(portraits.id_for_title(pair[0]) == pair[1], "Packed dialogue title selects correct portrait: " + pair[1])
		for wide in [false, true]:
			game._modal(pair[0], "Export portrait audit", "Packed dialogue remains usable", [["继续", game._close_modal]], wide)
			var node = game.overlay.find_child("Portrait_" + pair[1], true, false)
			_check(node is TextureRect and node.texture.region == Rect2(cells[pair[1]], Vector2(627, 627)) and node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Packed dialogue attaches correct non-intercepting portrait: %s wide=%s" % [pair[1], wide])
			_check(node.position.x >= 500 and node.position.y + node.size.y <= 120 and node.position.x + node.size.x <= node.get_parent().size.x, "Packed portrait stays inside header and outside dialogue body: %s wide=%s" % [pair[1], wide])
			await _key(KEY_ENTER)
			_check(not game.active_modal, "Packed portrait allows actual dialogue input: %s wide=%s" % [pair[1], wide])
	game._show_inventory()
	_check(game.overlay.find_child("Portrait_shen", true, false) == null and game.overlay.find_child("Portrait_tang", true, false) == null and game.overlay.find_child("Portrait_qin", true, false) == null, "Packed generic inventory never misidentifies a character")
	game._close_modal()


func _test_story_traversal_modules() -> void:
	for module in ["shen_care_rules", "shen_care_story", "lightness_rules", "lightness_story", "reed_islet"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "Packed personal story and exploration module retained: " + module)
	_check(game.shen_story != null and game.lightness_story != null, "Packed personal story and lightness controllers instantiate")

func _test_shen_care_route(choice: String, earlier: String, ending: String) -> void:
	# Seed completed older chapters only. Every new story transition is made through
	# the shipped scene, its actual buttons, and normal isolated save/load paths.
	_prepare_companion_chapter(true)
	game.state.side_choice = earlier
	game.state.ending = ending
	game._travel("qingwei", Vector2(330, 365))
	game.companion_story.roster()
	_press("沈青的近况")
	_check(game.state.shen_care_stage == 0 and _gather_text(game.overlay).contains("青苇药铺"), "Packed roster gives a location hint without remotely starting care: " + choice)
	await _talk("healer")
	_check(_find_button(game.overlay, "免费调息") != null and _find_button(game.overlay, "买药 · 12 文") != null, "Packed care story preserves normal healer services: " + choice)
	_press("药箱之外")
	_check(_gather_text(game.overlay).contains("可以行走") and _gather_text(game.overlay).contains("不用另买"), "Packed personal story presents its stakes and free investigation: " + choice)
	var stale_accept: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	stale_accept.call()
	_check(game.state.shen_care_stage == 0 and not game.active_modal, "Packed dismissed care acceptance cannot be replayed: " + choice)
	await _talk("healer")
	_press("药箱之外")
	_press("去问问他的近况")
	game._load()
	_check(game.state.shen_care_stage == 1 and game.world._quest_target_id() == "exit_sluice" and game.state.xp == 0, "Packed accepted care inquiry autosaves and targets its actual exit: " + choice)
	await _talk("exit_sluice")
	_press("前往废闸")
	_check(game.world.map_id == "sluice" and game.world._quest_target_id() == "stranded_boatman", "Packed care inquiry travels via the real region exit: " + choice)
	await _talk("stranded_boatman")
	_check(_gather_text(game.overlay).contains("先割断" if earlier == "rescue" else "不是补证言"), "Packed patient remembers the earlier rescue or pursuit: " + choice)
	_press("再听水令旧事")
	_check(game.state.shen_care_stage == 1 and _gather_text(game.overlay).contains("逆流时入港"), "Packed old testimony remains accessible without care progression: " + choice)
	_press("谈谈近况")
	_press("记下他的难处")
	game._load()
	_check(game.state.shen_care_stage == 2 and game.world._quest_target_id() == "sluice_cache", "Packed consultation saves and points to the existing shelter: " + choice)
	await _talk("sluice_cache")
	game.state.hp = 1
	_press("在此免费调息")
	_check(game.state.hp == game.state.max_hp and game.state.shen_care_stage == 2 and game.state.coins == 24, "Packed shelter rest remains free and does not perform inspection: " + choice)
	await _talk("sluice_cache")
	_press("记下药棚情形")
	game._load()
	_check(game.state.shen_care_stage == 3 and game.world._quest_target_id() == "return_village", "Packed shelter inspection autosaves and points home: " + choice)
	await _talk("return_village")
	_check(game.world.map_id == "qingwei" and game.world._quest_target_id() == "healer", "Packed return exit leads care inquiry back to pharmacy: " + choice)
	await _talk("healer")
	_press("药箱之外")
	_check(_gather_text(game.overlay).contains("远埠仍须等靠岸") and _gather_text(game.overlay).contains("暂缺固定照看"), "Packed care decision explains both finite volunteer allocations: " + choice)
	_press("随船问诊" if choice == "shore" else "留岸照护")
	_check(game.state.shen_care_stage == 4 and game.state.ShenCare.shore_bonus(game.state) == 0 and game.state.ShenCare.mobile_heal(game.state) == 0, "Packed unposted care draft grants neither combat benefit: " + choice)
	_press("重新商议")
	_press("留岸照护" if choice == "shore" else "随船问诊")
	_check(game.state.shen_care_choice == choice and game.state.xp == 0 and game.state.coins == 24, "Packed care draft can be revised without rewards or payment: " + choice)
	var draft: Dictionary = game.state.to_dict()
	var draft_bytes: PackedByteArray = FileAccess.get_file_as_bytes("user://hero_save.json")
	_press("重新商议")
	_press("留岸照护" if choice == "shore" else "随船问诊")
	_check(game.active_modal and _gather_text(game.overlay).contains("未贴出的照护约") and _find_button(game.overlay, "带去告示牌") != null, "Packed reaffirming the same draft returns to its review page: " + choice)
	_check(game.state.to_dict() == draft and FileAccess.get_file_as_bytes("user://hero_save.json") == draft_bytes, "Packed same-draft reaffirmation repeats no mutation or save write: " + choice)
	_press("带去告示牌")
	game._load()
	_check(game.state.shen_care_stage == 4 and game.state.shen_care_choice == choice and game.world._quest_target_id() == "board" and game.quest_label.text == "药箱之外", "Packed chosen draft and matching HUD objective survive reload: " + choice)
	await _talk("board")
	_check(_gather_text(game.overlay).contains("抄过账页" if ending == "守望" else "县衙收账"), "Packed notice sponsor respects the earlier main ending: " + choice)
	_check(_gather_text(game.overlay).contains("不张贴病人的姓名") and _gather_text(game.overlay).contains("不再改换"), "Packed notice confirmation explains privacy and final commitment: " + choice)
	_press("看看原告示")
	_check(_gather_text(game.overlay).contains("点灯不收借火钱") and game.state.shen_care_stage == 4, "Packed old board is readable without posting the care plan: " + choice)
	_press("查看照护约")
	var stale_post: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	stale_post.call()
	_check(game.state.shen_care_stage == 4 and game.state.xp == 0, "Packed cancelled posting callback cannot finalize a plan: " + choice)
	await _talk("board")
	await _key(KEY_ENTER)
	_check(game.state.shen_care_stage == 5 and game.state.shen_care_choice == choice and game.state.xp == 40 and game.state.coins == 24, "Packed real notice confirmation grants exactly forty XP once: " + choice)
	_check(_gather_text(game.overlay).contains("他的恢复还没有结束"), "Packed resolution retains the patient's continuing recovery: " + choice)
	await _key(KEY_ESCAPE)
	var completed: Dictionary = game.state.to_dict()
	game._load()
	_check(game.state.to_dict() == completed, "Packed finalized care state round-trips exactly: " + choice)
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://hero_save.json"))
	_check(saved is Dictionary and saved.get("version") == 9 and saved.player.shen_care_stage == 5 and saved.player.shen_care_choice == choice, "Packed schema9 document records the final care plan: " + choice)
	stale_post.call()
	game.shen_story.post()
	game.shen_story.choose("mobile" if choice == "shore" else "shore")
	_check(game.state.to_dict() == completed, "Packed completed care plan cannot replay reward or change branch: " + choice)
	await _talk("board")
	_check(_gather_text(game.overlay).contains("照护约") and _gather_text(game.overlay).contains("留岸照护" if choice == "shore" else "随船问诊"), "Packed board shows lasting branch-specific aftermath after reload: " + choice)
	await _talk("healer")
	_press("药箱之外")
	_check(_gather_text(game.overlay).contains("仍有未尽之事") and _gather_text(game.overlay).contains("药棚有人照看" if choice == "shore" else "短渡把问候带远"), "Packed Shen remembers the completed care allocation: " + choice)
	await _talk("exit_sluice")
	_press("前往废闸")
	await _talk("stranded_boatman")
	_check(_gather_text(game.overlay).contains("记轮值" if choice == "shore" else "远处的人"), "Packed patient has a distinct persistent aftermath: " + choice)
	await _talk("sluice_cache")
	_check(_gather_text(game.overlay).contains("轮值纸" if choice == "shore" else "短渡停泊"), "Packed shelter reflects the same saved care choice: " + choice)
	await _key(KEY_ESCAPE)
	await _key(KEY_J)
	_check(_gather_text(game.overlay).contains("药箱之外") and _gather_text(game.overlay).contains("✓ 把照护约"), "Packed journal marks the personal story complete: " + choice)
	game._close_modal()
	game.companion_story.roster()
	_check(_gather_text(game.overlay).contains("减伤3" if choice == "shore" else "恢复2气血"), "Packed roster explains the actual new support benefit: " + choice)
	game._close_modal()
	_check(game.state.xp == 40 and game.state.coins == 24 and game.state.resources == completed.resources, "Packed aftermath revisits preserve one-time rewards and materials: " + choice)
	# Check benefits through actual battle turns, not direct support helper calls.
	game.state.set_formation("护后" if choice == "shore" else "并肩")
	game.state.hp = 70
	game._start_battle("sluice_boss")
	_check(game.state.battle_active and game.battle_art.companion_name == "沈青", "Packed completed care benefit enters real Shen combat: " + choice)
	var hp: int = game.state.hp
	var normal_hit: int = maxi(1, game.state.enemy_base_attack - game.state.defense - (3 if choice == "shore" else 0))
	game._battle_action("attack")
	_check(game.state.hp == hp - normal_hit, "Packed first strike applies exactly the chosen passive and no early heal: " + choice)
	hp = game.state.hp
	var strong_hit: int = maxi(1, game.state.enemy_strong_attack - game.state.defense - (3 if choice == "shore" else 0))
	game._battle_action("attack")
	_check(game.state.hp == hp - strong_hit + (2 if choice == "mobile" else 0), "Packed second strike applies exact three-point cover or two-point assist healing: " + choice)
	_check(game.state.battle_log.any(func(line): return line.contains("分担 3 点伤害" if choice == "shore" else "恢复2点气血")), "Packed combat log agrees with the care benefit: " + choice)
	var combat_before: Dictionary = game.state.to_dict()
	game._battle_action("invalid")
	_check(game.state.to_dict() == combat_before, "Packed rejected combat action grants no care benefit: " + choice)
	hp = game.state.hp
	game._battle_action("flee")
	game._close_modal()
	_check(not game.state.battle_active and game.state.hp == hp and game.state.xp == 40, "Packed retreat neither heals nor repeats personal-story reward: " + choice)

func _test_lightness_exploration() -> void:
	var lightness = load("res://scripts/lightness_rules.gd")
	game._new_game()
	await _talk("reed_cross")
	_check(_find_button(game.overlay, "踏苇过水") == null and _gather_text(game.overlay).contains("岑远"), "Packed locked crossing identifies its free mentor lesson")
	game._close_modal()
	game.state.quest_stage = 6
	game.state.ending = "守望"
	game.state.choose_sect("听潮阁")
	await _talk("mentor")
	_press("轻身基础")
	_check(_find_button(game.overlay, "修习踏苇行") == null and not game.state.lightness_unlocked, "Packed level-one disciple cannot learn lightness early")
	game._close_modal()
	game.state.gain_xp(180)
	game.state.recruit_companion()
	game.state.sect_trial_won = true
	game._refresh()
	await _talk("mentor")
	_check(_find_button(game.overlay, "领取内门荐记") != null and _find_button(game.overlay, "稍后领取") != null, "Packed pending-promotion mentor retains both receipt actions")
	_press("轻身基础")
	_check(_gather_text(game.overlay).contains("不收费") and _gather_text(game.overlay).contains("不改变普通行走碰撞"), "Packed lesson explains its price and explicit traversal limits")
	var stale_learn: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	stale_learn.call()
	_check(not game.state.lightness_unlocked and game.state.sect_rank == 1 and game.state.sect_trial_won, "Packed cancelled lightness lesson grants nothing and preserves pending promotion")
	await _talk("mentor")
	_press("轻身基础")
	game._save()
	var before: Dictionary = game.state.to_dict()
	_press("修习踏苇行")
	var expected: Dictionary = before.duplicate(true)
	expected.lightness_unlocked = true
	_check(game.state.to_dict() == expected, "Packed learning changes only the technique flag without consuming pending promotion")
	game._load()
	_check(game.state.to_dict() == expected and game.state.sect_rank == 1 and game.state.sect_trial_won, "Packed free lesson and pending receipt autosave together")
	await _talk("mentor")
	_press("稍后领取")
	_check(game.state.to_dict() == expected, "Packed postponement after learning remains resource-neutral")
	await _talk("mentor")
	_press("领取内门荐记")
	_check(game.state.sect_rank == 2 and game.state.sect_merit == int(before.sect_merit) + 3 and game.state.defense == int(before.defense) + 1 and game.state.max_qi == int(before.max_qi) + 1 and game.state.lightness_unlocked, "Packed pending promotion still pays exact original bonuses after lightness learning")
	await _talk("mentor")
	_press("轻身基础")
	_check(_find_button(game.overlay, "修习踏苇行") == null and _gather_text(game.overlay).contains("已经学会"), "Packed learned lesson cannot be purchased or granted twice")
	game._close_modal()
	_check(game.world._can_walk(lightness.SHORE) and game.world._can_walk(lightness.LANDING) and game.world._can_walk(lightness.RELIC_POSITION), "Packed authored shore, island landing and relic are walkable")
	_check(not game.world._can_walk(Vector2(1458, 930)) and not game.world._can_step(lightness.SHORE, lightness.LANDING) and not game.world._can_step(lightness.LANDING, lightness.SHORE), "Packed water collision blocks ordinary crossing in both directions")
	_check(not game.world._can_step(Vector2(825, 484), Vector2(1170, 484)) and not game.world._can_step(Vector2(155, 250), Vector2(460, 250)), "Packed segment collision also preserves existing pond and building barriers")
	_check(game.world._can_step(Vector2(500, 420), Vector2(520, 420)) and not game.world._can_step(Vector2(NAN, 0), lightness.LANDING), "Packed ordinary clear walking works and nonfinite movement is rejected")
	for delta in [0.2, 1.0]:
		game.world.teleport(Vector2(1440, 930))
		Input.action_press("move_right")
		game.world._process(delta)
		Input.action_release("move_right")
		_check(not lightness.on_islet(game.world.player_pos) and game.world._can_walk(game.world.player_pos), "Packed long-frame right input cannot walk across water: " + str(delta))
	await _talk("reed_cross")
	_check(game.world.nearby_id == "reed_cross", "Packed bank selects only the mainland crossing, never nearby island relics")
	_press("留在岸上")
	_check(game.world.player_pos == lightness.SHORE and not game.active_modal, "Packed crossing cancellation leaves the hero safely on shore")
	await _talk("reed_cross")
	var stale_cross: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	stale_cross.call()
	_check(game.world.player_pos == lightness.SHORE, "Packed expired crossing callback cannot teleport the hero")
	await _talk("reed_cross")
	before = game.state.to_dict()
	_press("踏苇过水")
	expected = before.duplicate(true)
	expected.position = {"x": lightness.LANDING.x, "y": lightness.LANDING.y}
	_check(game.world.player_pos == lightness.LANDING and game.state.position == lightness.LANDING and game.state.to_dict() == expected, "Packed explicit crossing changes only position and spends no resources")
	_check(game.world.companion_active and lightness.on_islet(game.world.companion_pos), "Packed active follower lands on safe island ground")
	game._load()
	_check(game.world.player_pos == lightness.LANDING and game.state.position == lightness.LANDING and lightness.on_islet(game.world.companion_pos), "Packed crossing autosave restores both hero and follower on the island")
	for facing in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		game.world.teleport(lightness.ISLET_CENTER + Vector2(35, 0))
		game.world.facing = facing
		game.world._process(0.25)
		_check(lightness.on_islet(game.world.companion_pos), "Packed follower stays inside island bounds for facing: " + str(facing))
	game.world.teleport(Vector2(1474, 930))
	Input.action_press("move_left")
	game.world._process(1.0)
	Input.action_release("move_left")
	_check(lightness.on_islet(game.world.player_pos), "Packed long-frame left input cannot leave the island through water")
	await _talk("reed_relic")
	_check(game.world.nearby_id == "reed_relic" and _find_button(game.overlay, "拓录残碑") != null and _gather_text(game.overlay).contains("只结算一次"), "Packed island relic is independently reachable and previews a one-time reward")
	var stale_relic: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	stale_relic.call()
	_check(game.state.lightness_relics.is_empty(), "Packed cancelled inscription cannot claim the lore reward")
	await _talk("reed_relic")
	before = game.state.to_dict()
	_press("拓录残碑")
	_check(game.state.lightness_relics == [lightness.RELIC_ID] and game.state.xp == int(before.xp) + 30 and game.state.coins == int(before.coins) + 18 and game.state.resources.herb == int(before.resources.herb) + 1, "Packed relic grants exact unique lore, thirty XP, eighteen coins and one herb")
	var discovered: Dictionary = game.state.to_dict()
	game._load()
	_check(game.state.to_dict() == discovered and game.world.player_pos == lightness.RELIC_POSITION, "Packed lore, all rewards and exact island position round-trip together")
	stale_relic.call()
	game.lightness_story.discover()
	_check(game.state.to_dict() == discovered, "Packed stale and direct repeat discovery cannot duplicate any reward")
	await _talk("reed_relic")
	_check(_find_button(game.overlay, "拓录残碑") == null and _gather_text(game.overlay).contains("已经收入江湖志"), "Packed discovered relic stays exhausted after reload")
	game._close_modal()
	await _key(KEY_J)
	_check(_gather_text(game.overlay).contains("苇心残碑已拓录") and _gather_text(game.overlay).contains("留刻度，不留渡价"), "Packed journal retains learned technique and recovered lore")
	game._close_modal()
	await _key(KEY_M)
	var chart := _find_chart(game.overlay)
	_check(chart != null and chart.map_id == "qingwei" and chart.markers.has("reed_cross") and chart.markers.has("reed_return") and chart.markers.has("reed_relic") and chart.player_position == game.world.player_pos, "Packed map shows the crossing, safe return, lore and actual island position")
	game._close_modal()
	await _talk("reed_return")
	before = game.state.to_dict()
	_press("借石回岸")
	expected = before.duplicate(true)
	expected.position = {"x": lightness.SHORE.x, "y": lightness.SHORE.y}
	_check(game.world.player_pos == lightness.SHORE and game.state.to_dict() == expected, "Packed safe return changes only position without healing or payment")
	game._load()
	_check(game.world.player_pos == lightness.SHORE and game.state.position == lightness.SHORE and game.state.lightness_relics == [lightness.RELIC_ID], "Packed return autosave keeps shore position and discovered lore")
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://hero_save.json"))
	_check(saved is Dictionary and saved.get("version") == 9 and saved.player.lightness_unlocked and saved.player.lightness_relics == [lightness.RELIC_ID], "Packed schema9 document writes lightness progression explicitly")
	game._start_battle("spar")
	before = game.state.to_dict()
	game.lightness_story.cross(true)
	_check(game.state.battle_active and game.world.player_pos == lightness.SHORE and game.state.to_dict() == before, "Packed traversal callback cannot escape combat or change its resources")
	game._battle_action("flee")
	game._close_modal()
	# Recovery of a safe authored position never strands an old/interrupted save,
	# even when that save has not learned the technique or earned the inscription.
	game._new_game()
	game.world.teleport(lightness.LANDING)
	game._save()
	game._load()
	_check(not game.state.lightness_unlocked and game.world.player_pos == lightness.LANDING, "Packed recovery preserves a safe island coordinate without inventing a lesson")
	await _talk("reed_relic")
	_check(_find_button(game.overlay, "拓录残碑") == null and _find_button(game.overlay, "借石回岸") != null and game.state.lightness_relics.is_empty(), "Packed unlearned island recovery offers an exit rather than a locked reward")
	_press("借石回岸")
	game._load()
	_check(game.world.player_pos == lightness.SHORE and not game.state.lightness_unlocked and game.state.lightness_relics.is_empty(), "Packed unlearned traveller safely returns and saves without unlocking anything")
	game.state.position = Vector2(1458, 930)
	game.state.save_game()
	game._load()
	_check(game.world._can_walk(game.world.player_pos), "Packed saved water coordinate is repaired onto safe ground")

func _test_visual_runtime() -> void:
	# These are checks of shipped runtime bytes, not the editable source directory.
	_check(ResourceLoader.exists("res://assets/generated/environment/qingwei_environment_atlas.png"), "Painted village atlas is shipped")
	_check(ResourceLoader.exists("res://assets/generated/environment/qingwei_moss_earth.png"), "Continuous ground painting is shipped")
	var environment=load("res://scripts/qingwei_environment_art.gd")
	var traveler=load("res://scripts/traveler_visual.gd")
	_check(environment!=null and traveler!=null,"Painted asset and articulated actor modules load from pack")
	if environment==null or traveler==null:return
	for b in game.world.buildings:
		var rect:Rect2=environment.building_rect(b)
		var scale_factor=rect.size.x/environment.REGIONS[b.type].size.x
		var anchor:Vector2=rect.position+environment.ANCHORS[b.type]*scale_factor
		_check(environment.texture_for(b.type)!=null,"Packed measured crop loads: "+b.type)
		_check(anchor.distance_to(b.pos+Vector2(b.size.x*.5,b.size.y))<.001 and rect.encloses(environment.plaque_rect(b)),"Packed doorstep/plaque anchors preserved: "+b.type)
	for pair in [[Vector2.DOWN,0],[Vector2.RIGHT,1],[Vector2.UP,2],[Vector2.LEFT,3]]:
		_check(traveler.direction_index(pair[0])==pair[1] and traveler.pose(pair[0],PI*.5,true).gait>.99,"Packed directional pose and walking contact")
	game._new_game();game._start_battle("spar")
	game.battle_presentation_enabled=true
	_check(game.battle_art.has_signal("impact_presented") and game.battle_art.has_signal("presentation_finished"),"Packed impact and completion contract")
	var before_turn:int=game.state.turn
	game._battle_action("attack")
	_check(game.battle_busy and game.battle_art.is_presenting(),"Packed action enters presentation lock")
	_check(game.battle_art.presentation_details.get("enemy_damage",0)>0,"Packed accepted result provides real damage number")
	var spent_turn:int=game.state.turn
	game._battle_action("attack")
	_check(spent_turn==before_turn+1 and game.state.turn==spent_turn,"Packed repeat input cannot spend another turn")
	await game.battle_art.presentation_finished
	await process_frame
	_check(not game.battle_busy and not game.battle_buttons[0].disabled,"Packed action releases controls after animation")
	_check(is_equal_approx(game.battle_hp.value,game.state.enemy_hp) and is_equal_approx(game.battle_player_hp.value,game.state.hp),"Packed end pose reconciles health display")
	game.state.enemy_hp=1
	game._battle_action("attack")
	_check(game.current_screen=="battle" and not game.active_modal,"Packed winning blow remains on stage")
	await game.battle_art.presentation_finished
	await process_frame
	_check(game.current_screen=="explore" and game.active_modal,"Packed finishing pose hands off to real result modal")
	game.battle_presentation_enabled=false
	game._close_modal()
