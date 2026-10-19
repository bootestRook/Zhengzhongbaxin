extends Node

const MainScene = preload("res://scenes/main.tscn")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")

const OUTPUT_DIR := "res://validation/defense/gems/tianfa_battle_frames"
const FRAME_WIDTH := 720
const FRAME_HEIGHT := 1440
const TOTAL_FRAMES := 360
const VIDEO_TICKS_PER_FRAME := 2

var app
var world
var near_enemy: Dictionary = {}
var far_enemy: Dictionary = {}
var near_anchor := Statue.BODY_CENTER + Vector2(-130, 0)
var far_anchor := Statue.BODY_CENTER + Vector2(360, 0)

func _ready() -> void:
	get_window().size = Vector2i(FRAME_WIDTH, FRAME_HEIGHT)
	_prepare_output()
	app = MainScene.instantiate()
	add_child(app)
	await get_tree().process_frame
	if not app.is_ready_for_use():
		push_error("正式战斗场景启动失败：" + str(app.boot_error))
		get_tree().quit(2)
		return
	app.set_process(false)
	if not _equip_tianfa():
		push_error("正式战斗场景无法装载天罚·传说")
		get_tree().quit(2)
		return
	app.submit("start", {"seed": 20261018})
	var hero_index: int = world.offers.find_custom(func(item): return int(item.id) == 1)
	if hero_index < 0:
		push_error("正式战斗场景无法招募测试英雄")
		get_tree().quit(2)
		return
	app.submit("choose", {"index": hero_index})
	world = app.session
	near_enemy = world.factory.create("enemy", 101, near_anchor, 2)
	far_enemy = world.factory.create("enemy", 101, far_anchor, 2)
	# Keep the two observation targets alive long enough to show the real status art.
	near_enemy.core.attributes.set_value("hp", 1000000.0)
	far_enemy.core.attributes.set_value("hp", 1000000.0)
	world.space.rebuild()
	call_deferred("_capture_loop")

func _equip_tianfa() -> bool:
	world = app.session
	var snapshot: Dictionary = world.equipment.snapshot()
	for item in snapshot.gem_defs:
		var definition: Dictionary = world.catalog.record("gems", int(snapshot.gem_defs[item]))
		if definition.get("name", "") != "天罚" or definition.get("quality", "") != "传说":
			continue
		var parts: Array = definition.get("parts", [])
		if parts.is_empty():
			return false
		return world.submit("gem_inlay", {"part": str(parts[0]), "item": str(item)}).is_empty()
	return false

func _prepare_output() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("frame_") and file_name.ends_with(".png"):
			dir.remove(file_name)

func _capture_loop() -> void:
	for frame_index in range(TOTAL_FRAMES):
		if frame_index == 30:
			world.damage.hit_wall(world.wall_max * 0.25)
		if frame_index == 60:
			world.damage.hit_wall(world.wall_max * 0.25 + 1.0)
		for _tick in range(VIDEO_TICKS_PER_FRAME):
			_handle_intermission()
			if world.phase == "playing" and not world.paused:
				world.step()
			_anchor_targets()
		world.space.rebuild()
		app.get_node("DefenseView").render(world.snapshot())
		await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		if image.get_width() != FRAME_WIDTH or image.get_height() != FRAME_HEIGHT:
			image = image.get_region(Rect2i(0, 0, mini(FRAME_WIDTH, image.get_width()), mini(FRAME_HEIGHT, image.get_height())))
		image.save_png("%s/frame_%04d.png" % [ProjectSettings.globalize_path(OUTPUT_DIR), frame_index])
	get_tree().quit(0)

func _handle_intermission() -> void:
	if world.phase == "choice" and not world.offers.is_empty():
		world.submit("choose", {"index": 0})
	elif world.phase == "reward":
		world.submit("reward_close", {"id": int(world.loot.snapshot().get("id", -1))})

func _anchor_targets() -> void:
	if near_enemy.is_empty() or far_enemy.is_empty():
		return
	if not near_enemy.dead:
		near_enemy.pos = near_anchor
		near_enemy.home = near_anchor
	if not far_enemy.dead:
		far_enemy.pos = far_anchor
		far_enemy.home = far_anchor
