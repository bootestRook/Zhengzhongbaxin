class_name DefenseHeroTerms
extends Control

const TermRow = preload("res://scenes/defense/hero_term_row.tscn")
const HeroButton = preload("res://scenes/defense/term_hero_button.tscn")

var catalog
var atlas: DefenseAtlas
var selected_hero_id: int = 0
var roster_ids: Array = []
var displayed_hero_id: int = 0
var displayed_upgrades: Array = []
var current: Dictionary = {}
var mouse_dragging: bool = false

func configure(definitions, resources: DefenseAtlas) -> void:
	catalog = definitions
	atlas = resources
	$Panel/Paper.configure(atlas)
	$Backdrop.pressed.connect(dismiss)
	$Panel/Scroll.gui_input.connect(scroll_input)
	$Panel/Scroll.mouse_exited.connect(func(): mouse_dragging = false)

func open(hero_id: int, snapshot: Dictionary) -> void:
	selected_hero_id = hero_id
	roster_ids = []
	displayed_hero_id = 0
	show()
	render(snapshot)
	if visible:
		$Panel.grab_focus()

func dismiss() -> void:
	hide()
	selected_hero_id = 0
	mouse_dragging = false

func scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_dragging = event.pressed
		$Panel/Scroll.accept_event()
	elif event is InputEventMouseMotion and mouse_dragging:
		$Panel/Scroll.scroll_vertical -= roundi(event.relative.y)
		$Panel/Scroll.accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_dragging = false

func render(snapshot: Dictionary) -> void:
	current = snapshot
	if not visible:
		return
	if snapshot.phase in ["home", "reward", "result"]:
		dismiss()
		return
	var selected: Dictionary = {}
	for hero: Dictionary in snapshot.heroes:
		if int(hero.id) == selected_hero_id:
			selected = hero
	if selected.is_empty():
		dismiss()
		return
	var ids: Array = snapshot.heroes.map(func(hero): return int(hero.id))
	if ids != roster_ids:
		for button in $Heroes.get_children():
			button.free()
		for hero: Dictionary in snapshot.heroes:
			var button = HeroButton.instantiate()
			$Heroes.add_child(button)
			button.configure(hero, atlas)
			button.pressed.connect(func(): select_hero(button.hero_id))
		roster_ids = ids
	for button in $Heroes.get_children():
		button.set_pressed_no_signal(button.hero_id == selected_hero_id)
	if displayed_hero_id != selected_hero_id or displayed_upgrades != selected.upgrades:
		$Panel/Portrait.configure(selected, atlas)
		$Panel/HeroName.text = selected.name
		for row in $Panel/Scroll/Rows.get_children():
			row.free()
		var counts: Dictionary = {}
		var initial: Array = catalog.record("heroes", int(selected.template)).initial_options.map(func(id): return int(id))
		for id in selected.upgrades:
			if initial.has(int(id)):
				continue
			counts[int(id)] = int(counts.get(int(id), 0)) + 1
		for id in counts:
			var row = TermRow.instantiate()
			$Panel/Scroll/Rows.add_child(row)
			row.configure(catalog.record("options", id), counts[id])
		$Panel/Empty.visible = counts.is_empty()
		$Panel/Scroll.scroll_vertical = 0
		displayed_hero_id = selected_hero_id
		displayed_upgrades = selected.upgrades.duplicate()

func select_hero(hero_id: int) -> void:
	selected_hero_id = hero_id
	render(current)
