extends Control

signal hero_requested(id: int)

const HeroCard = preload("res://scenes/defense/home_hero_card.tscn")

var catalog
var selected_hero_id: int = 0
var cards: Dictionary = {}
var notice_left: float = 0.0

func configure(definitions, atlas: DefenseAtlas) -> void:
	catalog = definitions
	$Actor.configure(atlas)
	var unlocked: Array = catalog.available_heroes()
	var ids: Array = []
	for key in catalog.records("heroes"):
		ids.append(int(key))
	ids.sort()
	var ordered: Array = unlocked.duplicate()
	for id in ids:
		if not unlocked.has(id):
			ordered.append(id)
	for id in ordered:
		var card = HeroCard.instantiate()
		card.name = "Hero%d" % id
		$Scroll/Grid.add_child(card)
		card.configure(catalog.record("heroes", id), unlocked.has(id), atlas)
		card.pressed.connect(func(): activate_hero(id))
		cards[id] = card
	select_hero(unlocked[0])
	visibility_changed.connect(clear_notice)

func activate_hero(id: int) -> void:
	select_hero(id)
	if cards[id].unlocked:
		hero_requested.emit(id)

func select_hero(id: int) -> void:
	if not cards[id].unlocked:
		notice_left = 1.6
		$Notice.show()
		return
	selected_hero_id = id
	var hero: Dictionary = catalog.record("heroes", id)
	$HeroName.text = hero.name
	$Actor.show_hero(hero.res)
	for key in cards:
		cards[key].set_selected(key == id)
	clear_notice()

func clear_notice() -> void:
	notice_left = 0.0
	$Notice.hide()

func _process(delta: float) -> void:
	if notice_left > 0.0:
		notice_left -= delta
		$Notice.visible = notice_left > 0.0
