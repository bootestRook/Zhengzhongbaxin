class_name DefenseActorOutline
extends RefCounted

const WIDTH := 3

var prepared: Dictionary = {}
var frames: Dictionary = {}
var textures: Dictionary = {}

func prepare(res: String, sprites: Dictionary, animations: Dictionary, pages: Array) -> void:
	if prepared.has(res):
		return
	prepared[res] = true
	var keys: Dictionary = {}
	if sprites.has(res):
		keys[res] = true
	for key: String in animations:
		if key.begins_with(res + "_"):
			for frame: Dictionary in animations[key].frames:
				keys[frame.sprite] = true
	var by_page: Dictionary = {}
	for key: String in keys:
		var sprite: Dictionary = sprites[key]
		if sprite.get("blank", false):
			continue
		var page := int(sprite.page)
		if not by_page.has(page):
			by_page[page] = []
		by_page[page].append(key)
	# Read each atlas page once per actor resource, retaining only its small frames.
	for page: int in by_page:
		var source: Image = pages[page].get_image()
		for key: String in by_page[page]:
			var r: Array = sprites[key].rect
			frames[key] = source.get_region(Rect2i(r[0], r[1], r[2], r[3]))

func texture(key: String) -> ImageTexture:
	if not textures.has(key):
		var mask: Image = frames[key]
		var size := mask.get_size()
		var white := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		var image := Image.create_empty(size.x + WIDTH * 2, size.y + WIDTH * 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(-WIDTH, WIDTH + 1):
			for x in range(-WIDTH, WIDTH + 1):
				if x * x + y * y <= WIDTH * WIDTH:
					image.blit_rect_mask(white, mask, Rect2i(Vector2i.ZERO, size), Vector2i(WIDTH + x, WIDTH + y))
		white.fill(Color.TRANSPARENT)
		image.blit_rect_mask(white, mask, Rect2i(Vector2i.ZERO, size), Vector2i(WIDTH, WIDTH))
		textures[key] = ImageTexture.create_from_image(image)
		frames.erase(key)
	return textures[key]
