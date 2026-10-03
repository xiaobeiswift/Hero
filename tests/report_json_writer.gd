extends RefCounted
## Test evidence only: preserve JSON.stringify(report, "\t") bytes while
## materializing one top-level array record at a time, never the whole report.
## The report has string keys and acyclic records; nested encoding, escaping,
## scalar types and key ordering remain the engine JSON encoder's job.

static func write(file: FileAccess, report: Dictionary) -> void:
	var keys: Array = report.keys()
	keys.sort()
	file.store_string("{\n")
	for key_index: int in keys.size():
		if key_index > 0:
			file.store_string(",\n")
		var key: String = keys[key_index]
		file.store_string("\t" + JSON.stringify(key) + ": ")
		var value: Variant = report[key]
		if value is Array:
			if value.is_empty():
				file.store_string("[]")
			else:
				file.store_string("[\n")
				for record_index: int in value.size():
					if record_index > 0:
						file.store_string(",\n")
					file.store_string("\t\t")
					file.store_string(_indented_json(value[record_index], "\t\t"))
				file.store_string("\n\t]")
		else:
			file.store_string(_indented_json(value, "\t"))
	file.store_string("\n}")

static func _indented_json(value: Variant, indent: String) -> String:
	# Godot emits an unindented blank line inside an empty dictionary.
	# Rebase content/closing lines, but preserve that blank line byte-for-byte.
	return JSON.stringify(value, "\t").replace("\n", "\n" + indent).replace("\n" + indent + "\n", "\n\n")
