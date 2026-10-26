# Bear Lock

Bear Lock provides native iOS and Android apps for scheduled app hibernation.

## Product specification

[現行仕様と構造の正本](docs/design-doc.md) — 製品の思想、共通契約、iOS固有仕様、Android固有仕様、UI、現行の責務対応をここに集約しています。READMEはビルド・実行・検証への入口です。

[仕様・責務・コード・テストの対応表（2026-10-26更新）](docs/qa/android-ios-structure-audit-2026-10-25.md) — 正本の基準IDごとに各OSの担当・適合状況・テストを対応付けています。仕様判断待ち・検証不足・任意の改善は不適合から分離しています。

## Current State

This repository contains:

- Native SwiftUI app source under `BearLock/`.
- Screen Time service wrappers for `FamilyControls`, `ManagedSettings`, and `DeviceActivity`.
- Device Activity Monitor, Shield Configuration, and Shield Action extension source.
- OS-independent core domain logic under `Sources/BearLockCore`.
- XCTest coverage for lock planning, recurrence, overlap rejection, and active lock immutability.
- Mock-driven UI end-to-end tests for the core creation/edit/delete flows.
- Up to three frequently used target selections, recorded automatically with pin and remove controls.
- On-device Diagnostics screen for local troubleshooting without external logging.
- Debug-build safety limit for pre-device testing.
- English and Japanese app localization strings.
- Design and implementation docs under `docs/`.

## Generate The Xcode Project

The WSL environment includes Swift through Swiftly for core package tests. Xcode and XcodeGen are still macOS-side requirements. On macOS:

```sh
brew install xcodegen
xcodegen generate
open BearLock.xcodeproj
```

Before building, replace placeholder identifiers:

- `DEVELOPMENT_TEAM` in `project.yml` is set to `3M4M7DRUZY`.
- Bundle identifiers are set to `com.hiyozoo.bearlock*`.
- App Group is set to `group.com.hiyozoo.bearlock` in entitlements and `BearLock/Services/AppGroup.swift`.

The app requires Apple's Family Controls capability and the corresponding development/distribution entitlement.

## Core Tests

On a machine with Swift installed:

```sh
swift test
```

Current WSL validation:

- Swift 6.3.3 installed with Swiftly.
- `swift test` passes for `BearLockCore` with 82 tests (2026-10-26).

Real Screen Time behavior must be verified on a physical iOS device. Simulator-only validation is not enough for this app.

## GitHub Actions iOS CI

The workflow at `.github/workflows/ios-ci.yml` performs automated validation without a physical iPhone:

- Generate `BearLock.xcodeproj` with XcodeGen.
- Validate plist, entitlement, and asset catalog metadata.
- Run `swift test` for `BearLockCore`.
- Run repository transaction and app-model integration tests.
- Build the iOS app and extensions in Release and Debug for iOS Simulator with signing disabled.
- Run the complete mock-driven UI test suite against an iPhone simulator.
- Run StoreKit purchase tests in a separate macOS 15 job.
- Export e2e screenshots and English/Japanese static screen snapshots as workflow artifacts.

The artifacts are named `bearlock-ios-ci-artifacts` and `storekit-purchase-results`. CI does not commit test results or screenshots to `main`.

The mock e2e tests currently cover setup launch, immediate lock creation, delayed lock creation, delayed lock edit/delete, recurring lock creation/disable, and active-lock immutability controls. This CI can catch Swift/package regressions, Xcode project generation failures, iOS compile errors, extension compile errors, and the main mock UI workflows. It cannot prove real Screen Time enforcement, Shield display over third-party apps, Family Controls authorization behavior, or DeviceActivity background callback behavior. Those still require a signed build on a physical iOS device with the Family Controls entitlement.

Pushes to the repository are expected to start this workflow automatically.

## Verification artifacts

Keep the current gallery in `ci-screenshots/`, the latest evidence for each verification scope in `ci-results/`, and evidence needed for unresolved issues. Capture provenance (source/APK hash, OS, test scope) travels with retained results; a newer build-only run does not replace UI or device evidence.

Write local captures, reports and logs under ignored `artifacts/`. Replace superseded output instead of accumulating dated copies. Historical QA prose may link to a fixed Git commit; superseded images, rejected attempts, comparison exports and intermediate logs are not retained in the working tree. See [current captures](ANDROID_SCREENSHOTS.md) and [verification scope](docs/qa/android-ios-structure-audit-2026-10-25.md).

## Remaining Work

製品方針は [現行仕様](docs/design-doc.md) を参照してください。[Android / iOS整合の実装・検証記録](docs/android-ios-execution-plan.md) は過去の結果であり、仕様変更の計画書ではありません。

Active pre-release tasks are tracked in `todo.md`.

Launch preparation drafts are under `docs/launch/`.

## Android Comparison Lab

`android-lab/` contains a bounded Android experiment comparing UsageStats with Accessibility-based app blocking, plus a separate target app and repeatable emulator scripts. It is not the Android release.

- [Build and run the experiment](android-lab/README.md)
- [Comparison results](docs/android-comparison-results.md)
- [iOS feature parity goals](docs/android-feature-parity.md)
- [Android 復帰処理の修正と追試](docs/android-recovery-results.md)

## Android Product

`android-lab/product` contains the Android app UI, schedule planner, local storage and Accessibility blocking implementation. It builds as `com.hiyozoo.bearlock`; the comparison lab remains separate.

- [Build and product behavior](android-lab/product/README.md)
- [Implementation TODO](docs/android-implementation-todo.md)
- [Implementation results and screenshots](docs/android-product-results.md)
- [Play release preparation](docs/android-release-preparation.md)

- [Android / iOS スクショ比較](ANDROID_SCREENSHOTS.md)
- [iOS UIへの整合と差分](docs/android-ui-parity.md)
