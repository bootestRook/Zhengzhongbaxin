class_name DefenseResultPanel
extends Control

signal confirmed
signal hero_requested(hero: Dictionary)

const Card = preload("res://scenes/defense/result_card.tscn")
const Item = preload("res://scenes/defense/result_item.tscn")
var atlas: DefenseAtlas
var active: bool = false
var entrance: Tween
var current: Dictionary = {}
var entrances: int = 0

func configure(resources: DefenseAtlas) -> void:
	atlas = resources
	for image in find_children("*", "TextureRect"):
		if image is DefenseAtlasSprite:
			image.configure(atlas)
	$Progress.atlas = atlas
	$Confirm.pressed.connect(func():
		stop_motion()
		confirmed.emit())
	$Confirm.button_down.connect(func(): $Confirm.modulate = Color(0.78, 0.78, 0.78))
	$Confirm.button_up.connect(func(): $Confirm.modulate = Color.WHITE)

func render(value: Dictionary) -> void:
	if value.phase != "result":
		active = false
		hide()
		stop_motion()
		return
	if active:
		return
	active = true
	current = value.result
	show()
	build()
	reveal()

func build() -> void:
	$Header/Paper.resource_key = "battle:bg2" if current.won else "battle:bg1"
	$Header/Paper.configure(atlas)
	$Header/Title.text = "关卡胜利" if current.won else "关卡结束"
	$Level.text = "第%d关" % current.level
	$History.text = "%d%%\n历史记录" % floori(current.best * 100)
	$Progress.result = current
	for holder in [$Heroes, $Rewards/Items]:
		for node in holder.get_children():
			node.free()
	var count: int = current.heroes.size()
	var left: float = (960 - count * 168 - maxi(0, count - 1) * 16) / 2
	for i in range(count):
		var card = Card.instantiate()
		$Heroes.add_child(card)
		card.position = Vector2(left + i * 184, 0)
		card.configure(atlas, current.heroes[i], current.totals, i == current.mvp)
		card.details_requested.connect(func(hero): hero_requested.emit(hero))
	$EmptyTeam.visible = count == 0
	add_items($Rewards/Items, current.rewards, 100, 12)
	$Rewards/Title.text = "获得奖励" if not current.rewards.is_empty() else "未获得奖励"

func add_items(holder: Control, items: Array, width: float, gap: float) -> void:
	var left: float = (960 - items.size() * width - maxi(0, items.size() - 1) * gap) / 2
	for i in range(items.size()):
		var item = Item.instantiate()
		holder.add_child(item)
		item.position = Vector2(left + i * (width + gap), 0)
		item.size = Vector2.ONE * width
		item.configure(atlas, items[i])

func reveal() -> void:
	entrances += 1
	stop_motion()
	entrance = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	$Shade.modulate.a = 0
	entrance.tween_property($Shade, "modulate:a", 1.0, 0.2)
	$Glow.modulate.a = 0
	entrance.tween_property($Glow, "modulate:a", 0.5, 0.6).set_delay(0.1)
	$Header.pivot_offset = $Header.size / 2
	$Header.scale = Vector2.ONE * 0.6
	$Header.modulate.a = 0
	entrance.tween_property($Header, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_delay(0.12)
	entrance.tween_property($Header, "modulate:a", 1.0, 0.18).set_delay(0.12)
	for pair in [[$Progress, 0.65], [$Level, 0.8], [$History, 0.8], [$EmptyTeam, 1.0], [$Rewards, 1.55], [$Confirm, 1.0]]:
		pair[0].modulate.a = 0
		entrance.tween_property(pair[0], "modulate:a", 1.0, 0.25).set_delay(pair[1])
	$Progress.update_fraction(0)
	entrance.tween_method($Progress.update_fraction, 0.0, current.progress, 0.45).set_delay(0.65)
	for i in range($Heroes.get_child_count()):
		var card = $Heroes.get_child(i)
		card.modulate.a = 0
		card.pivot_offset = card.size / 2
		card.scale = Vector2.ONE * 0.85
		card.count_up(0)
		var delay: float = 1.0 + i * 0.08
		entrance.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		entrance.tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(delay)
		entrance.tween_method(card.count_up, 0.0, 1.0, 0.6).set_delay(delay)
		var crown = card.get_node("MVP")
		crown.modulate.a = 0
		entrance.tween_property(crown, "modulate:a", 1.0, 0.25).set_delay(1.65)
	$Confirm.disabled = true
	entrance.tween_callback(func(): $Confirm.disabled = false).set_delay(1.25)

func stop_motion() -> void:
	if entrance != null:
		entrance.kill()
		entrance = null

func _process(delta: float) -> void:
	if is_visible_in_tree():
		$Glow.rotation += delta * 0.35

func _exit_tree() -> void:
	stop_motion()
