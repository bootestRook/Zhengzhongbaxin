class_name DefenseHud
extends Control

var atlas: DefenseAtlas
var speed: int = 1
var choice: bool = false
var gem_entry: bool = false
var contribution: bool = false
var monsters: bool = false

func _draw() -> void:
	if atlas == null:
		return
	atlas.picture(self, "map:speedUp4_face", Rect2(30, 15, 81, 78))
	atlas.picture(self, "map:speedUp%d_face" % speed, Rect2(150, 15, 81, 78))
	atlas.picture(self, "map:expBarBg_track", Rect2(143, 123, 670, 31))
	var points = [Vector2(146, 105), Vector2(176, 140), Vector2(146, 173), Vector2(114, 140)]
	draw_colored_polygon(PackedVector2Array(points), Color("69e8ff"))
	draw_colored_polygon(PackedVector2Array([points[0], points[1], Vector2(146, 140)]), Color("27bade"))
	draw_colored_polygon(PackedVector2Array([points[2], points[3], Vector2(146, 140)]), Color("1aaec5"))
	for i in range(4):
		draw_line(points[i], points[(i + 1) % 4], Color.BLACK, 5, true)
	draw_line(points[0], points[2], Color("15809b"), 2, true)
	draw_line(points[1], points[3], Color("c2f9ff"), 2, true)
	if choice:
		if gem_entry:
			atlas.picture(self, "common:btn_Blue_face", Rect2(706, 231, 242, 84))
	else:
		atlas.picture(self, "battle:btn_monster2" if monsters else "battle:btn_monster1", Rect2(29, 347, 79, 72))
	for i in range(3):
		var rect = Rect2(35 + i * 22, 246 - i * 18, 14, 29 + i * 18)
		draw_rect(rect.grow(4), Color.BLACK)
		draw_rect(rect, Color("87ddf5") if contribution else Color.WHITE)
	draw_rect(Rect2(29, 273, 70, 9), Color.BLACK)
	draw_rect(Rect2(32, 274, 64, 5), Color("87ddf5") if contribution else Color.WHITE)
