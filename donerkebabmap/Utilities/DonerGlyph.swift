//
//  DonerGlyph.swift
//  donerkebabmap
//

import SwiftUI

/// Scalable custom icon of a doner spit (vertical skewer + meat cone).
/// Used as the brand mark on pins, list rows and cards.
struct DonerGlyph: View {
    private let meat: AnyShapeStyle
    private let spit: Color

    init(meat: some ShapeStyle = DonerGlyph.meatGradient, spit: Color = Color(white: 0.82)) {
        self.meat = AnyShapeStyle(meat)
        self.spit = spit
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Skewer (sticks out above and below the meat)
                Capsule()
                    .fill(spit)
                    .frame(width: max(1.5, w * 0.07), height: h * 0.98)

                // Handle knob on top
                Circle()
                    .fill(spit)
                    .frame(width: w * 0.18, height: w * 0.18)
                    .offset(y: -h * 0.45)

                // Meat cone (barrel-shaped)
                DonerMeatShape()
                    .fill(meat)
                    .frame(width: w * 0.72, height: h * 0.72)
            }
            .frame(width: w, height: h)
        }
    }

    /// Warm brown gradient for a roasted-meat look.
    static let meatGradient = LinearGradient(
        colors: [
            Color(red: 0.80, green: 0.53, blue: 0.30),
            Color(red: 0.66, green: 0.40, blue: 0.21),
            Color(red: 0.50, green: 0.28, blue: 0.15)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Silhouette of the doner meat: a barrel that bulges in the middle and tapers to a point.
private struct DonerMeatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let half = rect.width / 2
        let top = rect.minY
        let bottom = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: cx, y: top))
        path.addQuadCurve(
            to: CGPoint(x: cx + half, y: rect.minY + rect.height * 0.42),
            control: CGPoint(x: cx + half, y: rect.minY + rect.height * 0.10)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx, y: bottom),
            control: CGPoint(x: cx + half * 0.72, y: rect.minY + rect.height * 0.92)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx - half, y: rect.minY + rect.height * 0.42),
            control: CGPoint(x: cx - half * 0.72, y: rect.minY + rect.height * 0.92)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx, y: top),
            control: CGPoint(x: cx - half, y: rect.minY + rect.height * 0.10)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        DonerGlyph()
            .frame(width: 80, height: 100)
        DonerGlyph(meat: Color.white, spit: .white)
            .frame(width: 40, height: 50)
            .padding()
            .background(AppTheme.brandGradient)
    }
    .padding()
}
