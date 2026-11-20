package com.nexvora.orbit

import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

/** Factory for [OrbitVoiceInteractionSession] — one session per assist invocation. */
class OrbitVoiceInteractionSessionService : VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return OrbitVoiceInteractionSession(this)
    }
}
