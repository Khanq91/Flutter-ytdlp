plugins {
    id("com.android.application")
    id("com.chaquo.python")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_ytdlp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    // Register native source folders before AGP finalizes the variants.
    sourceSets.configureEach {
        jniLibs.srcDir(layout.buildDirectory.dir("generated/curlNative/$name"))
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = System.getenv("STORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    defaultConfig {
        applicationId = "com.example.flutter_ytdlp"
//        minSdk = flutter.minSdkVersion
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.clear()
            abiFilters.addAll(listOf("arm64-v8a", "x86_64"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

chaquopy {
    defaultConfig {
        version = "3.13"
        // Optional local interpreter; CI discovers setup-python on PATH.
        System.getenv("YTDLP_BUILD_PYTHON")?.takeIf { it.isNotBlank() }?.let {
            buildPython(it)
        }
        pip {
            install("yt-dlp")
            // Android arm64 + x86_64 wheels published by the Flet project.
            options("--extra-index-url", "https://pypi.flet.dev")
            install("curl-cffi==0.16.2")
        }
    }
}

flutter {
    source = "../.."
}

// Flet's curl-cffi wheel keeps its C++ runtime under opt/lib. Chaquopy installs
// that directory as Python data; Android's linker needs it in the APK's lib/ABI.
android.applicationVariants.all {
    val variantName = name
    val taskSuffix = variantName.replaceFirstChar { it.uppercaseChar() }
    val nativeOutput = layout.buildDirectory.dir("generated/curlNative/$variantName")
    val prepareCurlRuntime = tasks.register<Sync>("prepare${taskSuffix}CurlRuntime") {
        dependsOn("install${taskSuffix}PythonRequirements")
        from(layout.buildDirectory.dir("python/pip/$variantName")) {
            include("*/opt/lib/libc++_shared.so")
            eachFile {
                path = "${relativePath.segments.first()}/libc++_shared.so"
            }
            includeEmptyDirs = false
        }
        into(nativeOutput)
        doLast {
            for (abi in listOf("arm64-v8a", "x86_64")) {
                check(nativeOutput.get().file("$abi/libc++_shared.so").asFile.isFile) {
                    "Missing curl-cffi C++ runtime for $abi"
                }
            }
        }
    }
    // Prepare before the source folders are scanned, not just before linking.
    tasks.matching { it.name == "merge${taskSuffix}JniLibFolders" }.configureEach {
        dependsOn(prepareCurlRuntime)
    }
}
