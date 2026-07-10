import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mweastwood.bad_pixel_art"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mweastwood.bad_pixel_art"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ML Kit GenAI Prompt API (com.google.mlkit:genai-prompt) requires at least API level 26
        minSdk = maxOf(flutter.minSdkVersion ?: 0, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "BadPixelArt (Dev)")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "BadPixelArt")
        }
    }

    signingConfigs {
        create("release") {
            val storeFileEnv = System.getenv("ANDROID_KEYSTORE_PATH")
            if (storeFileEnv != null) {
                storeFile = file(storeFileEnv)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            } else {
                val keystorePropertiesFile = rootProject.file("key.properties")
                if (keystorePropertiesFile.exists()) {
                    val properties = Properties().apply {
                        load(keystorePropertiesFile.inputStream())
                    }
                    storeFile = file(properties.getProperty("storeFile"))
                    storePassword = properties.getProperty("storePassword")
                    keyAlias = properties.getProperty("keyAlias")
                    keyPassword = properties.getProperty("keyPassword")
                } else {
                    // Fallback to debug configuration so local development runs don't break
                    val debugConfig = signingConfigs.getByName("debug")
                    storeFile = debugConfig.storeFile
                    storePassword = debugConfig.storePassword
                    keyAlias = debugConfig.keyAlias
                    keyPassword = debugConfig.keyPassword
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
