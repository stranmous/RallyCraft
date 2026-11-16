# Data Model

## TrackDefinition

| Field | Purpose |
| --- | --- |
| `format_version` | enables safe future migration |
| `track_id` | stable local identifier |
| `name` | editable player-visible name |
| `source` | `curated` or `custom` |
| `centerline_points` | normalized closed-loop X/Z control points |
| `elevation_profile` | curated elevation samples or generated bridge/slope data |
| `road_width` | `narrow`, `standard`, or `wide` |
| `surface` | `dirt` or `asphalt` |
| `theme` | `desert`, `forest`, `spa_forest`, `alpine`, `parkland`, or `open_grassland` |
| `metadata` | author/source label, creation time, and optional preview values |

Curated tracks provide their own authored control/elevation data. Custom tracks retain their normalized input points so they can be regenerated after engine updates.

## TrackRecord

One record exists per local `track_id`.

| Field | Purpose |
| --- | --- |
| `best_lap_ms` | fastest completed lap |
| `best_race_ms` | fastest completed event time |
| `ghost_version` | decoder compatibility |
| `ghost_samples` | fixed-rate position, heading, and time samples for the best lap |

Time Trial records are versioned local JSON under `user://records/`. A ghost is replaced only when a completed lap is strictly faster than the saved best lap.

## RaceEvent

Runtime-only state: selected track ID, mode, 1–5 lap count, 0–7 AI count, race timers, grid order, current positions, shared pickup cooldowns, and finish state. It is not retained as full history.

## Portable track payload

A share code and `.rallycraft` file encode only portable track-definition data. They never contain records, ghosts, device paths, unknown assets, executable code, or official branding.

### Import rules

- Reject unsupported versions, missing required fields, non-finite numbers, impossible point counts, oversized payloads, and malformed text.
- Compile a candidate in memory and show a preview before saving.
- Assign a new local ID on import; never overwrite a matching local track automatically.
- Preserve the original payload only as temporary import data until confirmation/cancellation.
