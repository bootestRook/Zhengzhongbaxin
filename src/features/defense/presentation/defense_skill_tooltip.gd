extends Control

const SKILL_HEADER_RIGHT := 642.0
const SKILL_HEADER_TOP := 24.0
const SKILL_HEADER_HEIGHT := 80.0
const COOLDOWN_MIN_WIDTH := 120.0
const COOLDOWN_MAX_WIDTH := 292.0
const COOLDOWN_GAP := 16.0
const COOLDOWN_PADDING := 24.0
var target_index: int = -1

func configure(_atlas) -> void:
	# The battle tooltip uses text only; atlas-backed skill icons stay on the HUD.
	pass

func render(_value: Dictionary) -> void:
	pass

func dismiss() -> void:
	target_index = -1
	hide()

func toggle(index: int, description: String, _anchor: Rect2) -> void:
	if visible and $Paper/Description.text == description:
		dismiss()
		return
	target_index = index
	$Paper/Description.text = description
	show()

func layout_cooldown(value: String) -> void:
	var cooldown_panel: Control = $Cooldown
	var cooldown_value: RichTextLabel = $Cooldown/Value
	if value.is_empty():
		cooldown_panel.hide()
		$Title.offset_right = SKILL_HEADER_RIGHT
		return
	var font: Font = cooldown_value.get_theme_font("normal_font")
	var font_size := cooldown_value.get_theme_font_size("normal_font_size")
	var measured := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var width := clampf(measured + COOLDOWN_PADDING, COOLDOWN_MIN_WIDTH, COOLDOWN_MAX_WIDTH)
	var left := SKILL_HEADER_RIGHT - width
	cooldown_panel.position = Vector2(left, SKILL_HEADER_TOP)
	cooldown_panel.size = Vector2(width, SKILL_HEADER_HEIGHT)
	cooldown_value.fit_content = false
	cooldown_value.position = Vector2(10.0, 4.0)
	cooldown_value.size = Vector2(width - 20.0, SKILL_HEADER_HEIGHT - 8.0)
	cooldown_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cooldown_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Title.offset_right = left - COOLDOWN_GAP
	cooldown_panel.show()
