import FamilyControls
import SwiftUI

struct TargetSelectionButton: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false
    @State private var shouldSaveSelectionOnDismiss = false

    let prominent: Bool

    var body: some View {
        baseButton
            .disabled(isLocked)
            .sheet(isPresented: $isPickerPresented, onDismiss: {
                if shouldSaveSelectionOnDismiss {
                    Task {
                        await model.saveSelection(selection)
                    }
                    shouldSaveSelectionOnDismiss = false
                }
            }) {
                TargetSelectionPickerSheet(
                    selection: $selection,
                    onCancel: {
                        shouldSaveSelectionOnDismiss = false
                        isPickerPresented = false
                    },
                    onSave: {
                        shouldSaveSelectionOnDismiss = true
                        isPickerPresented = false
                    }
                )
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
            Label(isLocked ? "Cannot change during lock" : "Select targets", systemImage: "app.badge")
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

    private var isLocked: Bool {
        model.lockState.activeLock?.isActive(at: Date()) == true
    }
}

private struct TargetSelectionPickerSheet: View {
    @Binding var selection: FamilyActivitySelection

    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Select targets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        Text(selectionHint)
                            .font(.caption)
                            .foregroundStyle(AppTheme.navy.opacity(0.62))
                            .multilineTextAlignment(.center)

                        Button(action: onSave) {
                            Label("Save", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(AppTheme.navy)
                        .disabled(selectionCount == 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .background(.regularMaterial)
                }
        }
    }

    private var selectionHint: LocalizedStringKey {
        selectionCount == 0 ? "No targets are selected." : LocalizedStringKey(L10n.format("%d targets", selectionCount))
    }

    private var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }
}

struct TargetSelectionSummaryView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var summary = TargetSelectionSummary.empty
    @State private var loadedSelection: FamilyActivitySelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Selected targets", systemImage: "checkmark.circle")
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
                Text("No targets are selected.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            } else {
                HStack(spacing: 8) {
                    summaryPill(title: "Apps", count: summary.applications)
                    summaryPill(title: "Categories", count: summary.categories)
                    summaryPill(title: "Websites", count: summary.webDomains)
                }
                if let loadedSelection {
                    TokenSelectionListView(selection: loadedSelection)
                }
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
            let selection = try model.targetSelectionStore.load()
            loadedSelection = selection
            summary = TargetSelectionSummary(selection: selection)
        } catch {
            loadedSelection = nil
            summary = .empty
        }
    }
}

private struct TokenSelectionListView: View {
    let selection: FamilyActivitySelection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !selection.applicationTokens.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    tokenGroupTitle("Apps")
                    ForEach(Array(selection.applicationTokens.prefix(5)), id: \.self) { token in
                        tokenRow {
                            Label(token)
                        }
                    }
                }
            }
            if !selection.categoryTokens.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    tokenGroupTitle("Categories")
                    ForEach(Array(selection.categoryTokens.prefix(5)), id: \.self) { token in
                        tokenRow {
                            Label(token)
                        }
                    }
                }
            }
            if !selection.webDomainTokens.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    tokenGroupTitle("Websites")
                    ForEach(Array(selection.webDomainTokens.prefix(5)), id: \.self) { token in
                        tokenRow {
                            Label(token)
                        }
                    }
                }
            }
            if overflowCount > 0 {
                Text(L10n.format("+%d more", overflowCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            }
        }
    }

    private func tokenGroupTitle(_ title: String) -> some View {
        Text(LocalizedStringKey(title))
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.navy.opacity(0.62))
    }

    private func tokenRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
                .labelStyle(TargetTokenLabelStyle())
                .font(.subheadline.weight(.semibold))
                .environment(\.colorScheme, .light)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.navy.opacity(0.12), lineWidth: 1)
        )
    }

    private var overflowCount: Int {
        max(0, selection.applicationTokens.count - 5)
            + max(0, selection.categoryTokens.count - 5)
            + max(0, selection.webDomainTokens.count - 5)
    }
}

private struct TargetTokenLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
            configuration.title
                .foregroundStyle(AppTheme.navy)
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
