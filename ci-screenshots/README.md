# Current iOS screenshots

The current English and Japanese simulator captures are in `app-store-en` and `app-store-ja` (16 screens per locale). [Source metadata](app-store-source.json) identifies the exact source commit, GitHub Actions run, and files.

These use the screenshot app's fixtures. They show the current UI, not evidence of actual Screen Time blocking. Interactive E2E evidence and the before/after review are recorded in [the selection-controls review](../docs/qa/ios-selection-controls-2026-10-11.md). Superseded QA and Android comparison images are available through fixed Git history links in the review notes.

The 2026-10-26 gallery contains 31 captures from [iOS Screenshots run 3](https://github.com/hiroyoshii/bearlock/actions/runs/40323886294), source `8567e31`, plus the English `composeDelayed.png` from [run 2](https://github.com/hiroyoshii/bearlock/actions/runs/40315675972), source `c642aac`. Run 3 captured the iPhone home screen for that one file; it was rejected. The intervening fixture changes do not alter the delayed composer. Per-file source exceptions and source archive hashes are recorded in the metadata.

All 32 selected images were visually reviewed and are 1206x2622 RGB PNGs for the Dynamic Island medium display slot. Their fully opaque alpha channels were removed without changing the decoded RGB pixels. Home and active-lock captures now show three selected apps, and the Japanese schedule heading is translated. The manual workflow succeeded, but it does not run UI tests or verify real Screen Time blocking. App Store Connect upload is not confirmed by this gallery update.

| Screen | Japanese | English |
|---|---|---|
| Home | ![Home JA](app-store-ja/home.png) | ![Home EN](app-store-en/home.png) |
| Repeat | ![Repeat JA](app-store-ja/composeRepeat.png) | ![Repeat EN](app-store-en/composeRepeat.png) |
| Starts later | ![Starts later JA](app-store-ja/composeDelayed.png) | ![Starts later EN](app-store-en/composeDelayed.png) |
| Scheduled locks | ![Scheduled locks JA](app-store-ja/scheduledList.png) | ![Scheduled locks EN](app-store-en/scheduledList.png) |
