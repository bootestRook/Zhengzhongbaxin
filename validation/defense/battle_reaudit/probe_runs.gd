extends SceneTree

func _initialize() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var fixture = preload("res://tests/test_defense.gd").new()
	for seed in [17, 23, 53, 81]:
		var result: Dictionary = fixture._full_run(catalog, seed)
		print("[RUN] seed=%d won=%s wave=%d bosses=%d wall=%s" % [seed, result.won, result.wave, result.bosses, result.wall])
		if result.won:
			var file = FileAccess.open("res://validation/defense/battle_reaudit/victory_run.json", FileAccess.WRITE)
			file.store_string(JSON.stringify({"seed": seed, "result": result}, "\t") + "\n")
			break
	quit()
