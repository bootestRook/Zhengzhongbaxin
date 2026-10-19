extends Control

signal intent_requested(intent: String, payload: Dictionary)
var data: Dictionary = {}
var part: String = "head"
var tab: String = "gems"

func configure() -> void:
	$Outside.pressed.connect(hide)
	$Card/Gems.pressed.connect(func(): set_tab("gems"))
	$Card/Equipment.pressed.connect(func(): set_tab("equipment"))
	for index in range(DefenseEquipment.SOCKET_LIMIT):
		get_node("Card/GemRows/Slot%d/Remove" % index).pressed.connect(func(): remove_gem(index))

func open(value: Dictionary, selected_part: String) -> void:
	data = value
	part = selected_part
	tab = "gems"
	refresh()
	show()

func render(value: Dictionary) -> void:
	data = value
	if visible:
		refresh()

func set_tab(value: String) -> void:
	tab = value
	refresh()

func refresh() -> void:
	var name_text: String = DefenseEquipment.PART_NAMES[part]
	var count: int = data.sockets[part].size()
	$Card/Title.text = "默认 · " + name_text
	$Card/Icon.configure(part, false)
	$Card/Part.text = "部位：" + name_text
	$Card/Gems.set_pressed_no_signal(tab == "gems")
	$Card/Equipment.set_pressed_no_signal(tab == "equipment")
	$Card/GemRows.visible = tab == "gems"
	$Card/EquipmentInfo.visible = tab == "equipment"
	$Card/EquipmentInfo.text = "默认%s装备\n\n暂无附加属性。" % name_text
	$Card/Footer.text = "卸下的宝石将返还背包" if tab == "gems" else "当前穿戴中的装备"
	for index in range(DefenseEquipment.SOCKET_LIMIT):
		var row = get_node("Card/GemRows/Slot%d" % index)
		var occupied = index < count
		if occupied:
			row.get_node("Icon").configure(part, true, data.gem_types[data.sockets[part][index]])
		var definition: Dictionary = data.definitions.get(str(data.gem_defs[data.sockets[part][index]]), {}) if occupied else {}
		row.get_node("Icon").visible = occupied
		row.get_node("Title").text = str(definition.get("name", "宝石")) + " · " + str(definition.get("quality", "")) if occupied else "空槽"
		row.get_node("Description").text = str(definition.get("description", "")) if occupied else "尚未镶嵌"
		row.get_node("Remove").visible = occupied

func remove_gem(index: int) -> void:
	if index < 0 or index >= data.sockets[part].size():
		return
	intent_requested.emit("gem_remove", {"part": part, "slot": index, "item": data.sockets[part][index]})
