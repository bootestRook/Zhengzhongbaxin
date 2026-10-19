extends Control

signal intent_requested(intent: String, payload: Dictionary)
const Item = preload("res://scenes/defense/equipment_item.tscn")
const DISPLAY_PARTS = ["head", "arms", "chest", "pants", "boots", "gloves"]
var data: Dictionary = {}
var category: String = "gem"
var part_filter: String = ""
var revision: int = -1

func configure(catalog, value: DefenseAtlas) -> void:
	$Statue.configure(value)
	$Dialog.configure(catalog, value)
	$Dialog.intent_requested.connect(func(intent, payload): intent_requested.emit(intent, payload))
	$Dialog.selection_started.connect(func(): $Toast.hide())
	$WornDialog.configure()
	$WornDialog.intent_requested.connect(func(intent, payload): intent_requested.emit(intent, payload))
	$Bag/Gems.pressed.connect(func(): set_category("gem"))
	$Bag/Equipment.pressed.connect(func(): set_category("equipment"))
	$Bag/Filter.pressed.connect(func(): $Filter.visible = not $Filter.visible)
	$Filter/Outside.pressed.connect(func(): $Filter.hide())
	$Power.pressed.connect(func(): show_feedback("宝石效果会在进入局内战斗后生效；攻速、攻击范围和天罚暂缓。"))
	$ToastTimer.timeout.connect(func(): $Toast.hide())
	for index in range(6):
		var part: String = DISPLAY_PARTS[index]
		get_node("Gear/Slot%d" % index).pressed.connect(func(): open_equipment(part))
	for index in range(7):
		var part = "" if index == 0 else str(DefenseEquipment.PARTS[index - 1])
		get_node("Filter/Panel/Part%d" % index).pressed.connect(func(): set_filter(part))
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			$Dialog.close()
			$WornDialog.hide()
			$Filter.hide())

func render(value: Dictionary) -> void:
	if revision == int(value.revision):
		return
	var previous_revision = revision
	data = value
	revision = int(value.revision)
	for index in range(6):
		var part: String = DISPLAY_PARTS[index]
		var socket_types: Array = []
		for item in data.sockets[part]:
			socket_types.append(data.gem_types[item])
		get_node("Gear/Slot%d" % index).configure(part, false, 1, true, socket_types)
	refresh_bag()
	$Dialog.render(data)
	$WornDialog.render(data)
	if previous_revision >= 0 and not $WornDialog.visible:
		show_feedback("操作成功")

func set_category(value: String) -> void:
	category = value
	refresh_bag()

func set_filter(value: String) -> void:
	part_filter = value
	$Filter.hide()
	$Bag/Filter.text = "筛选：全部" if value.is_empty() else "筛选：" + DefenseEquipment.PART_NAMES[value]
	refresh_bag()

func refresh_bag() -> void:
	if data.is_empty():
		return
	$Bag/Gems.set_pressed_no_signal(category == "gem")
	$Bag/Equipment.set_pressed_no_signal(category == "equipment")
	var grid = $Bag/Scroll/Items
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if category == "gem" and part_filter.is_empty():
		var global_stacks: Dictionary = {}
		for part in DefenseEquipment.PARTS:
			for item in data.gems[part]:
				var gem_id = str(data.gem_defs[item])
				if not global_stacks.has(gem_id):
					global_stacks[gem_id] = []
				if not global_stacks[gem_id].has(item):
					global_stacks[gem_id].append(item)
		for stack: Dictionary in _sorted_gem_stacks(global_stacks):
			var definition: Dictionary = stack.definition
			var allowed_part: String = str(definition.get("parts", ["head"])[0])
			add_stack(allowed_part, stack.items, stack.gem_type, stack.gem_id)
	else:
		for part in DefenseEquipment.PARTS:
			if not part_filter.is_empty() and part != part_filter:
				continue
			if category == "gem":
				var stacks: Dictionary = {}
				for item in data.gems[part]:
					var gem_id = str(data.gem_defs[item])
					if not stacks.has(gem_id):
						stacks[gem_id] = []
					stacks[gem_id].append(item)
				for stack: Dictionary in _sorted_gem_stacks(stacks):
					add_stack(part, stack.items, stack.gem_type, stack.gem_id)
			else:
				add_stack(part, data.spares[part])
	$Bag/Empty.visible = grid.get_child_count() == 0

func _sorted_gem_stacks(stacks: Dictionary) -> Array:
	var result: Array = []
	var source_order := 0
	for gem_id in stacks:
		var items: Array = stacks[gem_id]
		if items.is_empty():
			continue
		var definition: Dictionary = data.definitions.get(str(gem_id), {})
		result.append({
			"gem_id": int(gem_id),
			"items": items,
			"gem_type": str(data.gem_types[items[0]]),
			"definition": definition,
			"quality_rank": int(definition.get("quality_rank", 0)),
			"source_order": source_order,
		})
		source_order += 1
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rank := int(left.get("quality_rank", 0))
		var right_rank := int(right.get("quality_rank", 0))
		if left_rank != right_rank:
			return left_rank > right_rank
		return int(left.get("source_order", 0)) < int(right.get("source_order", 0))
	)
	return result

func add_stack(part: String, items: Array, gem_type: String = "", gem_id: int = 0) -> void:
	if items.is_empty():
		return
	var button = Item.instantiate()
	button.name = part + ("_" + str(gem_id) if category == "gem" else "")
	$Bag/Scroll/Items.add_child(button)
	button.configure(part, category == "gem", items.size(), false, [], gem_type)
	if category == "gem":
		var definition: Dictionary = data.definitions.get(str(gem_id), {})
		button.tooltip_text = "%s · %s · %s\n%s" % [definition.get("name", "宝石"), definition.get("quality", ""), DefenseEquipment.PART_NAMES[part], definition.get("description", "")]
	var item: String = items[0]
	button.pressed.connect(func(): $Dialog.open(data, part, category, item))

func open_equipment(part: String) -> void:
	$Dialog.close()
	$Toast.hide()
	$WornDialog.open(data, part)

func escape() -> void:
	if $WornDialog.visible:
		$WornDialog.hide()
	elif $Dialog.visible:
		$Dialog.dismiss_step()
	elif $Filter.visible:
		$Filter.hide()
	else:
		get_parent().show_page("battle")

func show_feedback(message: String) -> void:
	$Toast.text = message
	$Toast.show()
	$ToastTimer.start()
