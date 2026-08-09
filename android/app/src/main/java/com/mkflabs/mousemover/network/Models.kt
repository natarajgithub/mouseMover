package com.mkflabs.mousemover.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class DeviceStatus(
    val ok: Boolean = true,
    val name: String = "usb-hid-s3",
    val version: String = "unknown",
    @SerialName("device_id") val deviceId: String? = null,
    val jiggle: Boolean = false,
    @SerialName("jiggle_interval_ms") val jiggleIntervalMs: Int = 10_000,
    @SerialName("sta_ip") val staIp: String? = null,
    val mdns: String? = null,
    @SerialName("auth_required") val authRequired: Boolean = false,
)

@Serializable
data class JiggleRequest(val enabled: Boolean)

@Serializable
data class WifiProvisionRequest(
    val ssid: String,
    val password: String,
)

@Serializable
data class WifiStatus(
    val ok: Boolean? = null,
    val mode: String? = null,
    val configured: Boolean? = null,
    val ssid: String? = null,
    @SerialName("sta_ip") val staIp: String? = null,
    @SerialName("device_id") val deviceId: String? = null,
    @SerialName("ap_ssid") val apSsid: String? = null,
    @SerialName("ap_ip") val apIp: String? = null,
    @SerialName("auth_required") val authRequired: Boolean? = null,
)

data class Device(
    val id: String,
    val displayName: String,
    val mdnsHost: String,
    val staIp: String? = null,
    val apiToken: String? = null,
    val jiggleEnabled: Boolean = false,
    val lastSeenEpochMs: Long? = null,
    val firmwareVersion: String? = null,
) {
    companion object {
        fun fromStatus(status: DeviceStatus, fallbackHost: String): Device {
            val id = status.deviceId ?: fallbackHost
            return Device(
                id = id,
                displayName = status.name,
                mdnsHost = status.mdns ?: fallbackHost,
                staIp = status.staIp?.takeIf { it.isNotBlank() },
                jiggleEnabled = status.jiggle,
                lastSeenEpochMs = System.currentTimeMillis(),
                firmwareVersion = status.version,
            )
        }
    }
}
