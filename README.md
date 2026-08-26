# Bear Lock

Bear Lock is an iOS Screen Time app MVP for scheduling app hibernation windows that cannot be ended early from inside Bear Lock.

## Current State

This repository contains:

- Native SwiftUI app source under `BearLock/`.
- Screen Time service wrappers for `FamilyControls`, `ManagedSettings`, and `DeviceActivity`.
- Device Activity Monitor, Shield Configuration, and Shield Action extension source.
- OS-independent core domain logic under `Sources/BearLockCore`.
- XCTest coverage for lock planning, recurrence, overlap rejection, and active lock immutability.
- Design and implementation docs under `docs/`.

## Generate The Xcode Project

The WSL environment includes Swift through Swiftly for core package tests. Xcode and XcodeGen are still macOS-side requirements. On macOS:

```sh
brew install xcodegen
xcodegen generate
open BearLock.xcodeproj
```

Before building, replace placeholder identifiers:

- `DEVELOPMENT_TEAM` in `project.yml`
- `com.example.bearlock*` bundle identifiers
- `group.com.example.bearlock` App Group in entitlements and `BearLock/Services/AppGroup.swift`

The app requires Apple's Family Controls capability and the corresponding development/distribution entitlement.

## Core Tests

On a machine with Swift installed:

```sh
swift test
```

Current WSL validation:

- Swift 6.3.3 installed with Swiftly.
- `swift test` passes for `BearLockCore`.

Real Screen Time behavior must be verified on a physical iOS device. Simulator-only validation is not enough for this app.

## GitHub Actions iOS CI

The workflow at `.github/workflows/ios-ci.yml` runs on `macos-15` and performs the highest-value automated validation available without a physical iPhone:

- Generate `BearLock.xcodeproj` with XcodeGen.
- Run `swift test` for `BearLockCore`.
- Build the iOS app and extensions for iOS Simulator with signing disabled.
- Run a UI launch test against an iPhone simulator.
- Attach an XCTest screenshot and export a booted simulator screenshot as workflow artifacts.

The artifact is named `bearlock-ios-ci-artifacts`.

This CI can catch Swift/package regressions, Xcode project generation failures, iOS compile errors, extension compile errors, and basic launch/UI regressions. It cannot prove real Screen Time enforcement, Shield display over third-party apps, Family Controls authorization behavior, or DeviceActivity background callback behavior. Those still require a signed build on a physical iOS device with the Family Controls entitlement.
