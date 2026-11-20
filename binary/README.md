# NexVora ORBIT — Android APK

The latest installable Android APK for the **NexVora ORBIT** on-device chat app
(arm64-v8a).

## Get the most recent APK

```bash
bash binary/get-latest-apk.sh
```

This downloads it here as `binary/NexVora ORBIT.apk`, ready to install or share:

```bash
adb install -r binary/NexVora ORBIT.apk
```

## Share link

The APK is published with every build and is always available at this stable
URL (this is the easiest thing to share):

> https://github.com/NexVora-ORBIT/NexVora-ORBIT/releases/latest/download/nexvora-orbit-arm64-v8a.apk

## Why isn't the APK committed here?

The APK is ~200 MB (it embeds the default model), which is over GitHub's 100 MB
per-file push limit, so it can't live in git directly. It's hosted on the
GitHub release instead, and `get-latest-apk.sh` pulls it into this folder.
`binary/*.apk` is gitignored.

## Notes

- arm64-v8a only; the APK is debug-signed (installs directly — enable "install
  from unknown sources"). It is a demo build, not a Play-Store artifact.
- Built and published automatically by `.github/workflows/android-release.yml`.
