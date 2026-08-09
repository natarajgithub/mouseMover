package com.mkflabs.mousemover

import com.mkflabs.mousemover.network.DeviceEndpointResolver
import org.junit.Assert.assertEquals
import org.junit.Test

class DeviceEndpointResolverTest {
    @Test
    fun prefersMdnsThenStaIp() {
        val urls =
            DeviceEndpointResolver.endpointUrls(
                mdnsHost = "hid-helper-a1b2.local",
                staIp = "192.168.2.161",
            )
        assertEquals(2, urls.size)
        assertEquals("http://hid-helper-a1b2.local/", urls[0])
        assertEquals("http://192.168.2.161/", urls[1])
    }

    @Test
    fun sanitizesInterfaceZone() {
        assertEquals(
            "192.168.2.161",
            DeviceEndpointResolver.sanitizeHost("192.168.2.161%en0"),
        )
        assertEquals(
            "http://192.168.2.161/",
            DeviceEndpointResolver.baseUrl("192.168.2.161%en0"),
        )
    }

    @Test
    fun deduplicatesSameHost() {
        val urls =
            DeviceEndpointResolver.endpointUrls(
                mdnsHost = "192.168.2.161",
                staIp = "192.168.2.161",
            )
        assertEquals(1, urls.size)
    }
}
