class_name HetingCartRoutes
extends RefCounted
## Read-only chart guidance. Every edge uses the same loaded-cart collision rule
## as actual movement; no walking-only pier or hypothetical bridge is admitted.
const Region=preload("res://scripts/heting_region.gd")
const ANCHORS:Array[Vector2]=[
	Vector2(65,350),Vector2(330,350),Vector2(680,350),Vector2(1100,350),Vector2(1300,350),Vector2(1530,350),
	Vector2(65,575),Vector2(330,575),Vector2(65,730),Vector2(330,730),Vector2(230,780),
	Vector2(1300,425),Vector2(1530,425),Vector2(1300,565),Vector2(1530,565),Vector2(1300,730),Vector2(1530,730),Vector2(1390,600),
	Vector2(610,600),Vector2(1010,600),Vector2(610,728),Vector2(1010,728),Vector2(610,815),Vector2(1010,815),
	Vector2(475,728),Vector2(1155,728)]
static var _graphs:Dictionary={}

static func _graph(bridge:String)->Dictionary:
	if _graphs.has(bridge):return _graphs[bridge]
	var points=PackedVector2Array()
	for point in ANCHORS:
		if Region.walkable(point,bridge,true):points.append(point)
	var links:Array[PackedInt32Array]=[]
	for i in range(points.size()):links.append(PackedInt32Array())
	for i in range(points.size()):
		for j in range(i+1,points.size()):
			if Region.can_step(points[i],points[j],bridge,true):
				links[i].append(j);links[j].append(i)
	_graphs[bridge]={"points":points,"links":links}
	return _graphs[bridge]

static func route(start:Vector2,finish:Vector2,bridge:String)->PackedVector2Array:
	if bridge not in ["west","east"] or not Region.walkable(start,bridge,true) or not Region.walkable(finish,bridge,true):return PackedVector2Array()
	if start.distance_to(finish)<.001:return PackedVector2Array([start])
	if Region.can_step(start,finish,bridge,true):return PackedVector2Array([start,finish])
	var graph=_graph(bridge)
	var points:PackedVector2Array=graph.points.duplicate()
	var links:Array=graph.links.duplicate(true)
	for point in [start,finish]:
		var index=points.size();points.append(point);links.append(PackedInt32Array())
		for i in range(index):
			if Region.can_step(point,points[i],bridge,true):links[index].append(i);links[i].append(index)
	var start_index=points.size()-2;var end_index=points.size()-1
	var distance=PackedFloat64Array();distance.resize(points.size());distance.fill(INF);distance[start_index]=0
	var previous=PackedInt32Array();previous.resize(points.size());previous.fill(-1)
	var visited=PackedByteArray();visited.resize(points.size());visited.fill(0)
	for _iteration in range(points.size()):
		var current=-1;var best=INF
		for i in range(points.size()):
			if visited[i]==0 and distance[i]<best:current=i;best=distance[i]
		if current==-1:return PackedVector2Array()
		if current==end_index:break
		visited[current]=1
		for neighbor in links[current]:
			var candidate=distance[current]+points[current].distance_to(points[neighbor])
			if candidate<distance[neighbor]:distance[neighbor]=candidate;previous[neighbor]=current
	var result=PackedVector2Array();var index=end_index
	while index!=-1:
		result.append(points[index])
		if index==start_index:break
		index=previous[index]
	if index!=start_index:return PackedVector2Array()
	result.reverse();return result
