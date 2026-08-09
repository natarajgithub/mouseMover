package com.mkflabs.mousemover

import android.app.Application
import androidx.room.Room
import com.mkflabs.mousemover.data.AppDatabase
import com.mkflabs.mousemover.data.DeviceRepository
import com.mkflabs.mousemover.discovery.AndroidNsdBrowser
import com.mkflabs.mousemover.discovery.NsdBrowser
import com.mkflabs.mousemover.network.OkHttpDeviceApiClient

class MouseMoverApp : Application() {
    lateinit var database: AppDatabase
        private set
    lateinit var repository: DeviceRepository
        private set
    val apiClient by lazy { OkHttpDeviceApiClient() }

    fun nsdBrowser(): NsdBrowser = AndroidNsdBrowser(this)

    override fun onCreate() {
        super.onCreate()
        database =
            Room.databaseBuilder(this, AppDatabase::class.java, "mousemover.db")
                .fallbackToDestructiveMigration()
                .build()
        repository = DeviceRepository(database.deviceDao(), apiClient)
    }
}
