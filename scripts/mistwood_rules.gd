class_name MistwoodRules
extends RefCounted
const GAUGES:Array[String]=["rain","stone","basin"]
const APPROACHES:Array[String]=["duel","repair","records"]
const ENDINGS:Array[String]=["release_water","warn_ferries"]
static func begin(s)->bool:
 if s.battle_active or s.chapter_two_stage<4 or s.mist_stage!=0:return false
 s.mist_stage=1
 return true
static func access(s,route:String)->bool:
 if s.battle_active or s.mist_stage!=1 or not s.mist_approach.is_empty() or not APPROACHES.has(route):return false
 if route=="duel":
  if s.battle_kind!="mist_scout" or s.enemy_hp>0:return false
 elif route=="repair":
  if int(s.resources.timber)<1 or int(s.resources.cloth)<1:return false
  s.resources.timber-=1;s.resources.cloth-=1
 elif s.chapter_two_ending!="open_records":return false
 s.mist_approach=route
 if route!="duel":s.gain_xp(20)
 _advance(s)
 return true
static func record(s,id:String)->bool:
 if s.battle_active or s.mist_stage!=1 or not GAUGES.has(id) or s.mist_gauges.has(id):return false
 if id=="stone" and s.mist_approach.is_empty():return false
 s.mist_gauges.append(id);s.gain_xp(10);_advance(s)
 return true
static func _advance(s)->void:
 if s.mist_gauges.size()==3 and not s.mist_approach.is_empty():
  s.mist_stage=2;s.mist_gauges.assign(GAUGES)
static func victory(s)->bool:
 if s.mist_stage!=2:return false
 s.mist_stage=3
 return true
static func resolve(s,choice:String)->bool:
 if s.battle_active or s.mist_stage!=3 or not ENDINGS.has(choice):return false
 s.mist_stage=4;s.mist_ending=choice;s.coins=mini(999999,s.coins+60);s.gain_xp(100)
 var id="herb" if choice=="release_water" else "cloth"
 s.resources[id]=mini(9999,int(s.resources[id])+(3 if id=="herb" else 2))
 return true
static func restore(s,data:Dictionary)->void:
 s.mist_stage=s._bounded_int(data,"mist_stage",0,0,4)
 s.mist_approach=String(data.get("mist_approach",""))
 s.mist_ending=String(data.get("mist_ending",""))
 s.mist_gauges.clear()
 for id in data.get("mist_gauges",[]):
  if GAUGES.has(id) and not s.mist_gauges.has(id):s.mist_gauges.append(id)
 if s.mist_stage>=2:s.mist_gauges.assign(GAUGES)
 elif s.mist_stage==1:_advance(s)
static func valid(data:Dictionary,version:int)->bool:
 if version>=6:
  for key in ["mist_stage","mist_approach","mist_ending","mist_gauges"]:
   if not data.has(key):return false
 if data.has("mist_gauges"):
  if not data.mist_gauges is Array:return false
  for id in data.mist_gauges:
   if not id is String or not GAUGES.has(id):return false
 var stage=int(clampf(float(data.get("mist_stage",0)),0,4))
 var route=String(data.get("mist_approach",""))
 if not route.is_empty() and not APPROACHES.has(route):return false
 if stage>0 and int(clampf(float(data.get("chapter_two_stage",0)),0,4))<4:return false
 if stage==0 and (not route.is_empty() or not data.get("mist_gauges",[]).is_empty() or not String(data.get("mist_ending","")).is_empty()):return false
 if stage<4 and not String(data.get("mist_ending","")).is_empty():return false
 if route=="records" and data.get("chapter_two_ending","")!="open_records":return false
 if stage>=2 and route.is_empty():return false
 if stage==4 and not ENDINGS.has(data.get("mist_ending","")):return false
 if data.get("map_id","")=="mistwood" and stage==0:return false
 return true
