package com.nexvora.orbit

import android.service.voice.VoiceInteractionService

/**
 * The always-available service that makes ORBIT selectable as the device's
 * "Digital assistant app" (ROLE_ASSISTANT). The system binds this when ORBIT is
 * the chosen assistant; the actual per-invocation logic lives in
 * [OrbitVoiceInteractionSession], created by [OrbitVoiceInteractionSessionService].
 */
class OrbitVoiceInteractionService : VoiceInteractionService()
