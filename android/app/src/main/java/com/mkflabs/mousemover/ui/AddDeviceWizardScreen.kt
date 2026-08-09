package com.mkflabs.mousemover.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Radar
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
    val error by viewModel.error.collectAsState()
    val saved by viewModel.saved.collectAsState()
    val known by viewModel.known.collectAsState()

    LaunchedEffect(saved) {
        if (saved) onDone()
    }

    DisposableEffect(Unit) {
        onDispose { /* ViewModel.onCleared stops browser */ }
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
            WizardStep.SoftApPlaceholder -> "Set Up New Device"
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
                WizardStep.Scanning -> {
                    val visible = candidates.filter { known.match(it) == null }
                    val hidden = candidates.isNotEmpty() && visible.size < candidates.size
                    ScanList(
                        candidates = visible,
                        emptyTitle = if (hidden) "Already Added" else "Scanning…",
                        emptyBody =
                            if (hidden) {
                                "All Mouse Helpers found on the network are already in your device list."
                            } else {
                                "Looking for Mouse Helpers on your local network."
                            },
                        onSelect = viewModel::selectCandidate,
                        enabled = !probing,
                    )
                }
                WizardStep.Confirm -> {
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
                }
                WizardStep.SoftApPlaceholder -> {
                    Column(modifier = Modifier.padding(24.dp)) {
                        Text("Soft-AP setup arrives in the next PR.")
                        Text(
                            "For now use Scan Local Network or Add by Address.",
                            modifier = Modifier.padding(top = 8.dp),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            if (probing || saving) {
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
        Text(
            "Scanning uses mDNS/NSD to find Mouse Helpers on your network",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp),
        )
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
            Text(
                emptyBody,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    } else {
        LazyColumn {
            items(candidates, key = { it.id }) { candidate ->
                ListItem(
                    headlineContent = { Text(candidate.name) },
                    supportingContent = {
                        Text(DeviceEndpointResolver.sanitizeHost(candidate.host))
                    },
                    overlineContent = candidate.deviceId?.let { { Text(it) } },
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .clickable(enabled = enabled) { onSelect(candidate) },
                )
            }
        }
    }
}
