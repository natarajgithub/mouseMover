package com.mkflabs.mousemover

import android.app.Application
import com.mkflabs.mousemover.network.OkHttpDeviceApiClient

class MouseMoverApp : Application() {
    val apiClient by lazy { OkHttpDeviceApiClient() }
}
