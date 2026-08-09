package com.mkflabs.mousemover.discovery

import com.mkflabs.mousemover.network.DeviceEndpointResolver

object DiscoveryFilter {
    fun isCandidate(serviceName: String, host: String, txt: Map<String, String>): Boolean {
        if (txt["id"] != null) return true
        val haystack = "$serviceName $host".lowercase()
        return haystack.contains("hid-helper")
    }

    fun deduplicate(services: List<DiscoveredService>): List<DiscoveredService> {
        if (services.size <= 1) return services
        val parent = IntArray(services.size) { it }
        fun find(i: Int): Int {
            var x = i
            while (parent[x] != x) {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }
        fun union(a: Int, b: Int) {
            val ra = find(a)
            val rb = find(b)
            if (ra != rb) parent[rb] = ra
        }
        for (i in services.indices) {
            for (j in i + 1 until services.size) {
                if (shouldMerge(services[i], services[j])) union(i, j)
            }
        }
        val groups = mutableMapOf<Int, MutableList<DiscoveredService>>()
        for (i in services.indices) {
            groups.getOrPut(find(i)) { mutableListOf() }.add(services[i])
        }
        return groups.values.map { prefer(it) }.sortedBy { it.name.lowercase() }
    }

    private fun shouldMerge(a: DiscoveredService, b: DiscoveredService): Boolean {
        val idA = normalizedDeviceId(a)
        val idB = normalizedDeviceId(b)
        if (idA != null && idA == idB) return true
        val ipA = ipv4Host(a.host)
        val ipB = ipv4Host(b.host)
        if (ipA != null && ipA == ipB) return true
        if (isBareHidHelper(a) && isVersionedHidHelper(b)) return true
        if (isBareHidHelper(b) && isVersionedHidHelper(a)) return true
        return false
    }

    private fun prefer(group: List<DiscoveredService>): DiscoveredService {
        val best = group.maxByOrNull(::score) ?: group.first()
        val deviceId = group.mapNotNull { it.deviceId }.firstOrNull { it.isNotEmpty() } ?: best.deviceId
        val host =
            group.mapNotNull { ipv4Host(it.host) }.firstOrNull()
                ?: group.maxByOrNull { scoreHost(it.host) }?.host
                ?: best.host
        val name = group.maxByOrNull { scoreName(it.name) }?.name ?: best.name
        val txt = best.txt.toMutableMap()
        if (deviceId != null && txt["id"] == null) txt["id"] = deviceId
        return DiscoveredService(best.id, deviceId, name, host, best.port, txt)
    }

    private fun score(service: DiscoveredService): Int {
        var value = 0
        if (service.deviceId != null) value += 100
        if (isVersionedHidHelper(service)) value += 50
        if (ipv4Host(service.host) != null) value += 20
        if (!isBareHidHelper(service)) value += 10
        value += minOf(service.name.length, 40)
        return value
    }

    private fun scoreName(name: String): Int {
        val lower = name.lowercase()
        if (Regex("^hid-helper-[0-9a-f]+$").matches(lower)) return 100 + name.length
        if (lower == "hid-helper") return 1
        return name.length
    }

    private fun scoreHost(host: String): Int {
        val sanitized = DeviceEndpointResolver.sanitizeHost(host).lowercase()
        if (ipv4Host(sanitized) != null) return 100
        if (Regex("^hid-helper-[0-9a-f]+\\.local$").matches(sanitized)) return 80
        if (sanitized == "hid-helper.local") return 1
        return 40
    }

    private fun normalizedDeviceId(service: DiscoveredService): String? {
        service.deviceId?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }?.let { return it }
        return service.txt["id"]?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }
    }

    private fun ipv4Host(host: String): String? {
        val sanitized = DeviceEndpointResolver.sanitizeHost(host)
        val parts = sanitized.split('.')
        if (parts.size != 4) return null
        if (parts.any { it.toIntOrNull()?.let { n -> n !in 0..255 } != false }) return null
        return sanitized
    }

    private fun isBareHidHelper(service: DiscoveredService): Boolean {
        val name = service.name.lowercase()
        val host = DeviceEndpointResolver.sanitizeHost(service.host).lowercase()
        return name == "hid-helper" || host == "hid-helper.local"
    }

    private fun isVersionedHidHelper(service: DiscoveredService): Boolean {
        val name = service.name.lowercase()
        val host = DeviceEndpointResolver.sanitizeHost(service.host).lowercase()
        return Regex("^hid-helper-[0-9a-f]+$").matches(name) ||
            Regex("^hid-helper-[0-9a-f]+(\\.local)?$").matches(host)
    }
}
