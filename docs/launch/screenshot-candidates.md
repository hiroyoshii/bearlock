# Screenshot Candidates

Generate new App Store captures with the manual `iOS Screenshots` workflow described in the [README](../../README.md#github-actions-ios-ci). Current repository screenshots are in `ci-screenshots/app-store-en` and `ci-screenshots/app-store-ja`; their source commit, run, dimensions and per-file source exceptions are recorded in [app-store-source.json](../../ci-screenshots/app-store-source.json). The gallery contains reviewed 1206 × 2622 RGB PNGs. Artifact folders are `screenshots/iphone-app-store-en` and `screenshots/iphone-app-store-ja`. Historical QA comparisons are not the current gallery.

## iOS 1.4 App Store / LP Candidates

The previous App Store gallery used the same five screen types in Japanese and English. The 1.4 candidates below replace those existing image files in Git at 1206 × 2622; they have not been uploaded to App Store Connect.

1. Setup: `setup.png`
2. Home: `home.png`
3. Always Lock setup: `composeAlways.png`
4. Lock confirmation: `confirmation.png`
5. Active lock: `activeLock.png`

Files: `ci-screenshots/app-store-en/` and `ci-screenshots/app-store-ja/`. The paid timed-unlock purchase sheet is documented separately in [the IAP App Review screenshot](ios-1.4-timed-unlock/app-review-screenshot-ja.png).
   - Current files: `ci-screenshots/app-store-en/diagnostics.png` and `ci-screenshots/app-store-ja/diagnostics.png`

## E2E Evidence Screenshots

Source: `bearlock-ios-ci-artifacts`.

- `e2e-immediate-confirmation.png`
- `e2e-immediate-active-lock.png`
- `e2e-delayed-confirmation.png`
- `e2e-delayed-scheduled.png`
- `e2e-delayed-editor.png`
- `e2e-delayed-deleted.png`
- `e2e-recurring-confirmation.png`
- `e2e-recurring-scheduled.png`
- `e2e-recurring-disabled-editor.png`
- `e2e-recurring-disabled-list.png`
- `e2e-active-lock-constraints.png`

These are better for internal QA and review evidence than polished App Store screenshots.

## Final App Store Screenshot Direction

- Use iPhone screenshots for the first submission.
- Do not submit iPad screenshots for the first release.
- Capture final screenshots from a signed build after entitlement approval.
- Confirm final Japanese/English localization direction.
- Confirm final brand image rights and production assets.
