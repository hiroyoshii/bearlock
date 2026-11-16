# Usage Limit UI Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve usage-limit naming, color, defaults and paid-unlock visibility.
**Architecture:** Modify the existing SwiftUI views and core policy. StoreKit remains the price source.
**Tech Stack:** SwiftUI, XCTest, Swift Package, iOS Simulator.
**Spec:** docs/superpowers/specs/2026-11-16-usage-limit-ui-design.md

## Global Constraints

Preserve saved limits, the paid entry, and unrelated user changes.

## Review Focus

Check medium sheet height, large text, unavailable price, existing 60-minute policies and Japanese tab widths.

### Task 1: Usage limits

- [x] Capture baseline screenshots.
- [x] Update DailyAllowanceTests to prove the 60-minute default and 120-minute acceptance; run and observe failure.
- [x] Centralize the default in DailyAllowancePolicy and consume it in LockComposerView. Update localized names and control colors.
- [x] Run swift test.

### Task 2: Paid unlock

- [x] Modify the existing sheet in ScheduledLockListView with a visible price and pinned purchase action.
- [x] Extend the existing UI test to assert the purchase action is visible without scrolling.
- [x] Build and run UI tests; capture and inspect matching after screenshots.
