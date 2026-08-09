package com.mkflabs.mousemover

import com.mkflabs.mousemover.network.DeviceStatus
import com.mkflabs.mousemover.network.OkHttpDeviceApiClient
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceStatusDecodeTest {
    private val json = OkHttpDeviceApiClient.defaultJson()

    @Test
    fun decodesFirmware040Shape() {
        val raw =
            """
            {
              "ok": true,
              "name": "usb-hid-s3",
              "version": "0.4.0",
              "device_id": "a1b2c3d4",
              "jiggle": false,
              "jiggle_interval_ms": 10000,
              "sta_ip": "192.168.2.161",
              "mdns": "hid-helper-a1b2.local",
              "auth_required": false
            }
            """.trimIndent()

        val status = json.decodeFromString<DeviceStatus>(raw)
        assertTrue(status.ok)
        assertEquals("usb-hid-s3", status.name)
        assertEquals("0.4.0", status.version)
        assertEquals("a1b2c3d4", status.deviceId)
        assertFalse(status.jiggle)
        assertEquals(10_000, status.jiggleIntervalMs)
        assertEquals("192.168.2.161", status.staIp)
        assertEquals("hid-helper-a1b2.local", status.mdns)
        assertFalse(status.authRequired)
    }

    @Test
    fun decodesLegacyWithoutAuthRequired() {
        val raw =
            """
            {
              "ok": true,
              "name": "usb-hid-s3",
              "version": "0.3.3",
              "usb": "not-ready",
              "jiggle": true,
              "jiggle_interval_ms": 10000,
              "sta_ip": "192.168.2.161"
            }
            """.trimIndent()

        val status = json.decodeFromString<DeviceStatus>(raw)
        assertEquals("0.3.3", status.version)
        assertTrue(status.jiggle)
        assertNull(status.deviceId)
        assertFalse(status.authRequired)
        assertEquals("192.168.2.161", status.staIp)
    }
}
