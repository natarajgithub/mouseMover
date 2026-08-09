package com.mkflabs.mousemover.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mkflabs.mousemover.network.DeviceEndpointResolver
import com.mkflabs.mousemover.viewmodel.DeviceDetailViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeviceDetailScreen(
    viewModel: DeviceDetailViewModel,
    onBack: () -> Unit,
) {
    val device by viewModel.device.collectAsState()
    val displayName by viewModel.displayName.collectAsState()
    val apiToken by viewModel.apiToken.collectAsState()
    val error by viewModel.error.collectAsState()
    val deleted by viewModel.deleted.collectAsState()
    var confirmDelete by remember { mutableStateOf(false) }
    val presence = viewModel.presence

    LaunchedEffect(deleted) {
        if (deleted) onBack()
    }

    if (error != null) {
        AlertDialog(
            onDismissRequest = viewModel::clearError,
            confirmButton = { TextButton(onClick = viewModel::clearError) { Text("OK") } },
            title = { Text("Notice") },
            text = { Text(error.orEmpty()) },
        )
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete this device?") },
            text = { Text("This removes it from your saved list on this phone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmDelete = false
                        viewModel.delete()
                    },
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancel") }
            },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(displayName.ifBlank { device?.displayName ?: "Device" }) },
                navigationIcon = {
                    IconButton(
                        onClick = {
                            viewModel.saveMeta()
                            onBack()
                        },
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier =
                Modifier
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
        ) {
            Text("Friendly name", style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(
                value = displayName,
                onValueChange = viewModel::updateDisplayName,
                modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                singleLine = true,
            )

            Text("Status", style = MaterialTheme.typography.titleSmall)
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 8.dp)) {
                androidx.compose.foundation.layout.Box(
                    modifier =
                        Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(Color(presence.ledArgb)),
                )
                Text(presence.title, modifier = Modifier.padding(start = 8.dp))
            }

            device?.let { d ->
                DetailLabeled("Device ID", d.deviceId)
                d.firmwareVersion?.let { DetailLabeled("Firmware", it) }
                DetailLabeled("Hostname", d.mdnsHost)
                val sta = d.staIp
                if (!sta.isNullOrBlank() &&
                    DeviceEndpointResolver.sanitizeHost(sta) !=
                    DeviceEndpointResolver.sanitizeHost(d.mdnsHost)
                ) {
                    DetailLabeled("IP", sta)
                }

                Text("Auth", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(top = 16.dp))
                OutlinedTextField(
                    value = apiToken,
                    onValueChange = viewModel::updateApiToken,
                    label = { Text("API Token (optional)") },
                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                    singleLine = true,
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                ) {
                    Text("Enable jiggle", modifier = Modifier.weight(1f))
                    Switch(checked = d.jiggleEnabled, onCheckedChange = viewModel::setJiggle)
                }

                Button(
                    onClick = { confirmDelete = true },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.fillMaxWidth().padding(top = 24.dp),
                ) {
                    Text("Delete Device")
                }
            }
        }
    }
}

@Composable
private fun DetailLabeled(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(label, modifier = Modifier.weight(0.4f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, modifier = Modifier.weight(0.6f))
    }
}
