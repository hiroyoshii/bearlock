import BearLockCore
import SwiftUI

struct LockConfirmationDetails: Equatable {
    var title: String
    var targetSummary: String
    var startsAt: Date
    var endsAt: Date
    var isImmediate: Bool
}

struct LockConfirmationSheet: View {
    let details: LockConfirmationDetails
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                BearStateVisual(state: .arming, compact: true)
                    .frame(width: 168, height: 118)
                    .padding(.top, 10)

                Text(LocalizedStringKey(details.title))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.navy)

                Text("After this starts, it cannot be shortened or ended early.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.navy.opacity(0.68))
            }

            VStack(spacing: 12) {
                row(label: "Apps", value: details.targetSummary)
                row(label: "Starts", value: details.startsAt.formatted(date: .abbreviated, time: .shortened))
                row(label: "Wakes", value: details.endsAt.formatted(date: .abbreviated, time: .shortened))
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
        .presentationDetents([.height(560), .large])
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(label))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy.opacity(0.62))
            Spacer(minLength: 20)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
                .multilineTextAlignment(.trailing)
        }
    }
}
