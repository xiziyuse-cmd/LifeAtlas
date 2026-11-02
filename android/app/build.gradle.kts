plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStoreFile = System.getenv("LIFEATLAS_RELEASE_STORE_FILE")
val allowDebugRelease = System.getenv("LIFEATLAS_ALLOW_DEBUG_RELEASE") == "true"

android {
    namespace = "com.example.lifeatlas"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.lifeatlas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("lifeatlasRelease") {
                storeFile = file(releaseStoreFile)
                storePassword = System.getenv("LIFEATLAS_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("LIFEATLAS_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("LIFEATLAS_RELEASE_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            if (releaseStoreFile != null) {
                signingConfig = signingConfigs.getByName("lifeatlasRelease")
            } else if (allowDebugRelease) {
                // CI validation only. These packages must never be published as stable updates.
                signingConfig = signingConfigs.getByName("debug")
            } else {
                signingConfig = null
            }
        }
    }

}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// Refuse unsigned official release tasks; ordinary debug development remains available.
gradle.taskGraph.whenReady {
    if (!allowDebugRelease && releaseStoreFile == null && allTasks.any { it.name == "assembleRelease" || it.name == "bundleRelease" }) {
        throw GradleException("Configure the fixed LifeAtlas release keystore before building a distributable release.")
    }
}
