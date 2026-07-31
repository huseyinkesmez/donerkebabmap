//
//  DonerConeLogo.swift
//  donerkebabmap
//
//  Görsel kimlikteki "Kalın Konturlu Dürüm" logosunun SwiftUI'deki karşılığı.
//  Geometri, tasarımın svg/logo-cone-amber.svg dosyasından birebir alınmıştır
//  (referans viewBox 200×265). Splash ve profil gibi büyük gösterim yerlerinde
//  kullanılır.
//

import SwiftUI

struct DonerConeLogo: View {
    /// Tek renk siluet için verilir. `nil` ise tam renkli çizilir.
    var tint: Color?
    /// Üstteki buhar dalgalarını çiz.
    var showSteam: Bool
    /// Tam renkli modda kontur rengi (dark mode'da kırık beyaz verilebilir).
    var outline: Color

    init(tint: Color? = nil, showSteam: Bool = true, outline: Color = AppTheme.ink) {
        self.tint = tint
        self.showSteam = showSteam
        self.outline = outline
    }

    // Kimlik renkleri
    private static let amber = AppTheme.amber
    private static let cream = AppTheme.cream
    private static let green = Color(red: 0.18, green: 0.62, blue: 0.36) // #2E9E5B
    private static let red = Color(red: 0.85, green: 0.25, blue: 0.18)   // #D8402F

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 200, size.height / 265)
            context.translateBy(
                x: (size.width - 200 * scale) / 2,
                y: (size.height - 265 * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)

            if let tint {
                drawSilhouette(in: &context, color: tint)
            } else {
                drawFullColor(in: &context)
            }
        }
    }

    // MARK: - Silüet

    private func drawSilhouette(in context: inout GraphicsContext, color: Color) {
        if showSteam {
            context.stroke(steamPath(), with: .color(color), style: roundStroke(9))
        }
        context.fill(coneBodyPath(), with: .color(color))
        context.fill(fillingTopPath(), with: .color(color))
    }

    // MARK: - Tam renkli logo

    private func drawFullColor(in context: inout GraphicsContext) {
        if showSteam {
            context.stroke(steamPath(), with: .color(outline), style: roundStroke(9))
        }

        context.fill(coneBodyPath(), with: .color(Self.amber))
        context.stroke(coneBodyPath(), with: .color(outline), style: roundStroke(9))

        context.stroke(coneCreasePath(), with: .color(outline), style: roundStroke(7))

        context.fill(fillingTopPath(), with: .color(Self.amber))
        context.stroke(fillingTopPath(), with: .color(outline), style: roundStroke(9))

        context.fill(rimPath(), with: .color(Self.cream))

        context.stroke(spiralPath(), with: .color(outline), style: roundStroke(7))

        drawVeggie(&context, path: veggie1Path(), fill: Self.green)
        drawVeggie(&context, path: veggie2Path(), fill: Self.green)
        drawVeggie(&context, path: veggie3Path(), fill: Self.red)
    }

    private func drawVeggie(_ context: inout GraphicsContext, path: Path, fill: Color) {
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(outline), style: roundStroke(5))
    }

    private func roundStroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    // MARK: - Yollar (referans koordinatlar; koni grubu y+50 kaydırılmıştır)

    private func steamPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 76, y: 80))
        p.addQuadCurve(to: CGPoint(x: 76, y: 54), control: CGPoint(x: 67, y: 67))
        p.addQuadCurve(to: CGPoint(x: 76, y: 28), control: CGPoint(x: 85, y: 41))

        p.move(to: CGPoint(x: 100, y: 74))
        p.addQuadCurve(to: CGPoint(x: 100, y: 46), control: CGPoint(x: 91, y: 60))
        p.addQuadCurve(to: CGPoint(x: 100, y: 18), control: CGPoint(x: 109, y: 32))

        p.move(to: CGPoint(x: 124, y: 80))
        p.addQuadCurve(to: CGPoint(x: 124, y: 54), control: CGPoint(x: 133, y: 67))
        p.addQuadCurve(to: CGPoint(x: 124, y: 28), control: CGPoint(x: 115, y: 41))
        return p
    }

    private func coneBodyPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 140))
        p.addLine(to: CGPoint(x: 62, y: 240))
        p.addQuadCurve(to: CGPoint(x: 138, y: 240), control: CGPoint(x: 100, y: 250))
        p.addLine(to: CGPoint(x: 150, y: 140))
        p.closeSubpath()
        return p
    }

    private func coneCreasePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 100, y: 152))
        p.addLine(to: CGPoint(x: 130, y: 236))
        return p
    }

    private func fillingTopPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 140))
        p.addQuadCurve(to: CGPoint(x: 80, y: 118), control: CGPoint(x: 56, y: 112))
        p.addQuadCurve(to: CGPoint(x: 100, y: 110), control: CGPoint(x: 90, y: 100))
        p.addQuadCurve(to: CGPoint(x: 120, y: 118), control: CGPoint(x: 110, y: 100))
        p.addQuadCurve(to: CGPoint(x: 150, y: 140), control: CGPoint(x: 144, y: 112))
        p.closeSubpath()
        return p
    }

    private func rimPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 58, y: 134))
        p.addQuadCurve(to: CGPoint(x: 142, y: 134), control: CGPoint(x: 100, y: 122))
        p.addLine(to: CGPoint(x: 142, y: 140))
        p.addQuadCurve(to: CGPoint(x: 58, y: 140), control: CGPoint(x: 100, y: 130))
        p.closeSubpath()
        return p
    }

    private func spiralPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 100, y: 138))
        p.addQuadCurve(to: CGPoint(x: 117, y: 123), control: CGPoint(x: 116, y: 137))
        p.addQuadCurve(to: CGPoint(x: 100, y: 107), control: CGPoint(x: 116, y: 108))
        p.addQuadCurve(to: CGPoint(x: 79, y: 129), control: CGPoint(x: 80, y: 108))
        return p
    }

    private func veggie1Path() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 66, y: 122))
        p.addLine(to: CGPoint(x: 75, y: 108))
        p.addLine(to: CGPoint(x: 82, y: 121))
        p.closeSubpath()
        return p
    }

    private func veggie2Path() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 128, y: 118))
        p.addLine(to: CGPoint(x: 139, y: 107))
        p.addLine(to: CGPoint(x: 142, y: 122))
        p.closeSubpath()
        return p
    }

    private func veggie3Path() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 118, y: 112))
        p.addLine(to: CGPoint(x: 128, y: 100))
        p.addLine(to: CGPoint(x: 131, y: 114))
        p.closeSubpath()
        return p
    }
}

#Preview {
    DonerConeLogo()
        .frame(width: 140, height: 185)
        .padding()
        .background(AppTheme.cream)
}
