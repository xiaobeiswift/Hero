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
	var rehearsal: bool = OS.get_cmdline_user_args().has("--source-rehearsal")
	if rehearsal:
		if FileAccess.file_exists("res://project.binary"):
			push_error("Source rehearsal flag cannot bypass checks for an exported PCK"); quit(1); return
		print("SOURCE REHEARSAL: skipping exactly5 packaging-only assertions; no exported-pack claim")
	else:
		_check(FileAccess.file_exists("res://project.binary"), "Must load the exported binary project")
		_check(not DirAccess.dir_exists_absolute("res://tests"), "Test scripts excluded")
		_check(not DirAccess.dir_exists_absolute("res://tools"), "Build tools excluded")
		_check(not DirAccess.dir_exists_absolute("res://screenshots"), "Screenshots excluded")
		_check(not DirAccess.dir_exists_absolute("res://builds"), "Build outputs excluded")
	# A stale pack must fail before instantiating a scene or creating a save.
	if not _v18_prerequisites():
		print("FAIL: v18 prerequisites; %d checks; %d failures; no game instantiated" % [checks,failures])
		quit(1); return
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
	await _test_painted_hud_pack()
	await _test_party_inventory_pack()
	print("Retained party/inventory pack coverage: %d checks"%checks)
	_test_painted_combat_pack()
	print("Retained painted combat pack coverage: %d checks"%checks)
	await _test_rest_support_pack()
	print("Retained rest/support pack coverage: %d checks"%checks)
	await _test_village_finish_pack()
	print("Retained village/view pack coverage: %d checks"%checks)
	await _test_courtyard_props_pack()
	await _test_reading_party_pack()
	await _test_clear_visibility_pack()
	await _test_tang_combat_pack()
	await _test_martial_folio_pack()
	await _test_close_guard_pack()
	await _test_heting_pack()
	game.music.stop()
	game.sfx.stop()
	game.music.stream = null
	game.sfx.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	print("%s: %d %s checks; %d failures" % ["PASS" if failures == 0 else "FAIL", checks, "source-rehearsal" if rehearsal else "exported-pack", failures])
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
		var rank_caption=game.overlay.find_child("MartialRank",true,false)
		_check(rank_caption!=null and rank_caption.text=="内门弟子 · 考绩 3", "Packed martial panel displays its exact earned rank and merit: " + school)
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
	_check(saved is Dictionary and saved.get("version") == 10 and saved.get("player", {}).get("active_companion") == "唐栖", "Packed save writes schema10 and active party identity: " + choice)
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
	_check(game.world.interactables.size() == 9 and not game.world._can_walk(Vector2(277, 242)), "Packed vector region contains eight landmarks plus downstream exit and solid pond collision")
	await _key(KEY_M)
	var chart := _find_chart(game.overlay)
	_check(chart != null and chart.map_id == "mistwood" and chart.markers.size() == 9 and chart.current_target == "mist_rain_gauge", "Packed map chart loads fourth geography and current objective")
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
	_check(saved is Dictionary and saved.get("version") == 10 and saved.get("player", {}).get("mist_ending") == "warn_ferries", "Packed local save writes schema10 and Mistwood ending")
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
	_check(first_doc is Dictionary and first_doc.get("version") == 10 and first_doc.player.coins == 24, "Packed manual save writes the current schema and branch")
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
	_check(saved is Dictionary and saved.get("version") == 10 and saved.player.shen_care_stage == 5 and saved.player.shen_care_choice == choice, "Packed schema10 document records the final care plan: " + choice)
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
	_check(saved is Dictionary and saved.get("version") == 10 and saved.player.lightness_unlocked and saved.player.lightness_relics == [lightness.RELIC_ID], "Packed schema10 document writes lightness progression explicitly")
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

func _test_painted_hud_pack() -> void:
	game._new_game();game._process(0)
	var hero=load("res://scripts/painted_traveler_sprite.gd")
	var cast=load("res://scripts/painted_village_sprite.gd")
	_check(hero!=null and cast!=null and ResourceLoader.exists("res://scripts/game_hud.gd"),"Packed painted cast and full-world HUD modules retained")
	if hero==null or cast==null:return
	_check(ResourceLoader.exists(hero.PATH) and ResourceLoader.exists(cast.CAST_PATH) and ResourceLoader.exists(cast.SHEN_PATH),"All three character atlases survive export filtering")
	var frame_contract=true
	for direction in ["front","right","back","left"]:
		for frame in range(8):
			var texture=hero.texture_for(direction,frame)
			frame_contract=frame_contract and texture!=null and texture.region==Rect2(frame*256,hero.ROWS[direction]*256,256,256)
	_check(frame_contract,"Packed32-frame atlas retains all measured crops")
	var anchor=Vector2(350,650)
	_check((hero.drawing_rect(anchor).position+hero.FOOT*(72.0/256.0)).distance_to(anchor)<.001,"Packed hero foot is invariant under sprite scale")
	_check((cast.drawing_rect(anchor).position+cast.FOOT*(72.0/256.0)).distance_to(anchor)<.001,"Packed village cast shares the collision foot")
	var cast_contract=true
	for role in ["elder","healer","bandit","mentor"]:
		cast_contract=cast_contract and cast.texture_for(role)!=null and game.world._painted_npc_role(role)==role
	_check(cast_contract,"Packed key village cast resolves its original identities")
	game.world.companion_active=true;game.world.companion_name="沈青"
	_check(game.world._painted_npc_role("healer").is_empty() and game.world.get_npc_name("healer")=="药铺伙计","Packed travelling Shen is not duplicated inside pharmacy")
	game.world.companion_active=false
	_check(game.hud!=null and game.world_view.size==Vector2i(1280,800) and game.world.viewport_rect==Rect2(0,0,1280,800),"Packed HUD and world use the full1280x800 canvas")
	_check(game.hud.nav_buttons.size()==5 and game.hud.exploration.visible,"Packed exploration quick actions are visible")
	for key in [KEY_M,KEY_K,KEY_I,KEY_J,KEY_B]:
		await _key(key)
		_check(game.active_modal,"Packed HUD keeps real keyboard shortcut: "+OS.get_keycode_string(key))
		game._close_modal()
	game._show_inventory()
	_check(_gather_text(game.overlay).contains("攻击 16") and _gather_text(game.overlay).contains("防御 4") and _gather_text(game.overlay).contains("修为 0 / 60"),"Packed inventory retains secondary stats hidden from the minimal HUD")
	game._close_modal();game.toast_time=0;game.hud.quest_notice_time=0;game._process(0)
	_check(not game.world._navigation_target_covered(Vector2(520,220)),"Packed hidden toast releases its compass exclusion")
	game.save_warning=true;game._process(0)
	_check(game.hud.toast_wash.visible and game.status_label.text.contains("自动存档失败") and game.status_label.text.contains("F5"),"Packed failed autosave remains explicit and actionable")
	game.save_warning=false;game.toast_time=0;game._process(0)
	game.world.teleport(Vector2(70,160));game.hud.tick(1.0)
	_check(game.hud.identity_wash.modulate.a<.3,"Packed HUD fades rather than conceals the traveller")
	game._start_battle("spar");game._process(0)
	_check(not game.hud.exploration.visible and not game.world.visible and game.battle_art.scale.x>1.3,"Packed combat switches to full-width stage without drawing the village")
	game.battle_player_hp.max_value=180;game.battle_player_hp.value=37.25
	_check(game.hud.battle_player_value.text=="气血  37 / 180","Packed player digits follow presented health")
	game.battle_hp.max_value=96;game.battle_hp.value=23.9
	_check(game.hud.battle_enemy_value.text=="气血  24 / 96","Packed enemy digits follow tween rather than final model")
	game.state.qi=0;game._refresh_battle()
	_check(game.battle_buttons[1].disabled and game.battle_buttons[1].tooltip_text.contains("真气"),"Packed unavailable skill explains qi requirement")
	game._battle_action("flee");game._close_modal()

func _test_party_inventory_pack()->void:
	game._new_game();game._process(0)
	var shen=load("res://scripts/painted_shen_sprite.gd")
	_check(shen!=null and ResourceLoader.exists("res://scripts/inventory_panel.gd"),"Packed travelling Shen and paper inventory helpers retained")
	if shen==null:return
	_check(ResourceLoader.exists(shen.PATH) and shen.texture_for("front",0).atlas.get_size()==Vector2(2048,1024),"Packed painted Shen atlas has all32 cells")
	var crop_valid=true
	for direction in shen.ROWS:
		for frame in range(8):
			crop_valid=crop_valid and shen.texture_for(direction,frame).region==Rect2(frame*256,shen.ROWS[direction]*256,256,256)
	_check(crop_valid,"Packed Shen directional crops remain distinct and bounded")
	game._show_inventory()
	_check(game.overlay.find_child("InventoryFrame",true,false)!=null and game.overlay.find_child("InventoryTraveller",true,false)!=null,"Packed paper inventory displays its illustrated identity and structured layout")
	_check(_find_button(game.overlay,"回春散").disabled and _find_button(game.overlay,"切换阵型").disabled and _find_button(game.overlay,"青钢剑 · 45文").disabled,"Packed unavailable inventory actions are visibly disabled")
	var before=game.state.to_dict();var stale=game.modal_actions[2]
	await _key(KEY_3)
	_check(game.state.to_dict()==before and _gather_text(game.overlay).contains("还需 21 文"),"Packed blocked numeric shortcut explains price without spending")
	await _key(KEY_K)
	_check(game.active_modal and not game.overlay.get_meta("inventory",false) and _gather_text(game.overlay).contains("武学"),"Packed inventory K shortcut opens real martial screen")
	stale.call()
	_check(game.state.to_dict()==before,"Packed dismissed inventory callback cannot purchase equipment")
	game._close_modal();game._show_inventory();await _key(KEY_B)
	_check(game.active_modal and not game.overlay.get_meta("inventory",false) and _gather_text(game.overlay).contains("工艺"),"Packed inventory B shortcut opens actual crafting")
	game._close_modal();game.state.quest_stage=6;game.state.recruit_companion();game._sync_world_state();game.world.teleport(Vector2(435,650))
	var valid_spacing=true
	for facing in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		game.world.facing=facing
		var target=game.world._companion_follow_target()
		valid_spacing=valid_spacing and game.world._can_step(game.world.player_pos,target) and target.distance_to(game.world.player_pos)>35
	_check(valid_spacing,"Packed party trailing space keeps both figures on reachable ground")
	game.world.player_pos=Vector2(600,650);game.world.companion_pos=Vector2(500,670)
	_check(game.world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})==.4,"Packed foreground canopy also preserves painted follower readability")
	game._show_inventory();await _key(KEY_2)
	_check(game.state.formation=="护后" and _gather_text(game.overlay).contains("护后"),"Packed structured inventory retains formation action and current display")
	await _key(KEY_4)
	_check(not game.active_modal,"Packed fourth inventory shortcut still returns to exploration")

func _test_painted_combat_pack()->void:
	var hero=load("res://scripts/painted_battle_hero.gd")
	var rival=load("res://scripts/painted_battle_puheng.gd")
	var plate=load("res://scripts/ferry_battle_backdrop.gd")
	_check(hero!=null and rival!=null and plate!=null,"Packed painted combat helpers retained")
	if hero==null or rival==null or plate==null:return
	for helper in [hero,rival]:
		_check(ResourceLoader.exists(helper.PATH) and helper.texture_for("idle").atlas.get_size()==Vector2(1536,1024),"Packed six-pose combat atlas retained")
		for name in helper.POSES:
			var i:int=helper.POSES[name]
			_check(helper.texture_for(name).region==Rect2((i%3)*512,(i/3)*512,512,512),"Packed combat crop: "+name)
		var foot=Vector2(229,274)
		_check((helper.drawing_rect(foot,208).position+helper.FOOT*(208.0/512.0)).distance_to(foot)<.001,"Packed combat pose keeps fixed foot")
		_check(helper.texture_for("idle")==helper.texture_for("idle"),"Packed combat crops are cached")
	_check(ResourceLoader.exists(plate.PATH) and plate.texture()!=null,"Packed original ferry painting retained")
	var rect:Rect2=plate.cover_rect(plate.texture().get_size(),Vector2(938,plate.FIGHTING_HEIGHT))
	var deck_y=rect.position.y+567.0*rect.size.y/plate.texture().get_height()
	_check(deck_y<274 and 274-deck_y<40 and plate.FIGHTING_HEIGHT==356,"Packed scenery fighting plane supports unchanged actor feet")
	_check(plate.applies("qingwei") and not plate.applies("sluice") and not plate.applies("frostbridge") and not plate.applies("mistwood"),"Packed regional backdrop scope remains exact")
	game._new_game();game._start_battle("training")
	_check(game.battle_art.uses_painted_enemy() and game.battle_art.enemy_identity==game.state.enemy_name,"Packed battle connects Pu Heng identity to painted rival")
	_check(game.battle_art.painted_hero_enabled and game.battle_art.painted_enemy_enabled and game.battle_art.painted_backdrop_enabled,"Packed combat presentation enabled by default")
	for row in [[{},"idle"],[{"windup":.7},"windup"],[{"strike":.8},"strike"],[{"guard":.8},"guard"],[{"recoil":.8},"hurt"],[{"defeat":.8},"kneel"]]:
		_check(hero.pose_for(row[0])==row[1] and rival.pose_for(row[0])==row[1],"Packed accepted pose mapping: "+row[1])
	for identity in ["闸首罗沉","岑远","蒲横的徒弟"]:
		game.battle_art.enemy_identity=identity
		_check(not game.battle_art.uses_painted_enemy(),"Packed rival does not impersonate another identity: "+identity)
	game.battle_art.enemy_identity=game.state.enemy_name
	game._battle_action("flee");game._close_modal()

func _test_rest_support_pack()->void:
	var shen=load("res://scripts/painted_battle_shen.gd")
	var feedback=load("res://scripts/companion_battle_feedback.gd")
	_check(shen!=null and feedback!=null and ResourceLoader.exists("res://scripts/pause_menu.gd"),"Packed rest and support presentation modules retained")
	if shen==null or feedback==null:return
	game._new_game();await _key(KEY_ESCAPE)
	_check(game.active_modal and game.overlay.get_meta("pause_menu",false),"Packed Escape opens rest menu from exploration")
	var frame=game.overlay.find_child("JourneyPause",true,false)
	_check(frame!=null and Rect2(0,0,1280,800).encloses(frame.get_rect()) and game.modal_actions.size()==5,"Packed rest menu fits viewport with five real actions")
	var position:Vector2=game.world.player_pos
	Input.action_press("move_right");await create_timer(.08).timeout;Input.action_release("move_right")
	_check(game.world.player_pos==position,"Packed rest menu blocks walking")
	var stale:Callable=game.modal_actions[4];await _key(KEY_ESCAPE);stale.call()
	_check(not game.active_modal and not game.quit_pending,"Packed dismissed rest callback cannot request exit")
	await _key(KEY_ESCAPE);await _key(KEY_4)
	_check(_gather_text(game.overlay).contains("保存成功才会离开"),"Packed title-return explains actual save gate")
	await _key(KEY_2)
	_check(game.overlay.get_meta("pause_menu",false),"Packed leave cancellation returns to rest")
	await _key(KEY_4);await _key(KEY_1)
	_check(game.current_screen=="title" and game.state.has_save(),"Packed title-return saves into isolated profile before leaving")
	_check(shen.texture_for("idle").atlas.get_size()==Vector2(1024,1024),"Packed four-pose Shen atlas survives filters")
	for name in shen.POSES:
		var i:int=shen.POSES[name]
		_check(shen.texture_for(name).region==Rect2((i%2)*512,(i/2)*512,512,512),"Packed support crop: "+name)
	var foot=Vector2(126,266)
	_check((shen.drawing_rect(foot).position+shen.FOOT*(156.0/512.0)).distance_to(foot)<.001,"Packed support foot retains scale and placement")
	_check(shen.texture_for("assist")==shen.texture_for("assist"),"Packed support textures remain cached")
	var parsed=feedback.read({"log":["沈青与你并肩出手，追加 7 点伤害。","沈青与你换步照应，恢复2点气血。"]})
	_check(parsed.damage==7 and parsed.healing==2 and feedback.pose_for(parsed,.56,true)=="heal","Packed support facts preserve actual amount and healing beat")
	game._new_game();game.state.quest_stage=3;game.state.recruit_companion();game.state.shen_care_stage=5;game.state.shen_care_choice="mobile"
	game._start_battle("training");game.state.hp=50;game.state._companion_attack_count=1;game._refresh_battle()
	game.battle_presentation_enabled=true;game.battle_art.set_process(false);game._battle_action("attack")
	_check(game.state.hp==47 and game.battle_player_hp.value==50,"Packed accepted result does not show support healing early")
	game.battle_art._process(.5);_settle_support_pack()
	_check(game.battle_art.support_visual_pose()=="assist" and game.battle_player_hp.value==50 and game.battle_hp.value==41,"Packed assist contact precedes recovery")
	game.battle_art._process(.061);_settle_support_pack()
	_check(game.battle_art.support_visual_pose()=="heal" and game.battle_player_hp.value==52,"Packed companion recovery reaches health bar at its own beat")
	game.battle_art._process(.33);_settle_support_pack()
	_check(game.battle_player_hp.value==47,"Packed enemy response follows recovery truthfully")
	game.battle_art._process(2)
	_check(not game.battle_busy and not game.battle_art.is_presenting(),"Packed support presentation releases action lock")
	game.battle_presentation_enabled=false;game._battle_action("flee");game._close_modal();game.state.set_formation("护后");game._start_battle("training")
	game.battle_presentation_enabled=true;game._battle_action("guard");game.battle_art._process(.9)
	_check(game.battle_art.presentation_details.support.cover>0 and game.battle_art.support_visual_pose()=="cover","Packed rear guard shows actual covered damage")
	game.battle_art._process(2);game.battle_presentation_enabled=false;game._battle_action("flee");game._close_modal()
	game._new_game();game._start_battle("training")
	_check(not game.battle_art.companion_active and game.battle_art.support_visual_pose()=="idle","Packed fresh solo encounter cannot retain prior support cue")
	game._battle_action("flee");game._close_modal();game.battle_art.set_process(true)

func _settle_support_pack()->void:
	for tween in game._battle_health_tweens.values():
		if tween.is_valid():tween.custom_step(.25)

func _test_village_finish_pack()->void:
	var water=load("res://scripts/qingwei_water_material.gd")
	var props=load("res://scripts/qingwei_ferry_props.gd")
	var civilians=load("res://scripts/painted_village_civilians.gd")
	var prefs_class=load("res://scripts/view_preferences.gd")
	_check(water!=null and props!=null and civilians!=null and prefs_class!=null,"Packed village finish and display modules retained")
	if water==null or props==null or civilians==null or prefs_class==null:return
	_check(water.texture()!=null and water.texture().get_size()==Vector2(1254,1254),"Packed painted water retained at original size")
	_check(props.wood_texture()!=null and props.skiff_texture().region==Rect2(51,205,1693,498),"Packed deck and cropped skiff retained")
	_check(water.texture()==water.texture() and props.skiff_texture()==props.skiff_texture(),"Packed village materials reuse textures")
	water.prepare()
	_check(water._pond_points.size()==64 and water._river_points.size()==4,"Packed water preserves existing clipped geometry")
	var uv_delta:Vector2=water.uv_for(Vector2(1500,700),water.RIVER_RECT)-water.uv_for(Vector2(1490,690),water.RIVER_RECT)
	_check(is_equal_approx(uv_delta.x,uv_delta.y),"Packed channel UVs preserve painted proportions")
	for role in civilians.ROLES:
		var image=civilians.texture_for(role)
		_check(image!=null and image.atlas.get_size()==Vector2(768,256) and image.region==Rect2(civilians.ROLES[role]*256,0,256,256),"Packed civilian crop: "+role)
	_check((civilians.drawing_rect(Vector2(300,400)).position+civilians.FOOT*72.0/256.0).distance_to(Vector2(300,400))<.001,"Packed civilians keep their world foot anchors")
	game._new_game();game.view_preferences.zoom_index=0;game._apply_view_zoom()
	_check(game.world.painted_water_enabled and game.world.painted_props_enabled,"Packed village materials enabled by default")
	_check(game.world._can_walk(Vector2(880,450)) and game.world._can_walk(Vector2(1450,780)),"Packed painted piers remain walkable")
	_check(not game.world._can_walk(Vector2(998,484)) and not game.world._can_walk(Vector2(1540,831)),"Packed painted pond and skiff do not create false routes")
	var before=game.state.to_dict();var position:Vector2=game.world.player_pos
	await _key(KEY_EQUAL)
	_check(game.view_zoom==1.25 and game.world.viewport_rect.size==Vector2(1024,640),"Packed plus key enters closer logical exploration view")
	_check(game.state.to_dict()==before and game.world.player_pos==position,"Packed display choice leaves progress and world position intact")
	await _key(KEY_EQUAL)
	_check(game.view_zoom==1.6 and game.world.viewport_rect.size==Vector2(800,500),"Packed detailed view uses correct camera extent")
	_check(game.hud.identity_wash.position==Vector2(20,23) and game.hud.nav_buttons[0].size==Vector2(80,73),"Packed exploration zoom keeps interface readable at fixed size")
	var restored=prefs_class.new()
	_check(restored.load_settings()==OK and restored.zoom_index==2,"Packed display choice persists separately on disk")
	await _key(KEY_E)
	_check(game.active_modal and _gather_text(game.overlay).contains("陆伯"),"Packed E interaction still reaches the real nearby NPC at detailed view")
	await _key(KEY_EQUAL)
	_check(game.view_zoom==1.6,"Packed dialogue blocks display shortcut")
	await _key(KEY_ESCAPE);await _key(KEY_ESCAPE)
	var view_button=game.overlay.find_child("PauseView",true,false)
	_check(view_button!=null and view_button.text.contains("160%"),"Packed rest menu exposes current view choice")
	if view_button!=null:view_button.pressed.emit()
	await process_frame
	_check(game.view_zoom==1.0 and game.world_view.size==Vector2i(1280,800),"Packed rest view button cycles to standard view")
	await _key(KEY_ESCAPE)
	game.state.quest_stage=3;game.state.recruit_companion();game._sync_world_state();game._refresh()
	_check(game.world.get_npc_name("healer")=="药铺伙计" and game.world._painted_civilian_role("clerk")=="clerk","Packed travelling Shen leaves distinct pharmacy clerk")
	game._healer_dialogue()
	_check(_gather_text(game.overlay).contains("药铺伙计") and _gather_text(game.overlay).contains("55点"),"Packed clerk dialogue retains identity and actual sect medicine description")
	game._close_modal();game._start_battle("training");game._process(0);game._toast("已保存画面。");game.hud.tick(0)
	_check(game.hud.toast_wash.position.y>=774 and game.hud.toast_wash.size.y<=26,"Packed combat notice stays below action row")
	await _key(KEY_EQUAL)
	_check(game.view_zoom==1.0,"Packed battle blocks exploration zoom")
	game.battle_presentation_enabled=false;game._battle_action("flee");game._close_modal()

func _test_courtyard_props_pack()->void:
	var board=load("res://scripts/painted_noticeboard.gd")
	var camp=load("res://scripts/painted_camp_shelter.gd")
	var bamboo=load("res://scripts/painted_bamboo.gd")
	var tables=load("res://scripts/painted_tea_table.gd")
	var lamps=load("res://scripts/painted_lantern_post.gd")
	_check(board!=null and camp!=null and bamboo!=null and tables!=null and lamps!=null,"Packed courtyard presentation helpers retained")
	if board==null or camp==null or bamboo==null or tables==null or lamps==null:return
	for helper in [board,camp,bamboo,tables,lamps]:
		_check(ResourceLoader.exists(helper.PATH) and helper.texture()!=null,"Packed original prop resource retained")
	_check(board.texture()==board.texture() and board.texture().region==Rect2(35,139,1201,992),"Packed board crop stays cached and bounded")
	var foot=Vector2(720,480)
	_check((board.drawing_rect(foot).position+board.FOOT*board.WIDTH/board.REGION.size.x).distance_to(foot)<.001,"Packed board keeps its interaction foot")
	_check(camp.opacity_for([Vector2(1315,785),Vector2(1339,720)])==.45,"Packed canvas preserves a party member behind it")
	_check((camp.drawing_rect().position+camp.FOOT*camp.WIDTH/camp.REGION.size.x).distance_to(camp.WORLD_FOOT)<.001,"Packed shelter remains grounded")
	for height in [132.0,146.0]:
		var data=bamboo.geometry(foot,height,1.5,true);var p=data.points;var u=bamboo.FOOT.x/bamboo.REGION.size.x;var v=bamboo.FOOT.y/bamboo.REGION.size.y
		var anchor=p[0]*(1-u)*(1-v)+p[1]*u*(1-v)+p[2]*u*v+p[3]*(1-u)*v
		_check(anchor.distance_to(foot)<.001 and Geometry2D.triangulate_polygon(p).size()==6,"Packed bamboo sway keeps root on valid geometry")
	_check(bamboo.texture().get_size()==Vector2(1286,1223),"Packed bamboo texture preserves measured UV dimensions")
	for p in tables.POSITIONS:
		var rect:Rect2=tables.drawing_rect(p)
		_check((rect.position+tables.FOOT*tables.WIDTH/tables.REGION.size.x).distance_to(p+Vector2(0,8))<.001,"Packed tea arrangement preserves courtyard anchor")
	for p in lamps.POSITIONS:
		var data=lamps.lamp_geometry(p,1.0);var points=data.points;var u=lamps.LOOP.x/lamps.LAMP_REGION.size.x;var v=lamps.LOOP.y/lamps.LAMP_REGION.size.y
		var pivot=points[0]*(1-u)*(1-v)+points[1]*u*(1-v)+points[2]*u*v+points[3]*(1-u)*v
		_check(pivot.distance_to(lamps.lamp_pivot(p))<.001,"Packed suspended lantern remains attached to its hook")
	_check(lamps.post_texture()==lamps.post_texture() and lamps.texture().get_size()==Vector2(1774,887),"Packed lantern components share cached original art")
	game._new_game()
	_check(game.world.painted_board_enabled and game.world.painted_camp_enabled and game.world.painted_bamboo_enabled and game.world.painted_tea_tables_enabled and game.world.painted_lanterns_enabled,"Packed courtyard art enabled by default")
	game.world.teleport(Vector2(715,540));await create_timer(.05).timeout;await _key(KEY_E)
	_check(game.active_modal and _gather_text(game.overlay).contains("青苇渡告示"),"Packed E reaches original notice reading")
	await _key(KEY_ESCAPE)
	_check(not game.active_modal and game.state.quest_stage==0,"Packed notice dismissal preserves opening quest state")
	var prompt:Rect2=game.world._interaction_prompt_rect(Vector2(720,480))
	_check(not prompt.intersects(Rect2(game.world.player_pos-Vector2(20,62),Vector2(40,70))),"Packed local prompt leaves the traveller visible")

func _test_reading_party_pack()->void:
	var tang=load("res://scripts/painted_tang_sprite.gd")
	var sheet=load("res://scripts/dialogue_sheet.gd")
	_check(tang!=null and sheet!=null,"Packed reading and Tang helpers retained")
	if tang==null or sheet==null:return
	for direction in tang.ROWS:
		for frame in [0,4]:
			var image=tang.texture_for(direction,frame)
			_check(image!=null and image.atlas.get_size()==Vector2(2048,1024) and image.region==Rect2(frame*256,tang.ROWS[direction]*256,256,256),"Packed Tang directional contact frame retained")
	_check(tang.texture_for("front",0)==tang.texture_for("front",8),"Packed Tang frames reuse one crop")
	var foot=Vector2(720,480)
	_check((tang.drawing_rect(foot).position+tang.FOOT*72.0/256.0).distance_to(foot)<.001,"Packed Tang keeps shared ground anchor")
	game._new_game();game._interact("elder");await process_frame;await process_frame
	var page=game.overlay.find_child("DialogueSheet",true,false)
	var body=game.overlay.find_child("DialogueBody",true,false)
	_check(page!=null and body!=null,"Packed conversation uses the fitted paper page")
	_check(page!=null and page.size.y<500,"Packed short dialogue fits its actual content")
	_check(body!=null and body.get_theme_font_size("normal_font_size")==19,"Packed body keeps readable font size")
	var stale:Callable=game.modal_actions[0]
	await _key(KEY_ESCAPE);stale.call()
	_check(game.state.quest_stage==0 and not game.active_modal,"Packed abandoned dialogue callback cannot accept quest")
	await _key(KEY_E);await _key(KEY_ENTER)
	_check(game.state.quest_stage==1 and not game.active_modal,"Packed actual dialogue keys still accept original quest")
	game._modal("沈青 · 试读","纸面与头像","完整原始文字。",[["一",game._close_modal],["二",game._close_modal],["三",game._close_modal],["四",game._close_modal],["查看告示",game._show_board]],true)
	await process_frame;await process_frame
	body=game.overlay.find_child("DialogueBody",true,false)
	var portrait=game.overlay.find_child("Portrait_shen",true,false)
	_check(portrait!=null and not portrait.get_rect().intersects(body.get_rect()),"Packed portrait remains outside text")
	for i in range(1,6):
		var button=game.overlay.find_child("DialogueChoice"+str(i),true,false)
		_check(button!=null and not button.get_rect().intersects(body.get_rect()),"Packed numbered choice stays outside text")
	await _key(KEY_5)
	_check(_gather_text(game.overlay).contains("青苇渡告示"),"Packed fifth-choice shortcut reaches real notice")
	await _key(KEY_ESCAPE)
	game.world.teleport(Vector2(720.63916015625,469.580535888672))
	_check(game.world._noticeboard_opacity(foot)==.38,"Packed exact release obstruction position stays visible")
	game.world.teleport(Vector2(720,520))
	_check(game.world._noticeboard_opacity(foot)==1.0,"Packed board returns opaque in front")
	game.state.quest_stage=6;game.state.side_stage=3;game.state.chapter_two_stage=4;game.state.bridge_repaired=true;game.state.tangqi_stage=3;game.state.tangqi_choice="preserve";game.state.tangqi_unlocked=true;game.state.select_companion("唐栖");game._sync_world_state()
	_check(game.world.companion_active and game.world.companion_name=="唐栖","Packed painted follower keeps Tang identity")
	game.state.map_id="frostbridge";game.world.change_map("frostbridge",Vector2(700,805))
	_check(game.world.get_npc_name("bridge_worker")=="修桥工位","Packed travelling Tang leaves his work station")
	game._new_game()

func _test_clear_visibility_pack()->void:
	var prefs=load("res://scripts/view_preferences.gd")
	_check(prefs!=null,"Packed display preferences retained")
	if prefs==null:return
	var path="user://v17-preference-audit.cfg"
	for detail in [false,true]:
		for zoom in range(3):
			var selected=prefs.new();selected.full_resolution=detail;selected.zoom_index=zoom;selected.sound_enabled=detail
			_check(selected.save_settings(path)==OK,"Packed display settings write independently of character save")
			var restored=prefs.new()
			_check(restored.load_settings(path)==OK and restored.zoom_index==zoom and restored.full_resolution==detail and restored.sound_enabled==detail,"Packed sound/detail/zoom restore together")
	game._new_game();game._stop_audio();game.audio_on=false
	game.view_preferences.zoom_index=2;game.view_preferences.full_resolution=true;game._apply_view_zoom()
	_check(game.world_view.size==Vector2i(1280,800) and game.world.viewport_rect.size==Vector2(800,500),"Packed clear view preserves full pixels and close logical camera")
	_check(game.world.ui_font==game.world_detail_font,"Packed clear world uses separate detail font")
	await _key(KEY_ESCAPE);await _key(KEY_MINUS)
	_check(game.view_zoom==1.25 and game.active_modal and game.overlay.get_meta("pause_menu",false),"Packed pause minus key keeps menu open")
	await _key(KEY_KP_ADD)
	_check(game.view_zoom==1.6 and game.active_modal,"Packed keypad zoom returns to detail view")
	var button=game.overlay.find_child("PauseQuality",true,false)
	_check(button!=null and button.text.contains("清晰"),"Packed rest menu exposes detail choice")
	if button!=null:button.pressed.emit()
	await process_frame
	_check(not game.view_preferences.full_resolution and game.world_view.size==Vector2i(800,500),"Packed light choice reduces render pixels without changing zoom")
	game.overlay.find_child("PauseQuality",true,false).pressed.emit();await process_frame;await _key(KEY_ESCAPE)
	game.world.teleport(Vector2(300,185));game.toast_time=0;game.hud.quest_notice_time=0;game._process(0)
	var target:Vector2=game.world.interactables.elder.pos-game.world.camera_pos
	_check(game.world._navigation_target_visible(target),"Packed visible elder has no duplicate lower-edge compass")
	_check(game.world._building_opacity(game.world.buildings[0])==.35,"Packed clinic roof preserves traveller visibility")
	game.world.teleport(Vector2(900,695))
	_check(game.world._building_opacity(game.world.buildings[4])==.35,"Packed legal shrine-back position remains readable")
	game.world.teleport(Vector2(900,820))
	_check(game.world._building_opacity(game.world.buildings[4])==1.0,"Packed shrine facade remains opaque in front")
	for region in ["qingwei","sluice","frostbridge","mistwood"]:
		game.state.map_id=region;game.world.change_map(region,Vector2(600,480));game._show_map();await process_frame;await process_frame
		var page=game.overlay.find_child("DialogueSheet",true,false);var chart=game.overlay.find_child("RegionChart",true,false);var close=game.overlay.find_child("DialogueChoice1",true,false)
		_check(page!=null and chart!=null and close!=null,"Packed regional chart and close control retained")
		if page!=null and chart!=null and close!=null:
			_check(page.size.y==570 and Rect2(Vector2.ZERO,page.size).encloses(chart.get_rect()),"Packed chart fits its full paper page")
			_check(not chart.get_rect().intersects(close.get_rect()) and chart.map_id==region,"Packed regional chart leaves close control visible")
		await _key(KEY_1);_check(not game.active_modal,"Packed numbered map dismissal works")
	game._new_game()

func _test_tang_combat_pack()->void:
	var art=load("res://scripts/painted_battle_tang.gd")
	_check(art!=null,"Packed Tang combat helper retained")
	if art==null:return
	for pose in art.POSES:
		var texture=art.texture_for(pose);var i:int=art.POSES[pose]
		_check(texture!=null and texture.atlas.get_size()==Vector2(1024,1024),"Packed Tang pose texture survives export filters")
		_check(texture.region==Rect2((i%2)*512,(i/2)*512,512,512) and texture==art.texture_for(pose),"Packed Tang pose crop remains grounded and cached")
	game._new_game();game._stop_audio();game.audio_on=false
	game.state.tangqi_unlocked=true;game.state.select_companion("唐栖");game.battle_presentation_enabled=true;game.battle_art.set_process(false)
	game._start_battle("training");game.state.qi=0;game.state._companion_attack_count=1;game._refresh_battle();game._battle_action("attack")
	var facts=game.battle_art.presentation_details.support
	_check(facts.name=="唐栖" and facts.damage==4 and facts.qi==1 and game.state.qi==3,"Packed Tang assist preserves actual damage and qi contributions")
	var accepted=game.state.to_dict().duplicate(true)
	game.battle_art._process(.50)
	_check(game.battle_art.support_visual_pose()=="assist","Packed accepted support action displays Tang assist pose")
	game.battle_art._process(.20)
	_check(game.battle_art.support_visual_pose()=="recover" and game.state.to_dict()==accepted,"Packed Tang recovery pose is presentation-only")
	game.battle_art._process(2);await process_frame
	_check(game.hud.battle_qi.text.contains("3 / 6"),"Packed qi feedback settles at accepted model value")
	game.battle_presentation_enabled=false;game._battle_action("flee");game._close_modal();game.battle_art.set_process(true);game._new_game()

func _test_martial_folio_pack()->void:
	_check(ResourceLoader.exists("res://scripts/martial_panel.gd"),"Packed martial folio helper retained")
	game._new_game();game.state.choose_sect("听潮阁");game.state.quest_stage=6;game.state.sect_rank=2;game.state.sect_merit=5
	game._show_martials();await process_frame;await process_frame
	var page=game.overlay.find_child("MartialFolio",true,false)
	_check(page!=null and game.modal_actions.size()==3,"Packed folio preserves two learned choices andReturn")
	var ids=game.state.school_art_ids()
	for id in [ids[2],ids[3]]:
		var card=game.overlay.find_child("ArtCard_"+id,true,false)
		_check(card!=null and card.find_child("ArtLocked",true,false).disabled,"Packed unlearned school page is clearly unavailable")
	_check(game.state.sect_merit==5 and game.state.learned_arts.is_empty(),"Packed comparison never silently spends merit")
	await _key(KEY_3);_check(not game.active_modal,"Packed limited-loadout Return keeps original numeric position")
	_check(game.state.learn_art(ids[2]) and game.state.learn_art(ids[3]),"Packed existing mentor rules still unlock the two advanced moves")
	game._show_martials();await process_frame;await process_frame
	page=game.overlay.find_child("MartialFolio",true,false)
	_check(page!=null and game.modal_actions.size()==5,"Packed full loadout fits the original five-key contract")
	for id in ids:
		var card=page.find_child("ArtCard_"+id,true,false)
		_check(card!=null and Rect2(Vector2.ZERO,page.size).encloses(card.get_rect()),"Packed learned card stays inside the folio")
		_check(card.find_child("ArtEquip",true,false)!=null,"Packed learned move exposes equip control")
	await _key(KEY_4)
	_check(game.state.equipped_art==ids[3] and not game.active_modal,"Packed fourth key equips the chosen focus move")
	game._show_martials();await process_frame;await process_frame
	_check(game.overlay.find_child("EquippedArtTitle",true,false).text==ids[3],"Packed folio marks the actual equipped move")
	var description=game.overlay.find_child("EquippedArtDescription",true,false)
	_check(description.size.x==248 and description.get_minimum_size().y<=58,"Packed long Chinese description wraps inside its column")
	await _key(KEY_5);game._new_game()

func _test_close_guard_pack() -> void:
	game._new_game()
	_check(game.state.save_game()==OK,"Packed close fixture starts with a valid saved journey")
	var save_path:String=game.state.SAVE_PATH
	var original=FileAccess.get_file_as_bytes(save_path)
	var blocked=ProjectSettings.globalize_path(save_path+".tmp")
	var fixture_error=DirAccess.make_dir_absolute(blocked)
	_check(fixture_error==OK,"Packed close fixture blocks only its own temporary file path")
	if fixture_error!=OK:return
	game.state.coins+=1
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not game.quit_pending and game.active_modal,"Packed WM-close stays open when the actual save fails")
	_check(_gather_text(game.overlay).contains("手记未能落笔"),"Packed failed close opens the recovery page")
	_check(FileAccess.get_file_as_bytes(save_path)==original,"Packed failed close preserves existing saved bytes")
	await _key(KEY_2)
	_check(game.active_modal and game.overlay.get_meta("pause_menu",false),"Packed failed close can return to rest without quitting")
	await _key(KEY_ESCAPE)
	_check(not game.active_modal and game.save_warning,"Packed rest cancellation keeps unsaved journey active")
	_check(game.status_label.text.count("F5")==1 and game.status_label.text.count("存档失败")==1,"Packed autosave failure shows one recovery warning")
	await _key(KEY_F5)
	_check(game.status_label.text.count("F5")==1 and game.status_label.text.contains("错误码"),"Packed failed retry retains details without duplicate warning")
	_check(FileAccess.get_file_as_bytes(save_path)==original,"Packed failed retry leaves good save byte-identical")
	var restored=blocked+".closed-audit-%d"%Time.get_ticks_usec()
	_check(DirAccess.rename_absolute(blocked,restored)==OK,"Packed audit restores only the test-owned blocked path")
	await _key(KEY_F5)
	_check(not game.save_warning and not game.quit_pending,"Packed successful retry clears warning and stays in exploration")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(saved.player.coins==game.state.coins and game.state.coins==25,"Packed recovered write persists actual new progress")

func _v18_prerequisites() -> bool:
	var previous: int = failures
	_check(ProjectSettings.get_setting("application/config/version", "") == "0.0.18", "V18 project version is required")
	var model = load("res://scripts/game_state.gd")
	_check(model != null and model.SAVE_VERSION == 10, "V18 save schema10 is required")
	for module in ["heting_region", "heting_story", "heting_machinery_art", "heting_worksites_art", "world_material_tiles", "heting_cart_routes"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V18 module retained: " + module)
	for asset in ["heting_machinery_atlas", "heting_worksites_atlas"]:
		_check(ResourceLoader.exists("res://assets/generated/environment/" + asset + ".png"), "V18 painted asset retained: " + asset)
	return failures == previous

func _heting_open(id: String) -> void:
	if game.active_modal: game._close_modal()
	game.world.teleport(game.world.interactables[id].pos); game._process(0)
	var before: Dictionary = game.state.to_dict()
	await _key(KEY_E)
	_check(game.active_modal and game.state.to_dict() == before, "Packed E opens " + id + " without applying its choice")

func _test_heting_pack() -> void:
	var region = load("res://scripts/heting_region.gd")
	var tiles = load("res://scripts/world_material_tiles.gd")
	for pair in [["heting_machinery_art",Vector2(1024,512)],["heting_worksites_art",Vector2(512,320)]]:
		var art = load("res://scripts/" + pair[0] + ".gd")
		for id in art.SPRITES:
			var texture = art.texture_for(id)
			_check(texture != null and texture.atlas.get_size() == pair[1], "Packed harbor atlas dimensions: " + id)
			_check(texture == art.texture_for(id) and texture.region == art.SPRITES[id].region and texture.filter_clip, "Packed harbor cached crop: " + id)
			var foot := Vector2(820,690)
			var drawn: Rect2 = art.drawing_rect(id,foot)
			_check((drawn.position + art.SPRITES[id].foot * art.factor_for(id)).distance_to(foot) < .001, "Packed harbor foot anchor: " + id)
	var works = load("res://scripts/heting_worksites_art.gd")
	_check(works.drawing_rect("soup_pot_hot",Vector2.ZERO) == works.drawing_rect("soup_pot_cold",Vector2.ZERO), "Packed cooked pot swaps without position jump")
	_check(works.pot_id(false) == "soup_pot_cold" and works.pot_id(true) == "soup_pot_hot", "Packed pot state selects actual artwork")
	var surface := Rect2(590,565,440,270)
	var mesh: Dictionary = tiles.geometry(surface,160.0)
	_check(mesh.mesh == tiles.geometry(surface,160.0).mesh and mesh.tile_size == 160.0, "Packed material reuses world-scale mesh")
	_check(mesh.vertices.size() == mesh.uvs.size() and mesh.vertices.size() > 6, "Packed large deck keeps tiled rather than stretched sampling")
	for uv in mesh.uvs:
		_check(uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1, "Packed clipped material UV stays inside atlas")
	# Exercise both old water outcomes, both first-batch orders and both final plans.
	game.set_process(false); game.world.set_process(false)
	for water in ["release_water", "warn_ferries"]:
		_prepare_companion_chapter(true)
		var s = game.state
		s.mist_stage=4; s.mist_approach="duel"; s.mist_ending=water; s.mist_gauges.assign(["rain","stone","basin"])
		game._travel("mistwood",Vector2(1470,485)); game._stop_audio(); game.audio_on=false
		await _heting_open("exit_heting"); _press("走入鹤汀埠")
		_check(s.map_id == "heting" and s.heting_stage == 1 and game.world.map_id == "heting", "Packed actual fifth-region entry starts chapter")
		_check(s.heting_bridge == ("east" if water == "release_water" else "west"), "Packed prior water decision selects the initial pontoon")
		var order: Array = ["meal","sealed"] if water == "release_water" else ["sealed","meal"]
		for cargo in order:
			await _heting_open("heting_cargo")
			_press("押开锅粮" if cargo == "meal" else "押对秤封粮"); game._process(0)
			_check(s.heting_cargo == cargo and game.near_label.text.contains("查看货签"), "Packed loading refreshes stationary cargo hint")
			_check(is_equal_approx(game.toast_time,3.0), "Packed successful harbor work uses short feedback")
			game._process(3.1)
			_check(not game.hud.toast_wash.visible, "Packed ordinary success clears without obscuring continued exploration")
			_check(not game.world._can_walk(Vector2(805,500)), "Packed loaded cart cannot use pedestrian pier")
			await _heting_open("heting_winch")
			var next: String = "west" if s.heting_bridge == "east" else "east"
			_press("改接西岸" if next == "west" else "改接东岸")
			_check(s.heting_bridge == next and s.heting_cargo == cargo and game.world._can_walk(Vector2(450,730) if next == "west" else Vector2(1150,730)), "Packed winch changes real terrain while retaining cargo")
			var target: String = "heting_relief" if cargo == "meal" else "heting_scale"
			var wrong: String = "heting_scale" if cargo == "meal" else "heting_relief"
			await _heting_open(wrong)
			_check(game.world.interaction_verb(wrong) == "询问去处", "Packed wrong shore gives contextual guidance")
			await _key(KEY_ESCAPE); _check(s.heting_cargo == cargo, "Packed canceled wrong-shore discussion keeps cargo")
			await _heting_open(target)
			_check(game.world.interaction_verb(target) == "商议交粮", "Packed receiver labels a discussion, not automatic delivery")
			_press("交下开锅粮" if cargo == "meal" else "交粮当面复称")
			_check(s.heting_cargo.is_empty() and s.heting_delivered.has(cargo), "Packed explicit delivery records only its batch")
			_press("收好货签")
		_check(s.heting_stage == 2 and s.heting_delivered.size() == 2, "Packed base batches unlock night discussion")
		await _heting_open("heting_dispatch")
		var plan: String = "short_ferries" if water == "release_water" else "open_scale"
		_press("拟作短渡分粮" if plan == "short_ferries" else "拟作守秤留粮"); await _key(KEY_ESCAPE)
		await _heting_open("heting_lighter"); _press("押待分粮")
		_check(s.heting_stage == 3 and s.heting_draft == plan and s.heting_ending.is_empty(), "Packed loaded final batch does not lock the draft")
		game._show_map(); await process_frame
		var loaded_chart=game.overlay.find_child("RegionChart",true,false)
		var route:PackedVector2Array=loaded_chart.cart_route
		_check(loaded_chart.heting_cargo=="reserve" and route.size()>1 and route[0]==game.world.player_pos and route[-1]==loaded_chart.markers[loaded_chart.current_target].pos, "Packed loaded chart guides the actual cart to its intended receiver")
		var safe:bool=not route.is_empty()
		for i in range(1,route.size()):
			if not region.can_step(route[i-1],route[i],s.heting_bridge,true):safe=false
		_check(safe,"Packed map route never crosses unavailable water or pedestrian-only pier")
		await _key(KEY_1)
		_check(not game.active_modal and s.heting_cargo=="reserve", "Packed route map keeps numeric close and loaded cargo")
		game.world.teleport(Vector2(820,665)); game._save()
		var saved: Dictionary = s.to_dict()
		var document = JSON.parse_string(FileAccess.get_file_as_string(s.SAVE_PATH))
		_check(document.version == 10, "Packed autosave writes schema10")
		game.world.heting_bridge = "east" if s.heting_bridge == "west" else "west"; game.world.heting_cargo=""
		game._load()
		_check(s.to_dict() == saved and game.world.heting_bridge == s.heting_bridge and game.world.heting_cargo == "reserve", "Packed reload applies saved cargo and bridge before coordinate repair")
		var receiver: String = "heting_relief" if plan == "short_ferries" else "heting_scale"
		await _heting_open(receiver); await _key(KEY_ESCAPE)
		_check(s.heting_stage == 3 and s.heting_cargo == "reserve", "Packed final confirmation can still be canceled")
		await _heting_open(receiver)
		var stale: Callable = game.modal_actions[0]
		_press("照此交割")
		_check(s.heting_stage == 4 and s.heting_ending == plan and s.heting_delivered.size() == 3, "Packed final branch completes exactly once")
		var complete: Dictionary = s.to_dict(); stale.call()
		_check(s.to_dict() == complete, "Packed stale delivery callback cannot duplicate rewards")
		await _key(KEY_ESCAPE); game._show_map(); await process_frame
		var chart = game.overlay.find_child("RegionChart",true,false)
		_check(chart != null and chart.map_id == "heting" and chart.heting_bridge == s.heting_bridge and chart.markers.size() == 7, "Packed paper chart retains actual harbor topology and seven sites")
		await _key(KEY_1)
		_check(not game.active_modal, "Packed harbor map keeps numeric close control")
	game.set_process(true); game.world.set_process(true)
	# Exercise real loader documents inside this fresh audit's isolated user dir.
	game._new_game()
	var model = load("res://scripts/game_state.gd")
	var probe = model.new()
	var player: Dictionary = game.state.to_dict()
	var path := "user://v18-migration-audit.json"
	var file = FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"version":9,"player":player})); file.close()
	_check(probe.load_game(path) == OK and probe.to_dict() == player, "Packed reader accepts complete legitimate v9 progress")
	var stable: Dictionary = probe.to_dict()
	for version in [10,11]:
		var corrupt: Dictionary = player.duplicate(true)
		if version == 10: corrupt.erase("heting_bridge")
		file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"version":version,"player":corrupt})); file.close()
		var bytes = FileAccess.get_file_as_bytes(path)
		_check(probe.load_game(path) != OK and probe.to_dict() == stable and FileAccess.get_file_as_bytes(path) == bytes, "Packed invalid/future schema preserves memory and source bytes")
