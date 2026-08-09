package com.mkflabs.mousemover.wifi

/**
 * Soft-AP join for Path B provisioning.
 * Emulator typically cannot join Soft-AP — callers must offer a manual Continue path.
 */
interface SoftApJoiner {
    suspend fun join(ssid: String, password: String?)
}

class SoftApJoinException(message: String) : Exception(message)

/** Scaffold stub — real WifiNetworkSpecifier wired in wizard-softap phase. */
class StubSoftApJoiner : SoftApJoiner {
    override suspend fun join(ssid: String, password: String?) {
        throw SoftApJoinException(
            "Soft-AP join is not available in this build/environment. " +
                "Connect manually in system Wi‑Fi settings, then Continue.",
        )
    }
}
