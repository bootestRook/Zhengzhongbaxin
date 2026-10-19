extends SceneTree

const Support = preload("res://tests/test_support.gd")
const Suite = preload("res://tests/test_defense_gems.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test = Support.new()
	Suite.new().run(test)
	if test.failures.is_empty():
		print("[OK] gem scenario: %d assertions" % test.assertions)
		quit(0)
	else:
		for failure in test.failures:
			push_error("TEST FAILURE: %s" % failure)
		quit(1)
