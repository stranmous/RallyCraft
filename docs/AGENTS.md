# RallyCraft 3D Agent Guide

## Project status

This repository is documentation-first. Do not begin a gameplay milestone until the relevant item in `TASKS.md` is active and its acceptance criteria are understood.

`claude.md` is an early blueprint. The product and technical documents in this repository override it where they conflict.

## Commands

- Editor: `C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64.exe --editor project.godot`
- Headless validation after a project exists: `godot --headless --path . --editor --quit`
- Run after a project exists: `godot --path . --editor`
- Android export prerequisites are recorded in `ENV.md`.

## Architecture constraints

- Target Godot 4.6.2, GDScript, Mobile renderer, and Jolt Physics.
- Target Android landscape and a sideloadable ARM64 APK; no network, accounts, analytics, or cloud dependencies.
- Use minimal root scenes and procedural runtime composition where it prevents fragile scene-resource coupling.
- Generate production roads as meshes plus explicit static collision. Do not use `CSGPolygon3D` as the final road implementation.
- Keep curated and player-created tracks in the same versioned track-data format and compile them through the same pipeline.
- Prefer low-poly, instanced, Android-ready assets. Record every external asset before importing it.
- Keep real-track material educational/private only; do not add official logos or branding.

## Coding conventions

- Use Godot 4 syntax and typed GDScript where practical.
- Prefer small single-purpose scripts and explicit data objects over large controller scripts.
- Name signals as completed events (`track_compiled`, `race_finished`).
- Keep UI input state separate from driving, AI, persistence, and rendering code.
- Validate imported track data before creating meshes, collision, or saved records.

## Verification

- Run headless validation after project-setting or script changes.
- Test each gameplay change in editor before Android export.
- Test save/import changes with malformed data, an empty library, and a valid round trip.
- Do not claim 60 FPS until profiled on the Redmi Note 14 using the scenarios in `TESTING.md`.

## Documentation policy

- Keep documents concise and factual; update the document that owns a changed decision in the same task.
- `TASKS.md` is the current ordered backlog. `PRD.md` owns player-visible requirements. `ARCHITECTURE.md` owns system boundaries.
- Do not create API, authorization, security, or changelog documents unless the project scope changes to warrant them.
