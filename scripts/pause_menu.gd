class_name JourneyPauseMenu
extends RefCounted
## In-world rest menu. Exiting is gated by the actual save result, not a toast.
const HeroArt=preload("res://scripts/painted_traveler_sprite.gd")
const Paper=preload("res://scripts/inventory_panel.gd")
static func guarded(host,generation:int,action:Callable)->Callable:
	return func():
		if host.quit_pending or host.current_screen!="explore" or not host.active_modal or host.modal_generation!=generation:return
		action.call()
static func show(host)->void:
	if host.current_screen!="explore" or host.quit_pending:return
	host.modal_generation+=1;host._clear_overlay();host.active_modal=true
	host.overlay.set_meta("pause_menu",true)
	var generation:int=host.modal_generation
	var veil=ColorRect.new();veil.color=Color(.01,.04,.04,.74);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.overlay.add_child(veil)
	var frame=host._panel(host.overlay,Rect2(215,106,850,588),Color("123337"),Color("c5aa70"));frame.name="JourneyPause"
	var paper=Paper.PaperSurface.new();paper.position=Vector2(20,20);paper.size=Vector2(300,548);frame.add_child(paper)
	Paper.text(host,frame,"江 湖 小 憩",Rect2(45,40,256,43),28,Color("2a514b"))
	Paper.text(host,frame,host.state.current_region_name(),Rect2(48,85,246,25),16,Color("718477"))
	var art=TextureRect.new();art.texture=HeroArt.texture_for("front",0);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.position=Vector2(54,123);art.size=Vector2(231,290);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(art)
	Paper.text(host,frame,"%s · %d级"%[host.state.player_name,host.state.level],Rect2(48,429,242,34),22,Color("2a514b"))
	Paper.text(host,frame,host.state.sect+"\n气血 %d / %d"%[host.state.hp,host.state.max_hp],Rect2(49,470,235,53),15,Color("718477"))
	Paper.text(host,frame,"歇一歇，再向前",Rect2(360,30,443,43),28,host.PAPER)
	Paper.text(host,frame,"行走已暂停 · 江湖仍在原处等你",Rect2(361,77,433,25),14,Color("a9b9a3"))
	var rows=[["继续行走","回到当前所在之处",host._close_modal],["存一卷手记","保存到三份独立手记之一",host._show_save_slots],["查阅手记","选择手动记录或本地备份",host._show_load_slots],["返回首页","先保存当前进度，再回到首页",func():request_exit(host,true)],["暂别江湖","先保存当前进度，再关闭游戏",func():request_exit(host,false)]]
	for i in range(rows.size()):
		var action=guarded(host,generation,rows[i][2]);host.modal_actions.append(action)
		var y=120+i*72
		var button=host._button(frame,rows[i][0],Rect2(360,y,441,46),action)
		Paper.text(host,button,str(i+1),Rect2(15,11,32,25),15,Color("adbeaa"))
		Paper.text(host,frame,rows[i][1],Rect2(365,y+48,430,19),12,Color("a1b19f"))
	var sound=host._button(frame,"乐声 · "+("开" if host.audio_on else "关"),Rect2(360,508,139,37),guarded(host,generation,func():host._toggle_audio();show(host)))
	sound.name="PauseSound"
	var view=host._button(frame,"视野 · %d%%"%int(host.view_zoom*100),Rect2(515,508,139,37),guarded(host,generation,func():host._change_view_zoom(1,true)))
	view.name="PauseView";view.tooltip_text="探索时也可按 + / − 调整，界面字号保持不变"
	var quality=host._button(frame,"画面 · "+host.view_preferences.quality_caption(),Rect2(670,508,131,37),guarded(host,generation,host._toggle_view_detail))
	quality.name="PauseQuality";quality.tooltip_text="清晰：保留近景细节；轻量：降低渲染负担。不会改变视野范围。"
	var message=host.display_settings_warning if not host.display_settings_warning.is_empty() else "1—5 选择  ·  Esc 继续  ·  + / − 调整视野"
	var status=Paper.text(host,frame,message,Rect2(361,551,442,20),12,Color("d1bc8d"));status.name="PauseDisplayStatus"
static func request_exit(host,to_title:bool)->void:
	if host.current_screen!="explore" or host.quit_pending:return
	var generation:int=host.modal_generation+1
	var destination="首页" if to_title else "桌面"
	host._modal("收卷 · 暂歇", "离开 / 返回"+destination,"将保存当前地点、行囊与任务进度。\n\n只有保存成功才会离开；三份手动手记不受影响。",[["保存并离开",guarded(host,generation,func():save_and_leave(host,to_title))],["再走一程",guarded(host,generation,func():show(host))]])
static func save_and_leave(host,to_title:bool)->void:
	if host.current_screen!="explore" or host.quit_pending:return
	host.state.position=host.world.player_pos
	var error=host.state.save_game();host.save_warning=error!=OK
	if error==OK:
		leave(host,to_title);return
	var generation:int=host.modal_generation+1
	host._modal("手记未能落笔", "保存失败 / 当前旅程仍然保留在内存中","本地写入失败，错误码 %d。游戏尚未退出。\n\n请检查存储空间后重试，或返回江湖。若选择不保存离开，此次未保存的进度会丢失。"%error,[["重试保存",guarded(host,generation,func():save_and_leave(host,to_title))],["返回小憩",guarded(host,generation,func():show(host))],["不保存离开",guarded(host,generation,func():confirm_discard(host,to_title))]],true)
static func confirm_discard(host,to_title:bool)->void:
	var generation:int=host.modal_generation+1
	host._modal("舍下未存的这一程？", "再次确认 / 无法恢复本次未保存的变化","此操作不会删除已有存档，但本次尚未保存的地点、收获和任务进度不会写入。\n\n确定仍要离开吗？",[["继续留在江湖",guarded(host,generation,func():show(host))],["确认不保存离开",guarded(host,generation,func():leave(host,to_title))]],true)
static func leave(host,to_title:bool)->void:
	if to_title:host._show_title();host._refresh()
	else:host._quit_cleanly(false)
