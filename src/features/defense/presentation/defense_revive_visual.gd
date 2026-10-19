class_name DefenseReviveVisual
extends Control

var field: DefenseField

func _draw() -> void:
	if field == null or field.atlas == null or field.snapshot.get("phase", "home") == "home":
		return
	for effect in field.snapshot.get("visuals", []):
		if effect.kind == "revive":
			field.atlas.draw(self, effect.res, field.world(effect.pos), Vector2.ONE * effect.scale,
				field.snapshot.time - effect.start, effect.pivot, Color.WHITE, 0, false)
