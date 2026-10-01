extends SceneTree
const Art=preload("res://scripts/painted_battle_puheng.gd")
const Hero=preload("res://scripts/painted_battle_hero.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
func _initialize()->void:run.call_deferred()
func run()->void:
	for name in Art.POSES:
		var i:int=Art.POSES[name];var t=Art.texture_for(name)
		assert(t!=null and t.region==Rect2((i%3)*512,(i/3)*512,512,512))
		assert(t.atlas!=Hero.texture_for(name).atlas and t==Art.texture_for(name))
	var foot=Vector2(721,274)
	assert((Art.drawing_rect(foot).position+Art.FOOT*(216.0/512.0)).distance_to(foot)<.001)
	var app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app._start_battle("training");app.battle_art.set_process(false)
	assert(app.battle_art.enemy_identity==app.state.enemy_name and app.battle_art.uses_painted_enemy())
	app.battle_art.hit("attack",{"enemy_damage":16,"player_damage":5});app.battle_art.action_time=.36
	assert(app.battle_art.enemy_visual_pose()=="hurt")
	app.battle_art.action_time=.75;assert(app.battle_art.enemy_visual_pose()=="windup")
	app.battle_art.action_time=.90;assert(app.battle_art.enemy_visual_pose()=="strike")
	app.battle_art.hit("attack",{"finished":true,"won":true,"enemy_damage":70});app.battle_art.action_time=1.0
	assert(app.battle_art.enemy_visual_pose()=="kneel")
	app.battle_art.enemy_identity="蒲横的徒弟";assert(not app.battle_art.uses_painted_enemy())
	app.battle_art.enemy_identity="罗沉 · 闸首";assert(not app.battle_art.uses_painted_enemy())
	app.battle_art.enemy_identity="岑远 · 入门试炼";assert(not app.battle_art.uses_painted_enemy())
	app.battle_art.enemy_identity="蒲横";app.battle_art.painted_enemy_enabled=false;assert(not app.battle_art.uses_painted_enemy())
	app.battle_art.reset_presentation();app.queue_free();await create_timer(.25).timeout
	print("PASS: painted Pu Heng identity, leftward pose timing, anchors and independent caches");quit()
