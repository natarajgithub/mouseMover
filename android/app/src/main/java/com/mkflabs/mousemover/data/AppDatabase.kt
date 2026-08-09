package com.mkflabs.mousemover.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface DeviceDao {
    @Query("SELECT * FROM devices ORDER BY displayName COLLATE NOCASE ASC")
    fun observeAll(): Flow<List<StoredDeviceEntity>>

    @Query("SELECT * FROM devices ORDER BY displayName COLLATE NOCASE ASC")
    suspend fun getAll(): List<StoredDeviceEntity>

    @Query("SELECT * FROM devices WHERE deviceId = :deviceId LIMIT 1")
    suspend fun getById(deviceId: String): StoredDeviceEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(device: StoredDeviceEntity)

    @Update
    suspend fun update(device: StoredDeviceEntity)

    @Query("DELETE FROM devices WHERE deviceId = :deviceId")
    suspend fun deleteById(deviceId: String)
}

@Database(entities = [StoredDeviceEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun deviceDao(): DeviceDao
}
