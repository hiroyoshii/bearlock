# Current iOS screenshots

The current English and Japanese simulator captures are in `app-store-en` and `app-store-ja` (25 screens per locale). [Source metadata](app-store-source.json) identifies the source commit, capture time, local tools, simulator, dimensions, and files.

These use the screenshot app's fixtures. They show the current UI, not evidence of actual Screen Time blocking. Interactive E2E evidence and the before/after review are recorded in [the selection-controls review](../docs/qa/ios-selection-controls-2026-10-11.md). Dated QA and Android comparison images elsewhere remain historical records.

The 2026-11-15 captures were rebuilt from the current source and captured locally on an iPhone 14 Plus with iOS 27.0, at 1284 × 2778 pixels. The set includes always-lock setup, daily allowance states, and the remaining allowance after an early manual end. All 50 images are checked for dimensions and blank output. XcodeGen was unavailable locally, so the existing generated Xcode project was used for the screenshot app build. This capture validates the screenshot app and images; it does not replace interactive Screen Time validation.

| Screen | Japanese | English |
|---|---|---|
| Home | ![Home JA](app-store-ja/home.png) | ![Home EN](app-store-en/home.png) |
| Repeat | ![Repeat JA](app-store-ja/composeRepeat.png) | ![Repeat EN](app-store-en/composeRepeat.png) |
| Starts later | ![Starts later JA](app-store-ja/composeDelayed.png) | ![Starts later EN](app-store-en/composeDelayed.png) |
| Scheduled locks | ![Scheduled locks JA](app-store-ja/scheduledList.png) | ![Scheduled locks EN](app-store-en/scheduledList.png) |
| Always lock setup | ![Always setup JA](app-store-ja/composeAlways.png) | ![Always setup EN](app-store-en/composeAlways.png) |
| Always lock target selection | ![Always target JA](app-store-ja/allowanceTargetSelection.png) | ![Always target EN](app-store-en/allowanceTargetSelection.png) |
| Daily allowance available | ![Allowance JA](app-store-ja/allowanceLocked.png) | ![Allowance EN](app-store-en/allowanceLocked.png) |
| Temporary unlock | ![Temporary unlock JA](app-store-ja/allowanceTemporary.png) | ![Temporary unlock EN](app-store-en/allowanceTemporary.png) |
| After early end | ![Returned allowance JA](app-store-ja/allowanceReturned.png) | ![Returned allowance EN](app-store-en/allowanceReturned.png) |
| Allowance exhausted | ![Exhausted JA](app-store-ja/allowanceExhausted.png) | ![Exhausted EN](app-store-en/allowanceExhausted.png) |
| Tomorrow's allowance | ![Tomorrow JA](app-store-ja/allowancePending.png) | ![Tomorrow EN](app-store-en/allowancePending.png) |
| Stopped | ![Stopped JA](app-store-ja/allowanceStopped.png) | ![Stopped EN](app-store-en/allowanceStopped.png) |
