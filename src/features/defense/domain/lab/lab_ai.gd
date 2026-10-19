extends "res://src/features/defense/domain/defense_ai.gd"

func move(unit: Dictionary, destination: Vector2, face_destination: bool = true, path: bool = true) -> void:
	if w.allowed(unit, "move"):
		super.move(unit, destination, face_destination, path)
	else:
		set_action(unit, "idle")

func forced_move(unit: Dictionary) -> bool:
	return super.forced_move(unit) if w.allowed(unit, "move") else false

func attack(unit: Dictionary, target: Dictionary) -> void:
	if w.allowed(unit, "attack"):
		super.attack(unit, target)
	else:
		set_action(unit, "idle")

func emit_attack(unit: Dictionary, event: Dictionary) -> void:
	if w.allowed(unit, "attack"):
		w.record("attack", {"source": unit.id, "target": event.target, "wall": event.wall})
		super.emit_attack(unit, event)
