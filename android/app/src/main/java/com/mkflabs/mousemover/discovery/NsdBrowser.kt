package com.mkflabs.mousemover.discovery

/**
 * Discovered `_http._tcp` service candidate (mDNS / NSD).
 * BLE can later implement a parallel [RadioDiscovery] without changing UI.
 */
data class DiscoveredService(
    val id: String,
    val deviceId: String?,
    val name: String,
    val host: String,
    val port: Int,
    val txt: Map<String, String> = emptyMap(),
)

/**
 * Future BLE / alternate radio discovery plug-in point.
 * v1 uses NSD only via [NsdBrowser].
 */
interface RadioDiscovery {
    fun start()
    fun stop()
}

interface NsdBrowser : RadioDiscovery {
    var onUpdate: ((List<DiscoveredService>) -> Unit)?
}

/** Scaffold stub — real NSD wired in wizard-mdns-scan phase. */
class StubNsdBrowser : NsdBrowser {
    override var onUpdate: ((List<DiscoveredService>) -> Unit)? = null
    override fun start() {
        onUpdate?.invoke(emptyList())
    }
    override fun stop() = Unit
}

object DiscoveryFilter {
    fun isCandidate(serviceName: String, host: String, txt: Map<String, String>): Boolean {
        if (txt["id"] != null) return true
        val haystack = "$serviceName $host".lowercase()
        return haystack.contains("hid-helper")
    }
}
