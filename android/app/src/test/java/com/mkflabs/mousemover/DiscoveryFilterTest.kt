package com.mkflabs.mousemover

import com.mkflabs.mousemover.discovery.DiscoveredService
import com.mkflabs.mousemover.discovery.DiscoveryFilter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DiscoveryFilterTest {
    @Test
    fun acceptsTxtId() {
        assertTrue(DiscoveryFilter.isCandidate("printer", "office.local", mapOf("id" to "abc")))
    }

    @Test
    fun acceptsHidHelperName() {
        assertTrue(DiscoveryFilter.isCandidate("hid-helper-a1b2", "esp.local", emptyMap()))
    }

    @Test
    fun rejectsUnrelated() {
        assertFalse(DiscoveryFilter.isCandidate("homeassistant", "hass.local", mapOf("path" to "/")))
    }

    @Test
    fun deduplicatesSameIp() {
        val a =
            DiscoveredService("1", null, "hid-helper", "192.168.2.161", 80)
        val b =
            DiscoveredService(
                "2",
                "1cdbd4862378",
                "hid-helper-2378",
                "192.168.2.161",
                80,
                mapOf("id" to "1cdbd4862378"),
            )
        val result = DiscoveryFilter.deduplicate(listOf(a, b))
        assertEquals(1, result.size)
        assertEquals("hid-helper-2378", result[0].name)
        assertEquals("1cdbd4862378", result[0].deviceId)
    }

    @Test
    fun keepsDistinctDevices() {
        val a = DiscoveredService("1", "aaa", "hid-helper-aaaa", "192.168.2.10", 80)
        val b = DiscoveredService("2", "bbb", "hid-helper-bbbb", "192.168.2.20", 80)
        assertEquals(2, DiscoveryFilter.deduplicate(listOf(a, b)).size)
    }
}
