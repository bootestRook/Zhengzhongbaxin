class_name SaveCodec
extends RefCounted

const CURRENT_SCHEMA_VERSION := 2
const MINIMUM_SCHEMA_VERSION := 1


func encode(feature_states: Dictionary, rng_snapshot: Dictionary, data_schema_version: int) -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"data_schema_version": data_schema_version,
		"features": feature_states.duplicate(true),
		"rng": rng_snapshot.duplicate(true),
	}


func decode(payload: Dictionary) -> Dictionary:
	var version := int(payload.get("schema_version", 0))
	if version < MINIMUM_SCHEMA_VERSION:
		return {"ok": false, "error": "save_too_old", "data": {}}
	if version > CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "save_from_newer_version", "data": {}}
	var migrated := payload.duplicate(true)
	while version < CURRENT_SCHEMA_VERSION:
		match version:
			1:
				migrated = _migrate_v1_to_v2(migrated)
			_:
				return {"ok": false, "error": "missing_migration:%d" % version, "data": {}}
		version = int(migrated.get("schema_version", version))
	var validation_error := _validate_current(migrated)
	if not validation_error.is_empty():
		return {"ok": false, "error": validation_error, "data": {}}
	return {"ok": true, "error": "", "data": migrated}


func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var migrated := payload.duplicate(true)
	if migrated.has("feature_state") and not migrated.has("features"):
		migrated["features"] = {"sample": migrated.feature_state}
		migrated.erase("feature_state")
	if not migrated.has("data_schema_version"):
		migrated["data_schema_version"] = 1
	migrated["schema_version"] = 2
	return migrated


func _validate_current(payload: Dictionary) -> String:
	if int(payload.get("schema_version", 0)) != CURRENT_SCHEMA_VERSION:
		return "invalid_save_schema_version"
	if typeof(payload.get("features", {})) != TYPE_DICTIONARY:
		return "invalid_feature_state_map"
	if typeof(payload.get("rng", {})) != TYPE_DICTIONARY:
		return "invalid_rng_snapshot"
	if int(payload.get("data_schema_version", 0)) <= 0:
		return "invalid_data_schema_version"
	return ""
