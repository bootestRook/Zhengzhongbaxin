extends Node

func _ready() -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://validation/defense/home_normal_startup_720.png")
	print("NORMAL STARTUP CAPTURE: ", error, " size=", image.get_size())
	get_tree().quit(0 if error == OK else 1)
