# iOS review fixes — 2026-09-13

> 2026-10-26整理: 本文は当時の検証記録です。旧画像・途中ログは作業ツリーから削除し、Git管理されていた証跡は固定コミットの履歴へリンクしています。整理済みのローカル出力は同梱していません。

Source commit: `cbc1640233c06fa10c910b66f6f465391fa4b424`.

## Changes

- Qualify `MonitoringSchedule.desired` explicitly so the app and extensions compile.
- Observe the selected target (ID and content), rather than the target catalog. Keep decoded counts and details in one view snapshot.
- Show the recurring lock's calculated end date/time in confirmation, rather than a nominal elapsed duration. Immediate and delayed locks retain their elapsed-duration explanations.

## Regression coverage

- `testReusingTargetRefreshesHomeCountsDetailsAndConfirmation`: launch with target A (Messages, Video, Games), expand details, select saved B (Books, Music), assert 3→2 counts and replaced details, switch B→A→B without leaving the screen, then verify confirmation uses B.
- `testReuseChangesSelectionAndSummaryWithoutChangingTargetCatalog`: exercise AppModel and repository, verify that the catalog remains unchanged while the selected ID, summary and persisted selection change.
- `testCreateAndOpenRecurringEditorWithMockServices`: verify confirmation shows 7:00 and does not describe an elapsed duration.
- Existing core tests cover spring/fall DST: the 23:00–07:00 schedule lasts 7/9 hours while preserving the configured end time.

The UI fixture replaces decoding/rendering of private Screen Time tokens only. Selection actions, repository writes, published state, SwiftUI change observation, summary counts, disclosure and confirmation use the app's regular flow. The fixture does not prove that the OS supplies or renders real application tokens correctly.

## Device-only checks

- Select actual applications and categories through FamilyActivityPicker; switch saved targets with the details open and check counts, real names/icons, and confirmation.
- Verify actual shielding and expiry without opening Bear Lock. Mock services do not exercise OS callback delivery or real Screen Time enforcement.

## GitHub Actions evidence

- [iOS Lock Lifecycle](https://github.com/hiroyoshii/bearlock/actions/runs/34741644777): **success** on the source commit above. Core: 57/57; AppModel: 7/7; UI regression: 10/10; process transactions and Debug/Release app/extension builds passed. The new target-reuse E2E passed in 14.034 seconds.
- [iOS CI](https://github.com/hiroyoshii/bearlock/actions/runs/34741644778): **success** on the same source commit. Full UI E2E: 15/15, zero failures; target reuse passed in 14.747 seconds, and recurring confirmation passed. App/extension builds and screenshot generation passed.
- Raw summaries and bounded logs: [ci-results/ios-review/cbc1640233c06fa10c910b66f6f465391fa4b424/（履歴）](https://github.com/hiroyoshii/bearlock/tree/44465600fe304f1ab53b97de3a9f79180650063d/ci-results/ios-review/cbc1640233c06fa10c910b66f6f465391fa4b424).
- Visually checked `screenshots/e2e-target-summary-before-reuse.png`, `e2e-target-summary-after-reuse.png`, and `e2e-target-summary-confirmation.png` in that directory: counts changed 3→2, Messages/Video/Games changed to Books/Music, and confirmation displayed 2 targets.
- Local WSL validation: Swift core 57/57, changed Swift sources parsed successfully, workflow YAML and collector Python syntax validated. Xcode validation above ran on GitHub-hosted macOS; it was not claimed from WSL checks.
