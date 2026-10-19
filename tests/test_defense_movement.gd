extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "movement catalog loads")
	_entry(test, catalog)
	_wall_approach(test, catalog)
	_congestion(test, catalog)
	for x in [350, 800, 1250]:
		_avoidance(test, catalog, x)
	_opposing_movers(test, catalog)
	_spatial_index(test, catalog)

func world(catalog):
	var w = Session.new(catalog)
	w.start(71)
	w.spawn_wave = 1
	return w

func _entry(test, catalog) -> void:
	for start_x in [350, 575, 800, 1025, 1250]:
		var w = world(catalog)
		var enemy = w.factory.create("enemy", 101, Vector2(start_x, 10), 2)
		for frame in range(1500):
			w.time_ms += 16
			w.space.rebuild()
			w.navigation.rebuild()
			w.ai.tick()
			if enemy.pos.y >= w.combat.world.warning_y:
				break
		test.assert_true(enemy.pos.y >= 550, "entry reaches the acquisition boundary")
		test.assert_equal(enemy.pos.x, float(start_x), "unopposed entry retains its spawn X across the full battlefield")
		test.assert_equal(enemy.target, 0, "entry does not acquire an imaginary central target")
		test.assert_true(not enemy.has("path"), "unopposed entry does not build a path toward the statue")
		w.dispose()

func _wall_approach(test, catalog) -> void:
	var w = world(catalog)
	var enemy = w.factory.create("enemy", 101, Vector2(400, 650), 2)
	var origin: Vector2 = enemy.pos
	w.space.rebuild()
	w.ai.tick()
	var destination = Geometry.approach(enemy, Statue.TARGET)
	var delta: Vector2 = enemy.pos - origin
	test.assert_true(delta.x > 0 and delta.y > 0, "unblocked side-lane monster advances toward the real statue")
	test.assert_true(delta.normalized().dot((destination - origin).normalized()) > 0.999, "wall approach follows its direct bearing instead of a shared grid waypoint")
	test.assert_true(not enemy.has("path"), "wall approach leaves pathfinding to actual unit pursuit")
	w.dispose()

func _congestion(test, catalog) -> void:
	var w = world(catalog)
	var origin = Vector2i(16, 12)
	var goal = Vector2i(16, 22)
	for y in range(14, 21):
		w.navigation.grid.occupancy[Vector2i(16, y)] = 4
	var path = w.navigation.grid.get_id_path(origin, goal)
	test.assert_true(not path.is_empty() and path.back() == goal, "congested route still reaches the actual target")
	var occupied = 0
	for point in path:
		occupied += int(w.navigation.grid.occupancy.has(point))
	test.assert_equal(occupied, 0, "accumulated path cost chooses a clear route around the crowded cells")
	w.dispose()

func _avoidance(test, catalog, x: float) -> void:
	var w = world(catalog)
	var mover = w.factory.create("enemy", 101, Vector2(x, 600), 2)
	var resting = w.factory.create("enemy", 101, Vector2(x, 650), 2)
	var fixed: Vector2 = resting.pos
	var overlap = 0.0
	var peak_step = 0.0
	for frame in range(300):
		w.space.rebuild()
		var previous: Vector2 = mover.pos
		w.space.move(mover, Vector2(x, 900), 1.28)
		peak_step = maxf(peak_step, previous.distance_to(mover.pos))
		overlap = maxf(overlap, mover.radius + resting.radius - mover.pos.distance_to(resting.pos))
	test.assert_true(mover.pos.y > 850, "head-on contact turns around the stationary feet instead of forming a queue")
	test.assert_true(overlap < 0.1, "local detour prevents feet from overlapping")
	test.assert_true(peak_step <= 1.281, "contact steering respects the movement budget")
	test.assert_equal(resting.pos, fixed, "a moving crowd does not push an idle or attacking unit")
	w.dispose()

func _opposing_movers(test, catalog) -> void:
	var w = world(catalog)
	var a = w.factory.create("enemy", 101, Vector2(800, 600), 2)
	var b = w.factory.create("enemy", 101, Vector2(800, 660), 2)
	for frame in range(300):
		w.space.rebuild()
		w.space.move(a, Vector2(800, 1000), 1.28)
		w.space.move(b, Vector2(800, 300), 1.28)
	test.assert_true(a.pos.y > 900 and b.pos.y < 350, "opposing movers pass each other instead of drifting together into a queue")
	w.dispose()

func _spatial_index(test, catalog) -> void:
	var w = world(catalog)
	w.space.rebuild()
	var mover = w.factory.create("enemy", 101, Vector2(499, 600), 2)
	test.assert_true(w.space.nearby(mover.pos, 1).has(mover), "a newly spawned unit immediately participates in local avoidance")
	w.space.move(mover, Vector2(600, 600), 5)
	test.assert_true(w.space.cells.get(Vector2i(5, 6), []).has(mover), "a move refreshes its spatial bucket during the same tick")
	test.assert_true(not w.space.cells.get(Vector2i(4, 6), []).has(mover), "the old spatial bucket cannot retain a moved unit")
	w.start(72)
	test.assert_true(w.space.nearby(mover.pos, 1000).is_empty(), "a new run clears all old spatial occupants")
	w.dispose()
