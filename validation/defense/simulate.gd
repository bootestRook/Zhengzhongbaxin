extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	assert(catalog.load_default().is_empty())
	var world = Session.new(catalog)
	world.start(20261013)
	for i in range(45000):
		if world.phase == "choice":
			print("CHOICE ", world.stage, " ", world.choice_kind, " ", world.offers.map(func(o): return o.title))
			world.submit("choose", {"index": 0})
		if world.phase == "result":
			break
		world.step()
		world.drain_events()
		if i % 5000 == 0:
			print("TICK ", i, " wave=", world.spawn_wave, " kills=", world.kills, " wall=", world.wall_hp, " actors=", world.units.size(), " missiles=", world.missiles.size())
	print("RESULT ", JSON.stringify({"won": world.won, "phase": world.phase, "time": world.time_ms, "wave": world.spawn_wave, "stage": world.stage, "kills": world.kills, "wall": world.wall_hp, "bosses": world.bosses_dead, "diagnostics": world.diagnostics}))
	for id in world.heroes:
		print("HERO ", world.units[id].name, " ", world.units[id].stats)
	world.dispose()
	quit()
