extends Control

const AtlasSprite = preload("res://src/features/defense/presentation/defense_atlas_sprite.gd")
const CircleShader = preload("res://src/features/defense/presentation/gem_target_circle.gdshader")
const QUALITY_COLORS := {
	"普通": Color("909ba5"),
	"精良": Color("35e88b"),
	"卓越": Color("37b7ff"),
	"完美": Color("b95bfa"),
	"传说": Color("ff9d30"),
	"绝世": Color("ff4050"),
}
const GLOBAL_HERO_EFFECT_TYPES := {
	"attribute_pct": true,
	"attribute_pct_bundle": true,
	"attribute_add": true,
	"attack_damage_pct": true,
	"elite_damage_taken_pct": true,
	"stage_damage_pct": true,
	"suspended": true,
	"revive_buff": true,
	"revive_time_reduction": true,
	"instant_revive": true,
}
const GLOBAL_OBJECT_LABELS := {
	"extra_choice": "关卡",
}

signal intent_requested(intent: String, payload: Dictionary)
signal selection_started
var data: Dictionary = {}
var catalog
var atlas: DefenseAtlas
var hero_by_name: Dictionary = {}
var hero_by_id: Dictionary = {}
var part: String = "head"
var kind: String = "gem"
var item: String = ""
var gem_type: String = ""
var gem_id: int = 0
var selecting: bool = false

func configure(definitions, resources: DefenseAtlas) -> void:
	catalog = definitions
	atlas = resources
	hero_by_name.clear()
	hero_by_id.clear()
	if catalog != null:
		for hero: Dictionary in catalog.records("heroes").values():
			hero_by_name[str(hero.get("name", ""))] = hero
			hero_by_id[int(hero.get("id", 0))] = hero
	$Outside.pressed.connect(dismiss_step)
	$Left/Action.pressed.connect(inlay)
	$Left/Wash.pressed.connect(wash)
	$Right/Action.pressed.connect(replace_equipment)
	for i in range(5):
		get_node("GemRows/Slot%d" % i).pressed.connect(func(): replace_gem(i))

func open(value: Dictionary, selected_part: String, selected_kind: String, selected_item: String) -> void:
	data = value
	part = selected_part
	kind = selected_kind
	item = selected_item
	gem_type = str(data.gem_types[item]) if kind == "gem" else ""
	gem_id = int(data.gem_defs[item]) if kind == "gem" else 0
	selecting = false
	show()
	refresh()

func render(value: Dictionary) -> void:
	data = value
	if visible:
		refresh()

func dismiss_step() -> void:
	if selecting:
		selecting = false
		refresh()
	else:
		hide()

func close() -> void:
	selecting = false
	hide()

func refresh() -> void:
	var gem = kind == "gem"
	var name_text: String = DefenseEquipment.PART_NAMES[part]
	var copies: Array = []
	if gem:
		for candidate in data.gems[part]:
			if int(data.gem_defs[candidate]) == gem_id:
				copies.append(candidate)
		if not copies.has(item):
			item = str(copies[0]) if not copies.is_empty() else ""
	$Shade.color = Color(0, 0, 0, 0.65 if selecting or not gem else 0)
	$Prompt.visible = selecting
	$Right.visible = not gem and item != data.worn[part]
	$GemRows.visible = gem
	var definition: Dictionary = data.definitions.get(str(gem_id), {}) if gem else {}
	$Left/Title.text = (name_text + "·" + str(definition.get("quality", "")) + "宝石") if gem else name_text
	$Left/Icon.configure(part, gem, gem_type)
	$Left/Part.text = ("部位：" + name_text + "\n所属：" + str(definition.get("owner", "通用"))) if gem else "默认装备\n部位：" + name_text
	$Left/Part.visible = not gem
	$Left/PartBadge.visible = gem
	$Left/PartBadge.configure(part, false)
	$Left/GemPart.visible = gem
	$Left/GemPart.text = name_text
	$Left/Quality.visible = gem
	$Left/Quality.text = "品质：" + str(definition.get("quality", "")) if gem else ""
	$Left/Quantity.text = "数量：%d" % copies.size() if gem else ""
	$Left/Current.visible = not gem
	$Left/Section.text = "宝石效果" if gem else ""
	$Left/SectionBackdrop.visible = gem
	$Left/Body.set_text(str(definition.get("description", "")) if gem else "默认%s装备" % name_text)
	$Left/Action.visible = gem
	$Left/Action.disabled = copies.is_empty()
	$Left/Action.text = "镶嵌"
	$Left/Wash.visible = gem
	$Left/TargetsTitle.visible = gem
	$Left/Targets.visible = gem
	$Left/TargetsBackdrop.visible = gem
	_set_quality_header($Left, definition, gem)
	_render_targets($Left, definition if gem else {})
	_layout_card($Left, gem)
	if gem:
		for i in range(5):
			var row = get_node("GemRows/Slot%d" % i)
			var occupied = i < data.sockets[part].size()
			var socket_definition: Dictionary = data.definitions.get(str(data.gem_defs[data.sockets[part][i]]), {}) if occupied else {}
			if occupied:
				row.get_node("Icon").configure(part, true, data.gem_types[data.sockets[part][i]])
			row.get_node("Icon").visible = occupied
			row.get_node("Empty").visible = not occupied
			row.get_node("Title").text = str(socket_definition.get("name", "宝石")) + " · " + str(socket_definition.get("quality", "")) if occupied else "空槽"
			row.get_node("Description").text = str(socket_definition.get("description", "")) if occupied else "尚未镶嵌"
			row.disabled = not selecting or not occupied
	else:
		$Left/Wash.visible = false
		$Left/TargetsTitle.visible = false
		$Left/Targets.visible = false
		$Left/TargetsBackdrop.visible = false
		$Right/Title.text = name_text
		$Right/Icon.configure(part, false)
		$Right/Part.text = "默认装备\n部位：" + name_text
		$Right/Quantity.text = ""
		$Right/Body.set_text("默认%s装备" % name_text)
		$Right/Current.hide()
		$Right/Section.text = ""
		$Right/SectionBackdrop.visible = false
		$Right/TargetsTitle.visible = false
		$Right/Targets.visible = false
		$Right/TargetsBackdrop.visible = false
		$Right/Wash.visible = false
		$Right/Action.text = "替换"
		_set_quality_header($Right, {}, false)
		_render_targets($Right, {})
		_layout_card($Right, false)

func _layout_card(card: Control, gem: bool) -> void:
	if not gem:
		card.position.y = 455.0
		card.size.y = 560.0
		return
	var targets: VBoxContainer = card.get_node("Targets")
	var row_height := 44.0
	var row_gap := 4.0
	var target_height := maxf(row_height, targets.get_child_count() * row_height + maxf(0.0, targets.get_child_count() - 1) * row_gap)
	targets.size.y = target_height
	card.get_node("TargetsBackdrop").size.y = target_height
	var button_top := 425.0 + target_height + 4.0
	card.get_node("Action").position.y = button_top
	card.get_node("Wash").position.y = button_top
	var card_height := maxf(560.0, button_top + 64.0 + 23.0)
	card.size.y = card_height
	card.position.y = clampf(735.0 - card_height * 0.5, 24.0, 1920.0 - card_height - 24.0)

func _set_quality_header(card: Control, definition: Dictionary, visible_value: bool) -> void:
	var color_panel: ColorRect = card.get_node("QualityHeader")
	var rainbow: TextureRect = card.get_node("QualityRainbow")
	color_panel.visible = visible_value
	rainbow.visible = visible_value and str(definition.get("quality", "")) == "至尊"
	if visible_value:
		var quality := str(definition.get("quality", ""))
		color_panel.color = QUALITY_COLORS.get(quality, Color("536fc1")).darkened(0.18)

func _render_targets(card: Control, definition: Dictionary) -> void:
	var targets: VBoxContainer = card.get_node("Targets")
	for child in targets.get_children():
		targets.remove_child(child)
		child.queue_free()
	if definition.is_empty():
		return
	var effect_type := str(definition.get("effect", {}).get("type", ""))
	var owner := str(definition.get("owner", "通用"))
	if effect_type.begins_with("statue_"):
		var row := _new_target_row(targets)
		_add_target_label(row, "雕像")
	else:
		var heroes: Array[Dictionary] = _matching_heroes(definition)
		if heroes.is_empty():
			var object_label := str(GLOBAL_OBJECT_LABELS.get(effect_type, ""))
			if not object_label.is_empty():
				var object_row := _new_target_row(targets)
				_add_target_label(object_row, object_label)
				return
			if owner == "通用":
				var global_row := _new_target_row(targets)
				_add_target_label(global_row, "全英雄" if GLOBAL_HERO_EFFECT_TYPES.has(effect_type) else "未限定对象")
				return
			heroes.append(hero_by_name.get(owner, {}))
		var row: HBoxContainer
		for index in range(heroes.size()):
			if index % 4 == 0:
				row = _new_target_row(targets)
			var portrait := _hero_portrait(heroes[index])
			if portrait != null:
				row.add_child(portrait)
			else:
				_add_target_label(row, owner)

func _matching_heroes(definition: Dictionary) -> Array[Dictionary]:
	var effect: Dictionary = definition.get("effect", {})
	var candidates: Array[Dictionary] = []
	var owner_ids: Array = definition.get("owner_ids", [])
	if not owner_ids.is_empty():
		for hero_id in owner_ids:
			var hero: Dictionary = hero_by_id.get(int(hero_id), {})
			if not hero.is_empty():
				candidates.append(hero)
	elif effect.has("profession"):
		for hero: Dictionary in hero_by_id.values():
			if int(hero.get("profession", -1)) == int(effect.get("profession", -2)):
				candidates.append(hero)
	elif effect.has("element"):
		var element_names := {"fire": "火", "ice": "冰", "electric": "电", "nature": "自然", "physical": "物理"}
		var wanted_element := str(element_names.get(str(effect.get("element", "")), ""))
		for hero: Dictionary in hero_by_id.values():
			if not wanted_element.is_empty() and str(hero.get("element", "")) == wanted_element:
				candidates.append(hero)
	elif str(effect.get("range", "")) in ["ranged", "melee"]:
		var ranged := str(effect.get("range", "")) == "ranged"
		for hero: Dictionary in hero_by_id.values():
			if bool(hero.get("front", false)) == (not ranged):
				candidates.append(hero)
	if catalog == null or candidates.is_empty():
		return candidates
	var unlocked: Array = catalog.available_heroes()
	if unlocked.is_empty():
		return candidates
	return candidates.filter(func(hero: Dictionary): return unlocked.has(int(hero.get("id", 0))))

func _new_target_row(targets: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row%d" % targets.get_child_count()
	row.custom_minimum_size = Vector2(0, 44)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	targets.add_child(row)
	return row

func _add_target_label(row: HBoxContainer, value: String) -> void:
	var label := Label.new()
	label.name = "Label"
	label.text = value
	label.custom_minimum_size = Vector2(0, 44)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("4f4538"))
	row.add_child(label)

func _hero_portrait(hero: Dictionary) -> Control:
	if atlas == null or hero.is_empty():
		return null
	var key := "gameIcon:heroHead%d_new" % int(hero.get("id", 0))
	if not atlas.sprites.has(key):
		key = atlas.frame(str(hero.get("res", "")) + "_idle", 0)
	if not atlas.sprites.has(key):
		return null
	var icon: DefenseAtlasSprite = AtlasSprite.new()
	icon.resource_key = key
	icon.custom_minimum_size = Vector2(42, 42)
	icon.size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = str(hero.get("name", "英雄"))
	var circle_material := ShaderMaterial.new()
	circle_material.shader = CircleShader
	icon.material = circle_material
	icon.configure(atlas)
	if icon.texture is AtlasTexture:
		var portrait: AtlasTexture = icon.texture.duplicate()
		portrait.margin = Rect2()
		icon.texture = portrait
	return icon

func wash() -> void:
	return

func inlay() -> void:
	if item.is_empty() or selecting:
		return
	for index in range(data.sockets[part].size()):
		var current_definition: Dictionary = data.definitions.get(str(data.gem_defs[data.sockets[part][index]]), {})
		var candidate_definition: Dictionary = data.definitions.get(str(gem_id), {})
		if int(current_definition.get("effect_family_id", -1)) == int(candidate_definition.get("effect_family_id", -2)):
			if int(candidate_definition.get("quality_rank", 0)) > int(current_definition.get("quality_rank", 0)):
				selecting = true
				selection_started.emit()
				refresh()
				return
			intent_requested.emit("gem_inlay", {"part": part, "item": item})
			return
	if data.sockets[part].size() >= DefenseEquipment.SOCKET_LIMIT:
		selecting = true
		selection_started.emit()
		refresh()
		return
	intent_requested.emit("gem_inlay", {"part": part, "item": item})

func replace_gem(index: int) -> void:
	if not selecting:
		return
	var previous_revision: int = data.revision
	intent_requested.emit("gem_replace", {"part": part, "item": item, "slot": index})
	if data.revision != previous_revision:
		selecting = false
	refresh()

func replace_equipment() -> void:
	intent_requested.emit("equipment_replace", {"part": part, "item": item})
	close()
