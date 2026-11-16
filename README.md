# RallyCraft 3D

**RallyCraft 3D** is an offline-first, landscape arcade rally racer and procedural track studio built with **Godot 4.6.2** (typed GDScript, Forward Mobile renderer, Jolt Physics 3D) targeting **Android (ARM64-v8a)** and desktop development builds.

Race four built-in educational circuits or draw your own closed-loop tracks with automatic corner smoothing, bridge overpass generation, biome themes, 2D/3D previews, AI opponents, Time Trial ghosts, and offline track sharing.

---

## Key Features

- **Custom Track Studio (`TrackPathProcessor` + `TrackCompiler`)**
  - Freehand closed-loop drawing canvas with automatic normalization, spacing/curvature smoothing, and optimization notices.
  - Self-crossing detection that elevates overlapping segments into procedural bridges/overpasses.
  - Procedural `ArrayMesh` / `SurfaceTool` road, curb, embankment, and bridge generation paired with explicit `StaticBody3D` collision (no `CSGPolygon3D`).
  - Selectable road surfaces (**Asphalt**, **Dirt**), widths (**Narrow**, **Standard**, **Wide**), and **6 biome presets** (**Forest**, **Desert**, **Alpine**, **Spa Forest**, **Parkland**, **Open Grassland**).
  - Live **2D Minimap** and interactive **3D Orbit** previews across Home, Track Select, Track Builder, Library/Records, and Import Preview.
- **Built-in Curated Circuits (`CuratedTrackCatalog`)**
  - **Spa Ardennes** — wide asphalt, Spa Forest biome, Eau Rouge climb & sector metadata.
  - **Red Bull Ring** — wide asphalt, Alpine biome, elevation climbs & downhill sweepers.
  - **Monza Park** — wide asphalt, Parkland biome, high-speed boost straights & Lesmos.
  - **Silverstone Airfield** — standard asphalt, Open Grassland biome, flowing multi-apex S-curves.
  - *(Curated layouts are private/educational replicas with no official circuit logos or branding.)*
- **Arcade Racing, AI Pack & Time Trial**
  - **Circuit Race**: `1–5` laps with `0–7` curvature-aware AI opponents (`AIDriver`) featuring bounded lap-to-lap pace adaptation and automatic recovery.
  - **Time Trial**: Solo runs with best-lap ghost recording and playback (`GhostRecorder` / `GhostPlayback`).
  - **Trackside Boost Pads**: Shared `8 s` global pad respawn cooldown; stores 1 charge for a manual `1.2 s` speed burst.
  - **Arcade Physics & Recovery**: Auto-throttle drive model with soft horizontal car-to-car collision impulses and `3 s` automatic stuck/off-route checkpoint recovery.
  - **Mobile Visuals & Audio**: Instanced `MultiMeshInstance3D` nature/trackside props (`BiomePresets`), mobile-budget dust/boost/spark particles (`CarVfxController`), pitch-modulated engine and tire-skid loops (`RaceAudioController`), and independent **SFX** / **BGM** toggles.
- **Offline Storage & Portable Track Sharing (`user://`)**
  - Saves custom tracks (`user://tracks/`) and per-track best lap, best race, and ghost samples (`user://records/`) locally.
  - Imports and exports custom tracks offline using compact **`RC3D1:`** share codes (up to `16,384` chars) or **`.rallycraft`** files (up to `65,536` bytes), validated in isolation and previewed before saving without overwriting existing tracks.

---

## Project Status

| Area | Status | Notes |
| --- | --- | --- |
| Core gameplay, track builder, sharing, AI, ghosts, 6 biomes & Palette 4 UI | Implemented | Verified on desktop (`17 / 17` automated tests passing) |
| Android ARM64 debug build (`com.waqas.rallycraft3d`) | Implemented | Exports, signs, installs, and runs on Android 16 (Redmi Note 14) with clean `logcat` |
| Milestone 6 — 60 FPS device optimization & complex custom-track profiling | **In Progress (Help Welcome)** | 8-car live races on Redmi Note 14 (`Mali-G57 MC2`, `2400×1080`) currently average `~53–55 FPS` (`18.3–18.9 ms/frame`) vs. the locked `60 FPS` (`<= 16.6 ms`) target |

---

## Controls

### Android Touch (Landscape)
- **Auto-Throttle**: Forward acceleration is automatic once the countdown finishes.
- **Steer Left / Right**: Touch anywhere on the left or right half of the screen (BBR2-style split steering, outside HUD buttons).
- **Drift / Brake**: Bottom-left and bottom-right circular `DRIFT BRAKE` pads.
- **Boost**: Right-side `BOOST` pad positioned above the right brake pad.
- **HUD Utilities**: Top-right `SFX`, `BGM`, and `Pause` buttons.

### Desktop / Editor Keyboard
| Action | Key(s) |
| --- | --- |
| Steer Left / Right | `A` / `D` or `Left` / `Right` |
| Drift / Brake | `Space` or `Shift` |
| Trigger Boost | `F` |
| AI Telemetry Debug Overlay | `F1` |
| Pause / Back | `Esc` |

---

## Tech Stack & Repository Layout

- **Engine**: Godot `4.6.2.stable` (Typed GDScript)
- **Renderer**: Forward Mobile (`mobile`), `ETC2/ASTC` VRAM compression, mobile 3D render scale `0.67`
- **Physics**: `JoltPhysics3D` with physics interpolation enabled
- **Viewport**: `1280×720` base landscape (`canvas_items` stretch, `expand` aspect)
- **Target Package**: Offline-only Android ARM64 (`arm64-v8a`, no network/ads/analytics/accounts)

```text
RallyCraft/
├── assets/                   # Low-poly GLBs, surfaces, VFX textures, Lucide SVG icons, OGG/WAV audio + ASSET_CREDITS.md
├── docs/                     # Architecture, PRD, Data Model, Technical Plan, Testing, Operations, Agent Guide
├── scripts/
│   ├── main_controller.gd    # Screen shell, navigation, 6-biome Track Builder, race lifecycle, F1 overlay
│   ├── assets/               # AssetRegistry & caching
│   ├── data/                 # TrackDefinition, CuratedTrackCatalog, TrackStore, RecordStore, ShareCodec
│   ├── racing/               # RallyCar, RallyDriveModel, AIDriver, RaceManager, Ghost, Audio & VFX controllers
│   ├── track/                # TrackPathProcessor, TrackCompiler, BiomePresets
│   └── ui/                   # UITheme, TrackPreviewWidget, TrackSelectPanel, LibraryRecordsPanel, EventSetupPanel, RaceInputHud, RaceMinimap
├── tests/                    # 17 headless unit & integration test scripts (*_test.gd)
│   └── scenarios/            # 8 dynamic verification scenarios + telemetry/contact-sheet generator
├── export_presets.cfg        # Android ARM64 Debug preset
├── project.godot             # Engine, display, Jolt physics & mobile rendering config
├── run_tests.ps1             # Windows PowerShell runner for the 17 automated tests
└── run_scenario.ps1          # Windows PowerShell runner for the 8 dynamic desktop scenarios
```

---

## Getting Started

### Prerequisites
- **[Godot Engine 4.6.2.stable](https://godotengine.org/)** (standard editor + matching `4.6.2.stable` export templates if building Android APKs). Ensure the Godot console binary is on your `PATH` (or replace `godot` below with its full path; on Windows, PowerShell runners also check `$env:GODOT_BIN` or `-GodotPath`).
- **For Android APK builds**: **OpenJDK 17**, **Android SDK** (Build-Tools `35.0.0`, Platform-Tools / `adb`), and a local debug keystore (kept outside the repo).

### 1. Open or Run on Desktop
Clone the repository and open `project.godot` in Godot `4.6.2.stable`, or run from the CLI:

```bash
godot --path .
```

To run a headless editor import & script validation check:

```bash
godot --headless --path . --editor --quit
```

### 2. Run Automated Tests (17 Tests)
Each test script under `tests/*_test.gd` runs headlessly with Godot:

```bash
# Cross-platform example (run one test, or loop over tests/*_test.gd)
godot --headless --path . --script res://tests/track_compiler_test.gd
```

On Windows, use [run_tests.ps1](run_tests.ps1):

```powershell
powershell -ExecutionPolicy Bypass -File .\run_tests.ps1
```

> **Note for contributors**: [run_tests.ps1](run_tests.ps1) and [run_scenario.ps1](run_scenario.ps1) automatically look for `-GodotPath`, `$env:GODOT_BIN`, `PATH` (`Godot_v4.6.2-stable_win64_console.exe` / `godot4` / `godot`), or `%USERPROFILE%\Godot\`.

### 3. Run Dynamic Desktop Scenarios (8 Scenarios)
Desktop scenarios simulate driving, AI packs, collisions, recovery, pickups, UI navigation (`ScreensFlow`), and biome rendering (`BiomeShowcase`), exporting telemetry CSVs and multi-frame contact sheets to `build/scenario_runs/<Scenario>/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_scenario.ps1 -List
powershell -ExecutionPolicy Bypass -File .\run_scenario.ps1 -Scenario AccelBrakeReverse
powershell -ExecutionPolicy Bypass -File .\run_scenario.ps1 -All
```

Or run any scenario directly with Godot CLI (Windows/macOS/Linux):

```bash
godot --fixed-fps 60 --path . --resolution 1280x720 --script res://tests/scenarios/scenario_screens_flow.gd -- --out=./build/scenario_runs/ScreensFlow
```

### 4. Export & Install Android ARM64 Debug APK
Configure **Android SDK Path** and **Java SDK Path** (OpenJDK 17) in Godot Editor Settings, ensure `build/` exists (`mkdir -p build` in bash, or `New-Item -ItemType Directory -Force build | Out-Null` in PowerShell), then export and install:

```bash
mkdir -p build
godot --headless --path . --export-debug "Android ARM64 Debug" build/RallyCraft3D-debug.apk
apksigner verify --verbose build/RallyCraft3D-debug.apk
adb install -r build/RallyCraft3D-debug.apk
adb shell am start -n com.waqas.rallycraft3d/com.godot.game.GodotAppLauncher
```

For profiling on an attached device:

```bash
adb shell dumpsys gfxinfo com.waqas.rallycraft3d
adb logcat -d -s godot:I AndroidRuntime:E CRASH:E
```

---

## Contributing

Contributions, bug reports, performance profiles, and pull requests are welcome!

### Workflow
1. **Fork** the repository on GitHub and clone your fork locally.
2. Create a feature branch (`git checkout -b fix/your-change`).
3. Run headless validation and the automated tests (`godot --headless --path . --editor --quit` and `tests/*_test.gd`).
4. Commit your changes, push to your fork, and open a **Pull Request** describing what you changed and how you verified it.

### High-Impact Areas to Help With
1. **Lock 60 FPS on Mid-Range Mobile GPUs (Milestone 6)**: Profile 8-car CPU/GPU bottlenecks on curated and complex bridged custom tracks (for example, staggering AI avoidance/raycast intervals, tuning shadow/draw-call budgets, or testing mobile render scale vs. crispness).
2. **Cross-Platform Test Tooling**: Add POSIX shell (`*.sh`) test/scenario runners or a GitHub Actions workflow for Linux/macOS contributors.
3. **Android Device Testing**: Verify HUD layouts, touch responsiveness, and `.rallycraft` file/share-code round trips across additional screen aspect ratios and Android chipsets.
4. **Gameplay Polish & Content**: Tune drift/AI feel, refine Track Builder UX, or add new curated layouts and procedural scenery within the mobile asset budget.

### Contributor Guidelines
1. **Respect Module Boundaries**: Keep UI (`scripts/ui/`) separate from mesh/collision generation (`TrackCompiler`), driving physics (`RallyCar`/`RallyDriveModel`), AI (`AIDriver`), and persistence (`TrackStore`/`RecordStore`/`ShareCodec`). See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/AGENTS.md](docs/AGENTS.md).
2. **Keep Core Constraints Intact**:
   - Stay offline-only (no network calls, SDKs, accounts, analytics, or telemetry).
   - Keep production roads generated via `ArrayMesh`/`SurfaceTool` + `StaticBody3D` (never `CSGPolygon3D`).
   - Keep curated track data strictly educational/non-branded.
   - Never commit keystores, passwords, local SDK paths, device serials, or `build/` / `.godot/` / `*.apk` files.
3. **Asset Provenance & Budget**: Every external model, texture, icon, or audio clip added under `assets/` must meet the mobile limits in [docs/ASSET_STRATEGY.md](docs/ASSET_STRATEGY.md), include full attribution in [assets/ASSET_CREDITS.md](assets/ASSET_CREDITS.md), and pass `tests/asset_import_and_registry_test.gd`.
4. **Verify Before Opening a PR**: Run `godot --headless --path . --editor --quit`, all `17` tests (`tests/*_test.gd`), and any relevant `tests/scenarios/` checks, then describe what you tested in your PR.

---

## Documentation

- [Product Requirements](docs/PRD.md) — features, user journeys, functional rules, acceptance criteria
- [Architecture](docs/ARCHITECTURE.md) & [ADR 001: Procedural Road Meshes](docs/adr/001-procedural-road-mesh.md) — module boundaries and storage layout
- [Technical Plan](docs/TECHNICAL_PLAN.md) — core interfaces, compilation pipeline, physics & mobile budgets
- [Data Model](docs/DATA_MODEL.md) — `TrackDefinition`, `TrackRecord`, `ShareCodec`, and import validation rules
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) & [Current Backlog](docs/TASKS.md) — milestones and open tasks
- [Testing Plan](docs/TESTING.md) — automated tests, dynamic scenarios, and Android acceptance criteria
- [Environment Setup](docs/ENV.md) & [Operations](docs/OPERATIONS.md) — toolchain pairing and Android build/install flow
- [Asset Strategy](docs/ASSET_STRATEGY.md) & [Asset Credits](assets/ASSET_CREDITS.md) — asset budgets and full provenance ledger
- [Agent & Engineering Guide](docs/AGENTS.md) & [Handoff Notes](docs/HANDOFF.md) — coding conventions and current codebase map

---

## Assets & Licensing

- **Assets**: Packaged 3D models, textures, UI icons, and audio under `assets/` are documented file-by-file in [assets/ASSET_CREDITS.md](assets/ASSET_CREDITS.md). Most assets are **CC0 1.0**, UI SVG icons (`res://assets/icons/*.svg`) are from **Lucide Icons** (**ISC License**), and `res://assets/audio/sfx/tire_skid.wav` is licensed under **CC-BY 3.0** (credited to **audible-edge / Tom Haigh** and **qubodup / Iwan Gabovitch**).
- **Source Code**: Licensed under the **MIT License** — see [LICENSE](LICENSE).
