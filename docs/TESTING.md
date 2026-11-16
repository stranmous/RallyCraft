# Testing Plan

## Automated checks

- Run `.\run_tests.ps1` to execute the full suite with `Godot_v4.6.2-stable_win64_console.exe`.
- Run `godot --headless --path . --script res://tests/track_storage_test.gd` for the versioned track-data and local-storage round trip.
- Run `godot --headless --path . --script res://tests/track_path_processor_test.gd` for drawing normalization, smoothing, closure, and preview data.
- Run `godot --headless --path . --script res://tests/track_compiler_test.gd` for procedural road/curb meshes, Catmull-Rom resampling, bridge detection, static collision, checkpoints, start grid, minimap data, and safe boost anchors.
- Run `godot --headless --path . --script res://tests/rally_drive_model_test.gd` for auto-throttle, drift/brake slowdown, one-charge boost activation, and the 1.2-second boost duration.
- Run `godot --headless --path . --script res://tests/race_state_test.gd` for checkpoint order, lap advancement, race finish, and the three-second recovery threshold.
- Run `godot --headless --path . --script res://tests/race_result_test.gd` for Circuit Race and Time Trial result content and time formatting.
- Run `godot --headless --path . --script res://tests/record_store_test.gd` and `godot --headless --path . --script res://tests/ghost_recorder_test.gd` for best-lap replacement, ghost persistence, and sampled transform data.
- Run `godot --headless --path . --script res://tests/ai_driver_test.gd` for curvature braking, bounded steering, and pace reduction through turns.
- Run `godot --headless --path . --script res://tests/ai_simulation_test.gd` for multi-second headless driving simulation, lane-keeping, and recovery verification.
- Run `godot --headless --path . --script res://tests/hud_and_event_setup_test.gd` for EventSetupPanel state transitions, RaceMinimap coordinate projection, shared 8-second boost pickup cooldowns, and RaceInputHud telemetry/banner state.
- Run `godot --headless --path . --script res://tests/asset_import_and_registry_test.gd` for `AssetRegistry` completeness, mobile texture dimension budgets (`<=512px` surfaces, `<=128px` VFX), VRAM compression/mipmaps (`compress/mode=2`), full-sample WAV loop endpoints, 37-GLB material/orientation/clearance/zero-collider integrity, car paint isolation, `TrackCompiler` visual attachments, and bidirectional `assets/ASSET_CREDITS.md` coverage.
- Run `godot --headless --path . --script res://tests/biome_presets_and_vfx_test.gd` for `BiomePresets` sky/ground palettes across all 6 themes (`desert`, `forest`, `spa_forest`, `alpine`, `parkland`, `open_grassland`), deterministic scenery layout clearance, full coverage of all 23 `NATURE_MODELS` and 11 `TRACKSIDE_MODELS`, zero extra physics colliders on scenery, `CarVfxController` dust/boost/spark emitter behavior, and the 6-biome Track Builder UI.
- Run `.\run_scenario.ps1 -Scenario <Name>` (or `.\run_scenario.ps1 -All`) to execute windowed desktop dynamic verification with real-time stdout telemetry checkpoints, per-tick forensic `telemetry.csv`, and multi-frame `contact_sheet.png` visual sequences across all 8 scenarios (`AccelBrakeReverse`, `CorneringDrift`, `AiPackOvertake`, `BoundaryRecovery`, `BoostPickup`, `CollisionSeparation`, `ScreensFlow`, `BiomeShowcase`).
- Track-data serialization round trip preserves all supported fields.
- Unsupported, oversized, malformed, non-finite, and incomplete imports are rejected safely.
- Track normalization closes loops, removes near-duplicates, bounds width/surface/theme values, and creates valid checkpoint order.
- Compiler produces finite mesh/collision/route data for curated tracks and representative custom drawings.
- Record store preserves only the best lap/race and replaces the ghost only when the lap improves.

## Editor scenarios

- Draw simple oval, tight loop, figure-eight bridge, long circuit, and deliberately extreme scribble.
- Verify smoothing notice, preview, redraw, save, rename, delete, export, import, and duplicate-name behavior.
- Race Time Trial and Circuit Race at 1 and 5 laps with 0, 1, and 7 AI cars.
- Verify soft contact, pickup sharing/8-second respawn, manual boost, 3-second recovery, AI recovery, and lap/position rules.
- Verify ghost appears only in Time Trial after a valid best lap exists.

## Android acceptance

Run on the Redmi Note 14 in landscape with production-equivalent settings:

1. One eight-car curated-track race.
2. One eight-car complex custom bridged track race.
3. One save/export/import/race round trip.
4. One Time Trial with a visible ghost.

Pass only when gameplay is stable, input is usable, no crash/data-loss occurs, and the measured frame rate remains stable at the 60-FPS target. Record the exact device variant, Android version, build identifier, average FPS, worst frame time, and scene for every performance result.

## Bootstrap result

The signed ARM64 debug APK was installed and launched on Xiaomi Redmi Note 14 `24117RN76G` (`tanzanite`), Android 16/API 36. Landscape rendering, the four-action home shell, and direct physical touch interaction were verified. Gameplay and performance acceptance remain future-milestone tests.

## Regression rule

Any fix for compiler, import, AI, collision, recovery, or persistence must rerun its corresponding automated check and editor scenario before Android acceptance testing.

## Current development test target

Until explicitly requested otherwise, validate new gameplay changes in the PC debug build. Android remains the product platform and requires a full device pass before release acceptance.
