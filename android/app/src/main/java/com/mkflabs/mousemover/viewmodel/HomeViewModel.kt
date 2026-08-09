package com.mkflabs.mousemover.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.mkflabs.mousemover.data.DeviceRepository
import com.mkflabs.mousemover.data.StoredDeviceEntity
import com.mkflabs.mousemover.network.DevicePresenceStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class DeviceListItem(
    val device: StoredDeviceEntity,
    val presence: DevicePresenceStatus,
)

class HomeViewModel(
    private val repository: DeviceRepository,
) : ViewModel() {
    val devices: StateFlow<List<StoredDeviceEntity>> =
        repository.observeDevices().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val _offlineIds = MutableStateFlow<Set<String>>(emptySet())
    val offlineIds: StateFlow<Set<String>> = _offlineIds.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _refreshing = MutableStateFlow(false)
    val refreshing: StateFlow<Boolean> = _refreshing.asStateFlow()

    init {
        refresh()
    }

    fun presenceFor(device: StoredDeviceEntity): DevicePresenceStatus =
        DevicePresenceStatus.resolve(
            isReachable = !_offlineIds.value.contains(device.deviceId),
            jiggleEnabled = device.jiggleEnabled,
            staIp = device.staIp,
        )

    fun refresh() {
        viewModelScope.launch {
            _refreshing.value = true
            _error.value = null
            try {
                val current = repository.getAll()
                _offlineIds.value = repository.refreshAll(current)
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _refreshing.value = false
            }
        }
    }

    fun setJiggle(device: StoredDeviceEntity, enabled: Boolean) {
        viewModelScope.launch {
            try {
                repository.setJiggle(device, enabled)
                _offlineIds.value = _offlineIds.value - device.deviceId
            } catch (e: Exception) {
                _error.value = e.message
            }
        }
    }

    fun clearError() {
        _error.value = null
    }

    companion object {
        fun factory(repository: DeviceRepository): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    HomeViewModel(repository) as T
            }
    }
}
