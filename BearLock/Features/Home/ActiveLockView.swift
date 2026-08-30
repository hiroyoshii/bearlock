import BearLockCore
import SwiftUI

struct ActiveLockView: View {
    let activeLock: ActiveLock
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            BearStateVisual(state: .sleeping)
                .frame(maxWidth: 300)

            Text("Bear is sleeping.")
                .font(.title.bold())
                .foregroundStyle(AppTheme.navy)

            Text("Do not wake the bear.")
                .foregroundStyle(AppTheme.navy.opacity(0.72))

            Text(remainingText)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.navy)

            Text("Wakes at \(activeLock.endsAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(AppTheme.navy.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(AppTheme.ice, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.navy.opacity(0.16), lineWidth: 1)
        )
        .onReceive(timer) { date in
            now = date
        }
    }

    private var remainingText: String {
        let seconds = Int(activeLock.remainingTime(at: now))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
