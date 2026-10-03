extends "res://tests/automatic_party_battle_art_test.gd"
## Actual current-controller transactions over prepared high-HP render fixtures.
## This is geometry/event evidence, not natural balance or native pixel acceptance.
var observed_poses: Dictionary = {}
func team(count: int = 4, formation: String = "并肩", martial: String = Arts.BASE_ART) -> Dictionary:
	var prepared: Dictionary = super(count,formation,martial)
	# Deliberate render-fixture endurance so all roster sizes expose every pose
	# through a real terminal transaction. This is not a balance/earned-team test.
	for actor: Dictionary in prepared.actors:
		actor.max_hp = 10000
		actor.hp = 10000
	return prepared
func _observe() -> void:
	if art == null or art.display_snapshot.is_empty(): return
	var pose: String = art.actor_visual_pose("liang_zhen")
	observed_poses[pose] = true
	check(Art.Liang.POSES.has(pose), "Liang only uses his own six authored poses")
	check(art.actor_rect("liang_zhen") == Art.Liang.drawing_rect(art.actor_foot("liang_zhen"),204,pose), "Named authorizer maps actual pose feet through measured helper")
	check(art.actor_alpha_rect("liang_zhen") == Art.Liang.opaque_rect(art.actor_foot("liang_zhen"),204,pose), "Real helper bounds drive body occlusion and labels")
	check(Rect2(0,66,1280,619).encloses(art.actor_alpha_rect("liang_zhen")), "Full authored silhouette stays inside the arena during every observed pose")
	check(art.target_anchor("liang_zhen").is_equal_approx(Art.Liang.chest_point(art.actor_foot("liang_zhen"),204,pose)), "Target remains at this authored torso")
	check(art.blade_tip("liang_zhen").is_equal_approx(Art.Liang.weapon_point(art.actor_foot("liang_zhen"),204,pose)), "Actual saber tip uses the current authored pose")
	check(art.unit_label_rect("liang_zhen").size.x == 216 and art.unit_label_rect("liang_zhen").size.y == 62, "Name, HP, intent and phase status retain measured readable plate")
func advance(time: float) -> void:
	super(time)
	_observe()
func run() -> void:
	art=Art.new();root.add_child(art);await process_frame;art.set_process(false)
	ground=PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	art.event_presented.connect(on_fact)
	art.presentation_finished.connect(func(): completions+=1)
	art.target_requested.connect(func(id): requests.append(id))
	check(FileAccess.get_sha256(Art.Liang.PATH)=="4812052ca14b016e43818713eaefe3a15ba3baa79fc421a8d40fc1e6774b5f33", "Accepted original atlas bytes remain untouched")
	for form: String in ["并肩","护后"]:
		for count: int in [1,2,3,4]:
			var rules=model("capstone_authorizer",count,form)
			art.set_snapshot(rules.snapshot());_observe()
			check(art.backdrop_style=="archive", "Actual new encounter uses Frostbridge archive")
			var original: Dictionary = art.display_snapshot
			var duplicated: Dictionary = original.duplicate(true)
			duplicated.enemies.append(duplicated.enemies[0].duplicate(true))
			art.set_snapshot(duplicated)
			check(art.display_snapshot == original and art.actor_order().count("liang_zhen") == 1, "Duplicate named enemy is rejected without a second silhouette")
			var unknown: Dictionary = original.duplicate(true)
			unknown.enemies[0].id = "liang_zhen_walk"
			art.set_snapshot(unknown)
			check(art.display_snapshot == original and art.target_anchor("liang_zhen_walk") == Vector2.ZERO, "Unknown enemy key never falls back to old boss rendering")
			check(art.actor_visual_pose("liang_zhen")=="guard", "First announced guard phase uses original guard pose")
			check(rules.snapshot().enemies.size()==1 and rules.snapshot().enemies[0].id=="liang_zhen", "Exactly one named enemy, no duplicate or old-boss fallback")
			var iteration:int=0
			while rules.snapshot().active and iteration<900:
				await step(rules,false)
				_observe();iteration+=1
			check(not rules.snapshot().active and rules.snapshot().outcome=="win", "Prepared render fixture reaches actual terminal win")
			check(art.actor_visual_pose("liang_zhen")=="kneel" and art.target_at(art.target_anchor("liang_zhen"))!="liang_zhen", "Actual defeated authorizer uses own kneel and cannot be targeted")
	for pose: String in Art.Liang.POSES: check(observed_poses.has(pose), "Actual controller playback exposed authored pose: "+pose)
	art.queue_free();await process_frame
	print("%s: %d capstone original-atlas/current-event/pose/target/label/feet checks; prepared render fixtures only"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
