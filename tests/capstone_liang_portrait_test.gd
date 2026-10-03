extends SceneTree
## Original portrait-resource selection; actual main dialogue input is separate.
const Portraits = preload("res://scripts/character_portraits.gd")
const Liang = preload("res://scripts/painted_battle_liang.gd")
func _initialize() -> void:
	assert(FileAccess.get_sha256(Portraits.LIANG_PATH) == "ce56fcca4b2bfaa5af6511df62b65e1463fc21437d5d452d8cb75ede00e081d3")
	var picture := Portraits.texture_for("liang_zhen")
	assert(picture != null and picture == Portraits.texture_for("liang_zhen"))
	assert(picture.region == Rect2(0,0,1254,1254) and picture.filter_clip)
	assert(picture.atlas.resource_path == Portraits.LIANG_PATH)
	assert(picture.atlas != Liang.texture_for("idle").atlas)
	assert(Portraits.id_for_title("梁缜·签令主事") == "liang_zhen")
	assert(Portraits.id_for_title("梁缜 · 对簿") == "liang_zhen")
	for title: String in ["梁", "签令主事", "韩铮", "霜桥印台", "梁镇"]:
		assert(Portraits.id_for_title(title).is_empty())
	for id: String in ["", "unknown", "liang", "archive_boss"]:
		assert(Portraits.texture_for(id) == null)
	var shared: Texture2D
	for id: String in ["hero","shen","tang","qin"]:
		var original := Portraits.texture_for(id)
		assert(original != null and original.region.size == Vector2(627,627))
		assert(original.atlas.resource_path == Portraits.PATH and original.atlas != picture.atlas)
		assert(original.filter_clip and original.region.position == Vector2(Portraits.CELLS[id])*627)
		if shared == null: shared = original.atlas
		assert(shared == original.atlas)
	for pair: Array in [["沈青 · 药师","shen"],["唐栖 · 修桥匠","tang"],["秦禾 · 旧监水吏","qin"]]:
		assert(Portraits.id_for_title(pair[0]) == pair[1])
	var parent := Control.new()
	for pixels: float in [96,160,224]:
		var rect := Rect2(0,0,pixels,pixels)
		var node := Portraits.attach(parent,"liang_zhen",rect)
		assert(node.texture == picture and node.position == rect.position and node.size == rect.size)
		assert(node.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		assert(node.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		assert(node.get_meta("portrait_id") == "liang_zhen")
	assert(Portraits.attach(parent,"unknown",Rect2(0,0,96,96)) == null)
	parent.free()
	print("PASS: exact separately authored Liang portrait, cached full region, title mapping, unrelated-key rejection, old four portrait parity and96/160/224px non-intercepting attachment")
	quit()
