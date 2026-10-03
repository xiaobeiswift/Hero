extends RefCounted
## Read-only preview and explicit empty-slot commit, independent of active state.
const Transfer = preload("res://scripts/local_save_transfer.gd")
const Browser = preload("res://scripts/browser_save_transfer.gd")
var core
var adapter
var _owner
var _host_ref: WeakRef
var _building: bool = false
var _operation: int = 0
var _pending_generation: int = -1
var _preview_token: int = -1
var _target: int = -1

func _init(owner, directory: String = "user://", transport = null, transfer = null) -> void:
	_owner = weakref(owner)
	_host_ref = weakref(owner.host)
	core = transfer if transfer != null else Transfer.new(directory)
	adapter = transport if transport != null else Browser.new()
	adapter.selection_finished.connect(_selected)

func _host(): return _host_ref.get_ref()
func _slots(): return _owner.get_ref()

func allowed() -> bool:
	var host = _host()
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	if not host.browser_mode or not host.web_save_transfer_enabled or host.quit_pending or host.current_screen not in ["title", "explore"]: return false
	if host.state.battle_active or host.state._party_gate() or host.battle_busy: return false
	for key: String in ["party_battle", "receipt_battle", "courtyard_practice"]:
		if host.overlay.has_meta(key): return false
	if is_instance_valid(host.battle_art) and host.battle_art.is_presenting(): return false
	return true

func _live(generation: int) -> bool:
	var host = _host()
	return allowed() and host.active_modal and host.modal_generation == generation and host.overlay.get_meta("save_transfer", false)

func invalidate() -> void:
	_operation += 1
	_pending_generation = -1
	_target = -1
	if _preview_token >= 0: core.cancel_preview(_preview_token)
	_preview_token = -1
	adapter.cancel()

func overlay_cleared() -> void:
	if not _building: invalidate()

func dispose() -> void:
	invalidate()
	adapter.dispose()
	if adapter.selection_finished.is_connected(_selected): adapter.selection_finished.disconnect(_selected)

func _page(title: String, body: String, choices: Array) -> void:
	if not allowed():
		invalidate()
		return
	var host = _host()
	_building = true
	host._modal(title, "浏览器本地手记 / 文件转存", body, choices, true, true)
	_building = false
	host.modal_autosave_on_close = false
	host.overlay.set_meta("save_transfer", true)

func show() -> void:
	if not allowed(): return
	invalidate()
	var body: String = "下载已保存的手记，留一份由你保管的 JSON 文件。\n\n导入仅写入空白手记一至三；已有当前文件、备份或占用路径的位置均不可导入。不会覆盖现有文件，不会读取到当前旅程。\n\n此浏览器与当前网站的本地存储可能被清理。不同设备不会自动同步。"
	if not _host().browser_storage_available: body += "\n\n[color=#d3b276]浏览器未提供持久存储，刷新或关闭可能丢失手记。[/color]"
	if not adapter.available():
		_page("手记转存暂不可用", body + "\n\n当前页面未提供浏览器文件接口，请保留当前页面与已有手记。", [["返回", back]])
		return
	_page("导入 / 导出手记", body, [["导入到空白手记", targets], ["下载已存手记", exports], ["返回", back]])

func back() -> void:
	if not allowed(): return
	invalidate()
	var host = _host()
	host.modal_autosave_on_close = false
	if host.current_screen == "title": host._show_title()
	else:
		_slots().transfer_browse = true
		_slots().save_page()

func targets() -> void:
	if not allowed(): return
	invalidate()
	var body: String = "先选择空白位置，再由你选择一份 JSON 文件（最多 1 MiB）。\n\n"
	var choices: Array = []
	var next_generation: int = _host().modal_generation + 1
	for slot: int in [1, 2, 3]:
		var empty: bool = core.target_available(slot)
		body += "%s · %s\n" % [_slots().title(slot), "空白，可导入" if empty else "已占用，不可导入（包括备份或占用路径）"]
		if empty: choices.append(["选择文件 → " + _slots().title(slot), choose_file.bind(slot, next_generation)])
	if choices.is_empty(): body += "\n三处均已占用。本版只支持空白位置，请保管好下载文件。"
	choices.append(["返回转存", show])
	_page("选择空白手记", body, choices)

func choose_file(slot: int, generation: int) -> void:
	if not _live(generation): return
	invalidate()
	if not core.target_available(slot):
		_page("此处已有手记", "目标位置已被占用，未选择或写入任何文件。\n导入必须使用连备份也不存在的空白手记。", [["重新选择位置", targets], ["返回转存", show]])
		return
	_target = slot
	var next_generation: int = _host().modal_generation + 1
	_page("选择要导入的 JSON", "目标：" + _slots().title(slot) + " · 空白\n\n请在浏览器文件选择器中选择一份本地 JSON，最多 1 MiB。\n文件只在当前页面校验，不会上传到服务器。\n\n取消、返回或重新选择，均不会写入手记。", [["重新选择文件", choose_file.bind(slot, next_generation)], ["取消导入", show]])
	_pending_generation = _host().modal_generation
	# Keep transient browser user activation: picker opens in this input stack.
	if not adapter.choose_file(_operation): _selected(_operation, "read_error", PackedByteArray())

func _selected(operation: int, status: String, bytes: PackedByteArray) -> void:
	if operation != _operation: return
	if not _live(_pending_generation):
		invalidate()
		return
	# Callback is consumed before validation. Repeats cannot mint extra tokens.
	_pending_generation = -1
	_operation += 1
	operation = _operation
	if status != "selected":
		var reason: String = {"cancelled": "已取消选择文件。", "oversize": "文件超过 1 MiB，未读取或导入。", "invalid": "请选择一份有效的 JSON 文件。", "read_error": "浏览器未能读取文件，请重新选择。"}.get(status, "浏览器返回的文件无效。")
		_error(reason)
		return
	var result: Dictionary = core.preview_import(bytes, _target)
	if not result.get("ok", false):
		_error("手记未通过完整校验，或目标已被占用。\n损坏、超大及更新版本的手记不会导入。错误：" + str(result.get("error", ERR_INVALID_DATA)))
		return
	_preview_token = int(result.token)
	var meta: Dictionary = result.metadata
	var region: String = {"qingwei": "青苇渡", "sluice": "旧闸", "frostbridge": "霜桥驿", "mistwood": "雾竹坡", "heting": "鹤汀埠"}.get(meta.get("location", ""), "江湖")
	var body: String = "[color=#d3b276]已校验文件内容[/color]\n旅人：%s\n%d 级 · %s\n气血 %d / %d · 格式 %d\n\n[color=#d3b276]导入位置：%s · 空白[/color]\n当前文件与备份均不存在。确认时会再次检查。\n\n只写入此空白位置，保留文件原始字节。当前旅程与自动存档不变；想续写时，请另外进入查阅手记并确认读取。" % [escape_text(String(meta.get("player_name", "旅人"))), int(meta.get("level", 1)), escape_text(region), int(meta.get("hp", 0)), int(meta.get("max_hp", 0)), int(result.version), _slots().title(_target)]
	var generation: int = _host().modal_generation + 1
	_page("确认导入空白手记", body, [["确认导入 " + _slots().title(_target), confirm.bind(operation, generation)], ["重新选择文件", choose_file.bind(_target, generation)], ["取消导入", show]])

func _error(reason: String) -> void:
	var slot: int = _target
	invalidate()
	_page("未导入手记", reason + "\n\n当前旅程与已有手记均未改变。", [["重新选择文件", choose_file.bind(slot, _host().modal_generation + 1)], ["返回转存", show]])

func confirm(operation: int, generation: int) -> void:
	if operation != _operation or _preview_token < 0: return
	if not _live(generation):
		invalidate()
		return
	var token: int = _preview_token
	var slot: int = _target
	_preview_token = -1 # Single-use UI confirmation, consumed before commit.
	_operation += 1
	adapter.cancel()
	var result: Dictionary = core.commit_import(token)
	core.cancel_preview(token) # Release retained bytes on either terminal result.
	if not result.get("ok", false):
		_error("导入未完成，目标可能已被占用或本地存储无法写入。错误：" + str(result.get("error", ERR_CANT_CREATE)))
		return
	var body: String = _slots().title(slot) + "已写入当前浏览器的本地存储。\n\n当前旅程与自动存档未改变，也未自动读取。可前往查阅手记，另外确认续写。\n\n浏览器持久保存尚无完成回执；请保留原始 JSON。清理网站数据会移除本地手记。"
	if not _host().browser_storage_available: body += "\n\n[color=#d3b276]此浏览器未提供持久存储，刷新或关闭可能丢失手记。[/color]"
	_page("手记已导入", body, [["查阅手记", browse_import], ["返回转存", show]])

func browse_import() -> void:
	if not allowed(): return
	_slots().transfer_browse = true
	_slots().load_page()

func exports() -> void:
	if not allowed(): return
	invalidate()
	var body: String = "只下载已保存并通过校验的原始文件；未保存的当前旅程不会写入下载。\n\n"
	var choices: Array = []
	for slot: int in [0, 1, 2, 3]:
		body += "%s · %s\n" % [_slots().title(slot), _slots().summary(_slots().store.describe(slot))]
		choices.append([_slots().title(slot), export_detail.bind(slot)])
	choices.append(["返回转存", show])
	_page("下载已存手记", body, choices)

func export_detail(slot: int) -> void:
	if not allowed(): return
	invalidate()
	var choices: Array = []
	var body: String = _slots().title(slot) + "\n当前版本：" + _slots().summary(_slots().store.describe(slot))
	var generation: int = _host().modal_generation + 1
	if _slots().store.describe(slot).get("status", "") == "valid": choices.append(["下载当前版本", download.bind(slot, false, generation)])
	if slot > 0:
		var backup: Dictionary = _slots().store.describe_backup(slot)
		body += "\n\n上一份备份：" + _slots().summary(backup)
		if backup.get("status", "") == "valid": choices.append(["下载备份", download.bind(slot, true, generation)])
	body += "\n\n下载不会保存当前旅程，不会修改此处文件。浏览器可能要求你确认保留文件。"
	choices.append(["返回下载列表", exports])
	_page("下载 " + _slots().title(slot), body, choices)

func download(slot: int, backup: bool, generation: int) -> void:
	if not _live(generation): return
	var result: Dictionary = core.export_slot(slot, backup)
	if not result.get("ok", false):
		_page("未请求下载", "现有文件未通过校验或无法读取，未下载。\n原文件与当前旅程均未改变。", [["返回下载列表", exports], ["返回转存", show]])
		return
	# Download must also stay in the real button/key event stack.
	var requested: bool = adapter.request_download(result.bytes, slot, backup)
	_page("下载请求" if requested else "未请求下载", "已请求下载，请在浏览器确认保留\n\n浏览器未提供文件已落盘的回执，请检查下载记录。" if requested else "当前浏览器接口未能发起下载。\n原文件保持不变。", [["返回下载列表", exports], ["返回转存", show]])

static func escape_text(value: String) -> String:
	# No filename or raw JSON enters markup. Escape in one pass, so generated
	# BBCode escape tags are never recursively re-escaped.
	var escaped: String = ""
	for character: String in value:
		match character:
			"[": escaped += "[lb]"
			"]": escaped += "[rb]"
			"&": escaped += "&amp;"
			"<": escaped += "&lt;"
			">": escaped += "&gt;"
			_: escaped += character
	return escaped
