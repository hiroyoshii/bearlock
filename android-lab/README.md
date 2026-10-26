# Bear Lock Android comparison lab

`app` and `probe` are bounded engineering experiments with separate application IDs. `product` is the Android implementation (`com.hiyozoo.bearlock`), using Kotlin and native Views. Its UI now follows the existing iOS composition and assets; see [UI parity and validation](../docs/android-ui-parity.md) and [screenshot comparison](../ANDROID_SCREENSHOTS.md). Android release/device certification remains separate.

## Build

Requirements: JDK 17, Android SDK platform 36 and build tools, Gradle wrapper (included).

```sh
cd android-lab
export ANDROID_HOME=/home/hiroyoshii/Android/Sdk
./gradlew :app:assembleDebug :probe:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

Install both `app/build/outputs/apk/debug/app-debug.apk` and `probe/build/outputs/apk/debug/probe-debug.apk` with ADB or Android Studio. Open Bear Lock Lab, choose Bear Lock Probe, grant the permissions needed for the selected method, and confirm a 5–300 second experiment. Start delay is 0–300 seconds. A pending or active experiment cannot be replaced; there is no in-app early-end operation. OS revocation/uninstall remain available.

## What is being compared

| | A: USAGE | B: ACCESSIBILITY |
| --- | --- | --- |
| Detection | UsageStatsManager events, polled every 250 ms while the display is interactive | Window-state events plus current-window root package metadata on recovery; no text or child-node traversal |
| Blocking | TYPE_APPLICATION_OVERLAY | TYPE_ACCESSIBILITY_OVERLAY |
| Background | Foreground service with visible notification | System-bound accessibility service |
| Scheduling | Same persisted window and exact-alarm receiver | Same persisted window and exact-alarm receiver |
| Reconciliation | Shared 250 ms time check while process executes | Shared 250 ms time check while process executes |

This compares two complete approaches, not detection APIs in isolation. B's overlay type differs from A. A's `specialUse` foreground-service declaration is for this experiment; Play acceptance has not been established. B does not set `isAccessibilityTool=true`.

Schedules are persisted and re-registered after boot/time changes. Alarm or foreground-service failures are logged. Exact alarms do not replace runtime state reconciliation; Doze quotas can delay closely spaced alarm delivery. Usage history cannot guarantee current visible windows in all multi-window cases. B rechecks the current focused/active window after service connection and window/schedule changes. It reads only the root package name, with window-content access declared and disclosed. Reads run off the main thread, retry temporarily unavailable roots, and discard results superseded by newer events or service destruction. Multi-window behavior remains unverified. These limitations are test targets, not resolved guarantees.

## Measurements

Local JSONL logs: `adb shell run-as com.hiyozoo.bearlock.lab cat files/events.jsonl`.
Logcat tags: `BearLockLab` and `BearLockProbe`. The app has no Internet permission. Unrelated app package identities and screen content are not logged. Logs rotate at roughly 1 MB; pull each experiment's results before long runs.

- `foreground_snapshot`, `snapshot_retry`, `snapshot_unavailable`: recovery metadata and retry evidence.
- `foreground_changed`: source event timestamp and whether it is the selected target.
- `overlay_added`: successful WindowManager.addView return, not proof of on-screen visibility.
- `overlay_frame`: first frame callback, still not proof of compositor output or intercepted input.
- Probe `resume` and `tap`: independent target-side timestamps and delivered input count.
- `phase`, `schedule_receiver`, permission/service errors: start/end and recovery evidence.

Measure ordinary launch delay from Probe's resume timestamp to overlay addition, and scheduled onset from the saved start. Do not combine those baselines. Validate screenshots and target-side tap records: an overlay may be attached but hidden by the OS/target app. Emulator timings are exploratory, not production benchmarks or battery measurements.

The debug-only `ExperimentActivity` supports ADB automation against **only** the bundled probe. It still enforces permissions and the 5-minute/immutability bounds. It is absent from release builds:

```sh
adb shell am start -n com.hiyozoo.bearlock.lab/.ExperimentActivity --es method USAGE --ei delay 0 --ei duration 10
adb shell am start -n com.hiyozoo.bearlock.probe/.ProbeActivity
```

Do not enable Accessibility while measuring A; disable it between series. Use the same emulator/conditions for both methods. Capture cold and warm launches separately.

Automated emulator runs (after installing both APKs):

```sh
python3 scripts/compare.py --adb /path/to/adb --serial emulator-5554 --output ../artifacts/android-comparison
python3 scripts/reconnect.py --adb /path/to/adb --serial emulator-5554 --output ../artifacts/android-recovery/reconnect
python3 scripts/reboot.py --adb /path/to/adb --serial emulator-5554 --method ACCESSIBILITY --duration 240 --output ../artifacts/android-recovery/reboot
```

Run these sequentially. They change lab-specific permissions and temporarily select the accessibility service; `compare.py` also forces Doze for one scenario. They restore the original accessibility service list and leave no forced Doze/battery simulation. `reconnect.py` opens and taps the target before enabling monitoring, verifies recovery without relaunching the target, checks Home/re-entry, and checks expiry plus service reconnection after expiry. `reboot.py` reboots the emulator and verifies both blocked and post-expiry input; its default is both methods with 180-second locks, while the command above uses only B with 240 seconds. Use `--method USAGE` for A. Screenshots and raw JSON results are written to the chosen local output directory. The runner records failures as data; zero target taps is meaningful only alongside an in-window tap attempt and a successful post-end tap.

## Required scenarios

- Immediate start, target already open at scheduled onset, target opened during a lock.
- Screen off across scheduled start, forced Doze, wake and open target.
- End while target visible; subsequent target tap must work.
- Block screen Home action and target re-entry.
- Probe's “reject ordinary overlays” switch on/off; count actual delivered taps.
- Reboot during scheduled/active window; persistent state and actual enforcement are separate assertions.
- Process death vs user force-stop vs permission revocation (different OS behaviors).
- Split screen, PiP, notification entry; clock/timezone changes.
- Android 17 with Advanced Protection on/off (not covered by an Android 15 emulator).

Feature parity and results are tracked in `../docs/android-feature-parity.md` and `../docs/android-comparison-results.md`.

## UI parity evidence

Build/install both `:product:assembleDebug` and `:probe:assembleDebug` before UI inspection. The Probe debug APK supplies `QAInstrumentation`, which uses `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES`; ordinary UIAutomator dumps interrupt the blocker. Do not run instrumentation during a blocking-input measurement.

From the repository root, the current scripts are:

- `python3 android-lab/scripts/product_ui_parity_verify.py` — actual UI save/cancel/edit/delete flows (Japanese emulator setup).
- `BEARLOCK_DISPOSABLE_QA=1 ANDROID_SERIAL=<dedicated-emulator> python3 android-lab/scripts/product_parity_capture.py --output artifacts/android-product/full-capture --apk android-lab/product/build/outputs/apk/debug/product-debug.apk` — Installed-APK-verified Japanese/English capture of 16 screen states plus ordered save/cancel/edit/delete/wake/settings checkpoints. Seeds and clears test state **only on the explicitly selected disposable emulator**, retaining the initial state in the output directory. Uses 428×926dp/100% text; it does not replace narrow/large-font acceptance. `--languages` and `--flows` select capture work; completed evidence is retained.
- `python3 android-lab/scripts/product_verify.py` — bounded one-minute Probe input test.
- `python3 android-lab/scripts/product_parity_web_verify.py` — bounded one-minute example.com test in Chrome.
- `python3 android-lab/scripts/android_screenshot_diff.py` — regenerate committed side-by-side and pixel-diff images with Pillow.

The device scripts use the Windows ADB path/serial configured in `scripts/product_qa.py`. Save and restore emulator display/font/accessibility settings when reproducing. Product release builds contain neither the screenshot fixture activity nor the bounded QA lock activity.
