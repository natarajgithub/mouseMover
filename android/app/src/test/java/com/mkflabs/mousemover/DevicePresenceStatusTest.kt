package com.mkflabs.mousemover

import com.mkflabs.mousemover.network.DevicePresenceStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class DevicePresenceStatusTest {
    @Test
    fun offlineWhenUnreachable() {
        assertEquals(
            DevicePresenceStatus.OFFLINE,
            DevicePresenceStatus.resolve(false, true, "192.168.2.161"),
        )
    }

    @Test
    fun readyWhenOnlineJiggleOff() {
        assertEquals(
            DevicePresenceStatus.READY_TO_MOVE,
            DevicePresenceStatus.resolve(true, false, "192.168.2.161"),
        )
    }

    @Test
    fun movingWhenOnlineJiggleOn() {
        assertEquals(
            DevicePresenceStatus.MOVING,
            DevicePresenceStatus.resolve(true, true, "192.168.2.161"),
        )
    }

    @Test
    fun setupWhenNoStaIp() {
        assertEquals(
            DevicePresenceStatus.SETUP,
            DevicePresenceStatus.resolve(true, false, null),
        )
    }
}
