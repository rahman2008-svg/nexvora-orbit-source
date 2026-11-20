# Building NexVora ORBIT

Verified status: **not built in the authoring environment.** Everything below is the expected path.

## Requirements
Flutter stable (Dart 3.x), JDK 17, Android SDK + NDK (for `libcactus.so`), CMake. arm64-v8a only.

## Local
```bash
bash flutter/example/native/build.sh        # builds libcactus.so into jniLibs (needs NDK)
cd flutter/example
flutter pub get
dart format lib/orbit test
flutter analyze
flutter test                                 # needs libsqlite3 on the host
flutter build apk --release --target-platform android-arm64
```
Optional: `--dart-define=ORBIT_MODEL_BASE=https://github.com/<you>/NexVora-ORBIT/releases/latest/download`
to download models from your own release instead of upstream Eva's.

## CI
- `ci.yml`: format check (new code), analyze, unit tests, debug APK (`nexvora-orbit-debug-apk` artifact;
  GitHub always wraps workflow artifacts in a ZIP).
- `android-release.yml`: transpiles model bundles (arm64 runner) and publishes
  `nexvora-orbit-arm64-v8a.apk` as a **release asset** — the direct, non-zipped download.
Secrets for stable signing: `ORBIT_KEYSTORE_B64`, `ORBIT_KEYSTORE_PASSWORD` (alias `orbit`).
Without them the APK is debug-signed.
