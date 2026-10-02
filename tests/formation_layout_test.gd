extends SceneTree
const Art=preload("res://scripts/formation_battle_art.gd")
var checks=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:push_error(label);quit(1)
func _initialize()->void:run.call_deferred()
func run()->void:
	var art=Art.new();root.add_child(art);await process_frame
	var ground=PackedVector2Array([art.ground_point(0,0),art.ground_point(1,0),art.ground_point(1,1),art.ground_point(0,1)])
	var previous=Vector2.ZERO
	for formation:String in ["护后","并肩"]:
		art.formation=formation
		var feet={"hero":art.hero_foot(),"support":art.support_foot(),"bracer":art.ENEMY_FEET.bracer,"striker":art.ENEMY_FEET.striker}
		check(previous==Vector2.ZERO or previous.distance_to(feet.support)>65,"Existing formations visibly change support placement")
		previous=feet.support
		for id:String in feet:
			check(Geometry2D.is_point_in_polygon(feet[id],ground),formation+" actor foot stays on dock: "+id)
			var label=art.label_rect(id,feet[id])
			check(Rect2(0,66,1280,568).encloses(label),"Unit label stays inside battlefield")
			for other:String in feet:
				if other!=id:check(not label.intersects(art.label_rect(other,feet[other])),formation+" labels do not overlap: "+id+" / "+other)
			var texture
			var rect:Rect2
			match id:
				"hero":texture=art.Hero.texture_for("idle");rect=art.Hero.drawing_rect(feet[id],290)
				"support":texture=art.Shen.texture_for("idle");rect=art.Shen.drawing_rect(feet[id],245)
				_:texture=art.Rival.texture_for("guard" if id=="bracer" else "idle");rect=art.Rival.drawing_rect(feet[id],280 if id=="bracer" else 265)
			var image:Image=texture.get_image()
			if image.is_compressed():image.decompress()
			var visible_top=image.get_height()
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x,y).a>.08:visible_top=y;break
				if visible_top<image.get_height():break
			var head=rect.position.y+visible_top*rect.size.y/image.get_height()
			check(label.end.y+3<head,"Real alpha silhouette clears label: "+id)
	check(art.ENEMY_FEET.bracer.x<art.ENEMY_FEET.striker.x and art.ENEMY_FEET.bracer.y>art.ENEMY_FEET.striker.y,"Protector is nearer center and foreground")
	check(art.floor_mesh.get_surface_count()==1,"Ground uses one cached mesh")
	art.queue_free();await process_frame;print("PASS: %d original formation layout/ground/alpha-label checks; no battle integration claim"%checks);quit()
