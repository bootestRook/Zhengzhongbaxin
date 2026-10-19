extends RefCounted

const RngSetScript = preload("res://src/foundation/rng_set.gd")


func run(test: TestSupport) -> void:
	var first = RngSetScript.new(90210)
	var second = RngSetScript.new(90210)
	var first_values: Array = []
	var second_values: Array = []
	for index in range(8):
		first_values.append(first.stream("gameplay").next_int(10000))
		second_values.append(second.stream("gameplay").next_int(10000))
	test.assert_equal(first_values, second_values, "same seed and stream must replay")

	var isolated = RngSetScript.new(90210)
	isolated.stream("presentation").next_int(10000)
	var gameplay_after_presentation: int = isolated.stream("gameplay").next_int(10000)
	var untouched_gameplay: int = RngSetScript.new(90210).stream("gameplay").next_int(10000)
	test.assert_equal(gameplay_after_presentation, untouched_gameplay, "named streams must be isolated")

	var snapshot_source = RngSetScript.new(77)
	snapshot_source.stream("world").next_int(100)
	var snapshot: Dictionary = snapshot_source.snapshot()
	var expected_next: int = snapshot_source.stream("world").next_int(100)
	var restored = RngSetScript.new(1)
	test.assert_equal(restored.restore(snapshot), "", "RNG snapshot must restore")
	test.assert_equal(restored.stream("world").next_int(100), expected_next, "restored RNG must continue exactly")
