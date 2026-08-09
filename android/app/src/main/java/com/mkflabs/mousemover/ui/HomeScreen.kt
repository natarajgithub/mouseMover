package com.mkflabs.mousemover.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Mouse
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.mkflabs.mousemover.data.StoredDeviceEntity
import com.mkflabs.mousemover.network.DevicePresenceStatus
import com.mkflabs.mousemover.viewmodel.HomeViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    onOpenDevice: (StoredDeviceEntity) -> Unit,
    onAddDevice: () -> Unit,
    onAddByAddress: () -> Unit,
) {
    val devices by viewModel.devices.collectAsState()
    val offline by viewModel.offlineIds.collectAsState()
    val refreshing by viewModel.refreshing.collectAsState()
    val error by viewModel.error.collectAsState()
    var menuOpen by remember { mutableStateOf(false) }
    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(lifecycleOwner) {
        lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            viewModel.refreshQuietly()
            while (isActive) {
                delay(HomeViewModel.PRESENCE_POLL_MS)
                viewModel.refreshQuietly()
            }
        }
    }

    if (error != null) {
        AlertDialog(
            onDismissRequest = viewModel::clearError,
            confirmButton = { TextButton(onClick = viewModel::clearError) { Text("OK") } },
            title = { Text("Notice") },
            text = { Text(error.orEmpty()) },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Mouse Mover") },
                actions = {
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Default.Add, contentDescription = "Add")
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = { Text("Add Device") },
                                onClick = {
                                    menuOpen = false
                                    onAddDevice()
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("Add by Address") },
                                onClick = {
                                    menuOpen = false
                                    onAddByAddress()
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = viewModel::refresh,
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(padding),
        ) {
            if (devices.isEmpty()) {
                EmptyHome(onAddDevice = onAddDevice, onAddByAddress = onAddByAddress)
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(vertical = 8.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(devices, key = { it.deviceId }) { device ->
                        val presence =
                            DevicePresenceStatus.resolve(
                                isReachable = !offline.contains(device.deviceId),
                                jiggleEnabled = device.jiggleEnabled,
                                staIp = device.staIp,
                            )
                        DeviceRow(
                            device = device,
                            presence = presence,
                            onClick = { onOpenDevice(device) },
                            onJiggle = { viewModel.setJiggle(device, it) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyHome(onAddDevice: () -> Unit, onAddByAddress: () -> Unit) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Default.Mouse, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        Text("No Devices Yet", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(top = 16.dp))
        Text(
            "Add a HID helper on your local network to get started.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
        )
        TextButton(onClick = onAddDevice) { Text("Add Device") }
        TextButton(onClick = onAddByAddress) { Text("Add by Address") }
    }
}

@Composable
private fun DeviceRow(
    device: StoredDeviceEntity,
    presence: DevicePresenceStatus,
    onClick: () -> Unit,
    onJiggle: (Boolean) -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(Color(presence.ledArgb)),
        )
        Column(modifier = Modifier.padding(start = 12.dp).weight(1f)) {
            Text(device.displayName, style = MaterialTheme.typography.titleMedium)
            Text(presence.title, color = Color(presence.ledArgb), style = MaterialTheme.typography.bodyMedium)
            Text(
                device.mdnsHost.ifBlank { device.staIp ?: "Unknown host" },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(checked = device.jiggleEnabled, onCheckedChange = onJiggle)
    }
}
