pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Needed for android/app/google-services.json (Firebase Auth + Cloud
    // Messaging) to actually be processed at build time.
    id("com.google.gms.google-services") version "4.4.2" apply false
    // Needed for firebase_crashlytics — uploads native debug symbols/mapping
    // at build time so a release-mode (obfuscated/stripped) crash still
    // symbolicates back to real file/line info in the Firebase console.
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}

include(":app")
