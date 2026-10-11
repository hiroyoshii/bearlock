import BearLockCore
import SwiftUI

struct LockConfirmationDetails: Equatable {
    var title: String
    var targetSummary: String
    var startsAt: Date
    var endsAt: Date
    var startSummary: String? = nil
    var endSummary: String? = nil
    var isImmediate: Bool
    var isRecurring: Bool = false
}

struct LockConfirmationSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let details: LockConfirmationDetails
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    BearStateVisual(state: .arming, compact: true)
                        .frame(width: 168, height: 118)
                        .padding(.top, 10)

                    Text(LocalizedStringKey(details.title))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.navy)

                    Text(LocalizedStringKey(details.isRecurring ? "A wake-up ends only the current lock. Future repeating locks stay scheduled." : "After this starts, the schedule cannot be changed. Waking early takes 30 minutes unless you purchase an immediate wake-up."))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.navy.opacity(0.68))
                }

                VStack(spacing: 12) {
                    row(label: "Apps", value: details.targetSummary)
                    row(label: "Starts", value: details.startSummary ?? details.startsAt.formatted(date: .abbreviated, time: .shortened))
                    row(label: "Wakes", value: details.endSummary ?? details.endsAt.formatted(date: .abbreviated, time: .shortened))
                }
                .padding(16)
                .background(AppTheme.ice, in: RoundedRectangle(cornerRadius: 8))

                VStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(LocalizedStringKey(details.isImmediate ? "Start Lock" : "Schedule Lock"), systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppTheme.navy)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("lock-confirmation-confirm-button")

                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSubmitting)
                }
            }
            .padding(24)
        }
        .presentationDetents([.height(560), .large])
    }

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(label))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.navy.opacity(0.72))
                Text(value)
                    .accessibilityIdentifier("lock-confirmation-\(label.lowercased())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.navy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(label))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
                Spacer(minLength: 20)
                Text(value)
                    .accessibilityIdentifier("lock-confirmation-\(label.lowercased())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.navy)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
