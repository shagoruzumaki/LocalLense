plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.local_lense"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required for flutter_local_notifications to support Java 8+ APIs
        isCoreLibraryDesugaringEnabled = true
        
        // Using 1.8 compatibility is the most reliable way to satisfy desugaring metadata checks
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.local_lense"
        // minSdk 21 is required for Firebase, Maps, and modern notification features
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Verified stable version for desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    implementation("com.google.firebase:firebase-messaging-ktx:24.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
}

flutter {
    source = "../.."
}
