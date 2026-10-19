class_name DefenseEquipmentIcon
extends TextureRect

const GEMS = {
	"a": preload("res://assets/runtime/statue_equipment/gem_common.png"),
	"b": preload("res://assets/runtime/statue_equipment/gem_fine.png"),
	"c": preload("res://assets/runtime/statue_equipment/gem_excellent.png"),
	"d": preload("res://assets/runtime/statue_equipment/gem_perfect.png"),
	"e": preload("res://assets/runtime/statue_equipment/gem_legendary.png"),
	"f": preload("res://assets/runtime/statue_equipment/gem_peerless.png"),
	"g": preload("res://assets/runtime/statue_equipment/gem_supreme.png")}
const GEAR = {
	"head": preload("res://assets/runtime/statue_equipment/head.png"),
	"chest": preload("res://assets/runtime/statue_equipment/chest.png"),
	"boots": preload("res://assets/runtime/statue_equipment/boots.png"),
	"arms": preload("res://assets/runtime/statue_equipment/arms.png"),
	"pants": preload("res://assets/runtime/statue_equipment/pants.png"),
	"gloves": preload("res://assets/runtime/statue_equipment/gloves.png")}

func configure(part: String, gem: bool, gem_type: String = "") -> void:
	texture = GEMS[gem_type] if gem else GEAR[part]
