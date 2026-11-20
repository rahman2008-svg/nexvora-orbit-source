# Features and honest limits

**Works by design (needs on-device verification):** app discovery/search/launch; settings pages, camera, maps, timer, alarm, dialer, web (confirmed); multi-step plans; saved workflows; history/favorites/clear controls; Eva chat with Qwen3 1.7B (default) or LFM2.5 350M on low-RAM devices; offline English speech recognition; phone recognizer for other languages (may use the network depending on the device); TTS; documents, Wikipedia, maps, music, radio, reminders; default-assistant role and power-button hold (device/OEM dependent).

**Limits**
- Apps are not assumed to expose internal features; ORBIT only knows launcher entries and declared intent filters.
- Timers/alarms open the Clock app for confirmation; ORBIT cannot verify they were saved. Calls are never placed (dialer only).
- "Recently used" = launched through ORBIT (usage-access permission is not requested).
- Semantic search is lexical + capability matching. EmbeddingGemma is not part of Eva's engine; the Cactus embedder (nomic) is used for documents only.
- Bangla: UI action verbs partially; offline speech is English; Bangla speech depends on the phone recognizer.
- No Qwen3 0.6B bundle exists upstream; add it via the CI model list if wanted.
- Saved workflows run only when started; no background scheduling. Widgets and notification controls are not implemented.
- Dark theme only (the old Appearance setting has no effect).
- Power-button activation needs the default-assistant role; Android/OEMs may restrict it.
