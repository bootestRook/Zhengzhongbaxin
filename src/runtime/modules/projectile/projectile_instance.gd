class_name ProjectileInstance
extends RefCounted

var projectile_id: String = ""
var definition_id: String = ""
var source_entity_id: String = ""
var target_entity_id: String = ""
var spawned_tick: int = 0
var current_tick: int = 0
var expires_tick: int = -1
var state: String = "active"
var observation_sequence: int = 0
var hit_count: int = 0


func snapshot() -> Dictionary:
	return {
		"projectile_id": projectile_id,
		"definition_id": definition_id,
		"source_entity_id": source_entity_id,
		"target_entity_id": target_entity_id,
		"spawned_tick": spawned_tick,
		"current_tick": current_tick,
		"expires_tick": expires_tick,
		"state": state,
		"observation_sequence": observation_sequence,
		"hit_count": hit_count,
	}
