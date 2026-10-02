extends SceneTree
## Uses the checked-in, earned level-5 journey fixtures and immutable accepted
## PartyCombatRules transactions only. No HeroState, player profile or saves.
const Art = preload("res://scripts/party_battle_art.gd")
const Rules = preload("res://scripts/party_combat_rules.gd")
const Catalog = preload("res://scripts/party_actor_catalog.gd")
var checks: int = 0
var failures: int = 0
var completions: int = 0
var emitted: Array[Dictionary] = []
var requests: Array[String] = []
var art
var ground: PackedVector2Array
var frames: int = 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func integers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Dictionary:
		for key: Variant in value: value[key] = integers(value[key])
	elif value is Array:
		for i: int in value.size(): value[i] = integers(value[i])
	return value

func team(formation: String = "并肩", ids: Array = ["hero","shen","tang"]) -> Dictionary:
	var suffix: String = "side_by_side" if formation == "并肩" else "protect_rear"
	var path: String = "res://tests/fixtures/party_actors/earned_level5_" + suffix + ".json"
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/party_actors/provenance_" + suffix + ".json"))
	check(FileAccess.get_sha256(path) == provenance.fixture_sha256, "Earned fixture retains its source provenance and hash")
	var value: Dictionary = integers(JSON.parse_string(FileAccess.get_file_as_string(path)))
	var chosen: Array = []
	for actor: Dictionary in value.actors:
		if ids.has(actor.id): chosen.append(actor)
	value.actors = chosen
	return value

func arena(formation: String = "并肩", ids: Array = ["hero","shen","tang"], encounter: String = "heting_receipt"):
	var rules = Rules.new()
	check(rules.configure(team(formation,ids),encounter), "Earned normalized team configures real rules")
	return rules

func four_arena(formation: String = "并肩", ids: Array = ["hero","shen","tang","qin"]):
	# The original three actors retain the earned journey fixture. Qin is the
	# actual catalog's prepared level-5 combat actor, not an earned recruitment
	# claim; the authoritative recruitment/save journey is tested separately.
	var prepared: Dictionary = team(formation)
	prepared.actors.append(Catalog._companion("qin",5))
	var selected: Array = []
	for actor: Dictionary in prepared.actors:
		if ids.has(actor.id): selected.append(actor)
	prepared.actors = selected
	var rules = Rules.new()
	check(rules.configure(prepared,"heting_receipt"), "Prepared real Qin catalog actor configures explicit four-member capacity")
	return rules

func unit(snapshot: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in snapshot.actors + snapshot.enemies:
		if actor.id == id: return actor
	return {}

func advance(time: float) -> void: art._process(maxf(0,time-art.action_time))

func geometry(context: String) -> void:
	var previous: float = -INF
	var sorted: bool = true
	var grounded: bool = true
	var labels: bool = true
	var distinct: bool = true
	var picking: bool = true
	var actors: Array[String] = art.actor_order()
	for id: String in actors:
		var foot: Vector2 = art.actor_foot(id)
		sorted = sorted and previous <= foot.y
		previous = foot.y
		for offset: Vector2 in [Vector2.ZERO,Vector2(-51,5),Vector2(51,5),Vector2(0,-4),Vector2(0,14)]:
			grounded = grounded and Geometry2D.is_point_in_polygon(foot+offset,ground)
		if art.unit_label_alpha(id) > 0:
			var plate: Rect2 = art.unit_label_rect(id)
			labels = labels and Rect2(0,66,1280,610).encloses(plate)
			for other: String in actors:
				labels = labels and not plate.intersects(art.actor_alpha_rect(other).grow(3))
				if id != other and art.unit_label_alpha(other) > 0: distinct = distinct and not plate.intersects(art.unit_label_rect(other))
		if int(unit(art.display_snapshot,id).hp) > 0:
			picking = picking and art.target_at(art.target_anchor(id)) == id
	check(sorted, "Ground Y sorts all actual actors: " + context)
	check(grounded, "Feet and full shadows stay on the broad dock: " + context)
	check(labels and distinct, "Visible moving plates clear all five silhouettes and each other: " + context)
	check(picking, "Living torso input follows each actor: " + context)

func play(tx: Dictionary, rules, detailed: bool = true) -> void:
	var model: Dictionary = rules.snapshot()
	var original: Dictionary = tx.duplicate(true)
	var count: int = completions
	emitted.clear()
	check(art.present(tx), "Actual accepted transaction starts")
	if not String(tx.get("target_id", "")).is_empty(): check(art.selected_id == tx.target_id, "Selected ring locks the actual accepted target even for explicit target arguments")
	check(art.display_snapshot.is_read_only() and art.display_snapshot.actors.is_read_only() and art.display_snapshot.actors[0].status.is_read_only(), "Public display is deeply readonly and detached")
	check(not art.present(tx), "Reentrant accept cannot duplicate an active action")
	var before: Dictionary = art.display_snapshot
	art._process(0); art._process(-4); art._process(NAN); art._process(INF)
	check(art.action_time == 0 and art.display_snapshot == before and emitted.is_empty(), "Zero/negative/nonfinite deltas do not emit or alter facts")
	art.set_snapshot(tx.after)
	check(art.display_snapshot == before, "Snapshot replacement cannot skip accepted beats")
	if detailed:
		for segment: Dictionary in art._segments:
			for offset: float in [.02,.10,.18,.27,.359,.36,.40,.46,.53,.60,.76,.85]:
				advance(float(segment.start)+offset)
				geometry(String(segment.source_id)+" @ "+str(offset))
				check(art.selected_id == segment.target_id, "Ring follows current actual segment target through windup/contact/return")
				check(art.display_snapshot.selected_target_id == tx.before.selected_target_id, "Presentation focus never rewrites displayed player selection")
				if offset == .36 and art._is_melee(segment):
					check(art.actor_foot(segment.source_id).distance_to(art.actor_home(segment.source_id)) > 140, "Real melee actor traverses the distance to its actual target")
					check(art.blade_tip(segment.source_id).distance_to(art.target_anchor(segment.target_id)) < .1, "Original weapon tip reaches actual target torso at contact")
					check(art.unit_label_alpha(segment.source_id) == 0, "Lunging actor does not drag a plate across silhouettes")
				if offset == .76:
					check(art.actor_foot(segment.source_id) == art.actor_home(segment.source_id), "Every independent action returns exactly to its formation slot")
				if offset in [.18,.36,.60]:
					art.queue_redraw(); await process_frame; frames += 1
	art._process(999)
	check(not art.is_presenting() and completions == count+1 and art.display_snapshot == tx.after, "Completion reconciles exact accepted after snapshot once")
	check(art.selected_id == tx.after.selected_target_id, "Idle focus returns to the model selected target")
	check(emitted.size() == tx.events.size(), "Every accepted event is shown exactly once")
	var expected: Dictionary = tx.before.duplicate(true)
	for i: int in mini(emitted.size(),tx.events.size()):
		check(emitted[i].event == tx.events[i], "Displayed event order/content equals accepted event stream")
		var event: Dictionary = emitted[i].event
		check(event.is_read_only(), "Event listener receives readonly detached fact")
		check_event_resources(expected,event,emitted[i].snapshot)
	check(rules.snapshot() == model and tx == original and rules._locked, "Renderer cannot alter accepted transaction/model or complete its token")
	for id: String in art.actor_order(): check(art.actor_foot(id) == art.actor_home(id), "Exact final home: " + id)
	art._process(999)
	check(completions == count+1 and emitted.size() == tx.events.size(), "Repeated long delta cannot duplicate facts or completion")
	check(rules.complete_presentation(tx.token), "Host alone acknowledges the accepted token")
	art.set_snapshot(rules.snapshot())
	geometry("completed accepted transaction")

func check_event_resources(expected: Dictionary, event: Dictionary, shown: Dictionary) -> void:
	var target: Dictionary = unit(expected,event.target_id)
	match event.type:
		"damage": target.hp -= int(event.amount)
		"heal": target.hp += int(event.amount)
		"qi": target.qi += int(event.amount)
		"medicine": expected.medicine += int(event.amount)
		"down": target.hp = 0
		"guard":
			check(unit(shown,event.target_id).status.guard == (event.amount > 0), "Guard fact is reflected before signal")
		"barrier_grant", "barrier_absorb", "barrier_expire":
			check(unit(shown,event.target_id).status.barrier == event.remaining, "Barrier strength changes only at its accepted protection event")
		"weaken":
			check(unit(shown,event.target_id).status.weaken_amount == event.amount and unit(shown,event.target_id).status.weaken_strikes == event.strikes, "Weaken fact has exact accepted strength and duration")
		"focus":
			check(unit(shown,event.target_id).status.focused_damage == event.amount, "Focused damage displays only accepted event")
		"proficiency":
			target.art_uses[event.art_id] = int(target.art_uses.get(event.art_id,0)) + int(event.amount)
			check(unit(shown,event.target_id).art_uses[event.art_id] == target.art_uses[event.art_id] and unit(shown,event.target_id).art_rank == event.rank, "Proficiency/rank displays exact accepted event at its beat")
		"outcome":
			check(shown.outcome == event.outcome and not shown.active, "Outcome is visible only after its fact")
	for actor: Dictionary in expected.actors + expected.enemies:
		var actual: Dictionary = unit(shown,actor.id)
		check(actor.hp == actual.hp and actor.get("qi",0) == actual.get("qi",0), "Every resource at every signal equals only facts displayed so far: " + actor.id + "/" + event.type)
	check(expected.medicine == shown.medicine, "Medicine count follows its own accepted beat")

func check_original_atlas_bounds() -> void:
	for entry: Array in [["hero",Art.Hero],["rival",Art.Rival],["shen",Art.Shen],["tang",Art.Tang]]:
		for pose: String in entry[1].POSES:
			var texture: AtlasTexture = entry[1].texture_for(pose)
			check(texture != null, "Original atlas pose is imported and usable: " + entry[0] + "/" + pose)
			if texture == null: continue
			var image: Image = texture.get_image()
			if image.is_compressed(): image.decompress()
			var left: int = 512; var top: int = 512; var right: int = -1; var bottom: int = -1
			for y: int in range(512):
				for x: int in range(512):
					if image.get_pixel(x,y).a > .08:
						left = mini(left,x); top = mini(top,y); right = maxi(right,x); bottom = maxi(bottom,y)
			check(Art.ALPHA_BOUNDS[entry[0]][pose] == Rect2(left,top,right-left+1,bottom-top+1), "Nameplate clearance matches original texture alpha: " + entry[0] + "/" + pose)
	for pose: String in Art.Qin.SOURCE_RECTS:
		var texture: AtlasTexture = Art.Qin.texture_for(pose)
		check(texture != null, "Original Qin pose is imported and usable: " + pose)
		if texture == null: continue
		var image: Image = texture.get_image()
		if image.is_compressed(): image.decompress()
		var left: int = image.get_width(); var top: int = image.get_height(); var right: int = -1; var bottom: int = -1
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x,y).a > .08:
					left = mini(left,x); top = mini(top,y); right = maxi(right,x); bottom = maxi(bottom,y)
		var source: Rect2 = Art.Qin.SOURCE_RECTS[pose]
		check(Art.Qin.OPAQUE_BOUNDS[pose] == Rect2(source.position + Vector2(left,top),Vector2(right-left+1,bottom-top+1)), "Qin non-grid crop preserves exact original opaque bounds: " + pose)
	var tang: Image = Art.Tang.texture_for("assist").get_image()
	if tang.is_compressed(): tang.decompress()
	check(tang.get_pixelv(Vector2i(Art.WEAPON.tang)).a > .08, "Tang contact anchor lands on his original ruler pixels")

func finish_action(rules, id: String = "guard", target: String = "") -> Dictionary:
	var tx: Dictionary = rules.accept_action(id,target)
	check(tx.ok, "Fixture action accepted: " + id + " " + String(tx.get("reason", "")))
	if tx.ok: rules.complete_presentation(tx.token)
	return tx

func check_segment_target_focus() -> void:
	var guarded = arena("护后")
	finish_action(guarded,"guard"); finish_action(guarded,"guard")
	var tx: Dictionary = guarded.accept_action("guard")
	var committed: Dictionary = guarded.snapshot()
	check(tx.source_id == "tang" and tx.target_id == "tang", "Regression starts with accepted Tang guard")
	check(art.present(tx), "Tang guard/reply presentation starts")
	check(art.selected_id == "tang", "Tang guard initially focuses its actual self target")
	advance(Art.CONTACT_AT)
	check(art.selected_id == "tang", "Tang guard contact still focuses Tang")
	var enemy: Dictionary = art._segments[1]
	check(enemy.source_id == "striker" and enemy.target_id == "hero", "Actual next accepted enemy action targets hero")
	advance(float(enemy.start)+.02)
	check(art.selected_id == "hero", "Enemy windup moves ring from Tang to actual hero target")
	advance(float(enemy.start)+Art.CONTACT_AT)
	check(art.selected_id == "hero" and art.acting_unit_id == "striker", "Enemy impact highlights the ally actually being struck")
	check(art.display_snapshot.selected_target_id == tx.before.selected_target_id and guarded.snapshot() == committed, "Ring focus never changes snapshot/player/model selection")
	art._process(999)
	check(art.selected_id == tx.after.selected_target_id, "Finishing restores exact idle model target")
	guarded.complete_presentation(tx.token)
	for kind: String in ["heal","shield"]:
		var friendly = four_arena("护后")
		var actor: String = "shen" if kind == "heal" else "qin"
		var target: String = "hero" if kind == "heal" else "tang"
		if kind == "heal": friendly._actor(target).hp -= 20
		friendly.select_actor(actor)
		var action: String = Catalog.SHEN_ART if kind == "heal" else Catalog.QIN_ART
		var accepted: Dictionary = friendly.accept_action(action,target)
		check(art.present(accepted), "Friendly " + kind + " presentation starts")
		for time: float in [.02,Art.CONTACT_AT,.60]:
			advance(time)
			check(art.selected_id == target, "Friendly " + kind + " focuses its actual living ally target")
			check(art.display_snapshot.selected_target_id == accepted.before.selected_target_id, "Friendly focus preserves immutable player selection")
		art._process(999)
		check(art.selected_id == accepted.after.selected_target_id, "Friendly " + kind + " restores idle model selection")
		friendly.complete_presentation(accepted.token)
	# Cancellation also stops overriding selection without writing into snapshots.
	art.present(tx); advance(Art.CONTACT_AT); art.reset_presentation()
	check(art.selected_id == tx.before.selected_target_id, "Canceled presentation restores idle displayed model selection")

func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): push_error("Use isolated XDG directories"); quit(2); return
	art = Art.new(); art.size = Vector2(1280,685); root.add_child(art); art.set_process(false)
	art.presentation_finished.connect(func(): completions += 1)
	art.event_presented.connect(func(event: Dictionary): emitted.append({"event":event,"snapshot":art.display_snapshot,"time":art.action_time,"acting":art.acting_unit_id}))
	art.target_requested.connect(func(id: String): requests.append(id))
	ground = PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	check_original_atlas_bounds()
	check_segment_target_focus()
	var initial = arena()
	art.set_snapshot(initial.snapshot())
	check(art.actor_home("hero") == Vector2(420,585) and art.actor_home("shen") == Vector2(255,455) and art.actor_home("tang") == Vector2(475,350), "Three actors use agreed side-by-side composition")
	check(art.actor_visual_pose("bracer") == "guard" and art.actor_visual_pose("striker") == "idle", "Protecting bracer guards from its real intent; protected striker remains idle")
	geometry("all five idle with protecting bracer")
	for id: String in art.actor_order(): check(art.unit_label_alpha(id) == 1, "All five idle nameplates remain visible: " + id)
	var click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	for id: String in ["hero","shen","tang","bracer","striker"]:
		click.position = art.target_anchor(id); art._gui_input(click)
	check(requests == ["hero","shen","tang","bracer","striker"] and initial.snapshot().selected_target_id == "striker", "Picking requests living ally/enemy IDs without changing model selection")
	check(art.target_at(Vector2(50,80)).is_empty(), "Water and transparent corners are not hit targets")
	var actor_count: int = requests.size()
	var first: Dictionary = initial.accept_action("attack","striker")
	art.present(first); art._gui_input(click)
	check(requests.size() == actor_count, "Global input lock covers presentation")
	advance(.359)
	check(unit(art.display_snapshot,"striker").hp == unit(first.before,"striker").hp, "HP cannot reveal damage before contact")
	advance(.36)
	check(unit(art.display_snapshot,"striker").hp == unit(first.before,"striker").hp-int(first.events[1].amount), "HP changes by accepted damage at contact")
	art.reset_presentation(); initial.complete_presentation(first.token)
	for formation: String in ["护后","并肩"]:
		var four = four_arena(formation)
		art.set_snapshot(four.snapshot()); geometry("six actors / " + formation)
		for id: String in art.actor_order(): check(art.unit_label_alpha(id) == 1, "All six idle nameplates remain visible: " + formation + "/" + id)
		for target: String in ["striker","bracer"]:
			var striker = four_arena(formation); striker.select_actor("qin")
			await play(striker.accept_action("attack",target),striker)
		var shield = four_arena(formation); shield.select_actor("qin")
		var grant: Dictionary = shield.accept_action(Catalog.QIN_ART,"hero")
		await play(grant,shield)
		check(unit(art.display_snapshot,"hero").status.barrier == 18 and unit(grant.before,"hero").hp == unit(grant.after,"hero").hp, "Qin grants a real shield without healing")
		finish_action(shield,"guard"); finish_action(shield,"guard")
		await play(shield.accept_action("guard"),shield)
		check(unit(art.display_snapshot,"hero").status.barrier == 0, "Next incoming hit consumes granted shield")
		var untouched = four_arena(formation); untouched.select_actor("qin")
		await play(untouched.accept_action(Catalog.QIN_ART,"tang"),untouched)
		finish_action(untouched,"guard"); finish_action(untouched,"guard")
		var expiry: Dictionary = untouched.accept_action("guard")
		await play(expiry,untouched)
		check(unit(art.display_snapshot,"tang").status.barrier == 0, "Unhit shield expires at its accepted round-end fact")
		var rescue = four_arena(formation); rescue._actor("qin").hp -= 20; rescue.select_actor("shen")
		await play(rescue.accept_action(Catalog.SHEN_ART,"qin"),rescue)
		for roster: Array in [["hero","qin"],["hero","shen","qin"],["hero","tang","qin"]]:
			var subset = four_arena(formation,roster)
			art.set_snapshot(subset.snapshot()); geometry("Qin explicit subset " + str(roster))
			for id: String in art.actor_order(): check(art.unit_label_alpha(id) == 1, "Subset nameplates visible: " + id)
	var qin_down = four_arena("护后")
	for actor: Dictionary in qin_down._actors: actor.hp = 1 if actor.id == "qin" else 0
	qin_down.select_actor("qin")
	await play(qin_down.accept_action("guard"),qin_down)
	check(art.actor_visual_pose("qin") == "down" and art.display_snapshot.outcome == "defeat", "Qin uses his actual down pose after the final accepted hit")
	# Both formations, both targets, all original allies; earned resources only.
	for formation: String in ["护后","并肩"]:
		for actor: String in ["hero","shen","tang"]:
			for target: String in ["striker","bracer"]:
				for martial: bool in [false,true]:
					var local = arena(formation)
					local.select_actor(actor)
					var action: String = "attack"
					if martial: action = String(local.available_actions()[1].id)
					if actor == "shen" and martial:
						local._actor("hero").hp -= 25
						target = "hero"
					var tx: Dictionary = local.accept_action(action,target)
					check(tx.ok, "Actor/formation/target action accepted: " + actor + "/" + target)
					if tx.ok: await play(tx,local)
		# Solo and two-member rosters, real guard/item/flee, Pu Heng and receipt.
		for roster: Array in [["hero"],["hero","shen"],["hero","tang"]]:
			for action: String in ["guard","item","flee"]:
				var local = arena(formation,roster,"story")
				if action == "item": local._actor("hero").hp -= 35
				var tx: Dictionary = local.accept_action(action)
				check(tx.ok, "Roster action accepted")
				if tx.ok: await play(tx,local)
	# Sequential round replies alternate targets only according to real intents.
	for formation: String in ["护后","并肩"]:
		var local = arena(formation)
		for round_index: int in range(3):
			finish_action(local,"guard")
			finish_action(local,"guard")
			var tx: Dictionary = local.accept_action("guard")
			var victim: String = "hero" if formation == "护后" else ["hero","shen","tang"][round_index]
			var found: bool = false
			for event: Dictionary in tx.events:
				if event.type == "damage" and event.phase == "enemy": found = event.target_id == victim
			check(found, "Real intent targets " + victim + " in " + formation)
			await play(tx,local)
	# Authoritative rejection has no visual transaction; never synthesize healing.
	var healing = arena(); healing.select_actor("shen")
	for target: String in ["striker","shen"]:
		var rejected: Dictionary = healing.accept_action(Catalog.SHEN_ART,target)
		check(not rejected.ok and not art.present(rejected), "Wrong-team/full-health heal rejects before presentation")
	healing._actor("hero").hp = 0
	var dead_heal: Dictionary = healing.accept_action(Catalog.SHEN_ART,"hero")
	check(not dead_heal.ok and not art.present(dead_heal), "Healing a downed ally rejects without revival")
	# Downed hero does not end a party fight; living companions still act.
	var down = arena(); down._actor("hero").hp = 1
	finish_action(down,"guard"); finish_action(down,"guard")
	var fallen: Dictionary = down.accept_action("guard")
	await play(fallen,down)
	check(unit(art.display_snapshot,"hero").hp == 0 and art.actor_visual_pose("hero") == "kneel" and down.snapshot().active, "Hero remains down while party fight continues")
	check(down.snapshot().active_actor_id == "shen", "Living companion becomes next real actor")
	var companion_tx: Dictionary = down.accept_action("attack","striker")
	await play(companion_tx,down)
	check(art.actor_visual_pose("hero") == "kneel", "Companion turn never makes fallen hero act or revive")
	# Model-driven finishers and defeat, including companion down pose.
	for finisher: String in ["hero","shen","tang"]:
		var local = arena("并肩",["hero","shen","tang"],"training")
		local._enemy("puheng").hp = 1; local.select_actor(finisher)
		var tx: Dictionary = local.accept_action("attack","puheng")
		await play(tx,local)
		check(art.display_snapshot.outcome == "win" and art.actor_visual_pose("puheng") == "kneel" and art.target_at(art.target_anchor("puheng")).is_empty(), "Actual " + finisher + " finisher leaves enemy visibly down and unpickable")
	var doomed = arena(); doomed._actor("hero").hp = 0; doomed._actor("shen").hp = 0; doomed._actor("tang").hp = 1
	doomed.select_actor("tang")
	var end: Dictionary = doomed.accept_action("guard")
	await play(end,doomed)
	check(art.display_snapshot.outcome == "defeat" and art.actor_visual_pose("shen") == "down" and art.actor_visual_pose("tang") == "down", "All-down outcome leaves companions visibly down with existing original art")
	# A synthetic planned second enemy intent tests the generic sequencer through
	# real engine resolution; production encounter/balance definitions stay intact.
	var multi = arena("护后")
	multi._intents[1] = {"source_id":"bracer","target_id":"shen","target_order":["shen","tang"],"type":"attack","name":"护手短斩","damage":14,"heavy":false}
	finish_action(multi,"guard"); finish_action(multi,"guard")
	var many: Dictionary = multi.accept_action("guard")
	await play(many,multi)
	var enemies: int = 0
	for event: Dictionary in many.events:
		if event.type == "action" and event.phase == "enemy": enemies += 1
	check(enemies == 2 and art._segments.size() == 3, "Ally plus multiple actual enemy actions gets three separate segments")
	var shielded = arena("护后")
	shielded._actor("hero").status.barrier = 18
	finish_action(shielded,"guard"); finish_action(shielded,"guard")
	var barrier_tx: Dictionary = shielded.accept_action("guard")
	await play(barrier_tx,shielded)
	var absorbed: bool = false
	for event: Dictionary in barrier_tx.events:
		if event.type == "barrier_absorb": absorbed = true
	check(absorbed and unit(barrier_tx.before,"hero").hp == unit(barrier_tx.after,"hero").hp, "Real shield absorption can reduce accepted damage to zero without healing")
	# Accepted cap event may carry zero; floating proficiency must not invent +1.
	var capped = arena(); var hero: Dictionary = capped._actor("hero")
	hero.art_uses[hero.equipped_art] = 9999
	var cap: Dictionary = capped.accept_action(String(capped.available_actions()[1].id),"bracer")
	art.present(cap); advance(.45)
	var cap_found: bool = false
	for event: Dictionary in cap.events:
		if event.type == "proficiency": cap_found = event.amount == 0
	check(cap_found, "Actual capped proficiency event is zero")
	var floating: bool = false
	for fact: Dictionary in art._floats:
		if fact.event.type == "proficiency": floating = true
	check(not floating, "Zero proficiency never floats a fake +1")
	art.reset_presentation()
	# Detached caller input, replacement, and event-callback cancellation/epoch.
	var replacement = arena(); var tx: Dictionary = replacement.accept_action("attack","bracer")
	var mutable: Dictionary = tx.duplicate(true)
	art.present(mutable); mutable.after.actors[0].hp = 999; mutable.events[1].amount = 999
	check(art._after == tx.after and art._schedule[1].event == tx.events[1], "Caller mutations cannot replace pending accepted facts")
	var release_count: int = completions
	art.reset_presentation(); art.reset_presentation()
	check(completions == release_count+1 and not art.is_presenting() and art._floats.is_empty() and art.acting_unit_id.is_empty(), "Reset releases waiter exactly once and clears stale pose/floats")
	art.set_snapshot(replacement.snapshot())
	check(art.display_snapshot == replacement.snapshot(), "Host may install replacement snapshot after reset")
	var signal_cancel = func(_event: Dictionary): art.reset_presentation()
	art.event_presented.connect(signal_cancel, CONNECT_ONE_SHOT)
	emitted.clear(); art.present(tx); art._process(999)
	check(emitted.size() == 1 and not art.is_presenting(), "Oversized delta stops immediately if listener cancels at first event")
	var replacement_started: bool = false
	var replacement_once = func():
		art.set_snapshot(tx.before)
		art.present(tx)
	art.presentation_finished.connect(replacement_once, CONNECT_ONE_SHOT)
	art.present(tx); art.reset_presentation()
	replacement_started = art.is_presenting() and art.action_time == 0
	check(replacement_started, "Completion callback can install a fresh epoch without stale reset clearing it")
	art._process(999); art.reset_presentation()
	check(not art.present({"accepted":true,"ok":true,"before":{},"after":{},"events":[]}), "Malformed transaction rejects safely")
	art.free()
	print("%s: %d party battle art transaction/motion/geometry/cancellation checks; %d headless draw frames" % ["PASS" if failures == 0 else "FAIL",checks,frames])
	quit(0 if failures == 0 else 1)
