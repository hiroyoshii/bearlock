# Current iOS screenshots

The current English and Japanese simulator captures are in `app-store-en` and `app-store-ja` (16 screens per locale). [Source metadata](app-store-source.json) identifies the exact source commit, GitHub Actions run, and files.

These use the screenshot app's fixtures. They show the current UI, not evidence of actual Screen Time blocking. Interactive E2E evidence and the before/after review are recorded in [the selection-controls review](../docs/qa/ios-selection-controls-2026-10-11.md). Dated QA and Android comparison images elsewhere remain historical records.

The 2026-10-17 captures include the restored single-row weekdays. Screenshot capture and the weekday E2E passed on both tested devices, but [this run](https://github.com/hiroyoshii/bearlock/actions/runs/39010305244) is not fully green: two other assertions/flows failed on the normal-size device. See the review for the exact results.

| Screen | Japanese | English |
|---|---|---|
| Home | ![Home JA](app-store-ja/home.png) | ![Home EN](app-store-en/home.png) |
| Repeat | ![Repeat JA](app-store-ja/composeRepeat.png) | ![Repeat EN](app-store-en/composeRepeat.png) |
| Starts later | ![Starts later JA](app-store-ja/composeDelayed.png) | ![Starts later EN](app-store-en/composeDelayed.png) |
| Scheduled locks | ![Scheduled locks JA](app-store-ja/scheduledList.png) | ![Scheduled locks EN](app-store-en/scheduledList.png) |
