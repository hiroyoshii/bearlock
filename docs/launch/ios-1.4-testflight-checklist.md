# iOS 1.4 TestFlight and timed-unlock preparation

This checklist prepares the timed paid unlock for App Store Connect and TestFlight. It does not claim that the product is already registered or that the build has been uploaded.

## Product values from the current app

| App Store Connect field | Value |
| --- | --- |
| App | Bear Lock (`com.hiyozoo.bearlock`, App Store ID `6806725013`) |
| Product type | Consumable |
| Product ID | `com.hiyozoo.bearlock.daily.unlock.timed` |
| Reference name | Timed Unlock |
| Japanese display name | 時間指定解除 |
| Japanese description | 選択した時間だけ対象を一時解除します |
| English display name | Timed Unlock |
| English description | Unlock selected targets for a chosen duration |
| Japan price | ¥500 |

The ¥500 price is the product decision for this release. `BearLockPurchaseTests/SupportProducts.storekit` is only the local StoreKit test configuration; it does not create or configure the App Store Connect product.

The app loads this exact product ID through StoreKit. If StoreKit cannot return it, the “Choose unlock time” button stays disabled. A TestFlight build uses App Store Connect product data through the Sandbox, not the local `.storekit` file.

## App Store Connect setup

- [ ] In **Apps → Bear Lock → In-App Purchases**, confirm whether `com.hiyozoo.bearlock.daily.unlock.timed` already exists. Do not create a duplicate product ID.
- [ ] If it does not exist, create a **Consumable** product with the values above.
- [ ] Add the Japanese and English localizations above.
- [ ] Set the Japan storefront price to **¥500** and make the product available in the storefronts where Bear Lock is distributed.
- [ ] Confirm the Paid Apps Agreement is active and the app's agreements, tax, and banking setup do not block paid purchases.
- [ ] If you need to test storefront or purchase scenarios, create or select a Sandbox tester for the Japan storefront.
- [ ] Allow product metadata time to propagate; Apple notes Sandbox changes can take up to one hour.

No App Store Connect changes have been made from this workspace. The signed-in App Store Connect UI was unavailable during preparation, so product existence, agreement status, price, and availability remain unverified.

## TestFlight build

- [ ] Run the existing **iOS TestFlight Upload** workflow from `main` after the desired source is on `main`.
- [ ] Confirm archive validation and upload succeed, then wait until the build finishes processing in App Store Connect.
- [ ] Add the processed build to an internal TestFlight group and install it on a physical iPhone.
- [ ] Test the purchase flow on the TestFlight build. TestFlight uses Sandbox for IAP and does not charge the tester. Use a Sandbox Apple Account when testing alternate storefronts or purchase scenarios.

The project marketing version is currently **1.4**. The workflow sets the build number from the GitHub Actions run number. A successful upload is not the same as a processed or installable TestFlight build.

## Feature-by-feature device checks

Record each result separately as **Pass**, **Fail**, or **Not run**.

| Check | Expected result | Result |
| --- | --- | --- |
| Existing free allowance | 5/10/15-minute options respect the configured daily limit (maximum 60 minutes); selecting one reduces the displayed balance. | Not run |
| End free unlock early | “End temporary unlock” relocks the target and returns each full unused minute to today's free balance. | Not run |
| Free balance is exhausted | Free unlock buttons are unavailable; the paid timed option remains available when the product is loaded. | Not run |
| Product metadata loads | The paid option is enabled and displays StoreKit's ¥500 price. | Not run |
| Paid duration validation | 15 minutes is rejected; 16 minutes is accepted. A duration over 60 minutes, such as 90 minutes, is accepted. | Not run |
| Sandbox purchase succeeds | Purchase confirmation completes, the chosen target is temporarily unshielded, and the free daily balance does not change. | Not run |
| Paid unlock expiry | At the selected expiry time the daily Shield is restored. | Not run |
| Paid unlock crosses midnight | The paid grant remains active until its selected expiry; the free daily balance resets independently at local midnight. | Not run |
| Purchase cancelled or fails | No paid grant is delivered and the target remains locked. | Not run |
| Normal lock overlaps | A normal lock that blocks the selected target remains effective; unrelated normal locks do not disable the daily allowance. | Not run |

Use short durations for expiry checks where practical, then test one duration over 60 minutes to confirm that the paid path has no 60-minute daily allowance cap. Do not infer the paid-flow result from the local StoreKit test host alone.

## App Review preparation

- [ ] Verify the App Store Connect product's display name and price match the purchase sheet on a TestFlight device.
- [x] Capture the Japanese timed-unlock sheet for the IAP's App Review screenshot: [app-review-screenshot-ja.png](ios-1.4-timed-unlock/app-review-screenshot-ja.png). It uses the same slider and presets as other lock durations, with 15-minute steps from 15 to 1,440 minutes and a 30-minute default. This is a review-only screen capture, not an App Store product-page screenshot or proof of a completed purchase. The purchase action is below the visible area in the default medium sheet; the full sheet remains scrollable. Set the App Store Connect price to ¥500 before submitting.
- [ ] Add review notes explaining how to configure an Always Lock, open **Choose unlock time**, enter a duration, and complete the Sandbox purchase.
- [ ] Attach the current app version/build and the new consumable product to the intended review submission when ready to release.
- [ ] Keep submission for review separate from TestFlight testing; App Store Connect Sandbox testing does not require prior IAP approval.

## Completion record

- App Store Connect product/status: **Not verified**
- Product availability in Sandbox: **Not verified**
- TestFlight upload/processing: **Not run**
- Physical-device Screen Time and purchase checks: **Not run**
