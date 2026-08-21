import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Applies google-services.json (project connect-dating-app-e2ad4) to
    // this module — must come after com.android.application.
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.connect.connect_dating_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (used for foreground
        // push presentation, spec section 7/13) — it uses java.time APIs
        // under the hood for scheduling, which need desugaring to run on
        // API levels below 26. Matching dependency declared below.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.connect.connect_dating_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key only if key.properties/keystore aren't present
            // (e.g. a fresh checkout without the release keystore) so `flutter run
            // --release` still works locally without failing the build.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Google's own Play Install Referrer library (acquisition-source
    // tracking, spec section 17) — called directly via a MethodChannel
    // in MainActivity.kt instead of through the `android_play_install_referrer`
    // pub.dev wrapper, which is stuck at compileSdk 33 with no newer
    // release and fails Gradle's AAR-metadata check against this
    // project's other dependencies. Compiles against this app's own
    // compileSdk (set above via flutter.compileSdkVersion), so there's
    // no version-skew to hit — same real Google API, no wrapper.
    implementation("com.android.installreferrer:installreferrer:2.2")

    // Pairs with isCoreLibraryDesugaringEnabled above — version chosen
    // as the current latest stable per Google's Maven repo metadata
    // (dl.google.com), not the older 1.2.2 flutter_local_notifications'
    // own README example still shows, since that predates this
    // project's AGP 9.1.0/Gradle 9.3.1.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
