# Implementation Plan

## Milestone 0 — Bootstrap and toolchain

Create the Godot project, configure Mobile/Jolt/landscape settings, install Android export requirements, and ship a test APK to the Redmi Note 14.

**Complete when:** the empty project opens, runs, exports, and installs on the device.

## Milestone 1 — Track data and compiler

Define `TrackDefinition`; implement draw sampling, normalization, smoothing, mesh/collision generation, bridges, checkpoints, minimap data, and safe boost candidates.

**Complete when:** curated and arbitrary valid drawings produce a drivable closed-loop road without CSG.

## Milestone 2 — Solo driving and time trial

Add auto-throttle, touch steering, Drift/Brake, one-charge boost, chase camera, checkpoints, timing, recovery, and best-lap ghost recording/playback.

**Complete when:** a player can finish and retry a time trial on curated and custom tracks.

## Milestone 3 — Circuit racing

Add start grid, lap count, 0–7 adaptive AI, soft bumps, shared pickup cooldown, positions, finish order, and race results.

**Complete when:** an eight-car five-lap race remains stable on difficult generated geometry.

## Milestone 4 — Product flow and persistence

Add featured home, track select, builder, preview, event setup, library, local saves, naming, records, share codes, and file import/export.

**Complete when:** a player can create, save, share, import, and race a track without developer tools.

## Milestone 5 — Content and polish

Add the four curated private-use replica definitions, environment presets, selected optimized assets, HUD polish, dust/VFX, and audio.

**Complete when:** every built-in track has its own recognizable stylized regional atmosphere and documented asset sources.

## Milestone 6 — Performance and APK acceptance

Run the test matrix, fix evidenced bottlenecks, validate imports, and produce the final sideloadable APK.

**Complete when:** the acceptance criteria in `TESTING.md` pass on the Redmi Note 14.
