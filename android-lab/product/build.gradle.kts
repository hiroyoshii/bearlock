plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "com.hiyozoo.bearlock"
    compileSdk = 36
    defaultConfig { applicationId = "com.hiyozoo.bearlock"; minSdk = 26; targetSdk = 36; versionCode = 2; versionName = "0.1.1" }
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
dependencies { testImplementation("junit:junit:4.13.2") }
