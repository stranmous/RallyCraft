# Technical Plan

## Platform baseline

- Godot 4.6.2 stable, GDScript, Mobile renderer, Jolt Physics.
- Landscape Android ARM64 APK; private sideloading only.
- Use Godot 4.6 APIs. Jolt is the default 3D physics engine for new Godot 4.6 projects. [Godot 4.6 ProjectSettings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html)

## Core interfaces

| Concept | Required data/behavior |
| --- | --- |
| `TrackDefinition` | format version, ID, name, source, centerline points, elevation profile, width preset, surface, theme, metadata |
| `TrackCompiler` | validates/normalizes a definition and returns render mesh, collision, checkpoints, minimap data, AI route, bridge spans, and pickup anchors |
| `RaceEvent` | selected track, mode, lap count, AI count, start-grid state, timers, finish state |
| `CarState` | transform, velocity, heading, checkpoint index, boost charge, recovery state, player/AI role |
| `RecordStore` | one best lap, one best race, and one ghost per track ID |
| `ShareCodec` | versioned encode/decode, payload-size limits, schema checks, and import-preview result |

## Track pipeline

1. Receive curated points or sampled touch points.
2. Normalize coordinates, close the loop, remove near-duplicates, and enforce spacing/turn constraints.
3. Detect viable crossings and add bridge elevation; report any automatic optimization.
4. Sample the spline into a centerline with tangent, normal, curvature, slope, banking, and distance values.
5. Create road render mesh, curbs, bridge mesh, and independent static collision.
6. Derive start grid, checkpoints, safe boost anchors, AI look-ahead route, minimap polyline, and scenery placement zones.

`CSGPolygon3D` is excluded from the production path. Generated meshes give control over vertex density, collision, batching, bridge handling, and mobile profiling. Godot supports direct procedural mesh creation with `ArrayMesh` and `SurfaceTool`. [ArrayMesh documentation](https://docs.godotengine.org/en/4.6/tutorials/3d/procedural_geometry/arraymesh.html)

## Race systems

- The player controller converts touch state into auto-throttle, steering, combined drift/brake, and manual boost.
- AI uses the generated route and curvature look-ahead. Per-lap adaptation only changes bounded pace/braking targets; it does not persist telemetry histories.
- Soft bumps use clamped horizontal impulses and separation. Vertical launch, uncontrolled torque, and prolonged contact are suppressed.
- Recovery watches valid-route distance, orientation, and low speed. After 3 seconds of failed progress, reset at the last confirmed checkpoint.
- Boost pickup state is shared across racers. One charge maximum; global respawn after 8 seconds; activation applies a fixed 1.2-second speed burst.

## Persistence and sharing

- Store custom tracks and records under `user://` with atomic write/replace behavior.
- Curated track definitions are read-only packaged resources.
- Export a compact versioned track payload as text and as `.rallycraft` JSON-compatible data.
- Parse imports into an isolated candidate object, enforce limits, preview it, then save a new local copy only after player confirmation.

## Android readiness

The existing Android SDK must be paired with OpenJDK 17 and matching Godot 4.6.2 export templates. Godot's documented Android export setup requires the Java SDK path and Android SDK path in Editor Settings. [Godot Android export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)

## Performance budget

- Acceptance target: stable 60 FPS on Redmi Note 14 with eight cars.
- Limit active rigid bodies to racers and essential dynamic pickups.
- Instance vegetation, rocks, signs, and repeated barriers.
- Use bounded draw distance, low-overdraw particles, compressed textures, shared materials, and theme-specific prop budgets.
- Profile curated Spa and a complex bridged custom track before increasing visual density.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Extreme drawings create bad roads | normalize/smooth, retain source sketch, show optimization notice |
| AI jams on narrow tracks | safe route offsets, capped contact force, recovery, bounded AI count |
| Multi-biome assets exceed budget | theme budgets, instancing, selective assets, device profiling |
| Imported payload is malformed | version/schema/size validation before runtime compilation |
| Android export is incomplete | verify templates, JDK, SDK, and a hello-world APK before feature development |
