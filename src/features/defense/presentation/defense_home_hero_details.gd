extends Control

signal hero_selected(id: int)
signal closed

const Portrait = preload("res://scenes/defense/home_hero_portrait.tscn")
const Skill = preload("res://scenes/defense/home_hero_skill.tscn")
const MAIN_ATTRIBUTES = [1, 4, 10]
const EXTRA_ATTRIBUTES = [[2, 11, 15, 20, 30], [6, 25, 16, 21, 27], [7, 12, 17, 22, 32], [8, 13, 24, 23]]

var catalog
var atlas: DefenseAtlas
var selected_hero_id: int = 0
var portraits: Dictionary = {}
var initial_options: Array = []
var notice_left: float = 0.0
var cooldown_reduction_percent: float = 0.0

func configure(definitions, art: DefenseAtlas) -> void:
	catalog = definitions
	atlas = art
	$Panel/Paper.texture = atlas.texture("common:heroInfo2Bg")
	$Attributes/Paper.texture = atlas.texture("common:textBg_Box")
	$SkillTip/Paper.texture = atlas.texture("common:textBg_Box")
	$AttributeTip/Paper.texture = atlas.texture("common:textBg_Box")
	$Panel/Actor.configure(atlas)
	$Panel/Info.pressed.connect(func():
		$SkillTip.hide()
		$AttributeTip.hide()
		$Attributes.visible = not $Attributes.visible)
	var available: Array = catalog.available_heroes()
	var ids: Array = []
	for key in catalog.records("heroes"):
		if not available.has(int(key)):
			ids.append(int(key))
	ids.sort()
	for id in available + ids:
		var hero: Dictionary = catalog.record("heroes", id)
		var card = Portrait.instantiate()
		card.name = "Hero%d" % id
		$Roster/Row.add_child(card)
		var portrait_key = "gameIcon:heroHead%d_new" % id
		if not atlas.sprites.has(portrait_key):
			portrait_key = atlas.frame(hero.res + "_idle", 0)
		set_sprite(card.get_node("Portrait"), portrait_key)
		var texture: AtlasTexture = card.get_node("Portrait").texture.duplicate()
		texture.margin = Rect2()
		card.get_node("Portrait").texture = texture
		card.get_node("Portrait").material.set_shader_parameter("locked", not available.has(id))
		card.get_node("Lock").configure(atlas)
		card.get_node("Lock").visible = not available.has(id)
		card.get_node("Shade").visible = not available.has(id)
		card.tooltip_text = hero.name
		card.pressed.connect(func(): open_hero(id))
		connect_press(card)
		portraits[id] = card
	for index in range(MAIN_ATTRIBUTES.size()):
		var id: int = MAIN_ATTRIBUTES[index]
		set_sprite($Panel.get_node("Main%d/Icon" % index), "gameIcon:attr_%d" % id)
		set_sprite($Attributes.get_node("Main%d/Icon" % index), "gameIcon:attr_%d" % id)
		for parent in [$Panel, $Attributes]:
			var hit = parent.get_node("Main%d/Hit" % index)
			hit.pressed.connect(func(): show_attribute(id, hit))
	for column in range(EXTRA_ATTRIBUTES.size()):
		for row in range(EXTRA_ATTRIBUTES[column].size()):
			var id: int = EXTRA_ATTRIBUTES[column][row]
			var cell = $Attributes.get_node("Extra%d_%d" % [column, row])
			set_sprite(cell.get_node("Icon"), "gameIcon:attr_%d" % id)
			var hit = cell.get_node("Hit")
			hit.pressed.connect(func(): show_attribute(id, hit))

func set_equipment(equipment: Dictionary) -> void:
	cooldown_reduction_percent = 0.0
	var gem_defs: Dictionary = equipment.get("gem_defs", {})
	var definitions: Dictionary = equipment.get("definitions", {})
	for sockets: Array in equipment.get("sockets", {}).values():
		for item in sockets:
			var gem_id = gem_defs.get(str(item), gem_defs.get(item, 0))
			var definition: Dictionary = definitions.get(str(gem_id), {})
			var effect: Dictionary = definition.get("effect", {})
			if str(effect.get("attribute", "")) == "9":
				cooldown_reduction_percent += float(effect.get("value", 0))

func open_hero(id: int) -> void:
	if not catalog.available_heroes().has(id):
		notice_left = 1.6
		$Notice.show()
		return
	selected_hero_id = id
	var hero: Dictionary = catalog.record("heroes", id)
	$Panel/Title.text = hero.name
	$Panel/Actor.show_hero(hero.res)
	set_sprite($Panel/Watermark, "gameIcon:heroHead%d_new" % id)
	var portrait: AtlasTexture = $Panel/Watermark.texture.duplicate()
	portrait.margin = Rect2()
	$Panel/Watermark.texture = portrait
	for i in range(2):
		var badge = $Panel.get_node("Badge%d" % i)
		var tag: Dictionary = hero.tags[1 - i]
		set_sprite(badge.get_node("Icon"), tag.res)
		badge.get_node("Text").text = tag.title
	for index in range(MAIN_ATTRIBUTES.size()):
		var value := number(hero.base[str(MAIN_ATTRIBUTES[index])])
		$Panel.get_node("Main%d/Value" % index).text = value
		$Attributes.get_node("Main%d/Value" % index).text = value
	for column in range(EXTRA_ATTRIBUTES.size()):
		for row in range(EXTRA_ATTRIBUTES[column].size()):
			$Attributes.get_node("Extra%d_%d/Value" % [column, row]).text = number(hero.base[str(EXTRA_ATTRIBUTES[column][row])])
	for child in $Panel/Skills.get_children():
		$Panel/Skills.remove_child(child)
		child.queue_free()
	initial_options = hero.initial_options.duplicate()
	for option_id in initial_options:
		var option: Dictionary = catalog.record("options", option_id)
		var button = Skill.instantiate()
		button.name = "Skill%d" % option_id
		$Panel/Skills.add_child(button)
		button.get_node("Background").configure(atlas)
		set_sprite(button.get_node("Icon"), option.icon_res)
		button.pressed.connect(func(): show_skill(option_id))
		connect_press(button)
	for key in portraits:
		portraits[key].get_node("Selected").visible = key == id
	dismiss_popups()
	$Notice.hide()
	notice_left = 0.0
	show()
	hero_selected.emit(id)
	$Roster.ensure_control_visible(portraits[id])

func show_skill(option_id: int) -> void:
	var option: Dictionary = catalog.record("options", option_id)
	var hero: Dictionary = catalog.record("heroes", selected_hero_id)
	var skill: Dictionary = catalog.record("skills", int(option.get("trigger_skill", 0)))
	$Attributes.hide()
	$AttributeTip.hide()
	$SkillTip/Title.text = option.title
	$SkillTip/Description.text = rich_description(skill_description(option, skill))
	var cooldown_value := cooldown_text(skill, hero)
	$SkillTip/Cooldown/Value.text = cooldown_value
	$SkillTip.layout_cooldown(cooldown_value)
	set_sprite($SkillTip/Icon, option.icon_res)
	var height: float = maxf(320.0, float($SkillTip/Description.get_content_height()) + 220.0)
	$SkillTip.size.y = height
	$SkillTip/Paper.size.y = height
	$SkillTip/Description.size.y = height - 200.0
	$SkillTip.show()
func skill_description(option: Dictionary, skill: Dictionary) -> String:
	var description := str(skill.get("description", "")).strip_edges()
	if description.is_empty():
		description = str(option.get("description", "")).strip_edges()
	var cooldown = RegEx.new()
	assert(cooldown.compile("基础冷却\\s*[-+]?\\d+(?:\\.\\d+)?\\s*秒[，,、]?") == OK)
	description = cooldown.sub(description, "", true)
	return description.replace("。。", "。").strip_edges()

func cooldown_text(skill: Dictionary, hero: Dictionary) -> String:
	var original := float(skill.get("cd", 0)) / 1000.0
	if original <= 0:
		return ""
	var reduction := cooldown_reduction_percent + float(hero.get("base", {}).get("9", 0))
	var multiplier := maxf(0.6, 1.0 - reduction / 100.0)
	var actual := original * multiplier
	if reduction <= 0.0:
		return seconds(original) + "秒"
	return seconds(actual) + "秒（原冷却-" + seconds(original - actual) + "秒）"

func rich_description(description: String) -> String:
	var numbers = RegEx.new()
	assert(numbers.compile("[-+]?\\d+(?:\\.\\d+)?%?") == OK)
	var result := ""
	var offset := 0
	for match_value in numbers.search_all(description):
		result += description.substr(offset, match_value.get_start() - offset)
		result += "[color=#28712c][b]" + match_value.get_string() + "[/b][/color]"
		offset = match_value.get_end()
	result += description.substr(offset)
	return result

func show_attribute(id: int, anchor: Control) -> void:
	var attribute: Dictionary = catalog.record("attributes", id)
	var hero: Dictionary = catalog.record("heroes", selected_hero_id)
	var value := number(hero.base[str(id)])
	$SkillTip.hide()
	$AttributeTip/Title.text = attribute.title
	$AttributeTip/Value.text = value
	set_sprite($AttributeTip/Icon, "gameIcon:attr_%d" % id)
	$AttributeTip/Description.text = str(anchor.get_meta("description")).replace("{value}", "[color=#23812b]" + value + "[/color]") + "\n基础：" + value
	var icon_rect := Rect2(anchor.global_position - global_position, anchor.size)
	$AttributeTip.position = Vector2(clampf(icon_rect.get_center().x - 90, 20, 260), icon_rect.end.y + 24)
	$AttributeTip/ArrowInk.position.x = icon_rect.get_center().x - $AttributeTip.position.x
	$AttributeTip/ArrowPaper.position.x = $AttributeTip/ArrowInk.position.x
	$AttributeTip.show()

func dismiss_popups() -> void:
	$Attributes.hide()
	$SkillTip.hide()
	$AttributeTip.hide()

func close() -> void:
	dismiss_popups()
	$Notice.hide()
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if $AttributeTip.visible:
			$AttributeTip.hide()
		elif $Attributes.visible or $SkillTip.visible:
			dismiss_popups()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point = get_global_transform_with_canvas().affine_inverse() * event.position
		if $AttributeTip.visible:
			if not Rect2($AttributeTip.position, $AttributeTip.size).has_point(point):
				$AttributeTip.hide()
				get_viewport().set_input_as_handled()
			return
		var popup: Control = $Attributes if $Attributes.visible else $SkillTip
		if popup.visible:
			if not Rect2(popup.position, popup.size).has_point(point):
				dismiss_popups()
				get_viewport().set_input_as_handled()
			return
		if not Rect2($Panel.position, $Panel.size).has_point(point) and not Rect2($RosterPaper.position, $RosterPaper.size).has_point(point):
			close()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if notice_left > 0.0:
		notice_left -= delta
		$Notice.visible = notice_left > 0.0

func set_sprite(sprite: DefenseAtlasSprite, key: String) -> void:
	sprite.resource_key = key
	sprite.configure(atlas)

func connect_press(button: Button) -> void:
	button.button_down.connect(func(): button.modulate = Color(0.76, 0.76, 0.76))
	button.button_up.connect(func(): button.modulate = Color.WHITE)
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)

func number(value: float) -> String:
	return str(int(value)) if value == floorf(value) else str(value)

func seconds(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text
