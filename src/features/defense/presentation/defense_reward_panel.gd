extends Control

signal close_requested(id: int)
const Row = preload("res://scenes/defense/reward_row.tscn")
const VisualRng = preload("res://src/foundation/rng_set.gd")
const COUNT_TIME: float = 0.85
const SPIN_TIME: float = 0.9
var catalog
var atlas: DefenseAtlas
var packet: Dictionary = {}
var elapsed: float = 0
var finished: bool = false
var stops: Array = []
var pressed_at: Vector2 = Vector2.INF

func _ready() -> void:
	gui_input.connect(func(event): input_event(event, self))
	$Results.gui_input.connect(func(event): input_event(event, $Results))

func configure(definitions, art: DefenseAtlas) -> void:
	catalog = definitions
	atlas = art

func render(snapshot: Dictionary) -> void:
	visible = snapshot.phase == "reward"
	if not visible:
		packet = {}
		return
	if not packet.is_empty() and packet.id == snapshot.reward.id:
		return
	packet = snapshot.reward
	elapsed = 0
	finished = false
	pressed_at = Vector2.INF
	$Results.scroll_vertical = 0
	for row in $Results/Rows.get_children():
		row.free()
	$Source.text = "精英掉落" if packet.source == "elite" else "首领掉落"
	$Wheel.visible = not packet.items.is_empty()
	stops.clear()
	if packet.items.is_empty():
		update_motion()
		return
	var entries: Array = packet.items.duplicate(true)
	for candidate in packet.candidates:
		if not entries.any(func(item): return item.id == candidate.id):
			entries.append(candidate)
	var random = VisualRng.new(int(packet.id)).stream("defense.reward.visual")
	while entries.size() < 12:
		entries.append(entries[random.next_int(entries.size())])
	# Every award has a visible stopping position, even for a large candidate pool.
	entries.resize(12)
	for i in range(11, 0, -1):
		var other: int = random.next_int(i + 1)
		var swap = entries[i]
		entries[i] = entries[other]
		entries[other] = swap
	for i in range(12):
		$Wheel.get_child(i).configure(atlas, catalog.record("options", entries[i].id))
	for item in packet.items:
		stops.append(entries.map(func(entry): return entry.id).find(item.id))
		var option: Dictionary = catalog.record("options", item.id)
		var row = Row.instantiate()
		$Results/Rows.add_child(row)
		row.get_node("Content/Text/Name").text = "%s · %s" % [catalog.record("heroes", option.type[0]).name, option.title]
		row.get_node("Content/Text/Description").text = option.description
		row.get_node("Content/Icon").texture = atlas.texture(option.icon_res)
	update_motion()

func duration() -> float:
	return 0 if packet.items.is_empty() else COUNT_TIME + packet.items.size() * SPIN_TIME + 0.3

func _process(delta: float) -> void:
	if not visible or packet.is_empty():
		return
	elapsed += delta
	update_motion()

func update_motion() -> void:
	finished = elapsed >= duration()
	modulate.a = 1 if finished else minf(1, elapsed / 0.15)
	$Hint.text = "再次点击继续战斗" if finished else "点击跳过动画"
	if packet.items.is_empty():
		$Status.text = "词条已全部获得"
		$Hint.text = "点击继续战斗"
		return
	var spinning: int = clampi(int((elapsed - COUNT_TIME) / SPIN_TIME), 0, stops.size() - 1)
	var progress: float = clampf((elapsed - COUNT_TIME - spinning * SPIN_TIME) / SPIN_TIME, 0, 1)
	var start: int = 0 if spinning == 0 else stops[spinning - 1]
	var distance: int = 24 + posmod(int(stops[spinning]) - start, 12)
	var head: int = posmod(start + roundi(distance * (1 - pow(1 - progress, 3))), 12)
	$Status.text = "获得%d个词条" % packet.items.size() if finished else ("正在抽取数量：%d" % (int(elapsed * 18) % 4 + 1) if elapsed < COUNT_TIME else "获得%d个词条 · 正在揭晓第%d个" % [packet.items.size(), spinning + 1])
	for i in range(12):
		var slot = $Wheel.get_child(i)
		slot.active = elapsed >= COUNT_TIME and not finished and i == head
		slot.won = false
		for prize in range(stops.size()):
			if i == stops[prize] and elapsed >= COUNT_TIME + (prize + 1) * SPIN_TIME:
				slot.won = true
		slot.queue_redraw()
	for i in range(packet.items.size()):
		var row = $Results/Rows.get_child(i)
		var reveal: float = clampf((elapsed - COUNT_TIME - (i + 1) * SPIN_TIME) / 0.18, 0, 1)
		row.modulate.a = reveal
		row.scale = Vector2.ONE * (0.96 + 0.04 * reveal)

func advance_display() -> void:
	if packet.is_empty():
		return
	if not finished:
		elapsed = duration()
		update_motion()
	else:
		close_requested.emit(int(packet.id))

func input_event(event: InputEvent, surface: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = surface.get_global_transform_with_canvas() * event.position
		if event.pressed:
			pressed_at = point
		elif pressed_at != Vector2.INF:
			var dragged: bool = pressed_at.distance_to(point) > 16
			pressed_at = Vector2.INF
			if not dragged:
				advance_display()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
		advance_display()
		get_viewport().set_input_as_handled()
