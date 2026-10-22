import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase config is added by the owner later (see docs/PUSH_SETUP.md).
// Without google-services.json the app still builds; push is just disabled.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing: the owner's upload key, described by android/key.properties (git-ignored; template in
// key.properties.example). Without it a local `flutter run --release` / `flutter build apk --release` still works,
// signed with the debug key and a loud warning — but an App Bundle for Google Play is refused, because Play would
// reject a debug-signed upload anyway.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()
val requestedTasks = gradle.startParameter.taskNames
val buildsPlayBundle = requestedTasks.any { it.contains("bundleRelease", ignoreCase = true) }
val buildsRelease = requestedTasks.any { it.contains("Release", ignoreCase = true) }
if (!hasReleaseKey && buildsRelease) {
    if (buildsPlayBundle) {
        throw GradleException(
            "android/key.properties is missing: a Google Play App Bundle must be signed with the upload key. " +
                "Copy android/key.properties.example to android/key.properties and fill it in (see RELEASE.md)."
        )
    }
    // logger.error, not warn: `flutter build` only shows Gradle's error stream.
    logger.error(
        "WARNING: android/key.properties not found — the release build is signed with the DEBUG key. " +
            "Fine for a local test, never for Google Play (see RELEASE.md)."
    )
}

android {
    namespace = "mn.uziy.viewer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Store identity (owner, 2026-10-22). Debug builds add ".dev" so both can sit on one phone.
        applicationId = "mn.uziy.viewer"
        // Flutter 3.47 defaults: minSdk 24, compileSdk/targetSdk 36 (Android 16) — what Google Play requires for
        // new apps and updates since 31 Aug 2026. Re-check the target each August (RELEASE.md).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
        }
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            // R8 (minify + resource shrinking, proguard-android-optimize + Flutter's keep rules) is switched on for
            // release by the Flutter Gradle plugin itself. Add an app/proguard-rules.pro only if a release build
            // ever loses a class it needs; the plugin picks that file up automatically.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
