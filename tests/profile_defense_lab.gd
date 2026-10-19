extends RefCounted

const Lab = preload("res://src/features/defense/domain/lab/battle_lab.gd")

func run(test, catalog) -> Array:
	var results: Array = []
	var lab = Lab.new(catalog)
	for count in [100, 300]:
		test.assert_equal(lab.submit("clear", {"scope": "all"}), "", "stress clears previous setup")
		test.assert_equal(lab.submit("add", {"kind": "hero", "template": 1, "pos": [800, 1100], "survival": "immortal"}), "", "stress creates caster")
		test.assert_equal(lab.submit("add", {"template": 101, "count": count, "layout": "random", "spacing": 500, "pos": [800, 700], "survival": "immortal"}), "", "stress creates requested population")
		var samples: Array = []
		var snapshots: Array = []
		lab.submit("advance", {"ticks": 20})
		for _tick in range(180):
			var began = Time.get_ticks_usec()
			lab.submit("advance", {"ticks": 1})
			samples.append(Time.get_ticks_usec() - began)
			began = Time.get_ticks_usec()
			lab.world.snapshot()
			snapshots.append(Time.get_ticks_usec() - began)
		samples.sort()
		snapshots.sort()
		results.append({"monsters": count, "heroes": 1, "sample_steps": samples.size(), "fixed_step_ms": 16,
			"logical_step_p50_ms": samples[90] / 1000.0, "logical_step_p95_ms": samples[171] / 1000.0,
			"logical_step_max_ms": samples.back() / 1000.0, "snapshot_p95_ms": snapshots[171] / 1000.0,
			"scope": "Headless domain + bounded trace; excludes renderer and UI, not a frame-rate guarantee"})
		test.assert_true(lab.world.diagnostics.is_empty(), "stress no missing definitions")
		test.assert_true(lab.world.trace.size() <= 2000, "trace is bounded during stress")
		for _repeat in range(3):
			lab.submit("reset")
			lab.submit("advance", {"ticks": 5})
			test.assert_equal(lab.world.units.size(), count + 1, "restart does not duplicate actors")
		lab.submit("clear", {"scope": "all"})
		test.assert_true(lab.world.units.is_empty() and lab.world.core._entities.is_empty(), "stress clear removes every actor and core")
		test.assert_true(lab.world.missiles.is_empty() and lab.world.skills.queue.is_empty(), "stress clear removes delayed actions")
	lab.dispose()
	return results
