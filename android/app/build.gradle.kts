plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.modelloader.model_loader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.modelloader.model_loader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24  // ONNX Runtime requires minSdk 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17")
                arguments += listOf("-DANDROID_STL=c++_shared")
                abiFilters += listOf("arm64-v8a", "x86_64")
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

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ONNX Runtime for Android
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.16.3")

    // Gson for JSON parsing (STT vocabulary)
    implementation("com.google.code.gson:gson:2.10.1")

    // MediaPipe LLM Inference (optional - for local inference)
    // implementation("com.google.mediapipe:tasks-llm-inference:0.10.14")
}
