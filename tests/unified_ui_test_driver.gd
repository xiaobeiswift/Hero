extends RefCounted
## Focused feature tests use a prepared legal training checkpoint to inspect
## their menu/display guards in the current controller. This is not a journey
## fixture: natural story earning is exercised by the dedicated journey tests.

static func open_training(host):
	if host.active_modal: host._close_modal()
	if host.state.quest_stage < 4: host.state.quest_stage = 4
	if host.state.quest_stage >= 5 and host.state.ending.is_empty(): host.state.ending = "守望"
	host.state.map_id = "qingwei"
	host.world.change_map("qingwei", Vector2(955, 630))
	host.world.teleport(host.world.interactables.bandit.pos)
	host.state.position = host.world.player_pos
	host._start_battle("training")
	assert(host.current_screen == "party_battle" and host.state.battle_active, "Prepared training must enter the actual unified controller")
	var controller = host.overlay.get_meta("party_battle")
	controller.set_process(false)
	controller.art.set_process(false)
	return controller

static func leave(host) -> void:
	assert(host.current_screen == "party_battle" and host.overlay.has_meta("party_battle"))
	var controller = host.overlay.get_meta("party_battle")
	controller.leave()
	if controller.art.is_presenting(): controller.art._process(controller.art.get_presentation_duration() + .1)
	assert(not host.state.battle_active, "Actual utility/renderer acknowledgement must settle retreat")

static func active(host) -> bool:
	return host.current_screen == "party_battle" and host.overlay.has_meta("party_battle") and host.overlay.get_meta("party_battle").valid()

static func begin_step(host, tactics: bool = true) -> Dictionary:
	assert(active(host), "A scheduler step needs the current controller")
	var panel = host.overlay.get_meta("party_battle")
	panel.set_process(false); panel.art.set_process(false)
	if not panel.pending.is_empty(): return panel.pending
	var snapshot: Dictionary = host.state.party_battle_snapshot()
	if tactics:
		for actor: Dictionary in snapshot.actors:
			if actor.hp <= 0: continue
			for action: Dictionary in actor.actions:
				if action.id == "item" and action.available and actor.hp < actor.max_hp * .35:
					panel.request_command(actor.id, "item")
					if not panel.pending.is_empty(): return panel.pending
			if actor.basic_done: continue
			for action: Dictionary in actor.actions:
				if action.category != "martial" or not action.available or action.queued: continue
				var target: String = ""
				if bool(action.effects.get("guard", false)):
					var heavy: bool = false
					for intent: Dictionary in snapshot.enemy_intents: heavy = heavy or bool(intent.get("heavy", false))
					if not heavy and actor.status.get("vulnerability_hits", 0) == 0: continue
				if snapshot.encounter_id == "sect_trial" and action.effects.get("healing", 0) > 0 and actor.hp == actor.max_hp: continue
				if action.target_team == "enemy" and not action.valid_target_ids.is_empty(): target = action.valid_target_ids[0]
				elif action.target_team == "self": target = actor.id
				elif action.target_team == "ally":
					for ally: Dictionary in snapshot.actors:
						if action.valid_target_ids.has(ally.id) and ally.hp <= ally.max_hp - 20: target = ally.id
				if target.is_empty(): continue
				if action.target_team == "enemy": panel.select_target(target)
				panel.request_command(actor.id, action.id)
				if not panel.pending_action.is_empty(): panel.select_target(target)
	panel._process(1.0)
	return panel.pending

static func finish_step(host) -> void:
	var panel = host.overlay.get_meta("party_battle")
	assert(not panel.pending.is_empty() and panel.art.is_presenting(), "Actual scheduler transaction must be presenting")
	panel.art._process(panel.art.get_presentation_duration() + .1)

static func step(host, tactics: bool = true) -> Dictionary:
	var transaction: Dictionary = begin_step(host, tactics)
	assert(transaction.get("accepted", false), "Actual controller must accept scheduler transaction")
	finish_step(host)
	return transaction
