# ADR-0001: Ability Graph authoring and runtime compilation

- Status: accepted
- Date: 2026-08-10
- Owner: framework_team

## Context

Combat Ability needs a visual behavior graph with stable node and pin identity, typed connections, editor layout, compile diagnostics, and runtime debugging. Encoding graph topology as CSV relation rows makes authoring and review fragile, while executing Godot GraphNode or mutable Resource instances would couple the domain runtime to the editor and shared Resource cache.

The project requires an ADR before introducing a new data format. It also forbids compatibility layers and parallel sources of truth.

## Decision

Ability Graph uses four separate representations:

1. A text Godot `AbilityGraphResource` is the canonical human-authored graph document. It will live under a Godot-imported `authoring/combat/ability_graphs/` root so it can be created and opened from the FileSystem dock.
2. An authoring adapter extracts an engine-neutral `AbilityGraphDefinition` from the Resource and validates stable node IDs, semantic pin IDs, typed configuration, connections, variables, and subgraph references.
3. The content pipeline compiles the graph into an immutable `AbilityExecutionPlanDefinition` stored with generated combat data. Runtime code consumes only this plan.
4. Each activation owns an `AbilityRun`; editor debugging receives a read-only execution snapshot.

Editor layout is stored in the authoring Resource but excluded from the gameplay fingerprint. Node type, configuration, connections, variable schema, entry points, compiler version, and required capabilities are included.

There is no CSV Timeline representation and no Resource/CSV synchronizer. When Resource authoring is introduced, any obsolete Timeline path is deleted in the same change. Authoring Resources and editor-only plugin code are excluded from release artifacts; generated plans are included.

E0 implemented the engine-neutral model, explicit registries, compiler, plan, and run fixtures. E1 now adds the Resource adapter and EditorPlugin only after those contracts pass headless tests.

This ADR does not change Save or RNG contracts. A future saved AbilityRun records plan fingerprint/version and explicit execution state, never the Resource or GraphNode layout.

## Alternatives

- **CSV nodes and connections**: rejected because topology, dynamic pins, comments, copy/paste, and small visual edits become difficult to author and review.
- **Resource executed directly at runtime**: rejected because mutable cached Resources, Godot editor types, and runtime state would be mixed.
- **Custom JSON graph source**: rejected for the first implementation because it loses Godot Inspector/FileSystem integration without reducing the need for a schema and compiler.
- **Use Orchestrator as the Ability runtime**: rejected because it introduces a general visual scripting language, compiler, third-party dependency, and much broader execution authority than Combat requires.
- **Keep the ordered Timeline first**: rejected because the target authoring model is already known to require event entries, typed data flow, owned waits, and visual runtime inspection.

## Consequences and risks

- The project gains one new authoring root and Resource type in E1; packaging and delivery allowlists must explicitly exclude it.
- Resource schema changes require versioned compiler diagnostics. Unknown node data must be preserved for repair rather than silently discarded.
- The compiler is a permanent boundary and must remain usable without the EditorPlugin.
- Stable semantic pin IDs become public data contracts; renaming or changing their type is breaking.
- Generated plans add build work but remove editor/UI dependencies and repeated graph interpretation from runtime.
- There is no migration burden today because no Combat Timeline implementation or content exists.

## Verification

- Headless tests compile and execute `OnCast → Action → End` without SceneTree or EditorPlugin.
- Tests reject duplicate node IDs, unknown node/action types, bad pins, missing connections, unreachable nodes, and cycles.
- A two-Action graph proves that a later rejection restores the outer Action snapshot.
- The compiler produces deterministic operation order for identical input.
- Architecture lint confirms Combat domain code has no Node, SceneTree, app, or presentation dependency.
- `python tools/project.py check` remains green.

E1 verification is now covered by Resource save/load round-trip, stable semantic IDs, Editor Undo/Redo, copy/paste remapping, headless editor import, runtime GraphEdit smoke, debug snapshot transport, disabled-plugin runtime tests, and release-artifact exclusion of `authoring/` and `addons/`. Later slices add typed value routes, bounded control cycles, wait tokens, explicit TargetResolver and module action registries without changing the canonical Resource format.

## Rollback and re-evaluation

Before E1 content exists, rollback deletes the graph kernel and this ADR. After graph content exists, a different authoring format requires a replacement ADR and a one-time explicit source conversion; the old writer and reader are removed in the same change.

Reopen this decision only if Godot Resource text serialization cannot provide deterministic source control behavior, or if the project replaces its complete source-data pipeline with another canonical system.
