extends SceneTree
## Geometry and finite-lot projection only; no story completion or visual claim.
const Region=preload("res://scripts/heting_region.gd")
const Routes=preload("res://scripts/heting_cart_routes.gd")
var checks:int=0
var failures:int=0
var pairs:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func run()->void:
	var original=Region.points()
	check(original.size()==7,"Default harbor retains exactly seven original markers")
	for stage in range(6):
		var points=Region.points(true,stage)
		check(points.size()==8 and not points.has("heting_grain_boat"),"Chapter adds only one separate warehouse marker")
		for id in original:check(points[id]==original[id],"Original marker unchanged: "+id)
		check(points.consignee_warehouse.pos==Vector2(700,315),"Accepted source position remains exact")
		for id in original:check(points.consignee_warehouse.pos.distance_to(points[id].pos)>75,"Warehouse has independently selectable footprint from "+id)
		for side in ["west","east"]:
			for loaded in [false,true]:
				check(Region.walkable(points.consignee_warehouse.pos,side,loaded),"New source remains legal for feet and cart in every stage")
				check(Region.can_step(Vector2(700,350),points.consignee_warehouse.pos,side,loaded),"North street leads directly to source without a new obstacle")
	for side in ["west","east"]:
		var destinations=[Region.CONSIGNEE_WAREHOUSE,original.heting_scale.pos,original.heting_cargo.pos]
		for x in [60,180,330,595,700,805,1020,1290,1410,1540]:
			for y in [165,315,350,440,580,620,730,815,990]:
				var start=Vector2(x,y)
				if not Region.walkable(start,side,true):continue
				for finish:Vector2 in destinations:
					var route=Routes.route(start,finish,side);pairs+=1
					check(not route.is_empty(),"Every sampled legal cargo position can reach source and either new receiver")
					if route.is_empty():continue
					check(route[0]==start and route[-1]==finish,"Cart route joins exact requested positions")
					for i in range(1,route.size()):
						check(Region.can_step(route[i-1],route[i],side,true),"Every accepted edge uses real loaded motion")
						var steps=maxi(1,ceili(route[i-1].distance_to(route[i])/2.0))
						var safe=true
						for j in range(steps+1):
							if not Region.walkable(route[i-1].lerp(route[i],float(j)/steps),side,true):safe=false;break
						check(safe,"Every 2px route sample stays on physical terrain")
		check(Region.can_step(Vector2(805,425),Vector2(805,595),side,false),"Walking shortcut is preserved")
		check(not Region.can_step(Vector2(805,425),Vector2(805,595),side,true),"New cart cannot use narrow foot pier")
	_finite_visual_lot()
	print("%s: %d consignee geometry/finite-lot checks across %d legal route pairs"%["PASS" if failures==0 else "FAIL",checks,pairs])
	quit(0 if failures==0 else 1)
func _finite_visual_lot()->void:
	for stage in range(6):
		for plan in ["hold_for_inspection","return_to_owner"]:
			var location="" if stage==0 else ("warehouse" if stage<4 else ("cart" if stage==4 else ("public_scale" if plan=="hold_for_inspection" else "grain_boat")))
			var ending=plan if stage==5 else ""
			var hidden=Region.consignee_visual_state(false,stage,location,ending)
			check(not hidden.visible and Region.consignee_layers(hidden).is_empty(),"New scenery never leaks into unfinished old harbor")
			var view=Region.consignee_visual_state(true,stage,location,ending)
			check(view.duhui==(stage<3),"Stationary receiver withdraws after the verified win")
			check(view.warehouse_full==(2 if stage<=3 else 0),"Only one finite new lot is shown at the source before loading")
			check(view.warehouse_empty==(2 if stage>=4 else 0),"Loading and handover leave an empty source position")
			check(view.cart_full==(2 if stage==4 else 0),"Exactly two new baskets travel only while carrying")
			check(view.scale_full==(2 if stage==5 and plan=="hold_for_inspection" else 0),"Only final hold retains two intact samples at scale")
			check(view.boat_empty==(2 if stage==5 and plan=="return_to_owner" else 0),"Return records opening rather than duplicate sealed samples")
			check(view.warehouse_full+view.cart_full+view.scale_full==(0 if stage==5 and plan=="return_to_owner" else 2),"No duplicate batch exists at source/cart/scale")
			check(String(view.boat_record).is_empty()==(stage!=5),"Boat record appears only after final handover")
			check(String(view.scale_record).is_empty()==(stage!=5),"Scale retains the matching final record")
			for place in ["warehouse","cart","scale","boat"]:
				var layout=Region.consignee_basket_layout(place,view)
				var count=0
				for sprite:Dictionary in layout:count+=sprite.baskets
				check(count==int(view.get(place+"_full",0))+int(view.get(place+"_empty",0)),"Actual draw layout contains exactly the declared number of baskets")
				if int(view.get(place+"_full",0))==2:check(layout.size()==1 and layout[0].id=="cargo_hampers_sealed","Two sealed hampers are one atlas sprite, not two duplicated pairs")
			view.warehouse_full=99
			check(Region.consignee_visual_state(true,stage,location,ending).warehouse_full!=99,"Rendering snapshots cannot mutate stored state")
	var actor_rect=Region.ConsigneeArt.opaque_rect(Region.CONSIGNEE_WAREHOUSE,Region.CONSIGNEE_CELL_SIZE)
	check(not actor_rect.intersects(Region.Machinery.drawing_rect("cargo_hampers_sealed",Region.CONSIGNEE_WAREHOUSE_LOT,Region.CONSIGNEE_LOT_SCALE)),"Stationary receiver does not conceal the new-lot basket pair")
