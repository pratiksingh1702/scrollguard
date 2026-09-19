# ProGuard & R8 Optimization Rules for ScrollGuard

# Flutter Wrapper & Pigeon
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class com.yourorg.scrollguard.bridge.** { *; }

# Room Database & Entities
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**
-keep @androidx.room.Entity class * { *; }
-keep class com.yourorg.scrollguard.data.entity.** { *; }
-keep class com.yourorg.scrollguard.data.dao.** { *; }

# AndroidX WorkManager
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.yourorg.scrollguard.worker.** { *; }

# Accessibility Service & Components
-keep class com.yourorg.scrollguard.service.** { *; }
-keep class com.yourorg.scrollguard.core.** { *; }
-keep class com.yourorg.scrollguard.overlay.** { *; }

# Kotlin Coroutines & Reflection
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**
