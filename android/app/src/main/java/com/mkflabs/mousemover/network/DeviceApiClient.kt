package com.mkflabs.mousemover.network

sealed class DeviceApiException(message: String) : Exception(message) {
    data object InvalidUrl : DeviceApiException("Could not build a URL for this device.")
    data object InvalidResponse : DeviceApiException("The device returned an invalid response.")
    data class HttpStatus(val code: Int) : DeviceApiException("Device HTTP error ($code).")
    data class DecodingFailed(val detail: String?) :
        DeviceApiException(
            if (!detail.isNullOrBlank()) "Could not read device status: $detail"
            else "Could not read device status JSON.",
        )
}

interface DeviceApiClient {
    suspend fun status(baseUrl: String, token: String? = null): DeviceStatus
    suspend fun setJiggle(baseUrl: String, enabled: Boolean, token: String? = null)
    suspend fun getWifi(baseUrl: String, token: String? = null): WifiStatus
    suspend fun provisionWifi(baseUrl: String, ssid: String, password: String, token: String? = null)
}
