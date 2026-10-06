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
var _exploration_prerequisite_checks: int = 0
var _condition_prerequisite_checks: int = 0
var _transfer_prerequisite_checks: int = 0
var _transfer_setup_checks: int = 0
var _transfer_directory_counter: int = 0
var checks := 0
var failures := 0
var game
var legacy_reader
var schema9_reader
var schema12_reader
var schema13_reader
var schema14_reader
var schema15_reader
var _schema15_save: String = ""
var _fitting_legacy_model
var _fitting_prerequisite_checks: int = 0
const SCHEMA15_READER_SHA256 := "6a23204d1558b9f2e15ef4150f2c818fb200415fddad00fc35e1e3d99761a159"
const SCHEMA15_SAVE_SHA256 := "decba7dffc7af4906c3e3166e1b32ac9765329434869a3dcd0bf86f3653e17d6"
const FITTING_PROVENANCE_SHA256 := "14912385256444e441350c79e2fd2435af7898ef604cafa0216ed40a3960b292"
const FITTING_LEGACY_MODEL_SHA256 := "e1184548085af19dc0142fd01c25fe667b2be7e661bee50c03fd821899fb1c42"
var _schema14_save: String = ""
var _capstone_prerequisite_checks: int = 0
const SCHEMA14_READER_SHA256 := "160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5"
const SCHEMA14_SAVE_SHA256 := "4ec2f5ecdcd966f5e49a23bff1c0507381cb2bbae563e150c1b5af9ecf98eec2"
const SCHEMA14_PROVENANCE_SHA256 := "91c576ec2e3b85eb71936834427db60796d346a99bd6753689bbd4867429ffb1"
const CAPSTONE_FIELDS: Array[String] = ["capstone_stage", "capstone_draft", "capstone_ending"]
var _consignee_prerequisite_checks: int = 0
var _legacy_save_fixtures: String = ""
const SCHEMA13_READER_SHA256 := "4e052447cb4dbfed20ee3fd22f23261aef043ad7791a457e1e737fe8faa1176d"
const LEGACY_FIXTURE_MANIFEST_SHA256 := "9087fd567f3fa6953ad040025e084b054f535927042f9c8b868318bbab140a46"
const CONSIGNEE_FIELDS: Array[String] = ["consignee_stage", "consignee_observations", "consignee_contributions", "consignee_draft", "consignee_cargo_location", "consignee_ending"]
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
	if not _current_prerequisites() or not _exploration_prerequisites() or not _condition_prerequisites() or not _transfer_prerequisites() or not _consignee_prerequisites() or not _capstone_prerequisites() or not _fitting_prerequisites() or not _journal_prerequisites():
		print("FAIL: current package prerequisites; %d checks; %d failures; no game instantiated" % [checks,failures])
		quit(1); return
	if not _receipt_legacy_prerequisite(rehearsal) or not _party_legacy_prerequisite(rehearsal) or not _schema12_legacy_prerequisite(rehearsal) or not _schema9_legacy_prerequisite(rehearsal) or not _consignee_legacy_prerequisite(rehearsal) or not _capstone_legacy_prerequisite(rehearsal) or not _fitting_legacy_prerequisite(rehearsal) or not _journal_oracle_prerequisite(rehearsal):
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
	_transfer_fresh_title()
	if OS.get_cmdline_user_args().has("--journal-only"):
		await _test_journal_pack()
		await _finish_run(rehearsal, "journal-only")
		return
	if OS.get_cmdline_user_args().has("--fitting-only"):
		await _test_fitting_pack()
		await _finish_run(rehearsal, "fitting-only")
		return
	if OS.get_cmdline_user_args().has("--capstone-only"):
		await _test_capstone_pack()
		await _finish_run(rehearsal, "capstone-only")
		return
	if OS.get_cmdline_user_args().has("--consignee-only"):
		await _test_consignee_pack()
		await _finish_run(rehearsal, "consignee-only")
		return
	if OS.get_cmdline_user_args().has("--transfer-only"):
		await _test_transfer_pack()
		await _finish_run(rehearsal, "transfer-only")
		return
	if OS.get_cmdline_user_args().has("--condition-only"):
		await _test_condition_pack()
		await _finish_run(rehearsal, "condition-only")
		return
	if OS.get_cmdline_user_args().has("--exploration-only"):
		await _test_exploration_pack()
		await _finish_run(rehearsal, "exploration-only")
		return
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
	await _test_exploration_pack()
	await _test_unified_pack()
	await _test_condition_pack()
	await _test_transfer_pack()
	await _test_consignee_pack()
	await _test_heting_polish_pack()
	await _test_capstone_pack()
	await _test_fitting_pack()
	await _test_journal_pack()
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
	_journal_legacy_browse("tang_notes")
	_check(_gather_text(game.overlay).contains("尺上旧痕") and _gather_text(game.overlay).contains("与唐栖商议同行") and game.state.tangqi_stage == 3 and not game.state.tangqi_unlocked and game.journal_session.tracked_arc_id.is_empty() and game.JournalObjectives.row(game.state,"tang_notes").trackable, "Packed journal retains pending invitation: " + choice)
	game._close_modal()
	game._interact("bridge_worker")
	_press("邀请同行")
	game._load()
	await process_frame
	_check(game.state.tangqi_unlocked and game.state.current_companion() == "唐栖" and game.world.has_follower("tang"), "Packed recruitment and follower identity survive reload: " + choice)
	var before: Dictionary = game.state.to_dict()
	game._interact("bridge_worker")
	_check(_find_button(game.overlay, "邀请同行") == null and _find_button(game.overlay, "传给学徒") == null, "Packed completed quest cannot replay rewards: " + choice)
	game._close_modal()
	_check(game.state.to_dict() == before, "Packed completed quest revisit is resource-neutral: " + choice)
	game._show_inventory()
	await _key(KEY_5)
	var folio = game.overlay.get_meta("party_roster", null)
	_check(folio != null and not folio.cells.tang.toggle.disabled and folio.cells.shen.toggle.disabled == not shen and folio.cells.qin.toggle.disabled, "Packed roster enables only genuinely recruited companions: " + choice)
	# The selected party can contain both Shen and Tang. Explicitly bench Shen
	# through the real roster UI before checking the original inactive-clinic case.
	if shen: folio.cells.shen.toggle.pressed.emit()
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
	_check(saved is Dictionary and saved.get("version") == 16 and saved.get("player", {}).get("active_companion") == "唐栖", "Packed save writes schema16 and active party identity: " + choice)
	game._show_journal()
	_journal_legacy_history()
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
	_journal_legacy_history()
	_check(_gather_text(game.overlay).contains("竹坡余声") and _gather_text(game.overlay).contains("先鸣渡船钟") and game.state.mist_stage == 4 and game.state.mist_ending == "warn_ferries" and game.JournalObjectives.row(game.state,"mistwood").display_title == "竹坡余声" and game.JournalObjectives.row(game.state,"mistwood").status == "completed" and not game.JournalObjectives.row(game.state,"mistwood").trackable, "Packed journal records third chapter and chosen ending")
	await _key(KEY_ESCAPE)
	game._save()
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://hero_save.json"))
	_check(saved is Dictionary and saved.get("version") == 16 and saved.get("player", {}).get("mist_ending") == "warn_ferries", "Packed local save writes schema16 and Mistwood ending")
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
	_check(first_doc is Dictionary and first_doc.get("version") == 16 and first_doc.player.coins == 24, "Packed manual save writes the current schema and branch")
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
	_check(saved is Dictionary and saved.get("version") == 16 and saved.player.shen_care_stage == 5 and saved.player.shen_care_choice == choice, "Packed schema16 document records the final care plan: " + choice)
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
	_journal_legacy_history()
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
	_check(_packed_followers_on_islet(lightness), "Packed active follower lands on safe island ground")
	game._load()
	_check(game.world.player_pos == lightness.LANDING and game.state.position == lightness.LANDING and _packed_followers_on_islet(lightness), "Packed crossing autosave restores both hero and follower on the island")
	for facing in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		game.world.teleport(lightness.ISLET_CENTER + Vector2(35, 0))
		game.world.facing = facing
		game.world._process(0.25)
		_check(_packed_followers_on_islet(lightness), "Packed follower stays inside island bounds for facing: " + str(facing))
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
	_journal_legacy_history()
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
	_check(saved is Dictionary and saved.get("version") == 16 and saved.player.lightness_unlocked and saved.player.lightness_relics == [lightness.RELIC_ID], "Packed schema16 document writes lightness progression explicitly")
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
	assert(game.state.recruit_companion());game._sync_world_state()
	_check(game.world._painted_npc_role("healer").is_empty() and game.world.get_npc_name("healer")=="药铺伙计","Packed travelling Shen is not duplicated inside pharmacy")
	assert(game.state.set_party_roster(["hero"]));game._sync_world_state()
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
	# Actual cardinal input establishes path legality, gait and safe trailing space.
	var valid_spacing=true
	for pair in [[Vector2.UP,"move_up"],[Vector2.DOWN,"move_down"],[Vector2.LEFT,"move_left"],[Vector2.RIGHT,"move_right"]]:
		game.world.facing=pair[0];game.world.teleport(Vector2(600,450));game.world.active=true
		var initial:Dictionary=game.world.follower_view("shen")
		valid_spacing=valid_spacing and not initial.is_empty()
		Input.action_press(pair[1])
		for _frame in range(8):
			var before_position:Vector2=game.world.follower_view("shen").position
			game.world._process(.05)
			var actor:Dictionary=game.world.follower_view("shen")
			valid_spacing=valid_spacing and game.world._follower_can_step(before_position,actor.position) and actor.moving==(actor.position.distance_to(before_position)>.0001)
		Input.action_release(pair[1])
		var travelled:Dictionary=game.world.follower_view("shen")
		valid_spacing=valid_spacing and game.world.player_pos.distance_to(Vector2(600,450)+pair[0]*74)<.01 and travelled.walk_distance>initial.walk_distance and travelled.position.distance_to(game.world.player_pos)>35
		for _frame in range(30):game.world._process(.05)
		valid_spacing=valid_spacing and not game.world.follower_view("shen").moving
	_check(valid_spacing,"Packed actual party walking keeps legal segments, moving gait, idle feet and reachable trailing space")
	game.world.teleport(Vector2(600,450))
	# Prepared render fixture only: opacity coverage never represents movement.
	var canopy_valid:bool=true
	for id in ["shen","tang","qin"]:
		var frames:Array[Dictionary]=[{"id":id,"position":Vector2(500,670),"facing":Vector2.DOWN,"moving":false,"walk_phase":0.0,"walk_distance":0.0}]
		game.world._follower_frames=frames
		canopy_valid=canopy_valid and game.world._tree_opacity({"pos":Vector2(510,740),"scale":1.0})==.4
	_check(canopy_valid,"Packed foreground canopy preserves each painted follower's readability")
	game.world._refresh_follower_view()
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
	_check(game.world.has_follower("tang"),"Packed painted follower keeps Tang identity")
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
			# M-only old570 page -> exact720 caption page; chart remains780x330.
			var caption = game.overlay.find_child("MapGuidanceCaption",true,false)
			var paper: Rect2 = Rect2(Vector2.ZERO,page.size)
			_check(page.size.y==720 and chart.size==Vector2(780,330) and chart.position.y==255 and paper.encloses(chart.get_rect()) and paper.encloses(close.get_rect()) and caption != null and caption.visible and not caption.text.is_empty() and paper.encloses(caption.get_rect()) and not caption.get_rect().intersects(chart.get_rect()) and not caption.get_rect().intersects(close.get_rect()),"Packed chart fits its full paper page")
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

func _current_prerequisites() -> bool:
	var previous: int = failures
	_check(ProjectSettings.get_setting("application/config/version", "") == "0.0.33", "Save folio V33 project version is required")
	var model = load("res://scripts/game_state.gd")
	_check(model != null and model.SAVE_VERSION == 16, "V31 keeps actual writer schema16 without a migration")
	for module in ["heting_region", "heting_story", "heting_machinery_art", "heting_worksites_art", "world_material_tiles", "heting_cart_routes"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V18 module retained: " + module)
	for asset in ["heting_machinery_atlas", "heting_worksites_atlas"]:
		_check(ResourceLoader.exists("res://assets/generated/environment/" + asset + ".png"), "V18 painted asset retained: " + asset)
	for module in ["courtyard_exercise_rules", "courtyard_practice_ui", "courtyard_practice_art", "courtyard_training_rigs", "courtyard_practice_backdrop"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V19 courtyard module retained before scene load: " + module)
	for module in ["heting_receipt_rules", "heting_receipt_combat", "heting_receipt_story", "heting_receipt_ui", "heting_receipt_art"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "V20 receipt module retained before scene load: " + module)
	for module in ["automatic_party_combat", "unified_encounter_rules", "party_category_hud", "party_actor_catalog", "party_roster_rules", "party_combat_rules", "party_battle_art", "party_battle_backdrop", "party_battle_ui", "party_command_hud", "party_roster_ui", "qin_companion_rules", "qin_companion_story", "painted_battle_qin"]:
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
		_check(document.version == 16, "Packed autosave writes schema16")
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
		_check(chart != null and chart.map_id == "heting" and chart.heting_bridge == s.heting_bridge and chart.markers.size() == 8, "Packed paper chart retains original harbor topology plus available chapter warehouse")
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
	for version in [10,17]:
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
	for key: String in CONSIGNEE_FIELDS + CAPSTONE_FIELDS + ["weapon_fitting"]: legacy.erase(key)
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
			_check(game.state.save_game(path)==OK, "Packed writer creates actual schema16 receipt stage: "+ending+"/"+str(stage))
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			_check(probe.load_game(path)==OK and probe.to_dict()==game.state.to_dict(), "Packed schema16 stage round-trip preserves exact durable fields")
			_check(legacy_reader.load_game(path)==ERR_FILE_UNRECOGNIZED and _receipt_variables(legacy_reader)==old_before and FileAccess.get_file_as_bytes(path)==bytes and not FileAccess.file_exists(path+".tmp"), "Pinned old reader rejects actual new save before mutating memory or bytes")
	var stable: Dictionary = probe.to_dict()
	for bad: Variant in [-1,4,1.5,"1",true,null]:
		var corrupt: Dictionary = current.duplicate(true); corrupt.receipt_stage=bad
		_receipt_reject_document(probe,path,{"version":13,"player":corrupt},stable,"malformed receipt stage "+str(bad))
	_receipt_reject_document(probe,path,{"version":13,"player":legacy},stable,"missing current receipt field")
	_receipt_reject_document(probe,path,{"version":17,"player":current},stable,"future schema17")
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
	_check(game.state.formation == "护后" and _receipt_document().version == 16, "Packed roster formation writes current schema16 checkpoint")
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
			_check(_receipt_document().version == 16 and s.load_game() == OK and s.qin_stage == index+1, "Packed Qin stage autosaves and reloads exactly")
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
	for key: String in CONSIGNEE_FIELDS + CAPSTONE_FIELDS + ["weapon_fitting"]: historical.erase(key)
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
		_check(s.set_party_roster(roster) and s.save_game(path)==OK, "Packed actual schema16 serializes explicit%d actor roster" % roster.size())
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		_check(probe.load_game(path)==OK and probe.to_dict()==s.to_dict(), "Packed schema16 roundtrip preserves downed, benched and active own resources")
		_check(schema11_reader.load_game(path)==ERR_FILE_UNRECOGNIZED and _receipt_variables(schema11_reader)==frozen_before and FileAccess.get_file_as_bytes(path)==bytes and not FileAccess.file_exists(path+".tmp"), "Frozen exact schema11 reader rejects real schema16 before changing any live field or source bytes")
	var current: Dictionary = s.to_dict(); var stable: Dictionary = probe.to_dict()
	for key: String in current:
		if CONSIGNEE_FIELDS.has(key) or CAPSTONE_FIELDS.has(key) or key == "weapon_fitting": continue
		var missing: Dictionary = current.duplicate(true); missing.erase(key)
		_receipt_reject_document(probe,path,{"version":16,"player":missing},stable,"missing current field "+key)
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
	_receipt_reject_document(probe,path,{"version":17,"player":current},stable,"future schema17 with valid current roster")

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
	_check(_receipt_document().version == 16 and _receipt_document().player.side_choice == game.state.side_choice and _receipt_document().player.side_found == game.state.side_found, "Packed pre-entry checkpoint includes current route and clue order")
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
	_check(s.save_game() == OK, "Packed schema16 sluice checkpoint writes: " + label)
	var bytes: PackedByteArray = _receipt_bytes(); var document: Dictionary = _receipt_document()
	_check(document.version == 16 and document.player == JSON.parse_string(JSON.stringify(before)) and not bytes.get_string_from_utf8().contains("vulnerability") and not bytes.get_string_from_utf8().contains("_party_sluice_entry"), "Packed checkpoint keeps full canonical state and excludes battle-only fields: " + label)
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
	_check(not game.save_warning and _receipt_document().version == 16 and _receipt_document().player == JSON.parse_string(JSON.stringify(settled)), "Packed real F5 retry persists already-settled sluice resources once")
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
	_check(_receipt_document().version == 16 and _receipt_document().player.chapter_two_stage == 2 and _receipt_document().player.seal_sequence == JSON.parse_string(JSON.stringify([2,0,1])), "Packed pre-entry archive checkpoint durably records solved seal")
	return panel

func _archive_checkpoint(label: String) -> void:
	var s = game.state; var before: Dictionary = s.to_dict()
	_check(s.save_game() == OK, "Packed schema16 archive checkpoint writes: "+label)
	var bytes: PackedByteArray = _receipt_bytes(); var document: Dictionary = _receipt_document()
	_check(document.version == 16 and document.player == JSON.parse_string(JSON.stringify(before)) and not bytes.get_string_from_utf8().contains("vulnerability") and not bytes.get_string_from_utf8().contains("_party_archive_entry"), "Packed archive checkpoint preserves complete canonical state without encounter-only fields: "+label)
	game._load()
	_check(s.to_dict() == before and not s.battle_active and s.party_session == null and s._party_archive_entry.is_empty() and _receipt_bytes() == bytes, "Packed reload preserves exact archive resources/progress and clears transient encounter: "+label)
	var old10: Dictionary = _receipt_variables(legacy_reader); var old11: Dictionary = _receipt_variables(schema11_reader)
	_check(legacy_reader.load_game(s.SAVE_PATH) == ERR_FILE_UNRECOGNIZED and schema11_reader.load_game(s.SAVE_PATH) == ERR_FILE_UNRECOGNIZED and _receipt_variables(legacy_reader) == old10 and _receipt_variables(schema11_reader) == old11 and _receipt_bytes() == bytes, "Packed actual schema10/11 readers reject archive schema16 without any mutation: "+label)

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
	_check(rules.SUPPORTED_ENCOUNTERS == ["story","training","sect_trial","courtyard_practice","sluice_scout","sluice_boss","archive_boss","mist_scout","mist_keeper","heting_receipt", "heting_consignee", "capstone_authorizer"] and rules.SUPPORTED_ENCOUNTERS == encounters.IDS, "Packed all12 normal encounters share one explicit automatic catalog")
	game._show_title(); var title = game.overlay.find_child("BuildVersion",true,false)
	_check(title != null and title.text=="0.0.33", "Packed actual title retains save folio0.0.33 identity")
	for kind: String in encounters.IDS.slice(0,10): await _test_unified_entry(kind)
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
	var expected_backdrop: String = "courtyard" if kind in ["training","sect_trial","courtyard_practice"] else "ferry"
	_check(panel.art.backdrop_style == expected_backdrop, "Packed actual encounter chooses correct courtyard/ferry backdrop: " + kind)
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
	game._load(); _check(s.internal_unlocked and _receipt_document().version == 16, "Packed actual lesson autosaves and reloads schema16")
	await _talk("mentor"); _press("内功与轻身"); _press("轻功 · 踏苇行"); _press("修习踏苇行")
	_check(s.lightness_unlocked and s.internal_unlocked, "Packed separately chosen free lightness lesson remains independent")

func _test_unified_migration() -> void:
	var model = load("res://scripts/game_state.gd"); var fresh = model.new(); var legacy: Dictionary = fresh.to_dict(); legacy.erase("internal_unlocked")
	for key: String in CONSIGNEE_FIELDS + CAPSTONE_FIELDS + ["weapon_fitting"]: legacy.erase(key)
	var path: String = "user://unified-schema13-audit.json"
	for version: int in range(1,13):
		_receipt_write_document(path,{"version":version,"player":legacy}); var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var probe = model.new()
		_check(probe.load_game(path) == OK and not probe.internal_unlocked and FileAccess.get_file_as_bytes(path) == bytes, "Packed schema%d migration never grants internal lesson or rewrites old bytes" % version)
	var before: Dictionary = game.state.to_dict()
	_check(game.state.save_game(path) == OK, "Packed learned schema16 creates actual complete save")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for reader in [schema9_reader,legacy_reader,schema11_reader,schema12_reader]:
		var stable: Dictionary = _receipt_variables(reader)
		_check(reader.load_game(path) == ERR_FILE_UNRECOGNIZED and _receipt_variables(reader) == stable and FileAccess.get_file_as_bytes(path) == bytes, "Packed exact frozen prior reader rejects schema16 without memory or disk mutation")
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
		_check(game.state.to_dict()==before and game.world.map_id=="heting","Organic four-chapter result persists through current schema16")
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

func _packed_followers_on_islet(lightness) -> bool:
	if game.world.follower_ids().is_empty():return false
	for id in game.world.follower_ids():
		if not lightness.on_islet(game.world.follower_view(id).position):return false
	return true

func _exploration_prerequisites() -> bool:
	var previous: int = failures
	var first: int = checks
	for module: String in ["exploration_party_trail", "painted_qin_sprite"]:
		_check(ResourceLoader.exists("res://scripts/" + module + ".gd"), "Exploration package retains runtime module: " + module)
	for direction: String in ["front", "right", "back", "left"]:
		_check(ResourceLoader.exists("res://assets/generated/characters/painted_qin_walk_" + direction + ".png"), "Exploration package retains authored Qin direction: " + direction)
	_check(ResourceLoader.exists("res://assets/generated/characters/painted_qin_idle.png"), "Exploration package retains separate authored Qin neutral idle atlas")
	_exploration_prerequisite_checks = checks - first
	return failures == previous

func _exploration_positions() -> Dictionary:
	var result: Dictionary = {}
	for id: String in game.world.follower_ids(): result[id] = game.world.follower_view(id).position
	return result

func _exploration_safe() -> bool:
	var occupied: Array = []
	for id: String in game.world.follower_ids():
		var actor: Dictionary = game.world.follower_view(id)
		if not actor.position.is_finite() or not game.world._follower_can_walk(actor.position) or occupied.has(actor.position): return false
		occupied.append(actor.position)
	return true

func _test_exploration_pack() -> void:
	var first: int = checks
	var qin = load("res://scripts/painted_qin_sprite.gd")
	_check(qin != null and qin.FRAME_COUNT == 4 and game.world.QinWalk == qin, "Packed world uses the four-key exploration Qin renderer")
	if qin == null: return
	var all_hashes: Dictionary = {}
	for pair: Array in [["front", Vector2.DOWN], ["right", Vector2.RIGHT], ["back", Vector2.UP], ["left", Vector2.LEFT]]:
		var direction: String = pair[0]
		_check(qin.direction_for(pair[1]) == direction, "Packed Qin renderer resolves direction: " + direction)
		var hashes: Dictionary = {}
		for frame: int in range(4):
			var texture = qin.texture_for(direction, frame)
			_check(texture != null and texture.atlas.get_size() == Vector2(1254,1254) and texture.get_size() == Vector2(672,672), "Packed Qin imported atlas/cell dimensions: " + direction + str(frame))
			if texture == null: continue
			_check(texture.filter_clip and texture.margin.position.x >= 0 and texture.margin.position.y >= 0 and texture.region.size.x + texture.margin.position.x <= 672 and texture.region.size.y + texture.margin.position.y <= 672, "Packed Qin authored key fits stable cell without clipping: " + direction + str(frame))
			var image: Image = texture.atlas.get_image()
			_check(image != null and not image.is_empty(), "Packed Qin imported pixels are readable: " + direction + str(frame))
			if image != null and not image.is_empty():
				var pixels: PackedByteArray = image.get_region(Rect2i(texture.region)).get_data()
				var hasher := HashingContext.new(); hasher.start(HashingContext.HASH_SHA256); hasher.update(pixels)
				var digest: String = hasher.finish().hex_encode()
				_check(not hashes.has(digest) and not all_hashes.has(digest), "Packed Qin key has genuinely distinct source pixels: " + direction + str(frame))
				hashes[digest] = true; all_hashes[digest] = true
			_check(qin.texture_for(direction,frame+4) == texture and qin.texture_for(direction,frame-4) == texture, "Packed Qin positive/negative wrapping reuses authored crop: " + direction + str(frame))
		_check(hashes.size() == 4, "Packed Qin has four distinct authored poses: " + direction)
	_check(all_hashes.size() == 16, "Packed Qin has sixteen distinct authored direction/pose crops")
	var foot := Vector2(123,234)
	var rect: Rect2 = qin.drawing_rect(foot)
	_check(rect.size == Vector2(72,72) and (rect.position + qin.FOOT * (72.0/672.0)).is_equal_approx(foot), "Packed Qin retains fixed 72px scale and ground anchor")
	_check(qin.texture_for("unknown",0) == null, "Packed Qin rejects an unknown direction")
	_test_qin_idle_pack(qin, all_hashes)
	# Recruitment APIs establish eligibility. Damage is applied only after setup.
	_party_prepare(4)
	_check(game.state.begin_heting(), "Packed exploration starts eligible harbor chapter through actual API")
	game.set_process(false); game.world.set_process(false); game.world.active = true
	game.state.party_resources.shen = {"hp":7,"qi":0}
	game.state.party_resources.tang = {"hp":0,"qi":1}
	game.state.party_resources.qin = {"hp":9,"qi":2}
	var resources: Dictionary = game.state.party_resources.duplicate(true)
	var routes: Dictionary = {"qingwei":Vector2(400,450), "sluice":Vector2(300,500), "frostbridge":Vector2(350,805), "mistwood":Vector2(400,450), "heting":Vector2(400,350)}
	for map_id: String in routes:
		for count: int in range(1,4):
			var selected: Array = ["qin","tang","shen"].slice(0,count)
			_check(game.state.set_party_roster(["hero"] + selected), "Packed actual roster selects ordered exploration count: " + map_id + str(count))
			game.state.map_id = map_id; game._sync_world_state()
			game.world.facing = Vector2.RIGHT; game.world.change_map(map_id,routes[map_id]); game.world.active = true
			_check(game.world.follower_ids() == selected and game.world.exploration_actor_positions().size() == count+1, "Packed map includes every selected actor in order: " + map_id + str(count))
			_check(_exploration_safe() and game.world._can_step(routes[map_id],routes[map_id]+Vector2(277.5,0)), "Packed exploration fixture has a legal full input route: " + map_id + str(count))
			var initial: Dictionary = _exploration_positions()
			var reseeds: int = game.world._follower_reseed_count
			var valid: bool = true
			Input.action_press("move_right")
			for _frame: int in range(30):
				var before: Dictionary = _exploration_positions()
				game.world._process(.05)
				for id: String in selected:
					var actor: Dictionary = game.world.follower_view(id)
					valid = valid and game.world._follower_can_step(before[id],actor.position) and actor.moving == (actor.position.distance_to(before[id])>.0001)
			Input.action_release("move_right")
			_check(valid and game.world.player_pos.distance_to(routes[map_id]+Vector2(277.5,0)) < .01, "Packed actual ordered following moves only through legal accepted segments: " + map_id + str(count))
			_check(game.world._follower_reseed_count == reseeds and _exploration_safe(), "Packed ordinary following never uses a reseed shortcut: " + map_id + str(count))
			for rank: int in range(selected.size()):
				var actor: Dictionary = game.world.follower_view(selected[rank])
				_check(actor.position != initial[selected[rank]] and actor.walk_distance > 0 and actor.walk_phase > 0 and actor.facing.dot(Vector2.RIGHT) > .99, "Packed actor advances authored gait from actual displacement: " + map_id + selected[rank])
				_check(absf(game.world.player_pos.x-actor.position.x-45.0*(rank+1)) < .03, "Packed actual follower rank stays at its 45-unit path gap: " + map_id + selected[rank])
			for _frame: int in range(20): game.world._process(.05)
			var idle: Array = game.world._party_trail.snapshot(); game.world._process(.05)
			_check(game.world._party_trail.snapshot() == idle and not game.world.follower_view(selected[-1]).moving, "Packed stopped feet and gait remain stable: " + map_id + str(count))
			var layers: Array = []; game.world.append_follower_layers(layers)
			var ids: Array = []
			for layer: Dictionary in layers: ids.append(layer.id)
			_check(ids == selected and layers.size() == count, "Packed shared renderer receives exactly selected follower layers: " + map_id + str(count))
			_check(game.state.party_resources == resources and game.state.party_resources.tang.hp == 0, "Packed exploration leaves injured and HP0 resources exact: " + map_id + str(count))
	# Actual selected HP0 remains visible; benched and unrecruited actors do not.
	_check(game.world.has_follower("tang") and game.state.party_resources.tang.hp == 0, "Packed selected HP0 Tang is visible without healing")
	_check(game.state.set_party_roster(["hero","qin"]), "Packed roster benches two actors")
	game._sync_world_state()
	_check(game.world.follower_ids() == ["qin"] and not game.world.has_follower("shen") and not game.world.has_follower("tang") and game.state.party_resources == resources, "Packed benched followers disappear without changing injuries")
	_check(game.state.set_party_roster(["hero","tang","shen","qin"]), "Packed roster reselects injured actors in new order")
	game._sync_world_state()
	_check(game.world.follower_ids() == ["tang","shen","qin"] and game.state.party_resources == resources, "Packed reordered reselection preserves each actor's resources")
	await _exploration_boundaries()
	game._process(0) # Actual main loop synchronizes the accepted player position before save.
	var durable: Dictionary = game.state.to_dict()
	_check(game.state.save_game() == OK, "Packed exploration writes ordinary schema16 save")
	game._load(); game.set_process(false); game.world.set_process(false)
	_check(game.state.to_dict() == durable and game.world.follower_ids() == ["tang","shen","qin"] and _exploration_safe(), "Packed reload reconstructs selected followers without adding persistent trail state or healing")
	game._new_game(); game.set_process(false); game.world.set_process(false)
	_check(game.world.follower_ids().is_empty(), "Packed unrecruited new game has no fabricated followers")
	print("Ordered exploration party exact-runtime coverage: %d checks; actual input, 1-3 followers, all5maps, HP0/noheal, exclusion,16 distinct Qin walk poses plus4 separate neutral idles,collision/reseed; native PCK resource semantics only" % (checks-first+_exploration_prerequisite_checks))

func _test_qin_idle_pack(qin, walking_hashes: Dictionary) -> void:
	var path := "res://assets/generated/characters/painted_qin_idle.png"
	_check(qin.IDLE_PATH == path and qin.IDLE_SCALE == 1.125 and qin.CELL == Vector2(672,672) and qin.FOOT == Vector2(336,633), "Packed Qin idle retains one fixed scale, logical cell and foot contract")
	var expected: Dictionary = {
		"front": [Rect2(233,49,289,553), Vector2(191,88)],
		"left": [Rect2(799,53,259,551), Vector2(207,90)],
		"back": [Rect2(234,646,288,546), Vector2(190,95)],
		"right": [Rect2(798,649,254,542), Vector2(201,99)],
	}
	var hashes: Dictionary = {}
	for direction: String in ["front", "right", "back", "left"]:
		var texture = qin.idle_texture_for(direction)
		_check(texture != null and texture.atlas.get_size() == Vector2(1254,1254) and texture.get_size() == Vector2(672,672), "Packed Qin neutral idle atlas/cell dimensions: " + direction)
		if texture == null: continue
		_check(texture.atlas.resource_path == path and texture.atlas != qin.texture_for(direction,0).atlas, "Packed Qin idle uses separate neutral artwork rather than a walking key: " + direction)
		_check(qin.idle_texture_for(direction) == texture, "Packed Qin idle cache preserves stable direction texture: " + direction)
		_check(texture.filter_clip and texture.margin.position.x >= 0 and texture.margin.position.y >= 0 and texture.region.size.x + texture.margin.position.x <= 672 and texture.region.size.y + texture.margin.position.y <= 672, "Packed Qin neutral idle fits stable cell without clipping: " + direction)
		_check(texture.region == expected[direction][0] and texture.margin.position == expected[direction][1], "Packed Qin neutral idle keeps authored direction crop and ground placement: " + direction)
		var image: Image = texture.atlas.get_image()
		_check(image != null and not image.is_empty(), "Packed Qin imported neutral idle pixels are readable: " + direction)
		if image != null and not image.is_empty():
			var hasher := HashingContext.new(); hasher.start(HashingContext.HASH_SHA256); hasher.update(image.get_region(Rect2i(texture.region)).get_data())
			var digest: String = hasher.finish().hex_encode()
			_check(not hashes.has(digest) and not walking_hashes.has(digest), "Packed Qin neutral idle has distinct authored pixels: " + direction)
			hashes[digest] = true
	_check(hashes.size() == 4, "Packed Qin has four distinct separate neutral standing crops")
	_check(qin.idle_texture_for("unknown") == null, "Packed Qin neutral idle rejects an unknown direction")
	var foot := Vector2(321,432)
	var height: float = 72.0 * qin.IDLE_SCALE
	var rect: Rect2 = qin.drawing_rect(foot,height)
	_check(rect.size == Vector2(81,81) and (rect.position + qin.FOOT * (height / 672.0)).is_equal_approx(foot), "Packed Qin idle uses fixed source-scale correction without shifting the foot anchor")

func _exploration_boundaries() -> void:
	# All four diagonal quadrants use actual input and the packed corrected model.
	game.state.map_id = "qingwei"; game._sync_world_state(); game.world.change_map("qingwei",Vector2(600,450))
	for pair: Array in [["move_right","move_down",Vector2(1,1)],["move_left","move_down",Vector2(-1,1)],["move_left","move_up",Vector2(-1,-1)],["move_right","move_up",Vector2(1,-1)]]:
		game.world.facing = pair[2].normalized(); game.world.teleport(Vector2(600,450)); game.world.active = true
		var reseeds: int = game.world._follower_reseed_count
		var valid: bool = true
		Input.action_press(pair[0]); Input.action_press(pair[1])
		for _frame: int in range(40):
			game.world._process(1.0/60.0)
			valid = valid and _exploration_safe() and game.world._party_trail.status().ok
		Input.action_release(pair[0]); Input.action_release(pair[1])
		_check(valid and game.world._follower_reseed_count == reseeds and game.world.player_pos.distance_to(Vector2(600,450)+pair[2].normalized()*185.0*40.0/60.0)<.03, "Packed diagonal input preserves legal trails without spontaneous reseed: " + str(pair[2]))
		var debug: Dictionary = game.world._party_trail.debug_snapshot()
		for rank: int in range(3):
			var actor: Dictionary = debug.actors[game.world.follower_ids()[rank]]
			_check(absf(debug.head-actor.cursor-45.0*(rank+1))<.03, "Packed diagonal rank retains bounded arc gap: " + str(pair[2]) + str(rank))
	var lightness = load("res://scripts/lightness_rules.gd")
	var before: Dictionary = game.state.party_resources.duplicate(true)
	var reseeds: int = game.world._follower_reseed_count
	game.world.teleport(lightness.LANDING)
	_check(game.world._follower_reseed_count == reseeds+1 and game.world.follower_recovery_reason == "teleport" and _packed_followers_on_islet(lightness) and _exploration_safe(), "Packed explicit island teleport reseeds all three on separate legal island ground")
	_check(not game.world._follower_can_step(lightness.SHORE,lightness.LANDING) and game.state.party_resources == before, "Packed island arrival cannot fabricate a walkable water segment or heal")
	# Real removable deck topology: all actors walk on west deck before removal.
	game.state.map_id="heting"; game.state.heting_bridge="west"; game.state.heting_cargo=""
	game._sync_world_state(); game.world.facing=Vector2.LEFT; game.world.change_map("heting",Vector2(820,725)); game.world.active=true
	Input.action_press("move_left")
	for _frame: int in range(65): game.world._process(.05)
	Input.action_release("move_left")
	var region = load("res://scripts/heting_region.gd")
	var on_deck: bool = false
	for id: String in game.world.follower_ids(): on_deck = on_deck or region.WEST_PONTOON.has_point(game.world.follower_view(id).position)
	_check(on_deck, "Packed topology fixture actually has a follower on removable west deck")
	game.state.heting_bridge="east"; game._sync_world_state()
	var player: Vector2=game.world.player_pos
	var durable: Dictionary=game.state.to_dict()
	reseeds=game.world._follower_reseed_count; game.world._process(.05)
	_check(game.world._follower_reseed_count==reseeds+1 and game.world.follower_recovery_reason=="topology" and game.world.player_pos==player and _exploration_safe(), "Packed removed deck reseeds legal followers on the current connected shore")
	_check(game.state.to_dict()==durable and game.state.party_resources==before, "Packed topology repair preserves hero position, progress and injured resources")
	game.state.heting_cargo="meal"; game._sync_world_state(); game.world.change_map("heting",Vector2(820,665))
	_check(not game.world._can_walk(Vector2(805,510)) and game.world._follower_can_walk(Vector2(805,510)), "Packed followers retain pedestrian pier collision while loaded hero obeys cart limits")
	game.state.heting_cargo=""; game._sync_world_state(); game.world._process(0)
	# Real packed model fault outcomes must stop; only topology/teleport may reseed.
	var trail=load("res://scripts/exploration_party_trail.gd").new()
	var walk: Callable=func(p:Vector2)->bool:return p.is_finite()
	var step: Callable=func(a:Vector2,b:Vector2)->bool:return a.is_finite() and b.is_finite()
	_check(trail.set_members(["shen"],Vector2.ZERO,Vector2.RIGHT,walk,step).ok and trail.record_segment(Vector2.ZERO,Vector2(200,0)).ok, "Packed trail accepts explicit legal control route")
	var wall: Callable=func(a:Vector2,b:Vector2)->bool:return a.x<90 and b.x<90
	for _frame: int in range(100): trail.advance(.1,walk,wall)
	var outcome: Dictionary=trail.status()
	_check(outcome.reason=="blocked_history" and trail.snapshot()[0].position.x<90, "Packed trail stops at changed collision instead of shortcutting")
	var positions: Dictionary=_exploration_positions(); reseeds=game.world._follower_reseed_count
	game.world._recover_follower_fault(outcome)
	_check(game.world._follower_reseed_count==reseeds and _exploration_positions()==positions, "Packed world does not reseed a blocked-history outcome")
	trail=load("res://scripts/exploration_party_trail.gd").new()
	trail.set_members(["shen"],Vector2.ZERO,Vector2.RIGHT,walk,step)
	outcome=trail.record_segment(Vector2.ZERO,Vector2(9000,0)); game.world._recover_follower_fault(outcome)
	_check(outcome.reason=="history_capacity" and game.world._follower_reseed_count==reseeds and _exploration_positions()==positions, "Packed history capacity fails closed without teleporting actors")
	game.world.follower_recovery_reason="" # Clear diagnostic only; no membership/resource mutation.

# V25 adds a separately counted projection/input suite. All state comes from
# packaged runtime models; no release assertion depends on res://tests fixtures.
func _condition_prerequisites() -> bool:
	var previous: int = failures
	var first: int = checks
	_check(ResourceLoader.exists("res://scripts/exploration_companion_condition.gd"), "Condition package retains the actual compact companion display module")
	_condition_prerequisite_checks = checks-first
	return failures == previous

func _condition_orders(prefix: Array = []) -> Array:
	var result: Array = [prefix.duplicate()]
	for id: String in ["shen", "tang", "qin"]:
		if not prefix.has(id): result.append_array(_condition_orders(prefix+[id]))
	return result

func _condition_projected_ids(snapshot: Dictionary) -> Array:
	var ids: Array = []
	if not snapshot.get("ok", false): return ids
	for id: String in snapshot.roster:
		if id != "hero": ids.append(id)
	return ids

func _condition_card_matches(row, snapshot: Dictionary, id: String) -> bool:
	if not row.cards.has(id): return false
	var card: Dictionary = row.cards[id]
	var actor: Dictionary = _party_actor(snapshot,id)
	var selected: bool = snapshot.get("ok",false) and snapshot.get("roster",[]).has(id)
	if card.button.visible != selected: return false
	if not selected: return true
	return card.hp_bar.value == actor.hp and card.hp_bar.max_value == actor.max_hp and card.qi_bar.value == actor.qi and card.qi_bar.max_value == actor.max_qi and card.status.text.contains("倒下") == (int(actor.hp)==0)

func _condition_projection_matches(row) -> bool:
	var snapshot: Dictionary = game.state.party_resource_snapshot()
	if not snapshot.get("ok",false) or row.displayed_ids != _condition_projected_ids(snapshot): return false
	for id: String in ["shen", "tang", "qin"]:
		if not _condition_card_matches(row,snapshot,id): return false
	return true

func _condition_folio():
	return game.overlay.get_meta("party_roster") if game.overlay.has_meta("party_roster") else null

func _condition_freeze() -> void:
	game.set_process(false); game.world.set_process(false)
	game._process(0)

func _condition_injure() -> void:
	game.state.hp = 17; game.state.qi = 1
	game.state.party_resources.shen = {"hp":7,"qi":0}
	game.state.party_resources.tang = {"hp":0,"qi":1}
	game.state.party_resources.qin = {"hp":9,"qi":2}
	game._refresh(); game._process(0)

func _condition_key(key: Key, shift: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key; event.keycode = key; event.pressed = true
	event.shift_pressed = shift; event.echo = echo
	Input.parse_input_event(event); await process_frame
	event.pressed = false; event.echo = false
	Input.parse_input_event(event); await process_frame

func _condition_click(button: Control) -> void:
	game._process(0)
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false; root.push_input(event, true)
	await process_frame

func _test_condition_pack() -> void:
	var first: int = checks
	game._new_game(); _condition_freeze()
	var row = game.hud.companion_condition
	_check(row != null and row.get_script() == load("res://scripts/exploration_companion_condition.gd"), "Packed main HUD instantiates the real condition component")
	if row == null: return
	_check(row.displayed_ids.is_empty() and _condition_projection_matches(row), "Packed new journey displays no fabricated or unrecruited companion")
	_check(game.hud.identity_wash.position == Vector2(20,23) and game.hp_bar.value == game.state.hp, "Packed compact display preserves the existing protagonist HUD")
	_party_prepare(4); _condition_freeze(); _condition_injure()
	var portraits = load("res://scripts/character_portraits.gd")
	for id: String in ["shen", "tang", "qin"]:
		var shown = row.cards[id].portrait.texture
		var authored = portraits.texture_for(id)
		_check(shown is AtlasTexture and shown.atlas == authored.atlas and shown.region == authored.region and shown.filter_clip and shown.atlas.get_image() != null, "Packed compact portrait uses the original imported actor crop: "+id)
	var orders: Array = _condition_orders()
	_check(orders.size() == 16, "Packed condition suite enumerates all sixteen ordered companion subsets")
	for selected: Array in orders:
		_check(game.state.set_party_roster(["hero"]+selected), "Packed condition accepts actual ordered roster: "+str(selected))
		var before: Dictionary = game.state.to_dict().duplicate(true)
		var files: Dictionary = _courtyard_save_files()
		game._refresh(); game._process(0)
		var snapshot: Dictionary = game.state.party_resource_snapshot()
		_check(row.displayed_ids == selected, "Packed compact display follows actual selected roster order: "+str(selected))
		var increasing: bool = true; var x: float = -INF
		for id: String in selected:
			var center: float = row.cards[id].button.get_global_rect().get_center().x
			increasing = increasing and center > x; x = center
		_check(increasing, "Packed compact cards occupy their declared left-to-right roster order: "+str(selected))
		for id: String in ["shen", "tang", "qin"]:
			_check(_condition_card_matches(row,snapshot,id), "Packed compact HP/Qi/downed and omission reflect real selected actor: "+str(selected)+id)
		_check(game.state.to_dict() == before and _courtyard_save_files() == files, "Packed condition refresh changes no resources/roster/progression or save bytes: "+str(selected))
	_check(game.state.set_party_roster(["hero","qin","tang","shen"]), "Packed condition prepares noncanonical deployed order")
	game.state.active_companion = "沈青"; game._refresh(); game._process(0)
	_check(row.displayed_ids == ["qin","tang","shen"] and row.cards.tang.status.text.contains("倒下"), "Packed condition ignores legacy preference and retains selected HP0 actor")
	await _condition_readonly_inputs(row)
	await _condition_failure_refresh(row)
	await _condition_hidden_boundaries(row)
	await _condition_live_changes(row)
	game._new_game(); _condition_freeze()
	_check(row.displayed_ids.is_empty() and _condition_projection_matches(row), "Packed condition discards recruited display after new-game replacement")
	game._show_title(); game._process(0)
	_check(not row.is_visible_in_tree(), "Packed condition disappears on actual title return")
	print("Exploration companion condition exact-runtime coverage: %d checks; actual packaged HUD and original portraits; all16 ordered subsets; exact HP/Qi/downed; native mouse/keys; read-only folio/story return; stale/failed-snapshot guards; modal/battle/quit suppression; rest/load/roster/practice freshness; no browser claim" % (checks-first+_condition_prerequisite_checks))

func _condition_readonly_inputs(row) -> void:
	var before: Dictionary = game.state.to_dict().duplicate(true)
	_check(game.state.save_game() == OK, "Packed condition records an isolated checkpoint before view-only interaction")
	var files: Dictionary = _courtyard_save_files()
	var generation: int = game.modal_generation
	for id: String in ["qin","tang","shen"]:
		row.cards[id].button.grab_focus(); game._process(0)
		var actor: Dictionary = _party_actor(game.state.party_resource_snapshot(),id)
		_check(row.detail_panel.visible and row.detail_label.text.contains(actor.name) and row.detail_label.text.contains("气血  %d / %d" % [actor.hp,actor.max_hp]) and row.detail_label.text.contains("真气  %d / %d" % [actor.qi,actor.max_qi]) and row.cards[id].button.get_meta("downed") == (actor.hp == 0), "Packed keyboard inspection exposes own exact numeric resources: "+id)
	row.cards.qin.button.grab_focus(); await _condition_key(KEY_TAB,true)
	_check(row.roster_button.has_focus(), "Packed native Shift-Tab wraps from first selected card to roster entry")
	await _condition_key(KEY_ENTER,false,true)
	_check(not game.active_modal and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed held-key echo cannot activate compact entry or rewrite a save")
	await _condition_click(row.cards.qin.button)
	var folio = _condition_folio()
	_check(folio != null and game.active_modal and game.current_screen == "explore", "Packed real pointer on compact Qin opens the actual roster folio")
	if folio == null: return
	game._process(0)
	var stale_change: Callable = folio._toggle_actor.bind("qin")
	var position: Vector2 = game.world.player_pos
	Input.action_press("move_right"); game.world._process(.08); Input.action_release("move_right")
	_check(game.world.player_pos == position and not game.world.active, "Packed held movement cannot leak through direct roster modal")
	_check(not row.is_visible_in_tree() and not row.detail_panel.visible, "Packed direct folio suppresses compact cards and floating details")
	_check(folio.return_button.text.contains("赶路") or folio.return_button.text.contains("探索"), "Packed direct-origin roster labels its exploration return")
	game._show_exploration_party_roster(generation)
	_check(_condition_folio() == folio, "Packed stale double activation cannot replace the open direct roster")
	await _key(KEY_ESCAPE); game._process(0)
	_check(not game.active_modal and game.current_screen == "explore" and not game.overlay.has_meta("inventory") and row.is_visible_in_tree(), "Packed native Esc from direct roster returns immediately to exploration")
	_check(game.state.to_dict() == before and _courtyard_save_files() == files, "Packed pointer view and Esc preserve every model value and saved/backup byte")
	if stale_change.is_valid(): stale_change.call()
	game._show_exploration_party_roster(generation)
	_check(not game.active_modal and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed dismissed roster and old compact-generation callbacks cannot mutate or reopen the journey")
	for key: Key in [KEY_ENTER,KEY_SPACE]:
		row.roster_button.grab_focus()
		await _key(key)
		folio = _condition_folio()
		_check(folio != null and game.active_modal, "Packed focused direct entry opens through actual native key: "+str(key))
		if folio == null: return
		await _key(KEY_ESCAPE); game._process(0)
		_check(not game.active_modal and row.is_visible_in_tree() and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed keyboard view/close remains read-only: "+str(key))
	row.cards.qin.button.grab_focus(); await _key(KEY_TAB)
	_check(row.cards.tang.button.has_focus(), "Packed native Tab follows selected compact-card order")
	row.cards.qin.button.grab_focus()
	await _key(KEY_RIGHT)
	_check(not game.active_modal and not row.cards.qin.button.has_focus(), "Packed directional input releases compact focus without opening or navigating a folio")
	await _condition_click(row.roster_button)
	folio = _condition_folio()
	_check(folio != null, "Packed direct roster button accepts native pointer input")
	if folio == null: return
	folio.cells.tang.story.pressed.emit(); game._process(0)
	_check(game.active_modal and _gather_text(game.overlay).contains("唐栖") and not row.is_visible_in_tree(), "Packed direct-origin story opens actual Tang information while condition stays hidden")
	await _key(KEY_ESCAPE); game._process(0)
	_check(not game.active_modal and not game.overlay.has_meta("inventory") and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed direct-origin story Escape retains exploration context without save mutation")
	game._show_inventory(); await _key(KEY_5)
	folio = _condition_folio()
	_check(folio != null and folio.return_button.text.contains("行囊"), "Packed existing inventory-origin roster keeps its inventory return")
	await _key(KEY_ESCAPE)
	_check(game.active_modal and game.overlay.get_meta("inventory",false), "Packed inventory-origin Escape still returns to inventory")
	game._close_modal(); game._process(0)
	game.world.teleport(game.world.interactables.elder.pos); game._process(0); row.cards.qin.button.grab_focus()
	await _key(KEY_E)
	_check(game.active_modal and not game.overlay.has_meta("party_roster") and _gather_text(game.overlay).contains("陆伯"), "Packed focused compact card leaves E available for the real nearby NPC")
	game._close_modal(); game._process(0)

func _condition_failure_refresh(row) -> void:
	var valid_roster: Array = game.state.party_roster.duplicate()
	game.state.party_roster.assign(["hero","qin","qin"]); game._refresh()
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var files: Dictionary = _courtyard_save_files()
	game._process(0)
	var cleared: bool = row.displayed_ids.is_empty()
	for id: String in ["shen","tang","qin"]: cleared = cleared and not row.cards[id].button.visible
	_check(not game.state.party_resource_snapshot().ok and cleared and row.roster_button.disabled, "Packed failed actual resource snapshot clears stale cards and disables entry")
	game._show_exploration_party_roster(game.modal_generation)
	_check(not game.active_modal and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed invalid snapshot cannot open roster or repair malformed state by viewing")
	game.state.party_roster.assign(valid_roster)
	game.state.party_resources.qin = {"hp":3,"qi":0}; game._refresh(); game._process(0)
	_check(_condition_projection_matches(row) and row.cards.qin.hp_bar.value == 3 and not row.roster_button.disabled, "Packed failed snapshot retries cleanly with fresh valid resources at the same roster")
	game.state.party_resources.shen = {"hp":0,"qi":2}; game._refresh(); game._process(0)
	_check(row.cards.shen.hp_bar.value == 0 and row.cards.shen.qi_bar.value == 2 and row.cards.shen.status.text.contains("倒下"), "Packed same-roster HP0/Qi mutation refreshes without rebuilding selection")

func _condition_hidden_boundaries(row) -> void:
	var generation: int = game.modal_generation
	game._show_map(); game._process(0)
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var files: Dictionary = _courtyard_save_files(); var modal: int = game.modal_generation
	game._show_exploration_party_roster(generation)
	_check(not row.is_visible_in_tree() and not row.detail_panel.visible and game.modal_generation == modal and not game.overlay.has_meta("party_roster"), "Packed older compact callback cannot replace an unrelated active modal")
	_check(game.state.to_dict() == before and _courtyard_save_files() == files, "Packed modal-blocked entry performs no save or state write")
	game._close_modal(); game._process(0)
	for screen: String in ["title","battle","receipt_battle","party_battle"]:
		game.current_screen = screen; game._process(0)
		generation = game.modal_generation; before = game.state.to_dict().duplicate(true); files = _courtyard_save_files()
		game._show_exploration_party_roster(generation)
		_check(not row.is_visible_in_tree() and not row.detail_panel.visible and not game.overlay.has_meta("party_roster") and game.modal_generation == generation and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed screen boundary hides and rejects compact entry: "+screen)
	game.current_screen = "explore"; game.quit_pending = true; game._process(0)
	generation = game.modal_generation; before = game.state.to_dict().duplicate(true); files = _courtyard_save_files()
	game._show_exploration_party_roster(generation)
	_check(not row.is_visible_in_tree() and not row.detail_panel.visible and not game.active_modal and game.modal_generation == generation and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed pending quit suppresses compact controls without modifying state or saves")
	game.quit_pending = false; game._process(0)
	_check(row.is_visible_in_tree() and _condition_projection_matches(row), "Packed canceled boundary restores exact real companion resources")
	row.cards.qin.button.grab_focus()
	for zoom: float in [1.0,1.25,1.5]:
		game.view_zoom = zoom; game._refresh(); game._sync_hud_navigation(true)
		var covered: bool = true
		for rect: Rect2 in row.reserved_rects():
			var projected: Rect2 = Rect2(rect.position/zoom,rect.size/zoom)
			covered = covered and game.world.hud_exclusion_rects.has(projected)
		_check(covered and Rect2(0,0,1280,800).encloses(row.get_global_rect()) and row.size.x <= 304 and row.detail_panel.visible and Rect2(0,0,1280,800).encloses(row.detail_panel.get_global_rect()) and not row.detail_panel.get_global_rect().intersects(game.hud.toast_wash.get_global_rect()), "Packed compact display stays bounded and reserves its world-navigation area at zoom "+str(zoom))
	game.view_zoom = 1.0; game._refresh()

func _condition_live_changes(row) -> void:
	# Actual free-rest and roster actions, not a test-only display fixture.
	game._interact("healer"); game._process(0)
	var rest = _find_button(game.overlay,"免费调息")
	_check(rest != null and not row.is_visible_in_tree(), "Packed actual healer dialogue hides condition before explicit rest")
	if rest != null: rest.pressed.emit()
	game._process(0)
	var snapshot: Dictionary = game.state.party_resource_snapshot()
	var rested: bool = true
	for id: String in ["shen","tang","qin"]:
		var actor: Dictionary = _party_actor(snapshot,id)
		rested = rested and actor.hp == actor.max_hp and actor.qi == actor.max_qi
	_check(rested and _condition_projection_matches(row) and not game.active_modal, "Packed explicit free rest refreshes HP/Qi/downed from actual restored resources")
	_condition_injure(); game.state.set_party_roster(["hero","qin","tang","shen"]); game._refresh(); game._process(0)
	game._show_exploration_party_roster(game.modal_generation)
	var folio = _condition_folio()
	_check(folio != null, "Packed condition opens actual roster for freshness lifecycle")
	if folio == null: return
	folio.cells.tang.toggle.pressed.emit(); await _key(KEY_ESCAPE); game._process(0)
	_check(row.displayed_ids == ["qin","shen"] and not row.cards.tang.button.visible and game.state.party_resources.tang.hp == 0, "Packed real folio bench removes compact card without reviving downed actor")
	game._show_exploration_party_roster(game.modal_generation); folio = _condition_folio()
	folio.cells.tang.toggle.pressed.emit(); await _key(KEY_ESCAPE); game._process(0)
	_check(row.displayed_ids == ["qin","shen","tang"] and _condition_projection_matches(row) and row.cards.tang.status.text.contains("倒下"), "Packed real reselect appends compact card in new roster order with preserved HP0")
	_check(game.state.save_game() == OK, "Packed condition creates reload checkpoint with explicit selected HP0")
	var durable: Dictionary = game.state.to_dict().duplicate(true)
	game.state.party_resources.qin.hp = 2; game.state.set_party_roster(["hero","shen"]); game._refresh(); game._process(0)
	_check(row.displayed_ids == ["shen"], "Packed condition shows changed live roster before load")
	await _key(KEY_F9); _condition_freeze()
	_check(game.state.to_dict() == durable and row.displayed_ids == ["qin","shen","tang"] and _condition_projection_matches(row), "Packed actual F9 load refreshes exact saved order/HP/Qi/HP0 rather than stale display cache")
	_unified_prepare("courtyard_practice",4); _condition_freeze(); _condition_injure()
	game.world.teleport(game.world.interactables.courtyard_practice.pos); game._process(0)
	_check(game.state.save_game() == OK, "Packed condition creates real injured checkpoint before virtual practice")
	var before: Dictionary = game.state.to_dict().duplicate(true); var files: Dictionary = _courtyard_save_files()
	var panel = await _unified_enter("courtyard_practice")
	_check(panel != null and game.state.battle_active and not row.is_visible_in_tree(), "Packed actual virtual practice controller suppresses exploration condition")
	if panel == null: return
	var generation: int = game.modal_generation
	game._show_exploration_party_roster(generation)
	_check(game.overlay.get_meta("party_battle",null) == panel and game.modal_generation == generation and not game.overlay.has_meta("party_roster"), "Packed stale exploration entry cannot displace real practice controller")
	_unified_leave(); game._process(0)
	_check(not game.state.battle_active and game.state.party_settlement.practice and game.state.to_dict() == before and _courtyard_save_files() == files, "Packed practice leave preserves injured real resources and checkpoint bytes")
	if game.active_modal: game._close_modal()
	game._process(0)
	_check(row.is_visible_in_tree() and _condition_projection_matches(row) and row.cards.tang.hp_bar.value == 0, "Packed practice return restores real injured/HP0 condition instead of virtual full bars")

	# A real nonpractice return must reproject the accepted persistent settlement.
	game._close_modal(); game._process(0)
	panel = _unified_open_training(); game._process(0)
	_check(panel != null and game.state.battle_active and not row.is_visible_in_tree(), "Packed actual nonpractice battle hides all exploration condition controls")
	if panel == null: return
	var tx: Dictionary = _unified_begin(panel,false); _party_finish(panel)
	_check(tx.get("accepted",false), "Packed real training resolves an actual controller action before return")
	_unified_leave()
	if game.active_modal: game._close_modal()
	game._process(0)
	_check(not game.state.battle_active and row.is_visible_in_tree() and _condition_projection_matches(row), "Packed real battle settlement refreshes condition from accepted persistent HP/Qi")

# V26 adds an independent measured scope. Transport below is deliberately fake:
# the exact PCK's real core/UI/lifecycle runs natively; actual browser downloads,
# picker user activation and durable IDBFS persistence require separate Web QA.
class TransferPackBrowser extends RefCounted:
	signal selection_finished(operation: int, status: String, bytes: PackedByteArray)
	var enabled: bool = true
	var operation: int = -1
	var picks: int = 0
	var cancellations: int = 0
	var downloads: Array = []
	var disposed: bool = false
	func available() -> bool: return enabled and not disposed
	func choose_file(value: int) -> bool:
		operation = value; picks += 1
		return available()
	func cancel() -> void:
		operation = -1; cancellations += 1
	func dispose() -> void:
		disposed = true; cancel()
	func request_download(bytes: PackedByteArray, slot: int, backup: bool) -> bool:
		if not available(): return false
		downloads.append({"bytes":bytes.duplicate(),"slot":slot,"backup":backup})
		return true

func _transfer_prerequisites() -> bool:
	var previous: int = failures
	var first: int = checks
	for module: String in ["local_save_transfer", "browser_save_transfer", "save_transfer_ui"]:
		_check(ResourceLoader.exists("res://scripts/"+module+".gd"), "Transfer package retains actual runtime before scene instantiation: "+module)
	_transfer_prerequisite_checks = checks-first
	return failures == previous

func _transfer_fresh_title() -> void:
	var first: int = checks
	var original: bool = game.browser_mode
	var original_gate: bool = game.web_save_transfer_enabled
	var files: Dictionary = _courtyard_save_files()
	var before: Dictionary = _receipt_variables(game.state)
	_check(not game.state.has_save() and not game.save_slots.store.has_manual_saves(), "Packed fresh profile has no fabricated save or manual slot")
	game.browser_mode = true; game._show_title()
	_check(not game.web_save_transfer_enabled and _find_button(game.overlay,"导入 / 导出手记") == null and not game.save_slots.transfer.allowed(), "Packed release default-off gate suppresses unverified browser UI and direct operations")
	game.web_save_transfer_enabled = true; game._show_title()
	_check(_find_button(game.overlay,"导入 / 导出手记") != null and _find_button(game.overlay,"查阅手记") == null, "Packed fresh browser title offers import before any local save exists")
	_check(_courtyard_save_files() == files and _receipt_variables(game.state) == before, "Packed title transfer affordance creates no autosave or journey mutation")
	game.browser_mode = original; game.web_save_transfer_enabled = original_gate; game._show_title()
	_transfer_setup_checks = checks-first

func _transfer_directory(label: String) -> String:
	_transfer_directory_counter += 1
	var path: String = "user://transfer-pack-%03d-%s" % [_transfer_directory_counter,label]
	_check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path)) == OK, "Packed transfer fixture claims a fresh isolated directory: "+label)
	return path

func _transfer_write(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	_check(file != null, "Packed transfer fixture opens only isolated audit bytes: "+path.get_file())
	if file != null:
		file.store_buffer(bytes); file.close()

func _transfer_files(directory: String) -> Dictionary:
	var result: Dictionary = {}
	for name: String in DirAccess.get_files_at(directory):
		result[name] = FileAccess.get_file_as_bytes(directory.path_join(name))
	for name: String in DirAccess.get_directories_at(directory):
		result[name+"/"] = _transfer_files(directory.path_join(name))
	return result

func _transfer_document(version: int = 16) -> Dictionary:
	var model = load("res://scripts/game_state.gd").new()
	var data: Dictionary = model.to_dict()
	data.player_name = "归舟客"
	if version < 16: data.erase("weapon_fitting")
	if version < 15:
		for key: String in CAPSTONE_FIELDS: data.erase(key)
	if version < 14:
		for key: String in CONSIGNEE_FIELDS: data.erase(key)
	if version < 13: data.erase("internal_unlocked")
	if version < 12:
		for key: String in ["party_roster","party_resources","qin_stage","qin_unlocked"]: data.erase(key)
	if version < 11: data.erase("receipt_stage")
	return {"version":version,"player":data}

func _transfer_bytes(version: int = 16) -> PackedByteArray:
	# BOM, spacing and trailing newlines make any reserialization observable.
	return ("\ufeff  "+JSON.stringify(_transfer_document(version),"  ")+"\n\n").to_utf8_buffer()

func _transfer_failure_script():
	# Compile only after packed-module prerequisites, never preload a missing
	# current script before an old package can receive its fail-closed verdict.
	var script := GDScript.new()
	script.source_code = """extends "res://scripts/local_save_transfer.gd"
var fault: String = ""
var stage_reads: int = 0
var renames: int = 0
func _create_stage_directory() -> Dictionary:
	if fault == "create": return _failure(ERR_CANT_CREATE,"stage_create_failed")
	return super._create_stage_directory()
func _open_stage(path: String) -> FileAccess:
	if fault == "open": return null
	return super._open_stage(path)
func _write_stage(file: FileAccess, bytes: PackedByteArray) -> Error:
	if fault == "write":
		file.store_buffer(bytes.slice(0,12))
		return ERR_FILE_CANT_WRITE
	return super._write_stage(file,bytes)
func _flush_stage(file: FileAccess) -> Error:
	if fault == "flush": return ERR_FILE_CANT_WRITE
	return super._flush_stage(file)
func _read_bytes(path: String) -> Dictionary:
	var result: Dictionary = super._read_bytes(path)
	if path.get_file() == "incoming.json":
		stage_reads += 1
		if fault == "readback": return {"ok":true,"error":OK,"bytes":"changed staged bytes".to_utf8_buffer()}
		if fault == "occupied":
			var file: FileAccess = FileAccess.open(_slots.path_for(1)+".bak",FileAccess.WRITE)
			file.store_string("new competing backup"); file.close()
	return result
func _rename_stage(source: String, destination: String) -> Error:
	renames += 1
	if fault == "rename": return ERR_CANT_CREATE
	return super._rename_stage(source,destination)
"""
	_check(script.reload() == OK, "Packed transfer injected I/O probes compile against actual shipped core")
	return script

func _test_transfer_pack() -> void:
	var first: int = checks
	var core = load("res://scripts/local_save_transfer.gd")
	var model = load("res://scripts/game_state.gd")
	_check(core.MAX_IMPORT_BYTES == 1048576 and model.MAX_SAVE_BYTES == 1048576 and model.SAVE_VERSION == 16, "Packed transfer preserves schema16 and exact one-MiB envelope")
	_check(game.save_slots.transfer.get_script() == load("res://scripts/save_transfer_ui.gd") and game.save_slots.transfer.adapter.get_script() == load("res://scripts/browser_save_transfer.gd"), "Packed real SaveSlots owns shipped transfer UI and production browser adapter")
	_check(not game.save_slots.transfer.adapter.available(), "Native exact-pack audit does not impersonate the Web JavaScript bridge")
	_transfer_core_versions(core,model)
	_transfer_core_rejections(core)
	_transfer_core_targets(core)
	_transfer_core_transactions(core)
	await _transfer_actual_ui()
	print("Empty-slot save transfer exact-runtime coverage: %d checks; actual packaged byte inspector/core/UI; schemas1-15 plus current16; raw bytes; 1MiB/UTF8/semantic gates; empty manual slots only; staged/readback/final-recheck and failure preservation; native injected transport/lifecycle; no browser download or durability claim" % (checks-first+_transfer_prerequisite_checks+_transfer_setup_checks))

func _transfer_core_versions(core,model) -> void:
	for version: int in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]:
		var directory: String = _transfer_directory("schema%d" % version)
		var store = load("res://scripts/local_save_slots.gd").new(directory)
		var helper = core.new(directory)
		var bytes: PackedByteArray = _transfer_bytes(version)
		var probe = model.new()
		probe.coins = 987; probe.battle_active = true; probe.enemy_hp = 31
		var before: Dictionary = _receipt_variables(probe)
		var inspected: Dictionary = probe.inspect_save_bytes(bytes)
		_check(inspected.ok and inspected.version == version and inspected.state != probe and _receipt_variables(probe) == before, "Packed detached inspector accepts schema and preserves all live fields: "+str(version))
		var preview: Dictionary = helper.preview_import(bytes,1)
		_check(preview.get("ok",false) and preview.version == version and preview.metadata.player_name == "归舟客" and preview.metadata.level == 1 and preview.metadata.location == "qingwei", "Packed transfer metadata comes from validated schema: "+str(version))
		_check(not preview.has("state") and not preview.has("bytes") and not FileAccess.file_exists(store.path_for(1)), "Packed preview exposes detached metadata but writes no file: "+str(version))
		var committed: Dictionary = helper.commit_import(preview.get("token",-1))
		_check(committed.get("status","") == "imported" and FileAccess.get_file_as_bytes(store.path_for(1)) == bytes and _transfer_files(directory).size() == 1, "Packed import preserves original BOM/format/version bytes and leaves no stage: "+str(version))
		var exported: Dictionary = helper.export_slot(1)
		_check(exported.get("ok",false) and exported.bytes == bytes and exported.version == version and exported.metadata == preview.metadata, "Packed raw export retains original schema and validated metadata: "+str(version))
		_check(_receipt_variables(probe) == before, "Packed metadata/commit/export never changes original detached caller: "+str(version))
	var directory: String = _transfer_directory("exports")
	var store = load("res://scripts/local_save_slots.gd").new(directory)
	var helper = core.new(directory)
	for slot: int in range(4):
		var bytes: PackedByteArray = _transfer_bytes(slot+1)
		_transfer_write(store.path_for(slot),bytes)
		if slot > 0: _transfer_write(store.path_for(slot)+".bak",_transfer_bytes(slot+8))
	var files: Dictionary = _transfer_files(directory)
	for slot: int in range(4):
		for backup: bool in ([false] if slot == 0 else [false,true]):
			var result: Dictionary = helper.export_slot(slot,backup)
			var path: String = store.path_for(slot)+(".bak" if backup else "")
			_check(result.get("ok",false) and result.bytes == FileAccess.get_file_as_bytes(path) and result.digest == FileAccess.get_sha256(path), "Packed exports original validated saved bytes with digest: %d/%s" % [slot,backup])
			_check(_transfer_files(directory) == files, "Packed export never saves/rotates/reformats any primary or backup")
	_check(not helper.export_slot(0,true).ok, "Packed autosave has no invented backup export")

func _transfer_core_rejections(core) -> void:
	var directory: String = _transfer_directory("reject")
	var helper = core.new(directory)
	var valid: PackedByteArray = _transfer_bytes()
	var invalid: Array = [PackedByteArray(),"{".to_utf8_buffer(),"[]".to_utf8_buffer(),"null".to_utf8_buffer(),PackedByteArray([0]),PackedByteArray([0xc0,0x80]),PackedByteArray([0xed,0xa0,0x80]),PackedByteArray([0xf4,0x90,0x80,0x80]),PackedByteArray([0xe2,0x82]),PackedByteArray([0xff])]
	for version: Variant in [0,17,-1,16.5,"16",true,null]:
		var document: Dictionary = _transfer_document(); document.version = version
		invalid.append(JSON.stringify(document).to_utf8_buffer())
	for key: String in ["hp","level","quest_stage","internal_unlocked","party_roster","party_resources"]:
		var document: Dictionary = _transfer_document(); document.player.erase(key)
		invalid.append(JSON.stringify(document).to_utf8_buffer())
	for patch: Dictionary in [{"hp":0},{"hp":999999},{"coins":-1},{"level":1.5},{"map_id":"unknown"},{"quest_stage":-1},{"internal_unlocked":true},{"party_roster":["hero","qin"]},{"player_name":" "}]:
		var document: Dictionary = _transfer_document(); document.player.merge(patch,true)
		invalid.append(JSON.stringify(document).to_utf8_buffer())
	invalid.append(("[".repeat(513)+"0"+"]".repeat(513)).to_utf8_buffer())
	var oversized: PackedByteArray = valid.duplicate(); oversized.resize(1048577); oversized.fill(32)
	invalid.append(oversized)
	for index: int in range(invalid.size()):
		var result: Dictionary = helper.preview_import(invalid[index],1)
		_check(not result.ok and _transfer_files(directory).is_empty(), "Packed untrusted input fails before writes: "+str(index))
	var exact: PackedByteArray = valid.duplicate()
	var padding := PackedByteArray(); padding.resize(1048576-exact.size()); padding.fill(32); exact.append_array(padding)
	_check(helper.preview_import(exact,1).get("ok",false), "Packed exact one-MiB valid save remains accepted")
	var future: Dictionary = _transfer_document(); future.version = 17
	var result: Dictionary = helper.preview_import(JSON.stringify(future).to_utf8_buffer(),1)
	_check(not result.ok and result.error == ERR_FILE_UNRECOGNIZED, "Packed future schema returns incompatibility rather than rewriting")
	for text: String in [JSON.stringify(_transfer_document()).trim_suffix("}")+",}",JSON.stringify(_transfer_document()).replace('"version":16','"version":1,"version":16')]:
		var result_legacy: Dictionary = helper.preview_import(text.to_utf8_buffer(),1)
		_check(result_legacy.get("ok",false), "Packed byte wrapper preserves existing trailing-comma and duplicate-key parser semantics")

func _transfer_core_targets(core) -> void:
	var bytes: PackedByteArray = _transfer_bytes()
	for slot: Variant in [0,-1,4,1.0,true,"1","../hero_save.json",null]:
		var directory: String = _transfer_directory("invalid-target")
		var helper = core.new(directory)
		_check(not helper.target_available(slot) and not helper.preview_import(bytes,slot).ok and _transfer_files(directory).is_empty(), "Packed only integer manual targets1-3 are admissible: "+str(slot))
	for slot: int in [1,2,3]:
		var directory: String = _transfer_directory("manual-target")
		var helper = core.new(directory)
		var preview: Dictionary = helper.preview_import(bytes,slot)
		_check(preview.get("ok",false) and helper.commit_import(preview.token).get("ok",false) and not helper.target_available(slot), "Packed each empty manual slot accepts one explicit import: "+str(slot))
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		for folder: bool in [false,true]:
			var directory: String = _transfer_directory("occupied")
			var helper = core.new(directory)
			var path: String = directory.path_join("hero_slot_1.json"+suffix)
			if folder: _check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path)) == OK, "Packed fixture creates a conflicting directory")
			else: _transfer_write(path,"preexisting unparsed bytes".to_utf8_buffer())
			var files: Dictionary = _transfer_files(directory)
			_check(not helper.target_available(1) and not helper.preview_import(bytes,1).ok and _transfer_files(directory) == files, "Packed corrupt files, backup-only and conflicting paths never count as empty: "+suffix+str(folder))
	var directory: String = _transfer_directory("bad-source")
	var helper = core.new(directory)
	_transfer_write(directory.path_join("hero_slot_1.json"),"corrupt source".to_utf8_buffer())
	_transfer_write(directory.path_join("hero_slot_1.json.bak"),_transfer_bytes(12))
	var files: Dictionary = _transfer_files(directory)
	_check(not helper.export_slot(1).ok and helper.export_slot(1,true).ok and _transfer_files(directory) == files, "Packed corrupt primary export leaves independently valid backup export intact")

func _transfer_core_transactions(core) -> void:
	var bytes: PackedByteArray = _transfer_bytes()
	var directory: String = _transfer_directory("tokens")
	var helper = core.new(directory)
	var first: Dictionary = helper.preview_import(bytes,1)
	var second: Dictionary = helper.preview_import(bytes,2)
	_check(not helper.commit_import(first.token).ok and _transfer_files(directory).is_empty(), "Packed selecting a new target invalidates earlier confirmation")
	helper.cancel_preview(second.token)
	_check(not helper.commit_import(second.token).ok and _transfer_files(directory).is_empty(), "Packed explicit cancel invalidates pending token")
	first = helper.preview_import(bytes,1); helper.preview_import("bad".to_utf8_buffer(),2)
	_check(not helper.commit_import(first.token).ok and _transfer_files(directory).is_empty(), "Packed even invalid reselection invalidates previous valid confirmation")
	first = helper.preview_import(bytes,1)
	var original: PackedByteArray = bytes.duplicate(); bytes[0] = 32
	_check(helper.commit_import(first.token).get("status","") == "imported" and FileAccess.get_file_as_bytes(directory.path_join("hero_slot_1.json")) == original, "Packed caller byte-array mutation cannot alter privately retained preview")
	var files: Dictionary = _transfer_files(directory)
	_check(helper.commit_import(first.token).get("status","") == "already_imported" and _transfer_files(directory) == files, "Packed duplicate commit is read-only idempotent for unchanged result")
	_transfer_write(directory.path_join("hero_slot_1.json"),"changed target".to_utf8_buffer()); files = _transfer_files(directory)
	_check(not helper.commit_import(first.token).ok and _transfer_files(directory) == files, "Packed replay after target replacement never reports success or overwrites it")
	first = helper.preview_import(original,2)
	helper._preview.bytes[0] = 32
	_check(not helper.commit_import(first.token).ok and _transfer_files(directory) == files, "Packed retained-byte digest rejects changed confirmation before any write")
	first = helper.preview_import(original,3)
	helper._preview.slot = 2
	_check(not helper.commit_import(first.token).ok and _transfer_files(directory) == files, "Packed changed target binding rejects confirmation without writing either slot")
	var failure_script = _transfer_failure_script()
	for fault: String in ["create","open","write","flush","readback","occupied","rename",""]:
		var fault_directory: String = _transfer_directory("io-"+fault)
		var injected = failure_script.new(fault_directory); injected.fault = fault
		_transfer_write(fault_directory.path_join("hero_save.json"),original)
		_transfer_write(fault_directory.path_join("hero_slot_2.json"),_transfer_bytes(11))
		_transfer_write(fault_directory.path_join("hero_slot_2.json.bak"),_transfer_bytes(10))
		var stable: Dictionary = _transfer_files(fault_directory)
		var preview: Dictionary = injected.preview_import(original,1)
		_check(preview.get("ok",false), "Packed I/O fault fixture has a validated empty target: "+fault)
		var result: Dictionary = injected.commit_import(preview.get("token",-1))
		var expected: Dictionary = stable.duplicate(true)
		if fault == "occupied": expected["hero_slot_1.json.bak"] = "new competing backup".to_utf8_buffer()
		elif fault == "": expected["hero_slot_1.json"] = original
		_check(result.ok == fault.is_empty() and _transfer_files(fault_directory) == expected, "Packed staged failure or success preserves all other files and removes only owned stage: "+fault)
		if not fault.is_empty():
			injected.fault = ""
			_check(not injected.commit_import(preview.token).ok and _transfer_files(fault_directory) == expected, "Packed failed confirmation is consumed and cannot silently retry: "+fault)
		if fault in ["readback","occupied"]: _check(injected.stage_reads == 1 and injected.renames == 0, "Packed staged byte verification and final occupancy recheck precede rename: "+fault)
		elif fault in ["rename",""]: _check(injected.stage_reads == 1 and injected.renames == 1, "Packed commit reaches exactly one rename only after verified readback: "+fault)

func _transfer_actual_ui() -> void:
	var original_browser: bool = game.browser_mode
	var original_gate: bool = game.web_save_transfer_enabled
	var original_storage: bool = game.browser_storage_available
	var original_store = game.save_slots.store
	game.save_slots.transfer.dispose()
	var directory: String = _transfer_directory("real-ui")
	var store = load("res://scripts/local_save_slots.gd").new(directory)
	var fake := TransferPackBrowser.new()
	var panel = load("res://scripts/save_transfer_ui.gd").new(game.save_slots,directory,fake)
	game.save_slots.store = store; game.save_slots.transfer = panel
	game.browser_mode = true; game.web_save_transfer_enabled = true; game.browser_storage_available = false
	game._new_game(); _condition_freeze()
	game.state.coins = 37; game.state.player_name = "当前旅人"
	var before: Dictionary = _receipt_variables(game.state)
	var autosaves: Dictionary = _courtyard_save_files()
	var position: Vector2 = game.world.player_pos
	var bytes: PackedByteArray = _transfer_bytes()
	game._show_save_slots()
	_check(_find_button(game.overlay,"导入 / 导出手记") != null, "Packed actual browser SaveSlots offers transfer")
	_press("导入 / 导出手记")
	_check(game.overlay.get_meta("save_transfer",false) and not game.modal_autosave_on_close and _gather_text(game.overlay).contains("持久存储"), "Packed transfer modal suppresses close-autosave and explains unavailable persistence")
	_press("导入到空白手记"); _press("选择文件 → 手记一")
	var operation: int = fake.operation
	_check(fake.picks == 1 and panel._pending_generation == game.modal_generation and _transfer_files(directory).is_empty(), "Packed actual target button synchronously requests picker through injected native transport without writes")
	fake.selection_finished.emit(operation,"selected",bytes)
	_check(_gather_text(game.overlay).contains("归舟客") and _find_button(game.overlay,"确认导入 手记一") != null and _transfer_files(directory).is_empty(), "Packed selected bytes show validated preview and separate explicit confirmation")
	var stale_confirm: Callable = game.modal_actions[0]
	fake.selection_finished.emit(operation,"selected",bytes)
	_check(game.modal_actions[0] == stale_confirm and panel._preview_token >= 0, "Packed repeated picker callback cannot mint or replace confirmation")
	_press("取消导入"); stale_confirm.call()
	_check(_transfer_files(directory).is_empty() and _receipt_variables(game.state) == before and _courtyard_save_files() == autosaves, "Packed canceled preview and stale confirmation preserve current journey and all save bytes")
	panel.targets(); _press("选择文件 → 手记一"); operation = fake.operation
	await _key(KEY_ESCAPE)
	fake.selection_finished.emit(operation,"selected",bytes)
	_check(not game.overlay.get_meta("save_transfer",false) and panel._preview_token == -1 and _transfer_files(directory).is_empty(), "Packed actual Esc invalidates late selected callback and returns to SaveSlots")
	await _key(KEY_ESCAPE)
	_check(not game.active_modal and _receipt_variables(game.state) == before and _courtyard_save_files() == autosaves and game.world.player_pos == position, "Packed Esc from transfer then SaveSlots never autosaves unsaved current journey")
	for status: String in ["cancelled","oversize","invalid","read_error"]:
		panel.targets(); _press("选择文件 → 手记一"); operation = fake.operation
		fake.selection_finished.emit(operation,status,PackedByteArray())
		_check(_gather_text(game.overlay).contains("未导入手记") and _transfer_files(directory).is_empty() and _courtyard_save_files() == autosaves, "Packed picker terminal failure leaves every byte unchanged: "+status)
	panel.targets(); _press("选择文件 → 手记一"); operation = fake.operation
	_press("重新选择文件")
	var newest: int = fake.operation
	fake.selection_finished.emit(operation,"selected",bytes)
	_check(panel._preview_token < 0 and newest != operation and _transfer_files(directory).is_empty(), "Packed older picker result cannot replace newer selection")
	fake.selection_finished.emit(newest,"selected",bytes)
	var confirm: Callable = game.modal_actions[0]
	_transfer_write(store.path_for(1)+".bak","appeared after preview".to_utf8_buffer())
	var conflict_files: Dictionary = _transfer_files(directory)
	confirm.call(); confirm.call()
	_check(_gather_text(game.overlay).contains("未导入手记") and _transfer_files(directory) == conflict_files and _receipt_variables(game.state) == before, "Packed actual confirm rechecks newly occupied target and repeated click preserves failure bytes")
	panel.targets()
	_check(_find_button(game.overlay,"选择文件 → 手记一") == null and _find_button(game.overlay,"选择文件 → 手记二") != null, "Packed backup-only slot disappears from import target choices")
	_press("选择文件 → 手记二"); fake.selection_finished.emit(fake.operation,"selected",bytes)
	confirm = game.modal_actions[0]
	confirm.call(); confirm.call()
	_check(FileAccess.get_file_as_bytes(store.path_for(2)) == bytes and _gather_text(game.overlay).contains("手记已导入") and not FileAccess.file_exists(store.path_for(2)+".bak"), "Packed actual UI writes original bytes to only empty target and ignores double confirmation")
	_check(_receipt_variables(game.state) == before and _courtyard_save_files() == autosaves and game.world.player_pos == position, "Packed successful import leaves active model/world/autosave completely unchanged")
	_press("查阅手记"); _press("手记二"); _press("读取当前版本")
	_check(_find_button(game.overlay,"确认读取") != null and _receipt_variables(game.state) == before and _courtyard_save_files() == autosaves, "Packed imported slot remains a separate explicit load-confirmation workflow")
	await _key(KEY_ESCAPE)
	_check(_receipt_variables(game.state) == before and _courtyard_save_files() == autosaves, "Packed dismissing explicit load confirmation remains read-only")
	panel.exports(); _press("手记二"); _press("下载当前版本")
	_check(fake.downloads.size() == 1 and fake.downloads[0].bytes == bytes and fake.downloads[0].slot == 2 and not fake.downloads[0].backup, "Packed actual download button sends exact saved bytes through injectable transport")
	_check(_gather_text(game.overlay).contains("已请求下载，请在浏览器确认保留") and _gather_text(game.overlay).contains("未提供文件已落盘的回执"), "Packed download result truthfully distinguishes request from completed browser download")
	_check(_receipt_variables(game.state) == before and _courtyard_save_files() == autosaves and _transfer_files(directory).size() == 2, "Packed download UI never saves unsaved active journey or rotates backup")
	panel.back(); await _key(KEY_ESCAPE)
	_check(_receipt_variables(game.state) == before and _courtyard_save_files() == autosaves, "Packed successful transfer/download return chain suppresses implicit autosave")
	_check(load("res://scripts/save_transfer_ui.gd").escape_text("[b]<旅人>&") == "[lb]b[rb]&lt;旅人&gt;&amp;", "Packed metadata escape neutralizes BBCode and markup in one pass")
	fake.enabled = false; panel.show()
	_check(_gather_text(game.overlay).contains("手记转存暂不可用") and _find_button(game.overlay,"导入到空白手记") == null, "Packed absent browser adapter disables unsafe action controls")
	fake.enabled = true
	panel.targets(); _press("选择文件 → 手记三"); operation = fake.operation
	# J/M now protect a live transfer instead of replacing it. Preserve that
	# exact owner/token/state/files first, then test FORCED HOST replacement
	# through the actual generic modal path (not an ordinary user shortcut).
	var pending: Dictionary = {"owner":game.save_slots.transfer,"generation":game.modal_generation,"operation":panel._operation,"pending":panel._pending_generation,"preview":panel._preview_token,"state":_receipt_variables(game.state),"files":_transfer_files(directory),"autosaves":_courtyard_save_files()}
	game._show_journal(); game._show_map()
	var protected: bool = game.overlay.get_meta("save_transfer",false) and game.save_slots.transfer == pending.owner and game.modal_generation == pending.generation and panel._operation == pending.operation and panel._pending_generation == pending.pending and panel._preview_token == pending.preview and _receipt_variables(game.state) == pending.state and _transfer_files(directory) == pending.files and _courtyard_save_files() == pending.autosaves
	game._modal("Audit forced host replacement", "Prepared lifecycle input", "Generic host replacement invalidates an old picker; not a normal J/M shortcut.", [["Close",game._close_modal]])
	fake.selection_finished.emit(operation,"selected",bytes)
	_check(protected and not game.overlay.get_meta("save_transfer",false) and panel._preview_token == -1 and not FileAccess.file_exists(store.path_for(3)) and _receipt_variables(game.state) == pending.state and _transfer_files(directory) == pending.files and _courtyard_save_files() == pending.autosaves, "Packed replacement modal invalidates in-flight selection lifecycle")
	game.modal_autosave_on_close = false; game._close_modal()
	for screen: String in ["battle","receipt_battle","party_battle"]:
		game.current_screen = screen
		var generation: int = game.modal_generation
		panel.show()
		_check(not panel.allowed() and game.modal_generation == generation, "Packed transfer never opens in battle screen: "+screen)
	game.current_screen = "explore"
	game.state.battle_active = true
	_check(not panel.allowed(), "Packed transfer blocks active model battle even when presentation screen is stale")
	game.state.battle_active = false
	game.battle_busy = true
	_check(not panel.allowed(), "Packed transfer blocks pending battle presentation")
	game.battle_busy = false
	game.battle_art.hit("flee", {"valid":true})
	_check(game.battle_art.is_presenting() and not panel.allowed(), "Packed actual pending battle-art presentation suppresses transfer even after model battle ends")
	game.battle_art.reset_presentation()
	for key: String in ["party_battle","receipt_battle","courtyard_practice"]:
		game.overlay.set_meta(key,true)
		_check(not panel.allowed(), "Packed transfer blocks retained battle controller metadata: "+key)
		game.overlay.remove_meta(key)
	game.quit_pending = true
	_check(not panel.allowed(), "Packed transfer blocks quit-pending callbacks")
	game.quit_pending = false
	panel.targets(); _press("选择文件 → 手记三"); operation = fake.operation
	panel.dispose(); fake.selection_finished.emit(operation,"selected",bytes)
	_check(fake.disposed and panel._preview_token == -1 and not FileAccess.file_exists(store.path_for(3)), "Packed disposal disconnects callback and leaves no hidden pending import")
	_check(_receipt_variables(game.state) == before and _courtyard_save_files() == autosaves, "Packed lifecycle/guards leave complete active model and autosave unchanged")
	game.save_slots.store = original_store
	game.save_slots.transfer = load("res://scripts/save_transfer_ui.gd").new(game.save_slots)
	game.browser_mode = original_browser; game.web_save_transfer_enabled = original_gate; game.browser_storage_available = original_storage
	game._show_title()

# Chapter14 is separately measured. Historical coverage above stays independent;
# this scope binds actual new scenes/controls to finite cargo, battle and saves.
func _consignee_prerequisites() -> bool:
	var previous: int = failures; var first: int = checks
	for module: String in ["heting_consignee_rules", "heting_consignee_combat_data", "heting_consignee_story", "painted_battle_duhui"]:
		_check(ResourceLoader.exists("res://scripts/"+module+".gd"), "Consignee exact runtime retained before any scene or save: "+module)
	_check(ResourceLoader.exists("res://assets/generated/characters/painted_duhui_combat.png"), "Consignee original Du Hui atlas retained in actual pack")
	_check(not ProjectSettings.get_setting("hero/features/web_save_transfer_enabled",false), "Actual package keeps unverified browser transfer feature default-off")
	_consignee_prerequisite_checks = checks-first
	return failures == previous

func _consignee_legacy_prerequisite(rehearsal: bool) -> bool:
	var previous: int = failures; var first: int = checks
	var path: String = OS.get_environment("HERO_AUDIT_SCHEMA13_READER")
	_legacy_save_fixtures = OS.get_environment("HERO_AUDIT_LEGACY_SAVE_FIXTURES")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema13-reader="): path = argument.trim_prefix("--schema13-reader=")
		if argument.begins_with("--legacy-save-fixtures="): _legacy_save_fixtures = argument.trim_prefix("--legacy-save-fixtures=")
	if rehearsal:
		if path.is_empty(): path = ProjectSettings.globalize_path("res://tests/fixtures/v025_game_state.gd.txt")
		if _legacy_save_fixtures.is_empty(): _legacy_save_fixtures = ProjectSettings.globalize_path("res://tests/fixtures/legacy_saves")
	_check(path.is_absolute_path() and FileAccess.file_exists(path), "Consignee audit requires explicit external genuine Web25 schema13 reader")
	if not path.is_absolute_path() or not FileAccess.file_exists(path): return false
	_check(FileAccess.get_sha256(path) == SCHEMA13_READER_SHA256, "Genuine frozen Web25 reader matches immutable byte pin")
	if FileAccess.get_sha256(path) != SCHEMA13_READER_SHA256: return false
	var script = GDScript.new(); script.source_code = FileAccess.get_file_as_string(path).replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Genuine Web25 reader compiles with only global registration removed")
	if error != OK: return false
	schema13_reader = script.new()
	_check(schema13_reader.SAVE_VERSION == 13 and not schema13_reader.to_dict().has("consignee_stage"), "Actual old reader retains schema13 gate and old field layout")
	var manifest: String = _legacy_save_fixtures.path_join("provenance.json")
	_check(_legacy_save_fixtures.is_absolute_path() and FileAccess.file_exists(manifest) and FileAccess.get_sha256(manifest) == LEGACY_FIXTURE_MANIFEST_SHA256, "External schemas1–13 fixture provenance is pinned before scene instantiation")
	if failures != previous: return false
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	_check(provenance.fixtures.size() == 13, "Frozen compatibility manifest covers exactly1–13")
	for item: Dictionary in provenance.fixtures:
		var filename: String = "schema_%02d_default.json" % int(item.version)
		var source: String = _legacy_save_fixtures.path_join(filename)
		_check(item.path == "tests/fixtures/legacy_saves/"+filename and FileAccess.file_exists(source) and FileAccess.get_sha256(source) == item.sha256, "External historical bytes retain exact manifest identity: "+filename)
	_consignee_prerequisite_checks += checks-first
	return failures == previous

func _test_consignee_pack() -> void:
	var first: int = checks
	game.set_process(false); game.world.set_process(false)
	_check(game.consignee_story.get_script() == load("res://scripts/heting_consignee_story.gd"), "Main owns actual shipped consignee story controller")
	_test_consignee_migrations()
	_test_consignee_art()
	for route: Array in [["short_ferries","hold_for_inspection",0],["open_scale","return_to_owner",3]]:
		await _test_consignee_route(route[0],route[1],route[2])
	await _test_consignee_optional_methods()
	await _test_consignee_battle_boundaries()
	await _test_consignee_failures()
	_check(_unified_facts_ok and _unified_basic_encounters.has("heting_consignee"), "Actual chapter11 transactions retain unique living-actor basics and skill cooldown rules")
	_check(not game.web_save_transfer_enabled, "Actual chapter completion never enables browser transfer")
	print("Schema14 consignee chapter exact-runtime coverage: %d checks; actual E/guarded choices/proximity; both prior harbor endings and new handovers; optional receipt/companions; schema1–13 neutral migration and genuine frozen Web25 rejection; stage0–5/backup/reload; explicit120XP60coins once; finite same-lot cargo; eleventh automatic controller/targets/once-per-living-actor/3skills/resources/stale/retreat/defeat/presentation; exact DuHui art; read-only views and failed-save retries; native prepared-state audit, no browser claim" % (checks-first+_consignee_prerequisite_checks))

func _test_consignee_migrations() -> void:
	var model = load("res://scripts/game_state.gd"); var probe = model.new()
	probe.coins = 919; probe.skill_cooldown = 3; probe.battle_active = true
	var untouched: Dictionary = _receipt_variables(probe)
	var neutral: Dictionary = model.new().to_dict()
	for version: int in range(1,14):
		var path: String = _legacy_save_fixtures.path_join("schema_%02d_default.json" % version)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var inspected: Dictionary = probe.inspect_save_bytes(bytes)
		_check(inspected.ok and inspected.version == version and inspected.state != probe, "Actual packed reader accepts pinned legacy layout: "+str(version))
		_check(_receipt_variables(probe) == untouched and FileAccess.get_file_as_bytes(path) == bytes, "Legacy inspection preserves all live/transient fields and genuine source bytes")
		if not inspected.ok: continue
		for key: String in CONSIGNEE_FIELDS:
			_check(inspected.state.to_dict()[key] == neutral[key], "Schemas1–13 default absent chapter fields neutral: %d/%s" % [version,key])
		_check(inspected.state.coins == 24 and inspected.state.hp == 100 and inspected.state.qi == 2 and inspected.state.medicine == 3 and inspected.state.party_roster == ["hero"] and not inspected.state.internal_unlocked, "Legacy migration grants no reward, recovery, recruit or lesson")
		if version == 13:
			var genuine: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
			_check(probe._same_save_value(schema13_reader.to_dict(),genuine.player), "Pinned schema13 fixture is actual Web25 default producer serialization")
			_check(schema13_reader.load_game(path) == OK and not schema13_reader.to_dict().has("consignee_stage"), "Genuine frozen schema13 reader accepts its own real13 control")
		var new_path: String = "user://consignee-migrated-%d.json" % version
		_check(inspected.state.save_game(new_path) == OK and JSON.parse_string(FileAccess.get_file_as_string(new_path)).version == 16 and FileAccess.get_file_as_bytes(path) == bytes, "Only explicit current save upgrades legacy bytes to16")
		var bad: Dictionary = JSON.parse_string(bytes.get_string_from_utf8()); bad.player.consignee_stage = 0
		_check(not probe.inspect_save_bytes(JSON.stringify(bad).to_utf8_buffer()).ok, "Partial new field bundle is rejected even on legacy schema")
	var current: Dictionary = model.new().to_dict()
	for key: String in CONSIGNEE_FIELDS:
		var missing: Dictionary = current.duplicate(true); missing.erase(key)
		_check(not probe.inspect_save_bytes(JSON.stringify({"version":15,"player":missing}).to_utf8_buffer()).ok, "Actual schema15 still requires complete chapter bundle: "+key)
	var path: String = "user://consignee-real14-reader-rejection.json"
	_check(schema14_reader.save_game(path) == OK and FileAccess.get_sha256(path) == SCHEMA14_SAVE_SHA256, "Genuine frozen Web28 producer writes byte-exact true14 rejection subject")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	schema13_reader.coins = 913; schema13_reader.skill_cooldown = 3; schema13_reader.battle_active = true
	var old_before: Dictionary = _receipt_variables(schema13_reader)
	_check(schema13_reader.load_game(path) == ERR_FILE_UNRECOGNIZED and _receipt_variables(schema13_reader) == old_before and FileAccess.get_file_as_bytes(path) == bytes and not FileAccess.file_exists(path+".tmp"), "Genuine Web25 schema13 gate rejects true14 before any persistent/transient memory or disk mutation")

func _test_consignee_art() -> void:
	var art = load("res://scripts/painted_battle_duhui.gd")
	var hashes: Dictionary = {}
	# Source PNG pin4b44e7ff… is bound by the whole-source manifest. Godot lossless
	# import applies its authored fix_alpha_border setting; pin those runtime pixels.
	var pixels: Image = art.texture_for("idle").atlas.get_image(); pixels.convert(Image.FORMAT_RGBA8)
	var pixel_hash = HashingContext.new(); pixel_hash.start(HashingContext.HASH_SHA256); pixel_hash.update(pixels.get_data())
	_check(pixel_hash.finish().hex_encode() == "a2a74a0ea15cb2c1bdc60fc6490db76aecd89049f6482d92dab325e012749989", "Actual packed DuHui full atlas preserves approved Godot-imported RGBA pixel identity")
	for pose: String in ["idle","windup","strike","guard","hurt","kneel"]:
		var texture = art.texture_for(pose)
		_check(texture is AtlasTexture and texture.atlas.get_size() == Vector2(1536,1024) and texture.region == art.source_rect(pose) and texture.filter_clip, "Exact packed DuHui pose uses measured original atlas crop: "+pose)
		if texture == null: continue
		var image: Image = texture.get_image(); var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data())
		var digest: String = hash.finish().hex_encode()
		_check(not hashes.has(digest), "Six packed DuHui actions are distinct actual pixels: "+pose); hashes[digest] = true
		var foot := Vector2(1045,460); var rect: Rect2 = art.drawing_rect(foot,236,pose)
		_check((rect.position+(art.FOOT_ANCHORS[pose]-art.source_rect(pose).position)*(236.0/512.0)).distance_to(foot)<.001, "DuHui measured action anchor remains on authored foot: "+pose)
	_check(load("res://scripts/party_battle_backdrop.gd").style_for("heting_consignee") == "warehouse", "Chapter battle selects actual warehouse scenery")

func _consignee_prepare(ending: String = "short_ferries", receipt: int = 0, count: int = 1) -> void:
	_unified_prepare("heting_receipt",count)
	var s = game.state
	s.heting_draft = ending; s.heting_ending = ending; s.receipt_stage = receipt
	_check(s.learn_internal_skill() and s.learn_lightness(), "Prepared eligible chapter fixture explicitly learns existing internal/lightness skills")
	s.heal_rest(); game._sync_world_state(); game.world.refresh_heting_points()
	game.world.teleport(game.world.interactables.heting_dispatch.pos); s.position = game.world.player_pos
	game._refresh()
	_check(s.save_game() == OK and s._stage_save_data(s.to_dict(),16).ok, "Prepared prior harbor ending and optional receipt are canonical, with chapter unstarted")

func _consignee_progress() -> Dictionary:
	var result: Dictionary = {}
	for key: String in CONSIGNEE_FIELDS: result[key] = game.state.to_dict()[key]
	return result

func _consignee_economy() -> Dictionary:
	var s = game.state
	return {"xp":_receipt_xp(),"coins":s.coins,"hp":s.hp,"qi":s.qi,"medicine":s.medicine,"resources":s.resources.duplicate(true),"party":s.party_resources.duplicate(true)}

func _consignee_old_story() -> Dictionary:
	var s = game.state
	return {"harbor":s.heting_ending,"delivered":s.heting_delivered.duplicate(),"cargo":s.heting_cargo,"receipt":s.receipt_stage,"mist":s.mist_ending,"archive":s.chapter_two_ending,"roster":s.party_roster.duplicate()}

func _consignee_open(site: String) -> void:
	await _heting_open(site)
	if site != "consignee_warehouse": _press(game.consignee_story.link_label(site))
	_check(game.active_modal and game.consignee_story._at(site) and _gather_text(game.overlay).contains("未损先收"), "Actual E and original hub link open new chapter at the live site: "+site)

func _consignee_checkpoint(label: String) -> void:
	if game.active_modal: game._close_modal()
	game.state.position = game.world.player_pos
	var before: Dictionary = game.state.to_dict()
	_check(game.state.save_game() == OK, "Actual chapter checkpoint writes current scene progress: "+label)
	var bytes: PackedByteArray = _receipt_bytes()
	_check(_receipt_document().version == 16 and game.state._same_save_value(_receipt_document().player,before) and not bytes.get_string_from_utf8().contains("consignee_provenance"), "Chapter checkpoint includes complete16 fields and excludes transient battle provenance")
	game._load()
	_check(game.state.to_dict() == before and game.world.consignee_stage == game.state.consignee_stage and game.world.consignee_cargo_location == game.state.consignee_cargo_location and _receipt_bytes() == bytes, "Actual reload reapplies saved chapter/cargo before player position repair: "+label)
	var old: Dictionary = _receipt_variables(schema13_reader)
	_check(schema13_reader.load_game(game.state.SAVE_PATH) == ERR_FILE_UNRECOGNIZED and _receipt_variables(schema13_reader) == old and _receipt_bytes() == bytes, "Frozen Web25 rejects actual chapter stage without mutation: "+label)
	_consignee_backup(label)

func _consignee_begin_observe(plan: String, reverse: bool = false) -> void:
	await _consignee_open("heting_dispatch"); _press("接下本批核查")
	_check(game.state.consignee_stage == 1 and game.state.consignee_cargo_location == "warehouse", "Actual acceptance creates exactly one uninspected warehouse lot")
	await _consignee_checkpoint("accepted")
	var sites: Array[String] = ["consignee_warehouse","heting_dispatch","heting_lighter"]
	if reverse: sites.reverse()
	for site: String in sites:
		await _consignee_open(site); _press("亲自核验")
		_check(game.state.consignee_observations.size() == sites.find(site)+1 and game.state.consignee_contributions.is_empty(), "Actual independent solo observation persists in chosen visit order: "+site)
	_press("核对三处矛盾")
	var before: Dictionary = game.state.to_dict(); var bytes: PackedByteArray = _receipt_bytes()
	_press("两篓干粮证明整船无损")
	_check(game.state.to_dict() == before and _receipt_bytes() == bytes and _gather_text(game.overlay).contains("不能"), "Wrong deduction explains evidence boundary without losing clues or changing bytes")
	_press("重新核对"); _press("必须先补取旧复签")
	_check(game.state.to_dict() == before and _receipt_bytes() == bytes, "Optional old receipt is never forced or silently advanced")
	_press("重新核对"); _press("未验先撤，理由倒置")
	_check(game.state.consignee_stage == 2 and game.state.consignee_draft.is_empty(), "Correct actual deduction earns stage2 without selecting final policy")
	_press("拟作封粮留验" if plan == "hold_for_inspection" else "拟作撤运还粮")
	_check(game.state.consignee_stage == 2 and game.state.consignee_draft == plan and game.state.consignee_ending.is_empty(), "Actual chosen draft remains reversible and unpaid")
	await _consignee_checkpoint("reversible draft")

func _consignee_battle_open():
	await _consignee_open("consignee_warehouse")
	_check(_gather_text(game.overlay).contains("260") and _gather_text(game.overlay).contains("160") and _gather_text(game.overlay).contains("不发修为铜钱"), "Actual combat briefing identifies fixed enemies and no victory payment")
	_press("保存后阻止强提")
	var panel = _party_panel(); _unified_freeze(panel)
	_check(panel != null and game.current_screen == "party_battle" and panel.encounter == "heting_consignee" and panel.session.get_script() == load("res://scripts/automatic_party_combat.gd"), "Actual guarded E/choice enters eleventh shared automatic controller")
	return panel

func _consignee_fight(panel, outcome: String = "win") -> Dictionary:
	var terminal: Dictionary = {}; var before_hp: Dictionary = {"du_hui":260,"consignee_guard":160}
	var facts_ok: bool = true; var accepted: bool = true; var tokens: Dictionary = {}; var basics: Dictionary = {}
	for index: int in range(500):
		if not game.state.battle_active: break
		terminal = _unified_begin(panel,outcome == "win")
		if terminal.is_empty(): accepted = false; break
		facts_ok = facts_ok and not tokens.has(terminal.token); tokens[terminal.token] = true
		if terminal.action_id == "attack":
			var key: String = "%d/%s" % [terminal.before.round,terminal.source_id]
			facts_ok = facts_ok and not basics.has(key) and _party_actor(terminal.before,terminal.source_id).hp > 0; basics[key] = true
		for enemy: Dictionary in terminal.after.enemies:
			facts_ok = facts_ok and enemy.hp <= before_hp[enemy.id] and enemy.max_hp == (260 if enemy.id == "du_hui" else 160)
			before_hp[enemy.id] = enemy.hp
		facts_ok = facts_ok and not game.state.finish_party_presentation(terminal.epoch,terminal.token-1).accepted
		if not terminal.after.active: break
		panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(accepted and not terminal.is_empty() and not terminal.after.active and terminal.after.outcome == outcome, "Actual bounded chapter actions reach pending terminal outcome: "+outcome)
	_check(facts_ok and not basics.is_empty(), "Chapter actual transactions keep fixed enemy caps/no healing, unique tokens and once-per-living-actor basics; stale token rejected")
	return terminal

func _consignee_visual_lot() -> void:
	var s = game.state
	var visual: Dictionary = load("res://scripts/heting_region.gd").consignee_visual_state(true,s.consignee_stage,s.consignee_cargo_location,s.consignee_ending)
	_check(visual.warehouse_full+visual.cart_full+visual.scale_full == (0 if s.consignee_ending == "return_to_owner" else 2) and visual.cart_full == (2 if s.consignee_stage == 4 else 0), "Actual world projects one finite two-basket lot without source/cart/receiver duplication")
	_check(visual.duhui == (s.consignee_stage < 3) and (s.consignee_stage != 5 or not String(visual.scale_record).is_empty() and not String(visual.boat_record).is_empty()), "World opponent removal and both final receiver records agree with durable chapter state")

func _test_consignee_route(ending: String, plan: String, receipt: int) -> void:
	_consignee_prepare(ending,receipt)
	var s = game.state; var original: Dictionary = _consignee_old_story(); var economy: Dictionary = _consignee_economy()
	_check(s.party_roster == ["hero"] and not s.companion_unlocked and not s.tangqi_unlocked and not s.qin_unlocked, "Both new endings remain available without recruiting anybody")
	await _consignee_checkpoint("unstarted")
	await _consignee_open("heting_dispatch"); var stale: Callable = game.modal_actions[0]; var bytes: PackedByteArray = _receipt_bytes()
	await _key(KEY_ESCAPE); stale.call()
	_check(s.consignee_stage == 0 and _receipt_bytes() == bytes, "Canceled acceptance and its stale callback create no progress or write")
	await _consignee_begin_observe(plan,receipt == 3)
	_check(_consignee_economy() == economy and _consignee_old_story() == original, "Investigation and draft consume no reward/resources or earlier endings/optional receipt")
	var panel = await _consignee_battle_open()
	if panel == null: return
	var snapshot: Dictionary = s.party_battle_snapshot()
	_check(snapshot.enemies.size() == 2 and snapshot.enemies[0].id == "du_hui" and snapshot.enemies[0].max_hp == 260 and snapshot.enemies[1].id == "consignee_guard" and snapshot.enemies[1].max_hp == 160, "Actual chapter entry uses two distinct targetable fixed-cap opponents")
	_check(panel.art.backdrop_style == "warehouse" and panel.commands.context.title == "未损先收" and panel.unit_plates.has("du_hui") and panel.unit_plates.has("consignee_guard"), "Actual chapter presents correct backdrop/title and opponent plates")
	var terminal: Dictionary = _consignee_fight(panel)
	if terminal.is_empty(): return
	_check(s.consignee_stage == 2 and s.coins == economy.coins and _receipt_xp() == economy.xp and panel.art.is_presenting(), "Pending win leaves persistent stage/rewards untouched until real presentation completes")
	_party_finish(panel)
	_check(s.consignee_stage == 3 and s.consignee_ending.is_empty() and s.coins == economy.coins and _receipt_xp() == economy.xp and s.party_settlement.outcome == "win", "Only real completed victory secures stage3 and pays no XP or coins")
	var settled: Dictionary = s.to_dict(); panel._finished()
	_check(s.to_dict() == settled, "Duplicate terminal renderer callback cannot resettle victory")
	_consignee_visual_lot(); await _consignee_checkpoint("secured warehouse")
	await _consignee_open("consignee_warehouse"); _press("押本批两篓封粮"); _press("继续押送")
	_check(s.consignee_stage == 4 and s.consignee_cargo_location == "cart" and game.world.heting_cart_loaded() and s.heting_cargo.is_empty() and s.available_consignee_cargo("consignee_warehouse").is_empty(), "Actual take moves same finite lot onto loaded cart, independently of old cargo")
	_consignee_visual_lot(); await _consignee_checkpoint("loaded same lot")
	_check(not game.world._can_walk(Vector2(805,500)), "Actual new loaded cart rejects narrow pedestrian pier")
	var start: Vector2 = game.world.player_pos; var cargo_before: Dictionary = _consignee_progress()
	Input.action_press("move_down"); game.world._process(15.0/game.world.SPEED); Input.action_release("move_down")
	var moved: bool = game.world.player_pos.distance_to(start+Vector2(0,15)) < .01
	Input.action_press("move_up"); game.world._process(15.0/game.world.SPEED); Input.action_release("move_up")
	_check(moved and game.world.player_pos.distance_to(start)<.01 and _consignee_progress() == cargo_before and game.world.heting_cart_loaded(), "Actual movement input transports loaded same lot along legal warehouse approach without altering progress")

	var receiver: String = "heting_scale" if plan == "hold_for_inspection" else "heting_cargo"
	var wrong: String = "heting_cargo" if receiver == "heting_scale" else "heting_scale"
	await _consignee_open(wrong)
	_check(_find_button(game.overlay,"确认交下本批") == null and s.consignee_stage == 4, "Wrong receiver cannot silently finalize current draft")
	await _key(KEY_ESCAPE)
	await _consignee_open("consignee_warehouse"); _press("更改本批草案"); _press("拟作撤运还粮" if plan == "hold_for_inspection" else "拟作封粮留验")
	_check(s.consignee_draft != plan and s.consignee_stage == 4 and s.consignee_cargo_location == "cart", "Actual loaded draft can change without cloning, returning or delivering cargo")
	_press("更改本批草案"); _press("拟作封粮留验" if plan == "hold_for_inspection" else "拟作撤运还粮"); _press("继续押送")
	game._show_map(); await process_frame
	var chart = game.overlay.find_child("RegionChart",true,false)
	var route: PackedVector2Array = chart.cart_route
	var safe: bool = route.size() > 1
	for i: int in range(1,route.size()): safe = safe and load("res://scripts/heting_region.gd").can_step(route[i-1],route[i],s.heting_bridge,true)
	_check(chart.current_target == receiver and route[0] == game.world.player_pos and route[-1] == game.world.interactables[receiver].pos and safe, "Actual loaded chapter map routes same cart safely to current plan receiver")
	await _key(KEY_1)
	await _consignee_open(receiver); stale = game.modal_actions[0]; bytes = _receipt_bytes(); var before: Dictionary = s.to_dict()
	await _key(KEY_ESCAPE); stale.call()
	_check(s.to_dict() == before and _receipt_bytes() == bytes and s.consignee_stage == 4, "Canceled handover/stale callback retain complete loaded progress and bytes")
	await _consignee_open(receiver); stale = game.modal_actions[0]
	var xp: int = _receipt_xp(); var coins: int = s.coins
	_press("确认交下本批")
	_check(s.consignee_stage == 5 and s.consignee_ending == plan and s.consignee_cargo_location == ("public_scale" if plan == "hold_for_inspection" else "grain_boat") and _receipt_xp() == xp+120 and s.coins == coins+60, "Only explicit final handover locks selected branch and grants exactly120XP/60coins once")
	settled = s.to_dict(); stale.call()
	_check(s.to_dict() == settled and _consignee_old_story() == original, "Old ending/receipt/party and new ending survive duplicate callback without reward replay")
	_consignee_visual_lot(); await _consignee_checkpoint("final "+plan)
	await _consignee_open("consignee_warehouse")
	_check(_find_button(game.overlay,"押本批两篓封粮") == null and _gather_text(game.overlay).contains("平川粮栈") and _gather_text(game.overlay).contains("待追查"), "Completed warehouse has no respawn and records bounded local finding")
	await _key(KEY_ESCAPE)
	var final_before: Dictionary = s.to_dict(); var file_before: PackedByteArray = _receipt_bytes()
	var view_blocked: String = _receipt_block_save()
	game._show_journal(); await _key(KEY_ESCAPE); game._show_map(); await _key(KEY_1)
	_check(s.to_dict() == final_before and _receipt_bytes() == file_before and not game.save_warning, "Final journal/map views do not attempt save even with unwritable temporary path")
	_receipt_unblock_save(view_blocked)

func _consignee_backup(label: String) -> void:
	var directory: String = _transfer_directory("consignee-backup-"+label)
	var store = load("res://scripts/local_save_slots.gd").new(directory)
	var s = game.state; var prior: Dictionary = s.to_dict(); var probe = load("res://scripts/game_state.gd").new()
	_check(store.save_slot(s,1) == OK, "Actual new chapter manual slot records terminal stage")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(store.path_for(1))
	s.coins += 1
	_check(store.save_slot(s,1) == OK and FileAccess.get_file_as_bytes(store.path_for(1)+".bak") == bytes, "Ordinary second slot write preserves exact previous chapter backup bytes")
	_check(store.load_backup(probe,1) == OK and probe.to_dict() == prior, "Actual backup load restores final branch/reward/resources exactly")
	s.coins -= 1
	var transfer = load("res://scripts/local_save_transfer.gd").new(directory)
	var preview: Dictionary = transfer.preview_import(bytes,2)
	_check(preview.ok and preview.version == 16 and transfer.commit_import(preview.token).ok and FileAccess.get_file_as_bytes(store.path_for(2)) == bytes, "Actual packed core imports chapter14 exact bytes into genuinely empty slot only")
	_check(not transfer.preview_import(bytes,2).ok and transfer.export_slot(2).bytes == bytes, "Chapter14 occupied slot stays protected and export preserves raw bytes")

func _consignee_seed_ready(count: int = 1, receipt: int = 0) -> void:
	_consignee_prepare("short_ferries",receipt,count)
	var s = game.state
	_check(s.begin_consignee(), "Prepared chapter boundary fixture begins through actual state API")
	for id: String in ["lot_seals","removal_order","southern_counterfoil"]:
		_check(s.observe_consignee(id), "Prepared boundary fixture records actual independent observation: "+id)
	_check(s.resolve_consignee_contradiction("order_before_inspection").correct and s.choose_consignee_plan("hold_for_inspection"), "Prepared boundary fixture earns real deduction and draft without combat shortcut")
	game._sync_world_state(); game._refresh()

func _test_consignee_optional_methods() -> void:
	var story = load("res://scripts/heting_consignee_story.gd")
	for method: String in ["tang_teach","tang_preserve","qin_timing","shen_shore","shen_mobile"]:
		_consignee_prepare("open_scale",1,4)
		var s = game.state
		var actor: String = "tang" if method.begins_with("tang") else ("shen" if method.begins_with("shen") else "qin")
		var observation: String = "lot_seals" if actor == "tang" else ("southern_counterfoil" if actor == "shen" else "removal_order")
		var site: String = story.OBSERVATION_SITES[observation]
		if actor == "tang": s.tangqi_choice = "teach" if method == "tang_teach" else "preserve"
		if actor == "shen": s.shen_care_stage = 5; s.shen_care_choice = "shore" if method == "shen_shore" else "mobile"
		await _consignee_open("heting_dispatch"); _press("接下本批核查")
		await _consignee_open(site)
		var callback: Callable = game.modal_actions[1]
		_check(_find_button(game.overlay,story.METHOD_LABELS[method]) != null, "Actual deployed standing earned companion offers alternate method: "+method)
		s.party_resources[actor].hp = 0; var before: Dictionary = s.to_dict(); var bytes: PackedByteArray = _receipt_bytes(); callback.call()
		_check(s.to_dict() == before and _receipt_bytes() == bytes and s.consignee_observations.is_empty(), "Actual live downed helper invalidates already-open contribution callback")
		s.party_resources[actor].hp = 1
		await _consignee_open(site); callback = game.modal_actions[1]
		_check(s.set_party_roster(["hero"]), "Actual roster API benches optional contributor")
		before = s.to_dict(); callback.call()
		_check(s.to_dict() == before and s.consignee_observations.is_empty(), "Already-open optional contribution rechecks actual current party membership")
		_check(s.set_party_roster(["hero",actor]), "Actual roster API reselects living earned contributor")
		game._sync_world_state(); await _consignee_open(site)
		var economy: Dictionary = _consignee_economy(); _press(story.METHOD_LABELS[method])
		_check(s.consignee_observations == [observation] and s.consignee_contributions == [method] and _consignee_economy() == economy and _gather_text(game.overlay).contains(s.Consignee.method_description(method)), "Actual alternate method records meaningful prior-role text with no reward/recovery/cost: "+method)
		await _consignee_checkpoint("optional "+method)
	for ending: String in ["short_ferries","open_scale"]:
		for receipt: int in range(4):
			_consignee_prepare(ending,receipt)
			await _consignee_open("heting_dispatch")
			_press("接下本批核查")
			_check(game.state.consignee_stage == 1 and game.state.receipt_stage == receipt and game.state.heting_ending == ending, "Actual chapter offer accepts either prior ending and every optional receipt stage unchanged")

func _test_consignee_battle_boundaries() -> void:
	for count: int in range(1,5):
		_consignee_seed_ready(count)
		var s = game.state; var panel = await _consignee_battle_open()
		if panel == null: return
		var initial: Dictionary = s.party_battle_snapshot(); var bytes: PackedByteArray = _receipt_bytes()
		_check(panel.commands.groups.size() == count and initial.actors.size() == count, "Chapter occupied groups match actual1–4 selected actors")
		for actor: Dictionary in initial.actors:
			_check(panel.commands._slots(actor).size() == 3 and actor.actions[0].category == "martial" and actor.actions[1].category == "internal" and actor.actions[2].category == "lightness", "Every chapter actor retains fixed3 skill slots and autonomous basic")
		panel.set_pause_request(true)
		var snapshot: Dictionary = s.party_battle_snapshot(); var persistent: Dictionary = s.to_dict()
		root.gui_release_focus(); await _key(KEY_ENTER); await _key(KEY_SPACE)
		panel.request_command("hero","attack"); panel.request_command("hero","guard")
		_check(s.party_battle_snapshot() == snapshot and s.to_dict() == persistent and panel.pending.is_empty(), "Chapter Enter/Space and direct manual basic/guard cannot execute or consume")
		panel.unit_plates.consignee_guard.pressed.emit()
		_check(s.party_battle_snapshot().selected_target_id == "consignee_guard", "Actual distinct guard plate changes shared selected target")
		await _key(KEY_TAB)
		_check(s.party_battle_snapshot().selected_target_id == "du_hui", "Actual Tab cycles to authored DuHui target")
		panel.request_command("hero","lightness:hero_tawei")
		_check(s.party_battle_snapshot().actors[0].categories.lightness.queued and s.party_battle_snapshot().actors[0].qi == initial.actors[0].qi, "Existing actual lightness queue is free until its accepted slot")
		panel.cancel_skill("hero","lightness")
		_check(not s.party_battle_snapshot().actors[0].categories.lightness.queued and s.party_battle_snapshot().actors[0].qi == initial.actors[0].qi, "Actual cancel clears optional skill without Qi charge")
		panel.set_pause_request(false)
		var basics: Array = []; var valid: bool = true
		for step: int in range(16):
			if s.party_battle_snapshot().round > 1: break
			var tx: Dictionary = _unified_begin(panel,false)
			if tx.is_empty(): valid = false; break
			if tx.action_id == "attack": basics.append(tx.source_id)
			var display: Dictionary = panel.art.display_snapshot.duplicate(true)
			valid = valid and not s.advance_party_battle().accepted and not s.finish_party_presentation(tx.epoch,tx.token-1).accepted
			valid = valid and display == panel.art.display_snapshot
			panel.art._process(panel.art.get_presentation_duration()+.1)
		_check(valid and basics == s.party_roster and s.party_battle_snapshot().round == 2, "Actual chapter first round grants exactly once to every living occupied actor, with stale/duplicate presentation locked")
		_check(_receipt_bytes() == bytes and s.save_game() == ERR_BUSY, "Active chapter preserves exact pre-entry disk checkpoint and rejects mid-action saves")
		var current: Dictionary = s.party_battle_snapshot(); var economy: Dictionary = _consignee_economy(); var chapter: Dictionary = _consignee_progress()
		_unified_leave()
		_check(not s.battle_active and s.party_settlement.outcome == "flee" and _consignee_progress() == chapter and s.coins == economy.coins and _receipt_xp() == economy.xp, "Actual retreat applies no invented fee/reward or chapter stage advancement")
		_check(s.hp == current.actors[0].hp and s.qi == current.actors[0].qi and s.medicine == current.medicine, "Actual retreat retains consumed resources instead of restoring entry checkpoint")
		persistent = s.to_dict(); panel._finished(); panel.leave(); panel.request_command("hero","item")
		_check(s.to_dict() == persistent and not s.battle_active, "Stale real controller cannot replay medicine/retreat/settlement after return")
		await _consignee_checkpoint("retreat %d actors" % count)
	_consignee_seed_ready(1,2)
	game.state.hp = 1; game.state.qi = 0; game.state.medicine = 0
	var panel = await _consignee_battle_open(); var before: Dictionary = _consignee_economy(); var chapter: Dictionary = _consignee_progress()
	if panel == null: return
	var terminal: Dictionary = _consignee_fight(panel,"defeat")
	if terminal.is_empty(): return
	_party_finish(panel)
	_check(game.state.party_settlement.outcome == "defeat" and _consignee_progress() == chapter and game.state.coins == before.coins-mini(8,before.coins) and _receipt_xp() == before.xp, "Actual defeat charges bounded8coins once and preserves stage2/draft without reward")
	_check(game.state.map_id == "heting" and game.world.player_pos == Vector2(230,735) and game.state.hp == game.state.max_hp and game.state.qi >= 2 and game.state.medicine == 0, "Defeat safely returns to west relief point with documented recovery and no medicine refund")
	await _consignee_checkpoint("defeat")
	await _heting_open("heting_relief"); var coins: int = game.state.coins; _press("借棚调息")
	_check(game.state.hp == game.state.max_hp and game.state.qi == game.state.max_qi and game.state.coins == coins and game.state.consignee_stage == 2, "Actual harbor rest remains free after defeat and leaves investigation ready for retry")

func _test_consignee_failures() -> void:
	_consignee_prepare()
	await _consignee_open("heting_dispatch")
	var s = game.state; var stale: Callable = game.modal_actions[0]; var old: Dictionary = s.to_dict(); var bytes: PackedByteArray = _receipt_bytes()
	game.world.teleport(Vector2(150,335)); game._process(0); old = s.to_dict(); stale.call()
	_check(s.to_dict() == old and _receipt_bytes() == bytes and s.consignee_stage == 0, "Moved-away actual acceptance callback rechecks scene proximity before changing anything")
	await _consignee_open("heting_dispatch")
	var blocked: String = _receipt_block_save(); _press("接下本批核查")
	_check(s.consignee_stage == 1 and game.save_warning and _receipt_bytes() == bytes and _find_button(game.overlay,"重试保存") != null, "Failed acceptance save retains accepted in-memory stage and offers actual safe retry")
	var before: Dictionary = s.to_dict(); _press("重试保存")
	_check(s.to_dict() == before and _receipt_bytes() == bytes and game.save_warning, "Repeated failed save only retries same accepted progress")
	_receipt_unblock_save(blocked); _press("重试保存")
	_check(not game.save_warning and _receipt_document().player.consignee_stage == 1 and s.to_dict() == before, "Successful actual retry writes retained stage once without extra mutation")
	_consignee_seed_ready()
	await _consignee_open("consignee_warehouse"); bytes = _receipt_bytes(); before = s.to_dict(); blocked = _receipt_block_save()
	_press("保存后阻止强提")
	_check(not s.battle_active and s.to_dict() == before and _receipt_bytes() == bytes and game.save_warning, "Actual failed pre-entry checkpoint blocks fight before any resource cost")
	_receipt_unblock_save(blocked); _press("重试保存")
	_check(not s.battle_active and not game.save_warning and _find_button(game.overlay,"保存后阻止强提") != null, "Pre-entry retry restores briefing without automatically starting battle")
	_press("保存后阻止强提"); var panel = _party_panel(); _unified_freeze(panel)
	_check(panel != null and s.battle_active, "Actual explicit retry after recovered checkpoint can enter")
	if panel == null: return
	var terminal: Dictionary = _consignee_fight(panel)
	if terminal.is_empty(): return
	bytes = _receipt_bytes(); blocked = _receipt_block_save(); _party_finish(panel)
	var settled: Dictionary = s.to_dict()
	_check(s.consignee_stage == 3 and game.save_warning and _receipt_bytes() == bytes and _find_button(game.overlay,"重试保存") != null, "Failed real victory autosave keeps secured stage and actual consumed resources in memory")
	panel._finished(); _press("重试保存")
	_check(s.to_dict() == settled and _receipt_bytes() == bytes, "Duplicate renderer and failed victory retry cannot replay settlement")
	_receipt_unblock_save(blocked); _press("重试保存")
	_check(not game.save_warning and s.to_dict() == settled and _receipt_document().player.consignee_stage == 3, "Recovered post-battle retry persists same secured state once")
	await _consignee_open("consignee_warehouse"); _press("押本批两篓封粮"); _press("继续押送")
	await _heting_open("return_mistwood"); stale = game.modal_actions[0]; bytes = _receipt_bytes(); before = s.to_dict()
	_press("留在埠内"); stale.call()
	_check(s.to_dict() == before and s.consignee_stage == 4 and _receipt_bytes() == bytes, "Canceled actual departure and stale callback cannot discard or park loaded cargo")
	await _heting_open("return_mistwood"); _press("停回北仓后离开")
	_check(s.map_id == "mistwood" and s.consignee_stage == 3 and s.consignee_cargo_location == "warehouse" and s.consignee_draft == "hold_for_inspection", "Only explicit departure parks intact same lot and retains secured draft")
	await _heting_open("exit_heting"); _press("返回鹤汀埠")
	await _consignee_open("consignee_warehouse"); _press("押本批两篓封粮"); _press("继续押送")
	_check(s.consignee_stage == 4 and s.available_consignee_cargo("consignee_warehouse").is_empty(), "Returning retrieves original finite lot without replaying combat or duplicating warehouse stock")
	await _consignee_open("heting_scale"); stale = game.modal_actions[0]; bytes = _receipt_bytes(); blocked = _receipt_block_save()
	var coins: int = s.coins; var xp: int = _receipt_xp(); _press("确认交下本批")
	_check(s.consignee_stage == 5 and s.coins == coins+60 and _receipt_xp() == xp+120 and game.save_warning and _receipt_bytes() == bytes, "Failed final write retains one actually paid ending instead of rolling back or duplicating payout")
	settled = s.to_dict(); stale.call(); _press("重试保存")
	_check(s.to_dict() == settled and _receipt_bytes() == bytes, "Stale final choice and failed retry cannot pay120XP60coins again")
	_receipt_unblock_save(blocked); _press("重试保存")
	_check(not game.save_warning and s.to_dict() == settled and _receipt_document().player.consignee_stage == 5, "Successful actual final retry saves exact already-paid ending")
	await _consignee_checkpoint("retried final reward")

# Paint-only Web28 gates load actual shipped modules. Resource/draw-call/font-cache
# contracts are deliberately distinct from native framebuffer/browser acceptance.
class PolishLabelProbe extends RefCounted:
	var ui_font: Font
	var calls: Array = []
	func draw_string_outline(font: Font, p: Vector2, text: String, alignment: int, width: float, size: int, outline: int, color: Color) -> void:
		calls.append({"kind":"outline","font":font,"p":p,"text":text,"alignment":alignment,"width":width,"size":size,"outline":outline,"color":color})
	func draw_string(font: Font, p: Vector2, text: String, alignment: int, width: float, size: int, color: Color) -> void:
		calls.append({"kind":"fill","font":font,"p":p,"text":text,"alignment":alignment,"width":width,"size":size,"color":color})

class PolishBackdropProbe extends Control:
	var scenery
	var floor_mesh: ArrayMesh
	var encounter: String = "heting_consignee"
	var draws: int = 0
	func _draw() -> void:
		scenery.draw(self,floor_mesh,encounter,.375)
		draws += 1

func _polish_channel_step(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

func _polish_sky(scenery, y: float) -> Color:
	return scenery._warehouse_sky_colors[0].lerp(scenery._warehouse_sky_colors[3],clampf(y/685.0,0.0,1.0))

func _polish_opacity(scenery, y: float) -> float:
	return scenery.WAREHOUSE_APRON_OPACITY * clampf((y-278.0)/scenery.WAREHOUSE_APRON_FADE,0.0,1.0)

func _polish_contrast(a: Color, b: Color) -> float:
	var x: float = a.srgb_to_linear().get_luminance(); var y: float = b.srgb_to_linear().get_luminance()
	return (maxf(x,y)+.05)/(minf(x,y)+.05)

func _test_heting_polish_pack() -> void:
	var first: int = checks
	var state: Dictionary = _receipt_variables(game.state)
	var save_bytes: PackedByteArray = _receipt_bytes()
	var scenery = load("res://scripts/party_battle_backdrop.gd")
	var harbor = load("res://scripts/heting_region.gd")
	var encounters = load("res://scripts/unified_encounter_rules.gd")
	var art = load("res://scripts/party_battle_art.gd").new()
	scenery.prepare()
	_check(scenery.ENCOUNTER_STYLES == {"training":"courtyard","sect_trial":"courtyard","courtyard_practice":"courtyard","heting_consignee":"warehouse"}, "Polish keeps the bounded original four-entry style mapping")
	_check(encounters.IDS.size() == 12 and encounters.IDS.slice(0,11).size() == 11, "Polish retains eleven old identifiers; capstone archive checked separately")
	for id: String in encounters.IDS.slice(0,11):
		var expected: String = "warehouse" if id == "heting_consignee" else ("courtyard" if id in ["training","sect_trial","courtyard_practice"] else "ferry")
		_check(scenery.style_for(id) == expected and scenery.floor_texture_for(id) == (scenery.EARTH if expected in ["courtyard","warehouse"] else scenery.WOOD), "Polish retains prior encounter style/material: "+id)
	for id: String in ["","unrecognized","warehouse","heting_consignee_future"]:
		_check(scenery.style_for(id) == "ferry" and scenery.floor_texture_for(id) == scenery.WOOD, "Polish preserves unknown encounter fallback")
	_check(scenery.WAREHOUSE == {"type":"hall","pos":Vector2(676,173),"size":Vector2(435,110)}, "Packed warehouse anchor and source dimensions remain exact")
	var scale_factor: float = 485.0/568.0
	var hall_rect := Rect2(Vector2(893.5,283)-Vector2(281,340)*scale_factor,Vector2(568,397)*scale_factor)
	_check(scenery._warehouse_rect.is_equal_approx(hall_rect) and scenery._hall_texture.get_size() == Vector2(568,397), "Packed warehouse reuses unchanged hall image bounds/aspect")
	_check(scenery._warehouse_plaque.is_equal_approx(Rect2(hall_rect.position+Vector2(208,162)*scale_factor,Vector2(134,31)*scale_factor)), "Packed warehouse plaque remains aligned to original hall")
	_check(scenery.APRON == Rect2(0,278,1280,407) and scenery._apron_mesh == scenery.Tiles.geometry(scenery.APRON,512.0).mesh, "Packed original apron bounds and courtyard cache are unchanged")
	_check(scenery._warehouse_sky_points == PackedVector2Array([Vector2(0,0),Vector2(1280,0),Vector2(1280,685),Vector2(0,685)]), "Packed warehouse uses one continuous field without former rectangular bands")
	_check(scenery._warehouse_sky_colors == PackedColorArray([Color("637f75"),Color("637f75"),Color("858f77"),Color("858f77")]), "Packed muted opaque gradient endpoints match left and right")
	_check(scenery.WAREHOUSE_APRON_FADE == 64.0 and scenery.WAREHOUSE_APRON_OPACITY == .28, "Packed apron fades over64px without increasing its original opacity")
	# Bounded analytic samples across prior band coordinates and both target scales.
	# These are declared paint values, never claimed as final framebuffer samples.
	for width: float in [1280.0,1179.0]:
		var step: float = 1280.0/width
		for y: float in [0.0,155.0,179.0,207.0,221.0,265.0,277.0,278.0,301.0,319.0,337.0,341.0,342.0,511.0,683.0]:
			_check(_polish_channel_step(_polish_sky(scenery,y),_polish_sky(scenery,y+step)) <= 4.0/255.0, "Packed analytic field remains continuous at bounded logical row samples")
			for texel: Color in [Color.BLACK,Color.WHITE]:
				_check(_polish_channel_step(_polish_sky(scenery,y).lerp(texel,_polish_opacity(scenery,y)),_polish_sky(scenery,y+step).lerp(texel,_polish_opacity(scenery,y+step))) <= 4.0/255.0, "Packed opacity ramp has no analytic row discontinuity")
	_check(scenery._warehouse_shore_points.size() == 11 and scenery._warehouse_shore_colors.size() == 11, "Packed distant shore is one bounded cached silhouette")
	for i: int in scenery._warehouse_shore_points.size():
		var point: Vector2 = scenery._warehouse_shore_points[i]
		var color: Color = scenery._warehouse_shore_colors[i]
		var sky: Color = _polish_sky(scenery,point.y)
		var composed: Color = sky.lerp(Color(color.r,color.g,color.b),color.a)
		_check(point.y < 278 and color.a <= .12001 and absf(composed.get_luminance()-sky.get_luminance()) <= 12.0/255.0, "Packed distant shore remains faint and behind the apron")
	_check(scenery._warehouse_shore_colors[9].a == 0 and scenery._warehouse_shore_colors[10].a == 0, "Packed distant shore has no lower hard horizon")
	_test_polish_apron(scenery)
	var floor_mesh: ArrayMesh = art._make_floor()
	art.free()
	var floor_arrays: Array = floor_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = floor_arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = floor_arrays[Mesh.ARRAY_TEX_UV]
	_check(vertices.size() == 36 and uvs.size() == 36, "Packed shared combat floor keeps exactly six patches")
	var index: int = 0
	for row: int in range(2):
		for column: int in range(3):
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var depth: float = (row+corner.y)/2.0
				var expected := Vector3(lerpf(110-150*depth,1170+150*depth,(column+corner.x)/3.0),lerpf(320,682,depth),0)
				_check(vertices[index].is_equal_approx(expected) and uvs[index] == Vector2(1-corner.x if column%2 else corner.x,1-corner.y if row%2 else corner.y), "Packed combat floor retains every original vertex and mirror direction")
				index += 1
	var apron: ArrayMesh = scenery._warehouse_apron_mesh
	var apron_arrays: Array = apron.surface_get_arrays(0)
	var sky_points: PackedVector2Array = scenery._warehouse_sky_points.duplicate()
	var sky_colors: PackedColorArray = scenery._warehouse_sky_colors.duplicate()
	var shore_points: PackedVector2Array = scenery._warehouse_shore_points.duplicate()
	var shore_colors: PackedColorArray = scenery._warehouse_shore_colors.duplicate()
	var original_apron: ArrayMesh = scenery._apron_mesh
	var original_hall: Texture2D = scenery._hall_texture
	var probe := PolishBackdropProbe.new()
	probe.scenery = scenery; probe.floor_mesh = floor_mesh; probe.size = Vector2(1280,685)
	root.add_child(probe)
	for id: String in encounters.IDS.slice(0,11):
		probe.encounter = id
		for repeat: int in range(2):
			var before_draws: int = probe.draws
			scenery.prepare(); probe.queue_redraw()
			await process_frame; await process_frame
			_check(probe.draws > before_draws, "Actual packed backdrop draw executes for "+id)
			_check(scenery._warehouse_apron_mesh == apron and apron.surface_get_arrays(0) == apron_arrays and floor_mesh.surface_get_arrays(0) == floor_arrays, "Packed prepare/draw reuses immutable warehouse and combat meshes")
			_check(scenery._warehouse_sky_points == sky_points and scenery._warehouse_sky_colors == sky_colors and scenery._warehouse_shore_points == shore_points and scenery._warehouse_shore_colors == shore_colors and scenery._apron_mesh == original_apron and scenery._hall_texture == original_hall, "Packed paint caches and original courtyard resources remain immutable")
	probe.queue_free(); await process_frame
	_test_polish_route_labels(harbor)
	_check(_receipt_variables(game.state) == state and _receipt_bytes() == save_bytes, "Packed paint inspection leaves all gameplay fields and save bytes unchanged")
	_check(game.state.SAVE_VERSION == 16 and not game.web_save_transfer_enabled and not ProjectSettings.get_setting("hero/features/web_save_transfer_enabled",false), "Paint-only package retains schema16 and default-off browser transfer")
	print("Heting paint-only polish exact-runtime coverage: %d checks; actual warehouse gradient/apron/cache and eleven unchanged style mappings; exactly four route-label strings with both pontoon positions; actual outline/font-cache layout contracts; no native framebuffer or browser pixel acceptance" % (checks-first))

func _test_polish_apron(scenery) -> void:
	var mesh: ArrayMesh = scenery._warehouse_apron_mesh
	_check(mesh != null and mesh != scenery._apron_mesh and mesh.get_surface_count() == 1, "Packed warehouse opacity ramp owns one separate cached mesh")
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_check(vertices.size() == 54 and uvs.size() == 54 and colors.size() == 54, "Packed warehouse mesh contains only the original tiles plus one fade split")
	var area: float = 0.0; var seams: Dictionary = {}
	for i: int in range(0,vertices.size(),6):
		var a := Vector2(vertices[i].x,vertices[i].y)
		var b := Vector2(vertices[i+1].x,vertices[i+1].y)
		var c := Vector2(vertices[i+2].x,vertices[i+2].y)
		area += (b.x-a.x)*(c.y-b.y)
		_check(is_equal_approx(absf(uvs[i+1].x-uvs[i].x)*512.0,b.x-a.x) and is_equal_approx(absf(uvs[i+2].y-uvs[i+1].y)*512.0,c.y-b.y), "Packed apron keeps original 512-unit texel density")
	for i: int in vertices.size():
		var point := Vector2(vertices[i].x,vertices[i].y)
		var expected: Vector2 = point/512.0
		for axis: int in range(2):
			var cell: int = int(floor(expected[axis])); expected[axis] -= cell
			if cell%2 != 0: expected[axis] = 1.0-expected[axis]
		_check(uvs[i].is_equal_approx(expected) and scenery.APRON.grow(.001).has_point(point), "Packed apron preserves mirrored earth samples inside original bounds")
		_check(colors[i].r == 1 and colors[i].g == 1 and colors[i].b == 1 and absf(colors[i].a-_polish_opacity(scenery,point.y)) <= 1.0/255.0, "Packed apron changes only opacity at every vertex")
		_check(not seams.has(point) or (seams[point].uv == uvs[i] and seams[point].color == colors[i]), "Packed shared tile/fade seams are identical")
		seams[point] = {"uv":uvs[i],"color":colors[i]}
	_check(is_equal_approx(area,1280.0*407.0), "Packed apron patches cover original area exactly")

func _test_polish_route_labels(harbor) -> void:
	var font: FontFile = load("res://assets/fonts/NotoSansSC.otf")
	var labels: Array = [
		{"p":Vector2(1033,316),"text":"北岸横街  ·  板车可绕行","size":14,"width":297.0},
		{"p":Vector2(710,410),"text":"窄步栈  ·  行人通行","size":13,"width":195.0},
		{"p":Vector2(709,426),"text":"板车走侧浮栈","size":13,"width":195.0},
		{"p":Vector2(361,737),"text":"连 舟 浮 栈","size":13,"width":228.0},
		{"p":Vector2(1031,737),"text":"连 舟 浮 栈","size":13,"width":248.0},
	]
	var unique_labels: Dictionary = {}
	var probe := PolishLabelProbe.new(); probe.ui_font = font
	_check(harbor.ROUTE_INK == Color("142b26") and harbor.PAPER == Color("e2d3ad") and harbor.ROUTE_OUTLINE_SIZE == 2, "Packed route-only ink/support/outline palette remains pinned")
	_check(_polish_contrast(harbor.ROUTE_INK,harbor.PAPER) >= 8.0, "Packed declared ink/support contrast exceeds8:1; no framebuffer claim")
	for base: Color in [Color("b9b090"),Color("c3b794"),Color("d0c29f")]:
		_check(_polish_contrast(harbor.ROUTE_INK,base) >= 5.4, "Packed declared north-bank palette contrast remains readable")
	_check(_polish_contrast(harbor.ROUTE_INK,harbor.WOOD_DARK) < 4.5, "Packed dark timber alone is not incorrectly accepted as sufficient contrast")
	for item: Dictionary in labels:
		unique_labels[item.text] = true
		probe.calls.clear()
		harbor._route_label(probe,item.p,item.text,item.size,item.width,HORIZONTAL_ALIGNMENT_CENTER)
		_check(probe.calls.size() == 2, "Actual packed route helper emits exactly outline and fill")
		if probe.calls.size() != 2: continue
		_check(probe.calls[0].kind == "outline" and probe.calls[0].outline == 2 and probe.calls[0].color == harbor.PAPER and probe.calls[1].kind == "fill" and probe.calls[1].color == harbor.ROUTE_INK, "Actual packed route support precedes unchanged-weight CJK fill")
		for call: Dictionary in probe.calls:
			_check(call.font == font and call.p == item.p and call.text == item.text and call.size == item.size and call.width == item.width and call.alignment == HORIZONTAL_ALIGNMENT_CENTER, "Actual packed route preserves shared font/text/anchor/size/width/alignment")
	_check(unique_labels.size() == 4 and labels.size() == 5, "Exactly four approved route strings cover the two alternative pontoon positions")
	probe.ui_font = null; probe.calls.clear()
	harbor._route_label(probe,Vector2.ZERO,"通行",13,100,HORIZONTAL_ALIGNMENT_CENTER)
	_check(probe.calls.size() == 2 and probe.calls[0].font == ThemeDB.fallback_font and probe.calls[1].font == ThemeDB.fallback_font, "Packed null-font compatibility still uses the actual fallback font")
	for oversampling: float in [0.0,2.0]:
		var cached_font: FontFile = font.duplicate(); cached_font.oversampling = oversampling
		var support: Array[Rect2] = []; var ink: Array[Rect2] = []
		for item: Dictionary in labels:
			var width: float = cached_font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,item.size).x
			var offset: Vector2 = item.p+Vector2((item.width-width)*.5,0)
			var filled: Dictionary = _polish_glyph_bounds(cached_font,item.text,item.size,0)
			var outlined: Dictionary = _polish_glyph_bounds(cached_font,item.text,item.size,harbor.ROUTE_OUTLINE_SIZE)
			_check(width+4 < item.width and filled.valid and outlined.valid, "Packed actual Noto glyphs and real outline fit original route width")
			var fill_rect: Rect2 = filled.bounds; var support_rect: Rect2 = outlined.bounds
			_check(fill_rect.has_area() and support_rect.has_area() and support_rect.position.x >= -2 and support_rect.end.x <= width+2, "Packed Noto raster-cache bounds stay inside declared horizontal margins")
			fill_rect.position += offset; support_rect.position += offset
			ink.append(fill_rect); support.append(support_rect)
		_check(support[2].position.y-support[1].end.y >= .5 and ink[2].position.y-ink[1].end.y >= 2.0, "Packed fixed16px pier baseline spacing leaves distinct ink/support lines")
		_check(support[2].end.y < harbor.FOOT_PIER.position.y, "Packed qualifier support stays above physical pier deck")
		_check(harbor.WEST_PONTOON.encloses(support[3]) and harbor.EAST_PONTOON.encloses(support[4]), "Packed pontoon captions fit both unchanged deck rectangles")

func _polish_glyph_bounds(font: FontFile, text: String, size: int, outline: int) -> Dictionary:
	# Read actual font-cache alpha, not an estimated CJK box or framebuffer pixels.
	var cache_size := Vector2i(size,outline); var bounds := Rect2()
	var first: bool = true; var valid: bool = true; var cursor: float = 0.0
	for character: String in text: valid = valid and font.has_char(character.unicode_at(0))
	var line := TextLine.new(); line.add_string(text,font,size)
	for shaped: Dictionary in TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid()):
		if int(shaped.flags)&TextServer.GRAPHEME_IS_VIRTUAL: continue
		valid = valid and shaped.font_rid == font.get_rids()[0] and shaped.repeat == 1
		var glyph: int = shaped.index; font.render_glyph(0,cache_size,glyph)
		var texture_index: int = font.get_glyph_texture_idx(0,cache_size,glyph)
		if texture_index >= 0:
			var bitmap: Image = font.get_texture_image(0,cache_size,texture_index)
			var uv: Rect2 = font.get_glyph_uv_rect(0,cache_size,glyph)
			var extent: Vector2 = font.get_glyph_size(0,cache_size,glyph)
			var origin: Vector2 = Vector2(cursor,0)+shaped.offset+font.get_glyph_offset(0,cache_size,glyph)
			for y: int in range(int(uv.size.y)):
				for x: int in range(int(uv.size.x)):
					if bitmap.get_pixel(int(uv.position.x)+x,int(uv.position.y)+y).a < .05: continue
					var pixel := Rect2(origin+Vector2(x,y)*extent/uv.size,extent/uv.size)
					bounds = pixel if first else bounds.merge(pixel); first = false
		cursor += float(shaped.advance)
	return {"bounds":bounds,"valid":valid}

# Schema15 is a separate partition. Inputs/positions/history below are prepared;
# shipped rules, scene callbacks, disk writes and controller tokens are real.
func _capstone_prerequisites() -> bool:
	var previous: int = failures; var first: int = checks
	for module: String in ["volume_one_capstone_rules", "volume_one_capstone_combat_data", "volume_one_capstone_story", "volume_one_capstone_navigation", "painted_battle_liang"]:
		_check(ResourceLoader.exists("res://scripts/"+module+".gd"), "Capstone module required before scene/save: "+module)
	for asset: String in ["painted_liang_combat_v4", "painted_liang_portrait_v1"]:
		_check(ResourceLoader.exists("res://assets/generated/characters/"+asset+".png"), "Separate original Liang resource required before scene/save: "+asset)
	for file: String in ["combat-v4-review.json", "combat-v4-measurements.json", "portrait-v1-review.json"]:
		_check(FileAccess.file_exists("res://assets/generated/characters/liang_provenance/"+file), "Actual pack retains accepted project-asset provenance: "+file)
	if failures != previous: return false
	var rules = load("res://scripts/volume_one_capstone_rules.gd")
	var story = load("res://scripts/volume_one_capstone_story.gd")
	_check(rules.TITLE == "第一卷终章·截令归灯" and rules.INTRODUCED_VERSION == 15 and rules.MAX_SUPPORTED_VERSION == 16, "Actual capstone title and since15/current16 introduction/support are required")
	_check(rules.FIELDS == CAPSTONE_FIELDS and rules.REWARD_XP == 160 and rules.REWARD_COINS == 80 and rules.ORDER_IDS.size() == 4, "Actual capstone bounded durable bundle/rewards/order catalog")
	_check(story.PAGES.has("A0") and story.PAGES.has("H3") and story.SITES.size() == 6, "Actual six-stop authored scene must include beginning and completed homecoming")
	_check(not ProjectSettings.get_setting("hero/features/web_save_transfer_enabled",false), "Schema15 package transfer remains default-off")
	_capstone_prerequisite_checks = checks-first
	return failures == previous

func _capstone_legacy_prerequisite(rehearsal: bool) -> bool:
	var previous: int = failures; var first: int = checks
	var path: String = OS.get_environment("HERO_AUDIT_SCHEMA14_READER")
	_schema14_save = OS.get_environment("HERO_AUDIT_SCHEMA14_SAVE")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema14-reader="): path = argument.trim_prefix("--schema14-reader=")
		if argument.begins_with("--schema14-save="): _schema14_save = argument.trim_prefix("--schema14-save=")
	if rehearsal:
		if path.is_empty(): path = ProjectSettings.globalize_path("res://tests/fixtures/v028_game_state.gd.txt")
		if _schema14_save.is_empty(): _schema14_save = ProjectSettings.globalize_path("res://tests/fixtures/capstone/schema_14_default.json")
	_check(path.is_absolute_path() and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == SCHEMA14_READER_SHA256, "Exact genuine Web28 schema14 reader is externally byte-pinned")
	_check(_schema14_save.is_absolute_path() and FileAccess.file_exists(_schema14_save) and FileAccess.get_sha256(_schema14_save) == SCHEMA14_SAVE_SHA256, "Actual historical Web28 writer bytes, never modern version relabeling")
	var provenance: String = _schema14_save.get_base_dir().path_join("schema_14_provenance.json")
	_check(FileAccess.file_exists(provenance) and FileAccess.get_sha256(provenance) == SCHEMA14_PROVENANCE_SHA256, "Authentic14 producer provenance is pinned separately from1–13")
	if failures != previous: return false
	var script := GDScript.new(); script.source_code = FileAccess.get_file_as_string(path).replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Authentic old14 reader compiles with current dependencies, only global registration removed")
	if error != OK: return false
	schema14_reader = script.new()
	_check(schema14_reader.SAVE_VERSION == 14 and not schema14_reader.to_dict().has("capstone_stage"), "Frozen reader retains actual14 gate and pre-capstone field layout")
	_capstone_prerequisite_checks += checks-first
	return failures == previous

func _test_capstone_pack() -> void:
	var first: int = checks
	game.set_process(false); game.world.set_process(false)
	_check(game.capstone_story.get_script() == load("res://scripts/volume_one_capstone_story.gd"), "Main owns actual packaged capstone story")
	_capstone_migrations()
	await _capstone_art()
	await _capstone_route("pause_batch", "hold_for_inspection", true)
	await _capstone_route("cancel_proven", "return_to_owner", false)
	await _capstone_failures()
	await _capstone_combat_boundaries()
	_check(not game.web_save_transfer_enabled and _unified_facts_ok, "Capstone keeps browser transfer default-off and observed unified token/basic invariants")
	print("Schema15 capstone chapter exact-runtime coverage: %d checks; actual packed six-stop story/site/generation/save guards; genuine producers1,9–14 versus authored2–8; actual13 reader rejects true14 and actual14 reader rejects true15 with current dependencies, not full-old-runtime; modern required13/14/15 fields; fixed620 solo authorizer and real accepted terminal; finite four orders; both160XP80coins once; old identity/cargo/endings; original imported Liang/provenance/read-only draw/portrait; prepared state/input only, no earned-route, browser or pixel claim" % (checks-first+_capstone_prerequisite_checks))

func _capstone_migrations() -> void:
	var model = load("res://scripts/game_state.gd"); var probe = model.new()
	probe.coins = 925; probe.battle_active = true; probe.skill_cooldown = 3
	var unchanged: Dictionary = _receipt_variables(probe)
	var genuine14: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_schema14_save))
	var genuine15: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_schema15_save))
	_check(genuine14.version == 14 and probe._same_save_value(genuine14.player,schema14_reader.to_dict()), "Pinned true14 fixture equals actual old producer default serialization")
	_check(schema14_reader.load_game(_schema14_save) == OK, "Real14 source reader accepts genuine14 control without claiming full historical dependencies")
	for version: int in range(1,15):
		var path: String = _schema14_save if version == 14 else _legacy_save_fixtures.path_join("schema_%02d_default.json" % version)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var result: Dictionary = probe.inspect_save_bytes(bytes)
		_check(result.ok and result.version == version and result.state != probe, "Capstone current inspector accepts pinned old bytes: "+str(version))
		_check(_receipt_variables(probe) == unchanged and FileAccess.get_file_as_bytes(path) == bytes, "Capstone old inspection never changes live fields or original disk")
		if not result.ok: continue
		for key: String in CAPSTONE_FIELDS: _check(result.state.to_dict()[key] == model.new().to_dict()[key], "Old1–14 absent capstone fields remain neutral: %d/%s" % [version,key])
		_check(result.state.hp == 100 and result.state.qi == 2 and result.state.medicine == 3 and result.state.coins == 24 and result.state.party_roster == ["hero"], "Capstone migration grants no heal/reward/companion")
		var data: Dictionary = JSON.parse_string(bytes.get_string_from_utf8()).player
		for mask: int in range(1,7):
			var partial: Dictionary = data.duplicate(true)
			for index: int in range(3):
				if mask & (1 << index): partial[CAPSTONE_FIELDS[index]] = model.new().to_dict()[CAPSTONE_FIELDS[index]]
			_check(not probe.inspect_save_bytes(JSON.stringify({"version":version,"player":partial}).to_utf8_buffer()).ok, "Partial legacy capstone bundle fails closed: %d/%d" % [version,mask])
		var saved: String = "user://capstone-migrated-%d.json" % version
		_check(result.state.save_game(saved) == OK and JSON.parse_string(FileAccess.get_file_as_string(saved)).version == 16 and FileAccess.get_file_as_bytes(path) == bytes, "Only explicit save writes actual16; old source never rewritten")
	for version: int in [13,14,15]:
		var canonical: Dictionary = schema13_reader.to_dict() if version == 13 else (genuine14.player if version == 14 else genuine15.player)
		_check(probe.inspect_save_bytes(JSON.stringify({"version":version,"player":canonical}).to_utf8_buffer()).ok, "Complete genuine modern layout accepted: "+str(version))
		for key: String in canonical:
			var missing: Dictionary = canonical.duplicate(true); missing.erase(key)
			_check(not probe.inspect_save_bytes(JSON.stringify({"version":version,"player":missing}).to_utf8_buffer()).ok, "Every modern required field fails closed: %d/%s" % [version,key])
	var path: String = "user://capstone-true15-old14-reject.json"
	_check(schema15_reader.save_game(path) == OK and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 15 and FileAccess.get_sha256(path) == SCHEMA15_SAVE_SHA256, "Frozen actual15 writer produces authentic15 rejection bytes, never relabeled current16")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	schema14_reader.coins = 931; schema14_reader.battle_active = true; schema14_reader.skill_cooldown = 4
	var old: Dictionary = _receipt_variables(schema14_reader)
	_check(schema14_reader.load_game(path) == ERR_FILE_UNRECOGNIZED and _receipt_variables(schema14_reader) == old and FileAccess.get_file_as_bytes(path) == bytes and not FileAccess.file_exists(path+".tmp"), "Byte-pinned true14 reader rejects actual15 nondestructively before persistent/transient mutation")
	var directory: String = _transfer_directory("capstone-schema15")
	var store = load("res://scripts/local_save_slots.gd").new(directory)
	var helper = load("res://scripts/local_save_transfer.gd").new(directory)
	var preview: Dictionary = helper.preview_import(bytes,1)
	_check(preview.ok and preview.version == 15 and helper.commit_import(preview.token).ok and FileAccess.get_file_as_bytes(store.path_for(1)) == bytes, "Actual packed transfer accepts15 into empty manual slot preserving bytes")
	_check(not helper.preview_import(bytes,1).ok and helper.export_slot(1).bytes == bytes, "Current15 occupied slot remains protected and raw export is exact")

class CapstoneDrawProbe extends Control:
	var art
	var pose: Dictionary = {}
	var draws: int = 0
	var draw_ready: bool = false
	func _draw() -> void:
		draw_ready = art.draw(self, Vector2(380,480),pose,1.0,204.0)
		draws += 1

func _capstone_image_hash(texture: Texture2D) -> String:
	var image: Image = texture.get_image(); image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data())
	return hash.finish().hex_encode()

func _capstone_art() -> void:
	var art = load("res://scripts/painted_battle_liang.gd"); var portraits = load("res://scripts/character_portraits.gd")
	var state: Dictionary = _receipt_variables(game.state); var disk: PackedByteArray = _receipt_bytes()
	var provenance: Dictionary = {"combat-v4-review.json":"a1041d94a31df1a21542f766d7698e54d1bf797f98212890e6e48e47b767660c", "combat-v4-measurements.json":"c449ffee9ce988bca9121e2ea0e36b08b9e356fae28a0bca1b2df482f2e51555", "portrait-v1-review.json":"21cba51f3aa572a13dcae5e5add7a3be48ecaf2f7c1bc9dcf594be228fe0f8e9"}
	for file: String in provenance:
		_check(FileAccess.get_sha256("res://assets/generated/characters/liang_provenance/"+file) == provenance[file], "Actual packaged original asset provenance bytes pinned: "+file)
	var measurement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/characters/liang_provenance/combat-v4-measurements.json"))
	_check(measurement.sha256 == "4812052ca14b016e43818713eaefe3a15ba3baa79fc421a8d40fc1e6774b5f33", "Packaged measurement binds approved original combat source hash")
	_check(_capstone_image_hash(art.texture_for("idle").atlas) == "4258a20d42cf52ca009f5f75541d47e75d45273d641273be46ea23c2724af2f0", "Actual imported combat RGBA pixels pinned independently of source PNG")
	var portrait = portraits.texture_for("liang_zhen")
	_check(portrait is AtlasTexture and portrait.region == Rect2(0,0,1254,1254) and portrait.filter_clip and portrait.atlas != art.texture_for("idle").atlas, "Separate full original portrait is cached and never reuses battle crop")
	_check(_capstone_image_hash(portrait.atlas) == "eff3709294bc781bf9d43b01efe61243e167cfc53fc9ccb9783db57ca239eda3", "Actual imported portrait RGBA pixels pinned independently of source PNG")
	var probe := CapstoneDrawProbe.new(); probe.art = art; probe.size = Vector2(800,600); root.add_child(probe)
	var hashes: Dictionary = {}
	for key: String in art.POSES:
		var texture = art.texture_for(key); var measured: Dictionary = measurement.poses[key]
		var region: Array = measured.source_region; var anchor: Array = measured.foot_anchor
		_check(texture != null and texture.atlas.get_size() == Vector2(1254,1254) and texture.region == Rect2(region[0],region[1],region[2],region[3]) and texture.filter_clip, "Actual Liang measured separate action crop: "+key)
		var digest: String = _capstone_image_hash(texture)
		_check(not hashes.has(digest), "Actual six Liang pose pixels are distinct: "+key); hashes[digest] = true
		_check(art.FOOT_ANCHORS[key] == Vector2(anchor[0],anchor[1]) and art.drawing_rect(Vector2(380,480),204,key).encloses(art.opaque_rect(Vector2(380,480),204,key)), "Measured Liang original crop/feet enclose silhouette: "+key)
		var map: Dictionary = {"idle":{},"windup":{"windup":1.0},"strike":{"strike":1.0},"guard":{"guard":1.0},"hurt":{"recoil":1.0},"kneel":{"defeat":1.0}}
		probe.pose = map[key]; var before: int = probe.draws; probe.queue_redraw(); await process_frame; await process_frame
		_check(probe.draws > before and probe.draw_ready and art.pose_for(probe.pose) == key, "Actual read-only CanvasItem draw executed approved Liang pose: "+key)
	for pixels: float in [96,160,224]:
		var node = portraits.attach(probe,"liang_zhen",Rect2(0,0,pixels,pixels))
		_check(node != null and node.texture == portrait and node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Actual portrait attachment ready at original intended size: "+str(pixels))
	_check(portraits.id_for_title("梁缜·签令主事") == "liang_zhen" and portraits.id_for_title("韩铮").is_empty() and art.texture_for("walk") == null, "Original portrait maps named authorizer only; no invented walk cycle")
	probe.queue_free(); await process_frame
	_check(_receipt_variables(game.state) == state and _receipt_bytes() == disk, "Real Liang resource/Canvas/portrait checks are read-only in memory and on disk")

func _capstone_prepare(plan: String = "hold_for_inspection", count: int = 1, stage: int = 0) -> void:
	_consignee_prepare("short_ferries" if plan == "hold_for_inspection" else "open_scale",0,count)
	var s = game.state
	s.consignee_stage = 5; s.consignee_observations.assign(s.Consignee.OBSERVATIONS); s.consignee_draft = plan; s.consignee_ending = plan
	s.consignee_cargo_location = "public_scale" if plan == "hold_for_inspection" else "grain_boat"
	s.capstone_stage = stage; s.capstone_draft = ""; s.capstone_ending = ""
	if plan == "return_to_owner": s.ending = "秉公"; s.chapter_two_ending = "open_records"
	s.heal_rest(); game._sync_world_state(); game._refresh()
	_check(s._stage_save_data(s.to_dict(),16).ok and s.save_game() == OK, "Prepared completed old history is canonical16, without claiming earned predecessor gameplay")

func _capstone_history() -> Dictionary:
	var data: Dictionary = game.state.to_dict(); var result: Dictionary = {}
	for key: String in ["player_name","gender","active_companion","quest_stage","ending","side_stage","side_choice","side_clues","side_found","side_reward_claimed","chapter_two_stage","chapter_two_ending","archive_clues","seal_sequence","bridge_repaired","mist_stage","mist_approach","mist_ending","mist_gauges","heting_stage","heting_bridge","heting_delivered","heting_cargo","heting_draft","heting_ending","receipt_stage","consignee_stage","consignee_observations","consignee_contributions","consignee_draft","consignee_cargo_location","consignee_ending","party_roster","companion_unlocked","tangqi_unlocked","qin_unlocked"]:
		if data.has(key): result[key] = data[key]
	return result

func _capstone_go(site: String) -> void:
	if game.active_modal: game._close_modal()
	var map: String = game.capstone_story.SITES[site]
	game.state.map_id = map; game._sync_world_state(); game.world.change_map(map,Vector2(520,440))
	_check(game.world.interactables.has(site), "Actual physical capstone site exists: "+site)
	game.world.teleport(game.world.interactables[site].pos); game.state.position = game.world.player_pos; game._refresh(); game._process(0)
	_check(game.state.save_game() == OK, "Prepared site position checkpoint in isolated profile: "+site)

func _capstone_open(site: String) -> void:
	_capstone_go(site)
	var before: Dictionary = game.state.to_dict(); var disk: PackedByteArray = _receipt_bytes()
	await _key(KEY_E)
	_check(game.active_modal and game.state.to_dict() == before and _receipt_bytes() == disk and not game.modal_autosave_on_close, "Actual E opens capstone reading without mutation/save: "+site)

func _capstone_callback(fragment: String) -> Callable:
	var buttons: Array = []
	_capstone_buttons(game.overlay,buttons)
	for index: int in buttons.size():
		if String(buttons[index].text).contains(fragment): return game.modal_actions[index]
	_check(false,"Actual capstone callback missing: "+fragment)
	return func(): pass

func _capstone_buttons(node: Node, buttons: Array) -> void:
	if node is Button and node.name.begins_with("DialogueChoice"): buttons.append(node)
	for child: Node in node.get_children(): _capstone_buttons(child,buttons)

func _capstone_press(fragment: String) -> void:
	var buttons: Array = []; _capstone_buttons(game.overlay,buttons)
	_check(buttons.size() <= 5 and not buttons.is_empty(), "Actual capstone page has one-to-five visible choices")
	for button: Button in buttons:
		if button.text.contains(fragment):
			_check(button.visible and not button.disabled, "Actual capstone choice is available: "+fragment)
			button.pressed.emit(); return
	_check(false,"Actual capstone choice missing: "+fragment+" in "+str(buttons.map(func(button):return button.text)))

func _capstone_checkpoint(label: String) -> void:
	var s = game.state; var before: Dictionary = s.to_dict(); var disk: PackedByteArray = _receipt_bytes()
	_check(_receipt_document().version == 16 and s._same_save_value(_receipt_document().player,before) and not disk.get_string_from_utf8().contains("capstone_provenance"), "Actual current16 checkpoint has full durable fields, no terminal provenance: "+label)
	var probe = load("res://scripts/game_state.gd").new()
	_check(probe.load_game() == OK and probe.to_dict() == before and _receipt_bytes() == disk, "Detached actual reload preserves exact current16 progress/resources: "+label)
	var goal: Dictionary = s.Capstone.goal(s)
	var expected_sites: Array = ["heting_dispatch","chapter_host","chapter_clerk","chapter_archive","capstone_order_desk","capstone_order_desk","elder"]
	_check((goal.get("site_id","") == expected_sites[s.capstone_stage] and goal.get("map_id","") == game.capstone_story.SITES[expected_sites[s.capstone_stage]]) if s.capstone_stage < 7 else goal.is_empty(), "Actual stage goal matches independent six-stop sequence: "+label)
	game._sync_world_state(); game._refresh()
	_check(game.world.capstone_goal == goal and game.world.capstone_orders == s.Capstone.order_rows(s), "Actual world receives shared goal/finite order rows: "+label)
	if s.capstone_stage < 7: _check(game.quest_label.text == s.Capstone.TITLE and game.hint_label.text.contains(goal.objective), "Actual capstone scene HUD title and shared goal: "+label)
	else: _check(goal.is_empty() and game.quest_label.text != s.Capstone.TITLE, "Completed capstone releases ordinary goal ownership")
	game._show_map(); var chart = game.overlay.find_child("RegionChart",true,false)
	_check(chart != null and chart.current_target == game.world._quest_target_id() and not game.modal_autosave_on_close, "Actual map shares exact world navigation target without autosave")
	game._close_modal(); game._show_journal()
	_journal_legacy_history()
	_check(_gather_text(game.overlay).contains(s.Capstone.TITLE) and not game.modal_autosave_on_close, "Actual journal includes chapter record and remains read-only")
	game._close_modal()
	_check(s.to_dict() == before and _receipt_bytes() == disk, "Repeated real map/journal views preserve all fields and disk")

func _capstone_accept(fragment: String, stage: int, fail_save: bool) -> void:
	var disk: PackedByteArray = _receipt_bytes(); var stale: Callable = _capstone_callback(fragment)
	var blocked: String = _receipt_block_save() if fail_save else ""
	_capstone_press(fragment)
	_check(game.state.capstone_stage == stage, "Actual guarded capstone acceptance reaches stage: "+str(stage))
	var accepted: Dictionary = game.state.to_dict(); stale.call()
	_check(game.state.to_dict() == accepted, "Stale accepted capstone callback cannot replay mutation")
	if fail_save:
		_check(game.save_warning and _receipt_bytes() == disk, "Failed actual save retains accepted capstone memory and original disk")
		_capstone_press("重试保存")
		_check(game.state.to_dict() == accepted and _receipt_bytes() == disk and game.save_warning, "Repeated failed retry serializes only; no replay")
		_receipt_unblock_save(blocked); _capstone_press("重试保存")
		_check(not game.save_warning and game.state.to_dict() == accepted, "Recovered real retry persists exact already accepted capstone state")
	_capstone_checkpoint("stage"+str(stage))

func _capstone_battle_open():
	await _capstone_open("chapter_archive")
	_check(_gather_text(game.overlay).contains("梁缜") and _gather_text(game.overlay).contains("未发"), "Actual named-authorizer scene distinguishes responsibility from unacquired book")
	var portrait = game.overlay.find_child("Portrait_liang_zhen",true,false)
	_check(portrait is TextureRect and portrait.texture == load("res://scripts/character_portraits.gd").texture_for("liang_zhen") and portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Actual named Liang dialogue attaches separate approved portrait without intercepting choices")
	_capstone_press("查看应战准备")
	_check(game.capstone_story.battle_entry_ready() and _gather_text(game.overlay).contains("620"), "Actual explicit ready page discloses fixed620 endurance")
	_capstone_press("保存后阻止交发")
	var panel = _party_panel(); _unified_freeze(panel)
	_check(panel != null and panel.encounter == "capstone_authorizer" and game.current_screen == "party_battle", "Actual site/generation-guarded start enters shared twelfth controller")
	if panel != null:
		var snapshot: Dictionary = game.state.party_battle_snapshot()
		_check(snapshot.enemies.size() == 1 and snapshot.enemies[0].id == "liang_zhen" and snapshot.enemies[0].max_hp == 620 and snapshot.enemies[0].hp == 620, "Exactly one original authorizer, fixed620 independent of roster")
		_check(panel.art.backdrop_style == "archive" and panel.art.actor_order().count("liang_zhen") == 1 and panel.unit_plates.has("liang_zhen"), "Actual battle uses archive scene and one original Liang silhouette/plate")
	return panel

func _capstone_fight(panel, outcome: String = "win") -> Dictionary:
	var terminal: Dictionary = {}; var hp: int = 620; var facts: bool = true; var tokens: Dictionary = {}; var basics: Dictionary = {}
	for step: int in range(600):
		terminal = _unified_begin(panel,outcome == "win")
		if terminal.is_empty(): break
		facts = facts and not tokens.has(terminal.token); tokens[terminal.token] = true
		var enemy: Dictionary = terminal.after.enemies[0]
		facts = facts and terminal.after.enemies.size() == 1 and enemy.id == "liang_zhen" and enemy.max_hp == 620 and enemy.hp <= hp; hp = enemy.hp
		if terminal.action_id == "attack":
			var key: String = "%d/%s" % [terminal.before.round,terminal.source_id]
			facts = facts and not basics.has(key) and _party_actor(terminal.before,terminal.source_id).hp > 0; basics[key] = true
		facts = facts and not game.state.finish_party_presentation(terminal.epoch,terminal.token-1).accepted
		if not terminal.after.active: break
		panel.art._process(panel.art.get_presentation_duration()+.1)
	_check(not terminal.is_empty() and not terminal.after.active and terminal.after.outcome == outcome, "Actual automatic capstone transactions reach real pending terminal: "+outcome)
	_check(facts and not basics.is_empty(), "Actual capstone tokens/once-per-living-actor/no-heal/fixed620 invariant")
	return terminal

func _capstone_route(plan: String, old_plan: String, fail_save: bool) -> void:
	_capstone_prepare(old_plan)
	var s = game.state; var history: Dictionary = _capstone_history(); var xp: int = _receipt_xp(); var coins: int = s.coins
	_check(s.party_roster == ["hero"] and not s.companion_unlocked and not s.tangqi_unlocked and not s.qin_unlocked, "Both actual capstone scene routes permit never-recruited solo")
	await _capstone_open("heting_dispatch"); _capstone_accept("接下查册引介",1,fail_save)
	await _capstone_open("chapter_host"); var before: Dictionary = s.to_dict()
	_capstone_press("展开原信"); _capstone_press("听他说明作者"); _capstone_press("这封信要我做到哪里")
	_check(s.to_dict() == before and _gather_text(game.overlay).contains("原信"), "Original letter/draft/authorship reading is unpaid and mutation-free")
	_capstone_accept("收回原信",2,fail_save)
	await _capstone_open("chapter_clerk")
	_capstone_press("继续核两次鹤汀授权"); _capstone_press("核看经办与分存"); _capstone_press("自己核清")
	before = s.to_dict(); _capstone_press("先赢过他")
	_check(s.to_dict() == before, "Actual wrong responsibility answer cannot make combat proof of guilt")
	_capstone_press("重新判断"); _capstone_accept("梁缜须对",3,fail_save)
	var panel = await _capstone_battle_open()
	if panel == null: return
	var terminal: Dictionary = _capstone_fight(panel)
	if terminal.is_empty(): return
	_check(s.capstone_stage == 3 and s.coins == coins and _receipt_xp() == xp and s.save_game() == ERR_BUSY, "Pending actual win gives no book/reward/save before presentation")
	_check(s._valid_capstone_terminal(s.party_session.snapshot()), "Only actual terminal session/entry/identity/token passes acceptance gate")
	for mutation: String in ["epoch","token","enemy","cap","provenance","active","outcome"]:
		var forged: Dictionary = s.party_session.snapshot().duplicate(true)
		match mutation:
			"epoch": forged.epoch += 1
			"token": forged.pending_token += 1
			"enemy": forged.enemies[0].id = "archive_boss"
			"cap": forged.enemies[0].max_hp = 621
			"provenance": forged.capstone_provenance = {}
			"active": forged.active = true
			"outcome": forged.outcome = "flee"
		_check(not s._valid_capstone_terminal(forged), "Actual terminal validator rejects forged snapshot: "+mutation)
	var disk: PackedByteArray = _receipt_bytes(); var blocked: String = _receipt_block_save() if fail_save else ""
	_party_finish(panel)
	_check(s.capstone_stage == 4 and s.capstone_draft.is_empty() and s.capstone_ending.is_empty() and s.coins == coins and _receipt_xp() == xp and s.party_settlement.outcome == "win", "Actual accepted victory only obtains book, no classification/disposition/reward")
	before = s.to_dict(); panel._finished()
	_check(s.to_dict() == before and not s.finish_party_presentation(terminal.epoch,terminal.token).accepted, "Duplicate terminal presentation cannot repeat capstone settlement")
	if fail_save:
		_check(game.save_warning and _receipt_bytes() == disk, "Failed accepted victory save leaves exact old disk and genuine stage4 memory")
		_capstone_press("重试保存"); _check(s.to_dict() == before and _receipt_bytes() == disk, "Failed victory retry never resettles")
		_receipt_unblock_save(blocked); _capstone_press("重试保存")
	_capstone_checkpoint("obtained unclassified book")
	for row: Dictionary in s.Capstone.order_rows(s): _check(row.evidence == "not_yet_classified" and row.disposition == "pending", "Newly obtained four-order book is unclassified and entirely pending")
	await _capstone_open("capstone_order_desk"); _capstone_press("自行核定四号")
	before = s.to_dict(); _capstone_press("同册四号都算")
	_check(s.to_dict() == before, "Actual wrong four-order classification never progresses")
	_capstone_press("重新分类"); _capstone_accept("001、002证伪",5,fail_save)
	await _capstone_open("capstone_order_desk"); _capstone_press("商议处置草案"); _capstone_press("拟作整班暂缓"); _capstone_press("查看最后确认")
	var stale: Callable = _capstone_callback("确认执行")
	_capstone_press("返回核对"); _capstone_press("更改草案"); _capstone_press("拟作逐号撤销"); _capstone_press("更改草案"); _capstone_press("拟作整班暂缓"); _capstone_press("查看最后确认")
	before = s.to_dict(); stale.call(); _check(s.to_dict() == before and s.capstone_stage == 5, "A-to-B-to-A draft cannot revive old modal confirmation")
	_capstone_press("返回核对"); _capstone_press("撤下草案")
	_check(s.capstone_draft.is_empty() and s.capstone_stage == 5, "Actual clearing retains classification and does not dispatch")
	_capstone_press("重新商议草案"); _capstone_press("拟作整班暂缓" if plan == "pause_batch" else "拟作逐号撤销"); _capstone_press("查看最后确认")
	before = s.to_dict(); _capstone_press("先不确认"); await process_frame
	_check(s.to_dict() == before and s.capstone_ending.is_empty(), "Canceled actual confirmation never dispatches while waiting")
	for row: Dictionary in s.Capstone.order_rows(s): _check(row.disposition == "pending", "Draft/cancel preserves each finite order as pending")
	await _capstone_open("capstone_order_desk"); _capstone_press("查看当前草案"); _capstone_press("查看最后确认"); _capstone_accept("确认执行",6,fail_save)
	_check(s.capstone_ending == plan and s.coins == coins and _receipt_xp() == xp, "Only desk locks selected plan; no final reward before elder")
	var rows: Array = s.Capstone.order_rows(s)
	_check(rows.size() == 4, "Exactly four finite pending-batch orders, no invented cargo")
	for index: int in range(4):
		_check(rows[index].id == "capstone_pending_%03d" % (index+1) and rows[index].batch_id == s.Capstone.BATCH and rows[index].evidence == ("proven_false" if index<2 else "unverified") and rows[index].disposition == ("cancelled" if index<2 else ("held" if plan == "pause_batch" else "continuing")), "Actual final same-batch order keeps exact classification/disposition: "+str(index))
	await _capstone_open("elder"); _capstone_press("先看回条"); _capstone_press("回到灯下")
	var party_resources: Dictionary = s.party_resources.duplicate(true)
	_capstone_accept("交回回条",7,fail_save)
	_check(_receipt_xp() == xp+160 and s.coins == coins+80 and s.party_resources == party_resources, "Both accepted elder endings pay160XP80coins once, no companion recovery")
	await _capstone_open("elder"); _capstone_press("继续行走")
	_check(_receipt_xp() == xp+160 and s.coins == coins+80 and _capstone_history() == history and s.Capstone.goal(s).is_empty(), "Repeat elder preserves all old identity/endings/cargo/roster and never pays again")
	_consignee_backup("capstone-"+plan)

func _capstone_failures() -> void:
	for reason: String in ["distance","state_map","generation","closed","quit","state_identity"]:
		_capstone_prepare(); await _capstone_open("heting_dispatch")
		var s = game.state; var stale: Callable = _capstone_callback("接下查册引介"); var disk: PackedByteArray = _receipt_bytes()
		match reason:
			"distance": game.world.teleport(game.world.player_pos+Vector2(75,0))
			"state_map": s.map_id = "mistwood"
			"generation": game.modal_generation += 1
			"closed": game._close_modal()
			"quit": game.quit_pending = true
			"state_identity":
				var replacement = load("res://scripts/game_state.gd").new(); _check(replacement.load_game() == OK,"Replacement identity loads genuine checkpoint"); game.state = replacement
		var before: Dictionary = game.state.to_dict(); stale.call()
		_check(game.state.to_dict() == before and _receipt_bytes() == disk, "Actual stale capstone scene callback rechecks live boundary: "+reason)
		game.quit_pending = false; game.state = s
	_capstone_prepare("hold_for_inspection",1,3)
	await _capstone_open("chapter_archive"); _capstone_press("查看应战准备")
	var before: Dictionary = game.state.to_dict(); var disk: PackedByteArray = _receipt_bytes(); var blocked: String = _receipt_block_save()
	_capstone_press("保存后阻止交发")
	_check(not game.state.battle_active and game.state.to_dict() == before and _receipt_bytes() == disk and game.save_warning, "Actual failed capstone presave blocks combat and all resource changes")
	_receipt_unblock_save(blocked); _capstone_press("重试保存")
	_check(not game.state.battle_active and not game.save_warning and game.capstone_story.battle_entry_ready(), "Actual recovered presave retry only restores ready page, never auto-starts combat")

func _capstone_combat_boundaries() -> void:
	for count: int in [1,2,3,4]:
		_capstone_prepare("hold_for_inspection",count,3)
		var s = game.state; var history: Dictionary = _capstone_history(); var panel = await _capstone_battle_open()
		if panel == null: return
		var initial: Dictionary = s.party_battle_snapshot(); var disk: PackedByteArray = _receipt_bytes()
		_check(initial.actors.size() == count and panel.commands.groups.size() == count, "Actual capstone roster has exactly occupied1–4 groups")
		for actor: Dictionary in initial.actors: _check(panel.commands._slots(actor).size() == 3, "Every real capstone actor retains three fixed category slots")
		var tx: Dictionary = _unified_begin(panel,false); _party_finish(panel)
		_check(not tx.is_empty() and tx.action_id == "attack" and s.save_game() == ERR_BUSY and _receipt_bytes() == disk, "No-input actual capstone basic keeps active-save checkpoint isolated")
		var current: Dictionary = s.party_battle_snapshot(); var xp: int = _receipt_xp(); var coins: int = s.coins
		_unified_leave()
		_check(s.capstone_stage == 3 and s.party_settlement.outcome == "flee" and _capstone_history() == history and s.coins == coins and _receipt_xp() == xp, "Real capstone flee keeps established responsibility/book absent/old history/no payment")
		_check(s.hp == current.actors[0].hp and s.qi == current.actors[0].qi and s.medicine == current.medicine, "Real capstone flee preserves actually consumed resources")
	_capstone_prepare("return_to_owner",1,3); game.state.hp = 1; game.state.qi = 0; game.state.medicine = 0
	var history: Dictionary = _capstone_history(); var coins: int = game.state.coins; var xp: int = _receipt_xp()
	var panel = await _capstone_battle_open()
	if panel == null: return
	var terminal: Dictionary = _capstone_fight(panel,"defeat")
	if terminal.is_empty(): return
	_party_finish(panel)
	_check(game.state.party_settlement.outcome == "defeat" and game.state.capstone_stage == 3 and _capstone_history() == history and game.state.coins == coins-mini(8,coins) and _receipt_xp() == xp, "Real capstone defeat retains evidence/old history, bounded8coin fee once, no book/reward")
	_check(game.state.map_id == "frostbridge" and game.state.hp == game.state.max_hp and game.state.medicine == 0, "Actual capstone defeat applies documented safe recovery without medicine refund")

# Schema16 fitting partition. This external driver uses the actual shipped Main,
# State, fitting controller and PartyUI. Historical source has current packed
# dependencies; complete-old15 PCK rejection is a separate process/release gate.
func _fitting_prerequisites() -> bool:
	var previous: int = failures; var first: int = checks
	for module: String in ["weapon_fitting_rules", "weapon_fitting_trial_rules", "weapon_fitting_ui"]:
		_check(ResourceLoader.exists("res://scripts/"+module+".gd"), "Fitting actual shipped resource precedes scene/save: "+module)
	if failures != previous: return false
	var rules = load("res://scripts/weapon_fitting_rules.gd")
	var trials = load("res://scripts/weapon_fitting_trial_rules.gd")
	_check(rules.INTRODUCED_VERSION == 16 and rules.MAX_SUPPORTED_VERSION == 16 and rules.IDS == ["plain","edge","guard"], "Fitting has exactly three catalog choices and since16 semantics")
	_check(trials.PROFILES == ["ordinary","pressure"] and trials.ENCOUNTER_ID == "courtyard_practice", "Two whitelisted profiles retain original no-reward identity")
	_check(not ProjectSettings.get_setting("hero/features/web_save_transfer_enabled",false), "Fitting never enables unverified browser transfer")
	_fitting_prerequisite_checks += checks-first
	return failures == previous

func _fitting_legacy_prerequisite(rehearsal: bool) -> bool:
	var previous: int = failures; var first: int = checks
	var path: String = OS.get_environment("HERO_AUDIT_SCHEMA15_READER")
	_schema15_save = OS.get_environment("HERO_AUDIT_SCHEMA15_SAVE")
	var old_model: String = OS.get_environment("HERO_AUDIT_FITTING_LEGACY_MODEL")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema15-reader="): path = argument.trim_prefix("--schema15-reader=")
		if argument.begins_with("--schema15-save="): _schema15_save = argument.trim_prefix("--schema15-save=")
		if argument.begins_with("--fitting-legacy-model="): old_model = argument.trim_prefix("--fitting-legacy-model=")
	if rehearsal:
		if path.is_empty(): path = ProjectSettings.globalize_path("res://tests/fixtures/v029_game_state.gd.txt")
		if _schema15_save.is_empty(): _schema15_save = ProjectSettings.globalize_path("res://tests/fixtures/weapon_fitting/schema_15_default.json")
		if old_model.is_empty(): old_model = ProjectSettings.globalize_path("res://tests/fixtures/weapon_fitting/legacy_automatic.gd.txt")
	_check(path.is_absolute_path() and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == SCHEMA15_READER_SHA256, "Authentic Web29 source15 externally byte-pinned")
	_check(_schema15_save.is_absolute_path() and FileAccess.file_exists(_schema15_save) and FileAccess.get_sha256(_schema15_save) == SCHEMA15_SAVE_SHA256, "Genuine15 positive control came from actual old15 PCK, never relabeled16")
	var provenance: String = _schema15_save.get_base_dir().path_join("provenance.json")
	_check(FileAccess.file_exists(provenance) and FileAccess.get_sha256(provenance) == FITTING_PROVENANCE_SHA256, "Genuine14/15 fixture provenance is independently pinned")
	_check(old_model.is_absolute_path() and FileAccess.file_exists(old_model) and FileAccess.get_sha256(old_model) == FITTING_LEGACY_MODEL_SHA256, "Original b400 automatic combat source is external byte-pinned parity input")
	if failures != previous: return false
	var script := GDScript.new(); script.source_code = FileAccess.get_file_as_string(path).replace("class_name HeroState\n", "")
	var error: Error = script.reload()
	_check(error == OK, "Frozen15 source compiles with current packed dependencies only")
	if error != OK: return false
	schema15_reader = script.new()
	_check(schema15_reader.SAVE_VERSION == 15 and schema15_reader.to_dict().has("capstone_stage") and not schema15_reader.to_dict().has("weapon_fitting"), "Genuine15 preserves capstone layout and pre-fitting gate")
	_fitting_legacy_model = GDScript.new(); _fitting_legacy_model.source_code = FileAccess.get_file_as_string(old_model)
	_check(_fitting_legacy_model.reload() == OK, "Pinned original automatic model compiles with actual current dependencies, not full-old-runtime claim")
	_fitting_prerequisite_checks += checks-first
	return failures == previous

func _fitting_migrations() -> void:
	var model = load("res://scripts/game_state.gd"); var probe = model.new()
	probe.coins = 921; probe.battle_active = true; probe.skill_cooldown = 3
	var before: Dictionary = _receipt_variables(probe)
	for version: int in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]:
		var path: String = _schema15_save if version == 15 else (_schema14_save if version == 14 else _legacy_save_fixtures.path_join("schema_%02d_default.json" % version))
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var old: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
		var result: Dictionary = probe.inspect_save_bytes(bytes)
		_check(result.ok and result.version == version and result.state != probe, "Packed16 accepts explicit old version without dropping15: "+str(version))
		_check(_receipt_variables(probe) == before and FileAccess.get_file_as_bytes(path) == bytes, "Read-only migration retains all live variables and old original bytes")
		if not result.ok: continue
		_check(result.state.weapon_fitting == "plain" and result.state.attack == old.player.attack and result.state.defense == old.player.defense and result.state.hp == 100 and result.state.qi == 2 and result.state.medicine == 3 and result.state.coins == 24, "Absent old fitting migrates plain with no base/reward/resource change")
		if version >= 12:
			for key: String in old.player:
				_check(probe._same_save_value(result.state.to_dict()[key],old.player[key]), "Every canonical old field remains exact: %d/%s" % [version,key])
		var malformed: Dictionary = old.duplicate(true); malformed.player.weapon_fitting = "unknown"
		_check(not probe.inspect_save_bytes(JSON.stringify(malformed).to_utf8_buffer()).ok, "Present malformed fitting is never silently erased under an old header")
		malformed.player.weapon_fitting = "plain"
		_check(probe.inspect_save_bytes(JSON.stringify(malformed).to_utf8_buffer()).ok, "Complete valid present fitting follows historical present-field convention")
		malformed.player.weapon_fitting_cache = {}
		_check(not probe.inspect_save_bytes(JSON.stringify(malformed).to_utf8_buffer()).ok, "Reserved unknown fitting prefix rejects old-version smuggling")
	var canonical: Dictionary = model.new().to_dict()
	for version: int in [13,14,15,16]:
		for field: String in ["internal_unlocked"]+CONSIGNEE_FIELDS+CAPSTONE_FIELDS+["weapon_fitting"]:
			var since: int = 13 if field == "internal_unlocked" else (14 if field in CONSIGNEE_FIELDS else (15 if field in CAPSTONE_FIELDS else 16))
			if version < since: continue
			var missing: Dictionary = canonical.duplicate(true); missing.erase(field)
			_check(not probe.inspect_save_bytes(JSON.stringify({"version":version,"player":missing}).to_utf8_buffer()).ok, "Distinct since%d mandatory field under%d: %s" % [since,version,field])
	for invalid: Variant in [null,true,0,1.5,[],{},"", "PLAIN", "edge", "guard"]:
		var data: Dictionary = canonical.duplicate(true); data.weapon_fitting = invalid
		_check(not probe.inspect_save_bytes(JSON.stringify({"version":16,"player":data}).to_utf8_buffer()).ok, "Malformed or unearned schema16 fitting refuses before any mutation: "+str(invalid))
	var output: String = "user://fitting-current16-subject.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--schema16-subject="): output = argument.trim_prefix("--schema16-subject=")
	_check(not FileAccess.file_exists(output) and not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output+".tmp"), "Actual16 subject path is fresh and cannot overwrite evidence")
	if FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output): return
	_check(model.new().save_game(output) == OK and JSON.parse_string(FileAccess.get_file_as_string(output)).version == 16 and JSON.parse_string(FileAccess.get_file_as_string(output)).player.weapon_fitting == "plain", "Actual current writer creates16 subject with required fitting, never header relabeling")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(output)
	_check(schema15_reader.load_game(_schema15_save) == OK and FileAccess.get_sha256(_schema15_save) == SCHEMA15_SAVE_SHA256, "Frozen source15 accepts genuine15 positive control without modifying it")
	schema15_reader.coins = 935; schema15_reader.battle_active = true; schema15_reader.skill_cooldown = 4
	var old_live: Dictionary = _receipt_variables(schema15_reader)
	_check(schema15_reader.load_game(output) == ERR_FILE_UNRECOGNIZED and _receipt_variables(schema15_reader) == old_live and FileAccess.get_file_as_bytes(output) == bytes and not FileAccess.file_exists(output+".tmp"), "Frozen15 rejects actual16 nondestructively; source/current-dependency scope")
	var directory: String = _transfer_directory("fitting16")
	var store = load("res://scripts/local_save_slots.gd").new(directory)
	var helper = load("res://scripts/local_save_transfer.gd").new(directory)
	var modern = model.new()
	for slot: int in range(1,4):
		var preview: Dictionary = helper.preview_import(bytes,slot)
		_check(preview.ok and preview.version == 16 and helper.commit_import(preview.token).ok and helper.export_slot(slot).bytes == bytes, "Actual16 raw bytes import/export exactly to empty manual slot: "+str(slot))
		_check(store.load_slot(modern,slot) == OK and modern.weapon_fitting == "plain" and modern.to_dict() == canonical, "Actual16 slot load preserves canonical default")
		var files: Dictionary = _transfer_files(directory)
		_check(schema15_reader.load_game(store.path_for(slot)) == ERR_FILE_UNRECOGNIZED and _receipt_variables(schema15_reader) == old_live and _transfer_files(directory) == files, "Frozen15 direct reader rejects actual16 manual-path bytes without disk/live mutation")
	_transfer_write(store.path_for(1)+".bak",bytes)
	var retained_files: Dictionary = _transfer_files(directory)
	_check(schema15_reader.load_game(store.path_for(1)+".bak") == ERR_FILE_UNRECOGNIZED and _receipt_variables(schema15_reader) == old_live and _transfer_files(directory) == retained_files, "Frozen15 direct backup-path rejection preserves every manual primary/backup and live field")
	_check(_receipt_variables(probe) == before and FileAccess.get_sha256(_schema15_save) == SCHEMA15_SAVE_SHA256 and not game.web_save_transfer_enabled, "Migration and raw transfer never enable feature or change inspected live state")

func _fitting_semantic(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key not in ["epoch","token","pending_token","fitting_trial"]: result[key] = _fitting_semantic(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_fitting_semantic(entry))
		return result
	return value

func _fitting_old_plain() -> void:
	var factory = load("res://scripts/weapon_fitting_trial_rules.gd")
	for count: int in [1,4]:
		_fitting_prepare(count)
		var state_before: Dictionary = game.state.to_dict()
		var built: Dictionary = factory.build(game.state,"plain","ordinary")
		_check(built.ok, "Original plain parity uses genuine validated owned team")
		if not built.ok: continue
		var old = _fitting_legacy_model.new()
		var current = load("res://scripts/automatic_party_combat.gd").new()
		_check(old.configure(built.team,"courtyard_practice") and current.configure_fitting_practice(game.state,"plain","ordinary"), "Old ordinary and packed borrowed plain configure same detached baseline")
		_check(_fitting_semantic(old.snapshot()) == _fitting_semantic(current.snapshot()), "Exact frozen-original plain actors/enemies/intents")
		var steps: int = 0
		while old.snapshot().active and steps < 600:
			var left: Dictionary = old.advance(); var right: Dictionary = current.advance()
			_check(left.accepted and right.accepted and _fitting_semantic(left) == _fitting_semantic(right), "Complete original before/after/event transcript parity")
			if not left.accepted or not right.accepted: break
			_check(old.complete_presentation(left.token) and current.complete_presentation(right.token), "Both original/current exact accepted tokens complete")
			steps += 1
		_check(not old.snapshot().active and not current.snapshot().active and old.snapshot().outcome == current.snapshot().outcome, "Frozen-source/current-dependency ordinary comparison reaches matching terminal")
		_check(game.state.to_dict() == state_before, "Original baseline replay never mutates genuine live State")

func _fitting_prepare(count: int = 1, school: String = "听潮阁") -> void:
	# Canonical prepared route, not an earned journey claim. Main processing stays
	# enabled so the actual fitting lifecycle must suppress idle position writes.
	if game.active_modal: game.modal_autosave_on_close = false; game._close_modal()
	if count > 1:
		_party_prepare(count)
	else:
		game._new_game()
		game.state.quest_stage = 6; game.state.ending = "守望"
		game.state.choose_sect(school)
		game.state.level = 3; game.state.xp = 0
	var s = game.state
	s.map_id = "qingwei"
	game.world.change_map("qingwei",Vector2(700,733))
	game.world.teleport(game.world.interactables.courtyard_practice.pos + Vector2(-24,0))
	s.position = game.world.player_pos
	s.hp = 7; s.qi = 0; s.medicine = 0
	if s.party_resources.has("shen"): s.party_resources.shen = {"hp":0,"qi":0}
	if s.party_resources.has("tang"): s.party_resources.tang = {"hp":5,"qi":1}
	if s.party_resources.has("qin"): s.party_resources.qin = {"hp":9,"qi":0}
	_check(s._stage_save_data(s.to_dict(),16).ok, "Fitting prepared injured/zero-resource state is canonical")
	_check(s.save_game() == OK, "Fitting fixture seeds actual prior good primary")
	for slot: int in range(1,4):
		_check(game.save_slots.store.save_slot(s,slot) == OK and game.save_slots.store.save_slot(s,slot) == OK, "Fitting fixture seeds actual manual primary and backup: "+str(slot))
	s.coins += 1 # Deliberately unsaved real progress makes unintended writes observable.
	game.save_warning = false
	game.set_process(true); game.world.set_process(true)
	game._stop_audio(); game.audio_on = false; game._refresh(); game._process(0)

func _fitting_disk() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["user://hero_save.json","user://hero_slot_1.json","user://hero_slot_2.json","user://hero_slot_3.json"]:
		for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
			var name: String = path+suffix
			result[name] = {"file":FileAccess.file_exists(name),"directory":DirAccess.dir_exists_absolute(name)}
			if FileAccess.file_exists(name):
				result[name].bytes = FileAccess.get_file_as_bytes(name)
				result[name].modified = FileAccess.get_modified_time(name)
	return result

func _fitting_capture() -> Dictionary:
	return {"persistent":game.state.to_dict().duplicate(true),"state_id":game.state.get_instance_id(),"world_map":game.world.map_id,"world_position":game.world.player_pos,"files":_fitting_disk()}

func _fitting_unchanged(before: Dictionary, label: String) -> void:
	_check(game.state.get_instance_id() == before.state_id and game.state.to_dict() == before.persistent, "Whole real persistent state unchanged: "+label)
	_check(game.world.map_id == before.world_map and game.world.player_pos == before.world_position, "Actual world/map has no trial teleport: "+label)
	_check(_fitting_disk() == before.files, "All primary/manual/backup/temp bytes and observed metadata unchanged: "+label)
	_check(game.is_processing(), "Actual Main processing remains enabled: "+label)

func _fitting_panel(): return game.overlay.get_meta("weapon_fitting",null)

func _fitting_node(name: String) -> Button:
	var button = game.overlay.find_child(name,true,false)
	_check(button is Button and button.is_visible_in_tree(), "Real shipped fitting button visible: "+name)
	return button as Button

func _fitting_key(key: Key, echo: bool = false) -> void:
	var event := InputEventKey.new(); event.physical_keycode = key; event.keycode = key; event.pressed = true; event.echo = echo
	Input.parse_input_event(event); Input.flush_buffered_events()
	if _party_panel() != null: _unified_freeze(_party_panel())
	await process_frame
	event.pressed = false; event.echo = false; Input.parse_input_event(event); Input.flush_buffered_events()
	await process_frame

func _fitting_click(name: String) -> void:
	var button: Button = _fitting_node(name)
	if button == null: return
	_check(not button.disabled, "Actual fitting action enabled: "+name)
	if button.disabled: return
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = true
	root.push_input(event,true)
	await process_frame
	event.pressed = false; root.push_input(event,true)
	if _party_panel() != null: _unified_freeze(_party_panel())
	await process_frame

func _fitting_idle() -> void:
	await process_frame; await process_frame
	game._process(.016) # Explicitly retain the previously hazardous real Main path.

func _fitting_open(court: bool = false):
	if game.active_modal: game.modal_autosave_on_close = false; game._close_modal()
	await _fitting_key(KEY_E if court else KEY_B)
	_check(game.active_modal, "Actual E/B opens shipped courtyard/workshop entry")
	# Adversarial idle divergence begins immediately before real fitting entry.
	# No disabled Main process or State subclass can mask the production guard.
	game.state.position = game.world.player_pos + Vector2(-9,0)
	var before: Dictionary = _fitting_capture()
	await _fitting_key(KEY_3 if court else KEY_5)
	var panel = _fitting_panel()
	_check(panel != null and panel.get_script() == load("res://scripts/weapon_fitting_ui.gd") and panel.valid(), "Actual Main owns live shipped fitting controller")
	_check(not game.modal_autosave_on_close, "Actual fitting page explicitly suppresses close autosave")
	await _fitting_idle(); _fitting_unchanged(before,"native fitting entry and idle Main frames")
	return panel

func _fitting_replay(callback: Callable) -> void:
	# Freed controls correctly revoke their callables. Still-live stale callbacks
	# must fail their own capability checks before save/mutation.
	if callback.is_valid(): callback.call()

func _fitting_views_and_equips() -> void:
	for school: String in ["听潮阁","照野堂","问石门"]:
		_fitting_prepare(1,school)
		var panel = await _fitting_open()
		if panel == null: return
		var before: Dictionary = _fitting_capture()
		var weapon: String = game.state.equipment; var armor: String = game.state.armor
		_check(_gather_text(game.overlay).contains("当前已装配") and _gather_text(game.overlay).contains("16"), "Actual overview distinguishes installed choice and one-way writer16 notice")
		for fitting: String in ["edge","guard","plain"]:
			await _fitting_click("FittingCandidate_"+fitting)
			panel = _fitting_panel()
			var projected: Dictionary = game.state.preview_weapon_fitting(fitting)
			_check(panel != null and panel.candidate == fitting and game.state.weapon_fitting == "plain" and projected.ok, "Native candidate selection previews without equipping: "+fitting)
			_check(_gather_text(game.overlay).contains(str(projected.attack)) and _gather_text(game.overlay).contains(str(projected.defense)), "Actual visible preview shows effective projected attack/defense")
			await _fitting_idle(); _fitting_unchanged(before,"candidate preview "+school+"/"+fitting)
		_check(game.state.equipment == weapon and game.state.armor == armor, "Original sword and armor names never become generated fitting items")
		await _fitting_click("FittingAction_workshop"); await _fitting_key(KEY_ESCAPE)
		await _fitting_idle(); _fitting_unchanged(before,"return workshop then Escape with live Main")
	# Every optional choice locked before actual opening+sect, no capstone requirement.
	game._new_game(); game.set_process(true)
	await _fitting_key(KEY_B); await _fitting_key(KEY_5)
	var locked = _fitting_panel()
	_check(locked != null and game.state.weapon_fitting == "plain" and not game.state.preview_weapon_fitting("edge").ok and not game.state.preview_weapon_fitting("guard").ok, "Actual fresh-title fitting UI retains presect lock and original")
	var before: Dictionary = _fitting_capture()
	if locked != null:
		locked.choose_candidate("edge"); locked = _fitting_panel()
		locked.confirm_selection(); locked.confirm_equip(); locked.start_trial()
	_fitting_unchanged(before,"direct locked handler attempts")
	await _fitting_key(KEY_ESCAPE)
	for pair: Array in [[1,0],[3,1],[4,2]]:
		_fitting_prepare(); game.state.attack = pair[0]; game.state.defense = pair[1]
		await _fitting_open()
		var projected: Dictionary = game.state.preview_weapon_fitting("edge")
		_check(projected.ok == (pair[1] >= 2), "Actual optional edge rejects full defense cost floor")
		projected = game.state.preview_weapon_fitting("guard")
		_check(projected.ok == (pair[0] >= 4), "Actual optional guard rejects full attack cost floor")
		before = _fitting_capture()
		var floor_panel = _fitting_panel()
		if pair[1] < 2:
			floor_panel.choose_candidate("edge"); floor_panel = _fitting_panel()
			floor_panel.confirm_selection(); floor_panel.confirm_equip()
			_fitting_unchanged(before,"direct UI cannot bypass full-cost floor")
		await _fitting_key(KEY_ESCAPE)
	# Actual explicit confirmation/revert loop; a duplicate captured handler cannot save twice.
	_fitting_prepare(); await _fitting_open()
	for fitting: String in ["edge","guard","plain"]:
		await _fitting_click("FittingCandidate_"+fitting)
		await _fitting_click("FittingAction_equip")
		var panel = _fitting_panel(); var stale: Callable = Callable(panel,"confirm_equip")
		before = _fitting_capture()
		await _fitting_click("FittingAction_confirm")
		var expected: Dictionary = before.persistent.duplicate(true)
		expected.weapon_fitting = fitting; expected.position = {"x":game.world.player_pos.x,"y":game.world.player_pos.y}
		_check(game.state.weapon_fitting == fitting and game.state._same_save_value(game.state.to_dict(),expected), "Explicit UI equips/reverts only enum plus documented save-position synchronization")
		_check(_receipt_document().version == 16 and _receipt_document().player.weapon_fitting == fitting and not game.save_warning, "Explicit fitting save writes current16 real installed enum")
		_check(_fitting_node("FittingAction_equip").disabled, "Already installed candidate visibly disables redundant confirmation")
		var same = _fitting_panel(); var same_before: Dictionary = _fitting_capture()
		same.confirm_selection(); same.confirm_equip()
		_fitting_unchanged(same_before,"same-choice direct handler is a no-write no-op")
		var confirmed: Dictionary = _fitting_capture(); _fitting_replay(stale)
		await _fitting_key(KEY_ENTER,true); await _fitting_idle()
		_fitting_unchanged(confirmed,"stale duplicate confirmation and key echo")
	# Failed save keeps explicit enum, failure page is read-only, retry writes current real choice.
	await _fitting_click("FittingCandidate_edge"); await _fitting_click("FittingAction_equip")
	var old_bytes: PackedByteArray = _receipt_bytes(); var blocked: String = _receipt_block_save()
	await _fitting_click("FittingAction_confirm")
	_check(game.state.weapon_fitting == "edge" and game.save_warning and _receipt_bytes() == old_bytes, "Real filesystem failure retains explicit fitting and exact prior primary")
	before = _fitting_capture(); var failed = _fitting_panel(); var retry: Callable = Callable(failed,"retry_save")
	await _fitting_click("FittingAction_retry_save"); await _fitting_idle()
	_fitting_unchanged(before,"failed explicit-save retry leaves real state and all bytes")
	_check(_gather_text(game.overlay).contains("保存"), "Actual failed fitting page visibly discloses unsaved state")
	_receipt_unblock_save(blocked)
	await _fitting_click("FittingAction_retry_save")
	_check(not game.save_warning and _receipt_document().player.weapon_fitting == "edge" and game.state.weapon_fitting == "edge", "Recovered native retry saves current selected enum without applying projection twice")
	before = _fitting_capture(); _fitting_replay(retry); _fitting_unchanged(before,"old failed-save callback cannot repeat overwrite")
	await _fitting_key(KEY_ESCAPE)

func _fitting_guarded_actions() -> void:
	for reason: String in ["generation","state","installed","bases","candidate","closed","reload","new-journey","replacement","quit","battle","pending"]:
		_fitting_prepare(); await _fitting_open()
		await _fitting_click("FittingCandidate_edge"); await _fitting_click("FittingAction_equip")
		var panel = _fitting_panel(); var callback: Callable = Callable(panel,"confirm_equip")
		match reason:
			"generation": game.modal_generation += 1
			"state": game.state = game.state._detached_persistent_state()
			"installed": game.state.set_weapon_fitting("guard")
			"bases": game.state.attack += 1
			"candidate": panel.candidate = "guard"
			"closed": game.modal_autosave_on_close = false; game._close_modal()
			"reload": game._load()
			"new-journey": game._new_game()
			"replacement": game._show_inventory()
			"quit": game.quit_pending = true
			"battle": game.state.battle_active = true
			"pending": game.state._party_pending_token = 9981
		var before: Dictionary = _fitting_capture()
		_fitting_replay(callback)
		_fitting_unchanged(before,"stale explicit confirmation capability: "+reason)
		game.quit_pending = false; game.state.battle_active = false; game.state._party_pending_token = -1
		if game.active_modal: game.modal_autosave_on_close = false; game._close_modal()
	for reason: String in ["state-map","world-map","missing-site","nan-player","inf-site","distance85","distance85.01","quit","pending","generation","wrong-page"]:
		_fitting_prepare(); await _fitting_open(true); await _fitting_click("FittingAction_trial")
		var panel = _fitting_panel(); var site: Vector2 = game.world.interactables.courtyard_practice.pos
		match reason:
			"state-map": game.state.map_id = "sluice"
			"world-map": game.world.map_id = "sluice"
			"missing-site": game.world.interactables.erase("courtyard_practice")
			"nan-player": game.world.player_pos = Vector2(NAN,733)
			"inf-site": game.world.interactables.courtyard_practice.pos = Vector2(INF,733)
			"distance85": game.world.player_pos = site + Vector2(85,0)
			"distance85.01": game.world.player_pos = site + Vector2(85.01,0)
			"quit": game.quit_pending = true
			"pending": game.state._party_pending_token = 9971
			"generation": game.modal_generation += 1
			"wrong-page": panel.page = "preview"
		var before: Dictionary = game.state.to_dict(); var files: Dictionary = _fitting_disk(); var session = game.state.party_session
		_check(game.PartyUI.open_fitting(game,panel,"plain","ordinary") == null and game.state.party_session == session and not game.state.battle_active, "Actual shipped trial gate rejects invalid physical/capability condition: "+reason)
		_check(game.state.to_dict() == before and _fitting_disk() == files, "Failed actual trial entry preserves entire real state/save inventory")
		game.quit_pending = false; game.state._party_pending_token = -1
		# Reset only explicitly prepared adversarial site state before next fixture.
		game.world.change_map("qingwei",Vector2(700,733)); game.state.map_id = "qingwei"
		if game.active_modal: game.modal_autosave_on_close = false; game._close_modal()
	_fitting_prepare(); await _fitting_open(true); await _fitting_click("FittingAction_trial")
	game.world.player_pos = game.world.interactables.courtyard_practice.pos + Vector2(84.99,0)
	var boundary_before: Dictionary = _fitting_capture()
	await _fitting_click("FittingAction_start")
	var boundary_panel = _party_panel()
	_check(boundary_panel != null, "Actual courtyard gate permits strictly inside84.99 boundary")
	if boundary_panel != null:
		var boundary_result: Dictionary = _fitting_drive(boundary_panel,true)
		_check(not boundary_result.is_empty() and boundary_result.metrics.outcome == "flee", "Inside-boundary real trial completes through accepted retreat")
		await _fitting_idle(); _fitting_unchanged(boundary_before,"strictly inside boundary actual trial")
	await _fitting_key(KEY_ESCAPE)
	# Remote workshop is still a useful actual preview, but cannot start/teleport.
	_fitting_prepare(); game.state.map_id = "frostbridge"; game.world.change_map("frostbridge",Vector2(190,500))
	await _fitting_open(); await _fitting_click("FittingAction_trial")
	var before: Dictionary = _fitting_capture(); var panel = _fitting_panel()
	_check(_fitting_node("FittingAction_start").disabled and _gather_text(game.overlay).contains("南庭"), "Actual remote preview offers truthful court directions and disabled start")
	panel.start_trial(); await _fitting_idle(); _fitting_unchanged(before,"remote workshop trial cannot teleport")
	await _fitting_key(KEY_ESCAPE); await _fitting_key(KEY_ESCAPE)

var _fitting_observed: Dictionary = {}

func _fitting_measure(tx: Dictionary, session, expected: Dictionary) -> void:
	_check(tx.get("accepted",false), "Actual fitting controller supplies accepted transaction")
	if not tx.get("accepted",false): return
	for prior: Dictionary in tx.before.actors:
		var after: Dictionary = _party_actor(tx.after,prior.id)
		var loss: int = maxi(0,int(prior.hp)-int(after.hp))
		expected.losses[prior.id] += loss; expected.loss += loss
	expected.medicine += int(tx.before.medicine)-int(tx.after.medicine); expected.accepted += 1
	for event: Dictionary in tx.events:
		if event.type == "action" and event.get("action_id","") == "enemy:attack": expected.attacks += 1
		if event.type == "round_end": expected.rounds += 1
		if event.type in ["protect","medicine","down"]: _fitting_observed[event.type] = true
		_check(event.type != "proficiency", "Actual borrowed transaction never awards proficiency")
	var metrics: Dictionary = session.fitting_trial_snapshot().metrics
	_check(metrics.actual_hp_lost_by_actor == expected.losses and metrics.total_actual_hp_lost == expected.loss, "Packed metrics count capped per-actor actual HP decrease, not nominal/net damage")
	_check(metrics.medicine_used == expected.medicine and metrics.enemy_attacks_executed == expected.attacks, "Packed metrics count medicine and actual attacks excluding protection")
	_check(metrics.completed_rounds == expected.rounds and metrics.accepted_transactions == expected.accepted, "Packed metrics distinguish completed rounds and once-per-accepted token")
	_check(metrics.terminal_round == (0 if tx.after.active else int(tx.after.round)) and metrics.outcome == tx.after.outcome, "Packed metrics separate terminal round from completed rounds/outcome")
	for actor: Dictionary in tx.after.actors:
		_check(metrics.remaining_resources.actors[actor.id] == {"hp":actor.hp,"qi":actor.qi}, "Remaining borrowed HP/Qi are actual accepted snapshot values")
	_check(metrics.remaining_resources.medicine == tx.after.medicine and metrics.remaining_resources.medicine_heal == 40, "Remaining borrowed medicine is exact3×40 stock")
	var stable: Dictionary = session.fitting_trial_snapshot()
	_check(not game.state.finish_party_presentation(int(tx.epoch),int(tx.token)+99999).get("accepted",false), "Wrong live presentation token cannot acknowledge fitting transaction")
	_check(not session.advance().get("accepted",false) and session.fitting_trial_snapshot() == stable, "Locked/rejected model action cannot charge metrics")

func _fitting_drive(panel, flee: bool = false, medicine: bool = true) -> Dictionary:
	if panel == null: return {}
	_unified_freeze(panel)
	var session = game.state.party_session
	var initial: Dictionary = session.snapshot()
	var history_at_entry: Dictionary = game.state.fitting_comparison_snapshot()
	var expected: Dictionary = {"losses":{},"loss":0,"medicine":0,"attacks":0,"rounds":0,"accepted":0}
	for actor: Dictionary in initial.actors: expected.losses[actor.id] = 0
	var terminal: Dictionary = {}
	for index: int in range(700):
		if not game.state.battle_active: break
		if panel.pending.is_empty():
			if flee: panel.leave()
			else:
				if medicine:
					var snapshot: Dictionary = session.snapshot()
					for actor: Dictionary in snapshot.actors:
						if actor.hp > 0 and actor.hp <= actor.max_hp-40 and snapshot.medicine > 0:
							panel.request_command(actor.id,"item"); break
				if panel.pending.is_empty(): panel._process(1.0)
		var tx: Dictionary = panel.pending
		_check(not tx.is_empty(), "Actual shipped PartyUI has a renderable accepted fitting action")
		if tx.is_empty(): break
		_fitting_measure(tx,session,expected)
		game._process(.016)
		if not tx.after.active:
			terminal = tx.duplicate(true)
			var prior_history: Dictionary = game.state.fitting_comparison_snapshot()
			_check(prior_history == history_at_entry, "Accepted terminal result remains presentation-gated")
			_party_finish(panel)
			_check(game.state.fitting_comparison_snapshot().results.back() == session.fitting_trial_snapshot(), "Actual terminal renderer acknowledgement appends exact immutable result")
			var completed: Dictionary = game.state.fitting_comparison_snapshot()
			_check(not game.state.finish_party_presentation(tx.epoch,tx.token).get("accepted",false) and game.state.fitting_comparison_snapshot() == completed, "Duplicate terminal acknowledgement cannot duplicate history")
			break
		_party_finish(panel)
	_check(not terminal.is_empty() and not game.state.battle_active and game.current_screen == "explore", "Actual fitting win/defeat/flee reaches live result controller")
	if terminal.is_empty(): return {}
	_fitting_observed[terminal.after.outcome] = true
	return session.fitting_trial_snapshot()

func _fitting_start(candidate: String, profile: String):
	var panel = _fitting_panel()
	if panel == null: return null
	if panel.page == "results": await _fitting_click("FittingAction_trial")
	elif panel.page == "preview": await _fitting_click("FittingAction_trial")
	await _fitting_click("FittingCandidate_"+candidate)
	panel = _fitting_panel()
	if panel.profile != profile: await _fitting_click("FittingAction_"+profile)
	panel = _fitting_panel()
	_check(panel.profile == profile and panel.candidate == candidate and panel.page == "trial", "Actual trial controls select catalog enums only")
	await _fitting_click("FittingAction_start")
	var battle = _party_panel()
	_check(battle != null and battle.get_script() == load("res://scripts/party_battle_ui.gd") and battle.session == game.state.party_session, "Actual fitting enters shipped automatic PartyUI and genuine State session")
	if battle != null: _unified_freeze(battle)
	return battle

func _fitting_trials_and_history() -> void:
	for count: int in [1,4]:
		for profile: String in ["ordinary","pressure"]:
			_fitting_prepare(count)
			_check(game.state.set_weapon_fitting("guard").ok, "Prepared installed guard differs from optional borrowed candidates")
			await _fitting_open(true)
			var before: Dictionary = _fitting_capture(); var group: String = ""; var specs: Array = []
			for candidate: String in ["plain","edge","guard"]:
				var panel = await _fitting_start(candidate,profile)
				if panel == null: return
				var metadata: Dictionary = panel.session.fitting_trial_metadata(); var initial: Dictionary = panel.session.snapshot()
				_check(metadata.installed_fitting == "guard" and metadata.borrowed_fitting == candidate and game.state.weapon_fitting == "guard", "Real installed fitting remains separate from borrowed metadata throughout battle")
				_check(_gather_text(game.overlay).contains("本次借用") and _gather_text(game.overlay).contains("真实已装配"), "Actual battle display labels borrowed versus installed")
				if group.is_empty(): group = metadata.comparison_key; specs = metadata.enemy_specs
				_check(metadata.comparison_key == group and metadata.enemy_specs == specs, "Every candidate has the same frozen unfitted-baseline key and exact enemies")
				var budget: int = 0
				for actor: Dictionary in metadata.original_baseline.team.actors: budget += int(actor.attack)
				_check(budget == metadata.base_attack_budget and initial.actors.size() == count, "Actual factory uses exact selected owned unfitted party budget")
				if profile == "ordinary":
					_check(specs[0].hp == 96 and specs[1].hp == 64 and specs[0].attack == 14 and specs[0].heavy_attack == 24 and specs[1].attack == 10, "Default ordinary profile is unchanged96/64 and14/24/10")
				else:
					_check(specs[0].hp == budget*36/5 and specs[1].hp == budget*24/5 and specs[0].hp+specs[1].hp == budget*12-(0 if budget%5 == 0 else 1), "Pressure scales by independently truncated unfitted baseline only")
					_check(specs[0].attack == 40 and specs[0].heavy_attack == 64 and specs[1].attack == 16, "Pressure attack profile is frozen40/64/16")
				for actor: Dictionary in initial.actors: _check(actor.hp == actor.max_hp and actor.qi == actor.max_qi, "Borrowed virtual actor starts full despite actual injury/downed/Qi0")
				_check(initial.medicine == 3 and initial.medicine_heal == 40 and game.state.medicine == 0, "Borrowed three medicines do not spend or grant real zero medicine")
				_fitting_unchanged(before,"actual accepted trial entry")
				var result: Dictionary = _fitting_drive(panel)
				if result.is_empty(): return
				await _fitting_idle(); _fitting_unchanged(before,"actual "+String(result.metrics.outcome)+" terminal/result idle")
				var history: Dictionary = game.state.fitting_comparison_snapshot()
				_check(history.comparison_key == group and history.results.size() == mini(["plain","edge","guard"].find(candidate)+1,2), "Only latest two same-key accepted outcomes remain in session")
				var result_panel = _fitting_panel()
				_check(result_panel != null and result_panel.page == "results" and result_panel.result_rows == history.results, "Actual result renderer consumes exact authoritative history")
				var visible: String = _gather_text(game.overlay)
				_check(visible.contains("借用气血累计损失 %d" % result.metrics.total_actual_hp_lost) and visible.contains("借药用去 %d" % result.metrics.medicine_used), "Visible result shows actual capped HP loss and medicine count")
				_check(visible.contains("敌方实际攻击 %d" % result.metrics.enemy_attacks_executed) and visible.contains("完整经过 %d 轮" % result.metrics.completed_rounds) and visible.contains("结束于第 %d 轮" % result.metrics.terminal_round), "Visible executed attacks and completed/terminal rounds stay distinct")
				_check(not game.state.to_dict().has("fitting_comparison") and not JSON.stringify(game.state.to_dict()).contains("comparison_key") and not JSON.stringify(game.state.to_dict()).contains("borrowed_fitting"), "No trial candidate/history/key is serialized")
			# Real result retry, then immediate actual flee, preserves latest-two cap.
			await _fitting_click("FittingAction_start")
			var retry_panel = _party_panel(); var retry_result: Dictionary = _fitting_drive(retry_panel,true)
			_check(not retry_result.is_empty() and retry_result.metrics.outcome == "flee" and retry_result.metrics.completed_rounds == 0 and retry_result.metrics.terminal_round == 1, "Real result retry/immediate flee distinguishes incomplete first round")
			await _fitting_idle(); _fitting_unchanged(before,"real result retry and flee")
			await _fitting_click("FittingAction_close"); await _fitting_idle()
			_fitting_unchanged(before,"result dismiss with ordinary Main frames")
			var retained: Dictionary = game.state.fitting_comparison_snapshot()
			_check(retained.results.size() == 2, "Result dismissal preserves latest-two session history")
			# Real explicit save/load clears session history without serializing it.
			_check(game.state.save_game() == OK, "Explicit save of real state after comparison succeeds")
			game._load()
			_check(game.state.fitting_comparison_snapshot().results.is_empty(), "Actual Main successful load clears temporary comparison history")
	# Deterministic boundary fixtures: a full borrowed1HP hero can lose to a40-point hit;
	# a999 attack fixture can win within the first round. Both remain prepared, not earned.
	for outcome: String in ["win","defeat"]:
		_fitting_prepare(4 if outcome == "win" else 1)
		game.state.level = 99 if outcome == "win" else 3
		game.state.attack = 999 if outcome == "win" else 1
		game.state.defense = 0; game.state.max_hp = 999 if outcome == "win" else 1; game.state.hp = 1
		await _fitting_open(true)
		var before: Dictionary = _fitting_capture()
		var panel = await _fitting_start("plain","ordinary" if outcome == "win" else "pressure")
		var result: Dictionary = _fitting_drive(panel,false,false)
		_check(not result.is_empty() and result.metrics.outcome == outcome, "Actual prepared boundary reaches truthful "+outcome)
		if not result.is_empty() and outcome == "defeat": _check(result.metrics.total_actual_hp_lost == 1, "40-point nominal hit records only one actual remaining HP loss")
		await _fitting_idle(); _fitting_unchanged(before,"first-round/overkill actual outcome")
		await _fitting_key(KEY_ESCAPE)
	for expected: String in ["win","defeat","flee","protect","medicine"]:
		_check(_fitting_observed.has(expected), "Actual accepted fitting controller traces include "+expected)

func _fitting_group_changes() -> void:
	_fitting_prepare(4); await _fitting_open(true)
	var panel = await _fitting_start("plain","ordinary")
	var initial: Dictionary = _fitting_drive(panel,true)
	if initial.is_empty(): return
	var before_ordinary: Dictionary = game.state.fitting_comparison_snapshot()
	await _fitting_key(KEY_ESCAPE); await _fitting_key(KEY_E); await _fitting_key(KEY_1)
	_check(_party_panel() != null and _party_panel().fitting_metadata.is_empty(), "Original first courtyard choice still opens ordinary noncomparison practice")
	_unified_leave()
	_check(game.state.fitting_comparison_snapshot() == before_ordinary, "Actual ordinary practice preserves prior fitting comparison history")
	for determinant: String in ["formation","order","base","maxima","art","rank","profile"]:
		var old_key: String = game.state.fitting_comparison_snapshot().comparison_key
		await _fitting_key(KEY_ESCAPE)
		match determinant:
			"formation": _check(game.state.set_formation("护后" if game.state.formation == "并肩" else "并肩"), "Actual formation changes comparison determinant")
			"order": _check(game.state.set_party_roster(["hero","qin","tang","shen"]), "Actual ordered selected roster changes comparison determinant")
			"base": game.state.attack += 1
			"maxima": game.state.max_hp += 1
			"art": _check(game.state.equip_art(game.state.sect_art()), "Actual owned equipped art changes comparison determinant")
			"rank": game.state.art_uses[game.state.equipped_art] = int(game.state.art_uses.get(game.state.equipped_art,0))+15
		await _fitting_open(true)
		panel = await _fitting_start("plain","pressure" if determinant == "profile" else "ordinary")
		_check(game.state.fitting_comparison_snapshot().comparison_key != old_key and game.state.fitting_comparison_snapshot().results.is_empty(), "Changed successful trial group clears stale comparisons: "+determinant)
		var before: Dictionary = _fitting_capture()
		var result: Dictionary = _fitting_drive(panel,true)
		_check(not result.is_empty() and game.state.fitting_comparison_snapshot().results.size() == 1, "Changed group keeps only its own accepted result")
		await _fitting_idle(); _fitting_unchanged(before,"changed-group trial remains detached")
	await _fitting_key(KEY_ESCAPE)
	game._new_game()
	_check(game.state.fitting_comparison_snapshot().results.is_empty(), "Actual new journey clears session-only history")
	# Synthetic high-stat floor case, explicitly not an earned level99 journey.
	_fitting_prepare()
	game.state.level = 99; game.state.attack = 323; game.state.defense = 105; game.state.max_hp = 1286; game.state.hp = 7
	await _fitting_open(true)
	var outcomes: Array = []
	for candidate: String in ["plain","edge","guard"]:
		panel = await _fitting_start(candidate,"pressure")
		var before: Dictionary = _fitting_capture()
		var result: Dictionary = _fitting_drive(panel)
		if result.is_empty(): return
		outcomes.append([result.metrics.medicine_used,result.metrics.total_actual_hp_lost,result.metrics.completed_rounds,result.metrics.terminal_round,result.metrics.outcome])
		await _fitting_idle(); _fitting_unchanged(before,"synthetic high-level damage-floor sample")
	_check(outcomes[0] == outcomes[1] and outcomes[1] == outcomes[2], "Actual high-stat UI results may be identical; no manufactured universal advantage")
	_check(_gather_text(game.overlay).contains("不会保证普遍优势"), "Visible comparison states bounded sampled results")
	await _fitting_key(KEY_ESCAPE)

func _fitting_explicit_close() -> void:
	var original_browser: bool = game.browser_mode
	# Inject only the existing return-to-title destination, avoiding a process quit.
	# This is a native control-flow check, not browser refresh or physical-close proof.
	for fail_save: bool in [false,true]:
		_fitting_prepare(); game.state.set_weapon_fitting("guard")
		await _fitting_open(true)
		var panel = await _fitting_start("edge","ordinary")
		if panel == null: return
		var real: Dictionary = game.state.to_dict(); var disk: Dictionary = _fitting_disk()
		var blocker: String = _receipt_block_save() if fail_save else ""
		if fail_save: disk = _fitting_disk()
		panel._process(1.0)
		_check(not panel.pending.is_empty() and panel.art.is_presenting(), "Explicit close starts during actual accepted fitting presentation")
		game.browser_mode = true
		game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST); game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_check(panel.close_pending and game.state.battle_active and _fitting_disk() == disk, "Repeated close request waits accepted animation without premature saving")
		_party_finish(panel)
		if not panel.pending.is_empty(): _party_finish(panel)
		var expected: Dictionary = real.duplicate(true); expected.position = {"x":game.world.player_pos.x,"y":game.world.player_pos.y}
		_check(game.state._same_save_value(game.state.to_dict(),expected) and game.state.weapon_fitting == "guard", "Explicit exit saves only real choice/resources plus established position synchronization")
		if fail_save:
			_check(game.current_screen == "explore" and game.active_modal and game.save_warning and _fitting_disk() == disk, "Failed explicit close retains real state/all prior bytes and does not leave")
			var stale: Callable = game.modal_actions[0]
			await _fitting_key(KEY_2)
			var before: Dictionary = _fitting_capture(); _fitting_replay(stale)
			await _fitting_key(KEY_ESCAPE); await _fitting_idle()
			_fitting_unchanged(before,"failed-close return/Escape/stale retry")
			_receipt_unblock_save(blocker)
			game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_check(game.current_screen == "title" and not game.save_warning and _receipt_document().version == 16 and _receipt_document().player.weapon_fitting == "guard", "Accepted explicit exit writes real schema16 and returns safely to title")
		_check(not _receipt_bytes().get_string_from_utf8().contains("borrowed_fitting") and not _receipt_bytes().get_string_from_utf8().contains("comparison_key"), "Explicit exit never serializes borrowed candidate/comparison history")
		game.browser_mode = original_browser

func _test_fitting_pack() -> void:
	var first: int = checks
	_check(game.state.get_script().resource_path == "res://scripts/game_state.gd" and game.get_script() == load("res://scripts/main.gd"), "Fitting audit drives exact shipped Main and genuine State, never a mock subscene")
	_fitting_migrations()
	_fitting_old_plain()
	await _fitting_views_and_equips()
	await _fitting_guarded_actions()
	await _fitting_trials_and_history()
	await _fitting_group_changes()
	await _fitting_explicit_close()
	_check(not game.web_save_transfer_enabled and not ProjectSettings.get_setting("hero/features/web_save_transfer_enabled",false), "Complete fitting scope leaves transfer default-off")
	print("Schema16 equipment fitting exact-runtime coverage: %d checks; actual shipped Main/controller/native prepared keys/mouse/PartyUI; live Main processing/divergent position; explicit enum-only equip/revert and save-failure retry versus borrowed full virtual resources/no reward/no practice saves; original-source ordinary parity with current dependencies; frozen unfitted comparison/accepted metrics/latest-two/history/load; authentic1,9-15 and authored2-8; frozen15 accepts genuine15/rejects actual16 nondestructively; since13/14/15/16 separate; native return-to-title close injection only; no earned-route/browser/physical-close/pixel/full-old-PCK claim" % (checks-first+_fitting_prerequisite_checks))

# JOURNAL LEGACY COVERAGE LEDGER (old -> new, no removed checks/partitions):
# 1. Pending Tang global checklist -> earned tang_notes detail; frozen model says
#    "与唐栖商议同行", with explicit stage3/unrecruited/trackable/Auto invariants.
# 2. Tang chosen ending -> actual earned History; both unchanged branch literals.
# 3. Mist static aggregate heading "听雨辨令" -> immutable completed row
#    "竹坡余声"; exact warn_ferries ending retained, plus stage4/completed/untrackable.
# 4. Shen completion -> actual earned History; unchanged completed-care checkmark.
# 5. Learned lightness/lore -> actual earned History; unchanged two lore literals.
# 6. Capstone record -> actual earned History; unchanged title/read-only/disk gates.
# View entry only changes for (2,4–6); (1,3) have exact frozen-model mappings.
# 7. Map570 page -> exact720 caption page, same780x330 chart/region/close/
#    numbered dismissal; original four page checks retain containment plus caption.
# 8. Old M-replaces-transfer shortcut -> prove J/M protection, then actual generic
#    FORCED HOST replacement; original picker invalidation and all-file invariants.
# All nine prior partition counts remain pinned.
func _journal_legacy_history() -> void:
	var panel = game.overlay.get_meta("journal_ui",null)
	if panel != null: panel.show_history()
	else: push_error("Legacy earned-history coverage requires actual JournalUI")

func _journal_legacy_browse(id: String) -> void:
	var panel = game.overlay.get_meta("journal_ui",null)
	if panel != null: panel.browse(id)
	else: push_error("Legacy earned-detail coverage requires actual JournalUI")

# Same-schema16 journal partition. Driver and immutable oracle remain external;
# only actual shipped scripts are loaded from the subject PCK. Prepared canonical
# states and native injected inputs are not an organically earned walkthrough.
const JOURNAL_ORACLE_SHA256 := "38cb8469799e8169201c06e203cd219901e3d06c159c09998ffc2e577ff0c443"
const JOURNAL_TUPLE: Array[String] = ["mode","kind","arc_id","step_key","destination_map","destination_site","next_target_id","route_status"]
var _journal_prerequisite_checks: int = 0
var _journal_oracle: Dictionary = {}

func _journal_prerequisites() -> bool:
	var previous: int = failures; var first: int = checks
	for module: String in ["journal_objective_rules","journal_guidance_rules","journal_guidance_session","journal_guidance_view","journal_ui"]:
		_check(ResourceLoader.exists("res://scripts/"+module+".gd"), "Journal actual shipped resource precedes scene/save: "+module)
	_journal_prerequisite_checks += checks-first
	return failures == previous

func _journal_oracle_prerequisite(rehearsal: bool) -> bool:
	var previous: int = failures; var first: int = checks
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--journal-oracle="): path = argument.trim_prefix("--journal-oracle=")
	if rehearsal and path.is_empty(): path = ProjectSettings.globalize_path("res://tests/journal_guidance_frozen_oracle.json")
	_check(path.is_absolute_path() and FileAccess.file_exists(path) and FileAccess.get_sha256(path) == JOURNAL_ORACLE_SHA256, "Journal immutable117 oracle externally byte-pinned before scene/save")
	if failures != previous: return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary and parsed.get("rows",[]).size() == 117 and parsed.get("reviewed_target_differences",[]).size() == 14, "Frozen117 corpus retains exactly14 approved Qin-over-Tang target repairs")
	if failures != previous: return false
	_journal_oracle = parsed
	_journal_prerequisite_checks += checks-first
	return failures == previous

func _journal_panel(): return game.overlay.get_meta("journal_ui") if game.overlay.has_meta("journal_ui") else null

func _journal_tuple(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in JOURNAL_TUPLE: result[key] = value.get(key)
	return result

func _journal_shared(label: String, target: String = "*", arc: String = "*") -> void:
	var value: Dictionary = game.journal_guidance_snapshot
	var tuple: Dictionary = _journal_tuple(value)
	_check(_journal_tuple(game.world.journal_guidance_snapshot) == tuple and game.world.journal_guidance_revision == game.journal_guidance_revision, "Journal World receives exact host tuple/revision: "+label)
	_check(_journal_tuple(game.hud.journal_guidance_snapshot) == tuple and game.hud.journal_guidance_revision == game.journal_guidance_revision, "Journal HUD receives exact host tuple/revision: "+label)
	_check(game.world._quest_target_id() == value.next_target_id and game.quest_label.text == value.arc_title, "Journal actual diamond/compass/HUD share validated target/title: "+label)
	if value.route_status == "local":
		_check(not String(value.route_note).contains("暂无可标出的下一处") and not String(value.next_target_id).is_empty(), "Journal valid local target never carries unavailable default prose: "+label)
	elif value.route_status == "unavailable":
		_check(not String(value.route_note).is_empty() and String(value.next_target_id).is_empty(), "Journal genuinely unavailable route retains explanatory note and no marker: "+label)
	if _journal_panel() != null:
		_check(_journal_tuple(_journal_panel().guidance_copy()) == tuple and _journal_panel().guidance_revision == game.journal_guidance_revision, "Journal actual folio current strip shares tuple/revision: "+label)
	if game.overlay.get_meta("journal_map",false):
		var chart = game.overlay.find_child("RegionChart",true,false)
		_check(chart != null and _journal_tuple(chart.journal_guidance_snapshot) == tuple and chart.current_target == value.next_target_id, "Journal M shares host tuple/physical target: "+label)
		_check(chart != null and chart.cart_route == value.cart_route, "Journal M consumes exact supplied route: "+label)
	if target != "*": _check(value.next_target_id == target, "Journal independent expected target "+target+": "+label)
	if arc != "*": _check(value.arc_id == arc, "Journal independent expected arc "+arc+": "+label)

func _journal_state(label: String):
	for row: Dictionary in _journal_oracle.rows:
		if row.label != label: continue
		var model = load("res://scripts/game_state.gd")
		var read: Dictionary = model.new().inspect_save_bytes(JSON.stringify({"version":16,"player":row.state}).to_utf8_buffer())
		_check(read.ok and read.state._same_save_value(read.state.to_dict(),row.state), "Journal genuine current16 reader preserves prepared oracle state: "+label)
		return read.state
	_check(false,"Journal required frozen fixture missing: "+label)
	return null

func _journal_apply(state) -> void:
	game.modal_autosave_on_close = false
	game.current_screen = "explore"
	game._close_modal()
	game.state = state
	game._apply_loaded_state()
	game._stop_audio(); game.audio_on = false
	game.set_process(true); game.world.set_process(true)
	game._sync_world_state(); game._refresh()
	_check(game.get_script() == load("res://scripts/main.gd") and game.state.get_script().resource_path == "res://scripts/game_state.gd", "Journal uses unwrapped actual shipped Main and HeroState")
	_check(game.state.SAVE_VERSION == 16 and game.journal_session.tracked_arc_id.is_empty(), "Journal applied prepared16 journey starts transient Auto without migration")

func _journal_disk(path: String = "user://") -> Dictionary:
	var result: Dictionary = {}; var directory = DirAccess.open(path)
	if directory == null: return result
	directory.list_dir_begin(); var name: String = directory.get_next()
	while not name.is_empty():
		if name not in [".","..","logs"]:
			var full: String = path.path_join(name)
			if directory.current_is_dir(): result[full+"/"] = true; result.merge(_journal_disk(full))
			else: result[full] = {"bytes":FileAccess.get_file_as_bytes(full),"modified":FileAccess.get_modified_time(full)}
		name = directory.get_next()
	directory.list_dir_end()
	return result

func _journal_identities() -> Dictionary:
	# The already-running Python wrapper supplies its own interpreter, including
	# Windows; this subprocess only stats the isolated audit profile, never source.
	var python: String = OS.get_environment("HERO_AUDIT_PYTHON")
	var output: Array = []
	var code: String = "import os,json,sys; r=sys.argv[1]; out={};\nfor p,ds,fs in os.walk(r):\n ds[:]=[d for d in ds if d!='logs'];\n for n in sorted(ds+fs):\n  f=os.path.join(p,n); s=os.lstat(f); out[os.path.relpath(f,r)]=[str(s.st_ino),str(s.st_mtime_ns),s.st_size]\nprint(json.dumps(out,sort_keys=True))"
	var status: int = OS.execute(python,PackedStringArray(["-c",code,ProjectSettings.globalize_path("user://")]),output) if not python.is_empty() else -1
	_check(status == 0 and output.size() == 1, "Journal read-only isolated-file inode/nanosecond inventory succeeds")
	if status != 0 or output.is_empty(): return {}
	var parsed: Variant = JSON.parse_string(output[0])
	_check(parsed is Dictionary, "Journal isolated-file identity inventory is structured")
	return parsed if parsed is Dictionary else {}

func _journal_capture() -> Dictionary:
	return {"state":_receipt_variables(game.state),"canonical":game.state.to_dict().duplicate(true),"state_id":game.state.get_instance_id(),"world_map":game.world.map_id,"world_position":game.world.player_pos,"files":_journal_disk(),"identities":_journal_identities(),"zoom":game.view_zoom}

func _journal_same(before: Dictionary, label: String, disk: bool = true) -> void:
	_check(game.state.to_dict() == before.canonical and _receipt_variables(game.state) == before.state, "Journal entire canonical/transient State/resources/gates unchanged: "+label)
	_check(game.state.get_instance_id() == before.state_id and game.world.map_id == before.world_map and game.world.player_pos == before.world_position and game.view_zoom == before.zoom, "Journal actual identity/map/world position/preferences unchanged: "+label)
	if disk:
		_check(_journal_disk() == before.files, "Journal all nonlog user files/exact bytes/observed timestamps unchanged: "+label)
		_check(_journal_identities() == before.identities, "Journal no same-byte rewrite, inode replacement or nanosecond timestamp write: "+label)
	_check(game.is_processing(), "Journal actual Main processing retained: "+label)

func _journal_callback(button) -> Callable:
	var captured: Callable = Callable()
	if button is Button:
		for connection: Dictionary in button.pressed.get_connections():
			if connection.callable.is_valid(): captured = connection.callable; break
	_check(captured.is_valid(), "Journal captures an actual live connected native-control callback: "+str(button.name if button is Button else "missing"))
	return captured

func _journal_activate(key: String) -> void:
	await process_frame; await process_frame # Settle deferred owner focus before deliberately focusing an action.
	var panel = _journal_panel()
	var button = panel.action_buttons.get(key) if panel != null else null
	_check(button is Button and not button.disabled, "Journal actual native action exists/enabled: "+key)
	if button is Button and not button.disabled:
		button.grab_focus()
		await _fitting_key(KEY_ENTER) # Both native press and release before assertion.

func _journal_track(id: String) -> void:
	await process_frame; await process_frame # Fresh J schedules initial row focus; do not race it.
	var panel = _journal_panel()
	_check(panel != null and panel.row_buttons.has(id), "Journal earned visible row required: "+id)
	if panel == null or not panel.row_buttons.has(id): return
	panel.row_buttons[id].grab_focus(); await _fitting_key(KEY_ENTER)
	_check(_journal_panel() == panel and panel.browse_arc_id == id, "Journal native row Enter browses only: "+id)
	await _journal_activate("track")
	_check(game.journal_session.tracked_arc_id == id and _journal_panel() == panel, "Journal explicit native Track selects and retains owner: "+id)

func _journal_stale(callback: Callable, label: String) -> void:
	var before: Dictionary = _journal_capture(); var selected: String = game.journal_session.tracked_arc_id; var generation: int = game.modal_generation
	_check(callback.is_valid(), "Journal stale replay requires previously captured still-live callback: "+label)
	if callback.is_valid(): callback.call()
	_journal_same(before,label)
	_check(game.journal_session.tracked_arc_id == selected and game.modal_generation == generation, "Journal stale callback cannot replace selection/owner: "+label)

func _journal_frozen_runtime() -> void:
	var repairs: Dictionary = {}; var visited: Dictionary = {}; var changed: int = 0
	for row: Dictionary in _journal_oracle.reviewed_target_differences: repairs[row.label] = row
	for row: Dictionary in _journal_oracle.rows:
		_journal_apply(_journal_state(row.label))
		# Oracle physical context can deliberately differ from serialized position.
		game.world.player_pos = Vector2(row.context.player_position[0],row.context.player_position[1])
		game._sync_journal_guidance(true)
		var before: Dictionary = game.state.to_dict().duplicate(true)
		var expected: String = String(row.frozen_observation.target)
		if repairs.has(row.label):
			expected = String(repairs[row.label].new_target); changed += 1
			_check(row.frozen_observation.target == repairs[row.label].old_target and game.journal_guidance_snapshot.arc_id == "qin_rope", "Journal reviewed Qin repair retains frozen prior target/winning arc: "+row.label)
		var expected_hint: String = String(row.frozen_observation.hint)
		# Frozen capstone HUD appended travel prose; phase1's accepted contract
		# separates unchanged goal next_action from the current route explanation.
		# This exact mapping applies only to the retained capstone0–6 rows.
		if String(row.label).begins_with("capstone_") and int(row.state.capstone_stage) < 7:
			var core: String = expected_hint.get_slice(" 先沿",0)
			var suffix: String = " 先沿" + String(row.context.markers[expected].name) + "行路。" if expected_hint.contains(" 先沿") else ""
			_check(expected_hint == core+suffix and core == String(game.state.Capstone.goal(game.state).objective), "Journal frozen capstone instruction has exact unchanged core and independently named prior route suffix: "+row.label)
			var rendered_suffix: String = " 先往" + String(row.context.markers[expected].name) + "。" if not suffix.is_empty() else ""
			_check(game.hint_label.text == core+rendered_suffix, "Journal complete rendered capstone HUD exactly maps frozen core/physical-route suffix: "+row.label)
			expected_hint = core
		_check(game.quest_label.text == row.frozen_observation.title and game.journal_guidance_snapshot.next_action == expected_hint, "Journal frozen automatic title/action retained exactly: "+row.label)
		_journal_shared("frozen "+row.label,expected)
		game._show_map(); _journal_shared("frozen M "+row.label,expected); game._close_modal()
		_check(game.state.to_dict() == before, "Journal frozen actual M open/close remains canonical read-only: "+row.label)
		visited[row.label] = true
	_check(visited.size() == 117 and changed == 14 and repairs.size() == 14, "Journal no-skip actual Main117/14 frozen matrix executed exactly once")

func _journal_input_readonly() -> void:
	_journal_apply(_journal_state("opening_0"))
	game._show_journal()
	_check(_journal_panel() != null and _journal_panel().row_buttons.keys() == ["opening"] and game.modal_actions.is_empty(), "Journal fresh actual UI reveals only earned opening and no generic modal actions")
	var fresh: Dictionary = _journal_capture()
	await _fitting_key(KEY_ENTER); await _fitting_key(KEY_SPACE)
	_check(_journal_panel() != null and game.journal_session.tracked_arc_id.is_empty(), "Journal initial Enter/Space never implicitly tracks or closes")
	await _journal_activate("history"); await _fitting_key(KEY_ESCAPE)
	_check(_journal_panel() != null and _journal_panel().page == "journal", "Journal History Esc returns once to folio")
	await _fitting_key(KEY_ESCAPE); _journal_same(fresh,"fresh browse/history/back/close")
	for fitting: String in ["plain","edge","guard"]:
		var state = _journal_state("bounded_qin_tang_fix_1_1")
		_check(state.set_weapon_fitting(fitting).ok, "Journal prepared real fitting choice "+fitting)
		_journal_apply(state)
		_check(game.state.save_game() == OK, "Journal test-owned real16 baseline before read-only window")
		game.state.coins += 7; game.state.position = game.world.player_pos + Vector2(-9,0)
		var before: Dictionary = _journal_capture()
		game._show_journal(); await _fitting_idle()
		_check(_journal_panel() != null and not game.modal_autosave_on_close and not game.world.active and not game._journal_position_hold.is_empty(), "Journal actual folio owns held divergent position without autosave")
		var automatic: Dictionary = _journal_tuple(game.journal_guidance_snapshot)
		var panel = _journal_panel()
		panel.browse("opening")
		_check(panel._row("opening").status == "completed" and not panel._row("opening").trackable and panel.action_buttons.track.disabled, "Journal completed earned row is readable but cannot Track")
		panel.browse("heting_delivery")
		_check(panel._row("heting_delivery").status == "available" and panel._row("heting_delivery").trackable and game.state.heting_stage == 0, "Journal stage0 earned destination is available without accepting its story")
		panel.browse("tang_notes")
		_check(_journal_tuple(game.journal_guidance_snapshot) == automatic and game.journal_session.tracked_arc_id.is_empty(), "Journal browse never publishes the preview as guidance")
		var stale: Callable = _journal_callback(panel.action_buttons.track)
		panel.browse("qin_rope"); panel.browse("tang_notes"); _journal_stale(stale,"row A-B-A")
		await _journal_track("tang_notes"); _journal_shared("manual Tang","return_frostbridge","tang_notes")
		var selected_revision: int = game.journal_guidance_revision
		panel.track_selected(); panel.track_selected()
		_check(game.journal_guidance_revision == selected_revision and panel.action_buttons.track.disabled, "Journal redundant Track is inert and disabled")
		for key: Key in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_E,KEY_M,KEY_F5,KEY_F9,KEY_F6,KEY_F10,KEY_B,KEY_I,KEY_K,KEY_EQUAL,KEY_MINUS]:
			await _fitting_key(key)
			_check(_journal_panel() == panel and game.journal_session.tracked_arc_id == "tang_notes", "Journal consumes protected global key "+str(key))
		await _fitting_key(KEY_J,true); await _fitting_key(KEY_ESCAPE,true)
		_check(_journal_panel() == panel, "Journal key echoes cannot close or reopen owner")
		stale = _journal_callback(panel.action_buttons.auto)
		await _journal_activate("history"); await _fitting_key(KEY_END); await _fitting_key(KEY_HOME); await _fitting_key(KEY_ESCAPE)
		_journal_stale(stale,"history roundtrip Auto")
		await _journal_activate("auto"); _journal_shared("restored Auto","mist_rain_gauge","qin_rope")
		_check(game.journal_session.tracked_arc_id.is_empty() and panel.action_buttons.auto.disabled, "Journal explicit Auto disables repeat and keeps owner")
		stale = _journal_callback(panel.action_buttons.close)
		# Close through the real guarded owner, then replay before queued-free so
		# this proves a live stale callable rejects, not merely a freed Node.
		panel.close(); game._show_map(); _journal_shared("read-only M")
		_journal_stale(stale,"closed J callback cannot affect M")
		await _fitting_key(KEY_1); await _fitting_idle(); _journal_same(before,"J/Track/Auto/history/M fitting "+fitting)
		var save: Dictionary = JSON.parse_string(_receipt_bytes().get_string_from_utf8())
		_check(save.version == 16 and save.player.size() == game.state.to_dict().size() and save.player.keys().all(func(key): return game.state.to_dict().has(key)) and not _receipt_bytes().get_string_from_utf8().contains("tracked_arc_id") and not _receipt_bytes().get_string_from_utf8().contains("journal_guidance"), "Journal serialized schema/keys unchanged, no session or view fields")

func _journal_route_valid(label: String) -> void:
	var value: Dictionary = game.journal_guidance_snapshot; var route: PackedVector2Array = value.cart_route
	_check(not route.is_empty(), "Journal loaded cart has an actual collision route: "+label)
	if route.is_empty(): return
	_check(route[0] == game.world.player_pos and route[-1] == value.next_target_position, "Journal loaded route exact start and immediate target: "+label)
	var region = load("res://scripts/heting_region.gd")
	for index: int in range(1,route.size()):
		_check(region.can_step(route[index-1],route[index],game.state.heting_bridge,true), "Journal every loaded route segment legal: "+label+" "+str(index))

func _journal_routes_gates() -> void:
	_journal_apply(_journal_state("bounded_qin_tang_fix_1_1"))
	game._show_journal(); await _journal_track("tang_notes"); await _fitting_key(KEY_ESCAPE)
	var markers: Dictionary = game.world.interactables.duplicate(true)
	var target: String = game.journal_guidance_snapshot.next_target_id
	game.world.interactables.erase(target)
	_check(game.world._quest_target_id().is_empty(), "Journal World immediately suppresses removed marker before host refresh")
	game._sync_journal_guidance(); _journal_shared("missing marker","","tang_notes")
	_check(game.journal_session.tracked_arc_id == "tang_notes" and game.journal_guidance_snapshot.route_status == "unavailable", "Journal unavailable route retains explicit selection")
	game.world.interactables = markers.duplicate(true); game._sync_journal_guidance()
	_journal_shared("restored marker",target,"tang_notes")
	game.world.map_id = "qingwei"; game._sync_journal_guidance()
	_journal_shared("half-transition","","tang_notes")
	game.world.map_id = game.state.map_id; game._sync_journal_guidance()
	game.world.interactables[target].pos = Vector2.INF; game._sync_journal_guidance()
	_journal_shared("nonfinite marker","","tang_notes")
	game.world.interactables = markers.duplicate(true); game._sync_journal_guidance()
	var metrics: Dictionary = game.journal_view.metrics
	for unused: int in range(100): game._sync_journal_guidance()
	_check(game.journal_view.metrics.full_resolves == metrics.full_resolves and game.journal_view.metrics.catalog_builds == metrics.catalog_builds, "Journal100 unchanged idle refreshes do not rebuild catalog or resolver")
	var detached: Dictionary = game.journal_preview("tang_notes")
	detached.arc_title = "caller mutation"; detached.marker_view.markers[target].pos = Vector2.ZERO
	_check(game.journal_preview("tang_notes").arc_title != "caller mutation" and game.world.interactables[target].pos == markers[target].pos, "Journal published preview/marker values are detached from caller mutation")
	for gate: String in ["battle","pending","quit"]:
		var before_generation: int = game.modal_generation
		if gate == "battle": game.state.battle_active = true
		elif gate == "pending": game.state._party_pending_token = 44
		else: game.quit_pending = true
		game._show_journal(); game._show_map()
		_check(_journal_panel() == null and not game.overlay.get_meta("journal_map",false) and game.modal_generation == before_generation, "Journal J/M cannot enter guarded state: "+gate)
		game.state.battle_active = false; game.state._party_pending_token = -1; game.quit_pending = false
	for owner: String in ["weapon_fitting","party_roster","party_roster_direct_info","receipt_battle","party_battle","courtyard_practice","save_transfer","fitting_workshop_readonly","fitting_exit_readonly"]:
		game.overlay.set_meta(owner,true); var generation: int = game.modal_generation
		game._show_journal(); game._show_map()
		_check(_journal_panel() == null and game.modal_generation == generation, "Journal does not replace protected owner: "+owner)
		game.overlay.remove_meta(owner)
	for learned: bool in [false,true]:
		var state = _journal_state("bounded_qin_tang_fix_1_1")
		state.map_id = "qingwei"; state.position = Vector2(1514,930); state.lightness_unlocked = learned
		_journal_apply(state); var before: Dictionary = _journal_capture()
		game._show_journal(); await _journal_track("tang_notes"); _journal_shared("islet return","reed_return","tang_notes")
		await _fitting_key(KEY_ESCAPE); game._show_map(); _journal_shared("islet M","reed_return","tang_notes"); game._close_modal()
		_journal_same(before,"islet guidance never crosses")
	for modern: bool in [false,true]:
		for side: String in ["west","east"]:
			var state = _journal_state("harbor_overlap_1_4")
			state.heting_bridge = side; state.position = Vector2(820,665)
			if not modern:
				state.consignee_stage = 0; state.consignee_observations.clear(); state.consignee_draft = ""; state.consignee_cargo_location = ""; state.receipt_stage = 0
				state.heting_stage = 1; state.heting_delivered.clear(); state.heting_cargo = "meal"; state.heting_draft = ""; state.heting_ending = ""
			_journal_apply(state); var before: Dictionary = _journal_capture()
			game._show_journal(); await _journal_track("heting_consignee" if modern else "heting_delivery")
			_journal_route_valid("loaded "+str(modern)+side); await _fitting_key(KEY_ESCAPE)
			game._show_map(); _journal_shared("loaded M"); _journal_route_valid("loaded M "+str(modern)+side); game._close_modal()
			var route_metrics: Dictionary = game.journal_view.metrics
			var origin: Vector2 = game.world.player_pos
			for step: int in range(1,6):
				game.world.player_pos = origin + Vector2(step,0)
				game._sync_journal_guidance(); _journal_route_valid("exact loaded reanchor "+str(step))
			_check(game.journal_view.metrics.full_resolves == route_metrics.full_resolves and game.journal_view.metrics.route_reanchors == route_metrics.route_reanchors+5, "Journal measured five certified loaded reanchors avoid a full route solve")
			game.world.player_pos = origin; game._sync_journal_guidance()
			game._show_journal(); await _journal_track("qin_rope"); _journal_shared("loaded departure","return_mistwood","qin_rope")
			_check(game.journal_guidance_snapshot.route_status == "departure_confirmation" and game.journal_guidance_snapshot.route_note.contains("确认"), "Journal loaded remote objective truthfully requires parking confirmation")
			await _fitting_key(KEY_ESCAPE); _journal_same(before,"loaded guidance never parks or moves cargo")

func _journal_session_lifecycle() -> void:
	_journal_apply(_journal_state("bounded_qin_tang_fix_1_1"))
	_check(game.state.save_game() == OK and game.save_slots.store.save_slot(game.state,1) == OK, "Journal prepared actual auto/manual save baselines")
	game._show_journal(); await _journal_track("tang_notes"); await _fitting_key(KEY_ESCAPE)
	var identity: int = game.state.get_instance_id(); game._load()
	_check(game.state.get_instance_id() == identity and game.journal_session.tracked_arc_id.is_empty(), "Journal successful same-State quickload resets session")
	game._show_journal(); await _journal_track("tang_notes"); await _fitting_key(KEY_ESCAPE)
	game.save_slots.request_load(1,false); _press("返回详情")
	_check(game.journal_session.tracked_arc_id == "tang_notes", "Journal cancelled actual manual-load prompt retains selection")
	game.save_slots.perform_load(1,false)
	_check(game.state.get_instance_id() == identity and game.journal_session.tracked_arc_id.is_empty(), "Journal successful actual manual-load application resets selection")
	game._show_journal(); await _journal_track("tang_notes"); await _fitting_key(KEY_ESCAPE)
	var genuine: PackedByteArray = _receipt_bytes()
	_transfer_write("user://hero_save.json","{owned malformed journal test".to_utf8_buffer())
	var failed: Dictionary = _journal_capture(); game._load(); _journal_same(failed,"failed actual quickload")
	_check(game.journal_session.tracked_arc_id == "tang_notes", "Journal failed quickload retains selection")
	_transfer_write("user://hero_save.json",genuine)
	_check(game.save_slots.store.save_slot(game.state,2) == OK, "Journal prepared actual manual slot for failed-load control")
	var manual: PackedByteArray = FileAccess.get_file_as_bytes(game.save_slots.store.path_for(2))
	_transfer_write(game.save_slots.store.path_for(2),"{owned malformed manual journal test".to_utf8_buffer())
	failed = _journal_capture(); game.save_slots.perform_load(2,false); _journal_same(failed,"failed actual manual load")
	_check(game.journal_session.tracked_arc_id == "tang_notes", "Journal failed manual load retains selection")
	_transfer_write(game.save_slots.store.path_for(2),manual)
	var directory: String = _transfer_directory("journal-storage")
	var store = load("res://scripts/local_save_slots.gd").new(directory)
	_check(store.save_slot(game.state,1) == OK, "Journal isolated storage-only source prepared")
	var transfer = load("res://scripts/local_save_transfer.gd").new(directory)
	var before: Dictionary = _journal_capture(); var exported: Dictionary = transfer.export_slot(1)
	_check(exported.ok, "Journal underlying store exports actual16 bytes")
	_journal_same(before,"storage-only export")
	var preview: Dictionary = transfer.preview_import(exported.bytes,2)
	_check(preview.ok, "Journal storage-only import preview is valid")
	transfer.cancel_preview(preview.token)
	_check(not transfer.commit_import(preview.token).ok and game.journal_session.tracked_arc_id == "tang_notes", "Journal cancelled import preview cannot apply or reset")
	_journal_same(before,"cancelled storage-only import")
	preview = transfer.preview_import(exported.bytes,2)
	_check(preview.ok and transfer.commit_import(preview.token).ok, "Journal storage-only import writes only empty destination")
	_journal_same(before,"storage-only import retains active journey",false)
	_check(game.journal_session.tracked_arc_id == "tang_notes" and FileAccess.get_file_as_bytes(store.path_for(2)) == exported.bytes and not game.web_save_transfer_enabled, "Journal import retains tracking/default-off browser feature and exact bytes")
	for destination: String in ["frostbridge","sluice","qingwei","mistwood"]:
		game._travel(destination,Vector2(460,430))
		_check(game.journal_session.tracked_arc_id == "tang_notes", "Journal ordinary travel retains manual selection: "+destination)
		_journal_shared("travel "+destination)
	_check(game.state.recover_craft_notes(), "Journal prepared actual Tang stage1-to2 helper")
	game._refresh(); _check(game.journal_session.tracked_arc_id == "tang_notes", "Journal same-arc stage change retains tracking")
	_check(game.state.resolve_tangqi_quest("teach"), "Journal prepared actual Tang stage2-to3 helper")
	game._refresh(); _check(game.journal_session.tracked_arc_id == "tang_notes" and not game.state.tangqi_unlocked, "Journal pending invitation does not complete or auto-recruit")
	_check(game.state.recruit_tangqi(), "Journal prepared explicit final recruitment helper")
	var completed: Dictionary = _journal_capture(); game._refresh()
	_check(game.journal_session.tracked_arc_id.is_empty() and game.journal_guidance_snapshot.mode == "auto", "Journal terminal completion restores Auto")
	_check(game.journal_guidance_snapshot.selection_changed and game.journal_guidance_snapshot.selection_notice.contains("已完成，已恢复自动指引"), "Journal completion publishes one truthful transition notice")
	for unused: int in range(100): game._sync_journal_guidance()
	_check(not game.journal_guidance_snapshot.selection_changed and game.journal_guidance_snapshot.selection_notice.is_empty(), "Journal cached idle refresh does not replay completion notice")
	_journal_same(completed,"100 idle completion refreshes do not replay reward/save")
	game._show_journal(); await _journal_track("qin_rope"); await _fitting_key(KEY_ESCAPE)
	game._show_title(); game._request_new_game(); _press("返回")
	_check(game.current_screen == "title" and game.journal_session.tracked_arc_id == "qin_rope", "Journal title and cancelled new-game prompt preserve selection until applied new journey")
	game._new_game()
	_check(game.journal_session.tracked_arc_id.is_empty() and game.state.SAVE_VERSION == 16, "Journal actual new journey resets transient selection, same schema16")

func _test_journal_pack() -> void:
	var first: int = checks
	_journal_frozen_runtime()
	await _journal_input_readonly()
	await _journal_routes_gates()
	await _journal_session_lifecycle()
	print("Schema16 journal guidance exact-runtime coverage: %d checks; actual unwrapped Main/session/J/HUD/World/M; immutable117/14 prepared oracle; earned catalog/native Track/Auto/read-only canonical/resources/position/files; loaded routing/gates/stale callbacks/applied-load-only reset; same schema16/no migration/no serialized journal; Web30 full-PCK compatibility separate; no earned-walk/browser/pixel claim" % (checks-first+_journal_prerequisite_checks))
