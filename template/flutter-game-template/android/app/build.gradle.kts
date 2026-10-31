import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Values come from ../../app.config.yaml so there is one source of truth.
// Tiny line-based reader (no YAML dependency): finds `key: value` under a section path.
// ---------------------------------------------------------------------------
val appConfigLines: List<String> = file("../../app.config.yaml").readLines()

fun configValue(vararg path: String): String {
    var depth = 0
    var indentStack = mutableListOf(-1)
    for (raw in appConfigLines) {
        val line = raw.substringBefore(" #")
        if (line.isBlank() || line.trimStart().startsWith("#")) continue
        val indent = line.length - line.trimStart().length
        while (indentStack.size > 1 && indent <= indentStack.last()) {
            indentStack.removeAt(indentStack.size - 1)
            depth--
        }
        val key = line.trim().substringBefore(":").trim()
        val value = line.trim().substringAfter(":", "").trim().trim('"', '\'')
        if (depth < path.size && key == path[depth]) {
            if (depth == path.size - 1) return value
            indentStack.add(indent)
            depth++
        }
    }
    throw GradleException("app.config.yaml: missing ${path.joinToString(".")}")
}

// Release signing: read from android/key.properties, which exists only on CI runners
// (written by release.yml from GitHub secrets). Never commit it.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.flutter_game_template"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications (scheduled notifications).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = configValue("app", "package_name")
        // google_mobile_ads requires minSdk 23+; Flutter's default is already >= 24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["appLabel"] = configValue("app", "display_name")
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
        debug {
            // Debug builds ALWAYS use Google's sample AdMob app ID. Enforced by scripts/ad_safety_check.sh.
            manifestPlaceholders["admobAppId"] = configValue("admob", "debug", "app_id")
        }
        release {
            // Real AdMob app ID from app.config.yaml (admob.release.app_id).
            manifestPlaceholders["admobAppId"] = configValue("admob", "release", "app_id")
            // R8 shrinking is on in release; keep rules live in proguard-rules.pro (WorkManager needs them).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Release is never signed with the debug key. Without key.properties the output is unsigned.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
