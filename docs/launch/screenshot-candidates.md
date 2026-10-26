# Screenshot Candidates

Generate new App Store captures with the manual `iOS Screenshots` workflow described in the [README](../../README.md#github-actions-ios-ci). Current repository screenshots are in `ci-screenshots/app-store-en` and `ci-screenshots/app-store-ja`; their source commit, run and dimensions are recorded in [app-store-source.json](../../ci-screenshots/app-store-source.json). The existing gallery remains the earlier 1284 × 2778 capture until replaced with verified output from the manual workflow. Artifact folders are `screenshots/iphone-app-store-en` and `screenshots/iphone-app-store-ja`. Historical QA comparisons are not the current gallery.

## Primary App Store / LP Candidates

1. Setup
   - Purpose: shows brand, app icon, and permission/selection entry.
   - Use for: first App Store screenshot or LP hero support image.
   - Current files: `ci-screenshots/app-store-en/setup.png` and `ci-screenshots/app-store-ja/setup.png`

2. Home
   - Purpose: shows the main lock composer and selected target summary.
   - Use for: explaining the main workflow.
   - Current files: `ci-screenshots/app-store-en/home.png` and `ci-screenshots/app-store-ja/home.png`

3. Confirmation
   - Purpose: shows the commitment moment before locking.
   - Use for: explaining that the user confirms target apps and wake time.
   - Current files: `ci-screenshots/app-store-en/confirmation.png` and `ci-screenshots/app-store-ja/confirmation.png`

4. Active Lock
   - Purpose: shows sleeping bear, countdown, and the current wake-options entry.
   - Use for: demonstrating core behavior.
   - Current files: `ci-screenshots/app-store-en/activeLock.png` and `ci-screenshots/app-store-ja/activeLock.png`

5. Diagnostics
   - Purpose: shows local troubleshooting state.
   - Use for: reviewer/support docs, not primary consumer marketing unless needed.
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
