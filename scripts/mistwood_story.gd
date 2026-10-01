class_name MistwoodStory
extends RefCounted
var host
const GAUGE_IDS={"mist_rain_gauge":"rain","mist_stone_gauge":"stone","mist_basin":"basin"}
func _init(owner)->void:host=owner
func handle(id:String)->bool:
 match id:
  "exit_mistwood":entry()
  "return_frostbridge":host._travel("frostbridge",Vector2(1420,235))
  "mist_guide":guide()
  "mist_rain_gauge","mist_stone_gauge","mist_basin":gauge(GAUGE_IDS[id])
  "mist_camp":camp()
  "mist_scout":scout()
  "mist_gate":gate()
  _:return false
 return true
func entry()->void:
 if host.state.chapter_two_stage<4:
  host._modal("竹坡古道","道路 / 听雨关","霜桥原账还没有归处。先和温行舟商议清楚，再去追查账末的山雨刻度。")
  return
 host._modal("山雨未至，令已先行","第三章 / 听雨辨令","原账最后一行写着‘雾竹坡雨尺已满’，落款却早于那场山雨。\n\n雾竹坡有三处旧刻度，守着它们的秦禾曾经替水司记雨。你沿东北竹坡道上行，想问她一句：一场还没落下的雨，怎样先写进了公文？\n\n建议4级以上。可先回村研习内门藏页；坡上也有免费避雨营地。",[["走入雾竹坡",enter_region],["留在霜桥",host._close_modal]],true)
func enter_region()->void:
 if host.state.mist_stage==0 and not host.state.begin_mistwood():return
 host._travel("mistwood",Vector2(150,550))
func guide()->void:
 var s=host.state
 if s.mist_stage==3:
  host._modal("秦禾 · 旧监水吏","抉择 / 雨声与钟声","三处刻度与原令的时辰对不上。守令使拿出的底稿表明：雨还没落，有人已经预支了‘水患’的粮价。\n\n秦禾看向坡下。证据够了，可眼前的水还在涨。\n\n[color=#d3b276]先通缓水渠[/color]：为近坡田地争取时辰，由秦禾随后传信，得药草×3\n[color=#d3b276]先鸣渡船钟[/color]：先让下游船家撤离，由守坡人缓开石闸，得布料×2\n两种选择均得100修为、60文，且只结算一次。",[["先通缓水渠",finish.bind("release_water")],["先鸣渡船钟",finish.bind("warn_ferries")]],true)
  return
 if s.mist_stage>=4:
  var result="近坡田地先卸下了水压。秦禾按你的安排，沿路传去了更正的雨令。" if s.mist_ending=="release_water" else "渡船钟在雨声里响了三遍。等最后一艘船靠岸，守坡人才缓开石闸。"
  host._modal("秦禾","听雨辨令 / 余声",result+"\n\n‘刻度能量水深，量不了一个人肯不肯回头。’\n\n秦禾将底稿抄了两份：一份留下，一份由你带走。关于水令与粮价的线索，已经不再只是一张可被改掉的纸。")
  return
 host._modal("秦禾 · 旧监水吏","雾竹坡 / 雨过留痕","‘雨来过没有，竹子和石头都记得。’\n\n先看北边雨痕竹尺，再量东南分水石盂；东北叠石刻度由巡坡斥候看守，须先到中东山道取得勘量许可。\n\n你可以较量，也可以帮修警亭。若霜桥原账已经公示，还能拿它说明来意。\n\n三处读数齐备后，再到东侧听雨关问守令使。",[["记下路线",host._close_modal]],true)
func gauge(id:String)->void:
 var s=host.state
 if s.mist_gauges.has(id):
  host._modal("旧刻度","听雨辨令 / 已记读数","这处痕迹已经拓下，重复查看不会再获得修为。")
  return
 if id=="stone" and s.mist_approach.is_empty():
  host._modal("叠石刻度","听雨辨令 / 尚无许可","刻度旁系着巡坡斥候的封绳。先到中东山道找他谈谈，取得勘量许可后再拓读。")
  return
 var texts={
 "rain":["雨痕竹尺","雨痕只到第三道细线，原令却记成第七道。最上面几道仍沾着干燥的旧灰。"],
 "stone":["叠石刻度","旧苔在昨夜才被水打湿。原令上写的‘昨日午前已漫过石台’，比水痕足足早了半日。"],
 "basin":["分水石盂","石盂边残留一圈细砂，说明上游先放过一道急水。来水并非全由这场山雨积成。"]}
 host._modal(texts[id][0],"勘量 / 三处雨痕",texts[id][1]+"\n\n把这一处读数与霜桥的记时放在一起，才看得出被提前写下的那半天。",[["拓下读数",record.bind(id)],["稍后再看",host._close_modal]],true)
func record(id:String)->void:
 if host.state.record_mist_gauge(id):
  host._close_modal();host._toast("读数已入江湖志，修为+10。")
func scout()->void:
 var s=host.state
 if not s.mist_approach.is_empty():
  var routes={"duel":"较量之后，斥候愿意让你看清刻度。","repair":"警亭的支架与篷布已经补好。斥候收起了封绳。","records":"公示的原账有往来船家的印记。斥候不再阻拦勘量。"}
  host._modal("巡坡斥候","听雨辨令 / 许可已得",routes[s.mist_approach]+"\n\n东北石台可以通行。许可只记一次，无需重复出钱或交手。")
  return
 host._modal("巡坡斥候","通行 / 刀锋以外","‘这里的刻度不能任人添改。你凭什么让我信你？’\n\n[color=#d3b276]较量[/color]：看清三拍意图；重戳之后会有换步空隙\n[color=#d3b276]修警亭[/color]：交木料×1、布料×1，帮他稳住雨中的值守处\n[color=#d3b276]出示公示原账[/color]：仅限霜桥曾选择公示原账的旅人\n非战斗方案获得20修为，不另发战斗铜钱。三条路都能继续调查。",[["较量过关",func():host._start_battle("mist_scout")],["修亭 · 木1布1",access.bind("repair")],["出示公示原账",access.bind("records")],["暂且离开",host._close_modal]],true)
func access(route:String)->void:
 if host.state.obtain_mist_access(route):
  host._close_modal();host._toast("取得勘量许可，修为+20。可去东北石台拓读。")
 else:host._toast("修亭需要木料与布料各1份；原账通行需要曾在霜桥公示原账。")
func gate()->void:
 var s=host.state
 if s.mist_stage<2:
  host._modal("听雨关守令使","听雨关 / 读数未齐","‘你带来三处实据，我才愿与你谈那一道令。’\n\n找齐雨痕竹尺、叠石刻度与分水石盂，别只拿一张新纸去推翻一张旧纸。")
 elif s.mist_stage==2:
  host._modal("听雨关守令使","交锋 / 三拍刀势","守令使按住底稿：‘我守令，也要看看你守不守得住自己的说法。’\n\n[color=#d3b276]护刃 → 惊竹重击 → 收刀回息[/color]\n护刃时承伤减半，重击会附加破绽，回息时你的出招额外+8伤害。\n蓄锋可留到回息再用；卸劲按实际来击次数消耗。",[["请他交出底稿",func():host._start_battle("mist_keeper")],["回营地整备",host._close_modal]],true)
 else:
  host._modal("听雨关","听雨辨令 / 底稿已得","守令使已经交出原令底稿。"+("回秦禾处商议眼前的水势。" if s.mist_stage==3 else "刻度与底稿都留了副本，再没有人能独自改掉昨夜的雨。"))
func camp()->void:
 host._modal("避雨营地","休整 / 一檐山雨","油布下面留着热茶和干柴。不论你刚才走的是哪条路，都可在此免费调息。\n\n换上合适的武学和同行人，再去听雨关。",[["避雨调息",rest],["继续赶路",host._close_modal]])
func rest()->void:
 host.state.heal_rest();host._close_modal();host._toast("避雨调息，气血与真气恢复。")
func battle_victory(kind:String)->void:
 if kind=="mist_scout":
  host._modal("巡哨收刀","听雨辨令 / 取得许可","‘你看得清我换步的空隙，也许真能看清那场雨。’\n\n斥候准你拓读东北石台。许可已记下，继续查验还未读过的刻度。",[["收好许可",host._close_modal]],true)
 else:
  host._modal("雨前写成的令","听雨辨令 / 原令底稿","底稿的墨比雨痕旧。守令使终于承认，这道水令并非根据雨势写成，而是在等一场能替它作证的雨。\n\n三处读数和霜桥原账拼在一起，指向同一笔提前结算的粮钱。\n\n回秦禾处，先商议如何照应坡上与坡下的人。",[["带回底稿",host._close_modal]],true)
func finish(choice:String)->void:
 if host.state.resolve_mistwood(choice):
  host._close_modal();host._toast("第三章完成 · 修为+100、铜钱+60，收到分支谢礼。")
func title()->String:return ["山雨来信","三尺问雨","听雨关前","令与水势","竹坡余声"][host.state.mist_stage]
func hint()->String:
 return ["由霜桥东北竹坡道前往雾竹坡。","查三处雨痕；中东巡哨有较量、修亭、公示原账三种通行方案。","三处读数齐备，去东侧听雨关索取原令底稿。","回西北秦禾处，商议先行照应何处。","山雨有了实据。可回营地调息，或返回旧地研习。"][host.state.mist_stage]
func target_id()->String:
 var s=host.state
 if s.map_id!="mistwood":
  if s.mist_stage<=0 or s.mist_stage>=4:return ""
  return {"qingwei":"exit_sluice","sluice":"exit_frostbridge","frostbridge":"exit_mistwood"}.get(s.map_id,"")
 if s.mist_stage==1:
  if not s.mist_gauges.has("rain"):return "mist_rain_gauge"
  if not s.mist_gauges.has("basin"):return "mist_basin"
  if s.mist_approach.is_empty():return "mist_scout"
  return "mist_stone_gauge"
 return "mist_gate" if s.mist_stage==2 else ("mist_guide" if s.mist_stage==3 else "mist_camp")
func journal()->String:
 var s=host.state
 return "\n\n[color=#d3b276]第三章 · 听雨辨令[/color]\n%s 雨痕竹尺\n%s 叠石刻度\n%s 分水石盂\n通行：%s\n%s 原令底稿\n%s 水势抉择\n%s" % ["✓" if s.mist_gauges.has("rain") else "◇","✓" if s.mist_gauges.has("stone") else "◇","✓" if s.mist_gauges.has("basin") else "◇",{"":"未定","duel":"较量查哨","repair":"修复警亭","records":"援引公示原账"}[s.mist_approach],"✓" if s.mist_stage>=3 else "◇","✓" if s.mist_stage>=4 else "◇",("先通缓水渠" if s.mist_ending=="release_water" else "先鸣渡船钟") if s.mist_stage==4 else hint()]
