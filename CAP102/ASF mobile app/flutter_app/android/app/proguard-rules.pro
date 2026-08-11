# ══════════════════════════════════════════════════════════════════════
# R8/ProGuard rules for release builds (Task: APK/AAB size optimization —
# target release APK <60MB, release AAB <40MB). Flutter's own Gradle
# plugin already contributes its default Dart/embedding keep rules
# automatically whenever minifyEnabled is true, so this file only needs
# the ADDITIONAL rules for plugins with native Android (Kotlin/Java) code
# that R8 would otherwise be free to rename/strip incorrectly, plus the
# few third-party classes R8 warns about but can safely ignore because
# this app never uses them (Play Core split-install / deferred
# components — Flutter references them defensively even when unused).
# ══════════════════════════════════════════════════════════════════════

# --- Play Core (deferred components / split install) ---
# Flutter's embedding references these optionally; this app does not use
# Play Feature Delivery, so missing classes here are safe to ignore
# rather than pulling in the whole play-core artifact just to satisfy R8.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# --- Firebase (Auth, Messaging, Core) ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- flutter_local_notifications ---
# Uses reflection to find the launch activity / receiver classes at
# runtime; stripping/renaming these breaks scheduled reminder taps.
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- sqflite ---
-keep class com.tekartik.sqflite.** { *; }

# --- General Android/Kotlin safety net ---
# Keep anything invoked only via JNI/native calls, and keep enum
# valueOf/values() machinery some plugins rely on reflectively.
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable CREATORs (some plugin models implement Parcelable).
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep annotations/signatures so generic type info survives for any
# reflection-based (de)serialization in plugin code.
-keepattributes Signature, *Annotation*, Exceptions, InnerClasses
