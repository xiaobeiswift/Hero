extends SceneTree
## Draw-call integration only, not pixel or aesthetic approval.
const Fixture=preload("res://tests/party_exploration_fixture.gd")
class ProbeWorld extends "res://scripts/world.gd":
	var drawn_ids:Array[String]=[]
	var people:Array=[]
	func _draw()->void:
		drawn_ids.clear();people.clear();super._draw()
	func _draw_follower(id:String)->void:
		drawn_ids.append(id);super._draw_follower(id)
	func _draw_person(p:Vector2,robe:Color,player:bool=false,kind:String="villager")->void:
		people.append({"position":p,"kind":kind});super._draw_person(p,robe,player,kind)
var checks:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func person_at(w,point:Vector2,kind:String="")->bool:
	for person:Dictionary in w.people:
		if person.position==point and (kind.is_empty() or person.kind==kind):return true
	return false
func run()->void:
	var w=ProbeWorld.new();root.add_child(w);w.set_process(false)
	Fixture.select_world(w)
	for map:String in ["qingwei","sluice","frostbridge","mistwood","heting"]:
		w.change_map(map,w._safe_spawn());w.camera_pos=Vector2.ZERO;w.viewport_rect.size=Vector2(1600,1050)
		w.queue_redraw();await process_frame;await process_frame
		check(w.drawn_ids.size()==3,map+" renders exactly three followers")
		for id:String in ["shen","tang","qin"]:check(w.drawn_ids.count(id)==1,map+" draws "+id+" exactly once")
		if map=="qingwei":check(person_at(w,w.interactables.healer.pos,"clerk"),"Deployed Shen station has distinct clerk")
		if map=="frostbridge":check(not person_at(w,w.interactables.bridge_worker.pos),"Deployed Tang station never paints duplicate Tang")
		if map=="mistwood":check(not person_at(w,w.interactables.mist_guide.pos),"Deployed Qin station never paints duplicate person")
	w.change_map("qingwei",Vector2(600,450));w.camera_pos=Vector2.ZERO;w.hud_exclusion_rects.clear()
	var target:=Vector2(500,400)
	for id:String in ["shen","tang","qin"]:
		Fixture.prepare_render(w,[Fixture.render_frame(id,Vector2(500,465))])
		var prompt:Rect2=w._interaction_prompt_rect(target)
		check(not prompt.intersects(Rect2(Vector2(480,403),Vector2(40,70))),"Prompt avoids independent "+id+" body")
	w.queue_free();await process_frame
	print("%s exploration_party_render_consumers: %d checks; draw calls only"%["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
