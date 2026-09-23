plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.primitivesystems.janzeer.wallet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.primitivesystems.janzeer.wallet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing from the environment (docs/md/deploy_step_by_step.md → "Publishing the wallet app downloads"):
    // JANZEER_KEYSTORE=/path/release.jks JANZEER_KEY_ALIAS JANZEER_KEYSTORE_PASSWORD JANZEER_KEY_PASSWORD. The keystore
    // is generated ONCE and kept offline with the anchors' seeds — every update must be signed with the same key. When
    // unset (dev box, rehearsal) the APK is signed with the debug key so `flutter run --release` and side-loading work.
    val ksPath = System.getenv("JANZEER_KEYSTORE")
    if (ksPath != null && file(ksPath).exists()) {
        signingConfigs {
            create("release") {
                storeFile = file(ksPath)
                storePassword = System.getenv("JANZEER_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("JANZEER_KEY_ALIAS") ?: "janzeer"
                keyPassword = System.getenv("JANZEER_KEY_PASSWORD") ?: System.getenv("JANZEER_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (ksPath != null && file(ksPath).exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
