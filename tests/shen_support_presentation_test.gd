extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func settle()->void:
	for tween in app._battle_health_tweens.values():
		if tween.is_valid():tween.custom_step(.25)
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.battle_presentation_enabled=true;app.battle_art.set_process(false)
	app.state.quest_stage=3;app.state.recruit_companion();app.state.shen_care_stage=5;app.state.shen_care_choice="mobile"
	app._start_battle("training");assert(app.toast_time==0 and not app.save_warning and app.status_label.text.is_empty());app.state.hp=50;app.state._companion_attack_count=1;app._refresh_battle()
	app._battle_action("attack")
	assert(app.battle_art.presentation_details.healing==2 and app.battle_art.presentation_details.self_healing==0 and app.battle_art.presentation_details.support_healing==2)
	assert(app.state.hp==47 and app.battle_player_hp.value==50)
	app.battle_art._process(.5);settle()
	assert(app.battle_art.support_visual_pose()=="assist" and app.battle_player_hp.value==50 and app.battle_hp.value==41)
	app.battle_art._process(.061);settle()
	assert(app.battle_art.support_visual_pose()=="heal" and app.battle_player_hp.value==52)
	app.battle_art._process(.33);settle()
	assert(app.battle_player_hp.value==47 and app.battle_art.support_visual_pose()=="idle")
	app.battle_art._process(2);assert(not app.battle_busy)
	app._battle_action("item")
	assert(app.battle_art.presentation_details.self_healing==45 and app.battle_art.presentation_details.support_healing==0)
	app.battle_art._process(2);app.state.enemy_hp=20;app.state._companion_attack_count=1;app._refresh_battle()
	app._battle_action("attack")
	assert(app.battle_art.presentation_details.enemy_defeated and app.battle_art.presentation_details.companion_damage==7)
	app.battle_art._process(.48);assert(app.battle_art._pose(true).defeat==0)
	app.battle_art._process(.081);assert(app.battle_art._pose(true).defeat>0 and app.battle_art._pose(true).recoil>0)
	app.battle_art._process(2);app._close_modal();app.state.set_formation("护后");app._start_battle("training")
	app._battle_action("guard");app.battle_art._process(.9)
	assert(app.battle_art.presentation_details.support.cover>0 and app.battle_art.support_visual_pose()=="cover")
	app.battle_art._process(2);app.battle_presentation_enabled=false;app._battle_action("flee");app._close_modal()
	app.queue_free();await create_timer(.25).timeout
	print("PASS: Shen assist/heal/cover timing, real health interpolation and delayed support finisher");quit()
