import SwiftUI

struct StatusRingView: View {
    let isActive: Bool
    let subtitle: String

    @State private var rotationAngle: Double = 0
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.cardLine, lineWidth: 12)

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    AngularGradient(
                        colors: ringColors,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(rotationAngle))
                .shadow(color: isActive ? AppTheme.accent.opacity(0.45) : .clear, radius: 10)

            VStack(spacing: 8) {
                Image(systemName: isActive ? "shield.lefthalf.filled" : "shield")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(isActive ? AppTheme.accentLight : AppTheme.secondaryText)
                    .shadow(color: isActive ? AppTheme.accentLight.opacity(0.5) : .clear, radius: 8)
                Text(isActive ? "Kalkan Aktif" : "Bağlantı Kapalı")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? AppTheme.primaryText : AppTheme.secondaryText)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
        .frame(width: 216, height: 216)
        .scaleEffect(isPulsing && isActive ? 1.035 : 1.0)
        .onAppear {
            updateAnimations()
        }
        .onChange(of: isActive) { _ in
            updateAnimations()
        }
    }

    private var ringColors: [Color] {
        if isActive {
            return [AppTheme.accent, AppTheme.tealLight, AppTheme.accent.opacity(0.15)]
        }
        return [AppTheme.secondaryText.opacity(0.35), AppTheme.secondaryText.opacity(0.35)]
    }

    private func updateAnimations() {
        rotationAngle = 0
        isPulsing = false
        guard isActive else { return }
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

struct SpeedChartView: View {
    let downloadSeries: [Double]
    let uploadSeries: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                legend(color: AppTheme.accentLight, label: "İndirme")
                legend(color: AppTheme.teal, label: "Yükleme")
                Spacer()
                Text("Canlı Ağ Trafiği")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }

            Canvas { context, size in
                drawGrid(context: context, size: size)
                drawSeries(
                    context: context,
                    size: size,
                    series: uploadSeries,
                    lineColor: AppTheme.teal
                )
                drawSeries(
                    context: context,
                    size: size,
                    series: downloadSeries,
                    lineColor: AppTheme.accentLight
                )
            }
            .frame(height: 168)
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        var grid = Path()
        for index in 0...4 {
            let y = size.height * CGFloat(index) / 4
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(AppTheme.cardLine.opacity(0.5)), lineWidth: 1)
    }

    private func drawSeries(
        context: GraphicsContext,
        size: CGSize,
        series: [Double],
        lineColor: Color
    ) {
        guard series.count > 1 else { return }
        let maxValue = max(series.max() ?? 1, 1)
        let stepX = size.width / CGFloat(series.count - 1)

        var points: [CGPoint] = []
        for (index, value) in series.enumerated() {
            let x = CGFloat(index) * stepX
            let y = size.height - CGFloat(value / maxValue) * size.height * 0.92
            points.append(CGPoint(x: x, y: y))
        }

        var line = Path()
        line.addLines(points)
        context.stroke(line, with: .color(lineColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        var area = line
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        context.fill(
            area,
            with: .linearGradient(
                Gradient(colors: [lineColor.opacity(0.28), lineColor.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }
}
