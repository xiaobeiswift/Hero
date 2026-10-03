extends SceneTree
## Draw callback identity/sort consumers only; native pixels reviewed separately.
const Fixture=preload("res://tests/capstone_world_fixture.gd")
const PartyFixture=preload("res://tests/party_exploration_fixture.gd")
const Liang=preload("res://scripts/painted_battle_liang.gd")
class ProbeWorld extends "res://scripts/world.gd":
	var drawn_people:Array=[]
	var follower_draws:Array[String]=[]
	var labels:Array[String]=[]
	var desks:int=0
	func _draw()->void:
		drawn_people.clear();follower_draws.clear();labels.clear();desks=0;super._draw()
	func _draw_person(p:Vector2,robe:Color,player:bool=false,kind:String="villager")->void:
		drawn_people.append({"p":p,"kind":kind});super._draw_person(p,robe,player,kind)
	func _draw_follower(id:String)->void:
		follower_draws.append(id);super._draw_follower(id)
	func _draw_capstone_desk(p:Vector2)->void:
		desks+=1;super._draw_capstone_desk(p)
	func _label(p:Vector2,text:String,size:int,color:Color,width:float=-1,alignment:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,shadow:bool=false)->void:
		labels.append(text);super._label(p,text,size,color,width,alignment,shadow)
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func redraw(w)->void:
	w.queue_redraw();await process_frame;await process_frame
func run()->void:
	var w=ProbeWorld.new();w.terrain_cache_enabled=false;root.add_child(w);w.set_process(false)
	w.ui_font=load("res://assets/fonts/NotoSansSC.otf");w.viewport_rect.size=Vector2(1600,1050)
	PartyFixture.select_world(w)
	for stage:int in range(8):
		for plan:String in ["pause_batch","cancel_proven"]:
			Fixture.sync(w,Fixture.state(stage,plan));w.change_map("sluice",w.CAPSTONE_DESK_APPROACH);w.camera_pos=Vector2.ZERO
			await redraw(w)
			check(w.desks==(0 if stage==0 else 1),"exactly one sorted desk only while underway")
			check(w.follower_draws==["qin","tang","shen"] or w.follower_draws.size()==3,"all3followers included in stage-specific draw")
			for id:String in ["shen","tang","qin"]:check(w.follower_draws.count(id)==1,"follower once "+id)
			if stage>0:check(w.labels.has("待发令案") and w.labels.has(w.capstone_desk_caption()),"backed semantic name and state caption rendered")
			for number:String in ["001","002","003","004"]:check(w.labels.count(number)==(1 if stage>=4 else 0),"exact four sheet numbers, no pre-book rendering")
			if stage in [4,5]:check(w.labels.count("待")==4,"draft all pending stamps")
			if stage>=6:
				check(w.labels.count("撤")==2 and w.labels.count("缓" if plan=="pause_batch" else "续")==2,"same exact cancelled pair with held/continuing pair")
			w.change_map("frostbridge",Vector2(1320,785));w.camera_pos=Vector2.ZERO;await redraw(w)
			var old_actor_count:int=0
			for person:Dictionary in w.drawn_people:
				if person.p==Vector2(1320,745):old_actor_count+=1
			check(old_actor_count==(1 if stage<3 else 0),"archive legacy actor replaced never stacked stage"+str(stage))
			if stage==3:
				check(w.labels.has("梁缜·签令主事"),"Liang exact map label")
				check(Liang.texture_for("idle")!=null and not Liang.POSES.has("walk"),"accepted static helper loaded, no pretend walking")
			if stage>=4:check(w.labels.has("簿已取") and not w.labels.has("梁缜·签令主事"),"empty stand receipt aftermath instead of another boss")
			for person:Dictionary in w.drawn_people:check(person.p!=w.interactables.bridge_worker.pos,"deployed Tang remains absent from former station")
	Fixture.sync(w,Fixture.state(0));w.change_map("frostbridge",Vector2(1320,785));await redraw(w)
	var before:Array=w.drawn_people.duplicate(true);var old_labels:Array=w.labels.duplicate()
	Fixture.sync(w,Fixture.state(7));await redraw(w);Fixture.sync(w,Fixture.state(0));await redraw(w)
	check(w.drawn_people==before and w.labels==old_labels,"stage0 exact old actor/label draw sequence after reset")
	w.queue_free();await process_frame
	print("%s capstone_world_render_consumers: %d checks; draw-call identity/sort consumers, not pixel approval"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
