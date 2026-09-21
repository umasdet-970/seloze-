# Flutter engine and plugins are invoked via reflection/JNI from native code,
# so R8 can't see those call sites — without these keep rules, minification
# strips classes that are only referenced from the native/embedding side and
# the release build crashes on startup while the debug build (unminified)
# works fine.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's engine references Play Core's split-install API for deferred
# components (Play Feature Delivery), which this app doesn't use and whose
# library isn't bundled by default — without these, R8 fails the build
# entirely rather than just warning.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# WorkManager (pulled in by the Firebase libraries) builds its Room database
# by looking up a generated class (WorkDatabase_Impl) by name. Without these,
# R8 removes or renames it and the RELEASE app crashes before its first
# screen with "Failed to create an instance of androidx.work.impl.WorkDatabase"
# (debug builds are not shrunk, so they never show it).
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); *; }
-keep class androidx.room.** { *; }
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.paging.**
