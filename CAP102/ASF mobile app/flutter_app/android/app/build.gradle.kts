import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json — required for Firebase Auth + Cloud
    // Messaging to pick up this project's real Firebase config.
    id("com.google.gms.google-services")
    // Uploads debug symbols/ProGuard mapping for Crashlytics at build time —
    // without this, release-mode (obfuscated) stack traces in the Firebase
    // console would show meaningless renamed class/method names instead of
    // real file/line info.
    id("com.google.firebase.crashlytics")
}

// ── Release signing configuration ──────────────────────────────────────
// Keystore: android/app/asf-release.jks · Alias: asf-key — the SAME
// keystore already used to sign the Capacitor app's release build
// (copied from the project root's android/app/asf-release.jks +
// android/keystore.properties). Credentials live in
// flutter_app/android/keystore.properties (gitignored, never committed)
// rather than hardcoded here. Fails safe: if that file is ever missing,
// release builds fall back to debug signing instead of breaking the build.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.asf.asf_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires this — its AAR metadata
        // declares a hard dependency on core library desugaring (see
        // https://developer.android.com/studio/write/java8-support.html).
        // Confirmed as the sole cause of the first `flutter build apk
        // --release` failure (checkReleaseAarMetadata).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match the Android package_name registered in
        // google-services.json (same Firebase project as the existing
        // Capacitor app, "ph.edu.psau.asf") — otherwise the Google
        // Services Gradle plugin fails at build time with "No matching
        // client found for package name". This intentionally differs from
        // `namespace` above (com.asf.asf_flutter), which only affects
        // generated R-class code, not Firebase/app identity.
        applicationId = "ph.edu.psau.asf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystoreProperties) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing if keystore.properties is
            // missing, instead of failing the build outright.
            signingConfig = if (hasKeystoreProperties) signingConfigs.getByName("release") else signingConfigs.getByName("debug")

            // ── Code + resource shrinking (Task #326: release APK <60MB,
            // release AAB <40MB) ──
            // isMinifyEnabled runs R8 to strip unused classes/members and
            // obfuscate what's left; isShrinkResources removes unused
            // drawables/layouts/strings pulled in transitively by
            // dependencies (Firebase, fl_chart, pdf, etc. all ship far
            // more resources than this app actually references). Debug
            // builds are untouched — this only affects `--release`.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// ── APK size fix (reported: 187 MB APK / 197 MB installed) ─────────────
// Root cause: every plain `flutter build apk` bundles native libraries for
// ALL four Android ABIs (armeabi-v7a, arm64-v8a, x86, x86_64) into one
// "universal" APK by default — a real device only ever needs ONE of these.
// A manual `splits { abi { ... } }` block here conflicts with the Flutter
// Gradle plugin's own NDK abiFilters wiring ("Conflicting configuration...
// ndk abiFilters cannot be present when splits abi filters are set"), so
// the supported fix is the command-line flag instead: build with
// `flutter build apk --split-per-abi` (or `--release --split-per-abi`),
// which produces one much smaller APK per architecture — install
// app-arm64-v8a-*.apk on a physical test device (covers effectively every
// phone from the last ~8 years). The App Bundle build (`flutter build
// appbundle --release`) already gets the same benefit for free via Play
// Store's dynamic delivery. Neither of these touches app code or
// calculations — purely a packaging choice.

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
