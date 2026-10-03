extends "res://tests/automatic_party_battle_art_test.gd"
## Actual current-controller transactions over prepared high-HP render fixtures.
## This is geometry/event evidence, not natural balance or native pixel acceptance.
var observed_poses: Dictionary = {}
func _observe() -> void:
	if art == null or art.display_snapshot.is_empty(): return
	var pose: String = art.actor_visual_pose("du_hui")
	observed_poses[pose] = true
	check(Art.DuHui.POSES.has(pose), "DuHui only uses his own six authored poses")
	check(art.actor_rect("du_hui") == Art.DuHui.drawing_rect(art.actor_foot("du_hui"),236,pose), "Named receiver maps actual pose feet through measured helper")
	check(art.actor_alpha_rect("du_hui") == Art.DuHui.opaque_rect(art.actor_foot("du_hui"),236,pose), "Real helper bounds drive body occlusion and labels")
	check(art.target_anchor("du_hui").is_equal_approx(Art.DuHui.chest_point(art.actor_foot("du_hui"),236,pose)), "Target remains at this authored torso")
	check(art.blade_tip("du_hui").is_equal_approx(Art.DuHui.weapon_point(art.actor_foot("du_hui"),236,pose)), "Actual baton tip uses the current authored pose")
	check(art.unit_label_rect("du_hui").size.x == 216 and art.unit_label_rect("du_hui").size.y == 62, "Name, HP, intent and phase status retain measured readable plate")
func advance(time: float) -> void:
	super(time)
	_observe()
func run() -> void:
	art=Art.new();root.add_child(art);await process_frame;art.set_process(false)
	ground=PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	art.event_presented.connect(on_fact)
	art.presentation_finished.connect(func(): completions+=1)
	art.target_requested.connect(func(id): requests.append(id))
	check(FileAccess.get_sha256(Art.DuHui.PATH)=="4b44e7ff892123479fcd31b7d043291c2207fffe602f676d41401581d590962a", "Accepted original atlas bytes remain untouched")
	for form: String in ["并肩","护后"]:
		var rules=model("heting_consignee",4,form)
		art.set_snapshot(rules.snapshot());_observe()
		check(art.backdrop_style=="warehouse", "Actual new encounter uses north warehouse")
		check(art.actor_visual_pose("du_hui")=="guard" and art.actor_visual_pose("consignee_guard")=="idle", "First announced staggered phases remain distinct")
		var iteration:int=0
		while rules.snapshot().active and iteration<300:
			await step(rules,false)
			_observe();iteration+=1
		check(not rules.snapshot().active and rules.snapshot().outcome=="win", "Prepared render fixture reaches actual terminal win")
		check(art.actor_visual_pose("du_hui")=="kneel" and art.target_at(art.target_anchor("du_hui"))!="du_hui", "Actual defeated receiver uses own kneel and cannot be targeted")
	for pose: String in Art.DuHui.POSES: check(observed_poses.has(pose), "Actual controller playback exposed authored pose: "+pose)
	art.queue_free();await process_frame
	print("%s: %d consignee original-atlas/current-event/pose/target/label/feet checks; prepared render fixtures only"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
