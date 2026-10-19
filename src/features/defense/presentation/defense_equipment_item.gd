class_name DefenseEquipmentItem
extends Button

const SOCKET_COLORS = {
	"a": Color("909ba5"),
	"b": Color("35e88b"),
	"c": Color("37b7ff"),
	"d": Color("b95bfa"),
	"e": Color("ff9d30"),
	"f": Color("ff4050"),
	"g": Color.WHITE,
}

func configure(part: String, gem: bool, count: int, worn: bool = false, socket_types: Array = [], gem_type: String = "") -> void:
	$Icon.configure(part, gem, gem_type)
	$Badge.configure(part, false)
	$Badge.visible = gem
	$BadgeFrame.visible = gem
	$Icon.offset_left = 3 if gem else 8
	$Icon.offset_right = -3 if gem else -8
	$Icon.offset_top = 34 if worn else (3 if gem else 8)
	$Icon.offset_bottom = -31 if worn else (-3 if gem else -8)
	$Count.text = "×%d" % count
	$Count.visible = not worn
	$Part.text = DefenseEquipment.PART_NAMES[part]
	$Part.visible = worn
	$Sockets.visible = worn
	for index in range(5):
		var socket_type: String = socket_types[index] if index < socket_types.size() else ""
		get_node("Sockets/S%d/Fill" % index).color = Color("c2c4bd") if socket_type.is_empty() else SOCKET_COLORS[socket_type]
		get_node("Sockets/S%d/Fill/Rainbow" % index).visible = socket_type == "g"
	tooltip_text = ("%s宝石" if gem else "默认%s") % DefenseEquipment.PART_NAMES[part]
	if gem:
		tooltip_text = DefenseEquipment.PART_NAMES[part] + " · " + DefenseEquipment.GEM_TYPES[gem_type] + "宝石"
	if worn:
		tooltip_text += " · 已镶嵌%d/5" % socket_types.size()
