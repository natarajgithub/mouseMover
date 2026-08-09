package com.mkflabs.mousemover.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.mkflabs.mousemover.network.Device

@Entity(tableName = "devices")
data class StoredDeviceEntity(
    @PrimaryKey val deviceId: String,
    val displayName: String,
    val mdnsHost: String,
    val staIp: String? = null,
    val apiToken: String? = null,
    val jiggleEnabled: Boolean = false,
    val lastSeenEpochMs: Long? = null,
    val firmwareVersion: String? = null,
) {
    fun toDevice(): Device =
        Device(
            id = deviceId,
            displayName = displayName,
            mdnsHost = mdnsHost,
            staIp = staIp,
            apiToken = apiToken,
            jiggleEnabled = jiggleEnabled,
            lastSeenEpochMs = lastSeenEpochMs,
            firmwareVersion = firmwareVersion,
        )

    companion object {
        fun from(device: Device): StoredDeviceEntity =
            StoredDeviceEntity(
                deviceId = device.id,
                displayName = device.displayName,
                mdnsHost = device.mdnsHost,
                staIp = device.staIp,
                apiToken = device.apiToken,
                jiggleEnabled = device.jiggleEnabled,
                lastSeenEpochMs = device.lastSeenEpochMs,
                firmwareVersion = device.firmwareVersion,
            )
    }
}
