extends SceneTree

func _initialize() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var result = preload("res://tests/test_defense.gd").new()._full_run(catalog, 6)
	print("[CURRENT FULL RUN] ", JSON.stringify(result))
	quit(0 if result.won and result.bosses == 3 else 1)
