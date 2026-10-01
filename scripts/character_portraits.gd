class_name CharacterPortraits
extends RefCounted
## Original generated atlas. Preserve source PNG; crop equal cells at runtime.
const PATH="res://assets/generated/characters/hero-character-portraits-atlas.png"
const CELLS={"hero":Vector2i(0,0),"shen":Vector2i(1,0),"tang":Vector2i(0,1),"qin":Vector2i(1,1)}
static var _atlas:Texture2D
static func texture_for(id:String)->AtlasTexture:
 if not CELLS.has(id):return null
 if _atlas==null:
  if not ResourceLoader.exists(PATH):return null
  _atlas=load(PATH)
 if _atlas==null:return null
 var cell=Vector2(_atlas.get_width()*0.5,_atlas.get_height()*0.5)
 var part=AtlasTexture.new();part.atlas=_atlas;part.region=Rect2(Vector2(CELLS[id])*cell,cell);part.filter_clip=true
 return part
static func id_for_title(title:String)->String:
 if title.begins_with("沈青"):return "shen"
 if title.begins_with("唐栖"):return "tang"
 if title.begins_with("秦禾"):return "qin"
 return ""
static func attach(parent:Control,id:String,rect:Rect2)->TextureRect:
 var texture=texture_for(id)
 if texture==null:return null
 var node=TextureRect.new()
 node.name="Portrait_"+id
 node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 node.texture=texture
 node.position=rect.position;node.size=rect.size
 node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 node.set_meta("portrait_id",id)
 parent.add_child(node)
 return node
