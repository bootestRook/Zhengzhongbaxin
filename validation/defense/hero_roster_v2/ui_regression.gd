extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var test = preload("res://tests/test_support.gd").new()
 await preload("res://tests/test_defense_choice_skill_ui.gd").new().run(test,self)
 await preload("res://tests/test_defense_hero_roster_ui.gd").new().run(test,self)
 for failure in test.failures: push_error("TEST FAILURE: " + failure)
 print("[UI REGRESSION] assertions=%d failures=%d" % [test.assertions,test.failures.size()])
 quit(0 if test.failures.is_empty() else 1)
