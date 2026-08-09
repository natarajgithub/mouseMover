package com.mkflabs.mousemover.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mkflabs.mousemover.data.ProbedDevice
import com.mkflabs.mousemover.network.DeviceEndpointResolver

@Composable
fun ConfirmDeviceForm(
    probed: ProbedDevice,
    displayName: String,
    onDisplayNameChange: (String) -> Unit,
    apiToken: String,
    onApiTokenChange: (String) -> Unit,
    showAuthToken: Boolean,
) {
    Column(modifier = Modifier.verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("Device", style = MaterialTheme.typography.titleMedium)
        LabeledRow("Name", probed.status.name)
        LabeledRow("Version", probed.status.version)
        probed.status.deviceId?.let { LabeledRow("Device ID", it) }
        for (row in addressRows(probed)) {
            LabeledRow(row.first, row.second)
        }

        Text("Friendly name", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
        OutlinedTextField(
            value = displayName,
            onValueChange = onDisplayNameChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Name") },
        )

        if (showAuthToken) {
            Text("API Token", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
            OutlinedTextField(
                value = apiToken,
                onValueChange = onApiTokenChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("API Token") },
            )
            Text(
                "This device requires an API token for control.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun LabeledRow(label: String, value: String) {
    Column(modifier = Modifier.padding(vertical = 4.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyLarge)
    }
}

private fun addressRows(probed: ProbedDevice): List<Pair<String, String>> {
    val ip = probed.status.staIp?.let(DeviceEndpointResolver::sanitizeHost)
    val candidateHost = DeviceEndpointResolver.sanitizeHost(probed.candidate.host)
    val mdns = probed.status.mdns?.let(DeviceEndpointResolver::sanitizeHost)
    val rows = mutableListOf<Pair<String, String>>()
    val seen = mutableSetOf<String>()

    fun append(label: String, value: String?) {
        if (value.isNullOrBlank()) return
        val key = value.lowercase()
        if (!seen.add(key)) return
        rows.add(label to value)
    }

    if (ip != null) append("IP", ip)
    append("Hostname", mdns)
    if (!isIpv4(candidateHost)) {
        append("Hostname", candidateHost)
    } else if (ip == null) {
        append("IP", candidateHost)
    }
    return rows
}

private fun isIpv4(host: String): Boolean {
    val parts = host.split('.')
    return parts.size == 4 && parts.all { it.toIntOrNull()?.let { n -> n in 0..255 } == true }
}
