class_name ProjectileDefinition
extends RefCounted

var definition_id: String = ""
var lifetime_ticks: int = -1
var movement_policy: String = "direct"
var collision_policy: String = "single_target"
var max_hits: int = 1
var pierce_count: int = 0
var bounce_count: int = 0
var on_impact_action_ids: Array[String] = []
var on_expire_action_ids: Array[String] = []
var cue_keys: Dictionary = {}


func _init(configured_definition_id: String = "", configured_lifetime_ticks: int = -1) -> void:
	definition_id = configured_definition_id
	lifetime_ticks = configured_lifetime_ticks


func validate() -> String:
	if definition_id.is_empty():
		return "projectile_definition_id_empty"
	if lifetime_ticks == 0 or lifetime_ticks < -1:
		return "projectile_lifetime_invalid"
	if max_hits < 1 or pierce_count < 0 or bounce_count < 0:
		return "projectile_collision_budget_invalid"
	if movement_policy.is_empty() or collision_policy.is_empty():
		return "projectile_policy_empty"
	return ""


func snapshot() -> Dictionary:
	return {
		"definition_id": definition_id,
		"lifetime_ticks": lifetime_ticks,
		"movement_policy": movement_policy,
		"collision_policy": collision_policy,
		"max_hits": max_hits,
		"pierce_count": pierce_count,
		"bounce_count": bounce_count,
		"on_impact_action_ids": on_impact_action_ids.duplicate(),
		"on_expire_action_ids": on_expire_action_ids.duplicate(),
		"cue_keys": cue_keys.duplicate(true),
	}
