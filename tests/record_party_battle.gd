extends "res://tests/party_battle_ui_test.gd"
## Prepared level5 main-scene encounter. Actual mouse/keys, fixed30fps recording.
## Runtime hashes pin the already-tested gameplay; no frame-rate/audio claim.
var trace: Array[Dictionary] = []
var source_commit: String = ""
var trace_path: String = ""
var runtime_hashes: Dictionary = {}
func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): source_commit = argument.trim_prefix("--source=")
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
	check(not source_commit.is_empty() and not trace_path.is_empty(), "Recording requires explicit source and evidence paths")
	var record = JSON.parse_string(FileAccess.get_file_as_string("res://tests/party_integration_checkpoint.json"))
	runtime_hashes = record.source_runtime_sha256
	_verify_runtime()
	root.size = Vector2i(1280,800)
	fixture = "user://party-motion-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(fixture)
	s = State.new(); s.fixture = fixture
	app = load("res://scenes/main.tscn").instantiate(); app.set_script(CloseProbe); app.state = s
	root.add_child(app); app.save_slots.store = Slots.new(fixture)
	await process_frame
	app._stop_audio(); app.audio_on = false; app.world.set_process(false)
	app._new_game(); _prepare(4, "heting_receipt"); s.hp -= 24
	app.world.teleport(app.world.interactables.heting_scale.pos + Vector2(0,24)); app._process(0)
	app.receipt_story.open(); await _key(KEY_1)
	var panel = app.overlay.get_meta("party_battle", null)
	check(panel != null and panel.commands.groups.size() == 4, "Default dialogue opens real four-person controller")
	if panel == null: quit(1); return
	panel.art.event_presented.connect(func(event): trace.append(event.duplicate(true)))
	var initial = _resources()
	await _frames(24)
	await _click(panel.commands.actor_buttons.qin); await _key(KEY_2); await _frames(15)
	check(panel.pending_action == "art:qin_shoudu", "Qin protection waits for chosen ally")
	await _click(panel.unit_plates.hero); await _action(panel)
	check(_actor(s.party_battle_snapshot(), "hero").status.barrier == 18 and _actor(s.party_battle_snapshot(), "qin").qi == 3, "Actual protection18 and own3qi")
	await _click(panel.commands.actor_buttons.shen); await _key(KEY_2); await _frames(12)
	await _click(panel.unit_plates.hero); await _action(panel)
	check(s.hp == s.max_hp and _actor(s.party_battle_snapshot(), "shen").qi == 3, "Independent Shen heal keeps real cap/cost")
	await _click(panel.commands.actor_buttons.hero); await _click(panel.unit_plates.bracer); await _key(KEY_1); await _action(panel)
	await _click(panel.commands.actor_buttons.tang); await _key(KEY_2); await _action(panel)
	check(s.party_battle_snapshot().round == 2, "Four allies act before actual enemy response")
	check(_actor(s.party_battle_snapshot(), "qin").status.barrier == 0 and _actor(s.party_battle_snapshot(), "hero").status.barrier == 0, "Actual hit or end-of-phase consumes protection")
	var actors: Array[String] = []
	for event in trace:
		if event.type == "action" and event.phase == "ally": actors.append(event.source_id)
	check(actors == ["qin","shen","hero","tang"], "Recorded action sequence uses four distinct real actors")
	await _frames(22); await _key(KEY_ESCAPE); await _action(panel); await _frames(15)
	check(app.current_screen == "explore" and not s.battle_active and s.receipt_stage == 1, "Actual Escape leaves retryable quest")
	check(s.coins == initial.coins and s.xp == initial.xp and s.medicine == initial.medicine, "Scenario grants no reward and spends no medicine")
	_verify_runtime()
	var output = {"source_commit":source_commit,"scope":"Prepared level5 full-game scene, actual scripted mouse/keyboard, four independent actions and enemy reply, fixed30fps, no browser/manual/audio/FPS claim","checks":checks,"failures":failures,"initial":initial,"final":_resources(),"events":trace,"runtime_entries":runtime_hashes.size(),"runtime_sha256":runtime_hashes}
	var file = FileAccess.open(trace_path, FileAccess.WRITE)
	check(file != null, "Trace evidence destination opens")
	if file != null: file.store_string(JSON.stringify(output,"\t")); file.close()
	print("%s: recorded four independent party actions and true enemy response; %d checks" % ["PASS" if failures == 0 else "FAIL",checks])
	app._stop_audio(); app.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for _index in range(count): await process_frame
func _action(panel) -> void:
	for _index in range(180):
		if not is_instance_valid(panel) or not panel.valid() or not panel.art.is_presenting(): break
		await process_frame
	check(not is_instance_valid(panel) or not panel.valid() or not panel.art.is_presenting(), "Accepted animation ends within bounded frame window")
	await _frames(8)
func _resources() -> Dictionary:
	return {"party":s.party_resource_snapshot(),"coins":s.coins,"xp":s.xp,"medicine":s.medicine,"receipt_stage":s.receipt_stage}
func _verify_runtime() -> void:
	for path in runtime_hashes: check(FileAccess.get_sha256("res://"+path) == runtime_hashes[path], "Frozen runtime byte identity: " + path)
