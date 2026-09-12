# iOS lock expiry: implementation and verification

## Scope and root-cause confidence

This change fixes reproducible paths that leave a shield behind. It does **not** establish which path occurred on the reported iPhone. The device's callback delivery and effective Screen Time enforcement require physical-device evidence.

- App and monitor use `LockLifecycle` to reconcile the current occurrence.
- The shield configuration extension also reconciles when a blocked target is opened. If the end callback is delayed or missed, opening the target after its saved deadline clears the stale named store without requiring Bear Lock to launch. An adjacent current occurrence is applied instead of being cleared.
- Schedule components include seconds. Newly created/replaced rules use integral seconds; end times round up, never shortening the requested duration.
- A late start does not move the occurrence deadline. Duplicate starts do not replace the active snapshot; an expired start cannot reapply its old shield.
- Completion requires expiration of the saved active deadline **or** the immutable scheduled occurrence deadline. A callback alone is not proof: `stopMonitoring` can deliver an early end. Mismatched rule notifications cannot complete the current lock.
- Legacy one-shot locks can recover a shifted end from their immutable source rule. Legacy recurring locks without an occurrence deadline retain their active deadline, because the parent may have been edited.
- An expired shield is cleared before completion-history persistence. If history saving fails, the clear request has still occurred; another invocation can retry without duplicating history.
- Already completed state and expired one-shot rules provide evidence to clear a residual primary shield, provided no current occurrence needs it.
- New shields are only applied after their active snapshot is saved. If saving the next occurrence fails at a boundary, the expired predecessor is cleared and the failure is reported; enforcing the next window then requires a successful later reconciliation. Applying/releasing shields and updating state occur inside the same repository transaction, preventing cross-process interleaving.
- The extension finishes this work synchronously; it does not leave an unstructured `Task` after the OS callback returns.
- Parent schedule replacement/stopping preserves a separate one-shot completion monitor for an unexpired active snapshot. This prevents an early stop callback from being the last opportunity to unlock. Registration failure is surfaced rather than silently removing the end monitor.
- The repository reloads on every operation. A stable sidecar file with `flock` serializes read/modify/write across app and extension processes, including atomic JSON replacements.
- I/O failures propagate without moving data or substituting empty state. Invalid JSON is copied for diagnosis, retained in place, and remains an error on subsequent reads.
- New JSON writes use file protection until first user authentication on iOS. This is not permission to read before the first unlock after reboot.

## Automated checks

The `iOS Lock Lifecycle` GitHub Actions workflow runs:

1. `swift test`: schedule precision; delayed/duplicate/out-of-order callbacks; hours-late end; stop before deadline; different rule and later recurring occurrence; app refresh and shield presentation without callback; persistence/read failures; legacy shifted deadline; residual shield; current next rule; overnight recurrence; stale Store snapshots; concurrent repository instances; corrupted and unreadable files.
2. `python3 Scripts/test-lock-repository-processes.py`: compiles the production repository and launches four independent OS processes. All 160 mutations must survive with distinct IDs.
3. Xcode project validation and Simulator builds of the app, monitor, shield configuration, shield action, and screenshot app.
4. Simulator mock UI tests for immediate creation, delayed schedule edit/delete, and active-lock immutability controls.

A mocked `clear` call proves the code reaches the API adapter. It does not prove that iOS removed a real restriction. The process test proves participating writers serialize; it does not simulate iOS suspension or Data Protection.

## 実機で必ず確認すること（未実施）

- Bear Lockを閉じ、画面オフのまま終了時刻を十分過ぎてから端末を使用する。**Bear Lockを開く前に対象アプリを試し、解除されるか確認する。**
- 起きたまま終了をまたぐ場合、予約開始中にスリープしていた場合、繰り返し予定をロック中に変更・無効化した場合も確認する。
- `DeviceActivity.intervalDidEnd` → 判定理由 → `Shield.clear.requested` → `.finished` を確認する。`requested` はAPI呼び出しの記録であり、実際の制限解除の保証ではない。
- 本体を開いた後の `ActiveLock.reconcile` による復旧と、extensionによる解除を区別する。
- 終了通知の配信、extensionの実行寿命、画面ロック・再起動後のファイルアクセス、実際のScreen Time解除はCIでは確認できない。

## Physical iPhone checklist (still required)

Use a signed build with the Family Controls entitlement. Record iOS version, app build, timezone, start/end times, and whether the app was suspended, force-quit, or the device restarted. Choose a duration accepted by DeviceActivity (use a release/TestFlight build for tests exceeding the debug safety limit).

| Scenario | Procedure | Expected observation |
|---|---|---|
| Screen off through expiry | Start a lock, leave Bear Lock, switch screen off. Wait well beyond expiry, then use the iPhone and open a blocked app **before opening Bear Lock**. | The monitor receives end and requests clear; the target app becomes usable without opening Bear Lock. |
| Awake through expiry | Keep using an unblocked app across expiry; then open the target. | Restriction clears without opening Bear Lock. |
| Start at a nonzero second | Start around `hh:mm:30`, leave Bear Lock, and test across the displayed deadline. | Recorded schedule and active deadline agree; no persistent shield from second truncation. |
| Delayed/overnight start | Schedule a future lock, stop using the phone before start, resume partway through the window. | Active end stays at the planned deadline, not pickup time plus duration. |
| Late pickup | Resume hours after the scheduled end. | An expired start callback cannot re-lock; the end path clears residual shielding. |
| Parent edit/disable while active | While a recurring lock is active, edit or disable its parent; leave Bear Lock until after its original end. | No early unlock on stop/replacement; the preserved completion monitor unlocks at the original deadline. |
| Adjacent locks | Arrange consecutive windows with different target sets and use the device across the boundary. | An old end cannot clear the current window; current targets remain shielded. |
| Next recurring occurrence | Exercise at least a second occurrence, including an overnight boundary. | Current occurrence gets the correct end; old callbacks do not shorten it. Actual recurring OS scheduling remains a device check. |
| App force-quit | Force-quit Bear Lock after applying a lock; resume after expiry. | Observe whether iOS delivers end and effective clear without reopening the app. Record separately from normal suspension. |
| Reboot/Data Protection | Reboot during a lock, then perform first device unlock and test after expiry. | Record callback delivery and any repository read/lock failure; no claim of execution before first authentication. |
| Legacy upgrade | Install over an existing build with an active one-shot lock. | Existing tokens/dates load; planned deadline is preserved. Existing registrations made by the old build may still carry truncated times; capture callbacks explicitly. |

## Reading diagnostics

Capture diagnostics promptly after the failure. Opening Bear Lock invokes a separate recovery path, so record the target app's failure **before** opening Bear Lock to retrieve logs.

- `DeviceActivity.intervalDidEnd`: entered OS callback; detail contains activity name.
- `DeviceActivity.reconcile`: event, current time, active ID/end, scheduled deadline, and decision.
- `skip=activityMismatch` / `skip=unknownActivity`: callback rejected by identity.
- `keep=unexpiredOccurrence`: early end/stop, or a later valid occurrence is still active.
- `clear=expiredNoCurrentOccurrence`: expiry established with no current rule needing shielding.
- `Shield.clear.requested`: the ManagedSettings API was called. This is **not** an OS acknowledgement that restrictions are gone.
- `ShieldRecovery.clear`: opening a shielded target detected an expired lock and requested removal without launching Bear Lock.
- `saveFailed=...`: state persistence failed; when preceded by clear, that failure did not block the clear request.
- `DeviceActivity.intervalDidEnd.finished` / `.failed`: synchronous callback completion or error.
- `Schedule.preservedActiveDeadline`: independent end monitoring registered before parent changes.
- `ActiveLock.reconcile`: app recovery, distinguish from extension recovery.

The absence of an event in the bounded local log is not proof that the OS never called it: log I/O itself can fail, and old entries can be evicted. Use the device's Console logs (subsystem `com.hiyozoo.bearlock`) for stronger evidence.

## Limits

There is no always-running retry timer in the extension, nor a guarantee of a callback exactly at the wall-clock deadline while the phone is unused. Apple documents end at first use outside the interval. If all state is missing/corrupt or temporarily inaccessible, the implementation does not blindly clear an unknown active restriction. Diagnosis and a later successful reconciliation are needed; no autonomous recovery from total data loss is claimed.

Sources: [DeviceActivity intervalDidEnd](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidend(for:)), [named stores and extension restrictions](https://developer.apple.com/videos/play/wwdc2022/110336/).
