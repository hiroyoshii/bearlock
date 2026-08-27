import SwiftUI

struct BearDenArt: View {
    var sleeping: Bool = true
    var compact: Bool = false

    var body: some View {
        Image("BrandDen")
            .resizable()
            .scaledToFit()
            .padding(compact ? 0 : 4)
        .accessibilityHidden(true)
    }
}

struct BearHeroArt: View {
    var body: some View {
        Image("BrandHero")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
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
