extends SceneTree
const Plate=preload("res://scripts/ferry_battle_backdrop.gd")
const Art=preload("res://scripts/battle_art.gd")
func _initialize()->void:
	var image=Plate.texture();assert(image!=null and image==Plate.texture())
	var target=Vector2(938,Plate.FIGHTING_HEIGHT);var area=Plate.cover_rect(image.get_size(),target)
	assert(area.encloses(Rect2(Vector2.ZERO,target)))
	assert(is_equal_approx(area.size.x/area.size.y,image.get_width()/float(image.get_height())))
	assert(Plate.cover_rect(Vector2.ZERO,target)==Rect2())
	# Measured selected-source deck top is at y=567. Guard its projected contact
	# plane explicitly: an aspect-cover of the full 568px canvas makes actors float.
	var deck_y=area.position.y+567.0*area.size.y/image.get_height()
	assert(deck_y<Art.HERO_HOME.y and Art.HERO_HOME.y-deck_y<40)
	assert(Plate.FIGHTING_HEIGHT==356.0)
	assert(Plate.applies("qingwei"))
	for style in ["sluice","frostbridge","mistwood","training",""]:assert(not Plate.applies(style))
	assert(Art.HERO_HOME==Vector2(229,274) and Art.ENEMY_HOME==Vector2(721,274))
	assert(Rect2(Vector2.ZERO,target).has_point(Art.HERO_HOME) and Rect2(Vector2.ZERO,target).has_point(Art.ENEMY_HOME))
	print("PASS: painted ferry cover geometry, cached texture, regional scope and unchanged feet");quit()
