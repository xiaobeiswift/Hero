extends SceneTree
const Harbor=preload("res://scripts/heting_region.gd")
func _initialize()->void:
	assert(Harbor.WaterArt.texture()!=null)
	assert(Harbor.WaterArt.texture()==Harbor.WaterArt.texture())
	assert(Harbor.GroundArt.get_size().x>0)
	for area in [Harbor.CARGO_ISLAND,Harbor.FOOT_PIER,Harbor.WEST_PONTOON,Harbor.EAST_PONTOON]:
		var geometry=Harbor.DeckArt.deck_geometry(area)
		assert(geometry==Harbor.DeckArt.deck_geometry(area))
		for i in range(4):
			assert((area.get_center()+(geometry.uvs[i]-Vector2(.5,.5))*maxf(area.size.x,area.size.y)).distance_to(geometry.points[i])<.001)
	for index in range(3):
		var spec=Harbor.warehouse_spec(index)
		var footprint:Rect2=Harbor.BUILDINGS[index]
		assert(spec.pos==footprint.position and spec.size==footprint.size)
		assert(Harbor.BuildingsArt.texture_for(spec.type)!=null)
		var drawn=Harbor.BuildingsArt.building_rect(spec)
		var anchor:Vector2=Harbor.BuildingsArt.ANCHORS[spec.type]
		var scale=drawn.size.x/Harbor.BuildingsArt.REGIONS[spec.type].size.x
		assert((drawn.position+anchor*scale).distance_to(Vector2(footprint.get_center().x,footprint.end.y))<.001)
		assert(Harbor.BuildingsArt.building_opacity(spec,[drawn.get_center()])<1.0)
		assert(Harbor.BuildingsArt.building_opacity(spec,[Vector2(footprint.get_center().x,footprint.end.y+20)])==1.0)
	var roles=[]
	for id in ["heting_dispatch","heting_relief","heting_scale"]:
		var role=Harbor.npc_role(id)
		assert(not roles.has(role));roles.append(role)
		assert(Harbor.PeopleArt.texture_for(role)!=null)
		assert(Harbor.PeopleArt.texture_for(role)==Harbor.PeopleArt.texture_for(role))
	assert(Harbor.npc_role("healer")=="")
	print("PASS: Heting cached materials, dock UVs, warehouse anchors/party visibility and distinct civilian roles")
	quit()
