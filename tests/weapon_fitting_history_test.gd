extends SceneTree
## State-owned rehearsal lifecycle/result history. Model metric arithmetic and
## frozen profile validation are independently covered by fitting trial tests.
const State = preload("res://scripts/game_state.gd")
const Driver = preload("res://tests/automatic_state_test_driver.gd")
var checks: int = 0
var failures: int = 0
var fixture_root: String

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func _ready_state():
	var s := State.new(); s.quest_stage = 6; s.ending = "守望"; s.choose_sect("听潮阁")
	s.hp = 17; s.qi = 1; s.medicine = 0
	return s

func _flee(s, candidate: String = "plain", profile: String = "ordinary") -> Dictionary:
	var before: Dictionary = s.to_dict()
	check(s.start_fitting_practice(candidate, profile), "Start detached fitting trial")
	if not s.battle_active: return {}
	check(s.to_dict() == before and s.battle_kind == "courtyard_practice", "Entry preserves complete real snapshot and ordinary no-write identity")
	var snapshot: Dictionary = s.party_battle_snapshot()
	check(snapshot.actors[0].hp == s.max_hp and snapshot.actors[0].qi == s.max_qi and snapshot.medicine == 3, "Borrowed resources affect model only")
	var prior: Dictionary = s.fitting_comparison_snapshot()
	var tx: Dictionary = s.party_battle_action("flee")
	check(tx.accepted and not tx.after.active and s.fitting_comparison_snapshot() == prior, "Pending terminal metrics do not append a settled comparison")
	s._record_fitting_comparison()
	check(s.fitting_comparison_snapshot() == prior, "Direct record call cannot bypass pending terminal presentation")
	var settled: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
	check(settled.accepted and settled.settled and settled.outcome == "flee" and not settled.settlement.awarded, "Accepted flee is explicit incomplete outcome without reward")
	check(s.to_dict() == before, "Flee/terminal presentation preserves all real progress/resources")
	var history: Dictionary = s.fitting_comparison_snapshot()
	check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and s.fitting_comparison_snapshot() == history, "Duplicate presentation cannot append twice")
	check(history.is_read_only() and history.results.is_read_only() and history.results[-1].is_read_only() and history.results[-1].metadata.is_read_only() and history.results[-1].metrics.is_read_only(), "Comparison getter recursively detached and immutable")
	return history

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	fixture_root = "user://weapon-fitting-history-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Isolated history save test storage")
	_test_history_groups()
	_test_terminal_paths()
	_test_reset_load_and_entry_gates()
	if failures == 0: print("PASS: %d fitting state practice/no-leak/terminal/once-only/latest-two/group/load-reset checks; synthetic model lifecycle, no scene proximity claim" % checks)
	quit(0 if failures == 0 else 1)

func _test_history_groups() -> void:
	var s = _ready_state()
	check(s.set_weapon_fitting("guard").ok, "Actual installed fitting distinct from borrowing")
	var first: Dictionary = _flee(s, "plain")
	var key: String = first.comparison_key
	check(first.results.size() == 1 and first.results[0].metadata.installed_fitting == "guard" and first.results[0].metadata.borrowed_fitting == "plain", "Result clearly separates installed and borrowed")
	var second: Dictionary = _flee(s, "edge")
	check(second.comparison_key == key and second.results.size() == 2, "Different borrowed candidates remain comparable")
	check(first.results.size() == 1, "Earlier returned history snapshot remains detached")
	check(s.set_weapon_fitting("edge").ok, "Change actual installed fitting between trials")
	var third: Dictionary = _flee(s, "guard")
	check(third.comparison_key == key and third.results.size() == 2 and third.results[0].metadata.borrowed_fitting == "edge" and third.results[1].metadata.borrowed_fitting == "guard", "Only latest two comparable outcomes retained; installed enum excluded")
	check(third.results[1].metrics.outcome == "flee", "Flee never relabeled as successful result")
	var before: Dictionary = s.to_dict()
	check(s.start_fitting_practice("plain", "pressure"), "Explicit optional pressure starts")
	check(s.fitting_comparison_snapshot().results.is_empty() and s.fitting_comparison_snapshot().comparison_key != key, "Different profile clears old group at successful entry")
	var tx: Dictionary = s.party_battle_action("flee"); s.finish_party_presentation(tx.epoch, tx.token)
	check(s.to_dict() == before, "Pressure flee also preserves complete real state")
	var pressure_key: String = s.fitting_comparison_snapshot().comparison_key
	s.attack += 1
	check(s.start_fitting_practice("plain", "pressure"), "Changed real base starts new run")
	check(s.fitting_comparison_snapshot().results.is_empty() and s.fitting_comparison_snapshot().comparison_key != pressure_key, "Changed base invalidates group")
	tx = s.party_battle_action("flee"); s.finish_party_presentation(tx.epoch, tx.token)
	var history: Dictionary = s.fitting_comparison_snapshot()
	check(s.start_party_battle("courtyard_practice"), "Unchanged ordinary practice path still available")
	tx = s.party_battle_action("flee"); s.finish_party_presentation(tx.epoch, tx.token)
	check(s.fitting_comparison_snapshot() == history, "Ordinary noncomparison practice neither appends nor clears history")

func _test_terminal_paths() -> void:
	for outcome: String in ["win", "defeat"]:
		var s = _ready_state()
		if outcome == "win": s.attack = 100; s.defense = 100
		var before: Dictionary = s.to_dict()
		check(s.start_fitting_practice("plain", "ordinary" if outcome == "win" else "pressure"), "Start authentic automatic outcome path:" + outcome)
		var tx: Dictionary = Driver.terminal_next(s)
		check(tx.get("accepted", false) and not tx.after.active and tx.after.outcome == outcome, "Genuine model reaches expected terminal without forged results")
		check(s.fitting_comparison_snapshot().results.is_empty() and s.to_dict() == before, "Pending real terminal still preserves entry state and history")
		var settled: Dictionary = s.finish_party_presentation(tx.epoch, tx.token)
		check(settled.accepted and settled.settled and not settled.settlement.awarded and s.to_dict() == before, "Win/defeat commits no rewards/resources/proficiency")
		var history: Dictionary = s.fitting_comparison_snapshot()
		check(history.results.size() == 1 and history.results[0].metrics.outcome == outcome, "Terminal accepted exactly once into truthful outcome history")
		check(not s.finish_party_presentation(tx.epoch, tx.token).accepted and s.fitting_comparison_snapshot() == history, "Repeated terminal never duplicates outcome")

func _test_reset_load_and_entry_gates() -> void:
	var s = _ready_state(); _flee(s)
	var path: String = fixture_root.path_join("only-persistent.json")
	check(s.save_game(path) == OK, "Explicit save after trial writes only real persistent data")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).player
	check(s._same_save_value(data, s.to_dict()) and not data.has("fitting_comparisons") and not data.has("_fitting_comparisons") and not data.has("trial_candidate"), "No history or borrowed candidate serialized")
	var before: Dictionary = s.fitting_comparison_snapshot()
	check(s.load_game(fixture_root.path_join("missing.json")) != OK and s.fitting_comparison_snapshot() == before, "Failed load does not discard session history")
	check(s.load_game(path) == OK and s.fitting_comparison_snapshot().results.is_empty() and s.fitting_comparison_snapshot().comparison_key.is_empty(), "Successful load clears session comparisons")
	_flee(s); s.reset_game()
	check(s.fitting_comparison_snapshot().results.is_empty() and s.fitting_comparison_snapshot().comparison_key.is_empty(), "New journey clears session comparisons")
	for fitting: String in ["plain", "edge", "guard"]:
		check(not s.start_fitting_practice(fitting) and s.party_session == null, "Dedicated comparison locked before real opening+sect, including original")
	s = _ready_state(); s.map_id = "sluice"
	check(not s.start_fitting_practice("plain"), "Model entry cannot start from another map")
	s.map_id = "qingwei"; s._party_pending_token = 31
	check(not s.start_fitting_practice("plain"), "Stale pending token blocks comparison even without session")
	s._party_pending_token = -1
	before = s.to_dict()
	for candidate: Variant in [null, 1, true, {}, "unknown"]:
		check(not s.start_fitting_practice(candidate) and s.to_dict() == before, "Handler rejects arbitrary candidate payload")
	for profile: Variant in [null, 1, true, {}, "unknown"]:
		check(not s.start_fitting_practice("plain", profile) and s.to_dict() == before, "Handler rejects arbitrary profile payload")
