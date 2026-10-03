extends SceneTree
const Writer = preload("res://tests/report_json_writer.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _init() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var samples: Array[Dictionary] = [
		{},
		{"checks": 0, "failures": 0, "cases": [], "journey": [], "states": [], "operations": [], "mode": "party_subsets", "scope": ""},
		{"z": null, "a": true, "false": false, "integer": -9223372036854775807, "positive": 9223372036854775807},
		{"unicode": "Hero · 渡灯录：听潮阁/护后/秦禾 🐈𝄞", "escapes": "\"\\/\b\f\n\r\t", "controls": String.chr(1) + String.chr(31)},
		{"floats": [0.0, -0.0, 1.0, -1.0, 0.1, 1.234567890123456, 0.000000000000001, 1000000000000000.0]},
		{"nested": [{"empty_dict": {}, "empty_array": [], "z": [null, false, 2.5, "\n"], "a": [[{"雪": "灯", "a": {"b": 1}}]]}, {}, [], [[], {}]]},
		{"dict": {"z": "last", "a": {"mixed_nested_keys": {2: "two", 10: "ten"}}}, "packed": PackedStringArray(["a", "听潮阁"]), "vector": Vector2(460.0, 430.0)},
		{"keys": [{"10": 10, "2": 2, "A": 3, "a": 4, "雪": 5, "\n": 6}]}
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 619309211
	for trial: int in 64:
		var records: Array = []
		for index: int in rng.randi_range(0, 12):
			records.append({"float": rng.randf_range(-10000.0, 10000.0), "int": rng.randi_range(-10000, 10000), "null": null, "list": [trial, index, true, false, {"empty": {}, "text": "渡灯录\n\"\\"}]})
		samples.append({"trial": trial, "records": records, "empty": [], "details": {"unicode": "🕯", "n": trial * 0.125}})
	for index: int in samples.size():
		var path: String = "user://report-json-codec-%03d.json" % index
		var file := FileAccess.open(path, FileAccess.WRITE)
		check(file != null, "Can open isolated codec evidence %d" % index)
		if file == null:
			continue
		var before: Dictionary = samples[index].duplicate(true)
		Writer.write(file, samples[index])
		file.flush()
		check(file.get_error() == OK, "Complete report write %d" % index)
		file.close()
		var actual: String = FileAccess.get_file_as_string(path)
		var expected: String = JSON.stringify(samples[index], "\t")
		check(actual.to_utf8_buffer() == expected.to_utf8_buffer(), "Exact JSON.stringify UTF-8 bytes %d" % index)
		check(JSON.parse_string(actual) == JSON.parse_string(expected), "Exact parsed report %d" % index)
		check(samples[index] == before, "Report input not mutated %d" % index)
	print("REPORT_JSON_CODEC %d checks %d failures %d fixtures" % [checks, failures, samples.size()])
	quit(0 if failures == 0 else 1)
