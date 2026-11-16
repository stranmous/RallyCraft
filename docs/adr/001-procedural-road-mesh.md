# ADR 001: Use Generated Road Meshes Instead of CSG Roads

## Status

Accepted.

## Context

The early blueprint proposes `CSGPolygon3D` path extrusion for generated roads. RallyCraft must support arbitrary user drawings, bridge crossings, editable track settings, static collision, eight-car races, multi-biome scenery, and a 60-FPS target on a Redmi Note 14.

## Decision

Generate the final road, curbs, and bridge geometry from sampled track data using `ArrayMesh` or `SurfaceTool`, then create explicit static collision. Treat CSG only as an optional temporary diagnostic/prototype technique, never as production geometry.

## Consequences

- More initial geometry engineering is required.
- The compiler gains deterministic control over topology, UVs, vertex density, collision, and bridge segments.
- Meshes can be profiled and optimized without CSG rebuild overhead.
- Curated and custom tracks share one path to production geometry.
- Future texture/material and theme changes stay independent of track definition data.
