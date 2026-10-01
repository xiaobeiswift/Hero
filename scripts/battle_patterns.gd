class_name BattlePatterns
extends RefCounted
## Readable three-phase opponents. Old encounters retain their original timing.
const PATTERNS={
 "mist_scout":[
  {"name":"探竹轻刺","damage":14,"heavy":false,"guarded":false,"opening":0,"exposes":false},
  {"name":"追雨重戳","damage":24,"heavy":true,"guarded":false,"opening":0,"exposes":false},
  {"name":"换步回息","damage":9,"heavy":false,"guarded":false,"opening":6,"exposes":false}],
 "mist_keeper":[
  {"name":"护刃试探","damage":10,"heavy":false,"guarded":true,"opening":0,"exposes":false},
  {"name":"惊竹重击","damage":33,"heavy":true,"guarded":false,"opening":0,"exposes":true},
  {"name":"收刀回息","damage":8,"heavy":false,"guarded":false,"opening":8,"exposes":false}]
}
static func phase(kind:String,index:int)->Dictionary:
 if not PATTERNS.has(kind):return {}
 var result:Dictionary=PATTERNS[kind][posmod(index,3)].duplicate(true)
 result.make_read_only()
 return result
static func intent(kind:String,index:int)->String:
 var p=phase(kind,index)
 if p.is_empty():return ""
 var traits:Array[String]=[]
 if p.guarded:traits.append("受击减半")
 if p.opening>0:traits.append("你的出招+%d伤害" % p.opening)
 if p.exposes:traits.append("附加破绽")
 return "%s · %s（%d）%s" % [p.name,"重击" if p.heavy else "轻击",p.damage," · "+" / ".join(traits) if not traits.is_empty() else ""]
static func outgoing(kind:String,index:int,amount:int,support:bool=false)->int:
 var p=phase(kind,index)
 if p.is_empty():return amount
 if p.guarded:return maxi(1,int(ceil(float(amount)*0.5)))
 return amount+(int(p.opening) if not support else 0)
