class_name HeroViewPreferences
extends RefCounted
## Display choice is separate from character/quest saves and safe to reset.
const PATH="user://hero_preferences.cfg"
const ZOOMS=[1.0,1.25,1.6]
const CANVASES=[Vector2i(1280,800),Vector2i(1024,640),Vector2i(800,500)]
var zoom_index:int=0
func zoom()->float:return ZOOMS[clampi(zoom_index,0,2)]
func canvas_size()->Vector2i:return CANVASES[clampi(zoom_index,0,2)]
func caption()->String:return ["标准 100%","近景 125%","细看 160%"][clampi(zoom_index,0,2)]
func load_settings(path:String=PATH)->Error:
	var file=ConfigFile.new();var error=file.load(path)
	if error!=OK:return error
	var raw=file.get_value("display","zoom_index",0)
	if not(raw is int or raw is float) or not is_finite(float(raw)) or float(raw)!=floor(float(raw)) or raw<0 or raw>2:return ERR_INVALID_DATA
	zoom_index=int(raw);return OK
func save_settings(path:String=PATH)->Error:
	if path.is_empty():return ERR_INVALID_PARAMETER
	var file=ConfigFile.new();file.set_value("display","zoom_index",clampi(zoom_index,0,2))
	var temporary=path+".tmp";var error=file.save(temporary)
	if error!=OK:return error
	error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
	if error!=OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return error
