# Environment Setup

## Required local tools

- Godot 4.6.2 stable (installed).
- Matching Godot 4.6.2 export templates (installed and verified).
- OpenJDK 17 at `C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot` (configured in Godot).
- Android SDK at `C:\Users\Waqas\AppData\Local\Android\Sdk` (configured in Godot).
- Android Platform Tools/ADB (installed; no device currently attached).

## Godot configuration

In Godot Editor Settings, configure:

- Android SDK Path: `C:\Users\Waqas\AppData\Local\Android\Sdk`
- Java SDK Path: the installed OpenJDK 17 directory

The export templates matching `4.6.2.stable` are installed. Keep this exact version pairing when upgrading Godot.

## Android project setup

- Renderer: Mobile.
- Physics: Jolt Physics.
- Orientation: landscape.
- ABI: ARM64 for the primary Redmi Note 14 APK.
- Package/application ID: select a stable private identifier before the first install, then keep it stable to avoid uninstall/reinstall conflicts.

## Safe local setup

- Keep signing keystores and passwords outside the repository.
- Use a debug APK during development.
- Enable USB debugging only on the test device and revoke it after testing if no longer needed.
- Do not commit local SDK paths, device serials, keystores, or passwords.

## Verification

1. Confirm Godot sees the Android SDK and Java SDK with no export warning. **Complete.**
2. Create a minimal Android preset. **Complete.**
3. Export a signed debug ARM64 APK. **Complete:** `build/RallyCraft3D-debug.apk`.
4. Install it on the Redmi Note 14. **Complete.**
5. Confirm landscape startup and capture the device variant/Android version for `OPERATIONS.md`. **Complete:** Xiaomi `24117RN76G` (`tanzanite`), Android 16/API 36, ARM64-v8a.
