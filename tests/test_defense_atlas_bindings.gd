extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")

func run(test: TestSupport, _tree: SceneTree) -> void:
	_effect_colors(test)
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "UI binding catalog loads")
	var art: Dictionary = catalog.art()
	# Exercise names supplied by definitions and formatted families, which a
	# literal-only scene scan cannot cover (expanded stats, portraits, speeds).
	var required: Array = []
	for speed in range(1, 5):
		required.append("map:speedUp%d_face" % speed)
	for hero: Dictionary in catalog.records("heroes").values():
		if hero.available:
			required.append("gameIcon:heroHead%d_new" % hero.id)
		for tag: Dictionary in hero.tags:
			required.append(tag.res)
	for row in DefenseBattlePanels.EXTRA_ATTRIBUTES + [[1, 4, 10]]:
		for id in row:
			required.append("gameIcon:attr_%d" % id)
	for option: Dictionary in catalog.records("options").values():
		if not option.icon_res.is_empty():
			required.append(option.icon_res)
	var monsters: Dictionary = {}
	for level: Dictionary in catalog.records("levels").values():
		for wave: Dictionary in level.waves:
			for entry: Dictionary in wave.entries:
				monsters[int(entry.monster_id)] = true
		for entry in level.encounters:
			monsters[int(entry.id)] = true
	for id in monsters:
		var monster: Dictionary = catalog.record("monsters", id)
		required.append("atlas:" + str(monster.res).split(":")[1])
		test.assert_true(art.animations.has(monster.res + "_idle"), "current campaign actor has named idle: " + monster.res)
	for key: String in required:
		test.assert_true(art.sprites.has(key) and not art.sprites[key].get("blank", false), "dynamic UI name exists: " + key)
	var moved: Dictionary = art.duplicate(true)
	moved.pages.reverse()
	for sprite: Dictionary in moved.sprites.values():
		if not sprite.get("blank", false):
			sprite.page = moved.pages.size() - 1 - int(sprite.page)
	var entry: Dictionary = moved.sprites["map:expBarBg_track"]
	entry.rect[0] += 3
	entry.rect[1] += 6
	entry.rect[2] *= 2
	entry.rect[3] *= 2
	entry.size = [entry.rect[2], entry.rect[3]]
	var original := DefenseAtlas.new(art)
	var repacked := DefenseAtlas.new(moved)
	var texture: AtlasTexture = repacked.texture("map:expBarBg_track")
	test.assert_equal(texture.atlas, repacked.pages[int(entry.page)], "updated UI page comes from name")
	test.assert_equal(texture.region, Rect2(entry.rect[0], entry.rect[1], entry.rect[2], entry.rect[3]), "updated UI position and size come from name")
	test.assert_true(texture != original.texture("map:expBarBg_track"), "texture cache belongs to this resource index, not a previous export")

func _effect_colors(test: TestSupport) -> void:
	var image := Image.create_from_data(3, 1, false, Image.FORMAT_RGBA8, PackedByteArray([0, 0, 0, 255, 130, 110, 255, 255, 255, 255, 255, 64]))
	var page := ImageTexture.create_from_image(image)
	var cache := DefenseEffectColors.new()
	var tint := Color("72d8ff")
	var texture := cache.texture("arrow", page, Rect2i(0, 0, 3, 1), tint)
	var colored := texture.get_image()
	test.assert_equal(colored.get_pixel(0, 0), Color.BLACK, "effect recoloring preserves black ink")
	test.assert_equal(colored.get_pixel(1, 0), tint, "blue source pixels become clear ice cyan instead of a dark multiply")
	test.assert_equal(colored.get_pixel(2, 0).a, image.get_pixel(2, 0).a, "effect recoloring preserves transparency")
	test.assert_equal(cache.texture("arrow", page, Rect2i(0, 0, 3, 1), tint), texture, "repeated effects reuse the recolored texture")
	test.assert_equal(cache.texture("arrow", page, Rect2i(0, 0, 3, 1), Color(tint, 0.25)), texture, "fading effects reuse the same RGB texture instead of caching every opacity")
	test.assert_equal(page.get_image().get_pixel(1, 0), image.get_pixel(1, 0), "effect recoloring leaves the shared atlas unchanged")
