extends Control

const FLY_SECONDS := 0.4
const ARRIVE_SECONDS := 0.5
var atlas: DefenseAtlas
var field: DefenseField
var roster: Control
var snapshot: Dictionary = {}
var flights: Array = []

func prepare_selection(payload: Dictionary, panel: Control, catalog) -> Dictionary:
	var index = int(payload.get("index", -1))
	if index < 0 or index >= snapshot.get("offers", []).size() or snapshot.offers[index].kind != "upgrade":
		return {}
	var offer: Dictionary = snapshot.offers[index]
	var card = panel.get_node("Cards").get_child(index)
	var origin = get_global_transform_with_canvas().affine_inverse() * card.get_global_transform_with_canvas() * card.get_node("TermName").get_rect().get_center()
	return {"id": offer.id, "owner": offer.owner, "icon": catalog.record("options", int(offer.id)).icon_res,
		"origin": origin, "history_size": snapshot.get("history", []).size()}

func confirm_selection(selection: Dictionary) -> void:
	if selection.is_empty() or snapshot.get("history", []).size() != int(selection.history_size) + 1:
		return
	var committed: Dictionary = snapshot.history.back()
	if int(committed.id) == int(selection.id) and int(committed.owner) == int(selection.owner):
		play(int(selection.owner), selection.icon, selection.origin)

func render(value: Dictionary) -> void:
	if value.phase in ["home", "result"] or int(value.time) < int(snapshot.get("time", 0)):
		flights.clear()
	snapshot = value
	queue_redraw()

func play(owner: int, icon: String, origin: Vector2) -> void:
	if target(owner).is_empty():
		return
	flights.append({"owner": owner, "icon": icon, "origin": origin, "elapsed": 0.0})
	queue_redraw()

func target(owner: int) -> Dictionary:
	for i in range(snapshot.get("heroes", []).size()):
		var hero: Dictionary = snapshot.heroes[i]
		if int(hero.id) != owner:
			continue
		if hero.dead:
			var portrait = roster.get_node("Hero%d/Portrait" % i)
			var point = get_global_transform_with_canvas().affine_inverse() * portrait.get_global_transform_with_canvas() * (portrait.size / 2)
			return {"point": point, "foot": point, "dead": true}
		var foot = get_global_transform_with_canvas().affine_inverse() * field.get_global_transform_with_canvas() * field.world(hero.pos)
		return {"point": foot - Vector2(0, 55), "foot": foot, "dead": false}
	return {}

func position_for(flight: Dictionary) -> Vector2:
	var destination = target(int(flight.owner))
	if destination.is_empty():
		return flight.origin
	var t = clampf(float(flight.elapsed) / FLY_SECONDS, 0, 1)
	var start: Vector2 = flight.origin
	var end: Vector2 = destination.point
	var control = (start + end) / 2 - Vector2(0, clampf(start.distance_to(end) * 0.35, 140, 360))
	return start * (1 - t) * (1 - t) + control * 2 * t * (1 - t) + end * t * t

func _process(delta: float) -> void:
	if flights.is_empty() or snapshot.get("paused", false):
		return
	for flight: Dictionary in flights:
		flight.elapsed += delta
	flights = flights.filter(func(f): return f.elapsed < FLY_SECONDS + ARRIVE_SECONDS and not target(int(f.owner)).is_empty())
	queue_redraw()

func _draw() -> void:
	if atlas == null:
		return
	for flight: Dictionary in flights:
		var destination = target(int(flight.owner))
		if destination.is_empty():
			continue
		if flight.elapsed < FLY_SECONDS:
			var t = clampf(float(flight.elapsed) / FLY_SECONDS, 0, 1)
			var diameter = lerpf(132, 44, t) * (1 + 0.12 * sin(t * PI))
			var area = Rect2(position_for(flight) - Vector2.ONE * diameter / 2, Vector2.ONE * diameter)
			atlas.picture(self, "map:skillBg3", area)
			atlas.picture(self, flight.icon, area.grow(-4))
		else:
			var age = flight.elapsed - FLY_SECONDS
			var t = clampf(age / ARRIVE_SECONDS, 0, 1)
			if not destination.dead:
				atlas.draw(self, "battleEffect:summon3", destination.foot, Vector2.ONE * 0.75, roundi(age * 1000), Vector2(0.5, 0.8), Color.WHITE, 0, false)
			for i in range(8):
				var angle = TAU * i / 8 + 0.3
				var offset = Vector2(cos(angle), sin(angle)) * 80 * (1 - pow(1 - t, 3))
				var scale_value = lerpf(0.32, 0.6, (i % 3) / 2.0) * sin(t * PI)
				if scale_value > 0:
					atlas.draw(self, "battle:star", destination.point + offset, Vector2.ONE * scale_value, 0, Vector2(0.5, 0.5), Color(1, 0.83, 0.3, 1 - t), angle * 0.2)
