extends "res://tests/audit_second_region_test.gd"
const Portraits=preload("res://scripts/character_portraits.gd")
func _run()->void:
 var shared:Texture2D
 for id in ["hero","shen","tang","qin"]:
  var t=Portraits.texture_for(id)
  _check(t!=null and t.region.size==Vector2(627,627),"Equal original portrait atlas cell: "+id)
  _check(t.atlas.get_width()==1254 and t.atlas.get_height()==1254 and t.filter_clip,"Atlas dimensions and safe sampling preserved: "+id)
  if shared==null:shared=t.atlas
  _check(shared==t.atlas,"Portrait cells share one texture resource: "+id)
 _check(Portraits.texture_for("unknown")==null,"Unknown portrait safely omitted")
 _check(Portraits.id_for_title("药铺伙计").is_empty(),"Shop assistant is never misidentified as Shen")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.state=AuditState.new();game._new_game()
 var hero=game.find_child("Portrait_hero",true,false)
 _check(hero!=null and hero.texture is AtlasTexture and not game.portrait.visible,"Player card displays hero portrait with fallback glyph hidden")
 for pair in [["沈青 · 药师","shen"],["唐栖 · 修桥匠","tang"],["秦禾 · 旧监水吏","qin"]]:
  game._modal(pair[0],"portrait audit","Readable original dialogue",[["继续",game._close_modal]],true)
  var node=game.overlay.find_child("Portrait_"+pair[1],true,false)
  _check(node!=null and node.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Named dialogue shows non-intercepting portrait: "+pair[1])
  _check(node.position.x>=600 and node.position.y+node.size.y<=120,"Portrait stays in header, outside dialogue body: "+pair[1])
  await _key(KEY_ENTER)
  _check(not game.active_modal,"Portrait cannot block actual keyboard dialogue confirmation")
 game._show_inventory()
 _check(game.overlay.find_child("Portrait_shen",true,false)==null,"Generic inventory does not attach an unrelated character")
 game._close_modal();game._stop_audio();await create_timer(0.25).timeout;game.queue_free();await process_frame
 if failures==0:print("PASS: %d original portrait UI checks" % checks)
 else:push_error("FAIL: portrait UI checks")
 quit(0 if failures==0 else 1)
