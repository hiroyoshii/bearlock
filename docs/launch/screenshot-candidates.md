# Screenshot Candidates

Source: GitHub Actions Visual Snapshot and iOS CI artifacts. After localization, static screenshot artifacts are grouped by locale, such as `iphone-16-en` and `iphone-16-ja`.

## Primary App Store / LP Candidates

1. Setup
   - Purpose: shows brand, app icon, and permission/selection entry.
   - Use for: first App Store screenshot or LP hero support image.
   - Current file in CI artifact: `artifacts/screenshots/iphone-16-en/setup.png` or `artifacts/screenshots/iphone-16-ja/setup.png`

2. Home
   - Purpose: shows the main lock composer and selected target summary.
   - Use for: explaining the main workflow.
   - Current file in CI artifact: `artifacts/screenshots/iphone-16-en/home.png` or `artifacts/screenshots/iphone-16-ja/home.png`

3. Confirmation
   - Purpose: shows the commitment moment before locking.
   - Use for: explaining that the user confirms target apps and wake time.
   - Current file in CI artifact: `artifacts/screenshots/iphone-16-en/confirmation.png` or `artifacts/screenshots/iphone-16-ja/confirmation.png`

4. Active Lock
   - Purpose: shows sleeping bear, countdown, and no early unlock affordance.
   - Use for: demonstrating core behavior.
   - Current file in CI artifact: `artifacts/screenshots/iphone-16-en/activeLock.png` or `artifacts/screenshots/iphone-16-ja/activeLock.png`

5. Diagnostics
   - Purpose: shows local troubleshooting state.
   - Use for: reviewer/support docs, not primary consumer marketing unless needed.
   - Current file in CI artifact: `artifacts/screenshots/iphone-16-en/diagnostics.png` or `artifacts/screenshots/iphone-16-ja/diagnostics.png`

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

## Needed Before Final App Store Screenshots

- Replace placeholder bundle identifiers and sign with the real team.
- Decide whether iPhone-only screenshots are enough for first submission.
- Capture final screenshots from a signed build after entitlement approval.
- Confirm final Japanese/English localization direction.
- Confirm final brand image rights and production assets.
