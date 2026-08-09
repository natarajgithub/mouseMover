package com.mkflabs.mousemover.wifi

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class AndroidSoftApJoiner(
    context: Context,
) : SoftApJoiner {
    private val appContext = context.applicationContext

    override suspend fun join(ssid: String, password: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw SoftApJoinException(
                "Soft-AP join requires Android 10+. Connect manually in Wi‑Fi settings, then Continue.",
            )
        }
        // Emulators typically cannot bind to a Soft-AP; fail with a manual Continue hint.
        if (isEmulator()) {
            throw SoftApJoinException(
                "Soft-AP join is not available in the emulator. " +
                    "Connect manually in system Wi‑Fi settings, then Continue.",
            )
        }

        val specifierBuilder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (!password.isNullOrEmpty()) {
            specifierBuilder.setWpa2Passphrase(password)
        }
        val request =
            NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .setNetworkSpecifier(specifierBuilder.build())
                .build()

        val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        suspendCancellableCoroutine { cont ->
            val callback =
                object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        cm.bindProcessToNetwork(network)
                        if (cont.isActive) cont.resume(Unit)
                    }

                    override fun onUnavailable() {
                        if (cont.isActive) {
                            cont.resumeWithException(
                                SoftApJoinException(
                                    "Could not join $ssid. Connect manually in Wi‑Fi settings, then Continue.",
                                ),
                            )
                        }
                    }
                }
            cont.invokeOnCancellation {
                runCatching { cm.unregisterNetworkCallback(callback) }
                cm.bindProcessToNetwork(null)
            }
            cm.requestNetwork(request, callback)
        }
    }

    private fun isEmulator(): Boolean {
        val fp = Build.FINGERPRINT.lowercase()
        return fp.contains("generic") ||
            fp.contains("emulator") ||
            Build.MODEL.contains("Emulator", ignoreCase = true) ||
            Build.PRODUCT.contains("sdk", ignoreCase = true)
    }
}
