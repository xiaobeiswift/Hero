extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Art=preload("res://scripts/painted_battle_tang.gd")
const ShenArt=preload("res://scripts/painted_battle_shen.gd")
const Feedback=preload("res://scripts/companion_battle_feedback.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func settle()->void:
	for tween in app._battle_health_tweens.values():
		if tween.is_valid():tween.custom_step(.25)
func run()->void:
	assert(Art.texture_for("unknown")==null and Art.POSES.size()==4)
	for pose in Art.POSES:
		var frame=Art.texture_for(pose);var i:int=Art.POSES[pose]
		assert(frame!=null and frame.atlas.get_size()==Vector2(1024,1024) and frame.filter_clip)
		assert(frame.region==Rect2((i%2)*512,(i/2)*512,512,512) and frame==Art.texture_for(pose))
		assert(frame.atlas!=ShenArt.texture_for("idle").atlas)
	for scale in [130,156,184]:
		var foot=Vector2(126,266);assert((Art.drawing_rect(foot,scale).position+Art.FOOT*scale/512.0).distance_to(foot)<.001)
	assert(Feedback.pose_for({"name":"唐栖","qi":1},.70,true)=="recover")
	assert(Feedback.pose_for({"name":"唐栖","qi":0},.70,true)=="idle")
	assert(Feedback.pose_for({"name":"沈青","qi":1},.70,true)=="idle")
	assert(Feedback.pose_for({"name":"唐栖","qi":1,"cover":5},.70,true)=="cover")
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame
	app._new_game();app._stop_audio();app.battle_presentation_enabled=true;app.battle_art.set_process(false)
	app.state.tangqi_unlocked=true
	app.state._apply_party_plan(app.state.PartyRoster.load_plan(app.state,{"active_companion":"唐栖"},11))
	assert(app.state.select_companion("唐栖"));app._start_battle("training")
	app.state.qi=0;app.state._companion_attack_count=1;app._refresh_battle();app._battle_action("attack")
	var facts=app.battle_art.presentation_details.support
	assert(facts.name=="唐栖" and facts.damage==4 and facts.qi==1 and facts.healing==0)
	assert(app.state.qi==3 and app.battle_art.companion_name=="唐栖") # two from the basic attack, one from Tang
	var accepted=app.state.to_dict().duplicate(true)
	app.battle_art._process(.50);settle()
	assert(app.battle_art.support_visual_pose()=="assist" and app.battle_hp.value==app.state.enemy_hp)
	app.battle_art._process(.20);assert(app.battle_art.support_visual_pose()=="recover")
	app.battle_art._process(.14);assert(app.battle_art.support_visual_pose()=="idle")
	assert(app.state.to_dict()==accepted)
	app.battle_art._process(2);await process_frame;assert(app.hud.battle_qi.text.contains("3 / 6"))
	app._battle_action("flee");app.battle_art._process(2);app._close_modal()
	assert(app.state.set_formation("护后"));app._start_battle("training");app.state.turn=1;app._refresh_battle()
	app._battle_action("guard");app.battle_art._process(.90);settle()
	assert(app.battle_art.presentation_details.support.cover>0 and app.battle_art.support_visual_pose()=="cover")
	assert(app.battle_player_hp.value==app.state.hp)
	app.battle_art._process(2);app.battle_presentation_enabled=false;app._battle_action("flee");app._close_modal()
	app.queue_free();await create_timer(.25).timeout;print("PASS: Tang support art/caches/feet, accepted assist/qi/cover timing and model-neutral presentation");quit()
