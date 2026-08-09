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
import com.mkflabs.mousemover.network.WifiStatus
import com.mkflabs.mousemover.wifi.SoftApJoiner
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class WizardStep {
    ChoosePath,
    Scanning,
    Confirm,
    SoftApInstructions,
    SoftApJoin,
    SoftApHomeWifi,
    SoftApReconnect,
    SoftApDiscover,
}

class AddDeviceWizardViewModel(
    private val repository: DeviceRepository,
    private val browser: NsdBrowser,
    private val api: DeviceApiClient,
    private val softApJoiner: SoftApJoiner,
) : ViewModel() {
    companion object {
        const val SOFT_AP_BASE = "http://192.168.4.1/"
        const val SOFT_AP_SSID_PREFIX = "usb-hid-s3-"

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

    private val _step = MutableStateFlow(WizardStep.ChoosePath)
    val step: StateFlow<WizardStep> = _step.asStateFlow()

    private val _candidates = MutableStateFlow<List<DiscoveredService>>(emptyList())
    val candidates: StateFlow<List<DiscoveredService>> = _candidates.asStateFlow()

    private val _known = MutableStateFlow(SavedDeviceIndex.empty)

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

    private val _joining = MutableStateFlow(false)
    val joining: StateFlow<Boolean> = _joining.asStateFlow()

    private val _provisioning = MutableStateFlow(false)
    val provisioning: StateFlow<Boolean> = _provisioning.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private val _saved = MutableStateFlow(false)
    val saved: StateFlow<Boolean> = _saved.asStateFlow()

    private val _softApSsid = MutableStateFlow(SOFT_AP_SSID_PREFIX)
    val softApSsid: StateFlow<String> = _softApSsid.asStateFlow()

    private val _softApPassword = MutableStateFlow("")
    val softApPassword: StateFlow<String> = _softApPassword.asStateFlow()

    private val _homeSsid = MutableStateFlow("")
    val homeSsid: StateFlow<String> = _homeSsid.asStateFlow()

    private val _homePassword = MutableStateFlow("")
    val homePassword: StateFlow<String> = _homePassword.asStateFlow()

    private val _manualHost = MutableStateFlow("")
    val manualHost: StateFlow<String> = _manualHost.asStateFlow()

    private val _expectedDeviceId = MutableStateFlow<String?>(null)
    private val _wifiStatus = MutableStateFlow<WifiStatus?>(null)
    val wifiStatus: StateFlow<WifiStatus?> = _wifiStatus.asStateFlow()

    val newCandidates: List<DiscoveredService>
        get() {
            val base =
                _expectedDeviceId.value?.let { id ->
                    val matches = _candidates.value.filter { it.deviceId == id }
                    if (matches.isEmpty()) _candidates.value else matches
                } ?: _candidates.value
            return base.filter { _known.value.match(it) == null }
        }

    val hasHiddenKnown: Boolean
        get() = _candidates.value.isNotEmpty() && newCandidates.size < _candidates.value.size

    init {
        browser.onUpdate = { _candidates.value = it }
    }

    fun updateKnownDevices(devices: List<StoredDeviceEntity>) {
        _known.value = SavedDeviceIndex.fromDevices(devices)
    }

    fun updateSoftApSsid(v: String) {
        _softApSsid.value = v
    }

    fun updateSoftApPassword(v: String) {
        _softApPassword.value = v
    }

    fun updateHomeSsid(v: String) {
        _homeSsid.value = v
    }

    fun updateHomePassword(v: String) {
        _homePassword.value = v
    }

    fun updateManualHost(v: String) {
        _manualHost.value = v
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

    fun chooseScan() {
        resetSoftAp()
        _error.value = null
        _step.value = WizardStep.Scanning
        browser.start()
    }

    fun chooseSoftAp() {
        browser.stop()
        resetSoftAp()
        _error.value = null
        _step.value = WizardStep.SoftApInstructions
    }

    fun continueFromInstructions() {
        _error.value = null
        _step.value = WizardStep.SoftApJoin
    }

    fun joinSoftAp() {
        viewModelScope.launch {
            _joining.value = true
            _error.value = null
            try {
                val ssid = _softApSsid.value.trim()
                if (ssid.isEmpty()) {
                    _error.value = "Setup network SSID is required."
                    return@launch
                }
                softApJoiner.join(ssid, _softApPassword.value.trim().takeIf { it.isNotEmpty() })
                probeSoftAp()
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _joining.value = false
            }
        }
    }

    fun continueWithoutJoining() {
        viewModelScope.launch { probeSoftAp() }
    }

    private suspend fun probeSoftAp() {
        _probing.value = true
        _error.value = null
        try {
            val wifi = api.getWifi(SOFT_AP_BASE, null)
            _wifiStatus.value = wifi
            _expectedDeviceId.value = wifi.deviceId
            wifi.apSsid?.takeIf { it.isNotEmpty() && _softApSsid.value == SOFT_AP_SSID_PREFIX }?.let {
                _softApSsid.value = it
            }
            _step.value = WizardStep.SoftApHomeWifi
        } catch (_: Exception) {
            _error.value =
                "Could not reach the device at 192.168.4.1. Join the setup Wi‑Fi network and try again."
        } finally {
            _probing.value = false
        }
    }

    fun provisionHomeWifi() {
        viewModelScope.launch {
            val ssid = _homeSsid.value.trim()
            if (ssid.isEmpty()) {
                _error.value = "Home Wi‑Fi network name is required."
                return@launch
            }
            _provisioning.value = true
            _error.value = null
            try {
                api.provisionWifi(SOFT_AP_BASE, ssid, _homePassword.value, null)
                _step.value = WizardStep.SoftApReconnect
            } catch (e: Exception) {
                _error.value = e.message
            } finally {
                _provisioning.value = false
            }
        }
    }

    fun continueAfterReconnect() {
        _error.value = null
        _step.value = WizardStep.SoftApDiscover
        browser.start()
    }

    fun probeManualAddress() {
        val host = _manualHost.value.trim()
        if (host.isEmpty()) {
            _error.value = "Enter a host or IP address."
            return
        }
        val candidate =
            DiscoveredService(
                id = "manual-$host",
                deviceId = _expectedDeviceId.value,
                name = host,
                host = host,
                port = 80,
            )
        selectCandidate(candidate)
    }

    fun backToChoose() {
        browser.stop()
        _candidates.value = emptyList()
        _step.value = WizardStep.ChoosePath
        _error.value = null
        resetSoftAp()
    }

    fun backFromConfirm() {
        _error.value = null
        _probed.value = null
        if (_expectedDeviceId.value != null) {
            _step.value = WizardStep.SoftApDiscover
            browser.start()
        } else {
            _step.value = WizardStep.Scanning
            browser.start()
        }
    }

    fun backFromSoftApJoin() {
        _error.value = null
        _step.value = WizardStep.SoftApInstructions
    }

    fun backFromHomeWifi() {
        _error.value = null
        _step.value = WizardStep.SoftApJoin
    }

    fun backFromReconnect() {
        _error.value = null
        _step.value = WizardStep.SoftApHomeWifi
    }

    fun backFromDiscover() {
        browser.stop()
        _candidates.value = emptyList()
        _error.value = null
        _step.value = WizardStep.SoftApReconnect
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
                val expected = _expectedDeviceId.value
                if (expected != null && status.deviceId != null && status.deviceId != expected) {
                    _error.value = "This device does not match the one you provisioned."
                    return@launch
                }
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

    private fun resetSoftAp() {
        _softApSsid.value = SOFT_AP_SSID_PREFIX
        _softApPassword.value = ""
        _homeSsid.value = ""
        _homePassword.value = ""
        _manualHost.value = ""
        _expectedDeviceId.value = null
        _wifiStatus.value = null
    }

    override fun onCleared() {
        browser.stop()
        super.onCleared()
    }
}
