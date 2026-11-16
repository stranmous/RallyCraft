# RallyCraft 3D — Project Guidelines

## 1. Core Baseline

- **Tech Stack**: Godot `4.6.2.stable` (`Godot_v4.6.2-stable_win64_console.exe` for CLI/headless execution), typed GDScript, Forward Mobile renderer (`mobile`), Jolt Physics 3D (`JoltPhysics3D`), ETC2/ASTC VRAM compression, OpenJDK 17, Android SDK Build-Tools `35.0.0`.
- **Target Platform & Device**: Offline-only Android landscape (`1280x720` base viewport, `canvas_items` stretch, `expand` aspect), sideloadable ARM64-v8a APK (`com.waqas.rallycraft3d`). Primary acceptance device: Xiaomi Redmi Note 14 (`24117RN76G` / `tanzanite`, Android 16 / API 36, ARM Mali-G57 MC2).
- **Hard Constraints**:
  - **Performance Budget**: Stable 60 FPS ($\le 16.6\text{ ms}$ frame time) on the Redmi Note 14 with 8 active cars.
  - **Geometry & Physics**: Generate production roads, curbs, and bridges via `ArrayMesh`/`SurfaceTool` with explicit `StaticBody3D` collision (`CSGPolygon3D` is forbidden in production). Limit active physics bodies to racers and essential pickups; instance repeated props.
  - **Data & Persistence**: Local-only storage under `user://tracks/`, `user://records/`, and temporary staging `user://imports/`. Enforce schema, version, finiteness, and payload-size limits on all imports before compilation or saving; never overwrite existing tracks silently.
  - **Scope & Secrets**: Zero network, cloud, account, analytics, or telemetry dependencies. Private educational use only (no official circuit logos/branding). Never commit keystores, passwords, local SDK paths, device serials, or build artifacts (`build/`, `.godot/`, `*.apk`, `*.aab`).

## 2. Source-of-Truth Router

> **Rule**: Consult only the specific doc whose requirements or schema are changing—do not re-read all docs every turn. When architecture, schemas, requirements, or milestone states evolve, update the owning document in the same task.

- `docs/PRD.md`: Player-visible requirements, core user journeys, functional rules, non-goals, and acceptance criteria.
- `docs/ARCHITECTURE.md` & `docs/adr/`: System boundaries, runtime flow, module ownership rules, storage layout, and architectural decision records.
- `docs/TECHNICAL_PLAN.md`: Core interfaces, track compilation pipeline, race/AI mechanics, and mobile performance budgets.
- `docs/DATA_MODEL.md`: Schemas and validation rules for `TrackDefinition`, `TrackRecord`, `RaceEvent`, share codes, and `.rallycraft` payloads.
- `docs/TASKS.md` & `docs/IMPLEMENTATION_PLAN.md`: Milestone definitions, ordered backlog, and completion gates.
- `docs/TESTING.md`: Automated test suite, editor scenarios, regression rules, and Redmi Note 14 acceptance checklist.
- `docs/ENV.md` & `docs/OPERATIONS.md`: Toolchain paths, Android export settings, device diagnostics, and rollback procedures.
- `docs/ASSET_STRATEGY.md`: Stylized low-poly visual targets, Android asset import budgets, and provenance ledger rules (`assets/ASSET_CREDITS.md`).
- `docs/AGENTS.md` & `docs/HANDOFF.md`: Coding conventions and current milestone handoff context.

## 3. Verification Commands

Use `Godot_v4.6.2-stable_win64_console.exe` on Windows so headless stdout/stderr is not suppressed. In Windows PowerShell 5.1, chain commands with `;` rather than `&&`.

- **Project Import & Script Validation (Typecheck)**:
  ```powershell
  & "C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --editor --quit
  ```
- **Full Automated Test Suite**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\run_tests.ps1
  ```
- **Desktop Dynamic Scenario Runner (Windowed Live View + Telemetry CSV + Multi-Frame Contact Sheet)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\run_scenario.ps1 -Scenario AccelBrakeReverse
  powershell -ExecutionPolicy Bypass -File .\run_scenario.ps1 -All
  powershell -ExecutionPolicy Bypass -File .\run_scenario.ps1 -List
  ```
- **Single Test Script**:
  ```powershell
  & "C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/<test_name>.gd
  ```
- **Android ARM64 Debug APK Build & Signature Check**:
  ```powershell
  & "C:\Users\Waqas\Godot\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --export-debug "Android ARM64 Debug" build/RallyCraft3D-debug.apk
  & "C:\Users\Waqas\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat" verify --verbose build/RallyCraft3D-debug.apk
  ```
- **On-Device Install, Launch & Profiling (Redmi Note 14)**:
  ```powershell
  adb install -r build/RallyCraft3D-debug.apk
  adb shell am force-stop com.waqas.rallycraft3d ; adb shell am start -n com.waqas.rallycraft3d/com.godot.game.GodotAppLauncher
  adb logcat -d -s godot:I AndroidRuntime:E CRASH:E
  adb shell run-as com.waqas.rallycraft3d ls -la files
  adb shell dumpsys gfxinfo com.waqas.rallycraft3d
  ```
