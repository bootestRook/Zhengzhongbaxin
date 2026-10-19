class_name DefenseMonsterPortrait
extends Button

@export var show_banner: bool = true

var atlas: DefenseAtlas
var monster: Dictionary = {}
var kind: String = "enemy"

func configure(resources: DefenseAtlas, value: Dictionary, role: String) -> void:
	atlas = resources
	monster = value
	kind = role
	$Boss.visible = kind in ["elite", "boss"] and show_banner
	$Boss.text = "精英" if kind == "elite" else "首领"
	queue_redraw()

func _draw() -> void:
	if atlas == null or monster.is_empty():
		return
	atlas.picture(self, "atlas:bg3", Rect2(0, 0, 200, 200))
	atlas.picture(self, "atlas:b" if kind == "boss" else "atlas:a", Rect2(12, 12, 176, 176))
	var key = "atlas:" + str(monster.res).split(":")[1]
	atlas.stretch(self, key, Rect2(15, 15, 170, 170))
	if kind in ["elite", "boss"] and show_banner:
		atlas.picture(self, "atlas:boss_tag", Rect2(-10, -10, 160, 44))
	if button_pressed:
		draw_rect(Rect2(0, 0, 200, 200), Color(0, 0, 0, 0.13))
