# Architecture

Flutter UI → FFI → Cactus (`libcactus.so`) for LLM/embeddings; sherpa-onnx for offline English ASR; libzim for Wikipedia.

## ORBIT action pipeline (`lib/orbit/`)
1. **Input**: chat field, Home field, voice transcript.
2. **`CommandParser`**: deterministic EN (+ few Bangla verbs) parser → typed `OrbitAction`s, a disambiguation question, or "not found". Unrecognised text returns `null` and continues to Eva's handlers (reminders, music, radio, photos, maps) and finally the Qwen3 chat.
3. **`AppIndex`**: installed launchable apps + probe intents (public intent filters) + category; lexical/capability scoring. *Not neural embeddings.*
4. **`OrbitAction.validate()`**: argument checks; the closed `ActionKind` enum is the only executable vocabulary. `planFromLlmJson` validates any model-proposed plan against it (wired as a pure function; the chat path does not yet call the LLM for intents).
5. **`WorkflowEngine`**: sequential, cancellable; `ActionRisk.confirm` steps (dial, web, web search) need a dialog OK; first failure stops the run; summaries state only what Android reported.
6. **`OrbitAppControl.kt`** (`orbit/apps` channel): PackageManager queries, whitelisted intents (settings pages, camera, maps, timer/alarm via `AlarmClock`, dialer, http(s)). No shell, no accessibility automation, no `QUERY_ALL_PACKAGES`.
7. **`OrbitStore`** (SQLite via `sqlite3`): commands, workflows, favorites, launches.

Eva's own state (`ChatScreen` state) still owns models, music, documents and chat; `OrbitController` is created there and shared with the new screens.
