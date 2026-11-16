# Architecture

## System boundary

RallyCraft is a single-device Godot game. The app owns all gameplay, local persistence, rendering, and sharing. Android only provides file selection, text sharing, file sharing, and APK installation. No server or online service is part of the design.

## Runtime flow

```text
Home / Track Select
  -> TrackDefinition
  -> Track Compiler
  -> Road + collision + checkpoints + boost points + theme props
  -> Event setup
  -> Race manager
  -> Results / records / optional ghost update
```

The same `TrackDefinition` path is used for curated tracks and player-created tracks. Curated content provides hand-authored control points and environment metadata; custom content provides normalized drawing points and player-selected settings.

## Major modules

| Module | Owns | Must not own |
| --- | --- | --- |
| Game flow | screen transitions and selected event | physics or persistence details |
| Track compiler | smoothing, mesh, collision, bridges, checkpoints, minimap, pickup candidates | UI state |
| Theme system | terrain palette, lighting, instanced props, road material selection | track geometry |
| Car controller | input-to-motion, drift/brake, boost, visual body | lap rules or UI |
| Race manager | grid, countdown, laps, positions, recovery, results | mesh generation |
| AI driver | racing line, curvature targets, adaptation, AI recovery | player input |
| Library and sharing | local tracks, records, ghost files, validated imports/exports | race-time physics |
| HUD | touch actions and presentation | business rules |

## Road and collision

The compiler samples normalized control points into a closed centerline. It derives tangents, road cross-sections, UVs, bank values, checkpoint intervals, and safe pickup zones. It builds an `ArrayMesh`/`SurfaceTool` render surface and separate static collision. Self-crossings create a bridge elevation segment when clearance is possible. Invalid or extreme drawings are retained but smoothed to enforce practical spacing and turn radius, with a visible optimization notice.

## Data and storage

- `res://`: code, built-in track definitions, and packaged assets.
- `user://tracks/`: saved custom tracks.
- `user://records/`: best lap/race records and ghost samples.
- `user://imports/`: temporary import staging only; remove after validation or cancellation.

Portable payloads are versioned, size-limited, and validated before they become local tracks. Details are in [DATA_MODEL.md](DATA_MODEL.md).

## Performance boundary

The target is stable 60 FPS on a Redmi Note 14 in an eight-car event. Roads, props, and signs must be batched or instanced; effects must have fixed budgets; the chase camera must cull distant geometry. Profile before raising mesh density, shadow distance, vehicle count, texture resolution, or effect count.
