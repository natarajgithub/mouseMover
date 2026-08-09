package com.mkflabs.mousemover.discovery

import com.mkflabs.mousemover.data.StoredDeviceEntity
import com.mkflabs.mousemover.network.DeviceEndpointResolver
import com.mkflabs.mousemover.network.DeviceStatus

data class SavedDeviceIndex(
    private val byId: Map<String, Entry>,
    private val byHost: Map<String, Entry>,
) {
    data class Entry(
        val deviceId: String,
        val displayName: String,
        val hosts: Set<String>,
    )

    val isEmpty: Boolean get() = byId.isEmpty()

    fun match(candidate: DiscoveredService): Entry? {
        candidate.deviceId?.trim()?.takeIf { it.isNotEmpty() }?.lowercase()?.let { id ->
            byId[id]?.let { return it }
        }
        val host = DeviceEndpointResolver.sanitizeHost(candidate.host).lowercase()
        if (host.isNotEmpty()) byHost[host]?.let { return it }
        return null
    }

    fun match(status: DeviceStatus, host: String): Entry? {
        status.deviceId?.trim()?.takeIf { it.isNotEmpty() }?.lowercase()?.let { id ->
            byId[id]?.let { return it }
        }
        status.mdns?.let {
            val key = DeviceEndpointResolver.sanitizeHost(it).lowercase()
            if (key.isNotEmpty()) byHost[key]?.let { return it }
        }
        status.staIp?.let {
            val key = DeviceEndpointResolver.sanitizeHost(it).lowercase()
            if (key.isNotEmpty()) byHost[key]?.let { return it }
        }
        val hostKey = DeviceEndpointResolver.sanitizeHost(host).lowercase()
        if (hostKey.isNotEmpty()) byHost[hostKey]?.let { return it }
        return null
    }

    companion object {
        val empty = SavedDeviceIndex(emptyMap(), emptyMap())

        fun fromDevices(devices: List<StoredDeviceEntity>): SavedDeviceIndex {
            val entries =
                devices.map { device ->
                    val hosts = mutableSetOf<String>()
                    DeviceEndpointResolver.sanitizeHost(device.mdnsHost).lowercase()
                        .takeIf { it.isNotEmpty() }
                        ?.let { hosts.add(it) }
                    device.staIp?.let {
                        DeviceEndpointResolver.sanitizeHost(it).lowercase()
                            .takeIf { h -> h.isNotEmpty() }
                            ?.let { hosts.add(it) }
                    }
                    Entry(device.deviceId, device.displayName, hosts)
                }
            return fromEntries(entries)
        }

        fun fromEntries(entries: List<Entry>): SavedDeviceIndex {
            val byId = mutableMapOf<String, Entry>()
            val byHost = mutableMapOf<String, Entry>()
            for (entry in entries) {
                byId[entry.deviceId.lowercase()] = entry
                for (host in entry.hosts) byHost[host] = entry
            }
            return SavedDeviceIndex(byId, byHost)
        }

        fun alreadyExistsMessage(displayName: String): String =
            "“$displayName” is already in your device list."
    }
}
