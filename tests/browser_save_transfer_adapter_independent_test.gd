extends SceneTree
## Native injected fake bridge only: this does NOT exercise JavaScriptBridge internals.
const Adapter = preload("res://scripts/browser_save_transfer.gd")
const LIMIT: int = 1048576

class Bridge extends RefCounted:
	var conversions: int = 0
	var downloads: Array = []
	func js_buffer_to_packed_byte_array(value) -> PackedByteArray:
		conversions += 1
		return value.duplicate() if value is PackedByteArray else PackedByteArray()
	func download_buffer(bytes: PackedByteArray, name: String, mime: String) -> void:
		downloads.append([bytes.duplicate(), name, mime])

class Page extends RefCounted:
	var cancels: int = 0
	var chosen: Array = []
	var choose_result: bool = true
	func cancel() -> void:
		cancels += 1
	func chooseFile(operation: int, callback) -> bool:
		chosen.append([operation, callback])
		return choose_result

var checks: int = 0
var failures: Array[String] = []
var results: Array = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func captured(operation: int, status: String, bytes: PackedByteArray) -> void:
	results.append([operation, status, bytes.duplicate()])
func setup():
	results.clear()
	var a = Adapter.new()
	a._bridge = Bridge.new()
	a._page = Page.new()
	a._callback = Callable(self, "captured")
	a.selection_finished.connect(captured)
	return a
func run() -> void:
	var unavailable = Adapter.new()
	check(not unavailable.available(), "native default adapter remains unavailable")
	check(not unavailable.choose_file(1), "native default cannot claim picker opened")
	check(not unavailable.request_download(PackedByteArray([1]), 1, false), "unavailable adapter cannot claim download requested")
	var a = setup()
	check(a.available(), "injected fake bridge seam is available")
	check(a.choose_file(14), "choose request returns adapter result")
	check(a._page.chosen.size() == 1 and a._page.chosen[0][0] == 14 and a._callback != null, "callback retained and operation forwarded")
	check(a._page.cancels == 1, "new operation cancels previous picker first")
	var chinese: PackedByteArray = '{"name":"沈青·渡灯录","hp":37}\n'.to_utf8_buffer()
	a._received([14, "selected", chinese])
	check(results.size() == 1 and results[0][1] == "selected" and results[0][2] == chinese, "mock bridge result preserves UTF-8 Chinese exact bytes")
	check(a._operation == -1, "successful callback consumes operation")
	a._received([14, "selected", chinese])
	check(results.size() == 1 and a._bridge.conversions == 1, "duplicate callback ignored before conversion")
	a.choose_file(15)
	a._received([14, "selected", chinese])
	check(results.size() == 1 and a._bridge.conversions == 1, "stale callback ignored before conversion")
	for status: String in ["cancelled", "oversize", "invalid", "read_error"]:
		a.choose_file(20)
		a._received([20, status])
		check(results.back()[1] == status and results.back()[2].is_empty(), "terminal status " + status + " carries no bytes")
	for args: Array in [[30, "selected"], [30, "selected", null], [30, "selected", chinese, "extra"], [30, "selected", "not a buffer"], [30, "selected", PackedByteArray()], [30, "unknown"]]:
		a.choose_file(30)
		a._received(args)
		check(results.back()[1] == "invalid" and results.back()[2].is_empty(), "malformed terminal result rejected: " + str(args.slice(0,2)))
	var large := PackedByteArray()
	large.resize(LIMIT + 1)
	a.choose_file(31)
	a._received([31, "selected", large])
	check(results.back()[1] == "oversize" and results.back()[2].is_empty(), "post-conversion oversize identified and bytes discarded")
	large.resize(LIMIT)
	a.choose_file(32)
	a._received([32, "selected", large])
	check(results.back()[1] == "selected" and results.back()[2].size() == LIMIT, "one MiB accepted after fake conversion")
	var before: int = results.size()
	a.choose_file(40)
	for args: Array in [[], [40], ["40", "selected", chinese], [40, 3, chinese], [39, "selected", chinese]]:
		a._received(args)
	check(results.size() == before and a._operation == 40, "malformed nonterminal and stale headers ignored")
	for id in [40.5, NAN, INF, -INF, -1]:
		a._received([id, "selected", chinese])
		check(results.size() == before and a._operation == 40, "nonintegral/nonfinite/inactive ID rejected: " + str(id))
	a.choose_file(41)
	a._received([41.0, "selected", chinese])
	check(results.back()[0] == 41 and results.back()[1] == "selected", "integral JavaScript-number operation accepted")
	before = results.size()
	a.choose_file(42)
	a.cancel()
	a._received([42, "selected", chinese])
	check(results.size() == before and a._operation == -1, "cancel invalidates outstanding callback")
	a = setup()
	for slot: int in [0, 1, 2, 3]:
		check(a.request_download(chinese, slot, false), "slot " + str(slot) + " reports request despite void download API")
		var item: Array = a._bridge.downloads.back()
		check(item[0] == chinese and item[2] == "application/json", "slot " + str(slot) + " passes exact saved bytes and MIME")
		check(item[1] == ("Hero-auto.json" if slot == 0 else "Hero-slot-%d.json" % slot), "slot " + str(slot) + " download filename is fixed")
	for slot: int in [1, 2, 3]:
		check(a.request_download(chinese, slot, true), "manual backup " + str(slot) + " download requested")
		check(a._bridge.downloads.back()[0] == chinese and a._bridge.downloads.back()[1] == "Hero-slot-%d-backup.json" % slot, "manual backup " + str(slot) + " exact bytes and filename")
	var download_count: int = a._bridge.downloads.size()
	check(not a.request_download(chinese, 0, true), "autosave backup cannot be exported")
	check(not a.request_download(chinese, -1, false) and not a.request_download(chinese, 4, false), "invalid slots cannot be exported")
	check(not a.request_download(PackedByteArray(), 1, false), "empty bytes cannot be exported")
	large.resize(LIMIT + 1)
	check(not a.request_download(large, 1, false), "oversize bytes cannot be exported")
	check(a._bridge.downloads.size() == download_count, "rejected downloads never call fake bridge")
	large.resize(LIMIT)
	check(a.request_download(large, 1, false) and a._bridge.downloads.back()[0].size() == LIMIT, "exact one MiB export accepted")
	a.choose_file(60)
	var bridge = a._bridge
	var page = a._page
	a.dispose()
	check(a._callback == null and a._page == null and a._bridge == null, "dispose releases retained callback bridge and page")
	check(not a.available() and a._operation == -1, "disposed adapter cannot issue another transfer")
	a._received([-1, "selected", chinese])
	a._received([60, "selected", chinese])
	check(results.is_empty() and bridge.conversions == 0, "late callback after dispose cannot convert or emit")
	check(page.cancels >= 2, "dispose cancels underlying picker")
	print("ADAPTER_FAKE_BRIDGE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"kind":"native fake bridge injection; no real browser download or buffer conversion"}))
	quit(0 if failures.is_empty() else 1)
