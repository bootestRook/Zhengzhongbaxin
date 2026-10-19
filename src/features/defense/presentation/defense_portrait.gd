class_name DefensePortrait
extends Control

var atlas: DefenseAtlas
var resource_key: String = ""
var elapsed: int = 0
var is_actor: bool = true

func _process(delta: float) -> void:
	elapsed += roundi(delta * 1000)
	if visible:
		queue_redraw()

func _draw() -> void:
	if atlas == null or resource_key.is_empty():
		return
	if is_actor:
		atlas.actor(self, resource_key, "idle", Vector2(size.x / 2, size.y * 0.8), elapsed, minf(size.x / 240, size.y / 200))
	else:
		atlas.draw(self, resource_key, size / 2, Vector2.ONE, elapsed, Vector2(0.5, 0.5))
