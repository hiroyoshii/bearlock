# Bear Lock for Android

Native Kotlin/Android Views product module. The comparison lab is preserved in `../app`.
Package: `com.hiyozoo.bearlock`; min API 26, target/compile API 36. Dependencies are limited to the Android platform and JUnit for domain tests. iOS artwork is reused from this repository.

## Build

```sh
cd android-lab
./gradlew :product:assembleDebug :product:assembleRelease :product:testDebugUnitTest :product:lintDebug
```

Debug APK: `product/build/outputs/apk/debug/product-debug.apk`. Release APK is unsigned unless the signing environment below is supplied. No publishing occurs during builds. The GitHub workflow `.github/workflows/android-ci.yml` builds/tests the module; a remote run is not implied by local verification.

## Product behavior

- Multiple app/domain/category targets; immediate, delayed, dated and weekly repeating schedules.
- One lock lasts 1 minute to 24 hours. New dated schedules may start up to one year ahead. Repeating schedules continue indefinitely in their saved timezone. A DST gap moves to the next valid local time; duration is elapsed minutes, matching the iOS rule model.
- Overlapping locks are rejected, including future repeating occurrences. An active session is persisted independently from its parent. Deleting/editing a recurring parent changes future sessions, while the active snapshot retains its targets/end.
- Upcoming one-time schedules can be edited/deleted. Active one-time locks cannot. Completed sessions do not replay on wall-clock rollback. Device clock changes otherwise re-evaluate absolute timestamps; this is not a tamper-proof clock.
- Versioned JSON is written through AtomicFile; unreadable or unsupported data is retained, not overwritten. Cloud backup and device transfer are excluded. There is no account, network permission, analytics or remote collection. The last three unpinned selections and all pinned selections are retained.
- Categories use ApplicationInfo.category, including newly installed apps. Classification is incomplete and device-dependent; users can add apps individually. Settings, home and dialers are excluded from matching and selection. The app does not support cross-profile enumeration.
- Accessibility restores current foreground window metadata off the main thread and ignores stale callbacks. A local overlay intercepts screen input; it does not stop processes, traffic, notifications or OS-level force stop/revocation.
- Website adapters inspect only known address-bar view IDs in Chrome and Firefox, and only while website sessions are active. No page-tree traversal or URL/history logging. Unknown/hidden address bars and focused editing fields yield no domain. Private tabs/custom tabs/other browsers are not guaranteed. Browser-version validation is separate from adapter implementation.
- Ja/en copy and a per-app language choice are included. Native controls, scrollable screens, system insets, and API 33+ back callback are used.

## Release signing

Supply `BEARLOCK_KEYSTORE`, `BEARLOCK_STORE_PASSWORD`, `BEARLOCK_KEY_ALIAS`, and `BEARLOCK_KEY_PASSWORD` in the build environment. Keep the key and passwords outside git. These are not needed to build an unsigned release for inspection. Configure Play App Signing and upload-key custody before publishing. No key has been generated or uploaded by this implementation.

## QA

`QAHarnessActivity` exists only in `src/debug`. It can add a one-minute lock targeting the bundled probe, or a one-minute reservation two minutes ahead, through the production planner. It cannot reset data or terminate active locks. Debug navigation extras open real product screens and may preselect the probe; they do not provide production unlock paths.

```sh
adb shell am start -n com.hiyozoo.bearlock/.QAHarnessActivity --es action lock
```

`../scripts/product_qa.py` provides UI dump/tap/screenshot helpers for the Windows-hosted emulator used in this workspace. Adapt ADB path and serial for another machine. Always inspect screenshots alongside target-side input logs. Do not classify missing input as a successful block without a positive post-expiry control.

Release-only validation remains in `../../docs/android-implementation-todo.md`: actual device/OEM longevity, Android 17 protection modes, real browser compatibility, accessibility review, Play permission declarations and store signing/distribution.
