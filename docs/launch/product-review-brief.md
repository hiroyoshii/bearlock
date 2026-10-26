# Bear Lock Product And Review Brief

> Publication/review copy derived from [the current product specification](../design-doc.md). This document is not a separate source of product policy.

## Short Product Summary

Bear Lock is a self-control Screen Time app for people who want to protect focused time, sleep, study, or recovery periods from distracting apps. The user chooses apps or categories, chooses when the lock starts and ends, and Bear Lock applies a Screen Time shield during that window.

The core behavior is intentional commitment with explicit wake-up options. On iOS, the user can schedule a free wake-up after 30 minutes or use the consumable immediate wake-up purchase/ticket for the selected occurrence; future repeats and other locks remain.

## What The App Does

- Requests Screen Time / Family Controls authorization from the user.
- Lets the user choose blocked apps and categories through Apple's `FamilyActivityPicker`.
- Creates one-time locks for now, a delayed start, or a fixed date and time.
- Creates recurring locks for selected weekdays and times.
- Applies a Managed Settings shield to selected apps during active locks.
- Removes the shield automatically when the scheduled lock ends.
- Shows the active lock state, remaining time, and wake time inside Bear Lock.
- Provides local Diagnostics for troubleshooting on device.

## Why Family Controls Is Required

Bear Lock needs Family Controls, Managed Settings, and Device Activity because the app's main function is to let the user voluntarily restrict access to selected apps during scheduled intervals.

The app cannot deliver its core value with notifications, reminders, or ordinary local state alone. It must be able to:

- Let the user privately select apps without Bear Lock learning app identities directly.
- Apply an iOS Screen Time shield to selected apps.
- Schedule start and end windows that can run even when Bear Lock is not foregrounded.
- Provide a custom shield experience, with wake-up handled through the app's confirmation flow rather than unrestricted editing of an active lock.

## Safety And User Agency

Bear Lock is designed for self-control, not surveillance.

- The user initiates authorization.
- The user chooses the apps or categories to block.
- The user chooses the lock window before it starts.
- Bear Lock does not hide the lock status or wake time.
- Active-lock time and target edits are restricted; early wake-up follows the explicit options described above.
- Debug builds include a short maximum duration for safer pre-device testing.

Known system-level limitations are documented for review and QA: users may still change iOS Settings, revoke permissions, delete the app, or use account-level controls outside Bear Lock.

## Data Handling

Bear Lock MVP is local-only.

- No account.
- No cloud sync.
- No advertising.
- No analytics SDK.
- No tracking.
- Selected app tokens and lock schedules are stored locally in the app's App Group container.
- Diagnostics logs are stored locally and are intended to be shared manually by the user only when troubleshooting.

## Reviewer Notes Draft

Bear Lock uses Apple's Screen Time APIs to provide voluntary app blocking for self-control. During onboarding, the app requests Family Controls authorization and uses `FamilyActivityPicker` so the user can select apps or categories to block. The app then schedules locks and applies a Managed Settings shield during active lock windows.

To test the primary flow:

1. Launch Bear Lock.
2. Grant Screen Time authorization.
3. Choose at least one app or category in the picker.
4. Create a short Now lock.
5. Open the selected app and confirm the Bear Lock shield appears.
6. Return to Bear Lock and confirm the active lock screen shows the wake time.
7. Wait until the lock ends and confirm the selected app opens normally.

Early wake-up follows the options above and affects only the selected occurrence. Users can still use iOS-level settings and account controls outside the app.

Diagnostics are available at `Settings > Diagnostics` inside the app. Diagnostics are local-only and help confirm authorization status, selected target count, active lock status, safety policy, and recent app events.

## Entitlement Request Summary Draft

Bear Lock requests the Family Controls entitlement to implement a user-initiated self-control app. The app lets an individual user select distracting apps or categories and schedule periods when those apps are shielded. The purpose is to support focus, sleep, study, and intentional breaks from apps.

The app uses:

- `FamilyControls` for authorization and target selection.
- `FamilyActivityPicker` so app/category selection remains private and user-driven.
- `ManagedSettings` to shield selected apps during active lock windows.
- `DeviceActivity` to schedule lock intervals and clear shields when intervals end.

Bear Lock does not monitor another person, does not sell or share usage data, and does not use selected app information for advertising or analytics.
