plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val firebaseAndroidAppId = providers.gradleProperty("NEXT_FIREBASE_ANDROID_APP_ID")
    .orElse(System.getenv("NEXT_FIREBASE_ANDROID_APP_ID") ?: "")
val firebaseSenderId = providers.gradleProperty("NEXT_FIREBASE_GCM_SENDER_ID")
    .orElse(System.getenv("NEXT_FIREBASE_GCM_SENDER_ID") ?: "")
val productionFirebaseProjectId = providers.gradleProperty("NEXT_FIREBASE_PRODUCTION_PROJECT_ID")
    .orElse(System.getenv("NEXT_FIREBASE_PRODUCTION_PROJECT_ID") ?: "ictnagaoka-member")
val productionFirebaseWebApiKey = providers.gradleProperty("NEXT_FIREBASE_PRODUCTION_WEB_API_KEY")
    .orElse(System.getenv("NEXT_FIREBASE_PRODUCTION_WEB_API_KEY") ?: "")
val productionFirebaseAndroidAppId = providers.gradleProperty("NEXT_FIREBASE_PRODUCTION_ANDROID_APP_ID")
    .orElse(System.getenv("NEXT_FIREBASE_PRODUCTION_ANDROID_APP_ID") ?: "")
val productionFirebaseSenderId = providers.gradleProperty("NEXT_FIREBASE_PRODUCTION_GCM_SENDER_ID")
    .orElse(System.getenv("NEXT_FIREBASE_PRODUCTION_GCM_SENDER_ID") ?: "")

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
        buildConfigField("String", "FIREBASE_ANDROID_APP_ID", "\"${firebaseAndroidAppId.get()}\"")
        buildConfigField("String", "FIREBASE_GCM_SENDER_ID", "\"${firebaseSenderId.get()}\"")
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = false
            buildConfigField(
                "String",
                "FIREBASE_PROJECT_ID",
                "\"${productionFirebaseProjectId.get()}\"",
            )
            buildConfigField(
                "String",
                "FIREBASE_WEB_API_KEY",
                "\"${productionFirebaseWebApiKey.get()}\"",
            )
            buildConfigField(
                "String",
                "FIREBASE_ANDROID_APP_ID",
                "\"${productionFirebaseAndroidAppId.get()}\"",
            )
            buildConfigField(
                "String",
                "FIREBASE_GCM_SENDER_ID",
                "\"${productionFirebaseSenderId.get()}\"",
            )
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
    implementation(project(":feature:messages"))
    implementation(project(":feature:tools"))

    val composeBom = platform("androidx.compose:compose-bom:2026.06.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.fragment:fragment-ktx:1.8.8")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.1")
}
