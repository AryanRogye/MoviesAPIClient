import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.targets.native.tasks.KotlinNativeTest
import java.util.Properties

val localProperties = Properties()
rootProject.file("local.properties").takeIf { it.isFile }?.inputStream()?.use { stream ->
    localProperties.load(stream)
}

val tmdbTestToken = providers.gradleProperty("TMDB_API_READ_ACCESS_TOKEN")
    .orElse(providers.environmentVariable("TMDB_API_READ_ACCESS_TOKEN"))
    .orElse(localProperties.getProperty("TMDB_API_READ_ACCESS_TOKEN", ""))
    .getOrElse("")

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    alias(libs.plugins.kotlinSerialization)
}

tasks.withType<Test>().configureEach {
    environment("TMDB_API_READ_ACCESS_TOKEN", tmdbTestToken)
}

tasks.withType<KotlinNativeTest>().configureEach {
    environment("TMDB_API_READ_ACCESS_TOKEN", tmdbTestToken)
}

kotlin {
    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SharedLogic"
            isStatic = true
        }
    }

    macosArm64().binaries.framework {
        baseName = "SharedLogic"
        isStatic = true
    }

    android {
        namespace = "com.aryanrogye.movies_shared.sharedLogic"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()

        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
        androidResources {
            enable = true
        }
        withHostTest {
            isIncludeAndroidResources = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.serialization.json)

            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.ktor.serialization.json)
        }

        androidMain.dependencies {
            implementation(libs.ktor.client.android)
        }

        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }

        macosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }

        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }
    }
}
