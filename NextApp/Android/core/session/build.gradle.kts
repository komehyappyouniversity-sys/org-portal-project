plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "jp.komehyappyo.member.next.core.session"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    kotlinOptions { jvmTarget = "17" }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":core:model"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
}
