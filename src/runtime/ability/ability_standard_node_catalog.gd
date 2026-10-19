class_name AbilityStandardNodeCatalog
extends RefCounted

const NodeDescriptorScript = preload("res://src/runtime/ability/ability_node_descriptor.gd")
const PinDescriptorScript = preload("res://src/runtime/ability/ability_pin_descriptor.gd")


static func register_all(registry: RefCounted) -> void:
	_register_event_nodes(registry)
	_register_action_nodes(registry)
	_register_logic_nodes(registry)
	_register_data_nodes(registry)


static func _register_event_nodes(registry: RefCounted) -> void:
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_cast", "entry", [], ["then"], true, false,
		"Event", "On Cast", ["cast", "activate", "entry"], "Ability activation entry point.", [], [],
		"ability.cast"
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_hit", "entry", [], ["then"], true, false,
		"Event", "On Hit", ["hit", "damage", "impact"], "Committed hit event entry point.", [], [],
		"hit.resolved"
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_projectile_impact", "entry", [], ["then"], true, false,
		"Event", "On Projectile Impact", ["impact", "projectile", "missile"], "Projectile contact/impact fact entry point.", [], [],
		"projectile.impact"
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_hit_resolved", "entry", [], ["then"], true, false,
		"Event", "On Hit Resolved", ["hit", "dodge", "block", "miss"], "Gameplay hit resolution fact entry point.", [], [],
		"hit.resolved"
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_damage_applied", "entry", [], ["then"], true, false,
		"Event", "On Damage Applied", ["damage", "health", "outcome"], "Committed damage outcome entry point.", [], [],
		"damage.applied"
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_kill", "entry", [], ["then"], true, false,
		"Event", "On Kill", ["kill", "defeat"], "Committed kill event entry point.", [], [],
		"entity.defeated"
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.event.on_expire", "entry", [], ["then"], true, false,
		"Event", "On Expire", ["expire", "effect", "duration"], "Committed expiration event entry point.", [], [],
		"effect.expired"
	))


static func _register_action_nodes(registry: RefCounted) -> void:
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.action.deal_damage", "action", ["in", "targets", "amount"], ["then"], false, false,
		"Action", "Deal Damage", ["damage", "health", "hit"],
		"Submit a damage request to the active Event Pipeline.",
		[PinDescriptorScript.control("in"), PinDescriptorScript.value("targets", "entity_ids", "", "run", false, "many"), PinDescriptorScript.value("amount", "number", "damage", "run", false)],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.action.apply_effect", "action", ["in", "targets", "effect_id"], ["then"], false, false,
		"Action", "Apply Effect", ["buff", "debuff", "effect"],
		"Create a stable Effect instance owned by the target Entity.",
		[PinDescriptorScript.control("in"), PinDescriptorScript.value("targets", "entity_ids", "", "run", false, "many"), PinDescriptorScript.value("effect_id", "effect_id", "", "run", false)],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.target.select", "action", ["in"], ["then", "targets"], false, false,
		"Target", "Select Target", ["target", "query", "filter"],
		"Resolve stable Entity IDs through the injected Target resolver.", [],
		[PinDescriptorScript.control("then"), PinDescriptorScript.value("targets", "entity_ids", "", "run", false, "many")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.presentation.emit_cue", "action", ["in"], ["then"], false, false,
		"Presentation", "Emit Cue", ["animation", "vfx", "sfx", "cue"],
		"Request presentation from a committed domain fact.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.action.execute", "action", ["in"], ["then"], false, false,
		"Action", "Execute Action", ["action", "command", "effect"],
		"Resolve and execute a registered atomic Action."
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.action.spawn_projectile", "action", ["in", "targets"], ["then"], false, false,
		"Action", "Spawn Projectile", ["projectile", "launch", "missile"],
		"Create a domain projectile instance through the Projectile Module.",
		[PinDescriptorScript.control("in"), PinDescriptorScript.value("targets", "entity_ids", "", "run", false, "many")],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.action.move", "action", ["in"], ["then"], false, false,
		"Action", "Move", ["move", "knockback", "teleport"],
		"Submit a movement request to the Movement Module.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.action.summon", "action", ["in"], ["then"], false, false,
		"Action", "Summon", ["summon", "spawn", "entity"],
		"Create a domain entity through the Summon Module factory port.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.target.area_query", "action", ["in"], ["then", "targets"], false, false,
		"Target", "Area Query", ["area", "query", "observation"],
		"Validate an Area observation and return stable entity IDs.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then"), PinDescriptorScript.value("targets", "entity_ids", "", "run", false, "many")]
	))


static func _register_logic_nodes(registry: RefCounted) -> void:
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.branch", "branch", ["in", "condition"], ["true", "false"], false, false,
		"Logic", "Branch", ["if", "condition", "logic"],
		"Choose one deterministic control route from a boolean condition.",
		[PinDescriptorScript.control("in"), PinDescriptorScript.value("condition", "bool", "", "run", false)],
		[PinDescriptorScript.control("true"), PinDescriptorScript.control("false")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.delay", "delay", ["in"], ["then"], false, false,
		"Logic", "Delay", ["delay", "tick", "wait"],
		"Suspend the run for a bounded number of logical ticks.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.wait_event", "wait", ["in"], ["resumed", "timeout"], false, false,
		"Logic", "Wait Event", ["wait", "event", "resume"],
		"Suspend the run until a committed event matches its typed event key.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("resumed"), PinDescriptorScript.control("timeout", false)]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.repeat", "repeat", ["in", "continue"], ["body", "done"], false, false,
		"Logic", "Repeat", ["repeat", "bounded", "loop"],
		"Execute a statically bounded body count without implicit infinite loops.", [PinDescriptorScript.control("in"), PinDescriptorScript.control("continue")],
		[PinDescriptorScript.control("body"), PinDescriptorScript.control("done")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.subgraph_call", "subgraph", ["in"], ["then"], false, false,
		"Logic", "Subgraph Call", ["subgraph", "compose", "reuse"],
		"Call a declared owned subgraph; parent execution waits for child ticks/events and propagates cancellation.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then")]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.sequence", "sequence", ["in"], ["then"], false, false,
		"Logic", "Sequence", ["flow", "sequence", "control"],
		"Pass control to the next node without mutating combat state."
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.logic.end", "end", ["in"], [], false, true,
		"Logic", "End Ability", ["finish", "success", "terminal"],
		"Finish the current AbilityRun."
	))


static func _register_data_nodes(registry: RefCounted) -> void:
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.data.read_attribute", "value", ["in"], ["then", "value"], false, false,
		"Data", "Read Attribute", ["attribute", "value", "data"],
		"Read a numeric Attribute from the current source or target snapshot.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then"), PinDescriptorScript.value("value", "number", "", "run", false)]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.data.read_variable", "value", ["in"], ["then", "value"], false, false,
		"Data", "Read Variable", ["variable", "local", "value"],
		"Read a typed local variable owned by the current AbilityRun.", [PinDescriptorScript.control("in")],
		[PinDescriptorScript.control("then"), PinDescriptorScript.value("value", "number", "", "run", false)]
	))
	registry.register_descriptor(NodeDescriptorScript.new(
		"combat.ability.data.write_variable", "variable_set", ["in", "value"], ["then"], false, false,
		"Data", "Write Variable", ["variable", "local", "set"],
		"Write a local variable without mutating CombatState.",
		[PinDescriptorScript.control("in"), PinDescriptorScript.value("value", "number", "", "run", false)],
		[PinDescriptorScript.control("then")]
	))
