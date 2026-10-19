class_name MainView
extends Control

signal apply_intent_requested
signal save_requested
signal load_requested
signal reset_requested

@onready var _title_label: Label = %TitleLabel
@onready var _definition_label: Label = %DefinitionLabel
@onready var _value_label: Label = %ValueLabel
@onready var _progress_bar: ProgressBar = %ValueProgress
@onready var _status_label: Label = %StatusLabel
@onready var _badge: TextureRect = %Badge
@onready var _apply_button: Button = %ApplyButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _reset_button: Button = %ResetButton
@onready var _event_log: RichTextLabel = %EventLog

var _data
var _event_line: int = 0


func _ready() -> void:
	_apply_button.pressed.connect(func() -> void: apply_intent_requested.emit())
	_save_button.pressed.connect(func() -> void: save_requested.emit())
	_load_button.pressed.connect(func() -> void: load_requested.emit())
	_reset_button.pressed.connect(func() -> void: reset_requested.emit())


func configure(data_registry, resource_catalog) -> void:
	_data = data_registry
	_title_label.text = _data.text("ui.title")
	_apply_button.text = _data.text("ui.apply_intent")
	_save_button.text = _data.text("ui.save")
	_load_button.text = _data.text("ui.load")
	_reset_button.text = _data.text("ui.reset")
	var texture = resource_catalog.load_resource("ui.sample_badge")
	if texture is Texture2D:
		_badge.texture = texture


func render(snapshot: Dictionary, events: Array = []) -> void:
	var definition: Dictionary = _data.definition(String(snapshot.get("definition_id", "")))
	_definition_label.text = _data.text(String(definition.get("display_name_key", "")))
	var current := int(snapshot.get("value", 0))
	var maximum := maxi(1, int(snapshot.get("maximum", 1)))
	_value_label.text = "%d / %d" % [current, maximum]
	_progress_bar.max_value = maximum
	_progress_bar.value = current
	_apply_button.disabled = bool(snapshot.get("completed", false))
	_status_label.text = _data.text("cue.sample.limit_reached") if _apply_button.disabled else _data.text("cue.sample.value_changed")
	_append_events(events)


func show_notice(message: String) -> void:
	_status_label.text = message


func show_boot_error(message: String) -> void:
	_status_label.text = "BOOT ERROR: %s" % message
	_apply_button.disabled = true
	_save_button.disabled = true
	_load_button.disabled = true
	_reset_button.disabled = true


func _append_events(events: Array) -> void:
	for event: Dictionary in events:
		_event_line += 1
		var details := ""
		if event.has("current"):
			details = " value=%s delta=%s" % [event.current, event.get("delta", 0)]
		_event_log.append_text("%03d  %s%s\n" % [_event_line, event.get("type", "unknown"), details])
		_event_log.scroll_to_line(_event_log.get_line_count())
