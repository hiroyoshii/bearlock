import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    BearStateVisual(state: .ready, compact: true)
                        .frame(height: 108)
                    Text("Set app locks that end automatically at the chosen time.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.steel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(AppTheme.background)
            }

            Section("Data handling") {
                Text("Selected app tokens, schedules, and diagnostics stay on this device. No accounts, cloud sync, ads, analytics, or tracking.")
                    .font(.body)
            }

            Section("Support") {
                NavigationLink {
                    SupportView()
                } label: {
                    Label("Support Bear Lock", systemImage: "heart")
                }
            }

            Section("Debug") {
                NavigationLink {
                    DebugDiagnosticsView()
                } label: {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct DebugDiagnosticsView: View {
    @EnvironmentObject private var model: BearLockAppModel

    var body: some View {
        let summary = model.diagnosticsSummary

        List {
            Section("Status") {
                diagnosticRow("Authorization", summary.authorizationStatus)
                diagnosticRow("Target selections", "\(summary.targetSelectionCount)")
                diagnosticRow("Scheduled rules", "\(summary.scheduledRuleCount)")
                diagnosticRow("Recurring rules", "\(summary.recurringRuleCount)")
                diagnosticRow("Active lock", summary.activeLockStatus)
                diagnosticRow("Last error", summary.lastError)
                diagnosticRow("Last warning", summary.lastWarning)
                diagnosticRow("Safety policy", summary.safetyPolicy)
            }

            Section("Trace") {
                diagnosticRow("Selection", summary.lastSelectionEvent)
                diagnosticRow("Lock", summary.lastLockEvent)
                diagnosticRow("DeviceActivity", summary.lastDeviceActivityEvent)
                diagnosticRow("Shield", summary.lastShieldEvent)
                diagnosticRow("Shield UI", summary.lastShieldConfigurationEvent)
            }

            Section("App") {
                diagnosticRow("Bundle ID", summary.bundleIdentifier)
                diagnosticRow("Version", summary.appVersion)
                diagnosticRow("Diagnostics writable", summary.diagnosticsWritable ? L10n.string("Yes") : L10n.string("No"))
                Text(summary.appGroupPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("Device Check") {
                checkRow("Authorize Screen Time")
                checkRow("Choose at least one target")
                checkRow("Create a short lock")
                checkRow("Open a blocked app")
                checkRow("Confirm shield appears")
                checkRow("Wait for wake time")
                checkRow("Confirm shield clears")
            }

            Section("Recent Events") {
                if model.diagnosticsSnapshot.events.isEmpty {
                    Text("No events yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.diagnosticsSnapshot.events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(event.level.rawValue.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(color(for: event.level))
                            }
                            Text(event.date.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let detail = event.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    model.clearDiagnostics()
                } label: {
                    Label("Clear Diagnostics", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Diagnostics")
        .task {
            model.refreshDiagnostics()
        }
        .refreshable {
            model.refreshDiagnostics()
        }
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        LabeledContent(LocalizedStringKey(title)) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func checkRow(_ title: String) -> some View {
        Label(LocalizedStringKey(title), systemImage: "checkmark.circle")
            .foregroundStyle(AppTheme.navy)
    }

    private func color(for level: DiagnosticLevel) -> Color {
        switch level {
        case .info:
            return AppTheme.steel
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
