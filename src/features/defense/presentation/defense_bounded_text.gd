class_name DefenseBoundedText
extends Control

const OVERSCROLL := 42.0
const REBOUND_SECONDS := 0.16

@onready var text_label: Label = $Text
var _dragging := false
var _content_height := 0.0
var _tween: Tween

func _ready() -> void:
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_refresh_measurement)
	call_deferred("_refresh_measurement")

func set_text(value: String) -> void:
	text_label.text = value
	text_label.position.y = 0.0
	call_deferred("_refresh_measurement")

func _refresh_measurement() -> void:
	if not is_instance_valid(text_label):
		return
	text_label.size.x = size.x
	_content_height = maxf(size.y, text_label.get_combined_minimum_size().y)
	text_label.size.y = _content_height
	text_label.position.y = clampf(text_label.position.y, -_max_offset(), 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag()
		else:
			_end_drag()
		accept_event()
		return
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_drag(event.relative.y)
		accept_event()
	elif event is InputEventScreenDrag:
		_drag(event.relative.y)
		accept_event()

func _input(event: InputEvent) -> void:
	if _dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()

func _begin_drag() -> void:
	_stop_tween()
	_dragging = true

func _drag(delta_y: float) -> void:
	if _content_height <= size.y:
		text_label.position.y = 0.0
		return
	var raw := text_label.position.y + delta_y
	var min_offset := -_max_offset()
	if raw > 0.0:
		raw *= 0.32
	elif raw < min_offset:
		raw = min_offset + (raw - min_offset) * 0.32
	text_label.position.y = clampf(raw, min_offset - OVERSCROLL, OVERSCROLL)

func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var target := clampf(text_label.position.y, -_max_offset(), 0.0)
	_stop_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(text_label, "position:y", target, REBOUND_SECONDS)

func _max_offset() -> float:
	return maxf(0.0, _content_height - size.y)

func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
