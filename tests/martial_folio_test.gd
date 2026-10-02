extends SceneTree
const UnifiedUI = preload("res://tests/unified_ui_test_driver.gd")
const Scene=preload("res://scenes/main.tscn")
const Model=preload("res://scripts/game_state.gd")
const Arts=preload("res://scripts/martial_catalog.gd")
const Rules=preload("res://scripts/advanced_martial_rules.gd")
class NoSave extends Model:
	func save_game(_path:String=SAVE_PATH)->Error:return OK
	func has_save()->bool:return false
var app
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await process_frame
func run()->void:
	app=Scene.instantiate();app.state=NoSave.new();root.add_child(app);await process_frame;app._new_game();app._stop_audio();app.audio_on=false
	await key(KEY_K);await process_frame
	var page=app.overlay.find_child("MartialFolio",true,false)
	assert(page!=null and page.find_child("MartialInvitation",true,false)!=null and app.modal_actions.size()==2)
	await key(KEY_2);assert(not app.active_modal)
	for school in ["听潮阁","照野堂","问石门"]:
		app._new_game();app.state.choose_sect(school);app.state.sect_rank=2;app.state.sect_trial_won=true;app.state.sect_merit=5
		for learned in [false,true]:
			var ids=app.state.school_art_ids()
			if learned:
				assert(app.state.learn_art(ids[2]) and app.state.learn_art(ids[3]))
			for size in [Vector2i(1280,800),Vector2i(1180,737)]:
				root.size=size;await process_frame
				for uses in [0,4,5,14,15]:
					app.state.art_uses[ids[1]]=uses
					var before=app.state.to_dict();await key(KEY_K);await process_frame
					page=app.overlay.find_child("MartialFolio",true,false)
					assert(app.modal_actions.size()==app.state.available_arts().size()+1 and app.state.to_dict()==before)
					assert(page.find_child("EquippedArtTitle",true,false).text==app.state.equipped_art)
					for id in ids:
						var card=page.find_child("ArtCard_"+id,true,false);var art=Arts.definition(id)
						assert(card!=null and Rect2(Vector2.ZERO,page.size).encloses(card.get_rect()))
						for control in card.get_children():
							if control is Control:assert(Rect2(Vector2.ZERO,card.size).encloses(control.get_rect()))
						for label in card.find_children("*","Label",true,false):
							assert(Rect2(Vector2.ZERO,label.get_parent().size).encloses(label.get_rect()))
							assert(label.get_minimum_size().y<=label.size.y)
						assert(card.find_child("ArtCost",true,false).text=="真气 %d  ·  调息 %d 回合"%[int(art.cost),int(art.cooldown)])
						assert(card.find_child("ArtEffects",true,false).text.contains("伤害 %d"%Rules.direct_damage(art,app.state.attack,app.state.art_rank(id))))
						if app.state.available_arts().has(id):
							assert(card.find_child("ArtEquip",true,false).text=="修习 "+id)
							assert(card.find_child("ArtProficiency",true,false).text.begins_with(Arts.rank_name(app.state.art_rank(id))))
						else:
							var locked=card.find_child("ArtLocked",true,false);assert(locked.disabled)
							locked.pressed.emit();assert(app.state.to_dict()==before)
					await key(KEY_ESCAPE);assert(not app.active_modal)
			var available=app.state.available_arts()
			for i in range(available.size()):
				await key(KEY_K);await key(KEY_1+i);assert(app.state.equipped_art==available[i] and not app.active_modal)
				await key(KEY_K);await process_frame
				var description=app.overlay.find_child("EquippedArtDescription",true,false)
				assert(description.size.x==248 and description.position.x+description.size.x<310 and description.get_minimum_size().y<=58)
				await key(KEY_ESCAPE)
		await key(KEY_K);var stale:Callable=app.modal_actions[0];await key(KEY_ESCAPE);await key(KEY_K)
		var current:String=app.state.equipped_art;stale.call();assert(app.active_modal and app.state.equipped_art==current)
		await key(KEY_5);assert(not app.active_modal)
	root.size=Vector2i(1280,800);await process_frame;await key(KEY_K);await process_frame
	var button=app.overlay.find_child("ArtEquip",true,false);var motion=InputEventMouseMotion.new();motion.position=button.get_global_rect().get_center();root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=motion.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await process_frame
	assert(not app.active_modal and app.state.equipped_art==Arts.BASE_ART)
	UnifiedUI.open_training(app);await key(KEY_K);assert(UnifiedUI.active(app))
	app.battle_presentation_enabled=false;UnifiedUI.leave(app);app._close_modal();app._stop_audio();app.queue_free();await create_timer(.25).timeout
	print("PASS: martial folio cards, exact costs/effects/proficiency, locked pages, all schools/window sizes, original numeric and mouse equip, stale callback and battle guards");quit()
