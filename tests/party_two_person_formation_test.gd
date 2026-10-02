extends "res://tests/party_battle_art_test.gd"
## Measured existing art plus accepted rules transactions. The prepared Qin
## catalog actor tests geometry; it does not claim early Qin recruitment.
const ROSTERS = [["hero"],["hero","shen"],["hero","tang"],["hero","qin"],
	["hero","shen","tang"],["hero","shen","qin"],["hero","tang","qin"],
	["hero","shen","tang","qin"]]
var scaled_checks: int = 0
var counterattack_checks: int = 0
var opaque_images: Dictionary = {}

func physical_transform() -> Transform2D:
	# CanvasItem.get_screen_transform() omits Window stretch on the headless
	# display server. The viewport's final transform contains the real stretch.
	return root.get_final_transform() * art.get_global_transform_with_canvas()

func prepared_arena(formation_name: String, ids: Array, encounter: String = "story"):
	var prepared: Dictionary = team(formation_name)
	prepared.actors.append(Catalog._companion("qin",5))
	var chosen: Array = []
	for actor: Dictionary in prepared.actors:
		if ids.has(actor.id): chosen.append(actor)
	prepared.actors = chosen
	var rules = Rules.new()
	check(rules.configure(prepared,encounter), "Legal prepared roster configures " + str(ids) + "/" + encounter)
	return rules

func geometry(context: String) -> void:
	super.geometry(context)
	# Use the actual CanvasItem -> physical window transform, including the
	# project's canvas_items stretch, rather than assuming 1280px is physical.
	var transform: Transform2D = physical_transform()
	var dock: PackedVector2Array = transform * ground
	var physical: Rect2 = Rect2(Vector2.ZERO,Vector2(root.size))
	var clear: bool = true
	var grounded: bool = true
	var picking: bool = true
	for id: String in art.actor_order():
		var foot: Vector2 = art.actor_foot(id)
		for offset: Vector2 in [Vector2.ZERO,Vector2(-51,5),Vector2(51,5),Vector2(0,-4),Vector2(0,14)]:
			grounded = grounded and Geometry2D.is_point_in_polygon(transform * (foot+offset),dock)
		if art.unit_label_alpha(id) > 0:
			var plate: Rect2 = transform * art.unit_label_rect(id)
			clear = clear and physical.encloses(plate)
			for other: String in art.actor_order():
				clear = clear and not plate.intersects(transform * art.actor_alpha_rect(other).grow(3))
				if other != id and art.unit_label_alpha(other) > 0:
					clear = clear and not plate.intersects(transform * art.unit_label_rect(other))
		if int(unit(art.display_snapshot,id).hp) > 0:
			var point: Vector2 = transform * art.target_anchor(id)
			picking = picking and art.target_at(transform.affine_inverse() * point) == id
	check(clear and grounded and picking, "Physical viewport preserves plates, ground and target mapping: %s; size=%s transform=%s clear=%s grounded=%s picking=%s" % [context,root.size,transform,clear,grounded,picking])
	if root.size.x == 1179: scaled_checks += 1
	check_counterattacker_visibility(context)

func check_counterattacker_visibility(context: String) -> void:
	var segment: Dictionary = art._current_segment()
	if segment.is_empty() or art.formation != "并肩" or art.display_snapshot.actors.size() != 2: return
	if art._is_ally(segment.source_id) or segment.target_id == "hero" or not art._is_melee(segment): return
	var time: float = art.action_time-float(segment.start)
	if time < .359 or time > .46 or art.actor_visual_pose(segment.source_id) != "strike": return
	# Source-cell regions around the visible straw hat/face and jacket/belt,
	# measured from the original Rival strike. Weapons are intentionally outside
	# these regions. Count actual opaque pixels rather than intersecting boxes.
	var source: Image = opaque_image("rival","strike")
	var foreground: Image = opaque_image("hero",art.actor_visual_pose("hero"))
	var source_origin: Vector2 = art.actor_rect(segment.source_id).position
	var source_scale: float = art._scale(segment.source_id)
	var hero_origin: Vector2 = art.actor_rect("hero").position
	var hero_scale: float = art._scale("hero")
	var hero_in_front: bool = art.actor_order().find("hero") > art.actor_order().find(segment.source_id)
	for region: Rect2i in [Rect2i(195,226,132,66),Rect2i(270,276,118,94)]:
		var opaque: int = 0
		var hidden: int = 0
		for y: int in range(region.position.y,region.end.y):
			for x: int in range(region.position.x,region.end.x):
				if source.get_pixel(x,y).a <= .08: continue
				opaque += 1
				var point: Vector2 = source_origin+Vector2(x+.5,y+.5)*source_scale
				var local: Vector2 = (point-hero_origin)/hero_scale
				if hero_in_front and Rect2(0,0,512,512).has_point(local) and foreground.get_pixelv(Vector2i(local)).a > .08: hidden += 1
		check(opaque > 1000 and hidden == 0, "Uninvolved hero hides no original attacker head/torso pixels: %s / %s (%d of %d hidden)" % [context,region,hidden,opaque])
	counterattack_checks += 1

func opaque_image(kind: String, pose: String) -> Image:
	var key: String = kind+"/"+pose
	if not opaque_images.has(key):
		var atlas = Art.Rival if kind == "rival" else Art.Hero
		var image: Image = atlas.texture_for(pose).get_image()
		if image.is_compressed(): image.decompress()
		opaque_images[key] = image
	return opaque_images[key]

func check_homes(formation_name: String, ids: Array) -> void:
	var homes: Dictionary
	if ids.size() == 4:
		homes = {"hero":Vector2(440,585),"shen":Vector2(160,470),"tang":Vector2(325,350),"qin":Vector2(550,390)} if formation_name == "护后" else {"hero":Vector2(430,590),"shen":Vector2(180,480),"tang":Vector2(355,345),"qin":Vector2(580,435)}
	else:
		homes = {"hero":Vector2(440,585) if formation_name == "护后" else Vector2(420,585)}
		if ids.size() == 2:
			homes[ids[1]] = Vector2(255,450) if formation_name == "护后" else Vector2(140,505)
		elif ids.size() == 3:
			homes[ids[1]] = Vector2(200,470) if formation_name == "护后" else Vector2(255,455)
			homes[ids[2]] = Vector2(345,350) if formation_name == "护后" else Vector2(475,350)
	for id: String in ids:
		check(art.actor_home(id) == homes[id] and art.actor_foot(id) == homes[id], "Exact idle formation slot: " + formation_name + "/" + id + "/" + str(ids.size()))
		check(art.unit_label_alpha(id) == 1, "Every idle ally keeps a visible nameplate: " + formation_name + "/" + id)
	if ids.size() == 2:
		check(not art.actor_alpha_rect("hero").intersects(art.actor_alpha_rect(ids[1]).grow(4)), "Measured original two-person idle silhouettes have clear space")
		check(art.actor_alpha_rect(ids[1]).end.y - art.actor_foot(ids[1]).y < 3, "Companion's measured opaque feet remain on its ground anchor")

func check_visible_formation_change(companion: String) -> void:
	var rear = prepared_arena("护后",["hero",companion])
	art.set_snapshot(rear.snapshot())
	var rear_foot: Vector2 = art.actor_foot(companion)
	var rear_alpha: Rect2 = art.actor_alpha_rect(companion)
	var rear_label: Rect2 = art.unit_label_rect(companion)
	var side = prepared_arena("并肩",["hero",companion])
	art.set_snapshot(side.snapshot())
	var offset: Vector2 = art.actor_foot(companion)-rear_foot
	check(offset == Vector2(-115,55), "Actual " + companion + " feet visibly advance between two-person formations")
	check(art.actor_alpha_rect(companion).position-rear_alpha.position == offset, "Original " + companion + " silhouette follows the changed slot")
	check(art.unit_label_rect(companion).position.distance_to(rear_label.position) > 100, "Actual companion plate visibly follows the changed row")
	check((physical_transform().basis_xform(offset)).length() > 100, "Formation displacement remains visible at current physical size")

func check_target_policy(formation_name: String, companion: String) -> void:
	var rules = prepared_arena(formation_name,["hero",companion])
	check(rules.snapshot().enemy_intents[0].target_id == "hero", "Initial announced target stays model-driven")
	finish_action(rules,"guard")
	finish_action(rules,"guard")
	var before: Dictionary = rules.snapshot()
	var expected: String = "hero" if formation_name == "护后" else companion
	check(before.enemy_intents[0].target_id == expected, "Second-round enemy still uses the original formation target policy")
	art.set_snapshot(before)
	geometry("second-round targets / " + companion + "/" + formation_name)
	check(rules.snapshot() == before and art.display_snapshot == before, "Position lookup/picking never writes model or selection")

func check_two_person_playback(formation_name: String, companion: String, encounter: String) -> void:
	for source: String in ["hero",companion]:
		var rules = prepared_arena(formation_name,["hero",companion],encounter)
		rules.select_actor(source)
		await play(rules.accept_action("attack"),rules)
	# Finish the round with a companion guard so every opponent's incoming
	# windup, exact weapon contact, recoil, grounded return and plates are tested.
	var reply = prepared_arena(formation_name,["hero",companion],encounter)
	finish_action(reply,"guard")
	await play(reply.accept_action("guard"),reply)
	if companion == "shen":
		var heal = prepared_arena(formation_name,["hero",companion],encounter)
		heal._actor("hero").hp -= 20
		heal.select_actor("shen")
		await play(heal.accept_action(Catalog.SHEN_ART,"hero"),heal)
	elif companion == "qin":
		var shield = prepared_arena(formation_name,["hero",companion],encounter)
		shield.select_actor("qin")
		await play(shield.accept_action(Catalog.QIN_ART,"hero"),shield)

func check_archive_status_playback(formation_name: String, companion: String, hero_action: String = "attack") -> void:
	var rules = prepared_arena(formation_name,["hero",companion],"archive_boss")
	finish_action(rules,"guard"); finish_action(rules,"guard")
	finish_action(rules,hero_action)
	var strike: Dictionary = rules.accept_action("attack")
	await play(strike,rules)
	var recipient: String = "hero" if formation_name == "护后" else companion
	check(unit(art.display_snapshot,recipient).status.vulnerability_hits == 2, "Archive heavy hit displays vulnerability on its actual formation target")
	rules.select_actor(recipient)
	await play(rules.accept_action("guard"),rules)
	check(unit(art.display_snapshot,recipient).status.vulnerability_hits == 0, "Recipient's accepted guard clears displayed archive vulnerability")
	await play(rules.accept_action("flee"),rules)
	for actor: Dictionary in art.display_snapshot.actors:
		check(actor.status.vulnerability_hits == 0, "Archive terminal snapshot clears temporary vulnerability")

func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	art = Art.new(); art.size = Vector2(1280,685); root.add_child(art); art.set_process(false)
	art.presentation_finished.connect(func(): completions += 1)
	art.event_presented.connect(func(event: Dictionary): emitted.append({"event":event,"snapshot":art.display_snapshot,"time":art.action_time,"acting":art.acting_unit_id}))
	ground = PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	check_original_atlas_bounds()
	root.content_scale_size = Vector2i(1280,800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for physical_size: Vector2i in [Vector2i(1280,800),Vector2i(1179,737)]:
		root.size = physical_size; await process_frame
		var actual_width: float = physical_transform().basis_xform(Vector2(1280,0)).length()
		check(absf(actual_width-physical_size.x) < 1, "Actual canvas stretch maps logical 1280px to physical viewport width: %s -> %s" % [actual_width,physical_size.x])
		for companion: String in ["shen","tang","qin"]: check_visible_formation_change(companion)
		for formation_name: String in ["护后","并肩"]:
			for ids: Array in ROSTERS:
				var rules = prepared_arena(formation_name,ids,"heting_receipt")
				art.set_snapshot(rules.snapshot())
				check_homes(formation_name,ids)
				geometry("idle roster " + str(ids) + "/" + formation_name)
				for id: String in art.actor_order(): check(art.unit_label_alpha(id) == 1, "All original idle unit plates are visible")
			for companion: String in ["shen","tang","qin"]:
				check_target_policy(formation_name,companion)
				await check_two_person_playback(formation_name,companion,"heting_receipt")
	# Preserve the prior solo/sluice identities and support the real archive
	# snapshot, including its unique 205HP opponent and unchanged event protocol.
	check(Art.ENEMY_TINTS.archive_boss != Art.ENEMY_TINTS.sluice_boss and Art.ENEMY_TINTS.archive_boss != Color.WHITE, "Archive reuses owned opponent art with a distinct tint")
	for encounter: String in ["sluice_scout","sluice_boss","archive_boss"]:
		for formation_name: String in ["护后","并肩"]:
			for ids: Array in ROSTERS:
				var rules = prepared_arena(formation_name,ids,encounter)
				art.set_snapshot(rules.snapshot())
				check(art.actor_order().has(encounter) and not art.actor_order().has("puheng"), "Opponent retains real encounter identity: " + encounter)
				check(art.actor_home(encounter) == Vector2(865,580), "Solo opponent uses its explicit grounded home")
				if encounter == "archive_boss": check(unit(art.display_snapshot,encounter).hp == 205, "Archive HP comes unchanged from real accepted snapshot")
				check_homes(formation_name,ids)
				geometry(encounter + "/" + formation_name + "/" + str(ids.size()))
				check(art.unit_label_alpha(encounter) == 1, "Idle opponent nameplate remains visible")
			await check_two_person_playback(formation_name,"shen",encounter)
	for formation_name: String in ["护后","并肩"]:
		for companion: String in ["shen","tang","qin"]: await check_archive_status_playback(formation_name,companion)
	for companion: String in ["shen","tang","qin"]: await check_archive_status_playback("并肩",companion,"guard")
	check(scaled_checks > 100, "Compact viewport covers idle and actual moving frames")
	check(counterattack_checks >= 18, "All three companions cover incoming contact with idle and guarding hero silhouettes")
	art.queue_free(); await process_frame
	print("%s: %d two-person formation/archive geometry and accepted-event checks; %d compact checks; %d counterattack visibility checks; %d headless draw frames" % ["PASS" if failures == 0 else "FAIL",checks,scaled_checks,counterattack_checks,frames])
	quit(0 if failures == 0 else 1)

func check_event_resources(expected: Dictionary, event: Dictionary, shown: Dictionary) -> void:
	super.check_event_resources(expected,event,shown)
	if String(event.type).begins_with("vulnerability_"):
		check(unit(shown,event.target_id).status.vulnerability_hits == event.remaining, "Original vulnerability event is shown at its exact accepted beat")
