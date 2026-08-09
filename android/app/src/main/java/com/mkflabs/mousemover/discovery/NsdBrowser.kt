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

/** Test / scaffold stub. */
class StubNsdBrowser : NsdBrowser {
    override var onUpdate: ((List<DiscoveredService>) -> Unit)? = null
    override fun start() {
        onUpdate?.invoke(emptyList())
    }
    override fun stop() = Unit

    fun emit(services: List<DiscoveredService>) {
        onUpdate?.invoke(DiscoveryFilter.deduplicate(services))
    }
}
