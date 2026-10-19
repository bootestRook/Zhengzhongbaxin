class_name TestSupport
extends RefCounted

var assertions: int = 0
var failures: Array[String] = []


func assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s: expected=%s actual=%s" % [message, expected, actual])


func assert_not_empty(value: Variant, message: String) -> void:
	assertions += 1
	if value == null or (value is String and value.is_empty()) or (value is Dictionary and value.is_empty()) or (value is Array and value.is_empty()):
		failures.append(message)
