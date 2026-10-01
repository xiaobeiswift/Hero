extends SceneTree
const Art=preload("res://scripts/battle_art.gd")
const Model=preload("res://scripts/game_state.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var art=Art.new();root.add_child(art);art.set_process(false)
	assert(art.painted_hero_enabled and art.hero_visual_pose()=="idle")
	var model=Model.new();model.start_battle("training");var result=model.battle_action("attack");var before=model.to_dict()
	art.hit("attack",result)
	for point in [[.12,"windup"],[.25,"windup"],[.27,"strike"],[.36,"strike"],[.70,"idle"],[.91,"hurt"]]:
		art.action_time=point[0];assert(art.hero_visual_pose()==point[1])
	assert(model.to_dict()==before)
	art.hit("guard",{"guarded":true,"player_damage":4});art.action_time=.4;assert(art.hero_visual_pose()=="guard")
	art.hit("attack",{"finished":true,"won":false,"player_damage":100});art.action_time=1.20;assert(art.hero_visual_pose()=="kneel")
	art.reset_presentation();assert(art.hero_visual_pose()=="idle")
	art.queue_free();await process_frame
	print("PASS: painted hero follows actual combat poses without changing accepted results");quit()
