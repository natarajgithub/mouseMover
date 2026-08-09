package com.mkflabs.mousemover.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.mkflabs.mousemover.MouseMoverApp
import com.mkflabs.mousemover.viewmodel.AddByAddressViewModel
import com.mkflabs.mousemover.viewmodel.AddDeviceWizardViewModel
import com.mkflabs.mousemover.viewmodel.DeviceDetailViewModel
import com.mkflabs.mousemover.viewmodel.HomeViewModel
import com.mkflabs.mousemover.wifi.AndroidSoftApJoiner
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect

@Composable
fun MouseMoverNav() {
    val app = LocalContext.current.applicationContext as MouseMoverApp
    val nav = rememberNavController()
    val homeVm: HomeViewModel =
        viewModel(factory = remember { HomeViewModel.factory(app.repository) })

    NavHost(navController = nav, startDestination = "home") {
        composable("home") {
            HomeScreen(
                viewModel = homeVm,
                onOpenDevice = { device ->
                    nav.navigate("detail/${device.deviceId}")
                },
                onAddDevice = { nav.navigate("wizard") },
                onAddByAddress = { nav.navigate("addByAddress") },
            )
        }
        composable(
            route = "detail/{deviceId}",
            arguments = listOf(navArgument("deviceId") { type = NavType.StringType }),
        ) { entry ->
            val deviceId = entry.arguments?.getString("deviceId").orEmpty()
            val vm: DeviceDetailViewModel =
                viewModel(
                    factory =
                        remember(deviceId) {
                            DeviceDetailViewModel.factory(app.repository, deviceId)
                        },
                )
            DeviceDetailScreen(viewModel = vm, onBack = { nav.popBackStack() })
        }
        composable("addByAddress") {
            val vm: AddByAddressViewModel =
                viewModel(factory = remember { AddByAddressViewModel.factory(app.repository) })
            AddByAddressScreen(
                viewModel = vm,
                onDone = {
                    homeVm.refresh()
                    nav.popBackStack()
                },
                onCancel = { nav.popBackStack() },
            )
        }
        composable("wizard") {
            val devices by homeVm.devices.collectAsState()
            val vm: AddDeviceWizardViewModel =
                viewModel(
                    factory =
                        remember {
                            AddDeviceWizardViewModel.factory(
                                repository = app.repository,
                                browser = app.nsdBrowser(),
                                api = app.apiClient,
                                softApJoiner = AndroidSoftApJoiner(app),
                            )
                        },
                )
            LaunchedEffect(devices) {
                vm.updateKnownDevices(devices)
            }
            AddDeviceWizardScreen(
                viewModel = vm,
                onDone = {
                    homeVm.refresh()
                    nav.popBackStack()
                },
                onCancel = { nav.popBackStack() },
            )
        }
    }
}
