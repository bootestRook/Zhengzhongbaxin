extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var atlas := DefenseAtlas.new(catalog.art())
	var home = preload("res://scenes/defense/home.tscn").instantiate()
	root.add_child(home)
	home.configure(catalog, atlas)
	for control in home.find_children("*", "TextureRect"):
		if not control is DefenseAtlasSprite:
			print("NON_ATLAS: ", home.get_path_to(control))
	home.queue_free()
	await process_frame
	quit()
