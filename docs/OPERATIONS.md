# Operations

## Environments

- Development: Windows with Godot 4.6.2.
- Runtime target: Android landscape, ARM64, private sideloaded APK.
- Acceptance device: Xiaomi Redmi Note 14 (`24117RN76G`, codename `tanzanite`), Android 16/API 36, ARM64-v8a, 450 dpi. Record graphics settings before final performance sign-off.

## Build and install

1. Review `ENV.md`; the matching export templates and toolchain are configured.
2. Configure Android SDK and OpenJDK 17 paths in Godot Editor Settings.
3. Create a debug ARM64 Android export preset for device iteration.
4. Export an APK and install it on the test device through Godot or ADB.
5. Keep release signing material outside version control if a non-debug private APK is required.

## Bootstrap verification record

- The signed ARM64 debug APK installed and launched successfully on the acceptance device.
- Package: `com.waqas.rallycraft3d`.
- The Godot launcher activity was confirmed as foreground in landscape.
- The visible home shell showed Play, Track Select, Create Track, and Library actions without a crash.
- Direct physical touch was confirmed on the handset: all four placeholder buttons are clickable and display their action-specific later-milestone message.
- ADB synthetic-touch injection did not activate the buttons after rotation-coordinate checks; treat it as an automation limitation of this device configuration, not an application defect.

## Monitoring and diagnostics

- Use Godot's profiler, frame-time graph, visible collision shapes, and debug overlays during development.
- Record device model, build identifier, scene, reproduction steps, average FPS, worst frame time, and memory symptoms for performance defects.
- Keep a reproducible custom-track share code or `.rallycraft` file for every reported compiler, AI, or recovery issue.

## Backups and rollback

- Git is the source-controlled rollback mechanism for code, data definitions, and documentation.
- User track files are local data: export important tracks before destructive library operations.
- Never overwrite an existing imported or edited track without an explicit confirmation flow; create a new local copy on name/ID conflict.
- If an APK regression occurs, reinstall the last known-good APK and preserve the failing APK plus reproduction track.

## Incident handling

- Crash or malformed import: preserve the source payload, reject it safely, and log a non-sensitive reason.
- Performance failure: capture a profiler trace and reduce only the identified bottleneck.
- Broken curated track: disable it from selection through local content data while preserving other tracks.
