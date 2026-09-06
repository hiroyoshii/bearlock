# Android / iOS UI parity

Baseline: current SwiftUI sources and `ci-screenshots/app-store-ja` / `app-store-en`.
The iOS images use ScreenshotSupport fixtures; Android device verification is separate from visual fixtures.

- [x] Home: branded header, selection disclosure, embedded composer, inline schedules; remove bottom navigation / unrelated hero.
- [x] Composer: horizontal four modes, 15–720 minute slider/presets, delay stepper, Sunday-first weekdays, start/end time.
- [x] Active/confirmation/setup: original matching bear assets and composition.
- [x] Picker: cancel transaction, persistent selection, fixed bottom save; recent selection/pin/delete.
- [x] Schedule editing, recurring enabled toggle, active snapshot immutability.
- [x] Settings: grouped information and Android permission recovery.
- [x] Build, unit tests, lint and emulator interactions / blocking regression.
- [x] Capture Japanese/English screens; produce iOS/Android side-by-side and pixel diff with limitations.
- [x] Publish reviewable source, screenshots and comparison in repository branch.

## Follow-up

上記は今回実装・エミュレーター確認した範囲。残る見た目の差の調整は [AND-02](android-implementation-todo.md)、操作性の網羅確認は AND-08 で追跡する。OS固有の表示をピクセル一致したとは扱わない。残作業の正本は [Android製品版TODO](android-implementation-todo.md)。
