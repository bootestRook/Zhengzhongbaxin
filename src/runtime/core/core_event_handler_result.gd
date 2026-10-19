class_name CoreEventHandlerResult
extends RefCounted

const CONTINUE := "continue"
const REPLACE := "replace"
const REJECT := "reject"
const COMMIT := "commit"
const ENQUEUE := "enqueue"

var kind: String = CONTINUE
var error_code: String = ""
var relay: Dictionary = {}
var facts: Array[RefCounted] = []
var requests: Array[RefCounted] = []


static func continue_result() -> CoreEventHandlerResult:
	return CoreEventHandlerResult.new()


static func replace_result(next_relay: Dictionary) -> CoreEventHandlerResult:
	var result := CoreEventHandlerResult.new()
	result.kind = REPLACE
	result.relay = next_relay.duplicate(true)
	return result


static func reject_result(code: String) -> CoreEventHandlerResult:
	var result := CoreEventHandlerResult.new()
	result.kind = REJECT
	result.error_code = code
	return result


static func commit_result(committed_facts: Array[RefCounted]) -> CoreEventHandlerResult:
	var result := CoreEventHandlerResult.new()
	result.kind = COMMIT
	result.facts = committed_facts.duplicate()
	return result


static func enqueue_result(next_requests: Array[RefCounted]) -> CoreEventHandlerResult:
	var result := CoreEventHandlerResult.new()
	result.kind = ENQUEUE
	result.requests = next_requests.duplicate()
	return result
