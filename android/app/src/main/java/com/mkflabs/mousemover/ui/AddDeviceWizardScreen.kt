package com.mkflabs.mousemover.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Radar
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mkflabs.mousemover.discovery.DiscoveredService
import com.mkflabs.mousemover.network.DeviceEndpointResolver
import com.mkflabs.mousemover.viewmodel.AddDeviceWizardViewModel
import com.mkflabs.mousemover.viewmodel.WizardStep

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddDeviceWizardScreen(
    viewModel: AddDeviceWizardViewModel,
    onDone: () -> Unit,
    onCancel: () -> Unit,
) {
    val step by viewModel.step.collectAsState()
    val candidates by viewModel.candidates.collectAsState()
    val probed by viewModel.probed.collectAsState()
    val displayName by viewModel.displayName.collectAsState()
    val apiToken by viewModel.apiToken.collectAsState()
    val probing by viewModel.probing.collectAsState()
    val saving by viewModel.saving.collectAsState()
    val joining by viewModel.joining.collectAsState()
    val provisioning by viewModel.provisioning.collectAsState()
    val error by viewModel.error.collectAsState()
    val saved by viewModel.saved.collectAsState()
    val softApSsid by viewModel.softApSsid.collectAsState()
    val softApPassword by viewModel.softApPassword.collectAsState()
    val homeSsid by viewModel.homeSsid.collectAsState()
    val homePassword by viewModel.homePassword.collectAsState()
    val manualHost by viewModel.manualHost.collectAsState()
    val wifiStatus by viewModel.wifiStatus.collectAsState()

    LaunchedEffect(saved) {
        if (saved) onDone()
    }

    if (error != null) {
        AlertDialog(
            onDismissRequest = viewModel::clearError,
            confirmButton = { TextButton(onClick = viewModel::clearError) { Text("OK") } },
            title = { Text("Notice") },
            text = { Text(error.orEmpty()) },
        )
    }

    val title =
        when (step) {
            WizardStep.ChoosePath -> "Add Device"
            WizardStep.Scanning -> "Scan Network"
            WizardStep.Confirm -> "Confirm Device"
            else -> "Set Up New Device"
        }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(
                        onClick = {
                            when (step) {
                                WizardStep.ChoosePath -> onCancel()
                                WizardStep.Confirm -> viewModel.backFromConfirm()
                                WizardStep.SoftApJoin -> viewModel.backFromSoftApJoin()
                                WizardStep.SoftApHomeWifi -> viewModel.backFromHomeWifi()
                                WizardStep.SoftApReconnect -> viewModel.backFromReconnect()
                                WizardStep.SoftApDiscover -> viewModel.backFromDiscover()
                                else -> viewModel.backToChoose()
                            }
                        },
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (step == WizardStep.Confirm) {
                        TextButton(
                            onClick = viewModel::save,
                            enabled = displayName.isNotBlank() && !saving,
                        ) { Text("Save") }
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (step) {
                WizardStep.ChoosePath -> ChoosePath(viewModel)
                WizardStep.Scanning ->
                    ScanList(
                        candidates = viewModel.newCandidates,
                        emptyTitle = if (viewModel.hasHiddenKnown) "Already Added" else "Scanning…",
                        emptyBody =
                            if (viewModel.hasHiddenKnown) {
                                "All Mouse Helpers found on the network are already in your device list."
                            } else {
                                "Looking for Mouse Helpers on your local network."
                            },
                        onSelect = viewModel::selectCandidate,
                        enabled = !probing,
                    )
                WizardStep.Confirm ->
                    probed?.let {
                        ConfirmDeviceForm(
                            probed = it,
                            displayName = displayName,
                            onDisplayNameChange = viewModel::updateDisplayName,
                            apiToken = apiToken,
                            onApiTokenChange = viewModel::updateApiToken,
                            showAuthToken = it.status.authRequired,
                        )
                    }
                WizardStep.SoftApInstructions -> SoftApInstructions(viewModel)
                WizardStep.SoftApJoin ->
                    SoftApJoinForm(
                        ssid = softApSsid,
                        password = softApPassword,
                        onSsid = viewModel::updateSoftApSsid,
                        onPassword = viewModel::updateSoftApPassword,
                        onJoin = viewModel::joinSoftAp,
                        onContinue = viewModel::continueWithoutJoining,
                        busy = joining || probing,
                    )
                WizardStep.SoftApHomeWifi ->
                    SoftApHomeWifiForm(
                        wifiStatus = wifiStatus,
                        homeSsid = homeSsid,
                        homePassword = homePassword,
                        onHomeSsid = viewModel::updateHomeSsid,
                        onHomePassword = viewModel::updateHomePassword,
                        onProvision = viewModel::provisionHomeWifi,
                        busy = provisioning,
                    )
                WizardStep.SoftApReconnect -> SoftApReconnect(viewModel)
                WizardStep.SoftApDiscover ->
                    SoftApDiscover(
                        candidates = viewModel.newCandidates,
                        manualHost = manualHost,
                        onManualHost = viewModel::updateManualHost,
                        onSelect = viewModel::selectCandidate,
                        onProbeManual = viewModel::probeManualAddress,
                        probing = probing,
                    )
            }
            if (probing || saving || joining || provisioning) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            }
        }
    }
}

@Composable
private fun ChoosePath(viewModel: AddDeviceWizardViewModel) {
    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ListItem(
            headlineContent = { Text("Scan Local Network") },
            supportingContent = { Text("Find Mouse Helper in your Network") },
            leadingContent = { Icon(Icons.Default.Radar, contentDescription = null) },
            modifier = Modifier.clickable { viewModel.chooseScan() },
        )
        ListItem(
            headlineContent = { Text("Set Up New Device") },
            supportingContent = { Text("Join the device setup network and provision Wi‑Fi.") },
            leadingContent = { Icon(Icons.Default.Wifi, contentDescription = null) },
            modifier = Modifier.clickable { viewModel.chooseSoftAp() },
        )
    }
}

@Composable
private fun SoftApInstructions(viewModel: AddDeviceWizardViewModel) {
    Column(modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
        Text("Before You Start", style = MaterialTheme.typography.titleMedium)
        Text("1. Power on the HID helper.")
        Text("2. Wait for the magenta setup LED.")
        Text("3. The device broadcasts a setup Wi‑Fi network named like `usb-hid-s3-XXXX`.")
        Button(onClick = viewModel::continueFromInstructions, modifier = Modifier.padding(top = 16.dp)) {
            Text("Continue")
        }
    }
}

@Composable
private fun SoftApJoinForm(
    ssid: String,
    password: String,
    onSsid: (String) -> Unit,
    onPassword: (String) -> Unit,
    onJoin: () -> Unit,
    onContinue: () -> Unit,
    busy: Boolean,
) {
    Column(modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
        OutlinedTextField(value = ssid, onValueChange = onSsid, label = { Text("Setup network (SSID)") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(
            value = password,
            onValueChange = onPassword,
            label = { Text("Password (optional)") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
        Text(
            "Join the device Soft‑AP, then we'll connect at 192.168.4.1. Emulator: connect in system Wi‑Fi, then Continue.",
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(vertical = 8.dp),
        )
        Button(onClick = onJoin, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Text("Join Setup Network") }
        TextButton(onClick = onContinue, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Text("Continue") }
    }
}

@Composable
private fun SoftApHomeWifiForm(
    wifiStatus: com.mkflabs.mousemover.network.WifiStatus?,
    homeSsid: String,
    homePassword: String,
    onHomeSsid: (String) -> Unit,
    onHomePassword: (String) -> Unit,
    onProvision: () -> Unit,
    busy: Boolean,
) {
    Column(modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
        wifiStatus?.apSsid?.let { Text("Setup network: $it") }
        wifiStatus?.deviceId?.let { Text("Device ID: $it") }
        OutlinedTextField(
            value = homeSsid,
            onValueChange = onHomeSsid,
            label = { Text("Home Wi‑Fi SSID") },
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
        )
        OutlinedTextField(
            value = homePassword,
            onValueChange = onHomePassword,
            label = { Text("Home Wi‑Fi password") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
        Button(onClick = onProvision, enabled = !busy && homeSsid.isNotBlank(), modifier = Modifier.padding(top = 16.dp).fillMaxWidth()) {
            Text("Save Wi‑Fi to Device")
        }
    }
}

@Composable
private fun SoftApReconnect(viewModel: AddDeviceWizardViewModel) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Reconnect your phone to your home Wi‑Fi, then continue to find the device on the LAN.")
        Button(onClick = viewModel::continueAfterReconnect, modifier = Modifier.padding(top = 16.dp)) {
            Text("Continue")
        }
    }
}

@Composable
private fun SoftApDiscover(
    candidates: List<DiscoveredService>,
    manualHost: String,
    onManualHost: (String) -> Unit,
    onSelect: (DiscoveredService) -> Unit,
    onProbeManual: () -> Unit,
    probing: Boolean,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        Box(modifier = Modifier.weight(1f).heightIn(min = 120.dp)) {
            ScanList(
                candidates = candidates,
                emptyTitle = "Looking for device…",
                emptyBody = "Searching your home network for the provisioned HID helper.",
                onSelect = onSelect,
                enabled = !probing,
            )
        }
        Column(modifier = Modifier.padding(16.dp)) {
            OutlinedTextField(
                value = manualHost,
                onValueChange = onManualHost,
                label = { Text("Host or IP") },
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = onProbeManual,
                enabled = !probing && manualHost.isNotBlank(),
                modifier = Modifier.padding(top = 8.dp),
            ) { Text("Probe Address") }
        }
    }
}

@Composable
private fun ScanList(
    candidates: List<DiscoveredService>,
    emptyTitle: String,
    emptyBody: String,
    onSelect: (DiscoveredService) -> Unit,
    enabled: Boolean,
) {
    if (candidates.isEmpty()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(emptyTitle, style = MaterialTheme.typography.titleLarge)
            Text(emptyBody, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
        }
    } else {
        LazyColumn {
            items(candidates, key = { it.id }) { candidate ->
                ListItem(
                    headlineContent = { Text(candidate.name) },
                    supportingContent = { Text(DeviceEndpointResolver.sanitizeHost(candidate.host)) },
                    overlineContent = candidate.deviceId?.let { { Text(it) } },
                    modifier = Modifier.fillMaxWidth().clickable(enabled = enabled) { onSelect(candidate) },
                )
            }
        }
    }
}
