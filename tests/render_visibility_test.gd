extends SceneTree
const World=preload("res://scripts/world.gd")
var checks=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:push_error(message);quit(1)
func _initialize()->void:run.call_deferred()
func run()->void:
	var world=World.new();root.add_child(world);world.set_process(false)
	world.camera_pos=Vector2(200,300);world.viewport_rect=Rect2(0,0,938,568)
	check(world._world_rect_visible(Rect2(210,320,50,60)),"Visible art retained")
	check(world._world_rect_visible(Rect2(170,310,20,20)),"Near-edge antialias margin retained")
	check(not world._world_rect_visible(Rect2(1450,800,50,100)),"Distant animated art culled")
	check(not world._world_rect_visible(Rect2(-400,-400,50,50)),"Far negative bounds culled")
	world.terrain_bake_only=true
	check(world._world_rect_visible(Rect2(1450,800,50,100)),"Terrain baker never culls its world-size target")
	world.terrain_bake_only=false;world.render_culling_enabled=false
	check(world._world_rect_visible(Rect2(1450,800,50,100)),"Diagnostic fallback draws every authored prop")
	world.render_culling_enabled=true;world.map_id="sluice"
	check(world._world_rect_visible(Rect2(1450,800,50,100)),"Other maps preserve existing rendering")
	world.map_id="qingwei"
	check(world._terrain_viewport==null and not world.terrain_cache_ready(),"Headless rules/tests keep a no-GPU-cache fallback")
	var positions=[Vector2(460,430),Vector2(300,250),Vector2(998,484),Vector2(1514,930)]
	var before=[]
	for p in positions:before.append(world._can_walk(p))
	world.render_culling_enabled=false;world.terrain_cache_enabled=false
	for i in range(positions.size()):check(world._can_walk(positions[i])==before[i],"Rendering flags never change navigation")
	world.queue_free();await process_frame
	print("PASS: %d render visibility/cache invariants"%checks);quit()
