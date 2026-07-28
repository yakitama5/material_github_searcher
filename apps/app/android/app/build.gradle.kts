import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// apps/app/flavor/<flavor>.json を単一のソースとして Gradle と Dart の
// アプリ名・Application ID 設定を共有する。
val flavorDir = rootDir.resolve("../flavor")

fun readFlavorConfig(flavorName: String): Map<String, String> {
    val file = flavorDir.resolve("$flavorName.json")
    @Suppress("UNCHECKED_CAST")
    return JsonSlurper().parse(file) as Map<String, String>
}

android {
    namespace = "com.example.material_github_searcher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true
    }

    defaultConfig {
        // 全 flavor で appIdAndroid の値は共通のため、base の applicationId は
        // prod.json を代表値として読み取る（flavor ごとの差分は appIdSuffix で表現する）。
        applicationId = readFlavorConfig("prod").getValue("appIdAndroid")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        listOf("dev", "prod").forEach { flavorName ->
            create(flavorName) {
                dimension = "environment"
                val config = readFlavorConfig(flavorName)
                config.getValue("appIdSuffix").takeIf { it.isNotEmpty() }?.let {
                    applicationIdSuffix = it
                }
                resValue("string", "app_name", config.getValue("appName"))
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
