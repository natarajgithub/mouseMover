package com.mkflabs.mousemover.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.mkflabs.mousemover.data.DeviceRepository
import com.mkflabs.mousemover.data.StoredDeviceEntity
import com.mkflabs.mousemover.network.DevicePresenceStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class DeviceDetailViewModel(
    private val repository: DeviceRepository,
    private val deviceId: String,
    private val initiallyOffline: Boolean,
) : ViewModel() {
    private val _device = MutableStateFlow<StoredDeviceEntity?>(null)
    val device: StateFlow<StoredDeviceEntity?> = _device.asStateFlow()

    private val _displayName = MutableStateFlow("")
    val displayName: StateFlow<String> = _displayName.asStateFlow()

    private val _apiToken = MutableStateFlow("")
    val apiToken: StateFlow<String> = _apiToken.asStateFlow()

    private val _offline = MutableStateFlow(initiallyOffline)
    val offline: StateFlow<Boolean> = _offline.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _deleted = MutableStateFlow(false)
    val deleted: StateFlow<Boolean> = _deleted.asStateFlow()

    init {
        viewModelScope.launch { reload() }
    }

    val presence: DevicePresenceStatus
        get() {
            val d = _device.value ?: return DevicePresenceStatus.OFFLINE
            return DevicePresenceStatus.resolve(!_offline.value, d.jiggleEnabled, d.staIp)
        }

    fun updateDisplayName(value: String) {
        _displayName.value = value
    }

    fun updateApiToken(value: String) {
        _apiToken.value = value
    }

    fun saveMeta() {
        viewModelScope.launch {
            val name = _displayName.value.trim()
            if (name.isNotEmpty()) repository.rename(deviceId, name)
            repository.updateApiToken(deviceId, _apiToken.value)
            reload()
        }
    }

    fun setJiggle(enabled: Boolean) {
        val current = _device.value ?: return
        viewModelScope.launch {
            try {
                repository.setJiggle(current, enabled)
                _offline.value = false
                reload()
            } catch (e: Exception) {
                _error.value = e.message
            }
        }
    }

    fun delete() {
        viewModelScope.launch {
            repository.delete(deviceId)
            _deleted.value = true
        }
    }

    fun clearError() {
        _error.value = null
    }

    private suspend fun reload() {
        val d = repository.getAll().firstOrNull { it.deviceId == deviceId }
        _device.value = d
        if (d != null) {
            _displayName.value = d.displayName
            _apiToken.value = d.apiToken.orEmpty()
        }
    }

    companion object {
        fun factory(
            repository: DeviceRepository,
            deviceId: String,
            offline: Boolean,
        ): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    DeviceDetailViewModel(repository, deviceId, offline) as T
            }
    }
}
