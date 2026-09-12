plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "com.hiyozoo.bearlock"
    compileSdk = 36
    defaultConfig { applicationId = "com.hiyozoo.bearlock"; minSdk = 26; targetSdk = 36; versionCode = 5; versionName = "0.2.0" }
    defaultConfig {
        val licenseKey = System.getenv("BEARLOCK_PLAY_LICENSE_KEY").orEmpty().trim()
        require(licenseKey.matches(Regex("[A-Za-z0-9+/=]*"))) { "Play licensing key must be base64" }
        buildConfigField("String", "PLAY_LICENSE_KEY", "\"$licenseKey\"")
    }
    buildFeatures { buildConfig = true }
    bundle { language { enableSplit = false } }
    val signingPath = System.getenv("BEARLOCK_KEYSTORE")
    if (!signingPath.isNullOrBlank()) {
        signingConfigs.create("upload") {
            storeFile = file(signingPath)
            storePassword = requireNotNull(System.getenv("BEARLOCK_STORE_PASSWORD"))
            keyAlias = requireNotNull(System.getenv("BEARLOCK_KEY_ALIAS"))
            keyPassword = requireNotNull(System.getenv("BEARLOCK_KEY_PASSWORD"))
        }
        buildTypes.getByName("release").signingConfig = signingConfigs.getByName("upload")
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    buildTypes { getByName("release") { isMinifyEnabled = false } }
}
dependencies { implementation("com.android.billingclient:billing:8.3.0"); testImplementation("junit:junit:4.13.2") }
