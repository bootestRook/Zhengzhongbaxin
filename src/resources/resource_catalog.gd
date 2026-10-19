class_name ResourceCatalog
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://assets/generated/asset_manifest.json"

var _assets: Dictionary = {}


func load_default() -> String:
	if not FileAccess.file_exists(DEFAULT_MANIFEST_PATH):
		return "generated asset manifest is missing; run: python tools/project.py assets"
	var file := FileAccess.open(DEFAULT_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return "cannot open generated asset manifest"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("assets", [])) != TYPE_ARRAY:
		return "asset manifest has an invalid shape"
	_assets.clear()
	for asset: Dictionary in parsed.assets:
		_assets[String(asset.id)] = asset
	return ""


func entry(resource_id: String) -> Dictionary:
	var found: Dictionary = _assets.get(resource_id, {})
	return found.duplicate(true)


func path(resource_id: String) -> String:
	return String(_assets.get(resource_id, {}).get("runtime_path", ""))


func load_resource(resource_id: String) -> Resource:
	var runtime_path := path(resource_id)
	if runtime_path.is_empty() or not ResourceLoader.exists(runtime_path):
		return null
	return ResourceLoader.load(runtime_path)
