class_name CoreEventPipelineResult
extends RefCounted

var accepted: bool = false
var error_code: String = ""
var events: Array[RefCounted] = []
var trace: Array[Dictionary] = []
var processed_requests: int = 0


static func success(
	committed_events: Array[RefCounted],
	processed_count: int,
	trace_entries: Array[Dictionary]
) -> CoreEventPipelineResult:
	var result := CoreEventPipelineResult.new()
	result.accepted = true
	result.events = committed_events.duplicate()
	result.processed_requests = processed_count
	result.trace = trace_entries.duplicate(true)
	return result


static func rejected(
	code: String,
	processed_count: int,
	trace_entries: Array[Dictionary]
) -> CoreEventPipelineResult:
	var result := CoreEventPipelineResult.new()
	result.error_code = code
	result.processed_requests = processed_count
	result.trace = trace_entries.duplicate(true)
	return result
