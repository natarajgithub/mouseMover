package com.mkflabs.mousemover.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.mkflabs.mousemover.data.DeviceRepository
import com.mkflabs.mousemover.data.ProbedDevice
import com.mkflabs.mousemover.data.StoredDeviceEntity
import com.mkflabs.mousemover.discovery.DiscoveredService
import com.mkflabs.mousemover.discovery.NsdBrowser
import com.mkflabs.mousemover.discovery.SavedDeviceIndex
import com.mkflabs.mousemover.network.DeviceApiClient
import com.mkflabs.mousemover.network.DeviceEndpointResolver
import com.mkflabs.mousemover.network.DeviceStatus
import com.mkflabs.mousemover.wifi.SoftApJoiner
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class WizardStep {
    ChoosePath,
    Scanning,
    Confirm,
    SoftApPlaceholder,
}

class AddDeviceWizardViewModel(
    private val repository: DeviceRepository,
    private val browser: NsdBrowser,
    private val api: DeviceApiClient,
    private val softApJoiner: SoftApJoiner,
) : ViewModel() {
    private val _step = MutableStateFlow(WizardStep.ChoosePath)
    val step: StateFlow<WizardStep> = _step.asStateFlow()

    private val _candidates = MutableStateFlow<List<DiscoveredService>>(emptyList())
    val candidates: StateFlow<List<DiscoveredService>> = _candidates.asStateFlow()

    private val _known = MutableStateFlow(SavedDeviceIndex.empty)
    val known: StateFlow<SavedDeviceIndex> = _known.asStateFlow()

    private val _probed = MutableStateFlow<ProbedDevice?>(null)
    val probed: StateFlow<ProbedDevice?> = _probed.asStateFlow()

    private val _displayName = MutableStateFlow("")
    val displayName: StateFlow<String> = _displayName.asStateFlow()

    private val _apiToken = MutableStateFlow("")
    val apiToken: StateFlow<String> = _apiToken.asStateFlow()

    private val _probing = MutableStateFlow(false)
    val probing: StateFlow<Boolean> = _probing.asStateFlow()

    private val _saving = MutableStateFlow(false)
    val saving: StateFlow<Boolean> = _saving.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _saved = MutableStateFlow(false)
    val saved: StateFlow<Boolean> = _saved.asStateFlow()

    val newCandidates: List<DiscoveredService>
        get() = _candidates.value.filter { _known.value.match(it) == null }

    val hasHiddenKnown: Boolean
        get() = _candidates.value.isNotEmpty() && newCandidates.size < _candidates.value.size

    init {
        browser.onUpdate = { services ->
            _candidates.value = services
        }
    }

    fun updateKnownDevices(devices: List<StoredDeviceEntity>) {
        _known.value = SavedDeviceIndex.fromDevices(devices)
    }

    fun chooseScan() {
        _error.value = null
        _step.value = WizardStep.Scanning
        browser.start()
    }

    fun chooseSoftAp() {
        browser.stop()
        _error.value = null
        _step.value = WizardStep.SoftApPlaceholder
    }

    fun backToChoose() {
        browser.stop()
        _candidates.value = emptyList()
        _step.value = WizardStep.ChoosePath
        _error.value = null
    }

    fun backFromConfirm() {
        _error.value = null
        _probed.value = null
        _step.value = WizardStep.Scanning
        browser.start()
    }

    fun updateDisplayName(v: String) {
        _displayName.value = v
    }

    fun updateApiToken(v: String) {
        _apiToken.value = v
    }

    fun clearError() {
        _error.value = null
    }

    fun selectCandidate(candidate: DiscoveredService) {
        viewModelScope.launch {
            _probing.value = true
            _error.value = null
            try {
                _known.value.match(candidate)?.let {
                    _error.value = SavedDeviceIndex.alreadyExistsMessage(it.displayName)
                    return@launch
                }
                val base =
                    DeviceEndpointResolver.baseUrl(candidate.host, candidate.port)
                        ?: run {
                            _error.value = "Could not build a URL for this device."
                            return@launch
                        }
                val status = api.status(base, null)
                _known.value.match(status, candidate.host)?.let {
                    _error.value = SavedDeviceIndex.alreadyExistsMessage(it.displayName)
                    return@launch
                }
                _displayName.value = AddByAddressViewModel.defaultDisplayName(status)
                _apiToken.value = ""
                _probed.value = ProbedDevice(candidate, status, base)
                browser.stop()
                _step.value = WizardStep.Confirm
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _probing.value = false
            }
        }
    }

    fun save() {
        val probed = _probed.value ?: return
        viewModelScope.launch {
            _saving.value = true
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
                repository.addFromDiscovery(probed.status, probed.candidate.host, name, token)
                browser.stop()
                _saved.value = true
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _saving.value = false
            }
        }
    }

    override fun onCleared() {
        browser.stop()
        super.onCleared()
    }

    companion object {
        fun factory(
            repository: DeviceRepository,
            browser: NsdBrowser,
            api: DeviceApiClient,
            softApJoiner: SoftApJoiner,
        ): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    AddDeviceWizardViewModel(repository, browser, api, softApJoiner) as T
            }
    }
}
