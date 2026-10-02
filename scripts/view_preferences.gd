class_name HeroViewPreferences
extends RefCounted
## Sound and display choices are separate from character/quest saves.
const PATH="user://hero_preferences.cfg"
const ZOOMS=[1.0,1.25,1.6]
const CANVASES=[Vector2i(1280,800),Vector2i(1024,640),Vector2i(800,500)]
var zoom_index:int=0
var full_resolution:bool=true
var sound_enabled:bool=true
func zoom()->float:return ZOOMS[clampi(zoom_index,0,2)]
func canvas_size()->Vector2i:return CANVASES[clampi(zoom_index,0,2)]
func render_size()->Vector2i:return CANVASES[0] if full_resolution else canvas_size()
func caption()->String:return ["标准 100%","近景 125%","细看 160%"][clampi(zoom_index,0,2)]
func quality_caption()->String:return "清晰" if full_resolution else "轻量"
func load_settings(path:String=PATH)->Error:
	var file=ConfigFile.new();var error=file.load(path)
	if error!=OK:return error
	var raw=file.get_value("display","zoom_index",0)
	var quality=file.get_value("display","full_resolution",true)
	var sound=file.get_value("audio","enabled",true)
	if not(raw is int or raw is float) or not is_finite(float(raw)) or float(raw)!=floor(float(raw)) or raw<0 or raw>2:return ERR_INVALID_DATA
	if not quality is bool:return ERR_INVALID_DATA
	if not sound is bool:return ERR_INVALID_DATA
	zoom_index=int(raw);full_resolution=quality;sound_enabled=sound;return OK
func save_settings(path:String=PATH)->Error:
	if path.is_empty():return ERR_INVALID_PARAMETER
	var file=ConfigFile.new();file.set_value("display","zoom_index",clampi(zoom_index,0,2))
	file.set_value("display","full_resolution",full_resolution)
	file.set_value("audio","enabled",sound_enabled)
	var temporary=path+".tmp";var error=file.save(temporary)
	if error!=OK:return error
	error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
	if error!=OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return error
