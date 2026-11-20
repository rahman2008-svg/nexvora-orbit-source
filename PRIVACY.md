# Privacy
No account, analytics, Firebase, Supabase or cloud AI. Chats, documents, indexes, history and workflows stay on the device (SQLite in app storage); clear them under Settings → Your Activity.
Network use is user-triggered: model/ASR/Wikipedia downloads, map tiles, lyrics/radio streams, web actions you confirm, and the optional update check (off by default). The phone's speech recognizer may use the network depending on your device.
Permissions: microphone, location (map dot), notifications/exact alarms (reminders), media/storage (library), set-alarm (Clock handoff), voice-interaction (assistant). `REQUEST_INSTALL_PACKAGES` and `MANAGE_EXTERNAL_STORAGE` are inherited from Eva (updater, sideload folders) and are candidates for removal.
