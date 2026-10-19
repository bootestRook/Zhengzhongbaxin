class_name DefenseRosterCard
extends Control

var atlas: DefenseAtlas
var hero: Dictionary = {}
var clock: int = 0
var extent: Vector2 = Vector2.ZERO
var health_bar = preload("res://src/features/defense/presentation/defense_health_bar.gd").new()

func render(value: Dictionary, resources: DefenseAtlas, elapsed: int) -> void:
	if not value.is_empty() and (hero.is_empty() or hero.res != value.res):
		extent = Vector2.ZERO
		for frame in resources.animations[value.res + "_idle"].frames:
			var rect: Array = resources.sprites[frame.sprite].rect
			extent = extent.max(Vector2(rect[2], rect[3]))
	hero = value
	if hero.is_empty():
		health_bar.reset()
	atlas = resources
	clock = elapsed
	$EmptySlot.configure(atlas)
	$EmptySlot.visible = hero.is_empty()
	$Portrait.disabled = hero.is_empty()
	var present: bool = not hero.is_empty() and not hero.skills.is_empty()
	$Skill.disabled = not present
	$Skill.tooltip_text = hero.skills[0].title if present else ""
	$SkillLevel.visible = present
	if present:
		$SkillLevel.text = str(hero.skills[0].level)
	$Revive.visible = not hero.is_empty() and hero.dead
	if not hero.is_empty():
		$Revive.text = str(ceili(hero.revive / 1000.0))
	queue_redraw()

func _draw() -> void:
	if atlas == null or hero.is_empty():
		return
	var tint = Color(0.6, 0.6, 0.6) if hero.dead else Color.WHITE
	atlas.picture(self, "map:choice3", Rect2(0, 0, 172, 198), tint)
	var key: String = atlas.frame(hero.res + "_idle", clock)
	var region: Array = atlas.sprites[key].rect
	var art_bounds: Rect2 = $Portrait/Art.get_rect()
	var ratio = minf(1.2, minf(art_bounds.size.x / extent.x, art_bounds.size.y / extent.y))
	var visible_size = Vector2(region[2], region[3]) * ratio
	draw_set_transform(art_bounds.get_center(), 0, Vector2(-1, 1))
	atlas.picture(self, key, Rect2(-visible_size / 2, visible_size), tint)
	draw_set_transform(Vector2.ZERO)
	var bar = Rect2(12, 171, 148, 14)
	draw_rect(bar, Color("333333"))
	health_bar.draw(self, Rect2(bar.position + Vector2(2, 2), Vector2(144, 10)), hero, clock, Color("a1d557"))
	for slot in range(hero.skills.size()):
		var button = $Skill
		var bounds: Rect2 = button.get_rect()
		var skill: Dictionary = hero.skills[slot]
		atlas.picture(self, "map:skillBg3", bounds)
		if not skill.res.is_empty():
			atlas.picture(self, skill.res, bounds.grow(-4))
		var fraction = clampf(float(skill.cooldown) / maxf(1, skill.total), 0, 1)
		if fraction > 0:
			var points = PackedVector2Array([bounds.get_center()])
			for i in range(33):
				var angle = -PI / 2 + TAU * fraction * i / 32.0
				points.append(bounds.get_center() + Vector2(cos(angle), sin(angle)) * 35)
			draw_colored_polygon(points, Color(0, 0, 0, 0.57))
		if button.button_pressed:
			draw_circle(bounds.get_center(), 39, Color(0, 0, 0, 0.15))
	if $Portrait.button_pressed:
		draw_rect(Rect2(0, 0, 172, 198), Color(0, 0, 0, 0.15))
