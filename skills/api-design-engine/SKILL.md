---
name: api-design-engine
description: Design and review engine subsystem interfaces -- component vs service, ownership models, thread affinity, extensibility. TRIGGER when the user says "design a new subsystem", "should this be a component or a service", "how should the audio engine expose", "who owns this", "what thread runs this", "public API for the physics module", "plugin interface", "hot reload boundary". DO NOT TRIGGER for pure implementation questions or one-off utility class design. Focused on architectural decisions -- thread affinity annotations, ownership arrows, hot-reload boundaries, and the component-vs-service tradeoff.
---

# api-design-engine

## Component vs service
**Component**: data on entities, queried by systems. Cheap. `Mesh`, `Material`, `Transform`, `Health`, `InputController`.

**Service**: singleton-ish, coarse-grained, owns background threads/resources. `AudioService`, `AssetLoader`, `PhysicsWorld`.

Rule of thumb: service manages *lifecycle* of a resource; components hold *references*.

## Ownership arrows
`unique_ptr` = single owner. `shared_ptr` = multiple (rare in engine). Raw = reference (must outlive access). Two subsystems both wanting to own the same thing -> introduce resource system OR one is wrong.

## Thread affinity
Annotate every public method:
- `// [render thread]`
- `// [game thread]`
- `// [any thread, thread-safe]`
- `// [any thread, atomic]`
- `// [async safe]`

Enforce with `ENGINE_ASSERT_THREAD(RenderThread)` first line. Debug catch = fast diagnosis.

## Hot-reload boundary
Hot-reloadable subsystem must have:
- No stored vtable references across boundary.
- Clean shutdown-releases-resources semantics.
- No pinned globals in reloaded module.

Non-hot-reloadable? Say so on the API: `// non-hot-reloadable`.

## Extensibility
Inversion of control: subsystem exposes hooks; extensions register with subsystem, not vice versa. Shallow deps.

## Backwards compat
Public tagged interfaces = source-stable. Internal = break freely.

## Method
1. Sketch smallest possible interface.
2. Enumerate callers.
3. Annotate thread affinity per method.
4. Draw ownership graph. Cycle -> redesign.
5. "What breaks if hot-reloaded?" test.

## the engine convention
- Public: `include/engine/<subsystem>/`.
- Internal: `src/<subsystem>/internal/`.
- Factory returns `unique_ptr<ISubsystem>`; concrete types opaque.
- Config = struct passed to factory. No globals.