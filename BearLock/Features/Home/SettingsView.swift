import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    BearStateVisual(state: .ready, compact: true)
                        .frame(height: 108)
                    BrandLockup(
                        subtitle: "A private space that protects your time and energy.",
                        compact: true
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(AppTheme.background)
            }

            Section("データの扱い") {
                Text("MVPでは選択アプリとロック予定を端末内のApp Group領域に保存します。アカウント、クラウド同期、利用統計は扱いません。")
                    .font(.body)
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
            }

            Section("App") {
                diagnosticRow("Bundle ID", summary.bundleIdentifier)
                diagnosticRow("Version", summary.appVersion)
                diagnosticRow("Diagnostics writable", summary.diagnosticsWritable ? "Yes" : "No")
                Text(summary.appGroupPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
        LabeledContent(title) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
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
