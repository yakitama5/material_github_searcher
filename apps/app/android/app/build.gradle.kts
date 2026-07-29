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
        // applicationId は productFlavors の各 create ブロックで flavor ごとに
        // 上書きするため、ここでは namespace と同じ値を仮のデフォルトとして設定する。
        applicationId = "com.example.material_github_searcher"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    flavorDimensions += "environment"
    productFlavors {
        listOf("dev", "prod").forEach { flavorName ->
            create(flavorName) {
                dimension = "environment"
                val config = readFlavorConfig(flavorName)
                // appIdSuffix だけでなく appIdAndroid 自体も flavor ごとに
                // 独立して切り替えられるよう、flavor 自身の値をそのまま反映する。
                applicationId = config.getValue("appIdAndroid")
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

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
