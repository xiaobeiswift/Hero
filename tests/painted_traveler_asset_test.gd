extends SceneTree
const Art = preload("res://scripts/painted_traveler_sprite.gd")
func _initialize() -> void:
	var count := 0
	for direction: String in Art.ROWS:
		for frame in range(8):
			var texture := Art.texture_for(direction, frame)
			assert(texture != null)
			assert(texture.region.size == Vector2(256,256))
			assert(texture.region.position.x == frame*256)
			assert(texture.region.position.y == int(Art.ROWS[direction])*256)
			count += 1
	for cell_size in [60.0,72.0,84.0]:
		var foot := Vector2(420,580)
		var rect := Art.drawing_rect(foot,cell_size)
		assert((rect.position+Art.FOOT*(cell_size/256.0)).distance_to(foot)<0.001)
	assert(Art.direction_for(Vector2.RIGHT)=="right")
	assert(Art.direction_for(Vector2.LEFT)=="left")
	assert(Art.direction_for(Vector2.UP)=="back")
	assert(Art.direction_for(Vector2.DOWN)=="front")
	assert(Art.texture_for("front",8)==Art.texture_for("front",0))
	assert(Art.texture_for("front",-1)==Art.texture_for("front",7))
	assert(count==32)
	print("PASS: 32 painted traveler frames; all directional rows, wrapped indices and fixed foot anchors")
	quit()
