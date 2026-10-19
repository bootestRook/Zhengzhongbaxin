extends Control

const IDLE_INTERVAL_MS := 2000
const ACTIONS := ["idle", "attack", "idle", "skill"]

var atlas: DefenseAtlas
var resource_key: String = ""
var elapsed_ms: float = 0.0
var action: String = "idle"
var action_elapsed: int = 0
var durations: Array[int] = []
var frame_bounds := Rect2()

func _ready() -> void:
	visibility_changed.connect(update_processing)
	update_processing()

func configure(value: DefenseAtlas) -> void:
	atlas = value

func show_hero(key: String) -> void:
	resource_key = key
	elapsed_ms = 0.0
	action = "idle"
	action_elapsed = 0
	durations.clear()
	frame_bounds = Rect2()
	for name: String in ACTIONS:
		var animation: Dictionary = atlas.animations[key + "_" + name]
		var duration: int = 0
		for frame: Dictionary in animation.frames:
			duration += int(frame.duration_ms)
			var sprite: Dictionary = atlas.sprites[frame.sprite]
			var bounds := Rect2(sprite.offset[0], sprite.offset[1], sprite.rect[2], sprite.rect[3])
			frame_bounds = bounds if frame_bounds.size == Vector2.ZERO else frame_bounds.merge(bounds)
		durations.append(IDLE_INTERVAL_MS if name == "idle" else duration)
	queue_redraw()

func update_processing() -> void:
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	if resource_key.is_empty():
		return
	elapsed_ms += delta * 1000.0
	var tick: int = int(elapsed_ms) % (durations[0] + durations[1] + durations[2] + durations[3])
	for i in range(ACTIONS.size()):
		if tick < durations[i]:
			action = ACTIONS[i]
			action_elapsed = tick
			break
		tick -= durations[i]
	queue_redraw()

func _draw() -> void:
	if atlas == null or resource_key.is_empty():
		return
	var scale_value := minf(4.55, minf((size.x - 60.0) / frame_bounds.size.x, (size.y - 40.0) / frame_bounds.size.y))
	var origin := size / 2.0 - frame_bounds.get_center() * scale_value
	atlas.draw(self, resource_key + "_" + action, origin, Vector2.ONE * scale_value,
		action_elapsed, Vector2.ZERO, Color.WHITE, 0.0, action == "idle")
