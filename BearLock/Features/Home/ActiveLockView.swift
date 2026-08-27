import BearLockCore
import SwiftUI

struct ActiveLockView: View {
    let activeLock: ActiveLock
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            BearDenArt()
                .frame(maxWidth: 300)

            Text("Bear is sleeping.")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Do not wake the bear.")
                .foregroundStyle(.white.opacity(0.82))

            Text(remainingText)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text("Wakes at \(activeLock.endsAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.navy],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 8)
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
