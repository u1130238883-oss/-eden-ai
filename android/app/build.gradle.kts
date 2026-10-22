import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

/**
 * 正式簽章金鑰。放在 android/keystore.properties（已被 .gitignore 排除），格式：
 *
 *     storeFile=/絕對路徑/upload.jks
 *     storePassword=...
 *     keyAlias=upload
 *     keyPassword=...
 *
 * 沒有這個檔案時 release 版不簽章，只有 debug 版可以直接安裝。
 * 上傳 Google Play 一定要用自己的金鑰，Play 會拒絕用 debug 金鑰簽的檔案。
 */
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProps.getProperty("storeFile") != null

/** 直連版驗證啟用碼的金鑰，見 gradle.properties。 */
val activationSecret: String =
    (project.findProperty("ninetwelve.activationSecret") as String?) ?: "CHANGE-ME-BEFORE-RELEASE"

android {
    namespace = "com.ninetwelve.fortune"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "ACTIVATION_SECRET", "\"$activationSecret\"")
    }

    signingConfigs {
        // 公開的除錯金鑰，密碼是 Android 的標準預設值，沒有任何保密作用。
        // 存進版控只是為了讓 CI 每次產出的 APK 簽章一致，可以直接覆蓋安裝。
        getByName("debug") {
            storeFile = rootProject.file("keystore/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            isMinifyEnabled = false
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else null
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // locale：兩個語言版本是兩個獨立的 App。
    // store ：發行管道決定收款方式 —— play 走 Play 帳單、direct 走微信／支付寶 + 啟用碼、
    //         free 完全不含付費機制（自己試用與展示用）。
    flavorDimensions += listOf("locale", "store")

    productFlavors {
        // app_name 不寫在這裡，改放各 flavor 的 res/values-<語言>/strings.xml，
        // 主畫面上的名稱才會跟著手機的系統語言換。
        create("cjk") {
            dimension = "locale"
            applicationId = "com.ninetwelve.fortune"
        }
        create("latin") {
            dimension = "locale"
            applicationId = "com.ninetwelve.fortune.latin"
        }
        create("play") {
            dimension = "store"
        }
        create("direct") {
            dimension = "store"
            // 換一個套件名，直連版與 Play 版可以並存，也不會互相覆蓋
            applicationIdSuffix = ".direct"
            versionNameSuffix = "-direct"
        }
        create("free") {
            dimension = "store"
            // 完全解鎖，沒有付費機制；套件名再換一個，三種可以同時安裝
            applicationIdSuffix = ".free"
            versionNameSuffix = "-free"
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Google Play 帳單只有 play flavor 需要；直連版不帶這個函式庫。
    "playImplementation"("com.android.billingclient:billing-ktx:7.1.1")

    testImplementation("junit:junit:4.13.2")
}
