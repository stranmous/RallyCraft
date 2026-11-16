# RallyCraft 3D Backlog

## 1. Toolchain and project bootstrap

- [x] Install and verify Godot 4.6.2 Android export templates.
- [x] Configure OpenJDK 17 and Android SDK paths in Godot.
- [x] Create the Godot project with Mobile renderer, Jolt Physics, landscape orientation, and ARM64 Android export preset.
- [x] Add a minimal main scene and navigation shell.
- [x] Install and launch the signed debug APK on the Redmi Note 14 with USB debugging enabled.

## 2. Track foundation

- [x] Define the versioned track data model and local storage locations.
- [x] Implement drawing input, closed-loop normalization, safe smoothing, and preview data.
- [x] Generate render mesh, curbs, bridge segments, and static collision from track data.
- [x] Add checkpoints, start grid, minimap data, and generated safe boost locations.

## 3. Racing foundation

- [x] Implement auto-throttle rally-car control, Drift/Brake, boost, and low chase camera.
- [x] Implement laps, race state, 3-second automatic recovery, and soft arcade contact.
- [x] Implement Circuit Race and Time Trial results.
- [x] Record and replay a best-lap time-trial ghost.

## 4. Opponents and UI

- [x] Implement curvature-led AI with per-lap adaptation and recovery.
- [x] Support 0–7 AI cars and 1–5 laps.
- [x] Implement the BBR2-style touch HUD and event setup.
- [x] Implement home, track selection, create flow, preview, library, and records screens.

## 5. Persistence, sharing, and content

- [x] Implement track naming, save/edit/delete, share-code import/export, and `.rallycraft` document import/export.
- [x] Add hand-authored educational-use track data for Spa, Red Bull Ring, Monza, and Silverstone.
- [x] Select, import, optimize, and record licensed asset sources.
- [x] Build Desert, Forest, Spa, Alpine, Parkland, and Open-Grassland environment presets.

## 6. Validation and APK delivery

- [ ] Add automated data/compiler tests and manual race regression checklist.
- [ ] Profile curated and complex custom tracks on the Redmi Note 14.
- [ ] Produce and install a sideloadable ARM64 APK.
