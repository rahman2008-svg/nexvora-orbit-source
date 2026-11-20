plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nexvora.orbit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs core-library desugaring for the
        // java.time APIs it uses when scheduling reminders.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.nexvora.orbit"
        // libcactus.so is built only for arm64-v8a, so restrict the APK to that ABI.
        // The `record` mic plugin requires API 23+, so floor minSdk at 23.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    // Stable release signing so published APKs update each other in place.
    // The keystore comes from ORBIT_KEYSTORE_PATH/ORBIT_KEYSTORE_PASSWORD (CI
    // decodes them from repo secrets) or from ~/.keys/orbit-release.keystore +
    // .pass locally. Without either, falls back to debug signing so any clone
    // still builds.
    val home = System.getProperty("user.home")
    val orbitKeystore = file(
        System.getenv("ORBIT_KEYSTORE_PATH") ?: "$home/.keys/orbit-release.keystore")
    val orbitPassFile = file("$home/.keys/orbit-release.pass")
    val orbitKeystorePass = System.getenv("ORBIT_KEYSTORE_PASSWORD")
        ?: if (orbitPassFile.exists()) orbitPassFile.readText().trim() else null

    signingConfigs {
        if (orbitKeystore.exists() && orbitKeystorePass != null) {
            create("release") {
                storeFile = orbitKeystore
                storePassword = orbitKeystorePass
                keyAlias = "orbit"
                keyPassword = orbitKeystorePass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            // R8 shrinking is on; ship our keep rules so flutter_local_notifications'
            // Gson (de)serialization survives minification.
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications (core-library desugaring).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Build (or restore from cache) the native FFI library before assembling the
// app, so it never has to be produced by hand. native/build.sh is
// content-addressed: it skips in ~0.02s when libcactus.so is already current and
// restores from a machine-level cache otherwise (see native/README.md). A real
// change to the native sources triggers a recompile, which needs the Android
// NDK. Skipped on Windows / if the script is absent (the lib is arm64-only and
// developed on Linux/macOS).
val ensureNativeFfi by tasks.registering(Exec::class) {
    val script = rootProject.file("../native/build.sh")
    onlyIf {
        script.exists() &&
            !System.getProperty("os.name").lowercase().contains("windows")
    }
    workingDir = rootProject.projectDir
    // Expose the SDK so build.sh can locate the NDK if an actual recompile is
    // needed (cache hits don't need it).
    environment("ANDROID_HOME", android.sdkDirectory.absolutePath)
    commandLine("bash", script.absolutePath)
}

// Build (or restore) the offline-Wikipedia native bits (libzimffi.so + the
// prebuilt libzim.so + libc++_shared.so + ICU data). build_zim.sh downloads the
// prebuilt libzim once and caches it; it only recompiles the small shim when its
// source changes. Same guards as the FFI task above.
val ensureZimFfi by tasks.registering(Exec::class) {
    val script = rootProject.file("../native_zim/build_zim.sh")
    onlyIf {
        script.exists() &&
            !System.getProperty("os.name").lowercase().contains("windows")
    }
    workingDir = rootProject.projectDir
    environment("ANDROID_HOME", android.sdkDirectory.absolutePath)
    commandLine("bash", script.absolutePath)
}

tasks.named("preBuild") {
    dependsOn(ensureNativeFfi)
    dependsOn(ensureZimFfi)
}
