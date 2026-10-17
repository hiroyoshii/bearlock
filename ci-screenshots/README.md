# Current iOS screenshots

The current English and Japanese simulator captures are in `app-store-en` and `app-store-ja` (16 screens per locale). [Source metadata](app-store-source.json) identifies the exact source commit, GitHub Actions run, and files.

These use the screenshot app's fixtures. They show the current UI, not evidence of actual Screen Time blocking. Interactive E2E evidence and the before/after review are recorded in [the selection-controls review](../docs/qa/ios-selection-controls-2026-10-11.md). Dated QA and Android comparison images elsewhere remain historical records.

The 2026-10-18 captures restore the icon mode buttons and the weekdays' light-gray fill and 1pt outline. [This run](https://github.com/hiroyoshii/bearlock/actions/runs/39049336403) passed all 22 normal-device E2E tests and screenshot capture, but failed two of four SE tests: preset selection after a tap and accessibility-size native menu switching. Weekday save/reopen passed on both devices. See the review for the exact results; the full E2E suite is not green.

| Screen | Japanese | English |
|---|---|---|
| Home | ![Home JA](app-store-ja/home.png) | ![Home EN](app-store-en/home.png) |
| Repeat | ![Repeat JA](app-store-ja/composeRepeat.png) | ![Repeat EN](app-store-en/composeRepeat.png) |
| Starts later | ![Starts later JA](app-store-ja/composeDelayed.png) | ![Starts later EN](app-store-en/composeDelayed.png) |
| Scheduled locks | ![Scheduled locks JA](app-store-ja/scheduledList.png) | ![Scheduled locks EN](app-store-en/scheduledList.png) |
