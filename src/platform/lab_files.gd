extends RefCounted

static func read_json(path: String) -> Dictionary:
	var parser = JSON.new()
	var error = parser.parse(FileAccess.get_file_as_string(path))
	if error != OK or not parser.data is Dictionary:
		return {"error": "JSON读取失败：%s（第%d行）" % [parser.get_error_message(), parser.get_error_line()]}
	return {"value": parser.data}

static func write_json(path: String, data: Dictionary) -> String:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "无法写入：" + path
	if not file.store_string(JSON.stringify(data, "\t", true, true) + "\n"): return "写入失败：" + path
	return ""

static func fingerprint() -> String:
	var paths: Array = []
	for root in ["res://src", "res://scenes"]: collect(root, paths)
	paths.sort()
	var hashes = PackedStringArray()
	for path in paths: hashes.append(path + ":" + FileAccess.get_sha256(path))
	return "\n".join(hashes).sha256_text()

static func collect(path: String, paths: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null: return
	for file in dir.get_files():
		if file.get_extension() in ["gd", "tscn", "tres", "gdshader"]: paths.append(path.path_join(file))
	for child in dir.get_directories(): collect(path.path_join(child), paths)

static func presets() -> Array:
	var result: Array = []
	var dir = DirAccess.open("res://tests/lab_cases")
	if dir == null: return result
	for name in dir.get_files():
		if name.ends_with(".json"): result.append("res://tests/lab_cases/" + name)
	result.sort()
	return result
