extends SceneTree

func _initialize() -> void:
	var catalog = DefenseCatalog.new()
	catalog.load_default()
	var w = DefenseSession.new(catalog)
	for seed in range(1, 25):
		w.start(seed)
		print("[SEED] %d %s" % [seed, w.offers.map(func(item): return item.id)])
	w.start(889)
	print("[SEED] 889 " + str(w.offers.map(func(item): return item.id)))
	w.dispose()
	quit()
