package com.mkflabs.mousemover.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.mkflabs.mousemover.data.DeviceRepository
import com.mkflabs.mousemover.data.ProbedDevice
import com.mkflabs.mousemover.network.DeviceStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AddByAddressViewModel(
    private val repository: DeviceRepository,
) : ViewModel() {
    enum class Step { Enter, Confirm }

    private val _step = MutableStateFlow(Step.Enter)
    val step: StateFlow<Step> = _step.asStateFlow()

    private val _host = MutableStateFlow("")
    val host: StateFlow<String> = _host.asStateFlow()

    private val _token = MutableStateFlow("")
    val token: StateFlow<String> = _token.asStateFlow()

    private val _displayName = MutableStateFlow("")
    val displayName: StateFlow<String> = _displayName.asStateFlow()

    private val _apiToken = MutableStateFlow("")
    val apiToken: StateFlow<String> = _apiToken.asStateFlow()

    private val _probed = MutableStateFlow<ProbedDevice?>(null)
    val probed: StateFlow<ProbedDevice?> = _probed.asStateFlow()

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _saved = MutableStateFlow(false)
    val saved: StateFlow<Boolean> = _saved.asStateFlow()

    fun updateHost(value: String) {
        _host.value = value
    }

    fun updateToken(value: String) {
        _token.value = value
    }

    fun updateDisplayName(value: String) {
        _displayName.value = value
    }

    fun updateApiToken(value: String) {
        _apiToken.value = value
    }

    fun clearError() {
        _error.value = null
    }

    fun backToEnter() {
        _step.value = Step.Enter
        _probed.value = null
    }

    fun probe() {
        viewModelScope.launch {
            _busy.value = true
            _error.value = null
            try {
                val trimmedHost = _host.value.trim()
                val optionalToken = _token.value.trim().takeIf { it.isNotEmpty() }
                val result = repository.probeByAddress(trimmedHost, optionalToken)
                _probed.value = result
                _displayName.value = defaultDisplayName(result.status)
                _apiToken.value = optionalToken.orEmpty()
                _step.value = Step.Confirm
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _busy.value = false
            }
        }
    }

    fun save() {
        val probed = _probed.value ?: return
        viewModelScope.launch {
            _busy.value = true
            _error.value = null
            try {
                val name = _displayName.value.trim()
                if (name.isEmpty()) {
                    _error.value = "Friendly name is required."
                    return@launch
                }
                val token = _apiToken.value.trim().takeIf { it.isNotEmpty() }
                if (probed.status.authRequired && token == null) {
                    _error.value = "This device requires an API token."
                    return@launch
                }
                repository.addFromDiscovery(
                    status = probed.status,
                    fallbackHost = probed.candidate.host,
                    displayName = name,
                    token = token,
                )
                _saved.value = true
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _busy.value = false
            }
        }
    }

    companion object {
        fun defaultDisplayName(status: DeviceStatus): String {
            val id = status.deviceId
            if (!id.isNullOrEmpty() && id.length >= 4) return id.takeLast(4)
            if (status.name.isNotEmpty()) return status.name
            return "HID Helper"
        }

        fun factory(repository: DeviceRepository): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    AddByAddressViewModel(repository) as T
            }
    }
}
