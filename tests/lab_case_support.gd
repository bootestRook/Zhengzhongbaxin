extends RefCounted

const Lab = preload("res://src/features/defense/domain/lab/battle_lab.gd")
const Units = preload("res://src/features/defense/domain/lab/lab_units.gd")

func execute(catalog, value: Dictionary, test) -> Dictionary:
	var lab = Lab.new(catalog)
	var error: String = lab.load_config(value.get("config"))
	test.assert_equal(error, "", "case loads: " + str(value.get("title", "")))
	if error.is_empty():
		for command in value.get("commands", []):
			error = lab.submit(str(command.get("action", "")), command.get("payload", {}))
			test.assert_equal(error, "", "case command: " + str(command))
			if not error.is_empty(): break
	var checks: Array = value.get("checks", [])
	test.assert_true(not checks.is_empty(), "case must declare nonzero independent checks")
	for check in checks:
		var actual: Variant
		if check.get("kind", "unit") == "event":
			actual = lab.world.trace.filter(func(e): return e.type == check.event and (not check.has("skill") or e.get("skill", 0) == check.skill)).size()
		elif check.get("kind", "unit") == "world":
			actual = lab.state().get(str(check.field))
		else:
			var actor = Units.find(lab.world, int(check.get("key", 0)))
			var snapshot: Dictionary = lab.inspect(int(actor.get("id", 0)))
			if check.has("skill"):
				for skill in snapshot.get("skills", []):
					if skill.id == check.skill: actual = skill.get(str(check.field))
			else:
				actual = snapshot
				for part in str(check.field).split("."):
					actual = actual.get(part) if actual is Dictionary else null
		var passed = false
		match check.get("op", "eq"):
			"eq": passed = actual == check.value
			"gte": passed = (actual is int or actual is float) and actual >= check.value
			"lte": passed = (actual is int or actual is float) and actual <= check.value
			"near": passed = (actual is int or actual is float) and absf(float(actual) - float(check.value)) <= float(check.get("tolerance", 0.01))
		test.assert_true(passed, "case check %s actual=%s" % [str(check), str(actual)])
	var result = {"title": value.get("title", ""), "state": lab.state(), "trace": lab.world.trace.duplicate(true), "trace_dropped": lab.world.trace_dropped}
	test.assert_true(lab.world.diagnostics.is_empty(), "case emits no missing-definition diagnostic")
	lab.dispose()
	return result
