plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "com.hiyozoo.bearlock.lab"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.hiyozoo.bearlock.lab"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1-lab"
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies { testImplementation("junit:junit:4.13.2") }
