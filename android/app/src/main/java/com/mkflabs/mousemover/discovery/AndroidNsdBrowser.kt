package com.mkflabs.mousemover.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import com.mkflabs.mousemover.network.DeviceEndpointResolver
import java.util.concurrent.ConcurrentHashMap

class AndroidNsdBrowser(
    context: Context,
) : NsdBrowser {
    override var onUpdate: ((List<DiscoveredService>) -> Unit)? = null

    private val nsd = context.applicationContext.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val services = ConcurrentHashMap<String, DiscoveredService>()
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val resolveListeners = ConcurrentHashMap<String, NsdManager.ResolveListener>()

    override fun start() {
        stop()
        val listener =
            object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(regType: String?) = Unit

                override fun onServiceFound(service: NsdServiceInfo) {
                    val name = service.serviceName ?: return
                    val type = service.serviceType ?: return
                    if (!type.contains("_http._tcp")) return
                    val provisionalHost = "$name.local"
                    val key = "$name.$type"
                    val provisional =
                        DiscoveredService(
                            id = key,
                            deviceId = null,
                            name = name,
                            host = provisionalHost,
                            port = 80,
                        )
                    if (DiscoveryFilter.isCandidate(name, provisionalHost, emptyMap())) {
                        services[key] = provisional
                        publish()
                        resolve(service, key)
                    }
                }

                override fun onServiceLost(service: NsdServiceInfo) {
                    val name = service.serviceName ?: return
                    val type = service.serviceType ?: return
                    val key = "$name.$type"
                    services.remove(key)
                    publish()
                }

                override fun onDiscoveryStopped(serviceType: String?) = Unit

                override fun onStartDiscoveryFailed(serviceType: String?, errorCode: Int) {
                    onUpdate?.invoke(emptyList())
                }

                override fun onStopDiscoveryFailed(serviceType: String?, errorCode: Int) = Unit
            }
        discoveryListener = listener
        nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    override fun stop() {
        discoveryListener?.let {
            runCatching { nsd.stopServiceDiscovery(it) }
        }
        discoveryListener = null
        resolveListeners.clear()
        services.clear()
    }

    private fun resolve(service: NsdServiceInfo, key: String) {
        val listener =
            object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo?, errorCode: Int) {
                    resolveListeners.remove(key)
                }

                override fun onServiceResolved(resolved: NsdServiceInfo) {
                    resolveListeners.remove(key)
                    val hostAddress =
                        resolved.host?.hostAddress
                            ?: resolved.host?.hostName
                            ?: return
                    val host = DeviceEndpointResolver.sanitizeHost(hostAddress)
                    val port = if (resolved.port > 0) resolved.port else 80
                    val txt = txtMap(resolved)
                    val deviceId = txt["id"]
                    val name = resolved.serviceName ?: key
                    if (!DiscoveryFilter.isCandidate(name, host, txt)) {
                        services.remove(key)
                        publish()
                        return
                    }
                    services[key] =
                        DiscoveredService(
                            id = key,
                            deviceId = deviceId,
                            name = name,
                            host = host,
                            port = port,
                            txt = txt,
                        )
                    publish()
                }
            }
        resolveListeners[key] = listener
        @Suppress("DEPRECATION")
        nsd.resolveService(service, listener)
    }

    private fun txtMap(info: NsdServiceInfo): Map<String, String> {
        val attrs =
            if (Build.VERSION.SDK_INT >= 21) {
                info.attributes ?: emptyMap()
            } else {
                emptyMap()
            }
        return attrs.mapNotNull { (k, v) ->
            if (v == null) return@mapNotNull null
            k to String(v, Charsets.UTF_8)
        }.toMap()
    }

    private fun publish() {
        val deduped = DiscoveryFilter.deduplicate(services.values.toList())
        onUpdate?.invoke(deduped)
    }

    companion object {
        const val SERVICE_TYPE = "_http._tcp."
    }
}
