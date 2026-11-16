# Product Requirements Document

## Product goal

RallyCraft 3D is a private Android school project that combines accessible arcade circuit racing with player-created tracks. It should feel fast, readable, and forgiving while still making driving mistakes cost time.

## Audience and platform

- Audience: the project creator, classmates, and local testers.
- Platform: Android only, landscape only, offline only.
- Target device: Redmi Note 14.
- Visual direction: polished stylized low-poly, not photorealistic simulation.

## Core player journeys

### Curated race

1. Open the featured-track home.
2. Select Spa, Red Bull Ring, Monza, or Silverstone.
3. Choose Circuit Race or Time Trial.
4. For Circuit Race, select 1–5 laps and 0–7 AI cars.
5. Race, review best times/results, and retry or choose another track.

### Create and race

1. Open a blank drawing canvas and sketch a closed loop.
2. Select Desert or Forest and Dirt or Asphalt.
3. The game smooths unsafe geometry while preserving the sketch and explains any optimization.
4. Inspect a rotatable 3D preview and a top-down map.
5. Save with an editable suggested name or race immediately.

### Share and import

1. Export a local track as a text share code or `.rallycraft` file.
2. Send it through an installed Android app or a file transfer method.
3. The receiving device previews validated data before saving it to its local library.

## Functional requirements

- Home has Play, Track Select, Create Track, and Library actions, with a featured curated track.
- Curated tracks are recognizable arcade replicas for private educational use only, without official branding.
- Custom tracks are closed loops and can be redrawn, saved, renamed, deleted, exported, imported, and replayed.
- Circuit Race supports 1–5 laps and 0–7 AI cars. Time Trial is solo and may show the best-lap ghost.
- Cars auto-accelerate and expose Left, Right, combined Drift/Brake, and Boost touch controls.
- Soft arcade contact causes limited speed loss and separation, without flips, prolonged blocking, or race-ending spins.
- A car stuck, overturned, or far off route for 3 seconds resets to the last valid checkpoint with no additional time penalty.
- AI follows curvature-derived pace targets and improves modestly after completed laps.
- Boost points appear on safe straights. A collected point disappears globally for 8 seconds, fills one charge, and enables a 1.2-second manually triggered burst.
- Save best lap, best race time, and one best-lap ghost per track.

## Non-goals

- Online multiplayer, leaderboards, cloud sync, accounts, ads, analytics, monetization, Play Store publication, and official track licensing.
- Point-by-point spline editing, replay archives, weather, damage simulation, pit stops, or multiple car classes.

## Acceptance criteria

- A new player can select a curated track and start a race without creating content.
- A custom drawing can become a previewable, saveable, and raceable track or receives a clear smoothing notice.
- A valid export imports successfully on another Android device; malformed data cannot crash the game or overwrite a track silently.
- Circuit Race, Time Trial, records, ghost, boosts, AI, collisions, and recovery work on both curated and custom tracks.
- Eight cars can race at the target 60 FPS on the Redmi Note 14 in the documented acceptance scenarios.
