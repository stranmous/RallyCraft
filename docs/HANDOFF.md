# RallyCraft Handoff

## Current state

RallyCraft 3D is an offline, Android-only Godot 4.6.2 arcade-racing project. PC is currently used only for development validation; do not claim Android performance or release acceptance without a Redmi Note 14 pass.

Milestones completed: bootstrap, versioned track data/local storage, drawing normalization and preview data, procedural road/curbs/bridges/collision, checkpoints/start grid/minimap/boost anchors, solo driving, race state/recovery/contact, Circuit Race/Time Trial results, best-lap ghost persistence/replay, curvature-led AI with bounded pace adaptation/recovery, full 0–7 AI opponents and 1–5 laps support, shared 8-second boost pickup pads, the viewport-adaptive BBR2-style touch HUD and Event Setup, Home/Select/Create/Library/Records screens with share-code and `.rallycraft` export/import, curated circuits (Spa, Red Bull Ring, Monza, Silverstone), external licensed 3D/texture/VFX/UI/audio asset pipeline, and all six procedural `BiomePresets` + `CarVfxController` integration.

## Run and validate

- Run full automated test suite: `.\run_tests.ps1` (uses `Godot_v4.6.2-stable_win64_console.exe`, `17 / 17` tests passing).
- Run desktop windowed verification scenarios: `.\run_scenario.ps1 -All` (`8 / 8` scenarios passing with rendered `contact_sheet.png` captures).
- Android verification checklist:
  - Export debug APK: `& "C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --export-debug "Android ARM64 Debug" build/RallyCraft3D-debug.apk`
  - Verify signature: `& "C:\Users\Waqas\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat" verify --verbose build/RallyCraft3D-debug.apk`
  - Install: `adb install -r build/RallyCraft3D-debug.apk`
  - Launch: `adb shell am force-stop com.waqas.rallycraft3d ; adb shell am start -n com.waqas.rallycraft3d/com.godot.game.GodotAppLauncher`
  - Performance: `adb shell dumpsys gfxinfo com.waqas.rallycraft3d`
- PC run: `C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64.exe --path .` (press F1 in race preview for live AI telemetry overlay).
- Headless editor validation: `C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --editor --quit`
- Individual tests: `C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/<name>.gd`.

## Important boundaries

- Keep Android as the shipping platform: landscape, Mobile renderer, Jolt, ARM64, no network/accounts/analytics/cloud.
- `TrackDefinition` is the single versioned format for curated and custom tracks.
- `TrackCompiler` owns generated road/collision/checkpoints/grid/minimap/boost data; UI must not generate track geometry.
- `BiomePresets` owns the 6 theme skies/lighting/fog/scenery layouts and instanced `MultiMeshInstance3D` nodes shared between live races (`MainController`) and 3D previews (`TrackPreviewWidget`).
- `RaceManager` owns player race state, multi-car tracking, and dynamic leaderboard rankings (`P%d/%d`).
- `AIDriver` owns AI steering, curvature pace, lap adaptation, and AI recovery.
- Node3D references in headless scripts/tests: `_get_car_position()` falls back to local `transform.origin` if `!is_inside_tree()`.
- GDScript closures: value types (int/float/bool/string) are copied on capture. Shared reactive mutable state in UI lambdas must use Dictionaries or Objects.
- Keep generated roads as meshes plus explicit static collision. Do not introduce production CSG roads.
- Records and ghosts are local-only under `user://records/`.

## Primary files

- `scripts/track/track_compiler.gd` — procedural track compilation and road/curb/bridge materials.
- `scripts/track/biome_presets.gd` — 6 biome environment presets, horizon rings, zero-collider MultiMesh trackside/nature scattering.
- `scripts/assets/asset_registry.gd` — cached licensed models, materials, VFX textures, SVG icons, and audio streams.
- `scripts/racing/rally_car.gd`, `rally_drive_model.gd`, and `car_vfx_controller.gd` — player/AI car motion and mobile-budget particle VFX (dust, boost, sparks).
- `scripts/racing/race_audio_controller.gd` — engine RPM pitch, tire skid crossfade, boost/impact/countdown/lap audio and music routing.
- `scripts/racing/race_manager.gd` — player lap/checkpoint/recovery/results, multi-racer tracking, and live ranking.
- `scripts/racing/ai_driver.gd` — route-following, curvature braking, bounded lap-to-lap pace adjustment, AI recovery.
- `scripts/data/record_store.gd`, `scripts/racing/ghost_recorder.gd`, `ghost_playback.gd` — Time Trial ghost path and best lap/race records.
- `scripts/ui/event_setup_panel.gd`, `track_preview_widget.gd`, `track_select_panel.gd`, `library_records_panel.gd` — navigation screens, 2D/3D previews, and library/share/import UI.
- `scripts/ui/race_input_hud.gd` and `scripts/ui/race_minimap.gd` — BBR2-style viewport-adaptive touch HUD.
- `scripts/main_controller.gd` — Navigation shell, Event Setup integration, 6-biome Track Builder UI, multi-car race preview spawner, F1 telemetry overlay.

## Known limitations and next work

All Task 5.4 biome presets and car VFX are desktop-verified (`17 / 17` tests, `8 / 8` windowed scenarios). Live Redmi Note 14 60 FPS device profiling with 8 active cars and audible speaker balance check remain to be executed on attached hardware.

Next unchecked tasks (Milestone 6 — Validation and APK delivery):
1. Add automated data/compiler tests and manual race regression checklist completion.
2. Profile curated and complex custom tracks on the Redmi Note 14 (`adb shell dumpsys gfxinfo`).
3. Produce and install the final sideloadable ARM64 APK.

Review `docs/AGENTS.md`, `docs/PRD.md`, `docs/TECHNICAL_PLAN.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/TASKS.md`, `docs/DATA_MODEL.md`, and `docs/TESTING.md` before making changes.
