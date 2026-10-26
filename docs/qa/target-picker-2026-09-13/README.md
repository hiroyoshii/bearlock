# Android target picker performance and iOS interaction parity

> 2026-10-26整理: 本文は当時の検証記録です。旧画像・途中ログは作業ツリーから削除し、Git管理されていた証跡は固定コミットの履歴へリンクしています。整理済みのローカル出力は同梱していません。

## Implementation

- iOS continues using Apple's `FamilyActivityPicker`, with draft selection, Cancel, and Save.
- Android uses platform `ListView` / `ExpandableListView` with a bounded viewport, outside the screen's generic `ScrollView`.
- Search keeps one adapter and reuses rows; it does not create all matching application views.
- Categories expand to individual apps. Whole-category selection applies to new apps as before, and inherited app selection is visibly checked.
- The catalog publishes names and categories without waiting for icons. Labels are cached by APK/resource/configuration identity; launcher membership and exclusions are queried on each visit so install/uninstall and default-app changes are refreshed.
- Icons load independently on two worker threads into a 4 MiB bitmap cache. Rebinding cancels queued work and uses a request identity to prevent a late result being shown on the wrong app. The worker holds only an application context and a weak view reference.
- Search, selection count, Save, Cancel, and the Web tab remain available; selecting a target still does not add it to recent locks.
- Android 0.2.3 / versionCode 8.

## Verification commands

```sh
ANDROID_HOME=/home/hiroyoshii/Android/Sdk ./android-lab/gradlew -p android-lab :product:assembleDebug :product:testDebugUnitTest :product:lintDebug -Pkotlin.compiler.execution.strategy=in-process --max-workers=2
adb install -r android-lab/product/build/outputs/apk/debug/product-debug.apk
adb shell am instrument -w com.hiyozoo.bearlock/.PickerInstrumentation
```

The debug-only instrumentation verifies a 1,000-entry catalog has at most 40 attached rows, scrolls to the last entry, retains selection across search and recycling, applies category selection, and restores the original selection on Cancel. The Android 14 acceptance workflow runs it and stores `picker-test.log`.

Debug Logcat tag `BearLockPicker` records time from opening the picker to the first app-row pre-draw, catalog size, and attached row count. This is not a measurement of GPU presentation or all icons finishing. Initial and repeat navigation should both be sampled; sample numbers on a small emulator must not be presented as performance on a large physical-device catalog.

## Local results

- Final debug build, 20 Planner unit tests, and lint: PASS (`BUILD SUCCESSFUL in 3m 47s`).
- Android 14 emulator instrumentation: PASS, 1,000 candidates / 13 attached rows. Category header tap expands/collapses and keeps child views bounded.
- Actual device catalog: 15 candidates / 7 attached rows. Screenshots: [apps（履歴）](https://github.com/hiroyoshii/bearlock/blob/44465600fe304f1ab53b97de3a9f79180650063d/docs/qa/target-picker-2026-09-13/apps.png), [expanded category（履歴）](https://github.com/hiroyoshii/bearlock/blob/44465600fe304f1ab53b97de3a9f79180650063d/docs/qa/target-picker-2026-09-13/categories.png).
- The local emulator experienced System UI ANRs and host contention. Raw timings are retained in [timing-log.txt（履歴）](https://github.com/hiroyoshii/bearlock/blob/44465600fe304f1ab53b97de3a9f79180650063d/docs/qa/target-picker-2026-09-13/timing-log.txt), but they are not a reliable before/after performance comparison or a physical-device latency guarantee.
- Android 14 CI now runs the picker test; remote CI results are not verified in this report.
