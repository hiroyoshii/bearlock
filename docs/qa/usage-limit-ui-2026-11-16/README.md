# Usage limit UI verification

Before/after images were captured from the existing BearLockScreenshot scheme on the same iPhone 17 simulator, iOS 27.0, Japanese locale, at 1206 x 2622. BEFORE uses the pre-change source; AFTER uses this change. The status bar is fixed; sample schedule/expiry timestamps follow capture time and differ by approximately one minute.

- [Paid duration sheet comparison](paidUnlockReview-comparison.png): store price is explicit above duration selection; the purchase button is pinned outside the scrolling form. In the baseline on this large simulator the action was barely above the bottom edge, rather than entirely hidden.
- [Usage limit setup comparison](composeAlways-comparison.png): new label, blue selected tab, 60-minute initial limit (120 minutes remains selectable).
- [Normal controls comparison](composeNow-comparison.png): blue segmented selection and existing duration presets.
- [Maximum accessibility text](after/paidUnlockLargeText.png): the purchase action remains visible. Duration and explanatory content scroll within the sheet.

Original captures are retained in `before/` and `after/`. These are real simulator screenshots, not mockups. The screenshot fixture uses the existing test price of JPY 500; production continues to use StoreKit displayPrice. Configured fixture rows deliberately retain their saved 60-minute limit.

Validation:

- `swift test`: 106 core tests passed. The updated 120-minute acceptance test first failed against the old implementation; the default was subsequently restored to 60 minutes at the user's request.
- BearLockScreenshot simulator build succeeded.
- BearLock UI tests on iPhone 14 Plus / iOS 27.0: 4 passed, 0 failures. Covered new limit setup/use, editing a saved 60-minute policy, Japanese labels and setup, and the paid sheet. The paid-sheet test checks the purchase button is enabled, hittable, fully inside the app frame, and includes JPY 500, without scrolling the sheet.
- Localization plist validation and `git diff --check` passed.
- Independent code review found no important issues.

No real purchase was performed. Unrelated pre-existing screenshot and CI changes were left intact.

Follow-up: the user requested a 60-minute default while keeping 120 minutes selectable. Updated the shared default and UI expectations, reran all 106 core tests and the screenshot build successfully, and recaptured the setup comparison. The 4 UI-test pass above predates this default-only adjustment.
