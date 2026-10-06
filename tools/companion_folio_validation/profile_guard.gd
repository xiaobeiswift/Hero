extends SceneTree
# Deliberately no game scripts, scenes, autoloads, or preloads in this guard.

func _unlinked(path: String) -> bool:
	var directory := DirAccess.open("/")
	var current := "/"
	for component in path.split("/", false):
		current = current.path_join(component)
		if directory.is_link(current):
			return false
	return true

func _refuse(message: String) -> void:
	push_error("HERO_PROFILE_GUARD: " + message)
	quit(2)

func _initialize() -> void:
	var root := OS.get_environment("HERO_FOLIO_QA_OWNED_ROOT")
	var expected := root.path_join("data/godot/app_userdata/Hero · 渡灯录")
	var token := OS.get_environment("HERO_FOLIO_QA_TOKEN")
	if not root.is_absolute_path() or root.simplify_path() != root or not _unlinked(expected):
		_refuse("invalid or linked QA path")
		return
	if OS.get_environment("HERO_FOLIO_QA_USER_DIR") != expected:
		_refuse("declared user directory mismatch")
		return
	# Python exclusively creates this caller-owned 0700 root and 0600 token.
	if token.length() != 64 or not _unlinked(root.path_join(".hero-folio-qa-owner")) or FileAccess.get_file_as_string(root.path_join(".hero-folio-qa-owner")) != token:
		_refuse("owned-root token mismatch")
		return
	for entry in [["HOME", "home"], ["XDG_DATA_HOME", "data"], ["XDG_CONFIG_HOME", "config"], ["XDG_CACHE_HOME", "cache"]]:
		if OS.get_environment(entry[0]) != root.path_join(entry[1]):
			_refuse("profile environment mismatch")
			return
	if OS.get_user_data_dir().simplify_path().trim_suffix("/") != expected or ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/") != expected:
		_refuse("resolved user:// is outside the exact QA profile")
		return
	var directory := DirAccess.open(expected)
	if directory == null:
		_refuse("missing user data directory")
		return
	directory.include_hidden = true
	directory.include_navigational = false
	if directory.list_dir_begin() != OK:
		_refuse("cannot enumerate user data")
		return
	var first := directory.get_next()
	directory.list_dir_end()
	if not first.is_empty():
		_refuse("user data directory is not empty")
		return
	print("HERO_PROFILE_GUARD_OK")
	quit(0)
