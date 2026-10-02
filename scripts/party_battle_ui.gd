extends Control
## Full-game adapter: the state accepts and settles; the renderer replays facts.
const Arena = preload("res://scripts/party_battle_art.gd")
const Commands = preload("res://scripts/party_category_hud.gd")
const Pause = preload("res://scripts/pause_menu.gd")
const ENCOUNTER_TITLES = {"story":"渡口问剑", "training":"旧友切磋", "heting_receipt":"复签不撤", "sluice_scout":"半页水令", "sluice_boss":"逆水而行", "archive_boss":"封仓问剑", "mist_scout":"竹坡问路", "mist_keeper":"听雨辨令", "sect_trial":"门中验艺", "courtyard_practice":"南庭演练"}
const ENCOUNTER_LOCATIONS = {"story":"青苇渡 · 蒲横", "training":"青苇渡 · 蒲横", "heting_receipt":"公秤外栈桥 · 实战", "sluice_scout":"废闸栈道 · 截住传令", "sluice_boss":"旧闸栈台 · 罗沉", "archive_boss":"霜桥仓台 · 韩砚", "mist_scout":"雾竹坡 · 巡坡斥候", "mist_keeper":"听雨关 · 守令使", "sect_trial":"练武堂 · 岑远", "courtyard_practice":"练武堂 · 虚拟资源"}
var host
var generation: int
var epoch: int
var session
var encounter: String
var art
var commands
var pending: Dictionary = {}
var pending_action: String = ""
var pending_actor: String = ""
var target_ids: Array = []
var close_pending: bool = false
var notice: String = ""
var logs: Array[String] = []
var _phase_key: String = ""
var unit_plates: Dictionary = {}
var manual_paused: bool = false
var _boundary_wait: float = .35
var _host_notice: String = ""

class UnitPlate extends Button:
	const FONT = preload("res://assets/fonts/NotoSansSC.otf")
	var facts: Dictionary = {}
	var intent: String = ""
	var selected: bool = false
	func status_caption() -> String:
		var status: Dictionary = facts.get("status", {})
		return "卸劲%d · 余%d击" % [int(status.weaken_amount),int(status.weaken_strikes)] if int(status.get("weaken_strikes",0)) > 0 else ""
	func _draw() -> void:
		if facts.is_empty(): return
		var ally: bool = facts.get("team", "") == "ally"
		var title: String = facts.name if ally else "%s  %d/%d" % [facts.name, facts.hp, facts.max_hp]
		var tint = Color("e5c890") if selected else Color("e8dcc2")
		var font_size = 15 if ally else 13
		draw_string_outline(FONT, Vector2(0,17), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color("15231f"))
		draw_string(FONT, Vector2(0,17), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, tint)
		var rail = Rect2(8,22,size.x-16,5)
		draw_rect(rail.grow(1), Color("a79770")); draw_rect(rail, Color("311c19"))
		draw_rect(Rect2(rail.position, Vector2(rail.size.x * float(facts.hp) / maxi(1,int(facts.max_hp)),rail.size.y)), Color("b34b37"))
		if not ally:
			draw_string_outline(FONT, Vector2(0,44), intent, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, 4, Color("15231f"))
			draw_string(FONT, Vector2(0,44), intent, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, tint)
			if not status_caption().is_empty():
				draw_string_outline(FONT, Vector2(0,59), status_caption(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, 4, Color("15231f"))
				draw_string(FONT, Vector2(0,59), status_caption(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("edbf82"))

static func open(owner, kind: String) -> Control:
	if owner.current_screen != "explore" or owner.quit_pending or owner.state.battle_active: return null
	# Every real entry checkpoints before accepting any new combat costs.
	if kind != "courtyard_practice":
		owner._autosave()
		if owner.save_warning: return null
	if not owner.state.start_party_battle(kind): return null
	owner.modal_generation += 1
	owner._clear_overlay()
	owner.active_modal = true
	owner.modal_autosave_on_close = false
	owner.current_screen = "party_battle"
	owner.battle_layer.visible = false
	owner.toast_time = 0
	var panel = load("res://scripts/party_battle_ui.gd").new()
	panel.host = owner; panel.generation = owner.modal_generation
	panel.epoch = owner.state.party_battle_epoch; panel.session = owner.state.party_session; panel.encounter = kind
	owner.overlay.set_meta("party_battle", panel)
	owner.overlay.add_child(panel)
	panel.build()
	owner._refresh()
	return panel

func valid() -> bool:
	return is_instance_valid(host) and is_inside_tree() and not host.quit_pending and host.active_modal \
		and host.current_screen == "party_battle" and host.modal_generation == generation \
		and host.state.party_battle_epoch == epoch and host.state.party_session == session \
		and host.overlay.get_meta("party_battle", null) == self

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	art = Arena.new(); art.size = Vector2(1280, 800); add_child(art)
	art.target_requested.connect(select_target)
	art.event_presented.connect(_event)
	art.presentation_finished.connect(_finished)
	for unit: Dictionary in host.state.party_battle_snapshot().actors + host.state.party_battle_snapshot().enemies:
		var plate = UnitPlate.new(); plate.flat = true; plate.mouse_filter = Control.MOUSE_FILTER_STOP
		for state in ["normal","hover","pressed","disabled","focus"]: plate.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		plate.pressed.connect(select_target.bind(String(unit.id)))
		plate.focus_mode = Control.FOCUS_ALL
		add_child(plate); unit_plates[unit.id] = plate
	commands = Commands.new(); add_child(commands)
	commands.actor_requested.connect(select_actor)
	commands.command_requested.connect(request_command)
	commands.cancel_queue_requested.connect(cancel_skill)
	commands.pause_requested.connect(set_pause_request)
	logs.append("每位存活队员每轮自动普攻一次。可安排武学、内功与轻功，排在该角色下次普攻前；不会替代普攻。")
	art.set_snapshot(host.state.party_battle_snapshot())
	refresh()

func _process(delta: float) -> void:
	if not valid() or art == null: return
	var host_notice: String = host.status_label.text if host.toast_time > 0 else ""
	if host_notice != _host_notice: _host_notice = host_notice; refresh()
	_sync_plates()
	if art.is_presenting():
		var key = art.acting_unit_id + "/" + art.presentation_phase
		if key != _phase_key: _phase_key = key; refresh()
		return
	if not pending.is_empty() or close_pending or not pending_action.is_empty(): return
	var facts = host.state.party_battle_snapshot()
	if not facts.get("active", false) or facts.get("paused", false): return
	_boundary_wait = maxf(0, _boundary_wait - delta)
	if _boundary_wait <= 0:
		var tx = host.state.advance_party_battle()
		if tx.get("accepted", false): _present(tx)
		else: _boundary_wait = .15

func refresh() -> void:
	if not valid(): return
	var snapshot: Dictionary = art.display_snapshot.duplicate(true) if art.is_presenting() else host.state.party_battle_snapshot().duplicate(true)
	var live: Dictionary = host.state.party_battle_snapshot()
	# Resource rails remain on presented event facts. Selection and queued
	# commands are live future choices and may change while that action plays.
	for key in ["selected_actor_id", "paused", "pause_requested", "pending_token"]: snapshot[key] = live.get(key)
	if art.is_presenting():
		for actor: Dictionary in snapshot.actors:
			var current = _unit(live, actor.id)
			for category: String in actor.get("categories", {}):
				var future: Dictionary = current.get("categories", {}).get(category, {})
				for key in ["queued", "queue_round", "action_id", "target_id"]:
					actor.categories[category][key] = future.get(key, actor.categories[category].get(key))
			for action: Dictionary in actor.get("actions", []):
				var future_action: Dictionary = _action(current, action.id)
				for key in ["queued", "queue_round", "queued_target_id"]:
					action[key] = future_action.get(key, action.get(key))
				if action.category in ["martial", "internal", "lightness"]:
					_project_skill_availability(snapshot, actor, action)
				else:
					action.available = false; action.reason = "请待这一招收势。"
	snapshot.locked = art.is_presenting() or not pending.is_empty()
	snapshot.closing = close_pending
	snapshot.log = logs.duplicate()
	var prompt: String = notice
	if host.toast_time > 0: prompt = host.status_label.text
	if not pending_action.is_empty():
		var actor = _unit(snapshot, pending_actor)
		var action = _action(actor, pending_action)
		prompt = "%s · %s：选择队友（点击人物，或Tab换人后Enter确认；Esc取消）" % [actor.get("name", ""), action.get("name", "")]
	if close_pending: prompt = "本次出招收束后退开并保存；保存失败仍会留在游戏。"
	if host.save_warning: prompt = host._save_retry_message()
	elif host.browser_mode and not host.browser_storage_available: prompt = (prompt+"\n" if not prompt.is_empty() else "")+host._browser_storage_message()
	commands.set_snapshot(snapshot, {
		"title": ENCOUNTER_TITLES.get(encounter, "交锋"),
		"input_block_reason": "正在收招退避并保存。" if close_pending else "",
		"location": String(ENCOUNTER_LOCATIONS.get(encounter, ""))+" · "+(String(snapshot.get("formation", "")) if snapshot.actors.size()>1 else "独行"),
		"acting_unit_id": art.acting_unit_id if art.is_presenting() else "",
		"phase_label": {"windup":"起招", "contact":"交锋", "return":"收招", "settle":"收束"}.get(art.presentation_phase, "已暂停" if live.get("paused",false) else "自动交锋"),
		"selected_actor_id":pending_actor, "selected_action_id": pending_action, "target_prompt": prompt,
		"notice": "Q/E选队员 · 1武学/2内功/3轻功 · 4用药 · 5退避 · P暂停 · Tab换目标" if prompt.is_empty() else ""
	})
	_sync_plates()

func _project_skill_availability(snapshot: Dictionary, actor: Dictionary, action: Dictionary) -> void:
	# Only visible facts decide the visual state; the authoritative queue checks
	# the real future boundary again when the player requests a command.
	var reason: String = ""
	var next_round: int = int(snapshot.round) + (1 if actor.get("basic_done", false) else 0)
	if not action.get("learned", false): reason = String(action.get("reason", "尚未习得。"))
	elif int(actor.hp) <= 0: reason = "已倒下。"
	elif action.get("queued", false): reason = "这类技能已排定；可点击取消。"
	elif int(actor.get("categories", {}).get(action.category, {}).get("used_round", 0)) == next_round: reason = "本轮已经用过此类技能。"
	elif next_round < int(action.get("eligible_round", 1)): reason = "调息中；第%d轮可用。" % int(action.eligible_round)
	elif int(actor.qi) < int(action.cost): reason = "真气不足，需要%d点。" % int(action.cost)
	var candidates: Array = snapshot.enemies if action.target_team == "enemy" else snapshot.actors
	var targets: Array[String] = []
	for unit: Dictionary in candidates:
		if int(unit.hp) <= 0 or (action.target_team == "self" and unit.id != actor.id): continue
		if action.target_team in ["ally", "self"] and int(action.effects.get("healing", 0)) > 0 and int(unit.hp) >= int(unit.max_hp):
			if int(action.effects.get("focus_bonus", 0)) <= int(actor.status.get("focused_damage", 0)) and int(action.effects.get("barrier", 0)) == 0: continue
		targets.append(unit.id)
	action.valid_target_ids = targets
	if reason.is_empty() and action.target_team != "none" and targets.is_empty(): reason = "没有可用目标；治疗不能救起倒下者。"
	action.available = reason.is_empty()
	action.reason = reason

func _sync_plates() -> void:
	var facts: Dictionary = commands.snapshot if commands != null and not commands.snapshot.is_empty() else art.display_snapshot
	if facts.is_empty(): return
	var can_choose: bool = valid() and not close_pending and bool(host.state.party_battle_snapshot().get("active",false))
	for id: String in unit_plates:
		var plate = unit_plates[id]
		var unit: Dictionary = _unit(facts, id)
		var area: Rect2 = art.unit_label_rect(id)
		plate.position = area.position; plate.size = area.size
		plate.modulate.a = art.unit_label_alpha(id)
		plate.disabled = not can_choose or int(unit.hp) <= 0 or plate.modulate.a < .1
		var caption = "已倒下" if int(unit.hp) <= 0 else ""
		var details = ""
		for intention: Dictionary in facts.get("enemy_intents", []):
			if intention.source_id != id or int(unit.hp) <= 0: continue
			caption = "%d %s → %s" % [int(intention.order)+1, "护伴" if intention.type=="protect" else ("重击" if intention.heavy else "进攻"), _unit(facts,intention.target_id).get("name", "")]
			details = String(intention.get("description", intention.name))
		var selected = art.selected_id == id
		if plate.facts != unit or plate.intent != caption or plate.selected != selected:
			plate.facts = unit.duplicate(true); plate.intent = caption; plate.selected = selected; plate.tooltip_text = details + ("\n" + plate.status_caption() if not plate.status_caption().is_empty() else ""); plate.queue_redraw()

func _unit(snapshot: Dictionary, id: String) -> Dictionary:
	for unit: Dictionary in snapshot.get("actors", []) + snapshot.get("enemies", []):
		if unit.id == id: return unit
	return {}

func _action(actor: Dictionary, id: String) -> Dictionary:
	for action: Dictionary in actor.get("actions", []):
		if action.id == id: return action
	return {}

func _available() -> bool:
	return valid() and not close_pending and bool(host.state.party_battle_snapshot().get("active", false))

func _safe_boundary() -> bool:
	return _available() and pending.is_empty() and not art.is_presenting() and not host.state.party_battle_snapshot().get("locked",true)

func request_pause() -> void:
	set_pause_request(not manual_paused)

func set_pause_request(paused: bool) -> void:
	if not _available(): return
	manual_paused = paused
	host.state.pause_party_battle(manual_paused or not pending_action.is_empty())
	refresh()

func cancel_skill(actor_id: String, category: String) -> void:
	if _available() and host.state.cancel_party_skill(actor_id, category):
		notice = "已取消排定；没有扣除真气。"; refresh()

func select_actor(id: String) -> void:
	if not _available() or not host.state.select_party_actor(id): return
	_cancel_target(); notice = ""
	art.set_snapshot(host.state.party_battle_snapshot()); refresh()

func select_target(id: String) -> void:
	if not _available(): return
	if not pending_action.is_empty():
		if not target_ids.has(id): notice = "请选择提示中的有效队友。"; refresh(); return
		_accept(pending_action, id); return
	var snapshot = host.state.party_battle_snapshot()
	for actor: Dictionary in snapshot.actors:
		if actor.id == id: select_actor(id); return
	if not host.state.select_party_target(id): return
	art.set_snapshot(host.state.party_battle_snapshot()); refresh()

func cycle_target() -> void:
	if not _available(): return
	var snapshot = host.state.party_battle_snapshot()
	var ids: Array = target_ids.duplicate()
	if pending_action.is_empty():
		for enemy: Dictionary in snapshot.enemies:
			if enemy.hp > 0: ids.append(enemy.id)
	if ids.is_empty(): return
	var index = ids.find(snapshot.selected_target_id)
	if host.state.select_party_target(ids[(index + 1) % ids.size()]):
		art.set_snapshot(host.state.party_battle_snapshot()); refresh()

func cycle_actor(direction: int) -> void:
	if not _available(): return
	var snapshot = host.state.party_battle_snapshot()
	var ids: Array = []
	for actor: Dictionary in snapshot.actors:
		if actor.hp > 0: ids.append(actor.id)
	if ids.is_empty(): return
	select_actor(ids[posmod(ids.find(snapshot.selected_actor_id) + direction, ids.size())])

func request_command(actor_id: String, action_id: String) -> void:
	if not _available() or not host.state.select_party_actor(actor_id): return
	var snapshot = host.state.party_battle_snapshot()
	var action = _action(_unit(snapshot, actor_id), action_id)
	if action.is_empty() or not action.get("available", false):
		notice = String(action.get("reason", "此刻无法出招。")); refresh(); return
	_cancel_target()
	if action.target_team == "ally":
		pending_action = action_id; pending_actor = actor_id; target_ids = action.valid_target_ids.duplicate()
		host.state.pause_party_battle(true)
		if not target_ids.has(snapshot.selected_target_id): host.state.select_party_target(target_ids[0])
		art.set_snapshot(host.state.party_battle_snapshot()); refresh(); return
	var target: String = ""
	if action.target_team == "self": target = actor_id
	elif action.target_team == "enemy":
		target = snapshot.selected_target_id if action.valid_target_ids.has(snapshot.selected_target_id) else String(action.valid_target_ids[0])
	_accept(action_id, target)

func _accept(action_id: String, target: String = "") -> void:
	if not valid(): return
	if action_id not in ["item", "flee"]:
		var actor_id: String = pending_actor if not pending_actor.is_empty() else String(host.state.party_battle_snapshot().selected_actor_id)
		var queued: Dictionary = host.state.queue_party_skill(actor_id, action_id, target)
		if not queued.get("queued",false): notice = String(queued.get("reason","此刻无法排招。")); refresh(); return
		_cancel_target()
		notice = "已排在第%d轮该队员普攻之前；执行时才扣真气。" % int(queued.queue_round)
		refresh(); return
	if not pending.is_empty() or art.is_presenting():
		notice = "药品与退避须待当前招式收束；可用P请求暂停。"; refresh(); return
	var tx: Dictionary = host.state.party_battle_action(action_id, target)
	if not tx.get("accepted", false): notice = String(tx.get("reason", "此刻无法出招。")); refresh(); return
	_cancel_target(); _present(tx)

func _present(tx: Dictionary) -> void:
	pending = tx; notice = ""; _phase_key = ""
	if not art.present(tx):
		notice = "演出未能开始，已接受的行动仍保留；请勿刷新或关闭网页。"; refresh(); return
	refresh()
	if host.audio_on: host.sfx.play()

func _cancel_target() -> void:
	pending_action = ""; pending_actor = ""; target_ids.clear()
	if valid() and host.state.battle_active: host.state.pause_party_battle(manual_paused)

func _event(event: Dictionary) -> void:
	if not valid() or pending.is_empty(): return
	var facts = art.display_snapshot
	var source = String(_unit(facts, event.source_id).get("name", event.source_id))
	var target = String(_unit(facts, event.target_id).get("name", event.target_id))
	var line = ""
	match event.type:
		"damage": line = "%s → %s：%d伤害" % [source, target, event.amount]
		"heal": line = "%s为%s恢复%d气血" % [source, target, event.amount]
		"barrier_grant": line = "%s为%s架起%d护势" % [source, target, event.amount]
		"barrier_absorb": line = "%s护势吸收%d伤害" % [target, event.amount]
		"barrier_expire": line = "%s护势收束" % target
		"down": line = "%s倒下，本次无法再行动" % target
		"guard": line = "%s以武学稳住守势" % source
		"queue_cancel": line = String(event.get("reason", "排定技能已取消，未扣真气"))
		"lightness_grant": line = "%s运起轻功，下一次来击少受%d点" % [source,event.amount]
		"lightness_absorb": line = "%s轻功卸去%d点来击" % [target,event.amount]
		"weaken": line = "%s受到卸劲%d，持续%d次来击" % [target,event.amount,event.strikes]
		"focus": line = "%s蓄锋%d，留给下次自动普攻" % [source,event.amount]
		"vulnerability_apply": line = "%s露出破绽，接下来%d次来击各多受3点伤害；本人守势可解" % [target,event.remaining]
		"vulnerability_expire": line = "%s的破绽已消除" % target
	if not line.is_empty():
		logs.append(line)
		if logs.size() > 60: logs.pop_front()
	refresh()

func _finished() -> void:
	if not valid() or pending.is_empty(): return
	var result = host.state.finish_party_presentation(int(pending.epoch), int(pending.token))
	if not result.get("accepted", false): notice = String(result.get("reason", "本次结算尚未完成。")); refresh(); return
	pending = {}; _boundary_wait = .16
	if result.get("settled", false): _return_to_world(result.settlement); return
	art.set_snapshot(host.state.party_battle_snapshot())
	if close_pending: _accept("flee"); return
	refresh()

func leave() -> void:
	if not _available(): return
	if not pending_action.is_empty(): _cancel_target(); refresh(); return
	_accept("flee")

func request_application_close() -> void:
	if not valid() or close_pending: return
	close_pending = true; _cancel_target()
	if not pending.is_empty() or art.is_presenting(): refresh(); return
	_accept("flee")

func _return_to_world(result: Dictionary) -> void:
	if not valid() or not pending.is_empty() or host.state.battle_active: return
	var owner = host; var close_after = close_pending; var kind = encounter
	if owner.world.map_id != owner.state.map_id: owner.world.change_map(owner.state.map_id, owner.state.position)
	elif result.outcome == "defeat": owner.world.teleport(owner.state.position)
	owner.state.position = owner.world.player_pos
	owner.current_screen = "explore"; owner.modal_autosave_on_close = false
	owner._close_modal()
	if close_after: Pause.save_and_leave(owner, owner.browser_mode); return
	if kind != "courtyard_practice": owner._autosave()
	if kind == "courtyard_practice":
		owner._modal("演练结束", "南庭试招 / 真实资源未变", "演练已收束。真实气血、真气、药品、熟练度与剧情均未改变。", [["再练一次", owner._unified_entry.bind("courtyard_practice",owner.modal_generation+1)], ["回到南庭",owner._close_modal]], true)
		owner.modal_autosave_on_close = false
		return
	if result.outcome == "win" and kind in ["mist_scout","mist_keeper"]: owner.mist_story.battle_victory(kind); return
	if result.outcome == "win" and kind == "sect_trial": owner.sect_progress.victory(); return
	if kind == "heting_receipt":
		var receipt_result = result.duplicate(true)
		receipt_result.stage = int(result.get("receipt_stage", owner.state.receipt_stage))
		owner.receipt_story.after_battle(receipt_result); return
	if result.outcome == "win" and kind == "sluice_scout":
		owner._modal("半页水令", "废闸疑云 / 线索已得", "传令人仓促间遗下账页。上面记录的不是渡税，而是开闸时辰。\n\n有人故意把放水的时刻改到了粮船入港之后。你收好账页。"+("证言与账页已经齐备，可以找东南闸首对质。" if owner.state.side_found.has("boatman") else "接下来需要听听南岸船工的证言。")+"\n\n修为+%d，铜钱+%d。账页与队员状态已一并结算。" % [result.reward_xp,result.coin_change], [["收起账页",func(): owner._close_modal(); owner._autosave()]])
		return
	if result.outcome == "win" and kind == "sluice_boss":
		# HeroState settled both encounter and route rewards atomically. This
		# dialogue displays the result and never calls finish_side_quest again.
		owner._show_sluice_ending("交锋所得：修为+%d、铜钱+35。\n机缘所得：" % int(result.get("battle_reward_xp",70)))
		return
	if result.outcome == "win" and kind == "archive_boss":
		# Stage2→3 is already part of the accepted state settlement. The later
		# ending is deliberately left for a new, guarded choice at the inn.
		owner.chapter_story.show_victory("交锋所得：修为+%d、铜钱+%d。原账与队员状态已一并结算。\n\n" % [result.reward_xp,result.coin_change])
		return
	if result.outcome == "win":
		owner._modal("蒲横收剑", "交锋 / 已分高下", ("蒲横递回账册。回陆伯处，商议这页纸的归处。" if kind == "story" else "这一回切磋已记下。歇妥之后，还可再来较量。") + "\n\n修为+%d，铜钱+%d。各队员的剩余气血与真气已记录。" % [result.reward_xp, result.coin_change])
	elif result.outcome == "defeat":
		owner._modal("先歇一歇", "交锋 / 暂退", "全队已退回安全处，气血恢复，真气至少留2点；本次遗落%d文。药铺可免费调息，备妥再来。" % -int(result.coin_change))
	else: owner._toast("已退开。已用的药品与真气不会返还，各队员状态已记录。")

func _input(event: InputEvent) -> void:
	if not valid() or not event is InputEventKey or not event.pressed: return
	var key: int = event.physical_keycode
	var controlled = key in [KEY_Q, KEY_E, KEY_F, KEY_P, KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_F5, KEY_F6, KEY_F9, KEY_F10] or (key >= KEY_1 and key <= KEY_5) or (key == KEY_TAB and not event.shift_pressed)
	if event.echo:
		if controlled: get_viewport().set_input_as_handled()
		return
	if key in [KEY_ENTER, KEY_SPACE]:
		if not pending_action.is_empty():
			get_viewport().set_input_as_handled()
			if _available(): select_target(host.state.party_battle_snapshot().selected_target_id)
		elif get_viewport().gui_get_focus_owner() == null:
			get_viewport().set_input_as_handled()
		return
	if not controlled: return
	get_viewport().set_input_as_handled()
	if key in [KEY_F5, KEY_F6, KEY_F9, KEY_F10]: notice = "交锋结束后才可存读卷；浏览器刷新不会等候收招。"; refresh(); return
	if key == KEY_ESCAPE: leave(); return
	if not _available(): return
	if key == KEY_P: request_pause(); return
	if key == KEY_TAB: cycle_target(); return
	if key in [KEY_Q, KEY_E]: cycle_actor(-1 if key == KEY_Q else 1); return
	var snapshot = host.state.party_battle_snapshot()
	if key == KEY_F: commands.focus_actor_commands(snapshot.selected_actor_id); return
	var actor = _unit(snapshot, snapshot.selected_actor_id)
	var actions: Array = []
	for category in ["martial","internal","lightness"]:
		var found: String = ""
		for action: Dictionary in actor.actions:
			if action.category == category: found = action.id
		actions.append(found)
	actions.append_array(["item", "flee"])
	var index = key - KEY_1
	if index >= 0 and index < 3 and commands.has_method("request_slot"):
		commands.request_slot(actor.id, index)
	elif index >= 0 and index < actions.size(): request_command(actor.id, actions[index])
