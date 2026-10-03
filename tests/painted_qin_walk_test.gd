extends SceneTree
const Qin = preload("res://scripts/painted_qin_sprite.gd")
func _initialize() -> void:
    assert(Qin.FRAME_COUNT == 4)
    assert(Qin.direction_for(Vector2.DOWN) == "front")
    assert(Qin.direction_for(Vector2.UP) == "back")
    assert(Qin.direction_for(Vector2.LEFT) == "left")
    assert(Qin.direction_for(Vector2.RIGHT) == "right")
    assert(Qin.direction_for(Vector2.ZERO) == "front")
    assert(Qin.direction_for(Vector2(-1, -1)) == "back")
    assert(Qin.texture_for("unknown", 0) == null)
    var hashes: Dictionary = {}
    for direction in Qin.DIRECTIONS:
        hashes.clear()
        for frame in range(4):
            var texture := Qin.texture_for(direction, frame)
            assert(texture != null)
            assert(texture.get_size() == Qin.CELL)
            assert(texture.region.size.x > 250 and texture.region.size.y > 570)
            assert(texture.filter_clip)
            assert(texture.margin.position.x >= 0 and texture.margin.position.y >= 0)
            assert(texture.region.size.x + texture.margin.position.x <= Qin.CELL.x)
            assert(texture.region.size.y + texture.margin.position.y <= Qin.CELL.y)
            assert(texture.atlas.get_size() == Vector2(1254, 1254))
            var hash_value := hash(texture.atlas.get_image().get_region(Rect2i(texture.region)).get_data())
            assert(not hashes.has(hash_value))
            hashes[hash_value] = true
            assert(Qin.texture_for(direction, frame + 4) == texture)
            assert(Qin.texture_for(direction, frame - 4) == texture)
        assert(hashes.size() == 4)
    assert(Qin.idle_texture_for("unknown") == null)
    var idle_hashes: Dictionary = {}
    for direction in Qin.DIRECTIONS:
        var texture := Qin.idle_texture_for(direction)
        assert(texture != null and texture.get_size() == Qin.CELL)
        assert(texture.filter_clip)
        assert(texture == Qin.idle_texture_for(direction))
        assert(texture.atlas.resource_path == Qin.IDLE_PATH)
        var digest := hash(texture.atlas.get_image().get_region(Rect2i(texture.region)).get_data())
        assert(not idle_hashes.has(digest))
        idle_hashes[digest] = true
        assert(texture.atlas != Qin.texture_for(direction, 0).atlas)
    var foot := Vector2(123, 234)
    var rect := Qin.drawing_rect(foot)
    assert(rect.size == Vector2(72, 72))
    assert((rect.position + Qin.FOOT * (72.0 / 672.0)).is_equal_approx(foot))
    print("PASS: Qin four directions, 16 unclipped authored keys, chronology, 72px logical cell, fixed foot anchor, cache/wrap, four separate neutral idles, unknown direction")
    quit()
