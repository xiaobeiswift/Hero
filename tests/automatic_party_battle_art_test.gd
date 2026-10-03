extends SceneTree
## Actual scheduler transactions over prepared detached combat descriptors.
## No HeroState, player save, fabricated accepted events, or recruitment claims.
const Art = preload("res://scripts/party_battle_art.gd")
const Rules = preload("res://scripts/automatic_party_combat.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
const Arts = preload("res://scripts/martial_catalog.gd")
var checks: int = 0
var failures: int = 0
var completions: int = 0
var frames: int = 0
var art
var facts: Array[Dictionary] = []
var expected: Dictionary = {}
var ground: PackedVector2Array
var requests: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func team(count: int = 4, formation: String = "并肩", martial: String = Arts.BASE_ART) -> Dictionary:
	var actors: Array[Dictionary] = []
	for i: int in count:
		var id: String = Catalog.IDS[i]
		var actor: Dictionary = Catalog._actor(id,["无名客","沈青","唐栖","秦禾"][i],500,15,3,4)
		actor.equipped_art = martial if id == "hero" else ""
		actor.sect = String(Arts.definition(martial).sect) if id == "hero" else ""
		actor.recruited = id != "hero"
		actor.internal_unlocked = true
		actor.lightness_unlocked = true
		actors.append(actor)
	return {"actors":actors,"formation":formation,"medicine":3,"medicine_heal":45}

func model(encounter: String = "heting_receipt", count: int = 4, formation: String = "并肩", martial: String = Arts.BASE_ART):
	var result = Rules.new()
	check(result.configure(team(count,formation,martial),encounter), "Actual scheduler configures " + encounter)
	return result

func unit(snapshot: Dictionary, id: String) -> Dictionary:
	for value: Dictionary in snapshot.actors + snapshot.enemies:
		if value.id == id: return value
	return {}

func event(tx: Dictionary, type: String) -> Dictionary:
	for value: Dictionary in tx.events:
		if value.type == type: return value
	return {}

func action(snapshot: Dictionary, actor: String, category: String) -> Dictionary:
	for value: Dictionary in unit(snapshot,actor).actions:
		if value.category == category: return value
	return {}

func advance(time: float) -> void: art._process(maxf(0,time-art.action_time))

func geometry(context: String) -> void:
	var grounded: bool = true; var sorted: bool = true; var labels: bool = true; var picking: bool = true
	var previous: float = -INF
	for id: String in art.actor_order():
		var foot: Vector2 = art.actor_foot(id)
		sorted = sorted and previous <= foot.y; previous = foot.y
		for offset: Vector2 in [Vector2.ZERO,Vector2(-51,5),Vector2(51,5),Vector2(0,-4),Vector2(0,14)]:
			grounded = grounded and Geometry2D.is_point_in_polygon(foot+offset,ground)
		if art.unit_label_alpha(id) > 0:
			var plate: Rect2 = art.unit_label_rect(id)
			labels = labels and Rect2(0,66,1280,610).encloses(plate)
			for other: String in art.actor_order(): labels = labels and not plate.intersects(art.actor_alpha_rect(other).grow(3))
		if int(unit(art.display_snapshot,id).hp) > 0:
			var picked: String = art.target_at(art.target_anchor(id))
			# Returning actors can temporarily cover another torso. Selection must
			# hit that living foreground actor, while input remains locked.
			picking = picking and (picked == id or (art.is_presenting() and not picked.is_empty() and art.actor_foot(picked).y >= foot.y))
	check(grounded and sorted, "All actual feet/shadows/Y order remain valid: " + context)
	check(labels and picking, "Labels and living-body input follow actual geometry: " + context)

func on_fact(value: Dictionary) -> void:
	var shown: Dictionary = art.display_snapshot
	facts.append({"event":value,"shown":shown,"time":art.action_time,"acting":art.acting_unit_id})
	check(value.is_read_only() and shown.is_read_only(), "Events and displayed facts stay readonly")
	var source: Dictionary = unit(expected,value.source_id)
	var target: Dictionary = unit(expected,value.target_id)
	match value.type:
		"action":
			check(shown.active_actor_id == value.source_id, "Actual ally or enemy action is identified before signal")
			if value.get("automatic",false):
				source.basic_round = int(value.round); source.basic_done = true; source.acted = true
			elif value.get("category", "") in ["martial","internal","lightness"]:
				var skill: Dictionary = action(expected,value.source_id,value.category)
				source.cooldowns[value.action_id] = skill.cooldown
				check(unit(shown,value.source_id).categories[value.category].used and not unit(shown,value.source_id).categories[value.category].queued, "Manual use spends its own category and consumes its exact queue")
				check(unit(shown,value.source_id).basic_done == source.basic_done and unit(shown,value.source_id).basic_round == source.basic_round, "Manual skill never spends automatic basic entitlement")
		"damage": target.hp -= int(value.amount)
		"heal": target.hp += int(value.amount)
		"qi": target.qi += int(value.amount)
		"medicine": expected.medicine += int(value.amount)
		"down": target.hp = 0
		"cooldown_tick": target.cooldowns[value.action_id] = int(value.remaining)
		"lightness_grant", "lightness_absorb", "lightness_expire":
			check(unit(shown,value.target_id).status.next_hit_reduction == value.remaining, "Lightness follows exact accepted remaining strength")
		"barrier_grant", "barrier_absorb", "barrier_expire":
			check(unit(shown,value.target_id).status.barrier == value.remaining, "Barrier remains separate from lightness and HP healing")
		"queue_cancel":
			var displayed: Dictionary = unit(shown,value.source_id)
			check(not displayed.categories[value.category].queued and displayed.categories[value.category].used == source.categories[value.category].used, "Queue cancellation clears only queued command without spending category")
			check(displayed.basic_done == source.basic_done and displayed.basic_round == source.basic_round, "Canceled skill does not consume a basic")
		"round_end":
			for actor: Dictionary in shown.actors: check(not actor.status.guard and actor.status.guard_action_id.is_empty(), "Round-end event clears guarding provenance")
		"round_start":
			for actor: Dictionary in expected.actors:
				actor.basic_done = int(actor.basic_round) == int(value.amount)
			check(shown.round == value.amount, "Only actual round-start fact advances displayed round")
		"trial_guarded_heavy":
			check(shown.trial_provenance.guarded_heavy and shown.trial_provenance.met, "Actual guarded-heavy evidence displays at its own event")
	for actor: Dictionary in expected.actors + expected.enemies:
		var displayed: Dictionary = unit(shown,actor.id)
		check(displayed.hp == actor.hp and displayed.get("qi",0) == actor.get("qi",0), "Resources equal only events shown so far: " + actor.id + "/" + value.type)
		if actor.get("team","") == "ally":
			check(displayed.cooldowns == actor.cooldowns, "Cooldowns change only at accepted use or explicit tick: " + actor.id + "/" + value.type)
			check(displayed.basic_done == actor.basic_done and displayed.basic_round == actor.basic_round, "Basic entitlement follows only automatic attack/new-round facts: " + actor.id)
	check(shown.medicine == expected.medicine, "Medicine changes only at its accepted event")

func present(tx: Dictionary, rules, draw: bool = false) -> void:
	check(tx.ok, "Scheduler produced a real accepted transaction")
	if not tx.ok: return
	var original: Dictionary = tx.duplicate(true)
	var committed: Dictionary = rules.snapshot()
	var completed: int = completions
	expected = tx.before.duplicate(true); facts.clear()
	check(art.present(tx), "Renderer accepts every scheduler transaction type")
	if not art.is_presenting(): return
	var count: int = 0
	for value: Dictionary in tx.events:
		if value.type == "action": count += 1
	check(art._segments.size() == count, "Only actual action events create actor segments")
	check(art.get_presentation_duration() > 0 and completions == completed, "Acceptance cannot synchronously acknowledge or recurse")
	var untouched: Dictionary = art.display_snapshot
	art._process(0); art._process(-5)
	check(facts.is_empty() and art.display_snapshot == untouched, "Zero/repeated input cannot reveal resolved facts")
	check(not art.present(tx), "Busy presentation rejects duplicate accepted transaction")
	var before_requests: int = requests.size()
	var click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = art.target_anchor(String(tx.get("target_id","")))
	art._gui_input(click)
	check(requests.size() == before_requests, "Moving-actor input stays locked through the complete accepted transaction")
	if count == 0:
		check(art.acting_unit_id.is_empty() and art.presentation_phase == "settle", "Passive boundary has no fake acting unit or attack")
		for id: String in art.actor_order(): check(art.actor_foot(id) == art.actor_home(id), "Passive boundary keeps every actor grounded at home")
	else:
		var segment: Dictionary = art._segments[0]
		for time: float in [.18,.359,.36,.60,.76]:
			advance(time); geometry(tx.action_id + " " + str(time))
			for id: String in art.actor_order():
				if art.is_practice_rig(id):
					check(art.actor_foot(id) == art.actor_home(id), "Practice sled never floats, lunges, or slides on a hit")
					check(art.actor_alpha_rect(id).has_point(art.actor_home(id)) and art.actor_alpha_rect(id).has_point(art.target_anchor(id)), "Rig bounds contain fixed ground contact and actual hinged impact anchor")
			if art.is_practice_rig(segment.source_id) and art._has_event(segment,"damage"):
				check(not art._is_melee(segment), "Wooden mechanism never receives human melee translation")
				if time == .18: check(float(art.rig_pose(segment.source_id).windup) > .1, "Actual striking mechanism visibly winds up its hinge")
				if time == .36:
					check(float(art.rig_pose(segment.source_id).strike) > .9, "Actual mechanism supplies its own contact pose")
					check(art.rig_projectile_tip(segment.source_id).distance_to(art.target_anchor(segment.target_id)) < .1, "Visible padded practice stroke reaches the actual ally at its damage beat")
			if art.is_practice_rig(segment.source_id) and art._has_event(segment,"protect") and time == .36:
				check(float(art.rig_pose(segment.source_id).bracing) > .65, "Actual protect action extends the wooden brace")
			check(art.selected_id == segment.target_id, "Presentation focus follows the actual action target")
			check(art.display_snapshot.selected_target_id == tx.before.selected_target_id, "Action focus never rewrites player selection")
			if time == .36 and art._is_melee(segment):
				check(art.blade_tip(segment.source_id).distance_to(art.target_anchor(segment.target_id)) < .1, "Actual original weapon reaches real target at contact")
			if segment.category in ["internal","lightness"]:
				check(art.actor_foot(segment.source_id) == art.actor_home(segment.source_id), "Internal/lightness skill never invents a melee lunge")
				check(art.actor_visual_pose(segment.source_id) not in ["strike","assist","windup"], "Internal/lightness uses recovery/protection poses")
			if time == .76: check(art.actor_foot(segment.source_id) == art.actor_home(segment.source_id), "Action returns exactly to home")
			if draw and time == .36:
				art.queue_redraw(); await process_frame; frames += 1
	art._process(10000)
	check(completions == completed+1 and not art.is_presenting(), "Each transaction acknowledges its display exactly once")
	check(art.display_snapshot == tx.after and art.selected_id == tx.after.selected_target_id, "Final display reconciles exact accepted after/idle focus")
	check(facts.size() == tx.events.size(), "Every event is emitted exactly once")
	for i: int in mini(facts.size(),tx.events.size()): check(facts[i].event == tx.events[i], "All accepted facts remain in exact stream order")
	check(rules.snapshot() == committed and tx == original, "Paint-only playback cannot change scheduler or accepted payload")
	art._process(10000)
	check(completions == completed+1, "Long repeated delta cannot acknowledge twice")
	check(rules.complete_presentation(tx.token), "Only host completes the real scheduler token")
	art.set_snapshot(rules.snapshot())

func step(rules, draw: bool = false) -> Dictionary:
	var tx: Dictionary = rules.advance()
	await present(tx,rules,draw)
	return tx

func round_to(rules, target: int) -> void:
	var limit: int = 80
	while rules.snapshot().active and rules.snapshot().round < target and limit > 0:
		await step(rules); limit -= 1
	check(rules.snapshot().round == target, "Real scheduler reaches requested round")

func test_routes() -> void:
	for encounter: String in Rules.ENCOUNTER_IDS:
		for formation: String in ["护后","并肩"]:
			for count: int in range(1,5):
				var rules = model(encounter,count,formation)
				if encounter == "heting_consignee":
					# Phase one exposes real combat facts but no new enemy art.
					# Preserve all old ten positive routes and verify rejection
					# without reading stale/empty presentation as chapter art.
					var probe=Art.new()
					probe.set_snapshot(rules.snapshot())
					check(probe.display_snapshot.is_empty(),"Phase-one enemy IDs cannot fabricate supported presentation")
					var tx:Dictionary=rules.advance()
					check(tx.get("accepted",false),"Phase-one model accepts its actual first action")
					var resolved:Dictionary=rules.snapshot()
					check(not probe.present(tx) and not probe.is_presenting(),"Unsupported chapter art rejects the accepted transaction")
					check(rules.snapshot()==resolved,"Rejected renderer leaves real model facts unchanged")
					check(rules.complete_presentation(tx.token),"Only model owner acknowledges phase-one transaction")
					probe.free()
					continue
				art.set_snapshot(rules.snapshot()); geometry(encounter+" idle")
				for id: String in art.actor_order(): check(art.unit_label_alpha(id) == 1, "Every idle actor has a clear nameplate: " + encounter + "/" + id)
				for enemy: Dictionary in rules.snapshot().enemies:
					check(unit(art.display_snapshot,enemy.id).name == enemy.name, "Distinct enemy title comes only from actual model snapshot")
					check(Art.ENEMY_FEET.has(enemy.id), "Enemy ID has its unchanged grounded slot")
					if art.is_practice_rig(enemy.id):
						check(Art.Rigs.texture_for("timber") != null and Art.Rigs.texture_for("hemp") != null, "Practice uses original wooden/rope rig materials")
					else: check(Art.Rival.texture_for(art.actor_visual_pose(enemy.id)) != null, "Other encounter retains original usable painted pose")
				var limit: int = 8
				while rules.snapshot().round == 1 and limit > 0:
					await step(rules,count == 4); limit -= 1
				check(rules.snapshot().round == 2, "Unified route completes its real first round")

func test_manual_and_cooldowns() -> void:
	for id: String in Catalog.IDS:
		var rules = model()
		for actor: Dictionary in rules._actors: actor.hp -= 30
		for category: String in ["martial","internal","lightness"]:
			var chosen: Dictionary = action(rules.snapshot(),id,category)
			var target: String = "hero" if id in ["shen","qin"] and category == "martial" else ("striker" if category == "martial" else id)
			check(rules.queue_skill(id,chosen.id,target).ok, "Queue actual " + id + "/" + category)
		while rules.snapshot().round == 1: await step(rules,true)
		await round_to(rules,3)
	# Item and flee are utilities, never consumed automatic basics.
	var utility = model(); utility._actor("hero").hp -= 40
	await present(utility.accept_action("item"),utility,true)
	check(not unit(art.display_snapshot,"hero").basic_done, "Medicine preserves pending automatic basic")
	await present(utility.accept_action("flee"),utility,true)

func test_passive_boundaries() -> void:
	var canceled = model()
	canceled._enemy("bracer").hp = 1
	canceled.select_target("bracer")
	check(canceled.queue_skill("tang",Catalog.TANG_ART,"bracer").ok, "Queue exact future target")
	await step(canceled); await step(canceled)
	var cancel: Dictionary = await step(canceled)
	check(cancel.action_id == Catalog.TANG_ART and not event(cancel,"queue_cancel").is_empty() and event(cancel,"action").is_empty(), "Dead exact target creates real queue-cancel-only transaction")
	check(art._segments.is_empty(), "Canceled skill cannot animate an invented attack")
	# The scheduler supports skipped-intent boundaries; construct that model state,
	# then accept its real round transaction without inventing an event payload.
	var boundary = model("story",1)
	await step(boundary)
	boundary._intents.clear()
	var round_end: Dictionary = await step(boundary)
	check(not event(round_end,"round_end").is_empty() and event(round_end,"action").is_empty(), "No-intent round boundary presents with no action")
	check(art.get_presentation_duration() >= Art.PASSIVE_DURATION, "Passive boundary retains a positive display interval")
	var terminal = model("story",1)
	terminal._enemy("puheng").hp = 0
	var outcome: Dictionary = await step(terminal)
	check(outcome.after.outcome == "win" and event(outcome,"action").is_empty(), "Terminal-only scheduler transaction completes without fake action")

func test_trial_and_lightness() -> void:
	var trial = model("sect_trial",1,"护后","磐石回锋")
	await round_to(trial,2)
	check(trial.queue_skill("hero","art:磐石回锋","sect_trial").ok, "Queue authentic martial guard for trial heavy")
	await step(trial); await step(trial)
	var heavy: Dictionary = trial.advance()
	check(not event(heavy,"trial_guarded_heavy").is_empty(), "Real model supplies guarded-heavy evidence")
	await present(heavy,trial,true)
	var absorbed = model("story",1)
	check(absorbed.queue_skill("hero","lightness:hero_tawei","hero").ok, "Queue learned lightness")
	await step(absorbed); await step(absorbed)
	var hit: Dictionary = absorbed.advance()
	check(not event(hit,"lightness_absorb").is_empty(), "Next real enemy hit consumes lightness")
	await present(hit,absorbed,true)
	var expired = model("story",2,"护后")
	check(expired.queue_skill("shen","lightness:shen_liuying","shen").ok, "Queue unexposed companion lightness")
	await step(expired); await step(expired); await step(expired)
	var round_hit: Dictionary = expired.advance()
	check(not event(round_hit,"lightness_expire").is_empty(), "Unhit companion lightness expires by real event")
	await present(round_hit,expired,true)

func test_practice_rigs() -> void:
	var practice = model("courtyard_practice",4)
	art.set_snapshot(practice.snapshot())
	for id: String in ["striker","bracer"]:
		check(art.is_practice_rig(id), "Only practice encounter opts into mechanical art: " + id)
		var bounds: Rect2 = art._rig_transform(id) * Art.Rigs.drawing_rect(Vector2.ZERO,id,art.rig_pose(id),art._clock)
		check(art.actor_alpha_rect(id) == bounds, "Rig nameplate envelope uses the helper's actual posed construction")
		check(art.actor_home(id) == Art.ENEMY_FEET[id] and art.target_at(art.target_anchor(id)) == id, "Rig identity, ground slot and physical body picking remain intact")
	check(float(art.rig_pose("bracer").bracing) > .6 and float(art.rig_pose("striker").bracing) == 0, "Only actual protecting rig shows the brace")
	# Both actual targets can receive and settle after a real lethal accepted hit.
	for id: String in ["striker","bracer"]:
		var lethal = model("courtyard_practice",4)
		lethal._enemy(id).hp = 1; lethal.select_target(id)
		var tx: Dictionary = lethal.advance()
		expected = tx.before.duplicate(true); facts.clear()
		check(art.present(tx), "Actual lethal practice transaction starts")
		advance(.359)
		check(float(art.rig_pose(id).defeat) == 0 and unit(art.display_snapshot,id).hp == 1, "Rig cannot collapse before the actual accepted damage beat")
		advance(.36)
		check(unit(art.display_snapshot,id).hp == 0 and art.target_at(art.target_anchor(id)) != id, "Defeated rig loses selection exactly at contact")
		advance(.60)
		check(float(art.rig_pose(id).defeat) > .5 and art.actor_foot(id) == art.actor_home(id), "Defeated frame folds toward its fixed low hinge")
		art.queue_redraw(); await process_frame; frames += 1
		art._process(10)
		check(art.display_snapshot == tx.after and float(art.rig_pose(id).defeat) == 1 and art.actor_visual_pose(id) == "down", "Collapsed rig remains visibly down without a human kneeling sprite")
		lethal.complete_presentation(tx.token)
	# A lone surviving bracer launches its actual reply from its own physical stay.
	var alone = model("courtyard_practice",1)
	alone._enemy("striker").hp = 0; alone._plan_intents(); alone.select_target("bracer")
	await step(alone,true)
	var reply: Dictionary = alone.advance()
	check(reply.source_id == "bracer" and not event(reply,"damage").is_empty(), "Actual surviving bracer supplies its own mechanical reply")
	await present(reply,alone,true)
	# The same IDs in the receipt encounter must retain the original human art.
	var receipt = model("heting_receipt",4)
	art.set_snapshot(receipt.snapshot())
	for id: String in ["striker","bracer"]:
		check(not art.is_practice_rig(id), "Receipt actor is never replaced with a wooden practice rig")
		var alpha: Rect2 = Art.ALPHA_BOUNDS.rival[art.actor_visual_pose(id)]
		check(art.actor_alpha_rect(id) == Rect2(art.actor_rect(id).position+alpha.position*art._scale(id),alpha.size*art._scale(id)), "Receipt keeps unchanged original painted alpha/pose geometry")

func test_callbacks() -> void:
	var rules = model("story",1)
	var initial: Dictionary = rules.advance()
	expected = initial.before.duplicate(true); facts.clear()
	check(art.present(initial), "Callback reset fixture begins")
	var cancel = func(_value: Dictionary): art.reset_presentation()
	art.event_presented.connect(cancel,CONNECT_ONE_SHOT)
	art._process(1000)
	check(facts.size() == 1 and not art.is_presenting(), "Cancellation from event callback stops long-delta stale facts")
	rules.complete_presentation(initial.token)
	# Completing a passive transaction may schedule the next action, but may not
	# synchronously finish that newly accepted action in the same _process call.
	rules._intents.clear()
	var boundary: Dictionary = rules.advance()
	expected = boundary.before.duplicate(true); facts.clear()
	art.present(boundary)
	var resume = func():
		rules.complete_presentation(boundary.token)
		var next: Dictionary = rules.advance()
		expected = next.before.duplicate(true); facts.clear()
		art.present(next)
	var count: int = completions
	art.presentation_finished.connect(resume,CONNECT_ONE_SHOT)
	art._process(1000)
	check(completions == count+1 and art.is_presenting() and art.action_time == 0 and facts.is_empty(), "Passive completion starts fresh epoch without zero-duration recursion")
	art.reset_presentation()

func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): push_error("Use isolated XDG directories"); quit(2); return
	art = Art.new(); art.size = Vector2(1280,685); root.add_child(art); art.set_process(false)
	art.presentation_finished.connect(func(): completions += 1)
	art.event_presented.connect(on_fact)
	art.target_requested.connect(func(id: String): requests.append(id))
	ground = PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	await test_routes()
	await test_manual_and_cooldowns()
	await test_passive_boundaries()
	await test_trial_and_lightness()
	await test_practice_rigs()
	test_callbacks()
	art.free()
	print("%s: %d automatic renderer fact/entitlement/round/pose/geometry checks; %d headless canvas frames" % ["PASS" if failures == 0 else "FAIL",checks,frames])
	quit(0 if failures == 0 else 1)
