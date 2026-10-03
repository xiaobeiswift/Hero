extends RefCounted
## Entry/progression evidence for the shared automatic battle controller.
## Resource changes belong to the battle model and atomic HeroState settlement.
const IDS: Array[String] = ["story", "training", "sect_trial", "courtyard_practice", "sluice_scout", "sluice_boss", "archive_boss", "mist_scout", "mist_keeper", "heting_receipt", "heting_consignee", "capstone_authorizer"]
const LOCATIONS = {"story":["qingwei","bandit"], "training":["qingwei","bandit"], "sect_trial":["qingwei","mentor"], "courtyard_practice":["qingwei","courtyard_practice"], "sluice_scout":["sluice","ledger_runner"], "sluice_boss":["sluice","sluice_boss"], "archive_boss":["frostbridge","chapter_archive"], "mist_scout":["mistwood","mist_scout"], "mist_keeper":["mistwood","mist_gate"], "heting_receipt":["heting","heting_scale"], "heting_consignee":["heting","consignee_warehouse"], "capstone_authorizer":["frostbridge","chapter_archive"]}
static func can_enter(s, id:String)->bool:
 if not IDS.has(id) or s.battle_active or s.hp<1 or s._party_gate():return false
 if s.map_id!=LOCATIONS[id][0]:return false
 match id:
  "story":return s.quest_stage==3
  "training":return s.quest_stage>=4
  "sect_trial":return s.can_take_sect_trial()
  "courtyard_practice":return true
  "sluice_scout","sluice_boss":return s.can_start_sluice_party_battle(id)
  "archive_boss":return s.can_start_archive_party_battle()
  "heting_receipt":return s.receipt_stage==1 and s.Receipt.can_begin(s)
  "capstone_authorizer":return s._party_pending_token < 0 and s.Capstone.can_confront(s)
  "heting_consignee":return s._party_pending_token < 0 and s.Consignee.can_confront(s)
  "mist_scout":return s.mist_stage==1 and s.mist_approach.is_empty() and s.chapter_two_stage==4
  "mist_keeper":return s.mist_stage==2 and not s.mist_approach.is_empty() and s.mist_gauges.size()==3 and s.chapter_two_stage==4
 return false
static func progress(s,id:String)->Dictionary:
 if id=="capstone_authorizer":return s.Capstone.progress(s)
 if id=="heting_consignee":return s.Consignee.progress(s)
 if id.begins_with("mist_"):
  return {"map":s.map_id,"chapter":s.chapter_two_stage,"chapter_ending":s.chapter_two_ending,"stage":s.mist_stage,"approach":s.mist_approach,"gauges":s.mist_gauges.duplicate(),"ending":s.mist_ending}
 if id=="sect_trial":
  return {"map":s.map_id,"sect":s.sect,"rank":s.sect_rank,"passed":s.sect_trial_won,"art":s.equipped_art}
 return {}
static func settle_extra_win(s,id:String,snapshot:Dictionary)->Dictionary:
 var xp=0;var coins=0
 match id:
  "mist_scout":
   if s.mist_stage!=1 or not s.mist_approach.is_empty():return {"ok":false}
   # The accepted terminal party snapshot is the victory proof. Never inspect
   # unrelated legacy enemy_hp or invoke a default story fallback.
   s.mist_approach="duel"
   s.Mist._advance(s)
   xp=40;coins=18
  "mist_keeper":
   if not s.Mist.victory(s):return {"ok":false}
   xp=90;coins=48
  "sect_trial":
   if not s.can_take_sect_trial():return {"ok":false}
   var proof:Dictionary=snapshot.get("trial_provenance",{})
   if proof.get("required_art","")!=s.sect_art():return {"ok":false}
   s.sect_trial_won=bool(proof.get("met",false))
   xp=45;coins=20
  _:return {"ok":false}
 s.coins=mini(999999,s.coins+coins);s.victories=mini(999999,s.victories+1)
 var messages=s.gain_xp(xp)
 return {"ok":true,"xp":xp,"messages":messages}
