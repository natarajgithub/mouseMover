package com.mkflabs.mousemover.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class OkHttpDeviceApiClient(
    private val client: OkHttpClient = defaultClient(),
    private val json: Json = defaultJson(),
) : DeviceApiClient {
    override suspend fun status(baseUrl: String, token: String?): DeviceStatus =
        get(join(baseUrl, "api/status"), token) { body ->
            runCatching { json.decodeFromString<DeviceStatus>(body) }
                .getOrElse { throw DeviceApiException.DecodingFailed(body.take(180)) }
        }

    override suspend fun setJiggle(baseUrl: String, enabled: Boolean, token: String?) {
        post(join(baseUrl, "api/jiggle"), token, json.encodeToString(JiggleRequest(enabled)))
    }

    override suspend fun getWifi(baseUrl: String, token: String?): WifiStatus =
        get(join(baseUrl, "api/wifi"), token) { body ->
            runCatching { json.decodeFromString<WifiStatus>(body) }
                .getOrElse { throw DeviceApiException.DecodingFailed(body.take(180)) }
        }

    override suspend fun provisionWifi(
        baseUrl: String,
        ssid: String,
        password: String,
        token: String?,
    ) {
        post(
            join(baseUrl, "api/wifi"),
            token,
            json.encodeToString(WifiProvisionRequest(ssid, password)),
        )
    }

    private suspend fun <T> get(url: String, token: String?, decode: (String) -> T): T =
        withContext(Dispatchers.IO) {
            val builder = Request.Builder().url(url).get()
            if (!token.isNullOrBlank()) builder.header("X-API-Token", token)
            client.newCall(builder.build()).execute().use { response ->
                validate(response.code)
                val body = response.body?.string().orEmpty()
                decode(body)
            }
        }

    private suspend fun post(url: String, token: String?, jsonBody: String) =
        withContext(Dispatchers.IO) {
            val builder =
                Request.Builder()
                    .url(url)
                    .header("Content-Type", "application/json")
                    .post(jsonBody.toRequestBody(JSON))
            if (!token.isNullOrBlank()) builder.header("X-API-Token", token)
            client.newCall(builder.build()).execute().use { response ->
                validate(response.code)
            }
        }

    private fun validate(code: Int) {
        if (code !in 200..299) throw DeviceApiException.HttpStatus(code)
    }

    private fun join(baseUrl: String, path: String): String {
        val base = if (baseUrl.endsWith("/")) baseUrl else "$baseUrl/"
        return base + path.trimStart('/')
    }

    companion object {
        private val JSON = "application/json; charset=utf-8".toMediaType()

        fun defaultClient(): OkHttpClient =
            OkHttpClient.Builder()
                .connectTimeout(5, TimeUnit.SECONDS)
                .readTimeout(8, TimeUnit.SECONDS)
                .writeTimeout(8, TimeUnit.SECONDS)
                .build()

        fun defaultJson(): Json =
            Json {
                ignoreUnknownKeys = true
                isLenient = true
                coerceInputValues = true
            }
    }
}
