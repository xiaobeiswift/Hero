class_name CompanionStory
extends RefCounted
var host
func _init(owner) -> void:host=owner
func bridge() -> void:
 var s=host.state
 if s.tangqi_stage==0:
  host._modal("唐栖 · 修桥匠","同行机缘 / 尺上旧痕","‘新桥能过人了，可有些旧事，还没过得去。’\n\n唐栖的父亲曾修过废闸的桥。那年洪水冲垮渡船，账上却写成了工匠偷料。霜桥原账证明水令被改过，可他还想找回父亲留下的手艺。\n\n‘旧工册装在废闸西北仓边的木匣里。你若愿意陪我走一趟，我想知道他最后画的那一笔。’", [["去找旧工册",begin],["以后再谈",host._close_modal]],true)
 elif s.tangqi_stage==1:
  host._modal("唐栖","尺上旧痕 / 旧册未寻","工册在废闸西北的旧仓木匣。西岸古道可返回废闸。\n\n‘不是为了在谁的账上改一个名字。修桥的人，总该给后来的人留点什么。’")
 elif s.tangqi_stage==2:
  host._modal("唐栖","尺上旧痕 / 一笔未完","工册的末页画着一座会让水的桥。旁边写着：‘桥不是和河争路，是替人借一条路。’\n\n唐栖看了许久，终于放下紧握的短尺。\n\n[color=#d3b276]传给学徒[/color]：把工册抄开，让更多人学会修桥，得布料×2\n[color=#d3b276]留存原稿[/color]：留在驿馆与水令同存，先校正每一处细节，得铁料×2\n两条路都得50修为，也都能邀请唐栖同行。",[["传给学徒",resolve.bind("teach")],["留存原稿",resolve.bind("preserve")],["再想想",host._close_modal]],true)
 elif not s.tangqi_unlocked:
  invite()
 else:
  var memory="学徒们已经在抄那座让水的桥。" if s.tangqi_choice=="teach" else "原稿留在驿馆，每处改笔都另纸注明。"
  host._modal("唐栖","尺上旧痕 / 已有新路",memory+"\n\n‘父亲没走完的路，我可以接着走。不只修这一座桥。’\n\n唐栖已在同行册，可与沈青切换上阵；未上阵的人留在熟悉的地方。",[["查看同行册",roster],["继续赶路",host._close_modal]],true)
func begin() -> void:
 if host.state.begin_tangqi_quest():
  host._close_modal();host._toast("同行机缘：回废闸西北旧仓木匣，寻找旧工册。")
 else:host._toast("先修复南桥，并完成霜桥原账的归处。")
func notebook() -> void:
 host._modal("旧仓木匣","尺上旧痕 / 一纸桥骨","木匣底下压着油纸包。尺规的笔迹不算工整，却把每一道榫口都画得认真。\n\n最末页不是自辩书，而是一座让河水先过的桥。\n\n这就是唐栖要找的旧工册。",[["收好工册",recover],["暂且离开",host._close_modal]],true)
func recover() -> void:
 if host.state.recover_craft_notes():
  host._close_modal();host._toast("取得旧工册。回霜桥南桥，将它交给唐栖。")
func resolve(choice:String) -> void:
 if host.state.resolve_tangqi_quest(choice):
  host._autosave();host._refresh();invite()
func invite() -> void:
 host._modal("唐栖","同行 / 与人借路","‘桥能把人送到对岸，可对岸还有路。’\n\n唐栖把短尺收入袖中：‘让我一起走吧。看清一股力往哪儿来，才能把它送到别处去。’\n\n并肩：每两次出招追加4伤害、回复1真气\n护后：只替你化解重击，减伤5\n"+("沈青保留在同行册，两人可在探索中换阵。" if host.state.companion_unlocked else "青苇渡的沈青仍可结识，往后可在探索中切换同行人。"),[["邀请同行",recruit],["稍后再说",host._close_modal]],true)
func recruit() -> void:
 if host.state.recruit_tangqi():
  host._close_modal();host._toast("唐栖加入同行册并上阵。行囊第五项可切换同行人。")
func roster() -> void:
 if host.current_screen=="battle":return
 var s=host.state
 var body="每次只带一名同行人。切换不消耗物品，也不重置气血或真气。\n\n[color=#d3b276]当前：%s · %s[/color]\n%s\n\n沈青：%s\n唐栖：%s" % [s.current_companion() if not s.current_companion().is_empty() else "独行",s.formation,s.companion_description(),"已结伴" if s.companion_unlocked else "青苇药铺可结识","已结伴" if s.tangqi_unlocked else "完成霜桥原账、修桥后，向唐栖询问旧事"]
 var options:Array=[]
 for id in s.available_companions():options.append(["与"+id+"同行",select.bind(id)])
 if s.companion_unlocked:options.append(["沈青的近况",host.shen_story.route_info])
 options.append(["返回行囊",host._show_inventory])
 host._modal("同行册","队伍 / 各有所长",body,options,true)
func select(id:String) -> void:
 if host.state.select_companion(id):
  host._close_modal();host._toast(id+"已上阵。"+host.state.companion_description())
func pending() -> bool:return host.state.tangqi_stage>0 and not host.state.tangqi_unlocked
func hint() -> String:
 return "返回废闸西北旧仓木匣，寻找唐栖父亲的工册。" if host.state.tangqi_stage==1 else ("回霜桥南桥，将旧工册交给唐栖。" if host.state.tangqi_stage==2 else "回霜桥南桥，与唐栖商议同行。")
func target_id() -> String:
 if not pending():return ""
 match host.state.map_id:
  "qingwei":return "exit_sluice"
  "sluice":return "sluice_cache" if host.state.tangqi_stage==1 else "exit_frostbridge"
  "mistwood":return "return_frostbridge"
  "frostbridge":return "return_sluice" if host.state.tangqi_stage==1 else "bridge_worker"
 return ""
func journal() -> String:
 var s=host.state
 if s.tangqi_stage==0:return "\n\n[color=#d3b276]同行机缘 · 尺上旧痕[/color]\n完成霜桥原账、修复南桥后，找唐栖聊聊旧事。"
 return "\n\n[color=#d3b276]同行机缘 · 尺上旧痕[/color]\n%s 寻回旧工册\n%s 决定手艺的去向\n%s 邀请唐栖同行\n%s" % ["✓" if s.tangqi_stage>=2 else "◇","✓" if s.tangqi_stage>=3 else "◇","✓" if s.tangqi_unlocked else "◇",hint() if pending() else ("工册已传给学徒。" if s.tangqi_choice=="teach" else "原稿与水令一同留存。")]
