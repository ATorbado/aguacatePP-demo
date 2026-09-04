import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
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
    namespace = "com.example.inspecciones"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.inspecciones"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

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
                // La autorización general exige la misma firma que las demás apps.
                signingConfig = signingConfigs.getByName("debug")
            } else if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                println("ADVERTENCIA: falta key.properties; se usará la firma de desarrollo.")
                signingConfig = signingConfigs.getByName("debug")
            }
            // isMinifyEnabled = false
        }
    }
}

flutter { source = "../.." }
