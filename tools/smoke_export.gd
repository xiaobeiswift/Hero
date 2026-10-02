extends SceneTree
## External PCK test driver: never bundled in the release PCK. Requires isolated XDG paths.
## The editor loads the exported PCK; release-template binaries do not support --script.
const SCHEMA9_READER_SHA256 := "fd5d6da903a8d24a16ecd5774642c2e5e2bc792a084807734ba6caa95f972f4f"
const SCHEMA12_READER_SHA256 := "7872904b27c52b2fe038b6f355a371ca8e9f90d1054c3be24a5dd912bea8a02a"
var _unified_tokens: Dictionary = {}
var _unified_basics: Dictionary = {}
var _unified_skills: Dictionary = {}
var _unified_basic_encounters: Dictionary = {}
var _unified_facts_ok: bool = true
var checks := 0
var failures := 0
var game
var legacy_reader
var schema9_reader
var schema12_reader
var schema11_reader
const SCHEMA11_READER_SHA256 := "fbd0cef61329356ba3f7fd17bf2fa861ddd149d4d565916711685e0c4c5aac30"
const LEGACY_READER_SHA256 := "e20c24c3cf7ac0cfc83f4a3ab453cad6f9e8c61e116f13d12b22576bd4d1b0a5"

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
		print("SOURCE REHEARSAL: PENDING exactly5 packaging-only assertions until exact final PCK; no exported-pack claim")
	else:
		_check(FileAccess.file_exists("res://project.binary"), "Must load the exported binary project")
		_check(not DirAccess.dir_exists_absolute("res://tests"), "Test scripts excluded")
		_check(not DirAccess.dir_exists_absolute("res://tools"), "Build tools excluded")
		_check(not DirAccess.dir_exists_absolute("res://screenshots"), "Screenshots excluded")
		_check(not DirAccess.dir_exists_absolute("res://builds"), "Build outputs excluded")
	# A stale pack must fail before instantiating a scene or creating a save.
	if not _v22_prerequisites():
		print("FAIL: v22 prerequisites; %d checks; %d failures; no game instantiated" % [checks,failures])
		quit(1); return
	if not _receipt_legacy_prerequisite(rehearsal) or not _party_legacy_prerequisite(rehearsal) or not _schema12_legacy_prerequisite(rehearsal) or not _schema9_legacy_prerequisite(rehearsal):
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
	if OS.get_cmdline_user_args().has("--unified-only"):
		await _test_unified_pack()
		await _finish_run(rehearsal, "unified-only")
		return
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
	var starter = _unified_open_training()
	_check(starter != null and game.current_screen == "party_battle", "Current unified training controller opens")
	var starter_tx: Dictionary = _unified_begin(starter, false); _party_finish(starter)
	_check(starter_tx.accepted and starter_tx.action_id == "attack", "No-input basic resolves through real renderer")
	_unified_leave()
	_check(not game.state.battle_active and game.current_screen == "explore", "Current retreat returns to exploration")
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
	await _talk("chapter_clerk")
	_check(game.active_modal and game.modal_actions.size()==2, "Packed clerk dialogue opens")
	game.modal_actions[0].call()
	_check(game.state.archive_clues.has("clerk"), "Packed clerk choice records evidence")
	await _talk("chapter_inscription")
	game.modal_actions[0].call()
	_check(game.state.archive_clues.size()==2, "Packed inscription records second clue")
	await _talk("chapter_archive")
	_check(game.modal_actions.size()==4, "Packed seal controls appear")
	game.modal_actions[2].call()
	game.modal_actions[0].call()
	game.modal_actions[1].call()
	_check(game.state.chapter_two_stage==2, "Packed seal puzzle opens archive")
	game._close_modal()
	_check(game.state.save_game()==OK and game.state.load_game()==OK and game.state.bridge_repaired, "Packed schema2 chapter progress saves and reloads")
	# Preserved noncombat suites retain shipped assets, actual stories, menus,
	# local save/backup semantics, exploration and recruitment. Superseded manual
	# combat assertions are replaced by the separately marked unified suite.
	var retained_first: int = checks
	_test_modules()
	await _test_companion_route("teach", false)
	await _test_companion_route("preserve", true)
	await _test_advanced_martials()
	await _test_mistwood()
	await _test_manual_slots()
	await _test_portraits()
	_test_story_traversal_modules()
	await _test_shen_care_route("shore", "rescue", "守望")
	await _test_shen_care_route("mobile", "pursuit", "秉公")
	await _test_lightness_exploration()
	await _test_visual_runtime()
	await _test_painted_hud_pack()
	await _test_party_inventory_pack()
	_test_painted_combat_pack()
	await _test_rest_support_pack()
	await _test_village_finish_pack()
	await _test_courtyard_props_pack()
	await _test_reading_party_pack()
	await _test_clear_visibility_pack()
	await _test_tang_combat_pack()
	await _test_martial_folio_pack()
	await _test_close_guard_pack()
	await _test_heting_pack()
	_test_party_assets_pack()
	await _test_party_roster_pack()
	await _test_party_qin_recruitment_pack()
	_test_receipt_migration_pack()
	_test_party_migration_pack()
	print("Preserved noncombat exact-runtime coverage: %d checks; original asset/story/recruitment/menu/save assertions adapted to current schema" % (checks-retained_first))
	if OS.get_cmdline_user_args().has("--preserved-only"):
		await _finish_run(rehearsal, "preserved-only")
		return
	await _test_unified_pack()
	await _finish_run(rehearsal)

func _finish_run(rehearsal: bool, scope: String = "complete") -> void:
	print("Audit scope: " + scope + "; prepared state/input only; no browser or physical desktop-close claim")
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
	var folio = game.overlay.get_meta("party_roster", null)
	_check(folio != null and not folio.cells.tang.toggle.disabled and folio.cells.shen.toggle.disabled == not shen and folio.cells.qin.toggle.disabled, "Packed roster enables only genuinely recruited companions: " + choice)
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
	_roster_select_only("shen")
	game._close_modal()
	game._process(0)
	await process_frame
	await process_frame
	_check(game.state.current_companion() == "沈青" and game.state.hp == hp and game.state.qi == qi, "Packed roster selection preserves resources: " + choice)
	_check(game.world.nearby_name == "药铺伙计" and game.near_label.text.contains("药铺伙计"), "Packed selection refreshes clinic prompt: " + choice)
	game._show_inventory()
	await _key(KEY_5)
	_roster_select_only("tang")
	game._close_modal()
	game._save()
	game._load()
	game._process(0)
	await process_frame
	_check(game.state.current_companion() == "唐栖" and game.state.formation == "护后" and game.world.nearby_name == "沈青", "Packed selected companion, formation and clinic identity persist: " + choice)
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://hero_save.json"))
	_check(saved is Dictionary and saved.get("version") == 13 and saved.get("player", {}).get("active_companion") == "唐栖", "Packed save writes schema13 and active party identity: " + choice)
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
	var panel = _party_panel(); _unified_freeze(panel)
	_check(panel != null and panel.encounter == "mist_keeper", "Packed actual keeper uses unified controller")
	var tx: Dictionary = _unified_begin(panel, false); _party_finish(panel)
	_check(tx.accepted and tx.action_id == "attack", "Packed keeper begins by automatic basic without manual attack")
	_unified_leave()
	game._close_modal()
	game._load()
	_check(game.state.mist_stage == 2, "Packed keeper retreat and reload keep encounter retryable")
	await _talk("mist_camp")
	_press("避雨调息")
	await _talk("mist_gate")
	_press("请他交出底稿")
	panel = _party_panel(); _unified_freeze(panel)
	var terminal: Dictionary = _sluice_terminal(panel); _party_finish(panel)
	_check(not game.state.battle_active and terminal.after.outcome == "win" and game.state.mist_stage == 3 and _gather_text(game.overlay).contains("底稿"), "Packed unified keeper is winnable and grants story evidence")
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
	_check(saved is Dictionary and saved.get("version") == 13 and saved.get("player", {}).get("mist_ending") == "warn_ferries", "Packed local save writes schema13 and Mistwood ending")
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
	game._process(0)
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
	_check(first_doc is Dictionary and first_doc.get("version") == 13 and first_doc.player.coins == 24, "Packed manual save writes the current schema and branch")
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
	var automatic = _unified_open_training()
	var battle_state: Dictionary = game.state.to_dict()
	var battle_files := _manual_file_snapshot(store)
	await _key(KEY_F6)
	await _key(KEY_F10)
	_check(game.state.battle_active and game.current_screen == "party_battle" and automatic.valid(), "Packed manual shortcuts are blocked in combat")
	game.save_slots.save_page()
	game.save_slots.load_page()
	game.save_slots.detail(1)
	game.save_slots.request_save(1)
	game.save_slots.request_load(1, false)
	game.save_slots.perform_save(1)
	game.save_slots.perform_load(1, true)
	_check(automatic.valid() and game.state.to_dict() == battle_state, "Packed direct slot UI entry points cannot change combat state")
	_check(store.save_slot(game.state, 1) == ERR_BUSY and store.load_slot(game.state, 1) == ERR_BUSY and store.load_backup(game.state, 1) == ERR_BUSY, "Packed storage API blocks battle saves, primary loads and backups")
	_check(_manual_file_snapshot(store) == battle_files, "Packed blocked battle actions leave all primary and backup bytes unchanged")
	_unified_leave()
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
	var care_folio = game.overlay.get_meta("party_roster", null)
	_check(care_folio != null and care_folio.cells.shen.story.visible, "Packed roster exposes Shen story")
	if care_folio != null: care_folio.cells.shen.story.pressed.emit()
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
	_check(saved is Dictionary and saved.get("version") == 13 and saved.player.shen_care_stage == 5 and saved.player.shen_care_choice == choice, "Packed schema13 document records the final care plan: " + choice)
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
	var care_snapshot: Dictionary = game.state.party_resource_snapshot()
	var care_actor: Dictionary = _party_actor(care_snapshot,"shen")
	_check(care_actor.care_defense_bonus == (1 if choice == "shore" else 0) and care_actor.care_healing_bonus == (2 if choice == "mobile" else 0), "Packed roster projects independent Shen care bonuses: " + choice)
	game._close_modal()
	_check(game.state.xp == 40 and game.state.coins == 24 and game.state.resources == completed.resources, "Packed aftermath revisits preserve one-time rewards and materials: " + choice)

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
	_press("内功与轻身"); _press("轻功 · 踏苇行")
	_check(_find_button(game.overlay, "修习踏苇行") == null and not game.state.lightness_unlocked, "Packed level-one disciple cannot learn lightness early")
	game._close_modal()
	game.state.gain_xp(180)
	game.state.recruit_companion()
	game.state.sect_trial_won = true
	game._refresh()
	await _talk("mentor")
	_check(_find_button(game.overlay, "领取内门荐记") != null and _find_button(game.overlay, "稍后领取") != null, "Packed pending-promotion mentor retains both receipt actions")
	_press("内功与轻身"); _press("轻功 · 踏苇行")
	_check(_gather_text(game.overlay).contains("不收费") and _gather_text(game.overlay).contains("不改变普通行走碰撞"), "Packed lesson explains its price and explicit traversal limits")
	var stale_learn: Callable = game.modal_actions[0]
	await _key(KEY_ESCAPE)
	stale_learn.call()
	_check(not game.state.lightness_unlocked and game.state.sect_rank == 1 and game.state.sect_trial_won, "Packed cancelled lightness lesson grants nothing and preserves pending promotion")
	await _talk("mentor")
	_press("内功与轻身"); _press("轻功 · 踏苇行")
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
	_press("内功与轻身"); _press("轻功 · 踏苇行")
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
	_check(saved is Dictionary and saved.get("version") == 13 and saved.player.lightness_unlocked and saved.player.lightness_relics == [lightness.RELIC_ID], "Packed schema13 document writes lightness progression explicitly")
	_unified_open_training()
	before = game.state.to_dict()
	game.lightness_story.cross(true)
	_check(game.state.battle_active and game.state.to_dict() == before, "Packed traversal callback cannot escape combat or change its resources")
	_unified_leave()
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
	game._close_modal()

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
	game.state.quest_stage=6;game.state.side_stage=3;game.state.chapter_two_stage=4;game.state.bridge_repaired=true;game.state.tangqi_stage=3;game.state.tangqi_choice="preserve";game.state.recruit_tangqi();game.state.select_companion("唐栖");game._sync_world_state()
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

func _v22_prerequisites() -> bool:
	var previous: int = failures
	_check(ProjectSettings.get_setting("application/config/version", "") == "0.0.22", "V22 unified automatic project version is required")
	var model = load("res://scripts/game_state.gd")
	_check(model != null and model.SAVE_VERSION == 13, "V22 requires save schema13")
	for module in ["heting_region", "heting_story", "heting_machinery_art", "heting_worksites_art", "world_material_tiles", "heting_cart_routes"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V18 module retained: " + module)
	for asset in ["heting_machinery_atlas", "heting_worksites_atlas"]:
		_check(ResourceLoader.exists("res://assets/generated/environment/" + asset + ".png"), "V18 painted asset retained: " + asset)
	for module in ["courtyard_exercise_rules", "courtyard_practice_ui", "courtyard_practice_art", "courtyard_training_rigs", "courtyard_practice_backdrop"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V19 courtyard module retained before scene load: " + module)
	for module in ["heting_receipt_rules", "heting_receipt_combat", "heting_receipt_story", "heting_receipt_ui", "heting_receipt_art"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V20 receipt module retained before scene load: " + module)
	for module in ["automatic_party_combat", "unified_encounter_rules", "party_category_hud", "party_actor_catalog", "party_roster_rules", "party_combat_rules", "party_battle_art", "party_battle_ui", "party_command_hud", "party_roster_ui", "qin_companion_rules", "qin_companion_story", "painted_battle_qin"]:
		_check(ResourceLoader.exists("res://scripts/"+module+".gd"), "Schema12 party module retained before scene load: "+module)
	for asset in ["res://assets/generated/characters/painted_qin_combat.png", "res://assets/ui/qin_commands_painted_atlas.png", "res://assets/ui/companion_commands_painted_atlas.png"]:
		_check(ResourceLoader.exists(asset), "Four-actor original artwork retained: "+asset)
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
		_check(document.version == 13, "Packed autosave writes schema13")
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
	for version in [10,14]:
		var corrupt: Dictionary = player.duplicate(true)
		if version == 10: corrupt.erase("heting_bridge")
		file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"version":version,"player":corrupt})); file.close()
		var bytes = FileAccess.get_file_as_bytes(path)
		_check(probe.load_game(path) != OK and probe.to_dict() == stable and FileAccess.get_file_as_bytes(path) == bytes, "Packed invalid/future schema preserves memory and source bytes")

func _courtyard_source_snapshot() -> Dictionary:
	var variables: Dictionary = {}
	for property: Dictionary in game.state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = String(property.name)
			var value: Variant = game.state.get(name)
			variables[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"save":game.state.to_dict().duplicate(true),"all_variables":variables}

func _courtyard_save_files() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["user://hero_save.json","user://hero_slot_1.json","user://hero_slot_2.json","user://hero_slot_3.json"]:
		for suffix: String in ["",".bak"]:
			var exists: bool = FileAccess.file_exists(path+suffix)
			result[path+suffix] = {"exists":exists,"bytes":FileAccess.get_file_as_bytes(path+suffix) if exists else PackedByteArray()}
	return result

func _receipt_legacy_prerequisite(rehearsal: bool) -> bool:
	# The pinned historical reader is external evidence, never a release resource.
	# Export callers can set this environment variable without changing builders.
	var path: String = OS.get_environment("HERO_AUDIT_LEGACY_READER")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-reader="): path = argument.trim_prefix("--legacy-reader=")
	if path.is_empty() and rehearsal: path = ProjectSettings.globalize_path("res://tests/fixtures/v019_game_state.gd.txt")
	_check(path.is_absolute_path() and FileAccess.file_exists(path), "V20 audit requires explicit external frozen v0.0.19 reader")
	if not path.is_absolute_path() or not FileAccess.file_exists(path): return false
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	var digest: String = hash.finish().hex_encode()
	_check(digest == LEGACY_READER_SHA256, "External historical reader matches its pinned SHA-256")
	if digest != LEGACY_READER_SHA256: return false
	var script = GDScript.new()
	script.source_code = bytes.get_string_from_utf8().replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Pinned historical reader compiles against loaded runtime dependencies")
	if error != OK: return false
	legacy_reader = script.new()
	_check(legacy_reader.SAVE_VERSION == 10, "Pinned historical reader retains its genuine schema10 gate")
	return legacy_reader.SAVE_VERSION == 10

func _receipt_prepare(ending: String = "short_ferries") -> void:
	game._new_game()
	var s = game.state
	s.quest_stage=6; s.ending="守望"; s.side_stage=3; s.side_choice="rescue"
	s.side_reward_claimed=true; s.side_found.assign(["boatman","ledger"]); s.side_clues=2
	s.chapter_two_stage=4; s.chapter_two_ending="protect_witness"
	s.archive_clues.assign(["clerk","inscription"]); s.seal_sequence.assign([2,0,1])
	s.mist_stage=4; s.mist_gauges.assign(["rain","stone","basin"])
	s.mist_approach="duel"; s.mist_ending="release_water"
	s.heting_stage=4; s.heting_bridge="east"; s.heting_delivered.assign(["meal","sealed","reserve"])
	s.heting_draft=ending; s.heting_ending=ending; s.map_id="heting"
	game._sync_world_state(); game.world.change_map("heting",Vector2(1150,735))
	game.world.teleport(game.world.interactables.heting_scale.pos+Vector2(-40,0))
	s.position=game.world.player_pos; game._refresh(); game._stop_audio(); game.audio_on=false
	_check(game.receipt_story._at_scale() and s._valid_save_data(s.to_dict(),13), "Packed prepared receipt fixture has legitimate harbor progress: "+ending)
	_check(s.save_game()==OK, "Packed receipt fixture checkpoint uses isolated storage")

func _receipt_bytes() -> PackedByteArray: return FileAccess.get_file_as_bytes(game.state.SAVE_PATH)
func _receipt_xp() -> int: return game.state.xp+30*game.state.level*(game.state.level-1)
func _receipt_document() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(game.state.SAVE_PATH))

func _receipt_block_save() -> String:
	var path: String = ProjectSettings.globalize_path(game.state.SAVE_PATH+".tmp")
	var error: Error = DirAccess.make_dir_absolute(path)
	_check(error==OK, "Packed receipt injects a real isolated temporary-path write failure")
	return path if error==OK else ""

func _receipt_unblock_save(path: String) -> void:
	_check(not path.is_empty() and DirAccess.rename_absolute(path,path+".receipt-audit-%d"%Time.get_ticks_usec())==OK, "Packed receipt restores only its test-owned write blocker")

func _receipt_variables(state) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = state.get(property.name)
			result[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _test_receipt_migration_pack() -> void:
	_receipt_prepare(); var model = load("res://scripts/game_state.gd"); var probe = model.new()
	var current: Dictionary = game.state.to_dict(); var legacy: Dictionary = current.duplicate(true)
	for key: String in ["receipt_stage", "party_roster", "party_resources", "qin_stage", "qin_unlocked","internal_unlocked"]: legacy.erase(key)
	var path: String = "user://receipt-schema-audit.json"
	for version: int in range(1,11):
		_receipt_write_document(path,{"version":version,"player":legacy})
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		_check(probe.load_game(path)==OK and probe.receipt_stage==0 and probe.to_dict()==current and FileAccess.get_file_as_bytes(path)==bytes, "Packed schema1–10 migration defaults receipt without altering legacy bytes: "+str(version))
	_receipt_write_document(path,{"version":10,"player":legacy})
	_check(legacy_reader.load_game(path)==OK and legacy_reader.to_dict()==legacy, "Pinned actual old reader accepts its own schema10 control")
	legacy_reader.coins=4242; legacy_reader.battle_active=true; legacy_reader.enemy_hp=37; legacy_reader.turn=6
	var old_before: Dictionary = _receipt_variables(legacy_reader)
	for ending: String in ["short_ferries","open_scale"]:
		_receipt_prepare(ending)
		for stage: int in range(4):
			game.state.receipt_stage=stage
			_check(game.state.save_game(path)==OK, "Packed writer creates actual schema13 receipt stage: "+ending+"/"+str(stage))
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			_check(probe.load_game(path)==OK and probe.to_dict()==game.state.to_dict(), "Packed schema13 stage round-trip preserves exact durable fields")
			_check(legacy_reader.load_game(path)==ERR_FILE_UNRECOGNIZED and _receipt_variables(legacy_reader)==old_before and FileAccess.get_file_as_bytes(path)==bytes and not FileAccess.file_exists(path+".tmp"), "Pinned old reader rejects actual new save before mutating memory or bytes")
	var stable: Dictionary = probe.to_dict()
	for bad: Variant in [-1,4,1.5,"1",true,null]:
		var corrupt: Dictionary = current.duplicate(true); corrupt.receipt_stage=bad
		_receipt_reject_document(probe,path,{"version":13,"player":corrupt},stable,"malformed receipt stage "+str(bad))
	_receipt_reject_document(probe,path,{"version":13,"player":legacy},stable,"missing current receipt field")
	_receipt_reject_document(probe,path,{"version":14,"player":current},stable,"future schema14")
	var impossible: Dictionary = current.duplicate(true); impossible.receipt_stage=1; impossible.heting_stage=3
	_receipt_reject_document(probe,path,{"version":13,"player":impossible},stable,"receipt before harbor ending")

func _receipt_write_document(path: String, document: Dictionary) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	_check(file!=null, "Packed migration fixture writes only in isolated profile")
	if file!=null: file.store_string(JSON.stringify(document)); file.close()

func _receipt_reject_document(probe, path: String, document: Dictionary, stable: Dictionary, label: String) -> void:
	_receipt_write_document(path,document)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check(probe.load_game(path)!=OK and probe.to_dict()==stable and FileAccess.get_file_as_bytes(path)==bytes, "Packed rejection preserves live state and source bytes: "+label)

# Schema12 is tested through shipped resources and the unmodified main scene.
# Prepared completed chapters only establish eligibility; each invitation/action
# uses the real API or scene control. Historical adapters above remain scoped.
func _party_legacy_prerequisite(rehearsal: bool) -> bool:
	var path: String = OS.get_environment("HERO_AUDIT_SCHEMA11_READER")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema11-reader="): path = argument.trim_prefix("--schema11-reader=")
	if path.is_empty() and rehearsal: path = ProjectSettings.globalize_path("res://tests/fixtures/v020_game_state.gd.txt")
	_check(path.is_absolute_path() and FileAccess.file_exists(path), "Party audit requires external frozen schema11 reader")
	if not path.is_absolute_path() or not FileAccess.file_exists(path): return false
	_check(FileAccess.get_sha256(path) == SCHEMA11_READER_SHA256, "Exact schema11 reader matches frozen pre-party source SHA256")
	if FileAccess.get_sha256(path) != SCHEMA11_READER_SHA256: return false
	var script = GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Exact schema11 reader compiles with only global registration removed")
	if error != OK: return false
	schema11_reader = script.new()
	_check(schema11_reader.SAVE_VERSION == 11, "Frozen pre-party reader retains its actual schema11 gate")
	return schema11_reader.SAVE_VERSION == 11

func _party_actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.get("actors", []):
		if actor.id == id: return actor
	return {}

func _party_unit(snapshot: Dictionary, id: String) -> Dictionary:
	for unit: Dictionary in snapshot.get("actors", []) + snapshot.get("enemies", []):
		if unit.id == id: return unit
	return {}

func _roster_select_only(id: String) -> void:
	var folio = game.overlay.get_meta("party_roster", null)
	_check(folio != null, "Packed actual roster folio exists")
	if folio == null: return
	for other: String in ["shen", "tang", "qin"]:
		if game.state.party_roster.has(other) and other != id: folio.cells[other].toggle.pressed.emit()
	if not game.state.party_roster.has(id): folio.cells[id].toggle.pressed.emit()
	_check(game.state.party_roster == ["hero", id], "Packed real roster buttons select only " + id)

func _party_prepare(count: int = 4, encounter: String = "training", ending: String = "short_ferries") -> void:
	_prepare_companion_chapter(true)
	var s = game.state
	_check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Packed Tang enters through personal quest and explicit invitation")
	s.mist_stage = 4; s.mist_ending = "release_water"; s.mist_approach = "duel"; s.mist_gauges.assign(["rain", "stone", "basin"])
	s.map_id = "mistwood"
	_check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Packed Qin enters only after actual quest and explicit invitation")
	_check(s.set_party_roster(["hero", "shen", "tang", "qin"].slice(0,count)), "Packed selects exactly %d recruited actors" % count)
	if encounter == "heting_receipt":
		s.heting_stage = 4; s.heting_bridge = "east"; s.heting_draft = ending; s.heting_ending = ending
		s.heting_delivered.assign(["meal", "sealed", "reserve"]); s.map_id = "heting"
		_check(s.begin_receipt(), "Packed party accepts optional receipt after actual harbor ending")
		game._sync_world_state(); game.world.change_map("heting", Vector2(1150,735))
		game.world.teleport(game.world.interactables.heting_scale.pos + Vector2(-40,0))
	else:
		s.map_id = "qingwei"; s.quest_stage = 3 if encounter == "story" else 6
		game._sync_world_state(); game.world.change_map("qingwei", Vector2(955,630))
		game.world.teleport(game.world.interactables.bandit.pos + Vector2(0,24))
	s.position = game.world.player_pos; s.heal_rest(); game._refresh(); game._stop_audio(); game.audio_on = false

func _party_panel(): return game.overlay.get_meta("party_battle") if game.overlay.has_meta("party_battle") else null

func _party_open(encounter: String = "training"):
	# Enter with the real default story callback, never the retained adapter.
	game._interact("heting_scale" if encounter == "heting_receipt" else "bandit")
	if encounter == "heting_receipt":
		_press("复签应战准备"); _press("保存后应战")
	else: _press("拔剑 · 迎战" if encounter == "story" else "友好切磋")
	var panel = _party_panel()
	_check(panel != null and game.current_screen == "party_battle" and game.state.battle_active, "Packed default story enters real party controller: " + encounter)
	if panel != null: _unified_freeze(panel)
	return panel

func _party_finish(panel) -> void:
	_check(is_instance_valid(panel) and not panel.pending.is_empty() and panel.art.is_presenting(), "Packed party action owns a real pending presentation")
	if is_instance_valid(panel) and panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration() + .1)

func _test_party_assets_pack() -> void:
	var qin = load("res://scripts/painted_battle_qin.gd")
	for pose: String in qin.SOURCE_RECTS:
		var texture = qin.texture_for(pose)
		_check(texture != null and texture.atlas.get_size() == Vector2(1536,1024) and texture.region == qin.SOURCE_RECTS[pose] and texture.filter_clip, "Packed original Qin pose retains full staff crop: " + pose)
		_check(texture == qin.texture_for(pose) and ResourceLoader.has_cached(qin.PATH), "Packed Qin pose and source texture remain cached: " + pose)
		var foot := Vector2(580,435); var scale: float = 230.0/512.0*qin.NORMALIZATION
		var rect: Rect2 = qin.drawing_rect(foot,230,pose)
		_check((rect.position + (qin.FOOT_ANCHORS[pose]-qin.SOURCE_RECTS[pose].position)*scale).distance_to(foot) < .001, "Packed Qin pose shares exact authored foot anchor: " + pose)
		_check(rect.encloses(qin.opaque_rect(foot,230,pose)) and rect.grow(1).has_point(qin.weapon_point(foot,230,pose)), "Packed Qin silhouette and staff anchor stay within crop: " + pose)
	var hud = load("res://scripts/party_category_hud.gd")
	_check(hud.MAX_ACTORS == 4 and hud.QIN_ATLAS.get_size().x > 0 and hud.COMPANION_ATLAS.get_size().x > 0, "Packed command HUD includes all four actual actor arts")

func _test_party_roster_pack() -> void:
	game._new_game(); game._show_inventory(); await _key(KEY_5)
	var folio = game.overlay.get_meta("party_roster", null)
	_check(folio != null and folio.summary.text.contains("1 / 4"), "Packed fifth inventory entry opens actual four-person roster")
	if folio == null: return
	var before: Dictionary = game.state.to_dict()
	for id: String in ["shen", "tang", "qin"]:
		_check(folio.cells[id].toggle.disabled and folio.cells[id].empty.visible and not folio.cells[id].portrait.visible, "Packed unrecruited slot is explicit and never an actor: " + id)
		folio.cells[id].toggle.pressed.emit()
	_check(game.state.to_dict() == before, "Packed unavailable actor controls cannot create or recruit anyone")
	game._close_modal(); _party_prepare()
	game.state.party_resources.shen = {"hp":7,"qi":0}; game.state.party_resources.tang = {"hp":0,"qi":1}; game.state.party_resources.qin = {"hp":9,"qi":2}
	game._show_inventory(); await _key(KEY_5); folio = game.overlay.get_meta("party_roster", null)
	_check(folio != null and folio.summary.text.contains("4 / 4"), "Packed all four explicitly recruited actors occupy their real cells")
	if folio == null: return
	before = game.state.to_dict()
	for id: String in ["hero", "shen", "tang", "qin"]:
		var actor: Dictionary = _party_actor(game.state.party_resource_snapshot(),id)
		_check(folio.cells[id].portrait.visible and folio.cells[id].hp_bar.value == actor.hp and folio.cells[id].qi_bar.value == actor.qi, "Packed roster displays own real HP/qi: " + id)
	var stale: Callable = folio._toggle_actor.bind("qin")
	folio.cells.qin.toggle.pressed.emit(); folio.cells.qin.toggle.pressed.emit()
	_check(game.state.party_roster == before.party_roster and game.state.party_resources == before.party_resources, "Packed bench/reselect preserves Qin and every other injured resource")
	_check(folio.cells.tang.status.text.contains("倒下") and folio.cells.tang.hp_bar.value == 0, "Packed downed companion stays down in actual roster")
	folio.formation_buttons["护后"].pressed.emit()
	_check(game.state.formation == "护后" and _receipt_document().version == 13, "Packed roster formation writes current schema13 checkpoint")
	game._close_modal(); before = game.state.to_dict(); stale.call()
	_check(game.state.to_dict() == before, "Packed dismissed roster callback cannot change selection or resources")

func _test_party_qin_recruitment_pack() -> void:
	for ending: String in ["release_water", "warn_ferries"]:
		_prepare_companion_chapter(true)
		var s = game.state
		_check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("preserve") and s.recruit_tangqi(), "Packed Qin story fixture really invites existing Tang")
		s.mist_stage = 4; s.mist_ending = ending; s.mist_approach = "duel"; s.mist_gauges.assign(["rain","stone","basin"])
		game._travel("mistwood",Vector2(970,260)); s.set_party_roster(["hero"])
		s.hp = 17; s.qi = 1; s.party_resources.shen = {"hp":3,"qi":0}; s.party_resources.tang = {"hp":4,"qi":1}
		var before: Dictionary = s.to_dict(); var xp: int = _receipt_xp()
		await _talk("mist_guide")
		_check(_find_button(game.overlay,"帮她复核尺绳") != null and not s.qin_unlocked, "Packed original Qin dialogue offers optional work after " + ending)
		var stale: Callable = game.modal_actions[0]; await _key(KEY_ESCAPE); stale.call()
		_check(s.qin_stage == 0 and not s.qin_unlocked, "Packed canceled Qin acceptance cannot be replayed")
		var landmarks: Array = ["mist_guide","mist_rain_gauge","mist_camp","mist_guide"]
		var choices: Array = ["帮她复核尺绳","核好尺绳，记下轮值要点","确认轮值交接","邀请秦禾同行"]
		for index: int in range(4):
			await _talk(landmarks[index]); _press(choices[index])
			_check(s.qin_stage == index+1 and s.qin_unlocked == (index==3), "Packed Qin stage advances only through its actual explicit choice: " + str(index+1))
			_check(_receipt_document().version == 13 and s.load_game() == OK and s.qin_stage == index+1, "Packed Qin stage autosaves and reloads exactly")
			if index < 3: _check(s.party_roster == ["hero"] and not s.party_resources.has("qin"), "Packed work and handoff never silently recruit Qin")
		_check(s.party_roster == ["hero","qin"] and s.qin_recruited() and s.party_resources.size() == 3, "Packed final spoken invitation enrolls fourth real companion")
		_check(s.hp == before.hp and s.qi == before.qi and s.party_resources.shen == before.party_resources.shen and s.party_resources.tang == before.party_resources.tang, "Packed Qin story preserves existing hero and benched injuries")
		_check(s.coins == before.coins and _receipt_xp() == xp and s.medicine == before.medicine and s.resources == before.resources and s.mist_ending == ending, "Packed Qin invitation grants no invented reward or water-ending change")
		await _talk("mist_guide")
		_check(_find_button(game.overlay,"邀请秦禾同行") == null, "Packed completed Qin invitation is not repeatable")
		game._close_modal()

func _test_party_migration_pack() -> void:
	_prepare_companion_chapter(true)
	var s = game.state
	_check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Packed migration fixture really recruits both historical companions")
	s.hp=17; s.qi=1
	var model = load("res://scripts/game_state.gd"); var probe = model.new()
	var path: String = "user://schema12-party-audit.json"
	var historical: Dictionary = s.to_dict()
	for key: String in ["party_roster","party_resources","qin_stage","qin_unlocked","internal_unlocked"]: historical.erase(key)
	for version: int in range(1,12):
		for choice: String in ["沈青","唐栖",""]:
			var data: Dictionary = historical.duplicate(true); data.active_companion=choice
			_receipt_write_document(path,{"version":version,"player":data})
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			_check(probe.load_game(path)==OK and probe.party_roster==["hero","tang" if choice=="唐栖" else "shen"] and probe.hp==17 and probe.qi==1, "Packed schema%d migration preserves actual chosen companion and hero injury: %s" % [version,choice])
			_check(probe.party_resources.size()==2 and not probe.qin_unlocked and probe.qin_stage==0 and FileAccess.get_file_as_bytes(path)==bytes, "Packed legacy migration creates no Qin and never rewrites original bytes")
			for id: String in ["shen","tang"]:
				var actor: Dictionary = _party_actor(probe.party_resource_snapshot(),id)
				_check(probe.party_resources[id]=={"hp":actor.max_hp,"qi":actor.max_qi}, "Packed legacy resource initialization uses own catalog maxima: "+id)
	_receipt_write_document(path,{"version":11,"player":historical})
	_check(schema11_reader.load_game(path)==OK and schema11_reader.to_dict()==historical, "Frozen exact schema11 reader accepts its own complete historical control")
	var ignored: Dictionary = historical.duplicate(true); ignored.qin_stage=4; ignored.qin_unlocked=true
	_receipt_write_document(path,{"version":11,"player":ignored})
	_check(probe.load_game(path)==OK and probe.qin_stage==0 and not probe.qin_unlocked and not probe.party_resources.has("qin"), "Packed schema11 migration cannot smuggle future Qin recruitment")
	schema11_reader.coins=4242; schema11_reader.battle_active=true; schema11_reader.enemy_hp=37; schema11_reader.turn=6
	var frozen_before: Dictionary = _receipt_variables(schema11_reader)
	_party_prepare(); s=game.state
	s.party_resources.shen={"hp":0,"qi":0}; s.party_resources.tang={"hp":5,"qi":1}; s.party_resources.qin={"hp":9,"qi":2}
	for roster: Array in [["hero"],["hero","qin"],["hero","tang","shen"],["hero","shen","tang","qin"]]:
		_check(s.set_party_roster(roster) and s.save_game(path)==OK, "Packed actual schema13 serializes explicit%d actor roster" % roster.size())
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		_check(probe.load_game(path)==OK and probe.to_dict()==s.to_dict(), "Packed schema13 roundtrip preserves downed, benched and active own resources")
		_check(schema11_reader.load_game(path)==ERR_FILE_UNRECOGNIZED and _receipt_variables(schema11_reader)==frozen_before and FileAccess.get_file_as_bytes(path)==bytes and not FileAccess.file_exists(path+".tmp"), "Frozen exact schema11 reader rejects real schema13 before changing any live field or source bytes")
	var current: Dictionary = s.to_dict(); var stable: Dictionary = probe.to_dict()
	for key: String in current:
		var missing: Dictionary = current.duplicate(true); missing.erase(key)
		_receipt_reject_document(probe,path,{"version":13,"player":missing},stable,"missing schema13 field "+key)
	for roster: Variant in [[],["shen","hero"],["hero","hero"],["hero","ghost"],["hero","shen","tang","qin","hero"],"hero",null]:
		var invalid: Dictionary = current.duplicate(true); invalid.party_roster=roster
		_receipt_reject_document(probe,path,{"version":13,"player":invalid},stable,"malformed exact party roster")
	for value: Variant in [-1,.5,true,"1",1e50,null]:
		for field: String in ["hp","qi"]:
			var invalid: Dictionary = current.duplicate(true); invalid.party_resources.qin[field]=value
			_receipt_reject_document(probe,path,{"version":13,"player":invalid},stable,"malformed independent Qin "+field)
	for pair: Array in [[3,true],[4,false],[.5,false],[5,true]]:
		var invalid: Dictionary = current.duplicate(true); invalid.qin_stage=pair[0]; invalid.qin_unlocked=pair[1]
		_receipt_reject_document(probe,path,{"version":13,"player":invalid},stable,"inconsistent Qin recruitment pair")
	var forged: Dictionary = current.duplicate(true); forged.qin_stage=0; forged.qin_unlocked=false
	_receipt_reject_document(probe,path,{"version":13,"player":forged},stable,"unearned Qin actor or resources")
	for extra: String in ["party_session","party_battle_epoch","party_settlement"]:
		var invalid: Dictionary = current.duplicate(true); invalid[extra]={}
		_receipt_reject_document(probe,path,{"version":13,"player":invalid},stable,"transient battle field "+extra)
	_receipt_reject_document(probe,path,{"version":14,"player":current},stable,"future schema14 with valid current roster")

func _sluice_prepare(count: int = 2, boss: bool = false) -> void:
	game._new_game()
	var s = game.state
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁"); s.gain_xp(180)
	var recruited: bool = count == 1 or s.recruit_companion()
	s.formation = "并肩" if count == 2 else "护后"; s.heal_rest(); s.map_id = "sluice"
	game._sync_world_state(); game.world.change_map("sluice",Vector2(190,520)); s.position = game.world.player_pos
	if boss:
		s.choose_side_route("rescue"); s.find_side_clue("boatman"); s.find_side_clue("ledger")
	game._refresh(); game._stop_audio(); game.audio_on = false
	_check(recruited and s.party_roster == (["hero","shen"] if count == 2 else ["hero"]) and not s.tangqi_unlocked and not s.qin_recruited() and s._valid_save_data(s.to_dict(),13), "Packed sluice prepares only a legitimate completed opening and natural%d-actor roster" % count)

func _sluice_open(encounter: String):
	await _talk("ledger_runner" if encounter == "sluice_scout" else "sluice_boss")
	await _key(KEY_1)
	var panel = _party_panel()
	_check(panel != null and game.current_screen == "party_battle" and game.state.battle_active and panel.encounter == encounter, "Packed E/number enters actual sluice party controller: " + encounter)
	if panel == null: return null
	_unified_freeze(panel)
	var enemy: Dictionary = _party_unit(game.state.party_battle_snapshot(),encounter)
	_check(enemy.hp == (85 if encounter == "sluice_scout" else 150) and enemy.attack == (11 if encounter == "sluice_scout" else 16) and enemy.heavy_attack == (22 if encounter == "sluice_scout" else 28), "Packed actual opponent retains exact HP/light/heavy stats: " + encounter)
	_check(panel.commands.context.title == ("半页水令" if encounter == "sluice_scout" else "逆水而行") and panel.unit_plates.has(encounter) and not panel.unit_plates.has("puheng"), "Packed encounter HUD names its real opponent and story: " + encounter)
	_check(_receipt_document().version == 13 and _receipt_document().player.side_choice == game.state.side_choice and _receipt_document().player.side_found == game.state.side_found, "Packed pre-entry checkpoint includes current route and clue order")
	return panel

func _sluice_events(tx: Dictionary, kind: String, team: String = "") -> Array:
	var found: Array = []
	for event: Dictionary in tx.get("events",[]):
		if event.type == kind and (team.is_empty() or event.get("phase","") == team): found.append(event)
	return found

func _sluice_terminal(panel, expected: String = "win") -> Dictionary:
	var terminal: Dictionary = {}; var accepted: bool = true
	for index: int in range(500):
		if not game.state.battle_active: break
		terminal = _unified_begin(panel, expected == "win")
		if terminal.is_empty(): accepted = false; break
		if not terminal.after.active: break
		panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(accepted and not terminal.is_empty() and not terminal.after.active and terminal.after.outcome == expected, "Packed bounded earned-stat automatic actions reach pending " + expected + ": " + panel.encounter)
	return terminal

func _sluice_checkpoint(label: String) -> void:
	var s = game.state; var before: Dictionary = s.to_dict()
	_check(s.save_game() == OK, "Packed schema13 sluice checkpoint writes: " + label)
	var bytes: PackedByteArray = _receipt_bytes(); var document: Dictionary = _receipt_document()
	_check(document.version == 13 and document.player == JSON.parse_string(JSON.stringify(before)) and not bytes.get_string_from_utf8().contains("vulnerability") and not bytes.get_string_from_utf8().contains("_party_sluice_entry"), "Packed checkpoint keeps full canonical state and excludes battle-only fields: " + label)
	game._load()
	_check(s.to_dict() == before and not s.battle_active and s.party_session == null and s._party_sluice_entry.is_empty() and _receipt_bytes() == bytes, "Packed reload preserves actual resources/clue order and clears transient encounter: " + label)

func _test_sluice_entry_pack(encounter: String) -> void:
	_sluice_prepare(2,encounter == "sluice_boss")
	var s = game.state; var target: String = "ledger_runner" if encounter == "sluice_scout" else "sluice_boss"
	var before: Dictionary = s.to_dict()
	if encounter == "sluice_scout": game._runner_dialogue()
	else: game._sluice_boss_dialogue()
	game.modal_actions[0].call()
	_check(s.to_dict() == before and not s.battle_active, "Packed far sluice callback cannot change route or enter: " + encounter)
	game._close_modal(); await _talk(target); var stale: Callable = game.modal_actions[0]; before = s.to_dict()
	await _key(KEY_ESCAPE); stale.call()
	_check(s.to_dict() == before and not s.battle_active, "Packed canceled sluice callback cannot enter: " + encounter)
	await _talk(target); stale = game.modal_actions[0]; before = s.to_dict(); game._show_map(); stale.call()
	_check(s.to_dict() == before and not s.battle_active, "Packed older sluice modal generation cannot enter: " + encounter)
	game._close_modal(); await _talk(target)
	_check(s.save_game() == OK, "Packed sluice entry control checkpoint exists")
	var bytes: PackedByteArray = _receipt_bytes(); var blocker: String = _receipt_block_save()
	if blocker.is_empty(): return
	await _key(KEY_1)
	_check(not s.battle_active and _party_panel() == null and game.save_warning and _receipt_bytes() == bytes and s.hp == before.hp and s.qi == before.qi and s.medicine == before.medicine and s.party_resources == before.party_resources, "Packed real failed sluice checkpoint blocks combat and costs: " + encounter)
	_check(s.side_choice == ("pursuit" if encounter == "sluice_scout" else "rescue") and s.side_found == before.side_found, "Packed nearby choice survives failed checkpoint for exact retry")
	_receipt_unblock_save(blocker); await _key(KEY_1)
	var panel = _party_panel()
	_check(panel != null and panel.encounter == encounter and not game.save_warning and _receipt_document().player.side_choice == s.side_choice, "Packed same numbered choice retries durable sluice entry")
	if panel == null: return
	_unified_freeze(panel)
	var active: Dictionary = s.party_battle_snapshot(); var progress: Dictionary = s.to_dict(); var files: Dictionary = _courtyard_save_files()
	_check(not s.start_party_battle(encounter) and not s.choose_side_route("rescue") and not s.find_side_clue("ledger") and not s.finish_side_quest() and s.to_dict() == progress and s.party_battle_snapshot() == active, "Packed active sluice fight rejects duplicate entry and side progression")
	await _key(KEY_F5); await _key(KEY_F9); game._show_map(); game._show_inventory()
	_check(_party_panel() == panel and s.save_game() == ERR_BUSY and game.save_slots.store.save_slot(s,2) == ERR_BUSY and s.load_game() == ERR_BUSY and _courtyard_save_files() == files, "Packed actual sluice combat blocks every save/load/menu path")
	await _key(KEY_5); var tx: Dictionary = panel.pending; _party_finish(panel)
	_check(not s.battle_active and s.party_settlement.outcome == "flee" and s.to_dict() == progress, "Packed numbered flee retains branch and spent resources without reward")
	var old_epoch: int = tx.epoch; var old_token: int = tx.token
	panel = await _sluice_open(encounter)
	if panel == null: return
	active = s.party_battle_snapshot()
	_check(not s.finish_party_presentation(old_epoch,old_token).accepted and s.party_battle_snapshot() == active, "Packed old attempt token cannot settle a fresh sluice retry")
	panel.leave(); _party_finish(panel); game._close_modal()

func _test_sluice_route_pack(route: String, count: int) -> void:
	_sluice_prepare(count)
	var s = game.state; var xp: int = _receipt_xp(); var coins: int = s.coins; var victories: int = s.victories
	if route == "rescue":
		await _talk("stranded_boatman"); await _key(KEY_1); await _key(KEY_1)
	_check(s.side_found == (["boatman"] if route == "rescue" else []) and _receipt_xp() == xp, "Packed first investigation uses real scene choice and no clue XP: " + route)
	var panel = await _sluice_open("sluice_scout")
	if panel == null: return
	_check(panel.commands.groups.size() == count and s.party_battle_snapshot().actors.size() == count, "Packed sluice command groups use only%d natural actors" % count)
	var checkpoint: PackedByteArray = _receipt_bytes()
	var tx: Dictionary = _sluice_terminal(panel)
	if tx.is_empty() or tx.after.active: return
	_check(s.coins == coins and _receipt_xp() == xp and s.victories == victories and not s.side_found.has("ledger") and s.battle_active and _receipt_bytes() == checkpoint, "Packed pending scout victory grants neither reward nor clue before presentation")
	_party_finish(panel)
	var expected_found: Array = ["boatman","ledger"] if route == "rescue" else ["ledger"]
	_check(s.party_settlement.outcome == "win" and s.side_found == expected_found and s.side_stage == (2 if route == "rescue" else 1), "Packed scout grants ledger exactly once and keeps real route order")
	_check(_receipt_xp() == xp+25 and s.coins == coins+14 and s.victories == victories+1 and s.party_settlement.battle_reward_xp == 25 and s.party_settlement.branch_reward_xp == 0, "Packed scout earns exact25XP/14coins/one victory")
	var settled: Dictionary = s.to_dict()
	_check(not s.finish_party_presentation(tx.epoch,tx.token).accepted and not s.start_party_battle("sluice_scout") and s.to_dict() == settled, "Packed duplicate scout terminal or reentry cannot replay finite reward")
	game._close_modal(); _sluice_checkpoint(route+"-ledger-"+str(count))
	if route == "pursuit":
		await _talk("sluice_boss"); await _key(KEY_1)
		_check(not s.battle_active and not s.can_start_sluice_party_battle("sluice_boss") and not game._start_party_battle("sluice_boss"), "Packed ledger-only route and old entry adapter cannot bypass actual boss clue gate")
		await _talk("stranded_boatman"); await _key(KEY_1); await _key(KEY_1)
		expected_found = ["ledger","boatman"]
	_check(s.side_choice == route and s.side_found == expected_found and _receipt_xp() == xp+25 and s.side_stage == 2, "Packed second clue preserves first route and exact clue order without XP")
	await _talk("sluice_cache"); await _key(KEY_1)
	_check(s.hp == s.max_hp and s.qi == s.max_qi and s.party_roster.size() == count, "Packed actual old-store rest restores eligible roster before boss")
	panel = await _sluice_open("sluice_boss")
	if panel == null: return
	checkpoint = _receipt_bytes(); var blocker: String = _receipt_block_save()
	if blocker.is_empty(): return
	tx = _sluice_terminal(panel)
	if tx.is_empty() or tx.after.active: _receipt_unblock_save(blocker); return
	var medicine_at_terminal: int = s.medicine
	_check(s.side_stage == 2 and not s.side_reward_claimed and s.coins == coins+14 and _receipt_xp() == xp+25 and s.battle_active and _receipt_bytes() == checkpoint, "Packed boss terminal defers battle and branch rewards together")
	_party_finish(panel)
	_check(not s.battle_active and s.side_stage == 3 and s.side_reward_claimed and s.side_choice == route and s.side_found == expected_found, "Packed actual boss presentation atomically completes correct branch")
	_check(_receipt_xp() == xp+175 and s.coins == coins+(94 if route == "rescue" else 114) and s.victories == victories+2 and s.medicine == medicine_at_terminal+(2 if route == "rescue" else 0), "Packed full route earns scout25 + boss70 + branch80XP and exact route coins/medicine")
	_check(s.party_settlement.reward_xp == 150 and s.party_settlement.battle_reward_xp == 70 and s.party_settlement.branch_reward_xp == 80 and s.party_settlement.branch_reward_claimed, "Packed boss exposes separate70/80XP and combined150XP settlement facts")
	_check(game.save_warning and _receipt_bytes() == checkpoint and _gather_text(game.overlay).contains("交锋所得：修为+70、铜钱+35") and _gather_text(game.overlay).contains("修为 +80"), "Packed failed post-victory save preserves disk and displays both actual reward components")
	settled = s.to_dict()
	_check(not s.finish_side_quest() and not s.finish_party_presentation(tx.epoch,tx.token).accepted and not s.start_party_battle("sluice_boss") and s.to_dict() == settled, "Packed legacy turn-in and repeated boss terminal cannot replay either reward")
	game._close_modal(); _receipt_unblock_save(blocker); await _key(KEY_F5)
	_check(not game.save_warning and _receipt_document().version == 13 and _receipt_document().player == JSON.parse_string(JSON.stringify(settled)), "Packed real F5 retry persists already-settled sluice resources once")
	_sluice_checkpoint(route+"-complete-"+str(count))

func _test_sluice_close_pack(encounter: String, outcome: String) -> void:
	_sluice_prepare(2 if outcome == "win" else 1,encounter == "sluice_boss")
	var s = game.state
	if outcome == "defeat": s.hp = 1; s.qi = 0; s.coins = 5
	var panel = await _sluice_open(encounter)
	if panel == null: return
	var progress: Dictionary = s._sluice_party_progress(); var xp: int = _receipt_xp(); var coins: int = s.coins; var victories: int = s.victories
	var tx: Dictionary
	if outcome == "flee": tx = _unified_begin(panel, false)
	else: tx = _sluice_terminal(panel,outcome)
	if tx.is_empty(): return
	var accepted: Dictionary = s.to_dict(); var snapshot: Dictionary = s.party_battle_snapshot(); var bytes: PackedByteArray = _receipt_bytes()
	var blocker: String = _receipt_block_save()
	if blocker.is_empty(): return
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST); game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	await _key(KEY_1); await _key(KEY_ESCAPE)
	_check(panel.close_pending and not game.quit_pending and s.to_dict() == accepted and s.party_battle_snapshot() == snapshot and _receipt_bytes() == bytes, "Packed repeated sluice close waits for accepted action without double costs: " + encounter+"/"+outcome)
	_party_finish(panel)
	if outcome == "flee":
		_check(panel.pending.get("action_id") == "flee" and panel.art.is_presenting(), "Packed queued sluice close accepts exactly one flee after automatic basic")
		_party_finish(panel)
	_check(game.current_screen == "explore" and not s.battle_active and not game.quit_pending and game.save_warning and _receipt_bytes() == bytes and s.party_settlement.outcome == outcome, "Packed real failed-save close retains actual sluice outcome and prior disk: " + encounter+"/"+outcome)
	if outcome == "win":
		_check(_receipt_xp() == xp+(150 if encounter == "sluice_boss" else 25) and s.coins == coins+(80 if encounter == "sluice_boss" else 14) and s.victories == victories+1 and s.side_found.has("ledger") and s.side_reward_claimed == (encounter == "sluice_boss"), "Packed close preserves actual terminal reward and clue/branch boundary once")
	elif outcome == "defeat":
		_check(s.coins == 0 and _receipt_xp() == xp and s.victories == victories and s.map_id == "qingwei" and s.position == Vector2(420,450) and game.world.player_pos == s.position and s.hp == s.max_hp and s.qi >= 2 and s.side_found == progress.side_found and s.side_choice == progress.side_choice and not s.side_reward_claimed, "Packed actual sluice defeat loses only available5coins and recovers at correct Qingwei position without progress rewards")
	else:
		_check(s._sluice_party_progress() == progress and _receipt_xp() == xp and s.coins == coins and s.victories == victories, "Packed closed retreat preserves retryable clue order without reward")
	var settled: Dictionary = s.to_dict(); var stale: Callable = game.modal_actions[0]
	_press("返回小憩"); stale.call()
	_check(not game.quit_pending and s.to_dict() == settled and _receipt_bytes() == bytes, "Packed canceled sluice close invalidates stale retry/exit callback")
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST); _press("不保存离开")
	_check(_gather_text(game.overlay).contains("舍下未存的这一程？") and not game.quit_pending, "Packed sluice discard still requires the explicit second choice")
	_press("继续留在江湖"); await _key(KEY_ESCAPE); _receipt_unblock_save(blocker); await _key(KEY_F5)
	_check(not game.quit_pending and not game.save_warning and s.to_dict() == settled and _receipt_document().player == JSON.parse_string(JSON.stringify(settled)), "Packed canceled sluice close permits exact save retry without process exit or duplicate settlement")
	_sluice_checkpoint(encounter+"-close-"+outcome)

# V22 extends the complete V21 audit; prepared earlier chapters establish only
# eligibility. Archive entry, commands, later ending, retry and close use the
# shipped main scene and real isolated disk writes. No test adapter is loaded.
func _archive_prepare(count: int = 2) -> void:
	game._new_game()
	var s = game.state
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁"); s.gain_xp(180)
	s.side_stage = 3; s.side_choice = "rescue"; s.side_reward_claimed = true
	s.side_found.assign(["boatman","ledger"]); s.side_clues = 2
	var recruited: bool = count == 1 or s.recruit_companion()
	s.map_id = "frostbridge"; s.formation = "并肩"; s.heal_rest()
	_check(s.begin_chapter_two() and s.add_archive_clue("clerk") and s.add_archive_clue("inscription"), "Packed archive eligibility uses actual chapter and clue APIs")
	var solved: bool = true
	for key: int in [2,0,1]: solved = bool(s.try_seal(key).valid) and solved
	_check(solved and s.chapter_two_stage == 2 and s.seal_sequence == [2,0,1], "Packed archive eligibility solves the actual canonical seal sequence")
	game._sync_world_state(); game.world.change_map("frostbridge",Vector2(190,500)); s.position = game.world.player_pos
	game._refresh(); game._stop_audio(); game.audio_on = false
	_check(recruited and s.party_roster == (["hero","shen"] if count == 2 else ["hero"]) and not s.tangqi_unlocked and not s.qin_recruited() and s._valid_save_data(s.to_dict(),13), "Packed archive uses natural%d-actor roster without recruiting later companions" % count)

func _archive_open():
	await _talk("chapter_archive"); await _key(KEY_1)
	var panel = _party_panel(); var s = game.state
	_check(panel != null and game.current_screen == "party_battle" and s.battle_active and panel.encounter == "archive_boss", "Packed E/number enters actual archive party controller")
	if panel == null: return null
	_unified_freeze(panel)
	var enemy: Dictionary = _party_unit(s.party_battle_snapshot(),"archive_boss")
	_check(enemy.hp == 205 and enemy.attack == 17 and enemy.heavy_attack == 31, "Packed live archive opponent retains exact HP/light/heavy stats")
	_check(panel.commands.context.title == "封仓问剑" and panel.commands.context.location == "霜桥仓台 · 韩砚 · "+(s.formation if s.party_roster.size() > 1 else "独行") and panel.unit_plates.has("archive_boss") and not panel.unit_plates.has("puheng"), "Packed archive title, location, formation and target plates identify real encounter")
	_check(_receipt_document().version == 13 and _receipt_document().player.chapter_two_stage == 2 and _receipt_document().player.seal_sequence == JSON.parse_string(JSON.stringify([2,0,1])), "Packed pre-entry archive checkpoint durably records solved seal")
	return panel

func _archive_checkpoint(label: String) -> void:
	var s = game.state; var before: Dictionary = s.to_dict()
	_check(s.save_game() == OK, "Packed schema13 archive checkpoint writes: "+label)
	var bytes: PackedByteArray = _receipt_bytes(); var document: Dictionary = _receipt_document()
	_check(document.version == 13 and document.player == JSON.parse_string(JSON.stringify(before)) and not bytes.get_string_from_utf8().contains("vulnerability") and not bytes.get_string_from_utf8().contains("_party_archive_entry"), "Packed archive checkpoint preserves complete canonical state without encounter-only fields: "+label)
	game._load()
	_check(s.to_dict() == before and not s.battle_active and s.party_session == null and s._party_archive_entry.is_empty() and _receipt_bytes() == bytes, "Packed reload preserves exact archive resources/progress and clears transient encounter: "+label)
	var old10: Dictionary = _receipt_variables(legacy_reader); var old11: Dictionary = _receipt_variables(schema11_reader)
	_check(legacy_reader.load_game(s.SAVE_PATH) == ERR_FILE_UNRECOGNIZED and schema11_reader.load_game(s.SAVE_PATH) == ERR_FILE_UNRECOGNIZED and _receipt_variables(legacy_reader) == old10 and _receipt_variables(schema11_reader) == old11 and _receipt_bytes() == bytes, "Packed actual schema10/11 readers reject archive schema13 without any mutation: "+label)

func _test_archive_gates_pack() -> void:
	_archive_prepare()
	var s = game.state
	_check(s.can_start_archive_party_battle(), "Packed canonical Frostbridge solved-seal stage2 is archive eligible")
	for pair: Array in [["map_id","qingwei"],["map_id","sluice"],["chapter_two_stage",1],["chapter_two_stage",3],["chapter_two_stage",4],["chapter_two_ending","open_records"],["quest_stage",5],["side_stage",2],["side_reward_claimed",false],["side_choice",""],["side_clues",1],["hp",0],["medicine",-1]]:
		var original: Variant = s.get(pair[0]); s.set(pair[0],pair[1]); var before: Dictionary = s.to_dict()
		_check(not s.can_start_archive_party_battle() and not s.start_party_battle("archive_boss") and not s.battle_active and s.party_session == null and s.to_dict() == before, "Packed archive rejects malformed prerequisite atomically: "+str(pair))
		s.set(pair[0],original)
	for pair: Array in [["archive_clues",["clerk"]],["archive_clues",["clerk","clerk"]],["seal_sequence",[2,0]],["seal_sequence",[0,2,1]],["side_found",["ledger"]],["side_found",["ledger","ledger"]]]:
		var original: Array = s.get(pair[0]).duplicate(); s.get(pair[0]).assign(pair[1]); var before: Dictionary = s.to_dict()
		_check(not s.can_start_archive_party_battle() and not s.start_party_battle("archive_boss") and s.to_dict() == before and not s.battle_active, "Packed archive cannot normalize incomplete/forged prerequisite into entry: "+str(pair))
		s.get(pair[0]).assign(original)

func _test_archive_entry_pack() -> void:
	_archive_prepare()
	var s = game.state; var before: Dictionary = s.to_dict()
	game.chapter_story.archive(); game.modal_actions[0].call()
	_check(s.to_dict() == before and not s.battle_active, "Packed far archive callback cannot enter or spend")
	game._close_modal(); await _talk("chapter_archive"); var stale: Callable = game.modal_actions[0]; before = s.to_dict()
	await _key(KEY_ESCAPE); stale.call()
	_check(s.to_dict() == before and not s.battle_active, "Packed canceled archive callback cannot enter")
	await _talk("chapter_archive"); stale = game.modal_actions[0]; game._show_map(); stale.call()
	_check(s.to_dict() == before and not s.battle_active, "Packed older archive modal generation cannot enter")
	game._close_modal(); await _talk("chapter_archive"); stale = game.modal_actions[0]
	game.world.teleport(Vector2(190,500)); game._process(0); before = s.to_dict(); stale.call()
	_check(s.to_dict() == before and not s.battle_active, "Packed moving away invalidates fresh archive entry callback")
	game._close_modal(); await _talk("chapter_archive"); before = s.to_dict()
	_check(s.save_game() == OK, "Packed archive entry control checkpoint exists")
	var bytes: PackedByteArray = _receipt_bytes(); var blocker: String = _receipt_block_save()
	if blocker.is_empty(): return
	await _key(KEY_1)
	_check(not s.battle_active and _party_panel() == null and game.save_warning and _receipt_bytes() == bytes and s.to_dict() == before, "Packed real failed archive checkpoint blocks entry and every resource cost")
	_receipt_unblock_save(blocker); await _key(KEY_1)
	var panel = _party_panel()
	_check(panel != null and panel.encounter == "archive_boss" and not game.save_warning and _receipt_document().player.chapter_two_stage == 2, "Packed same numbered archive choice retries after successful durable checkpoint")
	if panel == null: return
	_unified_freeze(panel)
	var active: Dictionary = s.party_battle_snapshot(); var progress: Dictionary = s.to_dict(); var files: Dictionary = _courtyard_save_files()
	_check(not s.start_party_battle("archive_boss") and not s.begin_chapter_two() and not s.add_archive_clue("clerk") and not s.try_seal(2).valid and not s.mark_archive_victory() and not s.resolve_chapter_two("open_records") and not s.repair_bridge() and s.to_dict() == progress and s.party_battle_snapshot() == active, "Packed active archive rejects every Chapter mutation, duplicate entry and final choice")
	await _key(KEY_F5); await _key(KEY_F9); game._show_map(); game._show_inventory()
	_check(_party_panel() == panel and s.save_game() == ERR_BUSY and game.save_slots.store.save_slot(s,2) == ERR_BUSY and s.load_game() == ERR_BUSY and _courtyard_save_files() == files, "Packed archive blocks save/load/menu paths while an independent party fight is active")
	await _key(KEY_5); var tx: Dictionary = panel.pending; _party_finish(panel)
	_check(not s.battle_active and s.party_settlement.outcome == "flee" and s.to_dict() == progress, "Packed numbered archive retreat preserves solved seal without reward")
	panel = await _archive_open()
	if panel == null: return
	active = s.party_battle_snapshot()
	_check(not s.finish_party_presentation(tx.epoch,tx.token).accepted and s.party_battle_snapshot() == active, "Packed previous archive attempt token cannot settle new retry")
	panel.leave(); _party_finish(panel); game._close_modal()

func _test_archive_ending_pack(choice: String, count: int) -> void:
	_archive_prepare(count)
	var s = game.state; var panel = await _archive_open()
	if panel == null: return
	var xp: int = _receipt_xp(); var coins: int = s.coins; var victories: int = s.victories
	_check(panel.commands.groups.size() == count and s.party_battle_snapshot().actors.size() == count, "Packed archive commands and HUD belong only to%d natural actors" % count)
	var tx: Dictionary = _sluice_terminal(panel)
	if tx.is_empty(): return
	_check(s.chapter_two_stage == 2 and s.chapter_two_ending.is_empty() and _receipt_xp() == xp and s.coins == coins and s.victories == victories, "Packed pending archive victory reveals neither progress nor rewards early")
	var bytes: PackedByteArray = _receipt_bytes(); var blocker: String = _receipt_block_save()
	if blocker.is_empty(): return
	_party_finish(panel)
	_check(s.chapter_two_stage == 3 and s.chapter_two_ending.is_empty() and _receipt_xp() == xp+80 and s.coins == coins+40 and s.victories == victories+1 and s.party_settlement.battle_reward_xp == 80 and s.party_settlement.branch_reward_xp == 0, "Packed actual archive victory awards80XP40coins once and leaves a separate stage3 ending")
	_check(game.save_warning and _receipt_bytes() == bytes and _gather_text(game.overlay).contains("回西岸驿馆"), "Packed failed victory autosave preserves disk and explains actual later ending location")
	var won: Dictionary = s.to_dict()
	_check(not s.finish_party_presentation(tx.epoch,tx.token).accepted and not s.start_party_battle("archive_boss") and not s.mark_archive_victory() and s.to_dict() == won, "Packed repeated archive terminal/reentry cannot replay battle rewards")
	game._close_modal(); _receipt_unblock_save(blocker); await _key(KEY_F5)
	_check(not game.save_warning and _receipt_document().player == JSON.parse_string(JSON.stringify(won)), "Packed F5 persists already-settled stage3 victory exactly once")
	_archive_checkpoint(choice+"-victory-"+str(count))
	var before: Dictionary = s.to_dict(); game.chapter_story.innkeeper(); var stale: Callable = game.modal_actions[0]; stale.call()
	_check(s.to_dict() == before, "Packed remote innkeeper ending callback cannot resolve or reward")
	game._close_modal(); await _talk("chapter_host"); stale = game.modal_actions[0]; before = s.to_dict()
	await _key(KEY_ESCAPE); stale.call()
	_check(s.to_dict() == before, "Packed canceled archive ending callback cannot resolve")
	await _talk("chapter_host"); stale = game.modal_actions[0]; game._show_inventory(); stale.call()
	_check(s.to_dict() == before, "Packed old archive ending generation cannot resolve from inventory")
	game._close_modal(); await _talk("chapter_host"); stale = game.modal_actions[0]
	game.world.teleport(Vector2(1100,700)); game._process(0); before = s.to_dict(); stale.call()
	_check(s.to_dict() == before, "Packed moved-away ending callback cannot resolve or reward")
	game._close_modal(); await _talk("chapter_host"); var selected: Callable = game.modal_actions[0 if choice == "open_records" else 1]
	before = s.to_dict(); xp = _receipt_xp(); bytes = _receipt_bytes(); blocker = _receipt_block_save()
	if blocker.is_empty(): return
	await _key(KEY_1 if choice == "open_records" else KEY_2)
	_check(s.chapter_two_stage == 4 and s.chapter_two_ending == choice and _receipt_xp() == xp+100 and s.coins == int(before.coins)+65 and s.victories == before.victories, "Packed actual nearby numbered ending separately awards100XP65coins: "+choice+"/"+str(count))
	_check(game.save_warning and not game.quit_pending and _receipt_bytes() == bytes, "Packed failed ending autosave retains actual chosen memory and old checkpoint")
	var settled: Dictionary = s.to_dict(); selected.call(); stale.call()
	_check(not s.resolve_chapter_two(choice) and s.to_dict() == settled, "Packed duplicate ending callbacks/model cannot replay final reward after failed save")
	_receipt_unblock_save(blocker); await _key(KEY_F5)
	_check(not game.save_warning and _receipt_document().player == JSON.parse_string(JSON.stringify(settled)), "Packed F5 retry writes exactly chosen ending and every party resource")
	_archive_checkpoint(choice+"-complete-"+str(count))
	await _talk("chapter_host")
	_check(_find_button(game.overlay,"借榻调息") != null and s.to_dict() == settled and s.chapter_two_ending == choice, "Packed completed archive ending returns to ordinary inn interaction without rewarding again")
	game._close_modal()

func _test_archive_close_pack(outcome: String) -> void:
	_archive_prepare(2 if outcome == "win" else 1)
	var encounter: String = "archive_boss"
	var s = game.state
	if outcome == "defeat": s.hp = 1; s.qi = 0; s.coins = 5
	var panel = await _archive_open()
	if panel == null: return
	var progress: Dictionary = s._archive_party_progress(); var xp: int = _receipt_xp(); var coins: int = s.coins; var victories: int = s.victories
	var tx: Dictionary
	if outcome == "flee": tx = _unified_begin(panel, false)
	else: tx = _sluice_terminal(panel,outcome)
	if tx.is_empty(): return
	var accepted: Dictionary = s.to_dict(); var snapshot: Dictionary = s.party_battle_snapshot(); var bytes: PackedByteArray = _receipt_bytes()
	var blocker: String = _receipt_block_save()
	if blocker.is_empty(): return
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST); game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST)
	await _key(KEY_1); await _key(KEY_ESCAPE)
	_check(panel.close_pending and not game.quit_pending and s.to_dict() == accepted and s.party_battle_snapshot() == snapshot and _receipt_bytes() == bytes, "Packed repeated archive close waits for accepted action without double costs: " + encounter+"/"+outcome)
	_party_finish(panel)
	if outcome == "flee":
		_check(panel.pending.get("action_id") == "flee" and panel.art.is_presenting(), "Packed queued archive close accepts exactly one flee after automatic basic")
		_party_finish(panel)
	_check(game.current_screen == "explore" and not s.battle_active and not game.quit_pending and game.save_warning and _receipt_bytes() == bytes and s.party_settlement.outcome == outcome, "Packed real failed-save close retains actual archive outcome and prior disk: " + encounter+"/"+outcome)
	if outcome == "win":
		_check(_receipt_xp() == xp+80 and s.coins == coins+40 and s.victories == victories+1 and s.chapter_two_stage == 3 and s.chapter_two_ending.is_empty(), "Packed close preserves actual terminal reward and separate ending boundary once")
	elif outcome == "defeat":
		var recovered_progress: Dictionary = progress.duplicate(true); recovered_progress.map_id = "qingwei"
		_check(s.coins == 0 and _receipt_xp() == xp and s.victories == victories and s.map_id == "qingwei" and s.position == Vector2(420,450) and game.world.player_pos == s.position and s.hp == s.max_hp and s.qi >= 2 and s._archive_party_progress() == recovered_progress and s.chapter_two_stage == 2 and s.chapter_two_ending.is_empty(), "Packed actual archive defeat loses only available5coins and recovers at correct Qingwei position without progress rewards")
	else:
		_check(s._archive_party_progress() == progress and _receipt_xp() == xp and s.coins == coins and s.victories == victories, "Packed closed retreat preserves retryable solved seal without reward")
	var settled: Dictionary = s.to_dict(); var stale: Callable = game.modal_actions[0]
	_press("返回小憩"); stale.call()
	_check(not game.quit_pending and s.to_dict() == settled and _receipt_bytes() == bytes, "Packed canceled archive close invalidates stale retry/exit callback")
	game._notification(game.NOTIFICATION_WM_CLOSE_REQUEST); _press("不保存离开")
	_check(_gather_text(game.overlay).contains("舍下未存的这一程？") and not game.quit_pending, "Packed archive discard still requires the explicit second choice")
	_press("继续留在江湖"); await _key(KEY_ESCAPE); _receipt_unblock_save(blocker); await _key(KEY_F5)
	_check(not game.quit_pending and not game.save_warning and s.to_dict() == settled and _receipt_document().player == JSON.parse_string(JSON.stringify(settled)), "Packed canceled archive close permits exact save retry without process exit or duplicate settlement")
	_archive_checkpoint(encounter+"-close-"+outcome)

func _test_archive_atomic_ending_pack() -> void:
	_archive_prepare()
	var s = game.state
	_check(s.mark_archive_victory(), "Packed separate model boundary prepares exact stage3 atomic ending fixture")
	var before: Dictionary = s.to_dict()
	_check(not s.resolve_chapter_two("forged_choice") and s.to_dict() == before, "Packed invalid final choice leaves every persistent field unchanged")
	s.medicine = -1; before = s.to_dict()
	_check(not s.resolve_chapter_two("open_records") and s.to_dict() == before, "Packed malformed final state cannot receive or partially apply ending rewards")
	s.medicine = 3; s.coins = 999990
	var xp: int = _receipt_xp()
	await _talk("chapter_host"); await _key(KEY_2)
	_check(s.chapter_two_stage == 4 and s.chapter_two_ending == "protect_witness" and s.coins == 999999 and _receipt_xp() == xp+100 and s._valid_save_data(s.to_dict(),13), "Packed actual final choice caps coins and commits validated ending/XP atomically")
	_archive_checkpoint("capped-final-choice")


func _schema12_legacy_prerequisite(rehearsal: bool) -> bool:
	var path: String = OS.get_environment("HERO_AUDIT_SCHEMA12_READER")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema12-reader="): path = argument.trim_prefix("--schema12-reader=")
	if path.is_empty() and rehearsal: path = ProjectSettings.globalize_path("res://tests/fixtures/v022_game_state.gd.txt")
	_check(path.is_absolute_path() and FileAccess.file_exists(path), "Unified audit requires external frozen schema12 reader")
	if not path.is_absolute_path() or not FileAccess.file_exists(path): return false
	_check(FileAccess.get_sha256(path) == SCHEMA12_READER_SHA256, "Exact schema12 reader matches immutable pre-automatic source SHA256")
	if FileAccess.get_sha256(path) != SCHEMA12_READER_SHA256: return false
	var script = GDScript.new(); script.source_code = FileAccess.get_file_as_string(path).replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Exact schema12 reader compiles without global registration")
	if error != OK: return false
	schema12_reader = script.new()
	_check(schema12_reader.SAVE_VERSION == 12, "Frozen prior reader retains actual schema12 gate")
	return schema12_reader.SAVE_VERSION == 12

func _unified_freeze(panel) -> void:
	if panel != null: panel.set_process(false); panel.art.set_process(false)

func _unified_open_training():
	if game.active_modal: game._close_modal()
	if game.state.quest_stage < 4: game.state.quest_stage = 4
	if game.state.quest_stage >= 5 and game.state.ending.is_empty(): game.state.ending = "守望"
	game.state.map_id = "qingwei"; game.world.change_map("qingwei",Vector2(955,630))
	game.world.teleport(game.world.interactables.bandit.pos); game.state.position = game.world.player_pos
	game._start_battle("training")
	var panel = _party_panel(); _unified_freeze(panel)
	return panel

func _unified_leave() -> void:
	var panel = _party_panel()
	if panel == null: _check(false,"Unified retreat requires actual current controller"); return
	_unified_freeze(panel)
	panel.leave()
	if panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration()+.1)
	if game.state.battle_active and panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration()+.1)

func _unified_begin(panel, tactics: bool = true) -> Dictionary:
	if panel == null: return {}
	_unified_freeze(panel)
	if not panel.pending.is_empty(): return panel.pending
	var snapshot: Dictionary = game.state.party_battle_snapshot()
	if tactics:
		for actor: Dictionary in snapshot.actors:
			if actor.hp <= 0: continue
			for action: Dictionary in actor.actions:
				if action.id == "item" and action.available and actor.hp < actor.max_hp * .35:
					panel.request_command(actor.id,"item")
					if not panel.pending.is_empty(): _unified_record(panel.pending); return panel.pending
			if actor.basic_done: continue
			for action: Dictionary in actor.actions:
				if action.category != "martial" or not action.available or action.queued: continue
				var target: String = ""
				if bool(action.effects.get("guard",false)):
					var heavy: bool = false
					for intent: Dictionary in snapshot.enemy_intents: heavy = heavy or bool(intent.get("heavy",false))
					if not heavy and actor.status.get("vulnerability_hits",0) == 0: continue
				if snapshot.encounter_id == "sect_trial" and action.effects.get("healing",0) > 0 and actor.hp == actor.max_hp: continue
				if action.target_team == "enemy" and not action.valid_target_ids.is_empty(): target = action.valid_target_ids[0]
				elif action.target_team == "self": target = actor.id
				elif action.target_team == "ally":
					for ally: Dictionary in snapshot.actors:
						if action.valid_target_ids.has(ally.id) and ally.hp <= ally.max_hp-20: target = ally.id
				if target.is_empty(): continue
				if action.target_team == "enemy": panel.select_target(target)
				panel.request_command(actor.id,action.id)
				if not panel.pending_action.is_empty(): panel.select_target(target)
	panel._process(1.0)
	if not panel.pending.is_empty(): _unified_record(panel.pending)
	return panel.pending

func _unified_record(tx: Dictionary) -> void:
	if _unified_tokens.has(tx.token): return
	_unified_tokens[tx.token] = true
	if tx.action_id == "attack":
		var key: String = "%d/%d/%s" % [tx.epoch,tx.before.round,tx.source_id]
		_unified_facts_ok = _unified_facts_ok and not _unified_basics.has(key) and _party_actor(tx.before,tx.source_id).hp > 0
		_unified_basics[key] = true
		_unified_basic_encounters[tx.before.encounter_id] = true
	for actor: Dictionary in tx.before.actors:
		if actor.id != tx.source_id: continue
		for action: Dictionary in actor.actions:
			if action.id != tx.action_id or action.category not in ["martial","internal","lightness"]: continue
			if not tx.events.any(func(event): return event.type == "action"): continue
			var key: String = "%d/%s/%s" % [tx.epoch,tx.source_id,tx.action_id]
			if _unified_skills.has(key): _unified_facts_ok = _unified_facts_ok and int(tx.before.round) >= int(_unified_skills[key])+int(action.cooldown)+1
			_unified_skills[key] = tx.before.round

func _test_unified_pack() -> void:
	var first: int = checks
	game.set_process(false); game.world.set_process(false)
	var rules = load("res://scripts/automatic_party_combat.gd"); var encounters = load("res://scripts/unified_encounter_rules.gd")
	_check(rules.SUPPORTED_ENCOUNTERS == ["story","training","sect_trial","courtyard_practice","sluice_scout","sluice_boss","archive_boss","mist_scout","mist_keeper","heting_receipt"] and rules.SUPPORTED_ENCOUNTERS == encounters.IDS, "Packed all10 normal encounters share one explicit automatic catalog")
	game._show_title(); var title = game.overlay.find_child("BuildVersion",true,false)
	_check(title != null and title.text=="0.0.22", "Packed actual title retains unified0.0.22 identity")
	for kind: String in encounters.IDS: await _test_unified_entry(kind)
	for count: int in range(1,5): await _test_unified_round(count)
	await _test_unified_learning()
	_test_unified_migration()
	await _test_unified_queues()
	await _test_unified_practice()
	for kind: String in ["sluice_scout","sluice_boss"]: await _test_sluice_entry_pack(kind)
	for route: String in ["rescue","pursuit"]:
		for count: int in [1,2]: await _test_sluice_route_pack(route,count)
	_test_archive_gates_pack(); await _test_archive_entry_pack()
	for choice: String in ["open_records","protect_witness"]:
		for count: int in [1,2]: await _test_archive_ending_pack(choice,count)
	for outcome: String in ["flee","win","defeat"]:
		await _test_sluice_close_pack("sluice_boss",outcome)
		await _test_archive_close_pack(outcome)
	await _test_archive_atomic_ending_pack()
	await _test_unified_journey()
	_check(_unified_facts_ok and _unified_basics.size() > 100 and _unified_skills.size() > 10 and _unified_basic_encounters.size() == 10, "Packed observed transactions across all10 encounters prove unique living-actor basics and full subsequent-round skill cooldowns")
	print("Schema13 unified automatic exact-runtime coverage: %d checks; all10 actual controllers; fixed3 skill slots; no-input basics; queued skills/CD;1-4 real rosters; explicit lessons; frozen9/10/11/12 readers; natural3-school journey; practice byte isolation; trial provenance; real save-failure/close/retry; no browser or physical desktop-close claim" % (checks-first))

func _unified_prepare(kind: String, count: int = 1) -> void:
	game._new_game(); var s = game.state
	if kind == "story": s.quest_stage = 3
	else:
		s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁"); s.gain_xp(900)
		s.side_stage = 3; s.side_choice = "rescue"; s.side_clues = 2; s.side_found.assign(["boatman","ledger"]); s.side_reward_claimed = true
		s.chapter_two_stage = 4; s.chapter_two_ending = "protect_witness"; s.archive_clues.assign(["clerk","inscription"]); s.seal_sequence.assign([2,0,1]); s.bridge_repaired = true
	if count >= 2: _check(s.recruit_companion(), "Packed explicit Shen invitation")
	if count >= 3: _check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(), "Packed explicit earned Tang quest/invitation")
	if count == 4:
		s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain","stone","basin"]); s.mist_ending = "release_water"; s.map_id = "mistwood"
		_check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(), "Packed explicit Qin late-story quest/invitation")
	_check(s.set_party_roster(["hero","shen","tang","qin"].slice(0,count)), "Packed exact occupied roster uses recruited actors")
	match kind:
		"sluice_scout": s.side_stage = 1; s.side_clues = 0; s.side_found.clear(); s.side_reward_claimed = false; s.chapter_two_stage = 0; s.chapter_two_ending = ""; s.archive_clues.clear(); s.seal_sequence.clear(); s.bridge_repaired = false
		"sluice_boss": s.side_stage = 2; s.side_reward_claimed = false; s.chapter_two_stage = 0; s.chapter_two_ending = ""; s.archive_clues.clear(); s.seal_sequence.clear(); s.bridge_repaired = false
		"archive_boss": s.chapter_two_stage = 2; s.chapter_two_ending = ""; s.bridge_repaired = false
		"mist_scout": s.mist_stage = 1; s.mist_approach = ""; s.mist_gauges.clear(); s.mist_ending = ""
		"mist_keeper": s.mist_stage = 2; s.mist_approach = "duel"; s.mist_gauges.assign(["rain","stone","basin"]); s.mist_ending = ""
		"heting_receipt":
			s.mist_stage = 4; s.mist_approach = "duel"; s.mist_gauges.assign(["rain","stone","basin"]); s.mist_ending = "release_water"
			s.heting_stage = 4; s.heting_bridge = "east"; s.heting_delivered.assign(["meal","sealed","reserve"]); s.heting_draft = "short_ferries"; s.heting_ending = "short_ferries"; s.receipt_stage = 1
	var location: Array = load("res://scripts/unified_encounter_rules.gd").LOCATIONS[kind]
	s.map_id = location[0]; game._sync_world_state(); game.world.change_map(location[0],Vector2(420,450))
	game.world.teleport(game.world.interactables[location[1]].pos+Vector2(0,24)); s.position = game.world.player_pos
	game._refresh(); game._stop_audio(); game.audio_on = false
	_check(s._stage_save_data(s.to_dict(),13).ok, "Packed prepared route is canonical: "+kind)

func _unified_enter(kind: String):
	var location: Array = load("res://scripts/unified_encounter_rules.gd").LOCATIONS[kind]
	await _talk(location[1])
	if kind == "heting_receipt": _press("复签应战准备")
	await _key(KEY_1)
	var panel = _party_panel(); _unified_freeze(panel)
	_check(panel != null and game.current_screen == "party_battle" and panel.encounter == kind and panel.session.get_script().resource_path == "res://scripts/automatic_party_combat.gd", "Packed actual E/number route opens shared automatic controller/model: "+kind)
	return panel

func _test_unified_entry(kind: String) -> void:
	_unified_prepare(kind,2 if kind == "story" else 1)
	var panel = await _unified_enter(kind)
	if panel == null: return
	for actor: Dictionary in panel.commands.snapshot.actors:
		_check(panel.commands._slots(actor).size() == 3 and actor.actions.size() == 5, "Packed occupied actor has three fixed skills plus two separate utilities")
		for category: String in ["martial","internal","lightness"]:
			var slot: Dictionary = panel.commands.slot_descriptor(actor.id,category)
			_check(slot.category == category and slot.id not in ["attack","guard"], "Packed slot preserves category and excludes manual basic/guard")
	panel.set_pause_request(true)
	var before: Dictionary = game.state.to_dict(); var snapshot: Dictionary = game.state.party_battle_snapshot()
	root.gui_release_focus(); await _key(KEY_ENTER); await _key(KEY_SPACE)
	panel.request_command("hero","attack"); panel.request_command("hero","guard")
	_check(game.state.to_dict() == before and game.state.party_battle_snapshot() == snapshot and panel.pending.is_empty(), "Packed Enter/Space and direct manual attack/guard cannot execute")
	panel.set_pause_request(false)
	var tx: Dictionary = _unified_begin(panel,false)
	_check(not tx.is_empty() and tx.action_id == "attack" and tx.source_id == "hero" and panel.art.is_presenting(), "Packed no-input timer starts automatic hero basic: "+kind)
	if tx.is_empty(): return
	_check(panel.commands.context.acting_unit_id == panel.art.acting_unit_id and not game.state.advance_party_battle().accepted, "Packed acting identity derives from actual renderer and duplicate advance is locked")
	_party_finish(panel); before = game.state.to_dict(); panel._finished()
	_check(game.state.to_dict() == before, "Packed duplicate presentation completion cannot replay resource or reward")
	_unified_leave()
	_check(not game.state.battle_active and game.current_screen == "explore", "Packed all10 routes settle retreat in the same controller")
	game._close_modal()

func _test_unified_round(count: int) -> void:
	_unified_prepare("heting_receipt",count)
	var panel = await _unified_enter("heting_receipt")
	if panel == null: return
	_check(panel.commands.groups.size() == count and panel.commands.is_compact() == (count == 4), "Packed actual1-4 occupied groups use matching compact layout")
	for actor: Dictionary in panel.commands.snapshot.actors:
		_check(panel.commands._slots(actor).size() == 3 and actor.actions[0].category == "martial" and actor.actions[1].category == "internal" and actor.actions[2].category == "lightness", "Packed every1-4 occupied actor retains the same exact3 semantic skill slots")
	var basics: Array = []; var accepted: bool = true
	for index: int in range(12):
		if game.state.party_battle_snapshot().round > 1: break
		var tx: Dictionary = _unified_begin(panel,false)
		if tx.is_empty(): accepted = false; break
		if tx.action_id == "attack": basics.append(tx.source_id)
		panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(accepted and basics == game.state.party_roster and game.state.party_battle_snapshot().round == 2, "Packed no-input round grants exactly one basic to each actual living actor in roster order")
	_unified_leave(); game._close_modal()

func _test_unified_learning() -> void:
	game._new_game(); var s = game.state
	_check(not s.internal_unlocked and not s.learn_internal_skill(), "Packed fresh hero cannot obtain unearned internal lesson")
	s.quest_stage = 6; s.ending = "守望"; s.choose_sect("问石门"); s.gain_xp(180)
	await _talk("mentor"); _press("内功与轻身"); _press("内功 · 调息归元")
	_check(_gather_text(game.overlay).contains("消耗2") and _gather_text(game.overlay).contains("16") and _gather_text(game.overlay).contains("不会替代自动普攻"), "Packed real lesson explains actual internal cost/effect and automatic basic")
	var stale: Callable = game.modal_actions[0]; await _key(KEY_ESCAPE); stale.call()
	_check(not s.internal_unlocked, "Packed canceled explicit lesson grants nothing")
	await _talk("mentor"); _press("内功与轻身"); _press("内功 · 调息归元"); stale = game.modal_actions[0]
	game.world.teleport(Vector2(420,450)); game._process(0); stale.call()
	_check(not s.internal_unlocked, "Packed moved-away lesson callback grants nothing")
	game._close_modal(); await _talk("mentor"); _press("内功与轻身"); _press("内功 · 调息归元")
	var coins: int = s.coins; _press("修习调息归元 · 免费")
	_check(s.internal_unlocked and s.coins == coins and not s.lightness_unlocked, "Packed explicit free lesson grants only the selected internal skill")
	game._load(); _check(s.internal_unlocked and _receipt_document().version == 13, "Packed actual lesson autosaves and reloads schema13")
	await _talk("mentor"); _press("内功与轻身"); _press("轻功 · 踏苇行"); _press("修习踏苇行")
	_check(s.lightness_unlocked and s.internal_unlocked, "Packed separately chosen free lightness lesson remains independent")

func _test_unified_migration() -> void:
	var model = load("res://scripts/game_state.gd"); var fresh = model.new(); var legacy: Dictionary = fresh.to_dict(); legacy.erase("internal_unlocked")
	var path: String = "user://unified-schema13-audit.json"
	for version: int in range(1,13):
		_receipt_write_document(path,{"version":version,"player":legacy}); var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var probe = model.new()
		_check(probe.load_game(path) == OK and not probe.internal_unlocked and FileAccess.get_file_as_bytes(path) == bytes, "Packed schema%d migration never grants internal lesson or rewrites old bytes" % version)
	var before: Dictionary = game.state.to_dict()
	_check(game.state.save_game(path) == OK, "Packed learned schema13 creates actual complete save")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for reader in [schema9_reader,legacy_reader,schema11_reader,schema12_reader]:
		var stable: Dictionary = _receipt_variables(reader)
		_check(reader.load_game(path) == ERR_FILE_UNRECOGNIZED and _receipt_variables(reader) == stable and FileAccess.get_file_as_bytes(path) == bytes, "Packed exact frozen prior reader rejects schema13 without memory or disk mutation")
	var probe = model.new()
	_check(probe.load_game(path) == OK and probe.to_dict() == before, "Packed new reader retains earned internal/lightness and all complete party fields")
	for malformed: Variant in [null,1,"true",{},[]]:
		var data: Dictionary = before.duplicate(true); data.internal_unlocked = malformed
		_receipt_reject_document(probe,path,{"version":13,"player":data},before,"strict internal boolean")
	var data: Dictionary = before.duplicate(true); data.erase("internal_unlocked")
	_receipt_reject_document(probe,path,{"version":13,"player":data},before,"missing required internal flag")
	data = fresh.to_dict(); data.internal_unlocked = true
	_receipt_reject_document(probe,path,{"version":13,"player":data},before,"unearned internal lesson")

func _test_unified_queues() -> void:
	_unified_prepare("heting_receipt",4)
	_check(game.state.learn_internal_skill() and game.state.learn_lightness(), "Packed eligible explicit lesson APIs support completed-story queue fixture")
	var panel = await _unified_enter("heting_receipt")
	if panel == null: return
	panel.set_pause_request(true); panel.select_actor("qin"); await _key(KEY_1)
	_check(panel.pending_action == "art:qin_shoudu" and game.state.party_battle_snapshot().paused, "Packed ally skill opens safely paused exact-target flow")
	var qi: int = _party_actor(game.state.party_battle_snapshot(),"qin").qi
	panel.unit_plates.hero.pressed.emit()
	_check(_party_actor(game.state.party_battle_snapshot(),"qin").categories.martial.queued and _party_actor(game.state.party_battle_snapshot(),"qin").qi == qi, "Packed actual ally target queues without early resource cost")
	await _key(KEY_1)
	_check(not _party_actor(game.state.party_battle_snapshot(),"qin").categories.martial.queued, "Packed same fixed slot cancels its pending category")
	panel.request_command("qin","art:qin_shoudu"); panel.select_target("hero")
	panel.set_pause_request(false); var tx: Dictionary = _unified_begin(panel,false)
	_check(tx.source_id == "hero" and tx.action_id == "attack", "Packed queued companion cannot steal automatic hero order")
	panel.select_actor("tang"); await _key(KEY_3)
	_check(game.state.party_battle_snapshot().selected_actor_id == "tang" and panel.commands.context.acting_unit_id == "hero" and _party_actor(panel.commands.snapshot,"tang").categories.lightness.queued, "Packed selection/queued future skill stays distinct from actually acting hero")
	var before: Dictionary = game.state.to_dict(); var snapshot: Dictionary = game.state.party_battle_snapshot()
	var echo := InputEventKey.new(); echo.physical_keycode = KEY_3; echo.keycode = KEY_3; echo.pressed = true; echo.echo = true
	Input.parse_input_event(echo); await process_frame; echo.pressed = false; echo.echo = false; Input.parse_input_event(echo)
	_check(game.state.to_dict() == before and game.state.party_battle_snapshot() == snapshot, "Packed held skill key cannot duplicate/cancel queue or cost")
	await _key(KEY_P)
	_check(game.state.party_battle_snapshot().pause_requested and not game.state.party_battle_snapshot().paused, "Packed pause request waits for accepted action")
	_party_finish(panel)
	_check(game.state.party_battle_snapshot().paused and panel.pending.is_empty(), "Packed actual renderer completion reaches safe paused boundary")
	var sequence: int = game.state.party_battle_snapshot().action_sequence; panel._process(10)
	_check(game.state.party_battle_snapshot().action_sequence == sequence, "Packed paused real time cannot advance automatic model")
	await _key(KEY_P)
	var accepted: bool = true
	for index: int in range(30):
		if game.state.party_battle_snapshot().round >= 2: break
		tx = _unified_begin(panel,false)
		if tx.is_empty(): accepted = false; break
		panel.art._process(panel.art.get_presentation_duration()+.1)
	var qin: Dictionary = _party_actor(game.state.party_battle_snapshot(),"qin")
	_check(accepted and game.state.party_battle_snapshot().round == 2 and qin.cooldowns["art:qin_shoudu"] == 2 and qin.actions[0].eligible_round == 4, "Packed fresh cooldown keeps2 full subsequent rounds and earliestR4 afterR1 cast")
	_unified_leave(); game._close_modal()
	_unified_prepare("heting_receipt",4); panel = await _unified_enter("heting_receipt")
	if panel == null: return
	panel.commands.request_slot("hero",0); panel._process(.5); tx = panel.pending; _unified_record(tx)
	var art_id: String = tx.action_id
	_check(_party_actor(panel.commands.snapshot,"hero").qi == _party_actor(tx.before,"hero").qi and _party_actor(panel.commands.snapshot,"hero").cooldowns[art_id] == _party_actor(tx.before,"hero").cooldowns[art_id], "Packed accepted skill hides future qi/CD until corresponding presentation events")
	panel.select_actor("tang"); panel.commands.request_slot("tang",2)
	_check(_party_actor(panel.commands.snapshot,"tang").categories.lightness.queued and _party_actor(panel.commands.snapshot,"hero").qi == _party_actor(tx.before,"hero").qi, "Packed live future queue refresh preserves old presented hero resource rail")
	panel.art._process(.03); panel.refresh()
	_check(_party_actor(panel.commands.snapshot,"hero").cooldowns[art_id] > 0 and _party_actor(panel.commands.snapshot,"hero").qi == _party_actor(tx.before,"hero").qi, "Packed actual action event shows CD before separate payment event")
	panel.art._process(.1); panel.refresh()
	_check(_party_actor(panel.commands.snapshot,"hero").qi == _party_actor(tx.after,"hero").qi, "Packed actual payment event reveals exactly accepted cost")
	_party_finish(panel); _unified_leave(); game._close_modal()

func _test_unified_practice() -> void:
	for outcome: String in ["flee","win","defeat"]:
		if outcome == "defeat":
			game._new_game(); game.world.teleport(game.world.interactables.courtyard_practice.pos); game.state.position = game.world.player_pos
		else: _unified_prepare("courtyard_practice",4)
		game.world.teleport(game.world.interactables.courtyard_practice.pos); game._process(0)
		game.state.hp -= 12; game.state.qi = 1; game.state.medicine = 2
		_check(game.state.save_game() == OK, "Packed real resources checkpoint before virtual practice")
		var before: Dictionary = game.state.to_dict(); var files: Dictionary = _courtyard_save_files()
		var panel = await _unified_enter("courtyard_practice")
		if panel == null: return
		var snapshot: Dictionary = game.state.party_battle_snapshot()
		_check(snapshot.medicine == 3 and _party_actor(snapshot,"hero").hp == _party_actor(snapshot,"hero").max_hp and _party_actor(snapshot,"hero").qi == _party_actor(snapshot,"hero").max_qi and game.state.to_dict() == before, "Packed practice starts genuine virtual resources without healing persistent state")
		var tx: Dictionary
		if outcome == "flee":
			tx = _unified_begin(panel,true); _party_finish(panel); _unified_leave()
		else:
			tx = _sluice_terminal(panel,outcome); _party_finish(panel)
		_check(not game.state.battle_active and game.state.party_settlement.outcome == outcome and game.state.party_settlement.practice and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed actual practice "+outcome+" changes no persistent resources/proficiency/progression or save bytes")
		panel = await _unified_enter("courtyard_practice")
		if panel == null: return
		_check(game.state.party_battle_snapshot().round == 1 and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed explicit practice retry starts fresh virtual round without rewriting real saves")
		_unified_leave()

func _test_unified_journey() -> void:
	for school in range(3):
		game._new_game()
		_journey_interact("elder");_journey_choose()
		_journey_interact("herb");_journey_choose()
		_journey_interact("healer");_journey_choose()
		_journey_interact("healer");_journey_choose()
		_check(game.state.companion_unlocked and game.state.quest_stage==3,"Opening supplies and recruit earned normally")
		_journey_interact("bandit");_journey_choose();_journey_fight()
		_journey_interact("elder");_journey_choose();_journey_choose(school)
		_check(game.state.quest_stage==6 and game.state.level>=3,"Opening rewards organically reach mentor level")
		game._show_inventory();_journey_choose(2);game._close_modal()
		_check(game.state.equipment=="青钢剑","Opening earnings buy the sword without extra currency")
		if school==2:
			game._show_inventory();_journey_choose(1);game._close_modal() # Earned formation choice puts the trial hero in the announced heavy lane.
		_journey_interact("mentor");_journey_choose();_journey_fight()
		_journey_interact("mentor");_journey_choose()
		_check(game.state.sect_rank==2,"Actual chosen school trial completed with normal stats")
		_journey_interact("exit_sluice");_journey_choose()
		_journey_interact("stranded_boatman");_journey_choose();game._close_modal()
		_check(game.state.party_roster==["hero","shen"] and not game.state.tangqi_unlocked and not game.state.qin_recruited(),"Natural sluice chronology has only the earned hero and Shen")
		var before_scout_coins:int=game.state.coins
		var before_scout_xp:int=game.state.xp+30*game.state.level*(game.state.level-1)
		_journey_interact("ledger_runner");_journey_choose()
		_check(game.current_screen=="party_battle" and game.state.party_battle_snapshot().encounter_id=="sluice_scout","Ordinary runner choice enters the actual independent party scout")
		_journey_fight()
		_check(game.state.side_found==["boatman","ledger"] and game.state.side_clues==2 and game.state.coins==before_scout_coins+14 and game.state.xp+30*game.state.level*(game.state.level-1)==before_scout_xp+25,"Natural scout grants one ledger, fourteen coins and twenty-five XP")
		_journey_interact("sluice_cache");_journey_choose()
		var before_boss_coins:int=game.state.coins
		var before_boss_xp:int=game.state.xp+30*game.state.level*(game.state.level-1)
		var before_boss_medicine:int=game.state.medicine
		_journey_interact("sluice_boss");_journey_choose()
		_check(game.current_screen=="party_battle" and game.state.party_battle_snapshot().encounter_id=="sluice_boss","Ordinary boss choice enters the actual independent party boss")
		_journey_fight()
		_check(game.state.side_stage==3 and game.state.side_reward_claimed,"Full sluice route naturally completed")
		_check(game.state.coins==before_boss_coins+80 and game.state.xp+30*game.state.level*(game.state.level-1)==before_boss_xp+150 and game.state.medicine==before_boss_medicine+2,"Earned rescue completion grants exact battle and branch rewards once")
		_check(game.state.party_settlement.battle_reward_xp==70 and game.state.party_settlement.branch_reward_xp==80 and game.state.party_settlement.branch_reward_claimed,"Boss settlement includes the seventy-XP battle and eighty-XP branch atomically")
		_journey_interact("exit_frostbridge");_journey_choose()
		_journey_interact("chapter_clerk");_journey_choose()
		_journey_interact("chapter_inscription");_journey_choose()
		_journey_interact("chapter_host");_journey_choose()
		_journey_interact("chapter_archive");_journey_choose(2);_journey_choose(0);_journey_choose(1)
		_check(game.state.party_roster==["hero","shen"] and not game.state.tangqi_unlocked and not game.state.qin_recruited(),"Natural archive chronology still has only the earned hero and Shen")
		var before_archive_coins:int=game.state.coins
		var before_archive_xp:int=game.state.xp+30*game.state.level*(game.state.level-1)
		_journey_choose()
		var archive:Dictionary=game.state.party_battle_snapshot()
		_check(game.current_screen=="party_battle" and archive.get("encounter_id")=="archive_boss","Ordinary solved-seal choice enters the actual independent party archive boss")
		if not archive.is_empty():
			_check(archive.enemies.size()==1 and archive.enemies[0].max_hp==205 and archive.enemies[0].attack==17 and archive.enemies[0].heavy_attack==31,"Natural archive encounter preserves its 205HP and light/heavy attack stats")
		_journey_fight()
		_check(game.state.chapter_two_stage==3 and game.state.chapter_two_ending.is_empty() and game.state.coins==before_archive_coins+40 and game.state.xp+30*game.state.level*(game.state.level-1)==before_archive_xp+80,"Natural archive victory settles stage two to three with exactly eighty XP and forty coins")
		_check(game.state.party_settlement.get("reward_xp")==80 and game.state.party_settlement.get("coin_change")==40,"Archive party settlement excludes the later narrative choice reward")
		_journey_interact("chapter_host");_journey_choose(0 if school==0 else 1)
		_check(game.state.chapter_two_stage==4 and game.state.chapter_two_ending==("open_records" if school==0 else "protect_witness"),"Both actual innkeeper branches finish the full archive story")
		_check(game.state.coins==before_archive_coins+105 and game.state.xp+30*game.state.level*(game.state.level-1)==before_archive_xp+180,"Earned ending separately adds exactly one hundred XP and sixty-five coins")
		_journey_interact("frost_timber");_journey_choose()
		_journey_interact("bridge_worker");_journey_choose()
		_check(game.state.bridge_repaired and game.state.resources.timber==1,"Gathering supports real bridge cost")
		_journey_interact("bridge_worker");_journey_choose()
		_journey_interact("return_sluice")
		_journey_interact("sluice_cache");_journey_choose()
		_journey_interact("exit_frostbridge");_journey_choose()
		_journey_interact("bridge_worker");_journey_choose(school%2);_journey_choose()
		_check(game.state.tangqi_unlocked and game.state.current_companion()=="唐栖","Natural chapter rewards unlock complete personal quest")
		# Learn both advanced arts from earned promotion/deed merit, then use a real build.
		_journey_interact("return_sluice");_journey_interact("return_village")
		_journey_interact("mentor");_journey_choose();_journey_choose(1);_journey_choose();_journey_choose(2);_journey_choose();_journey_choose();_journey_choose();_journey_choose();_journey_choose()
		_check(game.state.learned_arts.size()==2 and game.state.sect_merit==0,"Actual story deeds fund both advanced arts without injected merit")
		game._close_modal();game._show_martials();_journey_choose(3)
		_check(game.state.equipped_art==game.state.school_art_ids()[3],"Advanced focus art equipped through real four-move menu")
		_journey_interact("exit_sluice");_journey_choose();_journey_interact("exit_frostbridge");_journey_choose();_journey_interact("exit_mistwood");_journey_choose()
		_check(game.state.map_id=="mistwood","Natural journey enters fourth region")
		_journey_interact("mist_rain_gauge");_journey_choose();_journey_interact("mist_basin");_journey_choose()
		if school==0:
			_journey_interact("mist_scout");_journey_choose(2)
		elif school==1:
			game._show_workshop();_journey_choose(3);_journey_choose();_journey_choose(2);game._close_modal()
			_journey_interact("mist_scout");_journey_choose(1)
		else:
			_journey_interact("mist_scout");_journey_choose();_journey_fight()
		_check(not game.state.mist_approach.is_empty(),"All three patrol routes work using actual earlier choices and earned materials")
		_journey_interact("mist_stone_gauge");_journey_choose();_journey_interact("mist_camp");_journey_choose()
		_journey_interact("mist_gate");_journey_choose();_journey_fight()
		_journey_interact("mist_guide");_journey_choose(school%2)
		_check(game.state.mist_stage==4,"Third chapter completed with natural progression and advanced art")
		game._save();var before=game.state.to_dict();game.state.reset_game();game._load()
		_check(game.state.to_dict()==before,"Complete organic journey round-trips local save")
		# Complete Shen's follow-up using existing roads and earned party, without spending supplies.
		var saved_coins=game.state.coins
		_journey_interact("return_frostbridge");_journey_interact("return_sluice");_journey_interact("return_village")
		_journey_interact("healer");_journey_choose(3);_journey_choose()
		_check(game.state.shen_care_stage==1,"Natural journey discovers and accepts Shen follow-up")
		_journey_interact("exit_sluice");_journey_choose();_journey_interact("stranded_boatman");_journey_choose()
		_journey_interact("sluice_cache");_journey_choose();_journey_interact("return_village")
		_journey_interact("healer");_journey_choose(3);_journey_choose(school%2);_journey_choose()
		_journey_interact("board");_journey_choose();game._close_modal()
		_check(game.state.shen_care_stage==5 and game.state.shen_care_choice==("shore" if school%2==0 else "mobile"),"Natural journey completes care-pact branch")
		_check(game.state.coins==saved_coins and game.state.current_companion()=="唐栖","Care quest needs no purchase or forced follower change")
		game._save();before=game.state.to_dict();game.state.reset_game();game._load()
		_check(game.state.to_dict()==before,"Care pact round-trips after full journey")
		_journey_interact("mentor");_journey_choose(4);_journey_choose(1);_journey_choose()
		_check(game.state.lightness_unlocked,"Natural earned level and school allow free lightness lesson")
		game.world.teleport(game.state.Lightness.SHORE)
		_journey_interact("reed_cross");_journey_choose()
		_check(game.state.Lightness.on_islet(game.world.player_pos),"Learned traversal reaches the separated island")
		_journey_interact("reed_relic");_journey_choose();_journey_interact("reed_return");_journey_choose()
		_check(game.state.lightness_relics==["reed_islet"] and game.state.coins==saved_coins+18,"Natural exploration grants only one island reward")
		game._save();before=game.state.to_dict();game.state.reset_game();game._load()
		_check(game.state.to_dict()==before and game.world.player_pos==game.state.Lightness.SHORE,"Island discovery and safe return persist in full journey")
		# Continue existing organically earned party/resources into the harbor.
		var receipt_before_harbor=game.state.to_dict().duplicate(true)
		var before_port_coins=game.state.coins
		var before_port_xp=game.state.xp+30*game.state.level*(game.state.level-1)
		var before_port_resources=game.state.resources.duplicate(true)
		_journey_interact("exit_sluice");_journey_choose();_journey_interact("exit_frostbridge");_journey_choose();_journey_interact("exit_mistwood");_journey_choose()
		_journey_interact("exit_heting");_journey_choose()
		_check(game.state.map_id=="heting" and game.state.heting_stage==1,"Natural completed chapter unlocks harbor without injected progress")
		var order=["sealed","meal"] if school==0 else ["meal","sealed"]
		for cargo in order:
			_journey_interact("heting_cargo")
			_journey_choose(1 if cargo=="sealed" and not game.state.heting_delivered.has("meal") else 0)
			_check(game.state.heting_cargo==cargo,"Actual finite cargo choice loads expected batch")
			_journey_interact("heting_relief" if cargo=="meal" else "heting_scale");_journey_choose()
		_journey_interact("heting_dispatch");_journey_choose(school%2)
		_journey_interact("heting_lighter");_journey_choose()
		_journey_interact("heting_relief" if school%2==0 else "heting_scale");_journey_choose()
		_check(game.state.heting_stage==4 and game.state.heting_ending==("short_ferries" if school%2==0 else "open_scale"),"Natural full journey completes fourth chapter night allocation")
		_check(game.state.coins==before_port_coins+60 and game.state.xp+30*game.state.level*(game.state.level-1)==before_port_xp+120 and game.state.resources==before_port_resources,"Harbor costs no injected currency/material and grants only finite rewards")
		game._close_modal();game._save();before=game.state.to_dict();game.state.reset_game();game._load()
		_check(game.state.to_dict()==before and game.world.map_id=="heting","Organic four-chapter result persists through current schema13")
		print("JOURNEY: school=%s level=%d hp=%d/%d coins=%d medicines=%d" % [game.state.sect,game.state.level,game.state.hp,game.state.max_hp,game.state.coins,game.state.medicine])

func _journey_interact(id: String) -> void:
	if game.active_modal: game._close_modal()
	_check(game.world.interactables.has(id), "Packed natural journey landmark exists on actual region: "+id)
	if not game.world.interactables.has(id): return
	game.world.teleport(game.world.interactables[id].pos); game._process(0)
	game._interact(id)

func _journey_choose(index: int = 0) -> void:
	if index >= game.modal_actions.size(): _check(false,"Packed natural journey is missing actual numbered choice"); return
	game.modal_actions[index].call()

func _journey_fight() -> void:
	var panel = _party_panel(); _unified_freeze(panel)
	_check(panel != null and game.current_screen == "party_battle" and game.state.battle_active, "Packed natural story route starts real unified battle")
	if panel == null: return
	var before: Dictionary = game.state.to_dict(); var terminal: Dictionary = _sluice_terminal(panel)
	if terminal.is_empty(): return
	_check(game.state.coins == before.coins and game.state.xp == before.xp and game.state.level == before.level, "Packed natural pending victory has no early economy reward")
	if panel.encounter == "sect_trial":
		_check(terminal.after.trial_provenance.met and terminal.after.trial_provenance.required_art == game.state.sect_art(), "Packed natural school trial earns actual required martial provenance")
	_party_finish(panel)
	_check(not game.state.battle_active and game.state.party_settlement.outcome == "win", "Packed natural earned stats/resources win current automatic route")
	if game.active_modal: game._close_modal()

func _schema9_legacy_prerequisite(rehearsal: bool) -> bool:
	var path: String = OS.get_environment("HERO_AUDIT_SCHEMA9_READER")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema9-reader="): path = argument.trim_prefix("--schema9-reader=")
	if path.is_empty() and rehearsal: path = ProjectSettings.globalize_path("res://tests/fixtures/v017_game_state.gd.txt")
	_check(path.is_absolute_path() and FileAccess.file_exists(path), "Unified audit requires external frozen schema9 reader")
	if not path.is_absolute_path() or not FileAccess.file_exists(path): return false
	_check(FileAccess.get_sha256(path) == SCHEMA9_READER_SHA256, "Exact schema9 reader matches immutable pre-harbor source SHA256")
	if FileAccess.get_sha256(path) != SCHEMA9_READER_SHA256: return false
	var script = GDScript.new(); script.source_code = FileAccess.get_file_as_string(path).replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Exact schema9 reader compiles without global registration")
	if error != OK: return false
	schema9_reader = script.new()
	_check(schema9_reader.SAVE_VERSION == 9, "Frozen prior reader retains actual schema9 gate")
	return schema9_reader.SAVE_VERSION == 9
