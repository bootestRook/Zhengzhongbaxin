class_name DefenseResultProgress
extends Control

var atlas: DefenseAtlas
var result: Dictionary = {}
var fraction: float = 0.0

func update_fraction(value: float) -> void:
	fraction = value
	queue_redraw()

func _draw() -> void:
	if atlas == null or result.is_empty():
		return
	atlas.picture(self, "battle:pr2", Rect2(0, 65, 740, 29))
	draw_rect(Rect2(7, 70, 726, 17), Color("ba2825"))
	draw_rect(Rect2(7, 70, 726 * fraction, 17), Color("fff36c"))
	var x: float = clampf(740 * fraction, 24, 706)
	draw_rect(Rect2(x - 40, 6, 80, 32), Color.BLACK)
	draw_string_outline(atlas.font, Vector2(x - 40, 31), "%d%%" % floori(fraction * 100), HORIZONTAL_ALIGNMENT_CENTER, 80, 31, 3, Color.BLACK)
	draw_string(atlas.font, Vector2(x - 40, 31), "%d%%" % floori(fraction * 100), HORIZONTAL_ALIGNMENT_CENTER, 80, 31, Color("fff56d"))
	for entry in result.encounters:
		var bx: float = 740 * float(entry.wave) / result.wave_count
		var cleared: bool = result.get("encounter_rows_cleared", []).has(int(entry.get("row_id", -1)))
		atlas.picture(self, "battle:bo", Rect2(bx - 40, 39, 80, 80), Color("777777") if cleared else Color.WHITE)
		if cleared:
			atlas.picture(self, "battle:killed", Rect2(bx - 37, 32, 74, 86))
		var title: String = "精英" if entry.kind == "elite" else "首领"
		draw_string_outline(atlas.font, Vector2(bx - 40, 119), title, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, 4, Color.BLACK)
		draw_string(atlas.font, Vector2(bx - 40, 119), title, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color.WHITE)
