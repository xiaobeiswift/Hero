class_name SaveSlotsUI
extends RefCounted
const Slots=preload("res://scripts/local_save_slots.gd")
var host
var store
func _init(owner,directory:String="user://")->void:
 host=owner;store=Slots.new(directory)
func title(slot:int)->String:return ["自动续写","手记一","手记二","手记三"][slot] if slot>=0 and slot<=3 else "未知手记"
func summary(meta:Dictionary)->String:
 match meta.get("status","empty"):
  "empty":return "空白"
  "valid":
   var stamp=Time.get_datetime_string_from_unix_time(int(meta.get("modified",0)))
   return "%d级 · %s\n%s UTC" % [int(meta.get("level",1)),String({"qingwei":"青苇渡","sluice":"旧闸","frostbridge":"霜桥驿","mistwood":"雾竹坡","heting":"鹤汀埠"}.get(meta.get("location",""),"江湖")),stamp]
  "incompatible":return "由更新版本写下，需使用兼容游戏版本"
 return "文件不可读，可查看是否留有备份"
func save_page()->void:
 if host.current_screen in ["battle","title"]:return
 var body="三份手动手记独立保存，开始新旅程不会删除它们。\nF5仍是快速自动存档，F9仍是快速续写。\n\n"
 if host.browser_mode:body="三份手记保存在此浏览器与当前网站，清除网站数据会丢失它们。\n刷新或关闭页面前请先保存；不同设备不会自动同步。\n\n"
 var choices:Array=[]
 for id in [1,2,3]:
  body+="[color=#d3b276]%s[/color] · %s\n\n" % [title(id),summary(store.describe(id))]
  choices.append(["写下"+title(id),request_save.bind(id)])
 choices.append(["返回江湖",host._close_modal])
 host._modal("旅途手记","存档 / 留住不同的江湖",body,choices,true)
func load_page()->void:
 if host.current_screen=="battle":return
 var body="选择手记可查看详情与备份；查看不会替换当前进度。\n\n"
 var choices:Array=[]
 for id in [0,1,2,3]:
  var info=store.describe(id)
  body+="[color=#d3b276]%s[/color] · %s\n" % [title(id),summary(info)]
  choices.append([title(id),detail.bind(id)])
 choices.append(["返回",back])
 host._modal("续写手记","读档 / 选择一段前缘",body,choices,true)
func back()->void:
 if host.current_screen=="title":host._show_title()
 else:host._close_modal()
func request_save(slot:int)->void:
 if host.current_screen!="explore":return
 if not store.describe(slot).get("exists",false):
  perform_save(slot);return
 host._modal("重写"+title(slot),"存档 / 请确认覆盖","将覆盖这份手记的当前版本。\n\n现有可读手记会先留一份备份；损坏文件不会覆盖已有的好备份。其他两份手记不受影响。\n\n你也可以返回，换一个空白位置。",[["确认重写",confirm_save.bind(slot,host.modal_generation+1)],["返回手记",save_page]],true)
func perform_save(slot:int)->void:
 if host.current_screen!="explore":return
 host.state.position=host.world.player_pos
 var result=store.save_slot(host.state,slot)
 save_page()
 host._toast(title(slot)+"已写下。" if result==OK else "手记未能保存，原文件保持不变。错误："+str(result))
func detail(slot:int)->void:
 if host.current_screen=="battle":return
 var primary=store.describe(slot)
 var body="[color=#d3b276]%s[/color]\n%s\n\n" % [title(slot),summary(primary)]
 var choices:Array=[]
 if primary.get("status","")=="valid":choices.append(["读取当前版本",request_load.bind(slot,false)])
 if slot>0:
  var backup=store.describe_backup(slot)
  body+="[color=#d3b276]上一份备份[/color]\n"+summary(backup)+"\n\n读取备份只续写进度，不会自动覆盖这份手记的当前文件。"
  if backup.get("status","")=="valid":choices.append(["读取备份",request_load.bind(slot,true)])
 choices.append(["返回列表",load_page])
 host._modal(title(slot),"旅途手记 / 当前与备份",body,choices,true)
func request_load(slot:int,backup:bool)->void:
 if host.current_screen=="battle":return
 host._modal("续写"+title(slot)+("的备份" if backup else ""),"读档 / 请确认","读取会替换当前内存中的旅程进度。若要保留这条分支，请先另存一份手记。\n\n读取成功后会更新自动存档，三份手动手记的文件不会因读档而改变。",[["确认读取",confirm_load.bind(slot,backup,host.modal_generation+1)],["返回详情",detail.bind(slot)]],true)
func perform_load(slot:int,backup:bool)->void:
 if host.current_screen=="battle":return
 var result=store.load_backup(host.state,slot) if backup else store.load_slot(host.state,slot)
 if result==OK:
  host._apply_loaded_state(title(slot)+("的备份" if backup else "")+"已续写。")
 else:host._toast("这份手记暂时无法读取，当前旅程未改变。错误："+str(result))

func confirm_save(slot:int,generation:int)->void:
 if generation==host.modal_generation and host.active_modal:perform_save(slot)
func confirm_load(slot:int,backup:bool,generation:int)->void:
 if generation==host.modal_generation and host.active_modal:perform_load(slot,backup)
