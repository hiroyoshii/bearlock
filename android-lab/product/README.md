# Bear Lock for Android

Native Kotlin/Android Views product module. The comparison lab is preserved in `../app`.
Package: `com.hiyozoo.bearlock`; min API 26, target/compile API 36. Runtime uses Android Views and Material Components; tests use JUnit and JVM org.json to exercise the persisted codec. iOS artwork is reused from this repository.

## Build

```sh
cd android-lab
./gradlew :product:assembleDebug :product:assembleRelease :product:testDebugUnitTest :product:lintDebug
```

Debug APK: `product/build/outputs/apk/debug/product-debug.apk`. Release APK is unsigned unless the signing environment below is supplied. No publishing occurs during builds. The GitHub workflow `.github/workflows/android-ci.yml` builds/tests the module; a remote run is not implied by local verification.

## Product specification

The single current specification is [the product design](../../docs/design-doc.md), including [shared behavior](../../docs/design-doc.md#common), [Android-specific policy and limits](../../docs/design-doc.md#android), [UI](../../docs/design-doc.md#ui), and [current structure](../../docs/design-doc.md#structure). This README owns build, signing and QA instructions only; it does not maintain a second behavior specification.

## Release signing

Supply `BEARLOCK_KEYSTORE`, `BEARLOCK_STORE_PASSWORD`, `BEARLOCK_KEY_ALIAS`, and `BEARLOCK_KEY_PASSWORD` in the build environment. Keep the key and passwords outside git. These are not needed to build an unsigned release for inspection. Configure Play App Signing and upload-key custody before publishing. No key has been generated or uploaded by this implementation.

## Open source notices

Settings → Information → Open source licenses displays bundled notices offline in Debug and Release. The reviewed inventory is `src/main/assets/open-source/libraries.json`; it contains the exact runtime module versions, upstream links, copyright notices and references to shared license texts. Material Icons keeps its revision and modification record in `assets/material-icons/source.json`, which points to the same Apache license text.

Every build runs `verifyOpenSourceLicenses` before `preBuild`. It compares the inventory with both resolved runtime classpaths and fails on missing, changed, removed or duplicate module entries, or missing/empty license texts. Dependency updates require an upstream license/NOTICE review and catalog update; the build check does not infer licensing from a dependency name. Test-only libraries, build tools and BOMs without runtime artifacts are excluded.

The 2026-10-31 review covered 54 distinct runtime modules plus Material Icons, using the resolved AAR/JARs, their published source JARs and POMs, and upstream license records. AndroidX, Material Components, annotations, ListenableFuture and coroutines use Apache 2.0. The [Kotlin standard library license inventory](https://github.com/JetBrains/kotlin/blob/v2.2.21/license/README.md) also identifies GWT/Guava-derived code (Apache 2.0), [ThreeTen-derived time code](https://github.com/JetBrains/kotlin/blob/v2.2.21/license/third_party/threetenbp_license.txt) (BSD 3-Clause) and [Boost-derived math code](https://github.com/JetBrains/kotlin/blob/v2.2.21/license/third_party/boost_LICENSE.txt) (Boost 1.0); these attributions and texts are included. The [coroutines NOTICE](https://github.com/Kotlin/kotlinx.coroutines/blob/1.6.4/license/NOTICE.txt) is preserved verbatim. Copyright lines collected from the published sources retain upstream spelling, including the AndroidX `20188` typo. Kotlin compiler-only and JavaScript-only notices are outside the Android runtime inventory. Local audit inputs and validation output are under ignored `artifacts/oss-audit/`.

The iOS package and Xcode configuration currently reference only the local BearLockCore package and Apple frameworks; no external OSS package was found in those dependency declarations.

Validation on 2026-10-31: Debug/Release APK builds, 74 unit tests and lint completed (no lint errors; warnings remain in existing code). Both APKs contain the catalog and referenced texts byte-for-byte. A temporary Gradle init script adding a test-only library to the runtime classpath correctly failed the inventory check; the unchanged production configuration passed again. The Japanese license list rendered on API 35, but recurring emulator OS/System UI ANRs, including after reboot, prevented completing detail-navigation and 320dp/200% font checks. Those UI checks remain unverified; the emulator failure is not recorded as a pass.

## QA

`QAHarnessActivity` exists only in `src/debug`. It can add a one-minute lock targeting the bundled probe, or a one-minute reservation two minutes ahead, through the production planner. It cannot reset data or terminate active locks. Debug navigation extras open real product screens and may preselect the probe; they do not provide production unlock paths.

```sh
adb shell am start -n com.hiyozoo.bearlock/.QAHarnessActivity --es action lock
```

`../scripts/product_qa.py` provides UI dump/tap/screenshot helpers for the Windows-hosted emulator used in this workspace. Adapt ADB path and serial for another machine. Always inspect screenshots alongside target-side input logs. Do not classify missing input as a successful block without a positive post-expiry control.

`../scripts/product_wake_verify.py` checks booking/cancellation/restart and background expiry on a **disposable emulator only** (`BEARLOCK_DISPOSABLE_QA=1`, explicit `ANDROID_SERIAL`; optional `ADB` / `BEARLOCK_ADB_PORT`). It clears Bear Lock data and keeps the test emulator screen awake. The default shortens only the final expiry fixture; `--real-time` waits for the unchanged 30-minute deadline. `--without-exact-alarm` checks the warning and inexact fallback. Both timing modes require a positive target-input control, block before expiry and restored input afterward without reopening Bear Lock. Losing the foreground target invalidates the run. Results/screenshots are saved under `artifacts/android-product/free-wake[-real-time]`; `--output` selects a separate evidence directory for layout/permission runs.

`RecoveryInstrumentation` uses isolated cache storage and the existing preview display to test actual free-wake dialogs: AtomicFile write failure on booking/cancellation, successful save followed by alarm registration failure, retry without replacing the deadline, stale dialog target, the 30-minute cutoff and weekly editing after wake-up. It also checks started/woken one-shot immutability, immediate-list exclusion, weekly preview changes and touch targets, warning order, corrupt-data preservation and reload. Selection checks cover legacy migration, write failure/retry/cancel, stale legacy preferences and hiding unverified summaries after read failure. Filesystem write refusal works with both older and current AtomicFile implementations. Blocking itself is verified by the probe run, not by this isolated fixture. `LockInstrumentation` remains the native storage/alarm/overlay failure test, including Shield navigation failure/success without writes. Both restore real alarm registration from the original app storage afterward.

The 2026-10-11 evidence is recorded in `../../docs/android-ios-execution-plan.md` and `artifacts/android-product/storage-recovery-fix/`: Android 8/14/15 native recovery tests, Android 14 real UI transactions and regular-tab Chrome 113 / Firefox 153 blocking controls. Browser checks use a tall viewport to keep the address bar and external-page link visible; they do not establish visual parity or private/custom-tab coverage. Quick wake expiry is accelerated, not a 30-minute longevity test.

Remaining release validation is tracked in `../../docs/android-implementation-todo.md`: actual device/OEM longevity, Android 17 protection modes, remaining browser-state compatibility, accessibility review, Play permission declarations and store signing/distribution.
