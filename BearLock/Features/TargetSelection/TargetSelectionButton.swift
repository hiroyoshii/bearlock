import FamilyControls
import SwiftUI

struct TargetSelectionButton: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false

    let prominent: Bool

    var body: some View {
        baseButton
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onChange(of: isPickerPresented) { _, presented in
                guard !presented else { return }
                Task {
                    await model.saveSelection(selection)
                }
            }
    }

    @ViewBuilder
    private var baseButton: some View {
        let button = Button {
            do {
                selection = try model.targetSelectionStore.load()
            } catch {
                selection = FamilyActivitySelection()
            }
            isPickerPresented = true
        } label: {
            Label("Select blocked apps", systemImage: "app.badge")
                .frame(maxWidth: .infinity)
        }

        if prominent {
            button
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(AppTheme.steel)
        }
    }
}

struct TargetSelectionSummaryView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var summary = TargetSelectionSummary.empty

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Selected apps", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                Text(summaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(summary.total == 0 ? AppTheme.navy.opacity(0.5) : AppTheme.navy)
            }

            if summary.total == 0, let fallbackSelectionName {
                Text(fallbackSelectionName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.navy.opacity(0.72))
                Text("Saved selection")
                    .font(.caption)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            } else if summary.total == 0 {
                Text("No blocked apps are selected.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            } else {
                HStack(spacing: 8) {
                    summaryPill(title: "Apps", count: summary.applications)
                    summaryPill(title: "Categories", count: summary.categories)
                    summaryPill(title: "Websites", count: summary.webDomains)
                }
                Text("iOS keeps selected app names private. Bear Lock can show counts and enforce the saved selection.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: model.lockState.targetSelections) { _, _ in
            refresh()
        }
    }

    private func summaryPill(title: String, count: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline.monospacedDigit())
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(AppTheme.navy)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.ice, in: RoundedRectangle(cornerRadius: 8))
    }

    private var summaryTitle: String {
        if summary.total > 0 {
            return L10n.format("%d targets", summary.total)
        }

        if fallbackSelectionName != nil {
            return L10n.string("Saved")
        }

        return L10n.string("None")
    }

    private var fallbackSelectionName: String? {
        model.lockState.targetSelections.last?.displayName
    }

    private func refresh() {
        do {
            summary = TargetSelectionSummary(selection: try model.targetSelectionStore.load())
        } catch {
            summary = .empty
        }
    }
}

private struct TargetSelectionSummary: Equatable {
    var applications: Int
    var categories: Int
    var webDomains: Int

    var total: Int {
        applications + categories + webDomains
    }

    static let empty = TargetSelectionSummary(applications: 0, categories: 0, webDomains: 0)

    init(applications: Int, categories: Int, webDomains: Int) {
        self.applications = applications
        self.categories = categories
        self.webDomains = webDomains
    }

    init(selection: FamilyActivitySelection) {
        self.init(
            applications: selection.applicationTokens.count,
            categories: selection.categoryTokens.count,
            webDomains: selection.webDomainTokens.count
        )
    }
}
