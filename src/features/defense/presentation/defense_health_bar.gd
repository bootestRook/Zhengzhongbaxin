extends RefCounted

const SHIELD := Color("bfc3c7")
const EDGE := Color("eceef0")

var _identity: int = -1
var _shield: float = 0
var _last_time: int = -1
var _changed_at: int = -1000
var _gaining: bool = false

func reset() -> void:
	_identity = -1
	_shield = 0
	_last_time = -1
	_changed_at = -1000

func draw(canvas: CanvasItem, bounds: Rect2, actor: Dictionary, now: int, health_color: Color) -> void:
	if int(actor.id) != _identity or now < _last_time:
		reset()
		_identity = int(actor.id)
	var shield = 0.0 if actor.dead else maxf(0, actor.shield)
	if shield != _shield:
		_gaining = shield > _shield
		_changed_at = now
		_shield = shield
	_last_time = now
	var segment_count := maxi(1, int(actor.get("health_bars", 1)))
	var gap := 2.0 if segment_count > 1 else 0.0
	var segment_width := (bounds.size.x - gap * (segment_count - 1)) / segment_count
	var segment_max := maxf(1, float(actor.max_hp) / segment_count)
	var last_area := Rect2()
	for index in range(segment_count):
		var segment = Rect2(bounds.position + Vector2(index * (segment_width + gap), 0), Vector2(segment_width, bounds.size.y))
		if index > 0:
			canvas.draw_rect(Rect2(segment.position - Vector2(gap / 2.0, 0), Vector2(gap, segment.size.y)), Color("303438"))
		var segment_hp = clampf(float(actor.hp) - segment_max * index, 0, segment_max)
		var segment_shield = shield if index == segment_count - 1 else 0.0
		var capacity = maxf(1, maxf(segment_max, segment_hp + segment_shield))
		var shield_width = minf(segment.size.x, maxf(3, segment.size.x * segment_shield / capacity)) if segment_shield > 0 else 0.0
		var health_width = minf(segment.size.x - shield_width, segment.size.x * clampf(segment_hp / capacity, 0, 1))
		canvas.draw_rect(Rect2(segment.position, Vector2(health_width, segment.size.y)), health_color)
		if segment_shield > 0:
			last_area = Rect2(segment.position + Vector2(health_width, 0), Vector2(shield_width, segment.size.y))
	if shield <= 0:
		return
	var area = last_area
	# Battle time keeps the feedback frozen on pause and deterministic at any speed.
	var progress = clampf((now - _changed_at) / (260.0 if _gaining else 140.0), 0, 1)
	var flash = (1 - progress) * (0.85 if _gaining else 0.55)
	canvas.draw_rect(area, SHIELD.lerp(Color.WHITE, flash))
	canvas.draw_rect(Rect2(area.position, Vector2(area.size.x, 2)), EDGE)
	if area.size.x > 2:
		canvas.draw_rect(Rect2(area.position - Vector2(1, 0), Vector2(1, area.size.y)), Color("303438"))
	if _gaining and progress < 1:
		var gleam_width = minf(6, area.size.x * 0.3)
		var x = (area.size.x - gleam_width) * (1 - pow(1 - progress, 3))
		canvas.draw_rect(Rect2(area.position + Vector2(x, 0), Vector2(gleam_width, area.size.y)), Color(1, 1, 1, 0.65 * (1 - progress)))
