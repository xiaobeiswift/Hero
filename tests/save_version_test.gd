extends SceneTree
const State=preload("res://scripts/game_state.gd")
var failures=0
var checks=0
func _init() -> void:
	var state=State.new()
	var path="user://hero-schema-audit.json"
	check(state.save_game(path)==OK,"Save current schema")
	var file=FileAccess.open(path,FileAccess.READ);var doc=JSON.parse_string(file.get_as_text());file.close()
	check(doc.version==State.SAVE_VERSION,"New saves identify the current schema")
	doc.version=1;write(path,doc)
	check(state.load_game(path)==OK,"Version1 remains readable")
	doc.version=2;write(path,doc)
	check(state.load_game(path)==OK,"Version2 remains readable")
	doc.version=3;write(path,doc)
	check(state.load_game(path)==OK,"Version3 remains readable")
	doc.version=4;write(path,doc)
	check(state.load_game(path)==OK,"Version4 remains readable")
	for invalid in [0,1.5,State.SAVE_VERSION+1,99]:
		var before=state.to_dict()
		doc.version=invalid;write(path,doc)
		check(state.load_game(path)==ERR_FILE_UNRECOGNIZED and state.to_dict()==before,"Unknown schema rejected atomically: "+str(invalid))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures==0:print("PASS: %d save schema checks" % checks)
	else:push_error("FAIL: save schema checks")
	quit(0 if failures==0 else 1)
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures+=1;push_error(label)
func write(path:String,doc:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(doc));file.close()
