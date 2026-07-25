plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "jp.komehyappyo.member.next"
    compileSdk = 36

    defaultConfig {
        applicationId = "jp.komehyappyo.member.next"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"kome-org-portal-next-dev\"")
        buildConfigField(
            "String",
            "FIREBASE_WEB_API_KEY",
            "\"AIzaSyDiVMzyOYl143PI43c6GwWPAQLXHEC9pIU\"",
        )
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
    kotlinOptions { jvmTarget = "17" }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":core:model"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:navigation"))
    implementation(project(":core:session"))
    implementation(project(":core:data"))
    implementation(project(":core:notifications"))
    implementation(project(":feature:account"))
    implementation(project(":feature:community"))
    implementation(project(":feature:tools"))

    val composeBom = platform("androidx.compose:compose-bom:2026.06.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.fragment:fragment-ktx:1.8.8")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.1")
}
