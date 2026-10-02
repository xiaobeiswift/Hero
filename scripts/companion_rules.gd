class_name CompanionRules
extends RefCounted
## Persistent personal-quest and active-party rules, independent of the scene tree.
const SHEN="沈青"
const TANG="唐栖"
const QIN="秦禾"
const CHOICES=["teach","preserve"]
static func available(s) -> Array[String]:
 var result:Array[String]=[]
 if s.companion_unlocked:result.append(SHEN)
 if s.tangqi_unlocked:result.append(TANG)
 if s.has_method("qin_recruited") and s.qin_recruited():result.append(QIN)
 return result
static func active(s) -> String:
 if s.has_method("active_party_companion"):return s.active_party_companion()
 var roster=available(s)
 if roster.has(s.active_companion):return s.active_companion
 return roster[0] if not roster.is_empty() else ""
static func select(s,id:String) -> bool:
 if s.has_method("set_party_roster"):
  if id.is_empty():return s.set_party_roster(["hero"])
  if not available(s).has(id):return false
  return s.set_party_roster(["hero",{SHEN:"shen",TANG:"tang",QIN:"qin"}[id]])
 if s.battle_active or not available(s).has(id):return false
 s.active_companion=id
 s._companion_attack_count=0
 return true
static func can_begin(s) -> bool:
 return not s.battle_active and s.bridge_repaired and s.chapter_two_stage>=4 and s.tangqi_stage==0
static func begin(s) -> bool:
 if not can_begin(s):return false
 s.tangqi_stage=1
 return true
static func recover(s) -> bool:
 if s.battle_active or s.tangqi_stage!=1:return false
 s.tangqi_stage=2
 return true
static func resolve(s,choice:String) -> bool:
 if s.battle_active or s.tangqi_stage!=2 or not CHOICES.has(choice):return false
 s.tangqi_stage=3
 s.tangqi_choice=choice
 var resource="cloth" if choice=="teach" else "iron"
 s.resources[resource]=mini(9999,int(s.resources[resource])+2)
 s.gain_xp(50)
 return true
static func recruit(s) -> bool:
 if s.has_method("_recruit_party_companion"):return s._recruit_party_companion("tang")
 if s.battle_active or s.tangqi_stage!=3 or s.tangqi_unlocked:return false
 s.tangqi_unlocked=true
 s.active_companion=TANG
 s._companion_attack_count=0
 return true
static func description(s) -> String:
 if active(s)==QIN:return "独立出战：守渡横杖为一名仍站立的队友抵挡下一次来袭。"
 if active(s)==TANG:return "并肩：每两次出招追加4伤害，并回复1真气；护后：仅对重击减伤5。"
 if active(s)==SHEN:
  return "并肩：每两次出招追加7伤害%s；护后：每次来袭减伤%d。" % ["并恢复2气血" if s.ShenCare.mobile_heal(s)>0 else "",2+s.ShenCare.shore_bonus(s)]
 return "暂无同行人。"
static func assist(s,messages:Array[String]) -> void:
 if not active(s) in [SHEN,TANG]:return
 s._companion_attack_count+=1
 if s._companion_attack_count%2!=0 or s.enemy_hp<=0:return
 var id=active(s)
 var damage=4 if id==TANG else 7
 damage=s.deal_enemy_damage(damage,true)
 if id==TANG:
  var before=s.qi;s.qi=mini(s.max_qi,s.qi+1)
  messages.append("唐栖以短尺拆招，追加%d点伤害；为你赢得换气空隙，回复%d真气。" % [damage,s.qi-before])
 else:
  messages.append("沈青与你并肩出手，追加 %d 点伤害。" % damage)
  if s.ShenCare.mobile_heal(s)>0:
   var before=s.hp;s.hp=mini(s.max_hp,s.hp+s.ShenCare.mobile_heal(s))
   if s.hp>before:messages.append("沈青与你换步照应，恢复%d点气血。" % (s.hp-before))
static func cover(s,incoming:int,messages:Array[String]) -> int:
 var id=active(s)
 var reduction=5 if id==TANG and s.enemy_strike_is_heavy() else (2+s.ShenCare.shore_bonus(s) if id==SHEN else 0)
 if reduction==0:return incoming
 var result=maxi(1,incoming-reduction)
 messages.append("%s护住后路，替你分担 %d 点伤害。" % [id,incoming-result])
 return result
static func restore(s,data:Dictionary) -> void:
 s.tangqi_stage=s._bounded_int(data,"tangqi_stage",0,0,3)
 s.tangqi_choice=String(data.get("tangqi_choice",""))
 s.tangqi_unlocked=bool(data.get("tangqi_unlocked",false))
 s.active_companion=String(data.get("active_companion",""))
 if not s.has_method("active_party_companion"):s.active_companion=active(s)
static func valid(data:Dictionary) -> bool:
 if data.has("tangqi_unlocked") and not data.tangqi_unlocked is bool:return false
 var stage=int(clampf(float(data.get("tangqi_stage",0)),0,3))
 if stage>0 and (int(clampf(float(data.get("chapter_two_stage",0)),0,4))<4 or not data.get("bridge_repaired",false)):return false
 if stage>=3 and not CHOICES.has(data.get("tangqi_choice","")):return false
 if data.get("tangqi_unlocked",false) and stage<3:return false
 return true
