import SwiftUI

enum BearVisualState {
    case ready
    case arming
    case locked

    var assetName: String {
        switch self {
        case .ready:
            return "BearVisualReady"
        case .arming:
            return "BearVisualArming"
        case .locked:
            return "BearVisualLocked"
        }
    }
}

struct BearStateVisual: View {
    var state: BearVisualState
    var compact: Bool = false

    var body: some View {
        Image(state.assetName)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 10))
            .accessibilityHidden(true)
    }
}

struct BearDenArt: View {
    var sleeping: Bool = true
    var compact: Bool = false

    var body: some View {
        BearStateVisual(state: sleeping ? .locked : .ready, compact: compact)
    }
}

struct BearHeroArt: View {
    var body: some View {
        BearStateVisual(state: .ready)
    }
}

struct BrandLockup: View {
    var subtitle: String
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            HStack(spacing: 10) {
                Image("BrandAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 34 : 46, height: compact ? 34 : 46)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 10))
                Text("Bear Lock")
                    .font(.system(size: compact ? 28 : 44, weight: .bold, design: .rounded))
            }
            .foregroundStyle(AppTheme.navy)

            Text(subtitle)
                .font(compact ? .subheadline : .title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.steel)
        }
    }
}
