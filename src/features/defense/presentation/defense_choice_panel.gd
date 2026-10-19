class_name DefenseChoicePanel
extends Control

signal intent_requested(intent: String, payload: Dictionary)
signal details_requested(index: int)

var catalog
var atlas: DefenseAtlas
var current: Dictionary = {}
var last_key: String = ""
var motion: Tween
var busy: bool = false
var entrances: int = 0

func _exit_tree() -> void:
	if motion != null:
		motion.kill()

func configure(definitions, art: DefenseAtlas) -> void:
	catalog = definitions
	atlas = art
	$Refresh.atlas = art
	$Refresh.pressed.connect(refresh)
	for i in range(3):
		var card = $Cards.get_child(i)
		card.pressed.connect(func(): choose(i))
		card.details_requested.connect(func(): details_requested.emit(i))

func render(value: Dictionary) -> void:
	current = value
	visible = value.phase == "choice"
	$Refresh.visible = true
	$Refresh/Remaining.text = "剩余%d" % value.refresh_left
	$Refresh.disabled = busy or value.refresh_left <= 0
	if value.phase != "choice":
		cancel()
		last_key = ""
		return
	if value.paused:
		cancel()
		lock(true)
		return
	var key: String = JSON.stringify([value.choice_kind, value.offers])
	if key == last_key:
		if busy and motion == null:
			lock(false)
		return
	last_key = key
	for i in range(3):
		var card = $Cards.get_child(i)
		var index = i
		card.visible = index >= 0 and index < value.offers.size()
		$Lights.get_child(i).visible = card.visible
		if card.visible:
			card.configure(atlas, value.offers[index], catalog, value)
	enter()

func enter() -> void:
	cancel()
	entrances += 1
	lock(true)
	$Shade.modulate.a = 0
	$RosterShade.modulate.a = 0
	$Lights.modulate.a = 0
	$Refresh.modulate.a = 0
	$Refresh.scale = Vector2.ONE * 0.94
	$Refresh.pivot_offset = $Refresh.size / 2
	motion = create_tween().set_parallel(true)
	motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property($Shade, "modulate:a", 1.0, 0.18)
	motion.tween_property($RosterShade, "modulate:a", 1.0, 0.18)
	motion.tween_property($Lights, "modulate:a", 1.0, 0.45).set_delay(0.10)
	for i in range(3):
		var card = $Cards.get_child(i)
		card.position.y = 64
		card.scale = Vector2.ONE * 0.82
		card.modulate.a = 0
		var delay = 0.08 + i * 0.10
		motion.tween_property(card, "position:y", 0.0, 0.34).set_delay(delay)
		motion.tween_property(card, "scale", Vector2.ONE, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK)
		motion.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(delay)
	motion.tween_property($Refresh, "modulate:a", 1.0, 0.2).set_delay(0.4)
	motion.tween_property($Refresh, "scale", Vector2.ONE, 0.25).set_delay(0.4)
	motion.finished.connect(func(): lock(false))

func choose(index: int) -> void:
	if busy or not visible or current.paused or index < 0 or index >= current.offers.size():
		return
	cancel()
	lock(true)
	var selected = $Cards.get_child(index)
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(selected, "scale", Vector2.ONE * 1.035, 0.13)
	for i in range(3):
		if i != index:
			motion.tween_property($Cards.get_child(i), "modulate:a", 0.28, 0.13)
	motion.finished.connect(func():
		if visible and current.phase == "choice" and not current.paused:
			intent_requested.emit("choose", {"index": index}))

func refresh() -> void:
	if busy or not visible or current.refresh_left <= 0:
		return
	last_key = ""
	intent_requested.emit("refresh", {})

func lock(locked: bool) -> void:
	busy = locked
	$Refresh.disabled = locked or current.get("refresh_left", 0) <= 0
	for card in $Cards.get_children():
		card.disabled = locked
		card.get_node("Info").disabled = locked

func cancel() -> void:
	if motion != null:
		motion.kill()
		motion = null
	$Shade.modulate.a = 1
	$RosterShade.modulate.a = 1
	$Lights.modulate.a = 1
	$Refresh.modulate.a = 1
	$Refresh.scale = Vector2.ONE
	for card in $Cards.get_children():
		card.stop_press()
		card.scale = Vector2.ONE
		card.modulate = Color.WHITE
		card.position.y = 0
	lock(false)

