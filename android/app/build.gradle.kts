import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.vercel.justaman045.money_control"
    compileSdk = flutter.compileSdkVersion
    // This app ships no native code of its own; the NDK is only resolved at
    // configure time because this line is set (AGP needs an NDK to strip debug
    // symbols from the Firebase/ML Kit .so files). Flutter 3.47.7 defaults to
    // 28.2.13676358, which is NOT preinstalled on the GitHub ubuntu-24.04 runner,
    // so AGP tries to download ~1 GB and has corrupted mid-build ("Error on
    // ZipFile: unknown archive"). CI sets ANDROID_NDK_VERSION to an NDK already
    // on the runner (see .github/workflows/flutter_build.yml) to skip the
    // download; locally the env var is unset and Flutter's default is used.
    ndkVersion = System.getenv("ANDROID_NDK_VERSION") ?: flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "app.vercel.justaman045.money_control"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Fall back to debug keystore when env vars aren't set
            val keystorePass = System.getenv("KEYSTORE_PASSWORD")
            if (!keystorePass.isNullOrBlank()) {
                storeFile = file("../upload-keystore.jks")
                storePassword = keystorePass
                keyAlias = System.getenv("KEY_ALIAS") ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            } else {
                storeFile = file("../debug-keystore.jks")
                storePassword = "android"
                keyAlias = "debug"
                keyPassword = "android"
            }
            // Sign with every scheme: v1 (JAR) keeps the APK installable by
            // older/OEM package installers and file managers that don't verify
            // v2/v3, and v3 enables future key rotation. minSdk 24 makes AGP
            // default to v2-only, which some sideload paths report as a
            // "corrupted package".
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // R8 minify + resource shrink: the app only uses the Latin ML Kit
            // model and Dart-side dead code is large; shrinking cuts APK size
            // and startup JIT/AOT work on low-end devices.
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

dependencies {
    // kotlin-stdlib-jdk7:1.8.0 removed — conflicts with Flutter's Kotlin version.
    // google-services:4.4.2 removed — it's a Gradle plugin (in plugins {}), not a runtime dep.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Only the Latin script model is used (receipt scanner). Non-Latin ML Kit
    // packs (chinese/devanagari/japanese/korean) were removed to shrink the APK.
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
