extends Node2D

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")
const Atlas = preload("res://src/features/defense/presentation/defense_atlas.gd")

const OUTPUT_DIR := "res://validation/defense/gems/tianfa_frames"
const FRAME_WIDTH := 960
const FRAME_HEIGHT := 720
const FRAME_MS := 33
const FPS := 30
const TOTAL_FRAMES := 255
const VIEW_CENTER := Vector2(480, 410)
const WORLD_SCALE := 0.62
const RADIUS := 300.0

var catalog
var world
var atlas
var near_enemy: Dictionary = {}
var far_enemy: Dictionary = {}
var hero: Dictionary = {}
var frame_index := 0
var fired := false
var first_hit := false
var status_started_at := -1
var status_expired_at := -1
var error_message := ""

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(FRAME_WIDTH, FRAME_HEIGHT))
	_prepare_output()
	catalog = Catalog.new()
	var load_error: String = catalog.load_default()
	if not load_error.is_empty():
		error_message = "正式数据加载失败：" + load_error
		push_error(error_message)
		get_tree().quit(2)
		return
	atlas = Atlas.new(catalog.art())
	world = Session.new(catalog)
	if not _equip_tianfa():
		error_message = "无法装载天罚·传说"
		push_error(error_message)
		get_tree().quit(2)
		return
	var start_error: String = world.start(20261018)
	if not start_error.is_empty():
		error_message = "测试对局启动失败：" + start_error
		push_error(error_message)
		get_tree().quit(2)
		return
	var hero_index: int = world.offers.find_custom(func(item): return int(item.id) == 1)
	if hero_index < 0 or not world.submit("choose", {"index": hero_index}).is_empty():
		error_message = "测试英雄招募失败"
		push_error(error_message)
		get_tree().quit(2)
		return
	hero = world.units[world.heroes[0]]
	near_enemy = world.factory.create("enemy", 101, Statue.BODY_CENTER + Vector2(-120, 0), 2)
	far_enemy = world.factory.create("enemy", 101, Statue.BODY_CENTER + Vector2(360, 0), 2)
	world.space.rebuild()
	call_deferred("_capture_loop")

func _equip_tianfa() -> bool:
	var snapshot: Dictionary = world.equipment.snapshot()
	for item in snapshot.gem_defs:
		var definition: Dictionary = catalog.record("gems", int(snapshot.gem_defs[item]))
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
	for current in range(TOTAL_FRAMES):
		frame_index = current
		_advance_world(current)
		queue_redraw()
		await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		var width := mini(FRAME_WIDTH, image.get_width())
		var height := mini(FRAME_HEIGHT, image.get_height())
		image.get_region(Rect2i(0, 0, width, height)).save_png("%s/frame_%04d.png" % [ProjectSettings.globalize_path(OUTPUT_DIR), current])
	get_tree().quit(0)

func _advance_world(current: int) -> void:
	world.time_ms = current * FRAME_MS
	if current == 30:
		world.damage.hit_wall(world.wall_max * 0.25)
		first_hit = true
	if current == 60:
		world.damage.hit_wall(world.wall_max * 0.25 + 1.0)
		fired = true
		status_started_at = world.time_ms
	world.statuses.tick()
	if status_started_at >= 0 and status_expired_at < 0 and not world.statuses.has_status(near_enemy, 4):
		status_expired_at = world.time_ms

func _screen_pos(world_pos: Vector2) -> Vector2:
	return VIEW_CENTER + (world_pos - Statue.BODY_CENTER) * WORLD_SCALE

func _draw() -> void:
	draw_rect(Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT), Color("101b27"))
	draw_rect(Rect2(24, 20, FRAME_WIDTH - 48, 96), Color("1a2c40"), true)
	_draw_text(Vector2(48, 60), "天罚·传说  |  实际局内战斗验证", 30, Color("fff4cb"), 850)
	_draw_text(Vector2(48, 94), "累计损失达到 50% 触发 · 半径 300 · 昏迷 5 秒", 22, Color("b7d8e9"), 850)

	var center := VIEW_CENTER
	var scaled_radius := RADIUS * WORLD_SCALE
	draw_circle(center, scaled_radius, Color(0.9, 0.38, 0.15, 0.08), true)
	draw_arc(center, scaled_radius, 0, TAU, 96, Color("ff9858") if fired else Color("51758c"), 4.0, true)
	_draw_text(Vector2(48, 150), "雕像累计损失：%.0f / %.0f（%.0f%%）" % [world.wall_max - world.wall_hp, world.wall_max, (world.wall_max - world.wall_hp) / maxf(1.0, world.wall_max) * 100.0], 24, Color("f1f6fa"), 500)
	_draw_text(Vector2(48, 184), "范围内目标：%s" % ("已昏迷" if _is_stunned(near_enemy) else "未命中"), 23, Color("6fe3ff") if _is_stunned(near_enemy) else Color("d4e0e9"), 350)
	_draw_text(Vector2(515, 184), "范围外目标：%s" % ("异常" if _is_stunned(far_enemy) else "未受影响"), 23, Color("ff7b6b") if _is_stunned(far_enemy) else Color("d4e0e9"), 380)

	# Statue and the two real enemy units are drawn from the project's art atlas.
	if atlas != null:
		atlas.draw(self, "statue:statue1_4", _screen_pos(Statue.POSITION), Vector2.ONE * 0.43, 0, Vector2(0.5, 1))
	_draw_unit(near_enemy, "范围内")
	_draw_unit(far_enemy, "范围外")
	if fired:
		_draw_tianfa_effect()

	var elapsed := frame_index * FRAME_MS
	if fired and status_started_at >= 0:
		var remaining := maxi(0, 5000 - (elapsed - status_started_at))
		_draw_text(Vector2(48, 650), "天罚已触发 · 昏迷剩余 %.1f 秒" % (remaining / 1000.0), 25, Color("ffcf6b"), 850)
	else:
		_draw_text(Vector2(48, 650), "等待雕像累计损失达到 50%…", 25, Color("a9bfd0"), 850)
	if status_expired_at >= 0:
		_draw_text(Vector2(48, 686), "5 秒后状态解除：范围内目标恢复行动", 20, Color("8dffb1"), 850)
	else:
		_draw_text(Vector2(48, 686), "昏迷限制：不能移动、不能攻击、不能释放技能", 20, Color("9fc7dc"), 850)

func _draw_unit(unit: Dictionary, label: String) -> void:
	if unit.is_empty():
		return
	var position := _screen_pos(unit.pos)
	var stunned := _is_stunned(unit)
	var tint := Color("8bd6e8") if stunned else Color("f2b18a")
	draw_circle(position, 30, Color(0.02, 0.06, 0.1, 0.75), true)
	draw_circle(position, 33, Color("5de2ff") if stunned else Color("c87559"), false, 4.0, true)
	if atlas != null and not str(unit.get("res", "")).is_empty():
		atlas.actor(self, str(unit.res), "idle", position + Vector2(0, 20), frame_index * FRAME_MS, 0.32, 1.0, Color.WHITE, Vector2(0.5, 0.85))
	if stunned:
		_draw_stun_effect(position)
	_draw_text(position + Vector2(-90, 58), label, 21, tint, 180)
	_draw_text(position + Vector2(-110, 88), "昏迷" if stunned else "可行动", 18, Color("6fe3ff") if stunned else Color("d8e6ef"), 220)

func _draw_tianfa_effect() -> void:
	var age := maxi(0, frame_index * FRAME_MS - status_started_at)
	var pulse := 1.0 + 0.08 * sin(age * TAU / 420.0)
	draw_circle(VIEW_CENTER, RADIUS * WORLD_SCALE * pulse, Color(1.0, 0.55, 0.15, 0.05), false, 8.0, true)
	draw_arc(VIEW_CENTER, RADIUS * WORLD_SCALE * (0.82 + 0.08 * sin(age * TAU / 500.0)), 0, TAU, 64, Color(1.0, 0.72, 0.28, 0.75), 5.0, true)
	if atlas != null:
		# The trigger marker is a readable compact star ring, without covering the statue.
		atlas.draw(self, "bulletStatus:stun3", VIEW_CENTER, Vector2.ONE * 0.18, age, Vector2(0.5, 0.5), Color("#ffd35a"), 0, true)
	_draw_text(Vector2(300, 285), "天罚触发", 32, Color("ffd36b"), 360)

func _draw_stun_effect(position: Vector2) -> void:
	var age := maxi(0, frame_index * FRAME_MS - status_started_at)
	if atlas != null:
		atlas.draw(self, "bulletStatus:stun3", position + Vector2(0, -26), Vector2.ONE * 0.18, age, Vector2(0.5, 0.5), Color("#63e7ff"), 0, true)

func _is_stunned(unit: Dictionary) -> bool:
	return not unit.is_empty() and world.statuses.has_status(unit, 4)

func _draw_text(position: Vector2, value: String, size: int, color: Color, width: float) -> void:
	var font: Font = atlas.font if atlas != null else ThemeDB.fallback_font
	draw_string_outline(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, 5, Color(0.02, 0.04, 0.07, color.a))
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)
