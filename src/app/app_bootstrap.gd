class_name AppBootstrap
extends Node

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
var boot_error: String = ""
var session
var accumulator: float = 0
var _catalog

func _ready() -> void:
	_catalog = Catalog.new()
	boot_error = _catalog.load_default()
	if not boot_error.is_empty():
		push_error(boot_error)
		return
	session = Session.new(_catalog)
	$DefenseView.configure(_catalog)
	$DefenseAudio.configure(_catalog.art())
	$DefenseView.intent_requested.connect(submit)
	$DefenseView.render(session.snapshot())

func is_ready_for_use() -> bool:
	return boot_error.is_empty() and session != null

func battle_snapshot() -> Dictionary:
	return session.snapshot() if session != null else {}

func submit(intent: String, payload: Dictionary = {}) -> void:
	if intent == "start" and not payload.has("seed"):
		payload = payload.duplicate()
		payload["seed"] = maxi(1, int(Crypto.new().generate_random_bytes(4).decode_u32(0) & 0x7fffffff))
	var error: String = session.submit(intent, payload)
	if not error.is_empty():
		$DefenseView.show_notice(error)
	accumulator = 0
	$DefenseView.render(session.snapshot())

func _process(delta: float) -> void:
	if session == null:
		return
	if session.phase == "playing" and not session.paused:
		accumulator += minf(delta, 0.25) * session.speed
		while accumulator >= 0.016:
			session.step()
			accumulator -= 0.016
			if session.phase != "playing":
				accumulator = 0
				break
	else:
		accumulator = 0
	var snapshot = session.snapshot()
	$DefenseView.render(snapshot)
	$DefenseAudio.update(snapshot, session.drain_events())

func _exit_tree() -> void:
	if session != null:
		session.dispose()
