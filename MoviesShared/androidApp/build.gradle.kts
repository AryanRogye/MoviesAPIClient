import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

val localProperties = Properties()
rootProject.file("local.properties").takeIf { it.isFile }?.inputStream()?.use { stream ->
    localProperties.load(stream)
}

plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeCompiler)
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}
dependencies {
    implementation(project(":sharedLogic"))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.ktx)

    implementation(libs.compose.uiToolingPreview)
    debugImplementation(libs.compose.uiTooling)

    implementation(libs.compose.material3)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    // Bundles Mozilla's own Gecko engine instead of relying on the system
    // WebView provider. On Fire TV that provider is Amazon's forked AWV build,
    // which has real engine bugs (broken vh/percentage-height viewport unit
    // resolution) that a bundled, independently-maintained engine avoids.
    implementation("org.mozilla.geckoview:geckoview:155.0.20260903215306")
}

android {
    namespace = "com.aryanrogye.movies_shared"
    compileSdk = libs.versions.android.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "com.aryanrogye.movies_shared"
        minSdk = libs.versions.android.minSdk.get().toInt()
        targetSdk = libs.versions.android.targetSdk.get().toInt()
        versionCode = 1
        versionName = "1.0"

        val tmdbToken = providers.gradleProperty("TMDB_API_READ_ACCESS_TOKEN")
            .orElse(providers.environmentVariable("TMDB_API_READ_ACCESS_TOKEN"))
            .orElse(localProperties.getProperty("TMDB_API_READ_ACCESS_TOKEN", ""))
            .getOrElse("")
        buildConfigField("String", "TMDB_API_READ_ACCESS_TOKEN", "\"${tmdbToken.replace("\\", "\\\\").replace("\"", "\\\"")}\"")
        ndk {
            abiFilters.add("armeabi-v7a")
        }
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }

    sourceSets.named("main") {
        // Keep the canonical blocker lists beside the iOS implementation. Android
        // compiles them into its own matcher at runtime instead of duplicating them.
        assets.srcDir("../../MoviesAPIClient/Features/WebKit/NetworkFiltering")
        assets.srcDir("../../MoviesAPIClient/Features/WebKit/PopupFiltering")
        assets.srcDir("src/main/assets")
    }
}
