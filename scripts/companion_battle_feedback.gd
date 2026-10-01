class_name CompanionBattleFeedback
extends RefCounted
## Presentation facts extracted only from accepted, identity-tagged support logs.
static func read(details:Dictionary)->Dictionary:
	var result={"name":"","damage":0,"healing":0,"cover":0,"qi":0}
	for entry in details.get("log",[]):
		var line=String(entry)
		var identity="沈青" if line.begins_with("沈青") else ("唐栖" if line.begins_with("唐栖") else "")
		if identity.is_empty():continue
		result.name=identity
		for pair in [["damage","追加\\s*(\\d+)\\s*点伤害"],["healing","恢复\\s*(\\d+)\\s*点气血"],["cover","替你分担\\s*(\\d+)\\s*点伤害"],["qi","回复\\s*(\\d+)\\s*真气"]]:
			var expression=RegEx.new();expression.compile(pair[1]);var found=expression.search(line)
			if found:result[pair[0]]+=int(found.get_string(1))
	return result
static func pose_for(details:Dictionary,time:float,presenting:bool)->String:
	if not presenting:return "idle"
	if int(details.get("cover",0))>0 and time>=.66 and time<1.18:return "cover"
	if int(details.get("healing",0))>0 and time>=.51 and time<.80:return "heal"
	if details.get("name","")=="唐栖" and int(details.get("qi",0))>0 and time>=.65 and time<.82:return "recover"
	if int(details.get("damage",0))>0 and time>=.36 and time<.65:return "assist"
	return "idle"
