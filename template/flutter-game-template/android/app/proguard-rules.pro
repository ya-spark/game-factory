# R8 keep rules for release builds.
#
# WorkManager (pulled in by google_mobile_ads) builds its Room database by reflection at app start.
# Without these rules R8 renames/removes androidx.work.impl.WorkDatabase_Impl and the app crashes
# before the first frame: "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
