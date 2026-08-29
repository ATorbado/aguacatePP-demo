import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropsFile = rootProject.file("key.properties")
val hasKeystore = keystorePropsFile.exists()
val useInstalledAppSigningKey =
    providers.gradleProperty("useInstalledAppSigningKey").orNull == "true"
val keystoreProps = Properties().apply {
    if (hasKeystore) load(FileInputStream(keystorePropsFile))
}

android {
    namespace = "com.example.animalesapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.animalesapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (useInstalledAppSigningKey) {
                // Migración in situ: conserva la firma de la app ya instalada.
                signingConfig = signingConfigs.getByName("debug")
            } else if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                println("ADVERTENCIA: falta key.properties; el APK quedará sin firmar.")
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
