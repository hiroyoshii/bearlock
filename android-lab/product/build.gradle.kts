import groovy.json.JsonSlurper

plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "com.hiyozoo.bearlock"
    compileSdk = 36
    defaultConfig { applicationId = "com.hiyozoo.bearlock"; minSdk = 26; targetSdk = 36; versionCode = 11; versionName = "0.2.4" }
    sourceSets.getByName("test").resources.srcDir("../../Tests/ContractFixtures")
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
dependencies {
    implementation("com.google.android.material:material:1.13.0")
    testImplementation("junit:junit:4.13.2")
    // Execute the actual persisted JSON codec on the JVM, rather than Android's stub methods.
    testImplementation("org.json:json:20240303")
}

// The shipped catalog is also the reviewed dependency inventory. Version changes
// require reviewing upstream licenses/NOTICE files before updating this catalog.
val verifyOpenSourceLicenses by tasks.registering {
    doLast {
        val assets = file("src/main/assets")
        val entries = (JsonSlurper().parse(assets.resolve("open-source/libraries.json")) as List<*>)
            .map { it as Map<*, *> }
        val listed = entries.flatMap { it["artifacts"] as List<*> }.map { it as String }
        check(listed.size == listed.toSet().size) { "Duplicate OSS catalog artifacts" }
        for (variant in listOf("debug", "release")) {
            val actual = configurations.getByName("${variant}RuntimeClasspath")
                .resolvedConfiguration.resolvedArtifacts.map { it.moduleVersion.id.toString() }.toSet()
            check(actual == listed.toSet()) {
                "Review open-source/libraries.json for $variant. Missing: ${actual - listed.toSet()}; stale: ${listed.toSet() - actual}"
            }
        }
        for (entry in entries) {
            check((entry["name"] as String).isNotBlank())
            val texts = if (entry.containsKey("source")) {
                val source = JsonSlurper().parse(assets.resolve(entry["source"] as String)) as Map<*, *>
                listOf(source["licenseFile"] as String)
            } else {
                (entry["texts"] as List<*>).map { it as String }
            }
            check(texts.isNotEmpty()) { "Missing license for ${entry["name"]}" }
            texts.forEach { check(assets.resolve(it).readText().isNotBlank()) { "Empty license: $it" } }
        }
    }
}
tasks.named("preBuild") { dependsOn(verifyOpenSourceLicenses) }
