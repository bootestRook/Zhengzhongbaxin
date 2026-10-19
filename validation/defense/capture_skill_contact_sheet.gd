extends SceneTree

class Sheet extends Node2D:
	var font: Font
	var images: Array = []
	var names: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 1920), Color("dededb"))
		for i in range(images.size()):
			var x = i % 5 * 192
			var y = i / 5 * 455
			draw_texture_rect(images[i], Rect2(x + 6, y + 38, 180, 360), false)
			draw_string(font, Vector2(x + 8, y + 29), names[i], HORIZONTAL_ALIGNMENT_LEFT, 184, 23, Color.BLACK)

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var sheet = Sheet.new()
	sheet.font = load("res://assets/runtime/defense/chinese.ttf")
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://validation/defense/hero_skill_native.json"))
	for row in rows:
		sheet.names.append(row.name)
		var path = "res://validation/defense/skills_hero_%02d.png" % row.hero
		sheet.images.append(ImageTexture.create_from_image(Image.load_from_file(path)))
	root.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/skills_all_heroes.png")
	quit()
