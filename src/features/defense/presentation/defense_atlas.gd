class_name DefenseAtlas
extends RefCounted

var sprites: Dictionary
var animations: Dictionary
var pages: Array = []
var font: Font
var textures: Dictionary = {}
var effect_colors := DefenseEffectColors.new()
var outlines := DefenseActorOutline.new()

func _init(art: Dictionary) -> void:
	sprites = art.sprites
	animations = art.animations
	for path in art.pages:
		pages.append(load(path))
	font = load(art.font)

func texture(key: String) -> AtlasTexture:
	if not textures.has(key):
		var sprite: Dictionary = sprites[key]
		var r: Array = sprite.rect
		var result := AtlasTexture.new()
		result.atlas = pages[int(sprite.page)]
		result.region = Rect2(r[0], r[1], r[2], r[3])
		result.margin = Rect2(sprite.offset[0], sprite.offset[1], sprite.size[0] - r[2], sprite.size[1] - r[3])
		result.filter_clip = true
		textures[key] = result
	return textures[key]

func frame(key: String, elapsed: int, loop: bool = true, durations: Array = []) -> String:
	if not animations.has(key):
		return key
	var animation: Dictionary = animations[key]
	var sequence: Array = []
	for i in range(animation.frames.size()):
		sequence.append(i)
	if animation.swing:
		for i in range(animation.frames.size() - 2, 0, -1):
			sequence.append(i)
	var total = 0
	for index in sequence:
		total += int(durations[index]) if index < durations.size() else int(animation.frames[index].duration_ms)
	var tick = posmod(elapsed, maxi(1, total + int(animation.repeat_delay_ms))) if loop else clampi(elapsed, 0, maxi(0, total - 1))
	for index in sequence:
		var f = animation.frames[index]
		tick -= int(durations[index]) if index < durations.size() else int(f.duration_ms)
		if tick < 0:
			return f.sprite
	return animation.frames[sequence.back()].sprite

func draw(canvas: CanvasItem, key: String, position: Vector2, scale_value: Vector2 = Vector2.ONE, elapsed: int = 0, anchor: Vector2 = Vector2(0.5, 0.85), tint: Color = Color.WHITE, rotation: float = 0, loop: bool = true, durations: Array = [], outline: Color = Color.TRANSPARENT, recolor: bool = false) -> void:
	var frame_key := frame(key, elapsed, loop, durations)
	var sprite: Dictionary = sprites.get(frame_key, {})
	if sprite.is_empty() or sprite.get("blank", false):
		return
	var r = sprite.rect
	var s = Vector2(sprite.size[0], sprite.size[1])
	var offset = Vector2(sprite.offset[0], sprite.offset[1])
	canvas.draw_set_transform(position, rotation, scale_value)
	if outline.a > 0:
		if not outlines.frames.has(frame_key) and not outlines.textures.has(frame_key):
			outlines.prepare(frame_key, sprites, animations, pages)
		canvas.draw_texture(outlines.texture(frame_key), offset - s * anchor - Vector2.ONE * DefenseActorOutline.WIDTH, outline)
	if recolor and tint != Color.WHITE:
		canvas.draw_texture(effect_colors.texture(frame_key, pages[int(sprite.page)], Rect2i(r[0], r[1], r[2], r[3]), tint), offset - s * anchor, Color(1, 1, 1, tint.a))
	else:
		canvas.draw_texture_rect_region(pages[int(sprite.page)], Rect2(offset - s * anchor, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]), tint)
	canvas.draw_set_transform(Vector2.ZERO)

func stretch(canvas: CanvasItem, key: String, rect: Rect2, elapsed: int = 0) -> void:
	var sprite: Dictionary = sprites.get(frame(key, elapsed), {})
	if sprite.is_empty():
		return
	var s = Vector2(sprite.size[0], sprite.size[1])
	draw(canvas, key, rect.position, rect.size / s, elapsed, Vector2.ZERO)

func picture(canvas: CanvasItem, key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var sprite: Dictionary = sprites[key]
	var r: Array = sprite.rect
	var region = Rect2(r[0], r[1], r[2], r[3])
	canvas.draw_texture_rect_region(pages[int(sprite.page)], rect, region, tint)

func actor(canvas: CanvasItem, res: String, action: String, position: Vector2, elapsed: int, scale_value: float = 1, facing: float = 1, tint: Color = Color.WHITE, anchor: Vector2 = Vector2(0.5, 0.85), durations: Array = [], outline: Color = Color.TRANSPARENT) -> void:
	var key = res + "_" + action
	if not animations.has(key):
		key = res + "_idle"
	if not animations.has(key):
		key = res
	if outline.a > 0:
		outlines.prepare(res, sprites, animations, pages)
	draw(canvas, key, position, Vector2(scale_value * facing, scale_value), elapsed, anchor, tint, 0, action in ["idle", "walk", "skill2"], durations, outline)
