package com.mkflabs.mousemover

import com.mkflabs.mousemover.data.StoredDeviceEntity
import com.mkflabs.mousemover.discovery.DiscoveredService
import com.mkflabs.mousemover.discovery.SavedDeviceIndex
import com.mkflabs.mousemover.network.DeviceStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SavedDeviceIndexTest {
    @Test
    fun matchesByDeviceId() {
        val index =
            SavedDeviceIndex.fromDevices(
                listOf(
                    StoredDeviceEntity(
                        deviceId = "1cdbd4862378",
                        displayName = "Desk",
                        mdnsHost = "hid-helper-2378.local",
                        staIp = "192.168.2.161",
                    ),
                ),
            )
        val match =
            index.match(
                DiscoveredService(
                    id = "1",
                    deviceId = "1cdbd4862378",
                    name = "hid-helper-2378",
                    host = "192.168.2.200",
                    port = 80,
                ),
            )
        assertEquals("Desk", match?.displayName)
    }

    @Test
    fun matchesByIp() {
        val index =
            SavedDeviceIndex.fromDevices(
                listOf(
                    StoredDeviceEntity(
                        deviceId = "abc",
                        displayName = "Lab",
                        mdnsHost = "hid-helper-abcd.local",
                        staIp = "192.168.2.161",
                    ),
                ),
            )
        val match =
            index.match(
                DiscoveredService(
                    id = "1",
                    deviceId = null,
                    name = "hid-helper",
                    host = "192.168.2.161%en0",
                    port = 80,
                ),
            )
        assertEquals("Lab", match?.displayName)
    }

    @Test
    fun noMatchUnknown() {
        assertNull(
            SavedDeviceIndex.empty.match(
                DiscoveredService("1", "new", "hid-helper-new", "192.168.1.1", 80),
            ),
        )
    }

    @Test
    fun matchStatusByStaIp() {
        val index =
            SavedDeviceIndex.fromDevices(
                listOf(
                    StoredDeviceEntity("xyz", "Office", "hid-helper-xyz.local", "10.0.0.5"),
                ),
            )
        val status =
            DeviceStatus(
                deviceId = "other",
                jiggle = false,
                staIp = "10.0.0.5",
                mdns = "hid-helper-other.local",
            )
        assertEquals("Office", index.match(status, "ignored")?.displayName)
    }
}
