extends SceneTree
const Art = preload("res://scripts/painted_battle_liang.gd")

func _initialize() -> void:
	assert(Art.POSES.size() == 6)
	assert(Art.DEFAULT_CELL_SIZE == 204.0)
	assert(Art.texture_for("walk") == null and Art.texture_for("unknown") == null)
	assert(Art.source_rect("unknown") == Rect2())
	assert(Art.drawing_rect(Vector2.ZERO, 204, "unknown") == Rect2())
	assert(Art.opaque_rect(Vector2.ZERO, 204, "unknown") == Rect2())
	assert(Art.chest_point(Vector2(42, 53), 204, "unknown") == Vector2(42, 53))
	assert(Art.weapon_point(Vector2(42, 53), 204, "unknown") == Vector2(42, 53))
	assert(Art.pose_for({}) == "idle")
	assert(Art.pose_for({"windup": 0.1}) == "windup")
	assert(Art.pose_for({"strike": 0.1, "windup": 1}) == "strike")
	assert(Art.pose_for({"guard": 1, "strike": 1}) == "guard")
	assert(Art.pose_for({"recoil": 1, "guard": 1}) == "hurt")
	assert(Art.pose_for({"defeat": 1, "recoil": 1}) == "kneel")
	assert(Art.pose_for({"defeat": 0.25, "recoil": 0.12, "guard": 0.12, "strike": 0.005, "windup": 0.005}) == "idle")
	var foot := Vector2(870, 580)
	var fingerprints: Dictionary = {}
	for pose: String in Art.POSES:
		var texture := Art.texture_for(pose)
		assert(texture != null and texture.filter_clip)
		assert(texture == Art.texture_for(pose))
		assert(texture.atlas.get_size() == Vector2(1254, 1254))
		assert(texture.region == Art.source_rect(pose))
		var source: Rect2 = texture.region
		var bounds: Rect2 = Art.OPAQUE_BOUNDS[pose]
		assert(source.encloses(bounds))
		assert(source.has_point(Art.FOOT_ANCHORS[pose]))
		assert(source.has_point(Art.CHEST_ANCHORS[pose]))
		assert(source.has_point(Art.WEAPON_ANCHORS[pose]))
		var source_image := texture.atlas.get_image()
		var frame := source_image.get_region(Rect2i(source))
		var fingerprint := hash(frame.get_data())
		assert(not fingerprints.has(fingerprint))
		fingerprints[fingerprint] = true
		assert(source_image.get_pixelv(Art.CHEST_ANCHORS[pose]).a > 0.78)
		assert(source_image.get_pixelv(Art.WEAPON_ANCHORS[pose]).a > 0.78)
		for size: float in [Art.NPC_CELL_SIZE, 170.0, 204.0, 214.0]:
			var factor := size / Art.REFERENCE_SIZE
			var destination := Art.drawing_rect(foot, size, pose)
			var mapped_foot: Vector2 = destination.position + (Art.FOOT_ANCHORS[pose] - source.position) * factor
			assert(mapped_foot.is_equal_approx(foot))
			var mapped_chest: Vector2 = destination.position + (Art.CHEST_ANCHORS[pose] - source.position) * factor
			var mapped_weapon: Vector2 = destination.position + (Art.WEAPON_ANCHORS[pose] - source.position) * factor
			assert(mapped_chest.is_equal_approx(Art.chest_point(foot, size, pose)))
			assert(mapped_weapon.is_equal_approx(Art.weapon_point(foot, size, pose)))
	assert(is_equal_approx(Art.opaque_rect(foot, Art.NPC_CELL_SIZE, "idle").size.y, 72.0))
	assert(Art.weapon_point(foot, 204, "strike").x < Art.chest_point(foot, 204, "strike").x - 100)
	print("PASS: six unique keys, independent regions, pose priority, cache, unknown fallback, anchor mapping, uniform anatomical scale, 72px idle NPC, no walk alias")
	quit()
