extends SceneTree
## Presented status caption and geometry only; no synthetic gameplay claim.
const HUD=preload("res://scripts/party_category_hud.gd")
var checks:int=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	assert(value,message);checks+=1
func run()->void:
	root.size=Vector2i(1179,737);root.content_scale_size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var hud=HUD.new();root.add_child(hud);await process_frame
	var data={"actors":[],"active":true,"round":2,"selected_actor_id":"hero"}
	for id:String in ["hero","shen","tang","qin"]:
		data.actors.append({"id":id,"name":id,"hp":90,"max_hp":100,"qi":6,"max_qi":6,"attack":999,"status":{},"actions":[]})
	hud.set_snapshot(data);await process_frame
	check(hud.status_caption("hero").is_empty() and hud.status_caption("missing").is_empty(),"Absent statuses or actors have no badge")
	data.actors[0].status={"focused_damage":48};hud.set_snapshot(data)
	check(hud.status_caption("hero")=="蓄锋48","Caption is the exact stored amount, independent of attack")
	data.actors[0].status.focused_damage=0
	check(hud.status_caption("hero")=="蓄锋48","Resolved source mutation cannot leak through the detached presented snapshot")
	hud.set_snapshot(data)
	check(hud.status_caption("hero").is_empty(),"Acknowledged consumed focus removes its badge")
	var keys=["barrier","vulnerability_hits","next_hit_reduction","focused_damage"]
	var values=[18,2,12,48]
	var labels=["护18","破绽2","卸12","蓄锋48"]
	for mask in range(16):
		var status:Dictionary={};var expected:PackedStringArray=[]
		for i in range(4):
			if mask & (1<<i):status[keys[i]]=values[i];expected.append(labels[i])
		for actor:Dictionary in data.actors:actor.status=status.duplicate(true)
		hud.set_snapshot(data);await process_frame
		for id:String in hud.groups:
			check(hud.status_caption(id)==" · ".join(expected),"Each actor exposes exactly the same facts used by badge drawing")
			var badges:Array=hud._status_badges(hud._actor(id));var group:Rect2=hud.groups[id]
			var status_area=Rect2(group.position+Vector2(11,35),Vector2(54,88))
			var previous:Array[Rect2]=[]
			for i in range(badges.size()):
				var area:Rect2=hud._status_badge_rect(group,i)
				check(status_area.encloses(area),"Four badges stay within the existing portrait rail, above HP")
				check(hud.FONT.get_string_size(badges[i].text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=48,"Exact status text fits the badge at compact scale")
				for other:Rect2 in previous:check(not area.intersects(other),"Status badges do not overlap")
				for category:String in hud.SLOT_ORDER:check(not area.intersects(hud.command_rects[hud.slot_key(id,category)]),"Badges never cover skill slots")
				previous.append(area)
	data.actors[0].status={"focused_damage":-1};hud.set_snapshot(data)
	check(hud.status_caption("hero").is_empty(),"Nonpositive focus has no badge")
	print("PASS: %d presented status caption/geometry checks; all 16 status combinations across four groups at 1179, exact stored focus, snapshot isolation and consumed-focus removal."%checks)
	hud.queue_free();await process_frame;quit()
