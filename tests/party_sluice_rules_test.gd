extends SceneTree
## Detached rules only. Prepared recruitment flags select real catalog actors;
## hero growth, arts, costs, HP, shields and every attack use production rules.
const State = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Rules = preload("res://scripts/party_combat_rules.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
var checks: int = 0
var failures: int = 0


func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use an isolated XDG_DATA_HOME")
		quit(2)
		return
	_test_templates_and_legacy()
	_test_rosters_and_intents()
	_test_vulnerability_and_guard()
	_test_rotating_recipient()
	_test_guard_arts()
	_test_barriers_and_consumption()
	_test_weaken_and_cooldown_ownership()
	_test_downed_and_terminal_status()
	if failures == 0:
		print("PASS: %d sluice party rules checks (legal1–4/formation/intents/actual recipients/guard/arts/barrier/vulnerability/legacy)" % checks)
	else:
		push_error("FAIL: %d of %d sluice party rules checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _source(formation: String = "护后", level: int = 1):
	var source = State.new()
	if level > 1:
		source.gain_xp(30 * level * (level - 1))
		check(source.level == level, "Real XP progression reaches prepared hero level")
	# Explicit prepared eligibility, never a claim of earned story recruitment.
	source.companion_unlocked = true
	source.tangqi_unlocked = true
	source.qin_stage = 4
	source.qin_unlocked = true
	source.formation = formation
	return source


func _arena(source, ids: Array = ["hero"], encounter: String = "sluice_boss", resources: Dictionary = {}):
	var built: Dictionary = Catalog.build_team(source, ids, resources)
	check(built.ok, "Real catalog validates prepared roster " + str(ids))
	var rules = Rules.new()
	check(rules.configure(built.team, encounter), "Known encounter accepts detached catalog team " + encounter)
	return rules


func _actor(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors:
		if actor.id == id:
			return actor
	return {}


func _events(tx: Dictionary, type: String, phase: String = "") -> Array:
	var result: Array = []
	for event: Dictionary in tx.get("events", []):
		if event.type == type and (phase.is_empty() or event.phase == phase):
			result.append(event)
	return result


func _step(rules, action: String = "guard", target: String = "") -> Dictionary:
	var tx: Dictionary = rules.accept_action(action, target)
	check(tx.ok, "Accepted legal action " + action + " " + target + ": " + String(tx.get("reason", "")))
	if not tx.ok:
		return tx
	# A renderer can reconstruct every counter change from accepted events.
	var counters: Dictionary = {}
	for actor: Dictionary in tx.before.actors:
		counters[actor.id] = int(actor.status.get("vulnerability_hits", 0))
	for event: Dictionary in tx.events:
		if event.type in ["vulnerability_apply", "vulnerability_consume", "vulnerability_expire"]:
			check(counters.has(event.target_id) and event.remaining >= 0 and event.remaining <= 2, "Status event names a real actor and bounded remaining count")
			if event.type == "vulnerability_consume":
				check(event.amount == 1 and event.bonus == 3 and event.remaining == int(counters[event.target_id]) - 1, "Consumption reports exactly one previous incoming hit")
			elif event.type == "vulnerability_apply":
				check(event.amount == 2 and event.remaining == 2 and event.bonus == 3, "Application reports the authoritative two-hit counter")
			else:
				check(event.amount == counters[event.target_id] and event.remaining == 0, "Expiry reports only actual remaining status")
			counters[event.target_id] = int(event.remaining)
	for actor: Dictionary in tx.after.actors:
		check(int(counters[actor.id]) == int(actor.status.get("vulnerability_hits", 0)), "Accepted event playback exactly rebuilds counter for " + actor.id)
	check(rules.complete_presentation(tx.token), "Exact token unlocks accepted action once")
	return tx


func _guard_round(rules) -> Dictionary:
	var round_before: int = int(rules.snapshot().round)
	var last: Dictionary = {}
	for index: int in Catalog.MAX_PARTY_SIZE:
		if not rules.snapshot().active or int(rules.snapshot().round) != round_before:
			break
		last = _step(rules)
	return last


func _test_templates_and_legacy() -> void:
	var expected: Dictionary = {
		"story": [{"id": "puheng", "name": "蒲横 · 河帮执事", "hp": 96, "attack": 9, "heavy_attack": 19}],
		"training": [{"id": "puheng", "name": "蒲横 · 切磋", "hp": 64, "attack": 9, "heavy_attack": 19}],
		"heting_receipt": [{"id": "striker", "name": "截签刀客", "hp": 190, "attack": 22, "heavy_attack": 34}, {"id": "bracer", "name": "架刀护手", "hp": 110, "attack": 14, "heavy_attack": 14}],
		"sluice_scout": [{"id": "sluice_scout", "name": "旧闸巡哨", "hp": 85, "attack": 11, "heavy_attack": 22}],
		"sluice_boss": [{"id": "sluice_boss", "name": "河帮闸首", "hp": 150, "attack": 16, "heavy_attack": 28}],
		"archive_boss": [{"id": "archive_boss", "name": "韩砚 · 仓门执事", "hp": 205, "attack": 17, "heavy_attack": 31}],
	}
	check(Rules.ENCOUNTERS == expected, "Existing encounter templates retain exact names/stats alongside the archive adapter")
	for id: String in ["story", "training", "heting_receipt"]:
		var rules = _arena(_source(), ["hero"], id)
		var snap: Dictionary = rules.snapshot()
		check(not snap.actors[0].status.has("vulnerability_hits"), "Original encounter snapshot shape stays unchanged: " + id)
		check(snap.enemy_intents[0].name == ("探刃截签" if id == "heting_receipt" else "疾刃"), "Original first intent remains unchanged")
		for round_index: int in 2:
			var tx: Dictionary = _step(rules)
			var expected_damage: int = ([6, 9] if id == "heting_receipt" else [2, 5])[round_index]
			check(_events(tx, "damage", "enemy").size() == 1 and _events(tx, "damage", "enemy")[0].amount == expected_damage, "Original light/heavy guard arithmetic remains exact")
			check(_events(tx, "vulnerability_apply").is_empty() and _events(tx, "vulnerability_consume").is_empty() and _events(tx, "vulnerability_expire").is_empty(), "Original encounters emit no new status events")
			check(_events(tx, "protect").size() == (1 if id == "heting_receipt" else 0), "Existing protector behavior remains unchanged")
	check(not Rules.new().configure(Catalog.build_team(_source(), ["hero"]).team, "unknown"), "Unknown encounter still rejects")


func _test_rosters_and_intents() -> void:
	for encounter: String in ["sluice_scout", "sluice_boss"]:
		for formation: String in ["并肩", "护后"]:
			for count: int in range(1, 5):
				var source = _source(formation)
				var saved: Dictionary = source.to_dict().duplicate(true)
				var ids: Array = Catalog.IDS.slice(0, count)
				var rules = _arena(source, ids, encounter)
				for round_index: int in 4:
					var before: Dictionary = rules.snapshot()
					var intent: Dictionary = before.enemy_intents[0]
					var receiver: String = ids[round_index % count] if formation == "并肩" else "hero"
					var raw: int = ([11, 22] if encounter == "sluice_scout" else [16, 28])[round_index % 2]
					check(intent.source_id == encounter and intent.target_id == receiver and intent.target_order.size() == count, "Readable target and fallback order use actual roster/formation")
					check(intent.heavy == (round_index % 2 == 1) and intent.damage == raw and intent.description.contains(str(raw)), "Alternating intent states exact light/heavy base damage")
					check(intent.description.contains("破绽2次") == (encounter == "sluice_boss" and intent.heavy), "Only boss heavy announces two-hit vulnerability")
					for actor: Dictionary in before.actors:
						check(actor.exposed == (actor.id == receiver) and actor.status.vulnerability_hits == 0, "Target-priority boolean is independent of damage vulnerability")
						check(actor.front == (formation == "并肩" or actor.id == "hero"), "Formation rows remain stable")
					for actor_index: int in count:
						var tx: Dictionary = _step(rules)
						check(_events(tx, "damage", "enemy").size() == (1 if actor_index == count - 1 else 0), "Enemy phase waits for every living actor exactly once")
						if actor_index == count - 1:
							var damage: Dictionary = _events(tx, "damage", "enemy")[0]
							var actual: int = maxi(1, int(ceil(float(maxi(1, raw - int(_actor(before, receiver).defense))) * 0.3)))
							check(damage.target_id == receiver and damage.amount == actual and _events(tx, "vulnerability_apply").is_empty(), "Announced recipient takes exact guarded damage and no new vulnerability")
				check(source.to_dict() == saved, "Detached four-round probe changes no source save, costs or quest state")


func _test_vulnerability_and_guard() -> void:
	var rules = _arena(_source())
	_step(rules)
	var heavy: Dictionary = _step(rules, "attack", "sluice_boss")
	check(_events(heavy, "damage", "enemy")[0].amount == 24 and _actor(heavy.after, "hero").status.vulnerability_hits == 2, "Unguarded heavy deals24 then applies2; it does not boost itself")
	check(_events(heavy, "vulnerability_apply")[0].target_id == "hero" and _events(heavy, "vulnerability_apply")[0].source_id == "sluice_boss", "Application identifies actual source and recipient")
	var before: Dictionary = rules.snapshot()
	check(not rules.accept_action("attack", "puheng").ok and rules.snapshot() == before, "Invalid old opponent cannot cost or consume new status")
	check(not rules.accept_action("unknown").ok and rules.snapshot() == before, "Invalid action cannot tick vulnerability")
	var light: Dictionary = _step(rules, "attack", "sluice_boss")
	check(_events(light, "damage", "enemy")[0].amount == 15 and _actor(light.after, "hero").status.vulnerability_hits == 1, "Next light deals12+3 and consumes one hit")
	check(rules.action_description("guard").contains("清除自身破绽"), "Guard descriptor states actual clearing and prevention")
	var guard: Dictionary = _step(rules)
	check(_events(guard, "vulnerability_expire")[0].reason == "guard" and _events(guard, "damage", "enemy")[0].amount == 8, "Guard clears before the heavy's24 damage becomes ceil30percent=8")
	check(_actor(guard.after, "hero").status.vulnerability_hits == 0 and _events(guard, "vulnerability_apply").is_empty(), "Guarded heavy cannot reapply")
	var refreshed = _arena(_source())
	_step(refreshed)
	_step(refreshed, "attack", "sluice_boss")
	_step(refreshed, "attack", "sluice_boss")
	var refresh: Dictionary = _step(refreshed, "attack", "sluice_boss")
	check(_events(refresh, "damage", "enemy")[0].amount == 27 and _events(refresh, "vulnerability_consume")[0].remaining == 0, "Following heavy consumes previous final hit and deals24+3")
	check(_events(refresh, "vulnerability_apply").size() == 1 and _actor(refresh.after, "hero").status.vulnerability_hits == 2, "Positive unguarded heavy then refreshes to exactly2, never stacks")
	var scout = _arena(_source(), ["hero"], "sluice_scout")
	_step(scout)
	var scout_heavy: Dictionary = _step(scout, "attack", "sluice_scout")
	check(_events(scout_heavy, "damage", "enemy")[0].amount == 18 and _actor(scout_heavy.after, "hero").status.vulnerability_hits == 0, "Scout heavy retains22 base and never applies boss status")


func _test_rotating_recipient() -> void:
	var rules = _arena(_source("并肩"), ["hero", "shen", "tang"])
	_guard_round(rules)
	_step(rules)
	_step(rules, "attack", "sluice_boss")
	var heavy: Dictionary = _step(rules)
	check(_events(heavy, "vulnerability_apply")[0].target_id == "shen" and _actor(heavy.after, "shen").status.vulnerability_hits == 2, "Rotated heavy affects Shen, never the hero by default")
	check(_actor(heavy.after, "hero").status.vulnerability_hits == 0 and not _actor(heavy.after, "shen").exposed and _actor(heavy.after, "tang").exposed, "Persisting vulnerability does not alter next-target exposure")
	var guarded: Dictionary = _step(rules)
	check(_events(guarded, "vulnerability_expire").is_empty() and _actor(guarded.after, "shen").status.vulnerability_hits == 2, "Hero guard cannot clear another actor's vulnerability")
	var healing: Dictionary = _step(rules, Catalog.SHEN_ART, "shen")
	check(_events(healing, "heal")[0].amount == 25 and _actor(healing.after, "shen").status.vulnerability_hits == 2, "Real healing restores HP without consuming or clearing recipient status")
	var other_hit: Dictionary = _step(rules)
	check(_events(other_hit, "damage", "enemy")[0].target_id == "tang" and _actor(other_hit.after, "shen").status.vulnerability_hits == 2, "An unrelated incoming hit does not age Shen's two-hit status")
	_step(rules)
	var self_guard: Dictionary = _step(rules)
	check(_events(self_guard, "vulnerability_expire")[0].target_id == "shen" and _actor(self_guard.after, "shen").status.vulnerability_hits == 0, "Shen's own guard immediately clears only her status")


func _test_guard_arts() -> void:
	for art: String in ["磐石回锋", "藏锋立岳"]:
		var source = _source()
		source.choose_sect("问石门")
		if art == "藏锋立岳":
			source.sect_rank = 2
			source.sect_merit = 3
			check(source.learn_art(art), "Prepared inner disciple spends actual merit to learn advanced guard art")
		check(source.equip_art(art), "Hero equips eligible real guard art")
		var rules = _arena(source)
		_step(rules)
		_step(rules, "attack", "sluice_boss")
		check(_actor(rules.snapshot(), "hero").status.vulnerability_hits == 2, "Guard-art fixture has real heavy-applied vulnerability")
		check(rules.action_description("art:" + art).contains("清除自身破绽"), "Guard art declares its clearing effect")
		var tx: Dictionary = _step(rules, "art:" + art, "sluice_boss")
		check(_events(tx, "vulnerability_expire")[0].reason == "guard" and _events(tx, "vulnerability_consume").is_empty(), "Guard art clears before incoming damage, without consuming an extra hit")
		check(_actor(tx.after, "hero").status.vulnerability_hits == 0 and _events(tx, "damage", "enemy")[0].amount == 3, "Guard art uses defense7 then ceil30percent9=3")
		check(_actor(tx.after, "hero").cooldowns["art:" + art] == Arts.definition(art).cooldown, "Guard art owns its original cooldown")


func _test_barriers_and_consumption() -> void:
	for level: int in [1, 7]:
		var rules = _arena(_source("护后", level), ["hero", "qin"])
		_guard_round(rules)
		check(rules.select_actor("qin"), "Qin may protect before threatened hero acts")
		var grant: Dictionary = _step(rules, Catalog.QIN_ART, "hero")
		check(_events(grant, "barrier_grant")[0].amount == 18 and _actor(grant.after, "qin").qi == 3, "Actual Qin shield costs3 and grants18")
		var heavy: Dictionary = _step(rules, "attack", "sluice_boss")
		var expected: int = 6 if level == 1 else 0
		check(_events(heavy, "barrier_absorb")[0].amount == 18 and _events(heavy, "damage", "enemy")[0].amount == expected, "Partial or full shield absorption uses actual level-derived defense")
		check(_actor(heavy.after, "hero").status.vulnerability_hits == (2 if level == 1 else 0), "Positive HP damage applies status; fully absorbed heavy does not")
		check(_events(heavy, "vulnerability_apply").size() == (1 if level == 1 else 0), "No zero-damage fictitious application event")
		check(_actor(heavy.after, "qin").cooldowns[Catalog.QIN_ART] == 2, "Hero action and enemy phase do not tick Qin cooldown")
	var guarded = _arena(_source(), ["hero", "qin"])
	_guard_round(guarded)
	guarded.select_actor("qin")
	_step(guarded, Catalog.QIN_ART, "hero")
	var blocked: Dictionary = _step(guarded)
	check(_events(blocked, "barrier_absorb")[0].amount == 8 and _events(blocked, "barrier_expire")[0].amount == 10 and _events(blocked, "damage", "enemy")[0].amount == 0, "Guard applies before shield; unused10 expires truthfully")
	check(_events(blocked, "vulnerability_apply").is_empty(), "Guard plus shield cannot gain status")
	# Earned level11 defense14 lets a shield absorb a17-point vulnerable heavy.
	var consumed = _arena(_source("护后", 11), ["hero", "qin"])
	_guard_round(consumed)
	_step(consumed, "attack", "sluice_boss")
	_step(consumed)
	check(_actor(consumed.snapshot(), "hero").status.vulnerability_hits == 2, "High-defense real heavy still applies2 after positive14 damage")
	_step(consumed, "item")
	var light: Dictionary = _step(consumed)
	check(_events(light, "damage", "enemy")[0].amount == 5 and _actor(light.after, "hero").status.vulnerability_hits == 1, "Defense-adjusted light plus3 is consumed by the first following hit")
	consumed.select_actor("qin")
	_step(consumed, Catalog.QIN_ART, "hero")
	var expired: Dictionary = _step(consumed, "attack", "sluice_boss")
	check(_events(expired, "barrier_absorb")[0].incoming_after_guard == 17 and _events(expired, "damage", "enemy")[0].amount == 0, "Shield absorbs heavy14 plus existing3 bonus")
	check(_events(expired, "vulnerability_consume")[0].remaining == 0 and _events(expired, "vulnerability_apply").is_empty() and _actor(expired.after, "hero").status.vulnerability_hits == 0, "Second hit naturally exhausts status; zero damage cannot refresh it")
	var floor_probe = _arena(_source("护后", 20))
	_step(floor_probe)
	_step(floor_probe, "item")
	var floored: Dictionary = _step(floor_probe, "item")
	check(_events(floored, "damage", "enemy")[0].amount == 4 and _actor(floored.after, "hero").status.vulnerability_hits == 1, "Real defense23 floors light16 to1 before vulnerability adds3")


func _test_weaken_and_cooldown_ownership() -> void:
	var rules = _arena(_source(), ["hero", "tang"])
	_guard_round(rules)
	_step(rules, "attack", "sluice_boss")
	var heavy: Dictionary = _step(rules, Catalog.TANG_ART, "sluice_boss")
	check(_events(heavy, "damage", "enemy")[0].amount == 19 and _actor(heavy.after, "hero").status.vulnerability_hits == 2, "Tang weaken subtracts5 before boss heavy and does not cancel positive-hit vulnerability")
	check(heavy.after.enemies[0].status.weaken_strikes == 1, "Only actual enemy strike consumes enemy weaken")
	var before: Dictionary = rules.snapshot()
	var tx: Dictionary = rules.accept_action("attack", "sluice_boss")
	check(tx.ok and not rules.complete_presentation(tx.token + 1), "Presentation rejects stale token while preserving pending accepted costs")
	var locked: Dictionary = rules.snapshot()
	check(not rules.accept_action("attack", "sluice_boss").ok and rules.snapshot() == locked, "Repeated locked input cannot deal damage or consume status")
	check(_actor(tx.after, "tang").cooldowns[Catalog.TANG_ART] == 2 and _actor(tx.after, "hero").qi == mini(int(_actor(before, "hero").max_qi), int(_actor(before, "hero").qi) + 2), "Only hero gains attack qi; Tang cooldown remains its own")
	check(rules.complete_presentation(tx.token) and not rules.complete_presentation(tx.token), "Matching presentation completes once")
	var light: Dictionary = _step(rules)
	check(_events(light, "damage", "enemy")[0].amount == 10 and light.after.enemies[0].status.weaken_strikes == 0, "Light16-defense4-weaken5 plus3 equals10; weaken expires on its second strike")
	check(_actor(light.after, "tang").cooldowns[Catalog.TANG_ART] == 1 and _actor(light.after, "hero").status.vulnerability_hits == 1, "Tang's own guard ticks only Tang cooldown and leaves hero vulnerability")


func _test_downed_and_terminal_status() -> void:
	var rules = _arena(_source(), ["hero", "shen"], "sluice_boss", {"hero": {"hp": 30}})
	_guard_round(rules)
	_step(rules, "attack", "sluice_boss")
	_step(rules)
	check(_actor(rules.snapshot(), "hero").hp == 2 and _actor(rules.snapshot(), "hero").status.vulnerability_hits == 2, "Real heavy leaves vulnerable hero at2HP")
	_step(rules, "attack", "sluice_boss")
	var down: Dictionary = _step(rules)
	check(_events(down, "damage", "enemy")[0].amount == 2 and _events(down, "down")[0].target_id == "hero", "Overkill reports actual2HP loss and the actual fallen actor")
	check(_events(down, "vulnerability_expire")[0].reason == "down" and _actor(down.after, "hero").status.vulnerability_hits == 0, "Fallen actor expires remaining status after consumption")
	check(down.after.active and down.after.active_actor_id == "shen" and down.after.enemy_intents[0].target_id == "shen" and not rules.select_actor("hero"), "Downed actor is skipped and next real intent retargets survivor")
	var survivor: Dictionary = _step(rules)
	check(_events(survivor, "damage", "enemy")[0].target_id == "shen" and _actor(survivor.after, "shen").status.vulnerability_hits == 0, "Survivor alone completes round and receives guard-protected heavy")
	# Isolated recipient fallback invariant: simulate a casualty after announcing
	# an intent, before executing it. The single-opponent live route cannot cause
	# this timing today, but the shared engine must honor its public target order.
	var fallback = _arena(_source(), ["hero", "shen"])
	_guard_round(fallback)
	fallback._actor("hero").hp = 0
	fallback.select_actor("shen")
	var shifted: Dictionary = _step(fallback, "attack", "sluice_boss")
	var actions: Array = _events(shifted, "action", "enemy")
	check(actions[0].announced_target_id == "hero" and actions[0].target_id == "shen", "Actual fallback receiver differs truthfully from original announced actor")
	check(_events(shifted, "vulnerability_apply")[0].target_id == "shen" and _actor(shifted.after, "hero").status.vulnerability_hits == 0, "Fallback applies vulnerability only to actual struck survivor")
	var fled = _arena(_source())
	_step(fled)
	_step(fled, "attack", "sluice_boss")
	var escape: Dictionary = _step(fled, "flee")
	check(escape.after.outcome == "flee" and _events(escape, "damage", "enemy").is_empty() and _events(escape, "vulnerability_expire")[0].reason == "battle_end", "Flee ends status without another strike")
	var winner = _arena(_source("护后", 11))
	for index: int in 3:
		_step(winner, "attack", "sluice_boss")
	var win: Dictionary = _step(winner, "attack", "sluice_boss")
	check(win.after.outcome == "win" and _events(win, "damage", "ally")[0].amount == 12 and _events(win, "damage", "enemy").is_empty(), "Real level11 hero finishes150HP boss with clipped12 damage before its next heavy")
	check(_events(win, "vulnerability_expire")[0].reason == "battle_end" and _actor(win.after, "hero").status.vulnerability_hits == 0, "Victory clears pending vulnerability with explicit event")
	var defeated = _arena(_source(), ["hero"], "sluice_boss", {"hero": {"hp": 5}})
	_step(defeated)
	var defeat: Dictionary = _step(defeated, "attack", "sluice_boss")
	check(defeat.after.outcome == "defeat" and _events(defeat, "damage", "enemy")[0].amount == 1 and _events(defeat, "vulnerability_apply").is_empty(), "Fatal positive heavy reports1 real damage without applying transient status to a downed actor")
	var fresh = _arena(_source())
	check(_actor(fresh.snapshot(), "hero").status.vulnerability_hits == 0, "Every new battle starts without inherited vulnerability")
