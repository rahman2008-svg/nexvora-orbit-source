# NexVora ORBIT — Your Phone. Your Intelligence.

On-device AI agent for Android: local Qwen3 chat, offline voice, app discovery and
safe, typed phone actions. Developed by Prince AR Abdur Rahman · Published by NexVora Lab's Ofc.

> **Status: source complete, build UNVERIFIED.** The development sandbox had no Flutter/Dart/Android SDK
> and no network, so `flutter analyze`, tests and the APK build have **not been run**. CI (`.github/workflows/ci.yml`)
> runs them on GitHub. Expect to fix small compile errors on the first run. See [BUILDING.md](BUILDING.md).

## What it is
ORBIT is built on the **Eva** Flutter app (offline chat, documents, maps, music, voice, assistant integration)
and the **Cactus** inference engine, re-skinned to the NexVora design and extended with an action layer:

| Tab | What it does |
|---|---|
| Home | Animated orb, voice/text entry, quick actions, library shortcuts, recent activity |
| Explore (App Intelligence) | Lists launchable apps, searches by name or capability, shows detected Android intents, favorites, launch |
| Assistant | Eva's local chat (Qwen3 default), voice in/out, documents/Wikipedia grounding, maps, music, reminders; action commands run first |
| Automations (Task Builder) | One-sentence multi-step plans, confirmation for sensitive steps, progress, cancel, saved workflows |
| Settings | Activity & memory controls, models/voice/storage (Eva settings), default-assistant, licenses |

Library (Photos, Music, Documents) opens from Home; Maps opens at your GPS position or via "where is X" in chat.

See [FEATURES.md](FEATURES.md) for exact capabilities and limits, [ARCHITECTURE.md](ARCHITECTURE.md),
[MODEL_SETUP.md](MODEL_SETUP.md), [PRIVACY.md](PRIVACY.md), [LICENSES.md](LICENSES.md).

## Licensing — read this
The Cactus engine license (see `LICENSE`) permits free use for individuals, small organizations
(< $2M funding and < $2M revenue), educational and non-profit use; otherwise a commercial license
from Cactus Compute is required. NexVora's additions cannot override that: this project is **not** "all rights
reserved" in a way that supersedes `LICENSE`. Keep `LICENSE` and the upstream notices.
