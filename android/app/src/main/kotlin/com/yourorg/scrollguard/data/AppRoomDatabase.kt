package com.yourorg.scrollguard.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.yourorg.scrollguard.data.dao.DailyStatsDao
import com.yourorg.scrollguard.data.dao.GuardEventDao
import com.yourorg.scrollguard.data.dao.PenaltyEventDao
import com.yourorg.scrollguard.data.dao.SessionDao
import com.yourorg.scrollguard.data.entity.DailyStatsEntity
import com.yourorg.scrollguard.data.entity.GuardEventEntity
import com.yourorg.scrollguard.data.entity.PenaltyEventEntity
import com.yourorg.scrollguard.data.entity.SessionEntity

@Database(
    entities = [
        SessionEntity::class,
        DailyStatsEntity::class,
        PenaltyEventEntity::class,
        GuardEventEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class AppRoomDatabase : RoomDatabase() {
    abstract fun sessionDao(): SessionDao
    abstract fun dailyStatsDao(): DailyStatsDao
    abstract fun penaltyEventDao(): PenaltyEventDao
    abstract fun guardEventDao(): GuardEventDao

    companion object {
        @Volatile
        private var INSTANCE: AppRoomDatabase? = null

        fun getInstance(context: Context): AppRoomDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppRoomDatabase::class.java,
                    "scrollguard_native.db"
                ).fallbackToDestructiveMigration()
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
