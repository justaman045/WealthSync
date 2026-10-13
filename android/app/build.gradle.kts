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
    ndkVersion = flutter.ndkVersion

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
