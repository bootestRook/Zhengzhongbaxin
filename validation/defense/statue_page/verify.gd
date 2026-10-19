extends SceneTree

const Equipment = preload("res://src/features/defense/domain/defense_equipment.gd")
const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const WornTests = preload("res://validation/defense/statue_page/worn_tests.gd")
var failures: Array[String] = []
var checks: int = 0
var app
var home
var page
var dialog
const OUT = "res://validation/defense/statue_page/"

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("TEST FAILURE: " + message)

func domain_tests() -> void:
	var gear = Equipment.new()
	for part in Equipment.PARTS:
		var initial = gear.snapshot()
		verify(initial.sockets[part].is_empty(), "initial empty sockets " + part)
		verify(initial.spares[part].size() == 1 and initial.gems[part].size() == 14, "seven qualities with two copies each " + part)
		for gem_type in ["a", "b", "c", "d", "e"]:
			var item = "%s_gem_%s_1" % [part, gem_type]
			verify(gear.submit("gem_inlay", {"part": part, "item": item}).is_empty(), "inlay " + part)
			verify(not gear.submit("gem_inlay", {"part": part, "item": item}).is_empty(), "reject stale gem " + part)
			var unique = gear.snapshot()
			verify(gear.submit("gem_inlay", {"part": part, "item": "%s_gem_%s_2" % [part, gem_type]}) == "该部位已镶嵌相同宝石", "reject same type different instance " + part)
			verify(gear.snapshot() == unique, "duplicate inlay is atomic " + part)
		var before = gear.snapshot()
		var last = part + "_gem_f_1"
		verify(not gear.submit("gem_inlay", {"part": part, "item": last}).is_empty(), "no sixth socket " + part)
		verify(not gear.submit("gem_replace", {"part": part, "item": last, "slot": 5}).is_empty(), "invalid slot " + part)
		verify(not gear.submit("gem_replace", {"part": part, "item": last, "slot": 0.5}).is_empty(), "fractional slot " + part)
		verify(gear.submit("gem_replace", {"part": part, "item": part + "_gem_a_2", "slot": 2}) == "该部位已镶嵌相同宝石", "replacement cannot duplicate another socket type " + part)
		verify(gear.snapshot() == before, "invalid operations do not mutate " + part)
		verify(gear.submit("gem_replace", {"part": part, "item": last, "slot": 2}).is_empty(), "replace socket " + part)
		var after = gear.snapshot()
		verify(after.sockets[part].size() == 5 and after.sockets[part][2] == last, "replace exact socket " + part)
		verify(after.gems[part].size() == 9 and after.gems[part].has(before.sockets[part][2]) and not after.gems[part].has(last), "old gem returned " + part)
		verify(gear.submit("gem_replace", {"part": part, "item": part + "_gem_a_2", "slot": 0}).is_empty(), "same type can replace its own socket without duplication " + part)
		after = gear.snapshot()
		verify(after.sockets[part][0] == part + "_gem_a_2" and after.gems[part].has(part + "_gem_a_1"), "own-slot replacement preserves inventory " + part)
		verify(gear.submit("equipment_replace", {"part": part, "item": after.spares[part][0]}).is_empty(), "gear swap " + part)
		var swapped = gear.snapshot()
		verify(swapped.worn[part] != after.worn[part] and swapped.spares[part] == [after.worn[part]], "old gear returned " + part)
		verify(swapped.sockets[part] == after.sockets[part], "sockets retained across equipment replacement " + part)
		verify(not gear.submit("unequip", {"part": part}).is_empty(), "no unequip " + part)
	var before = gear.snapshot()
	verify(not gear.submit("gem_replace", {"part": "chest", "item": before.gems.head[0], "slot": 0}).is_empty(), "part restriction")
	before.sockets.head.clear()
	before.gem_types["head_gem_a_2"] = "f"
	verify(gear.snapshot().sockets.head.size() == 5, "snapshot cannot mutate owner")
	verify(gear.snapshot().gem_types.head_gem_a_2 == "a", "snapshot cannot change gem type identity")
	var catalog = Catalog.new()
	verify(catalog.load_default().is_empty(), "catalog loads")
	var session = Session.new(catalog)
	verify(session.submit("gem_inlay", {"part": "head", "item": "head_gem_a_1"}).is_empty(), "session routes inventory intent")
	var retained = session.equipment.snapshot()
	verify(session.submit("start", {"seed": 41}).is_empty(), "start combat with equipment")
	verify(session.wall_max == 3900 and session.wall_hp == 3900, "no combat stat effects")
	verify(not session.submit("gem_inlay", {"part": "head", "item": "head_gem_b_1"}).is_empty(), "combat blocks inventory mutations")
	session.submit("quit")
	session.submit("home")
	verify(session.equipment.snapshot() == retained, "battle round trip retains inventory")
	session.dispose()

func click(control: Control) -> void:
	var point = control.get_global_transform_with_canvas() * (control.size / 2)
	await click_point(point)

func click_point(point: Vector2) -> void:
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func outside() -> void:
	var point = page.get_global_transform_with_canvas() * Vector2(25, 300)
	await click_point(point)

func open_gem(part: String, gem_type: String) -> void:
	if dialog.visible:
		await outside()
	await click(page.get_node("Bag/Scroll/Items/" + part + "_" + gem_type))
	verify(dialog.visible and dialog.gem_type == gem_type and dialog.part == part, "open distinct gem stack " + part + gem_type)

func scroll_bag(button: int) -> void:
	var scroll = page.get_node("Bag/Scroll")
	var point = scroll.get_global_transform_with_canvas() * (scroll.size / 2)
	for index in range(12):
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.button_index = button
			event.position = point
			event.global_position = point
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame

func press_escape() -> void:
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(OUT + name + ".png")
	verify(error == OK, "capture " + name)

func verify_socket_types(part: String, types: Array) -> void:
	var card = page.get_node("Gear/Slot%d" % page.DISPLAY_PARTS.find(part))
	for index in range(5):
		var gem_type: String = types[index] if index < types.size() else ""
		var fill = card.get_node("Sockets/S%d/Fill" % index)
		var expected: Color = Color("c2c4bd") if gem_type.is_empty() else card.SOCKET_COLORS[gem_type]
		verify(fill.color == expected, "socket color follows actual ordered gem %s/%d/%s" % [part, index, gem_type])
		verify(fill.get_node("Rainbow").visible == (gem_type == "g"), "only supreme gem displays rainbow %s/%d" % [part, index])

func run() -> void:
	get_tree_timeout()
	domain_tests()
	root.position = Vector2i(-3000, 30)
	root.size = Vector2i(720, 1440)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	home = app.get_node("DefenseView/Home")
	page = home.get_node("StatuePage")
	dialog = page.get_node("Dialog")
	await click(home.get_node("Statue"))
	verify(home.current_page == "statue" and page.visible, "real navigation opens statue page")
	verify(not home.get_node("BattlePage").visible and not home.get_node("HeroPage").visible, "one page visible")
	verify(home.get_node("PlayerName").visible and home.get_node("PlayerId").visible, "shared header survives navigation")
	verify(page.get_node("Bag/Scroll/Items").get_child_count() == 42, "seven gem qualities per part shown separately")
	verify_socket_types("head", [])
	var qualities = ["普通", "精良", "卓越", "完美", "传说", "绝世", "至尊"]
	var textures: Array = []
	for index in range(7):
		var gem_type: String = Equipment.GEM_TYPES.keys()[index]
		var button = page.get_node("Bag/Scroll/Items/head_" + gem_type)
		verify(Equipment.GEM_TYPES[gem_type] == qualities[index], "quality display name " + gem_type)
		verify(button.get_node("BadgeFrame").visible, "part badge has backing " + gem_type)
		var path: String = button.get_node("Icon").texture.resource_path
		verify(not textures.has(path), "each quality has distinct illustrated texture " + gem_type)
		textures.append(path)
	await capture("main_720")
	await click(page.get_node("Bag/Filter"))
	await click(page.get_node("Filter/Panel/Part1"))
	await capture("gem_qualities_filtered_720")
	await click(page.get_node("Bag/Filter"))
	await click(page.get_node("Filter/Panel/Part0"))
	await scroll_bag(MOUSE_BUTTON_WHEEL_DOWN)
	await capture("bag_scrolled_720")
	await open_gem("gloves", "g")
	verify(dialog.get_node("Left/Quantity").text == "数量：2", "last stack reachable with real scrolling")
	verify(dialog.get_node("Left/Quality").visible and dialog.get_node("Left/Quality").text == "品质：至尊", "detail shows named quality")
	verify(dialog.get_node("Left/GemPart").text == "手套" and dialog.get_node("Left/PartBadge").visible, "detail shows equipment part icon and name")
	await capture("gem_rainbow_detail_720")
	await click(dialog.get_node("Left/Action"))
	verify_socket_types("gloves", ["g"])
	await outside()
	await scroll_bag(MOUSE_BUTTON_WHEEL_UP)
	await click(page.get_node("Bag/Equipment"))
	await click(page.get_node("Bag/Scroll/Items").get_child(0))
	verify(dialog.visible and dialog.get_node("Right").visible, "two separate equipment cards")
	await capture("equipment_720")
	var previous_gear: String = app.session.equipment.snapshot().worn.head
	await click(dialog.get_node("Right/Action"))
	verify(app.session.equipment.snapshot().worn.head != previous_gear and not dialog.visible, "real equipment replacement input")
	await click(page.get_node("Bag/Gems"))
	await click(page.get_node("Bag/Scroll/Items").get_child(0))
	verify(dialog.visible and dialog.kind == "gem", "gem detail opens")
	verify(dialog.get_node("Shade").color.a == 0, "ordinary gem detail no full-screen shade")
	await capture("gem_empty_720")
	for index in range(5):
		await open_gem("head", ["a", "b", "c", "d", "e"][index])
		await click(dialog.get_node("Left/Action"))
		verify(app.session.equipment.snapshot().sockets.head.size() == index + 1, "click directly fills free socket %d" % index)
		verify(not dialog.selecting, "free slot never asks selection")
		verify_socket_types("head", ["a", "b", "c", "d", "e"].slice(0, index + 1))
		if index == 0:
			var unique = app.session.equipment.snapshot()
			verify(dialog.item == "head_gem_a_2" and dialog.get_node("Left/Quantity").text == "数量：1", "details retain selected type and its remaining copy")
			await click(dialog.get_node("Left/Action"))
			verify(app.session.equipment.snapshot() == unique, "real repeated inlay rejects duplicate without consumption")
			verify(page.get_node("Toast").visible and page.get_node("Toast").text == "该部位已镶嵌相同宝石", "duplicate error visible above dialog")
			await capture("gem_duplicate_720")
	await outside()
	await capture("socket_colors_720")
	await open_gem("head", "f")
	await capture("gem_full_720")
	var before = app.session.equipment.snapshot()
	await click(dialog.get_node("Left/Action"))
	verify(dialog.selecting and dialog.get_node("Prompt").visible, "full sockets enter selection")
	verify(dialog.get_node("Shade").color.a > 0.5, "replacement backdrop darkens")
	verify(app.session.equipment.snapshot() == before, "selecting does not consume candidate")
	verify(not page.get_node("Toast").visible, "selection clears previous success feedback")
	await click(dialog.get_node("Left/Action"))
	verify(dialog.selecting and app.session.equipment.snapshot() == before, "repeat inlay during selection does not mutate")
	await capture("gem_select_720")
	await outside()
	verify(dialog.visible and not dialog.selecting, "outside selection returns to details without closing")
	verify(app.session.equipment.snapshot() == before, "cancel does not mutate inventory")
	await click(dialog.get_node("Left/Action"))
	await click(dialog.get_node("GemRows/Slot3"))
	var after = app.session.equipment.snapshot()
	verify(after.sockets.head[3] == "head_gem_f_1", "clicked fourth row replaced")
	verify(after.sockets.head.size() == 5 and after.gems.head.size() == 9 and after.gems.head.has(before.sockets.head[3]), "replace returns old gem and keeps five")
	verify(dialog.visible and not dialog.selecting, "success returns to gem detail")
	verify_socket_types("head", ["a", "b", "c", "f", "e"])
	await open_gem("head", "a")
	await click(dialog.get_node("Left/Action"))
	await click(dialog.get_node("GemRows/Slot1"))
	verify(app.session.equipment.snapshot() == after and dialog.selecting, "duplicate replacement keeps selection and inventory intact")
	verify(page.get_node("Toast").visible and page.get_node("Toast").text == "该部位已镶嵌相同宝石", "duplicate replacement error visible")
	await capture("gem_duplicate_replace_720")
	await click(dialog.get_node("GemRows/Slot0"))
	after = app.session.equipment.snapshot()
	verify(not dialog.selecting and after.sockets.head[0] == "head_gem_a_2", "after rejected target can select valid own-type slot")
	verify(after.gems.head.has("head_gem_a_1") and after.gems.head.size() == 9, "valid target returns original copy without loss")
	await outside()
	verify(not dialog.visible, "outside ordinary details closes")
	await click(page.get_node("Bag/Filter"))
	await click(page.get_node("Filter/Panel/Part3"))
	verify(page.part_filter == "boots" and page.get_node("Bag/Scroll/Items").get_child_count() == 7, "part filter shows seven distinct qualities")
	await click(home.get_node("Heroes"))
	verify(home.current_page == "heroes", "heroes page still works")
	await click(home.get_node("Battle"))
	verify(home.current_page == "battle", "battle page still works")
	await click(home.get_node("Statue"))
	verify(app.session.equipment.snapshot() == after, "tabs retain inventory")
	page.set_filter("")
	root.size = Vector2i(480, 960)
	await process_frame
	await capture("main_480")
	await open_gem("head", "d")
	await click(dialog.get_node("Left/Action"))
	await capture("gem_select_480")
	await outside()
	verify(dialog.visible and not dialog.selecting, "480 input cancellation")
	dialog.close()
	root.size = Vector2i(960, 1920)
	await process_frame
	await capture("main_960")
	await click(page.get_node("Bag/Equipment"))
	await click(page.get_node("Bag/Scroll/Items").get_child(0))
	await capture("equipment_960")
	await press_escape()
	verify(not dialog.visible and home.current_page == "statue", "Escape closes equipment details first")
	await click(page.get_node("Bag/Gems"))
	await click(page.get_node("Bag/Scroll/Items").get_child(0))
	await click(dialog.get_node("Left/Action"))
	await press_escape()
	verify(dialog.visible and not dialog.selecting, "Escape cancels selection without closing details")
	await press_escape()
	verify(not dialog.visible, "second Escape closes ordinary gem details")
	await press_escape()
	verify(home.current_page == "battle", "Escape from statue page returns to battle tab")
	await click(home.get_node("BattlePage/Next"))
	verify(app.battle_snapshot().level == 2, "level selection still works after statue operations")
	await click(home.get_node("BattlePage/Previous"))
	await click(home.get_node("BattlePage/LevelSelect"))
	verify(app.get_node("DefenseView/LevelPanel").visible, "level selector opens after page switching")
	await press_escape()
	await click(home.get_node("BattlePage/Start"))
	verify(app.battle_snapshot().phase == "choice" and not home.visible, "real start input enters battle from home")
	app.submit("choose", {"index": 0})
	verify(app.battle_snapshot().heroes.size() == 1, "battle recruits hero with statue inventory present")
	app.submit("quit")
	app.submit("home")
	await click(home.get_node("Statue"))
	verify(page.is_visible_in_tree() and app.session.equipment.snapshot() == after, "real battle round trip retains statue state")
	await WornTests.run(self)
	print("STATUE PAGE: %d checks; %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func get_tree_timeout() -> void:
	create_timer(60).timeout.connect(func():
		printerr("TEST FAILURE: statue UI timeout")
		quit(2))
