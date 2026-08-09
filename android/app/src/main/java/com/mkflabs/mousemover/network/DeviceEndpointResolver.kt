package com.mkflabs.mousemover.network

import java.net.URI

object DeviceEndpointResolver {
    fun sanitizeHost(host: String): String {
        val trimmed = host.trim()
        val percent = trimmed.indexOf('%')
        return if (percent >= 0) trimmed.substring(0, percent) else trimmed
    }

    fun endpointUrls(mdnsHost: String, staIp: String?): List<String> {
        val urls = LinkedHashSet<String>()
        baseUrl(mdnsHost)?.let { urls.add(it) }
        if (!staIp.isNullOrBlank()) {
            baseUrl(staIp)?.let { urls.add(it) }
        }
        return urls.toList()
    }

    fun baseUrl(host: String): String? {
        val trimmed = sanitizeHost(host)
        if (trimmed.isEmpty()) return null

        val lower = trimmed.lowercase()
        if (lower.startsWith("http://") || lower.startsWith("https://")) {
            return if (trimmed.endsWith("/")) trimmed else "$trimmed/"
        }

        val hostPart =
            if (trimmed.contains(':') && !trimmed.startsWith('[') && !lower.endsWith(".local")) {
                "[$trimmed]"
            } else {
                trimmed
            }
        return "http://$hostPart/"
    }

    fun baseUrl(host: String, port: Int): String? {
        val trimmed = sanitizeHost(host)
        if (trimmed.isEmpty()) return null
        if (port == 80) return baseUrl(trimmed)
        val hostPart =
            if (trimmed.contains(':') && !trimmed.startsWith('[') && !trimmed.lowercase().endsWith(".local")) {
                "[$trimmed]"
            } else {
                trimmed
            }
        return "http://$hostPart:$port/"
    }

    fun hostOf(baseUrl: String): String? =
        runCatching { URI(baseUrl).host }.getOrNull()
}
