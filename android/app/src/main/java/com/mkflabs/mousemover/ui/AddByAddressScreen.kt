package com.mkflabs.mousemover.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import com.mkflabs.mousemover.viewmodel.AddByAddressViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddByAddressScreen(
    viewModel: AddByAddressViewModel,
    onDone: () -> Unit,
    onCancel: () -> Unit,
) {
    val step by viewModel.step.collectAsState()
    val host by viewModel.host.collectAsState()
    val token by viewModel.token.collectAsState()
    val displayName by viewModel.displayName.collectAsState()
    val apiToken by viewModel.apiToken.collectAsState()
    val probed by viewModel.probed.collectAsState()
    val busy by viewModel.busy.collectAsState()
    val error by viewModel.error.collectAsState()
    val saved by viewModel.saved.collectAsState()

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

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(if (step == AddByAddressViewModel.Step.Confirm) "Confirm Device" else "Add by Address")
                },
                navigationIcon = {
                    IconButton(
                        onClick = {
                            if (step == AddByAddressViewModel.Step.Confirm) viewModel.backToEnter()
                            else onCancel()
                        },
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    when (step) {
                        AddByAddressViewModel.Step.Enter ->
                            TextButton(
                                onClick = viewModel::probe,
                                enabled = host.isNotBlank() && !busy,
                            ) { Text("Next") }
                        AddByAddressViewModel.Step.Confirm ->
                            TextButton(
                                onClick = viewModel::save,
                                enabled = displayName.isNotBlank() && !busy,
                            ) { Text("Save") }
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (step) {
                AddByAddressViewModel.Step.Enter -> {
                    ColumnEnter(host, token, viewModel::updateHost, viewModel::updateToken)
                }
                AddByAddressViewModel.Step.Confirm -> {
                    probed?.let {
                        ConfirmDeviceForm(
                            probed = it,
                            displayName = displayName,
                            onDisplayNameChange = viewModel::updateDisplayName,
                            apiToken = apiToken,
                            onApiTokenChange = viewModel::updateApiToken,
                            showAuthToken = it.status.authRequired || token.isNotBlank(),
                        )
                    }
                }
            }
            if (busy) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            }
        }
    }
}

@Composable
private fun ColumnEnter(
    host: String,
    token: String,
    onHost: (String) -> Unit,
    onToken: (String) -> Unit,
) {
    androidx.compose.foundation.layout.Column(
        modifier =
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
    ) {
        OutlinedTextField(
            value = host,
            onValueChange = onHost,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Host or IP") },
            placeholder = { Text("hid-helper.local or 192.168.2.161") },
        )
        OutlinedTextField(
            value = token,
            onValueChange = onToken,
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            singleLine = true,
            label = { Text("API Token (optional)") },
        )
        Text(
            "We'll look up the device and let you confirm before saving.",
            modifier = Modifier.padding(top = 12.dp),
        )
    }
}
