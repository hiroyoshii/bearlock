# Bear Lock Support And FAQ Draft

## What Is Bear Lock?

Bear Lock helps you choose distracting apps and schedule windows when those apps are blocked by iOS Screen Time shields. Once a lock starts, Bear Lock does not provide an in-app early unlock button.

## Bear Lock Is Not Blocking Apps

Check the following:

- Screen Time / Family Controls permission is granted.
- At least one app or category has been selected.
- The current time is inside an active lock window.
- The app was selected directly or belongs to a selected category.
- `Settings > Diagnostics` shows `Diagnostics writable: Yes`.
- Recent Events includes `Shield.apply.succeeded`.

If the lock should be active but apps are still opening, take screenshots of the active lock screen and `Settings > Diagnostics`.

## The Permission Prompt Does Not Appear

Try:

- Open iOS Settings and confirm Screen Time is available on the device.
- Restart Bear Lock.
- Reinstall the app if this is a development build.
- Confirm the installed build has the Family Controls entitlement.

This feature cannot be fully verified on Simulator. The first release is designed and officially supported for iPhone, and device verification should use a physical iPhone with the proper Apple entitlement.

Bear Lock may run on iPad in iPhone compatibility mode, but iPad-specific layouts are not part of the first release.

## The Lock Ended But Apps Are Still Blocked

Try:

- Open Bear Lock and wait for it to refresh.
- Check whether the active lock end time has passed.
- Open `Settings > Diagnostics` and look for `ActiveLock.completed` and `Shield.clear.succeeded`.
- If the shield remains, revoke and re-enable Screen Time permission from iOS Settings during testing.

## Why Is There No Unlock Button?

Bear Lock is built around pre-commitment. The user chooses the apps and schedule before a lock starts, and Bear Lock protects that choice during the lock. Removing the in-app unlock path is intentional.

System-level controls still exist outside Bear Lock, including iOS Settings, app deletion, and account-level changes.

## What Data Does Bear Lock Send?

The MVP sends no data to Bear Lock servers. It has no account, no cloud sync, no analytics, no ads, and no tracking. Lock schedules, app selection tokens, and Diagnostics are local to the device.

## How Do I Report A Problem?

Send:

- What you expected to happen.
- What happened instead.
- Device model and iOS version.
- Screenshots of the relevant Bear Lock screen.
- A screenshot of `Settings > Diagnostics`.

Support contact: support@hiyozoo.com
