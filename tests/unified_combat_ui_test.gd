extends SceneTree
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/game_state.gd")
const Encounters = preload("res://scripts/unified_encounter_rules.gd")
const CombatUI = preload("res://scripts/party_battle_ui.gd")
const Slots = preload("res://scripts/local_save_slots.gd")
class State extends Model:
	var fixture: String
	var fail_writes: bool = false
	var writes: int = 0
	func save_game(path: String = SAVE_PATH) -> Error:
		writes += 1
		if fail_writes: return ERR_CANT_CREATE
		return super.save_game(fixture + "/save.json" if path == SAVE_PATH else path)
	func load_game(path: String = SAVE_PATH) -> Error:
		return super.load_game(fixture + "/save.json" if path == SAVE_PATH else path)
	func has_save() -> bool: return FileAccess.file_exists(fixture + "/save.json")
class CloseProbe extends Main:
	var exits: int = 0
	func _quit_cleanly(_save_progress: bool = true) -> void:
		if not quit_pending: exits += 1; quit_pending = true
var app
var s: State
var checks = 0
var failures = 0
var fixture: String
func _initialize()->void: _run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("Unified UI: "+message)
func _prepared(id:String,count:int=1):
	var s=State.new()
	if id=="story":
		s.quest_stage=3
	else:
		s.quest_stage=6;s.ending="守望";s.choose_sect("听潮阁");s.gain_xp(900)
		s.side_stage=3;s.side_choice="rescue";s.side_clues=2;s.side_found.assign(["boatman","ledger"]);s.side_reward_claimed=true
		s.chapter_two_stage=4;s.chapter_two_ending="protect_witness";s.archive_clues.assign(["clerk","inscription"]);s.seal_sequence.assign([2,0,1]);s.bridge_repaired=true
	if count>=2:check(s.recruit_companion(),"Explicit Shen invitation")
	if count>=3:
		check(s.begin_tangqi_quest() and s.recover_craft_notes() and s.resolve_tangqi_quest("teach") and s.recruit_tangqi(),"Explicit Tang quest/invitation")
	if count==4:
		# Completed-story capacity fixture, not an early-story recruitment claim.
		s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water";s.map_id="mistwood"
		check(s.begin_qin_quest() and s.inspect_qin_rope() and s.arrange_qin_handoff() and s.recruit_qin(),"Actual Qin quest/invitation registers resources on completed-story fixture")
	var ids:Array=["hero","shen","tang","qin"].slice(0,count)
	check(s.set_party_roster(ids),"Explicit occupied roster")
	match id:
		"sluice_scout":s.side_stage=1;s.side_clues=0;s.side_found.clear();s.side_reward_claimed=false;s.chapter_two_stage=0;s.chapter_two_ending="";s.archive_clues.clear();s.seal_sequence.clear();s.bridge_repaired=false
		"sluice_boss":s.side_stage=2;s.side_reward_claimed=false;s.chapter_two_stage=0;s.chapter_two_ending="";s.archive_clues.clear();s.seal_sequence.clear();s.bridge_repaired=false
		"archive_boss":s.chapter_two_stage=2;s.chapter_two_ending="";s.bridge_repaired=false
		"mist_scout":s.mist_stage=1;s.mist_approach="";s.mist_gauges.clear();s.mist_ending=""
		"mist_keeper":s.mist_stage=2;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending=""
		"heting_receipt":
			s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water"
			s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries";s.receipt_stage=1
		"heting_consignee":
			s.mist_stage=4;s.mist_approach="duel";s.mist_gauges.assign(["rain","stone","basin"]);s.mist_ending="release_water"
			s.heting_stage=4;s.heting_bridge="east";s.heting_delivered.assign(["meal","sealed","reserve"]);s.heting_draft="short_ferries";s.heting_ending="short_ferries"
			s.map_id="heting";s.position=Vector2(420,450)
			# Phase-one prepared model; this does not assert a playable chapter scene.
			check(s.begin_consignee(),"Prepared completed Heting can begin consignee")
			for observation:String in ["lot_seals","removal_order","southern_counterfoil"]:
				check(s.observe_consignee(observation),"Actual solo observation "+observation)
			check(s.resolve_consignee_contradiction("order_before_inspection").ok,"Actual contradiction resolution")
			check(s.choose_consignee_plan("hold_for_inspection"),"Actual reversible draft before battle")
	s.map_id=Encounters.LOCATIONS[id][0];s.position=Vector2(420,450)
	check(s._stage_save_data(s.to_dict(),State.SAVE_VERSION).ok,"Prepared %s state is canonical"%id)
	return s
func _finish(panel) -> void:
	if is_instance_valid(panel) and panel.art.is_presenting(): panel.art._process(panel.art.get_presentation_duration() + .1)

func _key(key: Key, echo: bool = false) -> void:
	var event = InputEventKey.new(); event.physical_keycode = key; event.keycode = key; event.pressed = true; event.echo = echo
	Input.parse_input_event(event); await process_frame
	event.pressed = false; event.echo = false; Input.parse_input_event(event)

func _click(control: Control) -> void:
	var center: Vector2 = control.get_global_rect().get_center()
	center = root.get_final_transform() * center
	var event = InputEventMouseButton.new(); event.position = center; event.global_position = center; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event.pressed = false; Input.parse_input_event(event); await process_frame

func _actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id: return actor
	return {}

func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = _button(child, text)
		if found != null: return found
	return null
func _setup(kind:String,count:int=1)->void:
	app.quit_pending=false;app.exits=0;app.current_screen="explore";app.active_modal=false;app._clear_overlay()
	s=_prepared(kind,count);s.fixture=fixture;app.state=s
	var location:Array=Encounters.LOCATIONS[kind]
	app.world.change_map(location[0],Vector2(420,450))
	app._sync_world_state()
	app.world.teleport(app.world.interactables[location[1]].pos+Vector2(0,24))
	s.position=app.world.player_pos
	app._process(0);app._refresh()
func _step_view(panel)->void:
	if not is_instance_valid(panel):return
	if panel.art.is_presenting():_finish(panel)
	elif panel.valid():panel._process(.5)
func _run()->void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	fixture="user://unified-ui-%d"%OS.get_process_id();DirAccess.make_dir_recursive_absolute(fixture)
	s=State.new();s.fixture=fixture
	app=load("res://scenes/main.tscn").instantiate();app.set_script(CloseProbe);app.state=s
	root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false;app.world.set_process(false)
	for kind:String in Encounters.IDS:
		_setup(kind,2 if kind=="story" else 1)
		await _key(KEY_E)
		check(app.active_modal,"E opens actual entry dialogue: "+kind)
		if kind == "heting_receipt":
			var next = _button(app.overlay,"复签应战准备")
			check(next != null,"Harbor retains explicit optional receipt entry")
			if next != null: await _click(next)
		await _key(KEY_1)
		var panel=app.overlay.get_meta("party_battle") if app.overlay.has_meta("party_battle") else null
		check(panel!=null and app.current_screen=="party_battle","Actual dialogue enters same controller: "+kind)
		if panel==null:continue
		panel.set_process(false);panel.art.set_process(false)
		check(panel.encounter==kind and panel.session.get_script().resource_path.ends_with("automatic_party_combat.gd"),"Same controller/model identity")
		for actor:Dictionary in panel.commands.snapshot.actors:
			check(panel.commands._slots(actor).size()==3,"Exactly3 fixed skill slots")
			for category:String in ["martial","internal","lightness"]:
				var slot=panel.commands.slot_descriptor(actor.id,category)
				check(slot.category==category and slot.id not in ["attack","guard"],"Slot category cannot become basic/guard")
		panel.set_pause_request(true)
		var before=s.to_dict();root.gui_release_focus();await _key(KEY_ENTER);await _key(KEY_SPACE)
		check(s.to_dict()==before and panel.pending.is_empty(),"Unfocused Enter/Space cannot manual attack")
		panel.set_pause_request(false);panel._process(.5)
		check(not panel.pending.is_empty() and panel.pending.action_id=="attack","No-input controller starts automatic basic")
		var action=panel.pending;var snapshot=s.party_battle_snapshot()
		check(panel.commands.context.acting_unit_id==panel.art.acting_unit_id,"Acting phase derives from actual renderer")
		await _key(KEY_1,true);check(s.party_battle_snapshot()==snapshot,"Held key cannot duplicate a queue/action")
		_finish(panel)
		var after=s.to_dict();panel._finished();check(s.to_dict()==after,"Duplicate renderer completion cannot replay")
		panel.leave();_finish(panel)
		check(not s.battle_active and app.current_screen=="explore","Every route returns through shared settlement")
		await process_frame
	await _queue_and_pause()
	await _save_close()
	await _real_close_decisions()
	await _presented_queue_facts()
	await _practice_persistence()
	await _viewport_input_matrix()
	_legacy_route_guard()
	app._stop_audio();app.queue_free();await process_frame
	print("%s: %d unified full-game entry/input/queue/pause/close checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
func _queue_and_pause()->void:
	_setup("heting_receipt",4);s.learn_internal_skill();s.learn_lightness()
	check(app._start_unified_battle("heting_receipt"),"Shared receipt entry")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
	panel.set_pause_request(true)
	check(panel.commands.groups.size()==4,"Four actual occupied command groups")
	await _click(panel.commands.actor_buttons.qin)
	check(s.party_battle_snapshot().selected_actor_id=="qin","Actual selector chooses Qin")
	await _key(KEY_1)
	check(panel.pending_action=="art:qin_shoudu" and s.party_battle_snapshot().paused,"Ally skill opens safe paused target flow")
	var qi_before=_actor(s.party_battle_snapshot(),"qin").qi
	await _click(panel.unit_plates.hero)
	check(_actor(s.party_battle_snapshot(),"qin").categories.martial.queued and _actor(s.party_battle_snapshot(),"qin").qi==qi_before,"Queue exact ally without early cost")
	await _key(KEY_1)
	check(not _actor(s.party_battle_snapshot(),"qin").categories.martial.queued,"Same slot cancels queued category")
	panel.request_command("qin","art:qin_shoudu");panel.select_target("hero")
	panel.set_pause_request(false);panel._process(.5)
	check(panel.pending.source_id=="hero" and panel.pending.action_id=="attack","Queued Qin does not steal hero automatic order")
	await _click(panel.commands.actor_buttons.tang)
	check(s.party_battle_snapshot().selected_actor_id=="tang" and panel.commands.context.acting_unit_id=="hero","Selection during animation is distinct from acting actor")
	await _key(KEY_3)
	check(_actor(s.party_battle_snapshot(),"tang").categories.lightness.queued,"Real lightness key queues during animation")
	await _key(KEY_P)
	check(s.party_battle_snapshot().pause_requested and not s.party_battle_snapshot().paused,"Pause waits for accepted action")
	_finish(panel)
	check(s.party_battle_snapshot().paused and panel.pending.is_empty(),"Safe boundary pauses after exactly one action")
	var sequence=s.party_battle_snapshot().action_sequence;panel._process(10)
	check(s.party_battle_snapshot().action_sequence==sequence,"Paused time never advances model")
	await _key(KEY_P)
	for i in range(30):
		if s.party_battle_snapshot().round>=2:break
		_step_view(panel)
	if panel.art.is_presenting():_finish(panel)
	check(_actor(s.party_battle_snapshot(),"qin").cooldowns.get("art:qin_shoudu",0)==2,"Fresh martial cooldown retains full value at cast round end")
	check(s.party_battle_snapshot().round>=2,"Unpaused rounds progress without manual turns")
	panel.leave();_finish(panel);await process_frame
func _save_close()->void:
	_setup("training",4);s.fail_writes=true;var original=s.to_dict()
	check(not app._start_unified_battle("training") and not s.battle_active and s.to_dict()==original,"Failed checkpoint prevents entry without costs")
	s.fail_writes=false;check(app._start_unified_battle("training"),"Entry retry succeeds")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false);panel._process(.5)
	s.fail_writes=true;app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(panel.close_pending and app.exits==0,"Close waits for accepted automatic basic")
	_finish(panel)
	check(panel.pending.action_id=="flee","Close schedules only retreat after accepted action")
	_finish(panel)
	check(app.exits==0 and app.save_warning and not s.battle_active,"Save failure retains settled game")
	var settled=s.to_dict();var retry=_button(app.overlay,"重试保存")
	check(retry!=null,"Failed close provides retry")
	if retry!=null:retry.pressed.emit()
	check(s.to_dict()==settled and app.exits==0,"Failed retry does not add another basic or reward")
	s.fail_writes=false;retry=_button(app.overlay,"重试保存")
	if retry!=null:retry.pressed.emit()
	check(app.exits==1 and s.to_dict()==settled,"Successful retry exits once with exact settled state")

func _real_close_decisions()->void:
	for discard in [false,true]:
		_setup("training",4)
		check(app._start_unified_battle("training"),"Real disk close fixture enters")
		var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
		var path=fixture+"/save.json";var original=FileAccess.get_file_as_bytes(path)
		panel.commands.request_slot("hero",0);panel._process(.5)
		check(panel.pending.action_id.begins_with("art:"),"Accepted actual resource-consuming skill")
		check(DirAccess.make_dir_absolute(path+".tmp")==OK,"Inject temporary-file failure without touching original save")
		app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_finish(panel);_finish(panel)
		check(app.exits==0 and app.save_warning and FileAccess.get_file_as_bytes(path)==original,"Failed real write preserves original bytes and does not exit")
		var terminal=s.to_dict();var stale=app.modal_actions[0]
		await _key(KEY_2)
		check(app.exits==0 and app.overlay.get_meta("pause_menu",false) and s.to_dict()==terminal,"Cancel exit retains the settled current journey")
		stale.call();check(app.exits==0 and s.to_dict()==terminal,"Stale failure callback cannot resume or duplicate combat")
		app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		if discard:
			await _key(KEY_3);check(app.exits==0,"Discard requires its explicit confirmation")
			await _key(KEY_1);check(app.exits==0,"Cancel discard returns without data loss")
			app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST);await _key(KEY_3);await _key(KEY_2)
			check(app.exits==1 and FileAccess.get_file_as_bytes(path)==original,"Confirmed discard exits once and preserves earlier good save")
		else:
			check(DirAccess.rename_absolute(path+".tmp",path+".injected-blocker")==OK,"Retire only owned synthetic blocker")
			await _key(KEY_1)
			check(app.exits==1 and JSON.parse_string(FileAccess.get_file_as_string(path)).player.qi==s.qi and s.to_dict()==terminal,"Real retry writes exact settled state and exits once")
		var blocker=path+(".tmp" if discard else ".injected-blocker")
		check(DirAccess.remove_absolute(blocker)==OK,"Remove only empty test-created blocker")

func _presented_queue_facts()->void:
	_setup("heting_receipt",4);s.internal_unlocked=true;s.lightness_unlocked=true
	check(app._start_unified_battle("heting_receipt"),"Fact projection fixture enters")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
	panel.commands.request_slot("hero",0);panel._process(.5)
	var tx=panel.pending;var art_id=tx.action_id
	check(_actor(panel.commands.snapshot,"hero").qi==_actor(tx.before,"hero").qi,"HUD cost does not appear before payment beat")
	check(_actor(panel.commands.snapshot,"hero").cooldowns[art_id]==_actor(tx.before,"hero").cooldowns[art_id],"HUD cooldown does not reveal after snapshot before action beat")
	panel.select_actor("tang");panel.commands.request_slot("tang",2)
	check(_actor(panel.commands.snapshot,"tang").categories.lightness.queued and panel.commands.snapshot.selected_actor_id=="tang","Future selection/queue is live during presented action")
	check(_actor(panel.commands.snapshot,"hero").qi==_actor(tx.before,"hero").qi,"Queue refresh preserves presented resource rails")
	panel.art._process(.03);panel.refresh()
	check(_actor(panel.commands.snapshot,"hero").cooldowns[art_id]>0 and _actor(panel.commands.snapshot,"hero").qi==_actor(tx.before,"hero").qi,"Cooldown appears on actual action beat, payment still awaits its beat")
	panel.art._process(.1);panel.refresh()
	check(_actor(panel.commands.snapshot,"hero").qi==_actor(tx.after,"hero").qi,"Payment beat displays exact cost")
	_finish(panel);panel.leave();_finish(panel);await process_frame

func _practice_persistence()->void:
	_setup("courtyard_practice",4);s.hp-=12;s.qi=1;s.medicine=2
	check(s.save_game()==OK,"Save real resources before rehearsal")
	var original=s.to_dict();var bytes=FileAccess.get_file_as_bytes(fixture+"/save.json")
	check(app._start_unified_battle("courtyard_practice"),"Shared rehearsal opens")
	var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false)
	panel.commands.request_slot("hero",0);panel._process(.5);_finish(panel)
	panel.leave();_finish(panel)
	check(s.to_dict()==original and FileAccess.get_file_as_bytes(fixture+"/save.json")==bytes,"Shared rehearsal action/flee cannot spend real resources or rewrite saved bytes")
	await process_frame

func _legacy_route_guard()->void:
	var source=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(not source.contains("ReceiptUI.open(") and not source.contains("CourtyardPractice.open("),"Normal main has no alternate receipt/practice controller entry")
	var begin=source.find("func _start_battle(");var end=source.find("\nfunc ",begin+1)
	var body=source.substr(begin,end-begin)
	check(body.contains("_start_unified_battle") and not body.contains("state.start_battle("),"Legacy-named scene entry only redirects shared controller")
	check(not source.contains('current_screen = "battle"') and not source.contains('current_screen="battle"'),"Normal flow cannot activate legacy battle screen")
	var core=load("res://scripts/automatic_party_combat.gd")
	check(core.SUPPORTED_ENCOUNTERS==Encounters.IDS,"Every known encounter and rehearsal uses the one shared catalog")
	_setup("training",1)
	check(not app._start_unified_battle("unknown") and app.current_screen=="explore" and not s.battle_active,"Unknown scene route never opens fallback battle")

func _viewport_input_matrix()->void:
	for window:Vector2i in [Vector2i(1280,800),Vector2i(1179,737)]:
		root.size=window;await process_frame
		for count in range(1,5):
			_setup("heting_receipt",count);s.learn_internal_skill();s.learn_lightness()
			check(app._start_unified_battle("heting_receipt"),"Viewport/roster entry")
			var panel=app.overlay.get_meta("party_battle");panel.set_process(false);panel.art.set_process(false);panel.set_pause_request(true)
			var before=s.to_dict()
			for enemy_id in ["striker","bracer"]:
				await _click(panel.unit_plates[enemy_id])
				check(s.party_battle_snapshot().selected_target_id==enemy_id,"Actual compact/full enemy-nameplate click selects exact target")
			check(panel.commands.groups.size()==count,"No absent group at compact/full window")
			for id in s.party_roster:
				await _click(panel.commands.actor_buttons[id])
				check(s.party_battle_snapshot().selected_actor_id==id,"Actual scaled portrait click selects exact actor")
				for category in ["martial","internal","lightness"]:
					var button:Button=panel.commands.buttons[panel.commands.slot_key(id,category)]
					var physical:Rect2=root.get_final_transform()*button.get_global_rect()
					check(physical.size.x>=44 and physical.size.y>=44,"Every actual skill target stays at least44px")
				var light_button:Button=panel.commands.buttons[panel.commands.slot_key(id,"lightness")]
				await _click(light_button)
				check(_actor(s.party_battle_snapshot(),id).categories.lightness.queued,"Actual scaled skill click queues exact actor")
				await _key(KEY_3,true)
				check(_actor(s.party_battle_snapshot(),id).categories.lightness.queued,"Echo does not cancel or duplicate queue")
				await _key(KEY_3)
				check(not _actor(s.party_battle_snapshot(),id).categories.lightness.queued,"Fixed category key cancels same queued slot")
				check(s.to_dict()==before,"Queue/selection/layout never spends persistent resources")
			panel.leave();_finish(panel);await process_frame
	root.size=Vector2i(1280,800);await process_frame
