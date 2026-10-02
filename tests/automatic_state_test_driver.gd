extends RefCounted
## Deterministic test driver for the production automatic scheduler. Every
## returned transaction is created by advance_party_battle / a real utility;
## it never fabricates events or turns a manual attack into a runtime command.

static func tactical_next(state) -> Dictionary:
	var snapshot: Dictionary = state.party_battle_snapshot()
	for actor: Dictionary in snapshot.actors:
		if actor.hp <= 0: continue
		if actor.hp < actor.max_hp / 2 and snapshot.medicine > 0:
			for action: Dictionary in actor.actions:
				if action.id == "item" and action.available:
					state.select_party_actor(actor.id)
					return state.party_battle_action("item", actor.id)
		for action: Dictionary in actor.actions:
			if action.category != "martial" or not action.available or action.queued: continue
			var target: String = ""
			if action.target_team == "enemy" and not action.valid_target_ids.is_empty():
				target = action.valid_target_ids[0]
			elif action.target_team == "ally":
				for ally: Dictionary in snapshot.actors:
					if action.valid_target_ids.has(ally.id) and ally.hp <= ally.max_hp - 20:
						target = ally.id
			if not target.is_empty():
				var queued: Dictionary = state.queue_party_skill(actor.id, action.id, target)
				if not queued.get("queued", false): return queued
	return state.advance_party_battle()

static func queued_next(state, actor_id: String, action_id: String, target: String) -> Dictionary:
	var queued: Dictionary = state.queue_party_skill(actor_id, action_id, target)
	if not queued.get("queued", false): return queued
	for index: int in range(80):
		var tx: Dictionary = state.advance_party_battle()
		if not tx.get("accepted", false) or tx.source_id == actor_id and tx.action_id == action_id or not tx.after.active:
			return tx
		if not state.finish_party_presentation(tx.epoch, tx.token).accepted: return {}
	return {}

static func terminal_next(state) -> Dictionary:
	for index: int in range(400):
		var tx: Dictionary = state.advance_party_battle()
		if not tx.get("accepted", false) or not tx.after.active: return tx
		if not state.finish_party_presentation(tx.epoch, tx.token).accepted: return {}
	return {}
