extends SceneTree
const Routes=preload("res://scripts/heting_cart_routes.gd")
const Region=preload("res://scripts/heting_region.gd")
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var routed:int=0
	for side in ["west","east"]:
		for x in [60,180,330,595,805,1020,1290,1410,1540]:
			for y in [165,350,440,580,620,730,815,990]:
				var start=Vector2(x,y)
				if not Region.walkable(start,side,true):continue
				for finish in [Vector2(230,780),Vector2(1390,600)]:
					var route=Routes.route(start,finish,side);routed+=1
					check(not route.is_empty(),"Every sampled legal loaded position reaches either receiver")
					if route.is_empty():continue
					check(route[0]==start and route[-1]==finish,"Route preserves exact start and destination")
					for i in range(1,route.size()):
						check(Region.can_step(route[i-1],route[i],side,true),"Every displayed segment obeys real loaded-cart collision")
						var safe=true;var steps=maxi(1,ceili(route[i-1].distance_to(route[i])/2.0))
						for step in range(steps+1):
							if not Region.walkable(route[i-1].lerp(route[i],float(step)/steps),side,true):safe=false;break
						check(safe,"Dense route sampling retains the full actor footprint between movement checks")
		for target in [Vector2(230,780),Vector2(1390,600)]:
			var route=Routes.route(Vector2(820,665),target,side)
			var crosses_north=false
			for p in route:
				if p.y<=430:crosses_north=true
			check(crosses_north==((side=="west" and target.x>1200) or (side=="east" and target.x<400)),"Opposite shore uses north-bank bypass; connected shore needs no detour")
			var expected=route.duplicate();route[0]=Vector2.ZERO
			check(Routes.route(Vector2(820,665),target,side)==expected,"Caller mutation cannot corrupt cached bridge topology")
		check(Routes.route(Vector2(230,780),Vector2(230,780),side)==PackedVector2Array([Vector2(230,780)]),"Already-arrived player needs no invented route")
		for invalid in [Vector2(NAN,500),Vector2(500,500),Vector2(805,500),Vector2(0,0)]:
			check(Routes.route(invalid,Vector2(230,780),side).is_empty(),"Unsafe or walking-only start is rejected")
			check(Routes.route(Vector2(230,780),invalid,side).is_empty(),"Unsafe or walking-only destination is rejected")
	check(Routes.route(Vector2(820,665),Vector2(230,780),"north").is_empty(),"Unknown bridge never suggests a route")
	print("%s: %d cart-route checks across%d legal start/destination pairs"%["PASS" if failures==0 else "FAIL",checks,routed]);quit(0 if failures==0 else 1)
