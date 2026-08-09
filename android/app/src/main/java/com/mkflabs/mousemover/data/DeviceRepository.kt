package com.mkflabs.mousemover.data

import com.mkflabs.mousemover.discovery.DiscoveredService
import com.mkflabs.mousemover.discovery.SavedDeviceIndex
import com.mkflabs.mousemover.network.Device
import com.mkflabs.mousemover.network.DeviceApiClient
import com.mkflabs.mousemover.network.DeviceEndpointResolver
import com.mkflabs.mousemover.network.DeviceStatus
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow

sealed class DeviceRepositoryException(message: String) : Exception(message) {
    data object Unreachable : DeviceRepositoryException("Could not reach the device on the local network.")
    data object NotFound : DeviceRepositoryException("Device not found.")
    data class AlreadyExists(val displayName: String) :
        DeviceRepositoryException(SavedDeviceIndex.alreadyExistsMessage(displayName))
}

data class ProbedDevice(
    val candidate: DiscoveredService,
    val status: DeviceStatus,
    val baseUrl: String,
)

class DeviceRepository(
    private val dao: DeviceDao,
    private val api: DeviceApiClient,
) {
    fun observeDevices(): Flow<List<StoredDeviceEntity>> = dao.observeAll()

    suspend fun getAll(): List<StoredDeviceEntity> = dao.getAll()

    suspend fun refreshAll(devices: List<StoredDeviceEntity>): Set<String> = coroutineScope {
        val results =
            devices.map { device ->
                async {
                    val urls = DeviceEndpointResolver.endpointUrls(device.mdnsHost, device.staIp)
                    var status: DeviceStatus? = null
                    var fallback = device.mdnsHost
                    for (url in urls) {
                        runCatching { api.status(url, device.apiToken) }.onSuccess {
                            status = it
                            fallback = DeviceEndpointResolver.hostOf(url) ?: device.mdnsHost
                            return@async Triple(device.deviceId, status, fallback)
                        }
                    }
                    Triple(device.deviceId, null as DeviceStatus?, fallback)
                }
            }.awaitAll()

        val failed = mutableSetOf<String>()
        for ((deviceId, status, fallback) in results) {
            val device = devices.firstOrNull { it.deviceId == deviceId } ?: continue
            if (status != null) {
                dao.update(applyStatus(device, status, fallback))
            } else {
                failed.add(deviceId)
            }
        }
        failed
    }

    suspend fun addFromDiscovery(
        status: DeviceStatus,
        fallbackHost: String,
        displayName: String,
        token: String?,
    ): StoredDeviceEntity {
        val index = SavedDeviceIndex.fromDevices(dao.getAll())
        index.match(status, fallbackHost)?.let {
            throw DeviceRepositoryException.AlreadyExists(it.displayName)
        }
        val device =
            Device.fromStatus(status, fallbackHost).copy(
                displayName = displayName,
                apiToken = token,
            )
        val entity = StoredDeviceEntity.from(device)
        dao.upsert(entity)
        return dao.getById(entity.deviceId) ?: throw DeviceRepositoryException.NotFound
    }

    suspend fun probeByAddress(host: String, token: String?): ProbedDevice {
        val urls = DeviceEndpointResolver.endpointUrls(host, null)
        if (urls.isEmpty()) throw DeviceRepositoryException.Unreachable
        val index = SavedDeviceIndex.fromDevices(dao.getAll())
        var last: Throwable = DeviceRepositoryException.Unreachable
        for (url in urls) {
            try {
                val status = api.status(url, token)
                val fallback = DeviceEndpointResolver.hostOf(url) ?: host
                index.match(status, fallback)?.let {
                    throw DeviceRepositoryException.AlreadyExists(it.displayName)
                }
                val candidate =
                    DiscoveredService(
                        id = "manual-$fallback",
                        deviceId = status.deviceId,
                        name = status.name,
                        host = fallback,
                        port = 80,
                    )
                return ProbedDevice(candidate, status, url)
            } catch (e: DeviceRepositoryException.AlreadyExists) {
                throw e
            } catch (e: Throwable) {
                last = e
            }
        }
        throw last
    }

    suspend fun setJiggle(device: StoredDeviceEntity, enabled: Boolean) {
        val urls = DeviceEndpointResolver.endpointUrls(device.mdnsHost, device.staIp)
        if (urls.isEmpty()) throw DeviceRepositoryException.Unreachable
        var last: Throwable = DeviceRepositoryException.Unreachable
        for (url in urls) {
            try {
                api.setJiggle(url, enabled, device.apiToken)
                dao.update(device.copy(jiggleEnabled = enabled))
                return
            } catch (e: Throwable) {
                last = e
            }
        }
        throw last
    }

    suspend fun rename(deviceId: String, name: String) {
        val device = dao.getById(deviceId) ?: throw DeviceRepositoryException.NotFound
        dao.update(device.copy(displayName = name))
    }

    suspend fun delete(deviceId: String) {
        dao.deleteById(deviceId)
    }

    suspend fun updateApiToken(deviceId: String, token: String?) {
        val device = dao.getById(deviceId) ?: throw DeviceRepositoryException.NotFound
        val trimmed = token?.trim()?.takeIf { it.isNotEmpty() }
        dao.update(device.copy(apiToken = trimmed))
    }

    private fun applyStatus(
        stored: StoredDeviceEntity,
        status: DeviceStatus,
        fallbackHost: String,
    ): StoredDeviceEntity {
        val mdns =
            when {
                !status.mdns.isNullOrBlank() -> status.mdns
                stored.mdnsHost.isEmpty() -> fallbackHost
                else -> stored.mdnsHost
            }
        return stored.copy(
            mdnsHost = mdns,
            staIp = status.staIp?.takeIf { it.isNotBlank() } ?: stored.staIp,
            jiggleEnabled = status.jiggle,
            lastSeenEpochMs = System.currentTimeMillis(),
            firmwareVersion = status.version,
        )
    }
}
