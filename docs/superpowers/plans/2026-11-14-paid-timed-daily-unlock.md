# Paid Timed Daily Unlock Implementation Plan

> **For agentic workers:** Implement task-by-task in this session using the native inline workflow.

**Goal:** Let a user buy one temporary unlock for a chosen duration without consuming the configured daily allowance, then restore the daily Shield at expiry.

**Architecture:** Extend the existing `DailyAllowanceGrant` as the single persisted expiry source, distinguishing the paid override from budget grants only where necessary for UI/accounting. Use a dedicated timed-unlock consumable SKU so the App Store purchase sheet names the item correctly, while reusing existing StoreKit verification, transaction finishing, monitor registration, and Shield reconciliation paths.

**Tech Stack:** Swift, SwiftUI, StoreKit 2, DeviceActivity, ManagedSettings, BearLockCore.

**Spec:** `docs/design-doc.md` IOS-06 through IOS-09 and the user's paid timed-unlock request.

## Global Constraints

- Free grants remain 5/10/15 minutes and consume their full duration from today's allowance.
- Paid custom unlock is separate from the daily allowance, allows any representable whole-minute duration above 15 minutes, may cross local midnight, and ends at its selected expiry.
- Paid unlock may cross the local day boundary but cannot remove a normal lock.
- Purchase, monitor registration, persistence, and Shield reflection must fail closed.
- Existing wake-now IAP, free wake, support purchases, and normal lock behavior remain intact.

## Review Focus

- Purchase cancelled, pending, unverified, duplicated, or delivered after its intent expires.
- Monitor registration and state-save failure leave the target locked and budget unchanged.
- A normal lock overlapping the selected target remains effective and cannot be sold as unlocked access.
- Expiry at local midnight, clock/day-boundary changes, and app termination restore correct Shield state.
- Paid unlock leaves daily allowance balance unchanged; free grant behavior is unchanged.

### Task 1: Core paid temporary grant

**Files:** `Sources/BearLockCore/DailyAllowance.swift`, `Tests/BearLockCoreTests/DailyAllowanceTests.swift`

- [ ] Add a failing test for a paid duration grant that does not change usage balance, expires as specified, and remains active across local midnight.
- [ ] Run the focused core test and confirm it fails for the intended missing behavior.
- [ ] Add the smallest representation/operation that reuses the existing grant expiry as the access-state source.
- [ ] Run the focused test and confirm it passes.

### Task 2: Purchase intent and atomic delivery

**Files:** `Sources/BearLockCore/LockRepository.swift`, `Tests/BearLockCoreTests/LockStoreTests.swift`, `BearLockLogicTests/BearLockAppModelTests.swift`

- [ ] Add failing cases for verified paid grant delivery, duplicate transaction delivery, stale intent, and rejection under a matching normal lock.
- [ ] Run focused tests and confirm they fail.
- [ ] Add a dedicated paid daily-unlock intent and delivery operation; preserve the existing normal wake purchase path.
- [ ] Run focused tests and confirm they pass.

### Task 3: StoreKit, monitoring, and Shield reflection

**Files:** `BearLock/Features/Home/WakePurchaseStore.swift` or a focused paid-unlock store, `BearLock/App/BearLockAppModel.swift`, `BearLock/Services/ScheduleController.swift`, `BearLock/Extensions/DeviceActivityMonitor/BearLockMonitorExtension.swift`

- [ ] Add tests for purchase success/cancel/failure and monitor/save ordering.
- [ ] Implement an explicit custom-duration purchase path with StoreKit-loaded price, monitor-before-save, atomic delivery, and existing reconciliation.
- [ ] Ensure expiry monitoring for the selected duration is registered before saving or removing the daily Shield.

### Task 4: Home UI and localization

**Files:** `BearLock/Features/Schedule/ScheduledLockListView.swift`, localization files, `BearLockUITests/SelectionControlsUITests.swift`

- [ ] Keep free 5/10/15-minute actions and add a separate duration selector and priced purchase action for paid custom unlock.
- [ ] Show chosen end time, unchanged daily balance, temporary-unlock status, and normal-lock warning.
- [ ] Update localizations and UI coverage.

### Task 5: Verification and docs

- [ ] Run the focused core, app-model, and UI tests, followed by the iOS test suite.
- [ ] Update `docs/design-doc.md` and capture the updated temporary-unlock UI.
- [ ] Report simulator results separately from real-device Screen Time verification.
