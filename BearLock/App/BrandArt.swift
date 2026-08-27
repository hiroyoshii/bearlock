import SwiftUI

struct BearDenArt: View {
    var sleeping: Bool = true
    var compact: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 18 : 32)
                    .fill(AppTheme.ice.opacity(0.62))

                SnowField()
                    .foregroundStyle(AppTheme.snow.opacity(0.95))

                VStack(spacing: 0) {
                    Spacer(minLength: size * 0.12)
                    den(size: size)
                    snowBase(size: size)
                }
            }
        }
        .aspectRatio(compact ? 1.6 : 1.0, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func den(size: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Arch()
                .fill(AppTheme.snow)
                .frame(width: size * 0.78, height: size * 0.62)
                .overlay {
                    Arch()
                        .stroke(AppTheme.navy.opacity(0.14), lineWidth: 1)
                }

            Arch()
                .fill(AppTheme.steel.opacity(0.28))
                .frame(width: size * 0.52, height: size * 0.42)

            Arch()
                .fill(AppTheme.navy.opacity(0.78))
                .frame(width: size * 0.36, height: size * 0.30)

            LockStone()
                .fill(AppTheme.snow.opacity(0.92))
                .frame(width: size * 0.13, height: size * 0.20)
                .offset(y: -size * 0.27)

            sleepingBear(size: size)
                .offset(y: size * 0.02)
        }
    }

    private func sleepingBear(size: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.98, green: 0.94, blue: 0.86))
                .frame(width: size * 0.42, height: size * 0.22)
                .offset(y: size * 0.03)

            Circle()
                .fill(Color(red: 0.98, green: 0.94, blue: 0.86))
                .frame(width: size * 0.24)
                .offset(x: -size * 0.16, y: -size * 0.02)

            Circle()
                .fill(Color(red: 0.98, green: 0.94, blue: 0.86))
                .frame(width: size * 0.07)
                .offset(x: -size * 0.24, y: -size * 0.12)

            Circle()
                .fill(Color(red: 0.98, green: 0.94, blue: 0.86))
                .frame(width: size * 0.07)
                .offset(x: -size * 0.09, y: -size * 0.13)

            Circle()
                .fill(AppTheme.navy.opacity(0.72))
                .frame(width: size * 0.018)
                .offset(x: -size * 0.18, y: -size * 0.03)

            Path { path in
                path.move(to: CGPoint(x: size * 0.48, y: size * 0.50))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.55, y: size * 0.50),
                    control: CGPoint(x: size * 0.515, y: size * 0.535)
                )
            }
            .stroke(AppTheme.navy.opacity(0.58), lineWidth: 1.3)
            .offset(x: -size * 0.33, y: -size * 0.09)

            if sleeping {
                Text("Zz")
                    .font(.system(size: size * 0.09, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.snow.opacity(0.86))
                    .offset(x: size * 0.20, y: -size * 0.21)
            }
        }
    }

    private func snowBase(size: CGFloat) -> some View {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 24, topTrailing: 24))
            .fill(AppTheme.snow.opacity(0.96))
            .frame(height: size * 0.18)
            .overlay(alignment: .topLeading) {
                HStack(spacing: size * 0.08) {
                    Circle().frame(width: size * 0.04, height: size * 0.04)
                    Capsule().frame(width: size * 0.18, height: size * 0.025)
                    Circle().frame(width: size * 0.03, height: size * 0.03)
                }
                .foregroundStyle(AppTheme.steel.opacity(0.18))
                .padding(.leading, size * 0.16)
                .padding(.top, size * 0.03)
            }
    }
}

struct BrandLockup: View {
    var subtitle: String
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            HStack(spacing: 10) {
                MiniBearFace()
                    .frame(width: compact ? 30 : 40, height: compact ? 30 : 40)
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

private struct MiniBearFace: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.99, green: 0.96, blue: 0.90))
            Circle()
                .fill(Color(red: 0.99, green: 0.96, blue: 0.90))
                .frame(width: 10, height: 10)
                .offset(x: -11, y: -11)
            Circle()
                .fill(Color(red: 0.99, green: 0.96, blue: 0.90))
                .frame(width: 10, height: 10)
                .offset(x: 11, y: -11)
            Circle()
                .fill(AppTheme.navy.opacity(0.72))
                .frame(width: 3, height: 3)
                .offset(x: -7, y: -2)
            Circle()
                .fill(AppTheme.navy.opacity(0.72))
                .frame(width: 3, height: 3)
                .offset(x: 7, y: -2)
            Circle()
                .fill(AppTheme.navy.opacity(0.72))
                .frame(width: 4, height: 3)
                .offset(y: 5)
        }
    }
}

private struct SnowField: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [
            CGPoint(x: 0.18, y: 0.18),
            CGPoint(x: 0.34, y: 0.10),
            CGPoint(x: 0.64, y: 0.14),
            CGPoint(x: 0.78, y: 0.25),
            CGPoint(x: 0.22, y: 0.38),
            CGPoint(x: 0.52, y: 0.30),
            CGPoint(x: 0.86, y: 0.45),
            CGPoint(x: 0.12, y: 0.56),
            CGPoint(x: 0.72, y: 0.62)
        ]

        for point in points {
            let center = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            path.addEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
        }
        return path
    }
}

private struct Arch: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.28)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct LockStone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 8, height: 8))
        let shackle = CGRect(x: rect.midX - rect.width * 0.24, y: rect.minY + rect.height * 0.12, width: rect.width * 0.48, height: rect.height * 0.38)
        path.addEllipse(in: shackle)
        path.addRect(CGRect(x: rect.midX - rect.width * 0.09, y: rect.midY, width: rect.width * 0.18, height: rect.height * 0.28))
        return path
    }
}
