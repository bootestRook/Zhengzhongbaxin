extends Control

var atlas: DefenseAtlas
var resource_key: String = "":
	set(value):
		resource_key = value
		frame_extent = Vector2.ZERO
		for frame in atlas.animations[value + "_idle"].frames:
			var rect: Array = atlas.sprites[frame.sprite].rect
			frame_extent.x = maxf(frame_extent.x, float(rect[2]))
			frame_extent.y = maxf(frame_extent.y, float(rect[3]))
		elapsed = 0
var frame_extent: Vector2 = Vector2.ZERO
var elapsed: int = 0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += roundi(delta * 1000)
	queue_redraw()

func _draw() -> void:
	if atlas == null or resource_key.is_empty():
		return
	var sprite: Dictionary = atlas.sprites[atlas.frame(resource_key + "_idle", elapsed)]
	var r: Array = sprite.rect
	var scale_value: float = minf(size.x / frame_extent.x, size.y / frame_extent.y)
	var extent: Vector2 = Vector2(r[2], r[3]) * scale_value
	atlas.picture(self, atlas.frame(resource_key + "_idle", elapsed), Rect2(Vector2((size.x - extent.x) / 2, size.y - extent.y), extent))
