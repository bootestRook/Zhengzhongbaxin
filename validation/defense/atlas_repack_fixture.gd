extends RefCounted

const PAD := 8

static func make(original: DefenseAtlas, art: Dictionary) -> DefenseAtlas:
	var moved: Dictionary = art.duplicate(true)
	moved.pages.reverse()
	for sprite: Dictionary in moved.sprites.values():
		if not sprite.get("blank", false):
			sprite.page = moved.pages.size() - 1 - int(sprite.page)
			sprite.rect[0] += PAD
			sprite.rect[1] += PAD
	var result := DefenseAtlas.new(moved)
	# Move the actual pixels as well as the metadata. Every page changes size,
	# order and every nonblank sprite changes position; runtime files stay intact.
	for index in range(original.pages.size()):
		var source: Image = original.pages[index].get_image()
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		var image := Image.create(source.get_width() + PAD * 2, source.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
		image.blit_rect(source, Rect2i(0, 0, source.get_width(), source.get_height()), Vector2i(PAD, PAD))
		result.pages[result.pages.size() - 1 - index] = ImageTexture.create_from_image(image)
	return result
