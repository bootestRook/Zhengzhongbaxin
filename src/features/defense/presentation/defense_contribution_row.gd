extends Control

var atlas: DefenseAtlas
var hero: Dictionary = {}

func render(value: Dictionary, resources: DefenseAtlas, maximum: float) -> void:
	hero = value
	atlas = resources
	$Name.text = hero.name
	$Value.text = str(roundi(hero.stats.damage))
	$Bar.value = hero.stats.damage / maxf(1, maximum) * 100
	queue_redraw()

func _draw() -> void:
	if atlas != null and not hero.is_empty():
		atlas.picture(self, "gameIcon:heroHead%d_new" % hero.template, Rect2(0, 0, 75, 75))
