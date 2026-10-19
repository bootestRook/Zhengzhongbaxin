class_name SaveStore
extends RefCounted


func write_atomic(path: String, payload: Dictionary) -> String:
	var absolute_path := ProjectSettings.globalize_path(path)
	var parent := absolute_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK:
		return "cannot_create_save_directory:%d" % directory_error
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return "cannot_open_temporary_save"
	file.store_string(JSON.stringify(payload, "  ", false) + "\n")
	file.flush()
	file.close()

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(absolute_path):
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return "cannot_rotate_save_backup:%d" % backup_error
	var commit_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if commit_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		return "cannot_commit_save:%d" % commit_error
	return ""


func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "save_not_found", "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "cannot_open_save", "data": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_save_json", "data": {}}
	return {"ok": true, "error": "", "data": parsed}
