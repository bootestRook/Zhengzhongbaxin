extends RefCounted

const ActionExecutorScript = preload("res://src/runtime/action_executor.gd")
const ActionResultScript = preload("res://src/runtime/action_result.gd")
const DataRegistryScript = preload("res://src/data/data_registry.gd")
const RngSetScript = preload("res://src/foundation/rng_set.gd")
const SampleFeatureScript = preload("res://src/features/sample_interaction/domain/sample_feature.gd")


class FakeContext extends RefCounted:
	var value: int = 3

	func snapshot_state() -> Dictionary:
		return {"value": value}

	func restore_state(snapshot: Dictionary) -> String:
		value = int(snapshot.value)
		return ""


class FailingAtomicAction extends RefCounted:
	func action_id() -> String:
		return "test.failing_atomic"

	func atomicity() -> String:
		return "atomic"

	func validate(_context: RefCounted) -> String:
		return ""

	func execute(context: RefCounted):
		context.value = 99
		return ActionResultScript.rejected("intentional_failure")


func run(test: TestSupport) -> void:
	var data = DataRegistryScript.new()
	test.assert_equal(data.load_default(), "", "feature data must load")
	var first = SampleFeatureScript.new(data, RngSetScript.new(42))
	var second = SampleFeatureScript.new(data, RngSetScript.new(42))
	for index in range(4):
		var first_result = first.submit_increment_intent()
		var second_result = second.submit_increment_intent()
		test.assert_true(first_result.accepted, "sample intent should be accepted: %s" % first_result.error_code)
		test.assert_equal(first.snapshot(), second.snapshot(), "feature result must replay with same seed")
	test.assert_true(first.action_trace().size() == 4, "executor must record action trace: %s" % [first.action_trace()])

	var executor = ActionExecutorScript.new()
	var context := FakeContext.new()
	var failed = executor.execute(FailingAtomicAction.new(), context)
	test.assert_true(not failed.accepted, "failing action must be rejected")
	test.assert_equal(context.value, 3, "atomic action must roll back state")
