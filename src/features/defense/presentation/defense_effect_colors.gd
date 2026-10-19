class_name DefenseEffectColors
extends RefCounted

var textures: Dictionary = {}

func texture(key: String, page: Texture2D, rect: Rect2i, tint: Color) -> ImageTexture:
	var cache_key = key + ":" + tint.to_html(false)
	if not textures.has(cache_key):
		var image: Image = page.get_image().get_region(rect)
		image.convert(Image.FORMAT_RGBA8)
		var pixels = image.get_data()
		for i in range(0, pixels.size(), 4):
			# Keep ink and alpha; replace the original hue instead of darkening it.
			var value = maxi(pixels[i], maxi(pixels[i + 1], pixels[i + 2]))
			pixels[i] = roundi(value * tint.r)
			pixels[i + 1] = roundi(value * tint.g)
			pixels[i + 2] = roundi(value * tint.b)
		textures[cache_key] = ImageTexture.create_from_image(Image.create_from_data(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8, pixels))
	return textures[cache_key]
