extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Home = preload("res://scenes/defense/home.tscn")

func run(test: TestSupport, tree: SceneTree) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "home art catalog loads")
	var original: Dictionary = catalog.art()
	var repacked: Dictionary = original.duplicate(true)
	var count: int = original.pages.size()
	for i in range(count):
		repacked.pages[i] = original.pages[count - 1 - i]
	for sprite: Dictionary in repacked.sprites.values():
		if not sprite.get("blank", false):
			sprite.page = count - 1 - int(sprite.page)
	# Move two UI regions as well as reordering every page. This exercises the
	# regression without changing the user's source assets or generated data.
	repacked.sprites["home:bg4"].rect[0] += 11
	repacked.sprites["home:bg4"].rect[1] += 13
	repacked.sprites["home:home_level_bg_light"].rect[0] += 17
	repacked.sprites["home:home_level_bg_light"].rect[1] += 19
	var atlas := DefenseAtlas.new(repacked)
	var home = Home.instantiate()
	home.visible = false
	tree.root.add_child(home)
	home.configure(catalog, atlas)
	var bindings: int = 0
	var sprites: Array[Node] = home.find_children("*", "TextureRect")
	for card in home.get_node("HeroPage").cards.values():
		sprites.append_array(card.find_children("*", "TextureRect"))
	for control in sprites:
		# The home scene now contains static equipment presentation textures
		# (gradient headers and socket fills) in addition to atlas-backed art.
		# Only atlas-backed images participate in the binding contract.
		if not control is DefenseAtlasSprite:
			continue
		bindings += 1
		var entry: Dictionary = repacked.sprites[control.resource_key]
		var r: Array = entry.rect
		var texture: AtlasTexture = control.texture
		test.assert_equal(texture.atlas, atlas.pages[int(entry.page)], "home uses current page: " + control.resource_key)
		test.assert_equal(texture.region, Rect2(r[0], r[1], r[2], r[3]), "home uses current region: " + control.resource_key)
		var expected_margin := Rect2(entry.offset[0], entry.offset[1], entry.size[0] - r[2], entry.size[1] - r[3])
		if control.name == "Portrait" and control.get_parent().get_script() == preload("res://src/features/defense/presentation/defense_home_hero_card.gd"):
			expected_margin = Rect2()
		test.assert_equal(texture.margin, expected_margin, "home applies the intended sprite margins: " + control.resource_key)
	test.assert_true(bindings >= 50, "packed and screenshot-derived home artwork all have logical bindings")
	var light: TextureRect = home.get_node("MapLight")
	var texture: AtlasTexture = light.texture
	var extent: Vector2 = texture.atlas.get_size()
	var r: Rect2 = texture.region
	test.assert_equal(light.material.get_shader_parameter("atlas_region"),
		Vector4(r.position.x / extent.x, r.position.y / extent.y, r.size.x / extent.x, r.size.y / extent.y),
		"home light UV follows the repacked sprite and page dimensions")
	test.assert_equal(atlas.texture("home:bg4"), home.get_node("PlayerPaper").texture, "logical UI textures are cached by the atlas owner")
	home.queue_free()
	await tree.process_frame
