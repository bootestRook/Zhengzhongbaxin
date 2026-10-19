extends Panel

var atlas: DefenseAtlas

func configure(resources: DefenseAtlas, monster: Dictionary, kind: String) -> void:
	atlas = resources
	$Portrait.configure(resources, monster, kind)
	$Portrait.disabled = true
	$Name.text = monster.title
	$Description.text = monster.description
	$Boss.visible = kind in ["elite", "boss"]
	$Boss.text = "精英" if kind == "elite" else "首领"
	$Boss.position.x = 230 + atlas.font.get_string_size(monster.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x + 8
	queue_redraw()

func _draw() -> void:
	if atlas != null and $Boss.visible:
		atlas.picture(self, "atlas:boss_tag", Rect2($Boss.position, Vector2(160, 44)))
