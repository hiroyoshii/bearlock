# App Store Connect Draft

> Publication draft derived from [the current product specification](../design-doc.md), not a second source of product policy. Copy options and submission snapshots do not change the specification.

## App Name

Bear Lock

## Subtitle Options

Option A:

App locks for focused time

Option B:

Block distractions until wake time

Option C:

Screen Time locks for focus

## Promotional Text

Choose distracting apps, set a wake time, and let Bear Lock keep them asleep while you focus, rest, or wind down.

## Description

Bear Lock helps you protect focused time by scheduling app locks that resist impulsive changes. If you truly need to stop, you can request a free wake-up after 30 minutes or purchase an immediate wake-up.

Choose the apps or categories you want to avoid, decide when the lock starts and ends, and confirm the plan. During the lock window, Bear Lock uses iOS Screen Time shields to keep those distractions outside. When the scheduled wake time arrives, access is restored automatically.

Use Bear Lock for:

- Deep work sessions.
- Study blocks.
- Bedtime wind-down.
- Morning routines.
- Intentional breaks from social apps, video apps, or games.

Core features:

- Choose apps and categories with Apple's Screen Time picker.
- Start a lock now.
- Schedule a lock for later.
- Pick a fixed date and time.
- Create recurring weekday locks.
- See active lock status and wake time.
- Request a free wake-up after 30 minutes.
- Purchase a one-time immediate wake-up.

Privacy:

Bear Lock MVP is local-only. There is no account, no cloud sync, no advertising, no analytics, and no tracking. App selection tokens and schedules are stored on your device.

Note:

Bear Lock requires Screen Time / Family Controls permission. Some system-level actions outside Bear Lock, such as changing iOS Settings or deleting the app, remain controlled by iOS.

## Keywords Draft

focus,screen time,app blocker,distraction,study,sleep,self control,productivity,habit,lock

## Category

Productivity

Secondary category candidate:

Health & Fitness

## Device Support

First release: iPhone only. Use iPhone screenshots in App Store Connect.

## Age Rating Notes

Bear Lock does not contain user-generated content, web browsing, gambling, or social features. It offers consumable in-app purchases and uses Screen Time permissions to restrict selected apps at the user's request.

## Privacy Nutrition Label Draft

Data collected:

None.

Tracking:

No.

Data linked to user:

None.

Data not linked to user:

None.

Local-only data:

- Screen Time selection tokens.
- Lock schedules.
- Wake-up requests and processed purchase identifiers.

## Review Notes

Bear Lock uses Screen Time APIs for voluntary self-control app blocking. To test, grant Screen Time authorization, select at least one app or category, create a short Now lock, and open the selected app to confirm the Bear Lock shield appears.

During an active lock, the user can choose a free wake-up that keeps the shield active for another 30 minutes, or purchase an immediate wake-up. The immediate wake-up is a consumable In-App Purchase with product ID `com.hiyozoo.bearlock.wake.now`. It ends only the current lock occurrence; future repeating occurrences remain scheduled. If Ask to Buy is approved after the original lock ends, the purchase becomes a wake-up ticket for a later lock.

## Immediate Wake-Up In-App Purchase

- Product ID: `com.hiyozoo.bearlock.wake.now`
- Type: Consumable
- Reference name: `Wake Now`
- Japanese display name: `今すぐ起こす`
- Japanese description: `現在のBear Lockを1回だけ終了します`
- English display name: `Wake now`
- English description: `End the current Bear Lock once`
- Price: App Store Connectの日本価格が500円になる価格ポイント


## Screenshot Candidates

- Setup screen.
- Home / composer.
- Confirmation sheet.
- Active lock screen.
- Wake-up completion screen.
- Settings.
