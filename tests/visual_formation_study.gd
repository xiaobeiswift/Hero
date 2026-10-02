extends SceneTree
const Scene=preload("res://scenes/main.tscn")
const Art=preload("res://scripts/formation_battle_art.gd")
var app
var art
func _initialize()->void:
	create_timer(30).timeout.connect(func():quit(99))
	run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,800);app=Scene.instantiate();root.add_child(app);await process_frame;app._stop_audio();app.audio_on=false
	app._clear_overlay();app.active_modal=true;app.current_screen="formation_study"
	var state:HeroState=app.state;state.reset_game();state.gain_xp(600);state.choose_sect("听潮阁");state.equip_art(state.sect_art());state.companion_unlocked=true;state.active_companion="沈青";state.formation="护后";state.hp=state.max_hp;state.qi=state.max_qi
	var rules=preload("res://scripts/heting_receipt_combat.gd").new();assert(rules.configure(state));rules.selected_id="bracer"
	art=Art.new();art.size=Vector2(1280,685);app.overlay.add_child(art);art.set_snapshot(rules.snapshot())
	app._panel(app.overlay,Rect2(0,0,1280,65),Color(.025,.08,.09,.9),Color(.35,.42,.34,.4))
	app._label(app.overlay,"复签不撤",Rect2(28,14,230,34),24,app.PAPER)
	app._label(app.overlay,"公秤外栈桥",Rect2(198,23,200,24),14,app.MUTED)
	app._label(app.overlay,"第 一 招",Rect2(587,18,130,30),20,app.GOLD)
	app._label(app.overlay,"Esc  退开",Rect2(1145,20,105,26),15,app.PAPER)
	app._panel(app.overlay,Rect2(0,670,1280,130),Color("102727"),Color("596a58"))
	app._panel(app.overlay,Rect2(0,634,1280,37),Color(.025,.075,.08,.82),Color(.025,.075,.08,0))
	app._label(app.overlay,"架刀护手 · 正在援护刀客，刀客所受来伤减半",Rect2(35,641,1000,28),15,app.GOLD)
	app._label(app.overlay,"点击对手换目标 · Tab 切换",Rect2(925,644,325,24),13,app.MUTED)
	app._label(app.overlay,"真气 6/6  ·  回春散 3",Rect2(34,688,236,28),15,app.PAPER)
	for i in range(5):
		var text=["1  平击  +2气","2  回潮断浪  −4气","3  守势  +1气","4  回春散","5  退开"][i]
		app._button(app.overlay,text,Rect2(280+i*190,687,177,52),func():pass).add_theme_font_size_override("font_size",16)
	app._label(app.overlay,"保持距离，先看清护手与刀客的前后照应。",Rect2(34,753,920,26),14,app.MUTED)
	app._label(app.overlay,"站位构图预览",Rect2(1100,755,155,25),13,app.MUTED)
	await capture("281-formation-guard-rear-study")
	art.formation="并肩";art.queue_redraw();await capture("282-formation-side-support-study")
	app.queue_free();await create_timer(.25).timeout;print("PASS: two actual-engine composition previews; unintegrated layout study, no gameplay claim");quit()
func capture(name:String)->void:
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK)
