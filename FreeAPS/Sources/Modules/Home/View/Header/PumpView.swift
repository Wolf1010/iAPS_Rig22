import SwiftUI

struct PumpView: View {
    @Binding var reservoir: Decimal?
    @Binding var battery: Battery?
    @Binding var name: String
    @Binding var expiresAtDate: Date?
    @Binding var timerDate: Date
    @Binding var timeZone: TimeZone?

    @State var state: Home.StateModel

    @StateObject private var reservoirPieSegmentViewModel = PieSegmentViewModel()
    @StateObject private var batteryPieSegmentViewModel = PieSegmentViewModel()
    @StateObject private var podLifePieSegmentViewModel = PieSegmentViewModel()

    @Environment(\.colorScheme) var colorScheme

    private var reservoirFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private var batteryFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.multiplier = 1
        return formatter
    }

    struct PieSliceView: Shape {
        var startAngle: Angle
        var endAngle: Angle
        var animatableData: AnimatablePair<Double, Double> {
            get {
                AnimatablePair(startAngle.degrees, endAngle.degrees)
            }
            set {
                startAngle = Angle(degrees: newValue.first)
                endAngle = Angle(degrees: newValue.second)
            }
        }

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            path.move(to: center)
            path.addArc(
                center: center,
                radius: rect.width / 2,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            path.closeSubpath()
            return path
        }
    }

    class PieSegmentViewModel: ObservableObject {
        @Published var progress: Double = 0.0

        func updateProgress(to newValue: CGFloat, animate: Bool) {
            if animate {
                withAnimation(.easeInOut(duration: 2.5)) {
                    self.progress = Double(newValue)
                }
            } else {
                progress = Double(newValue)
            }
        }
    }

    struct FillablePieSegment: View {
        @ObservedObject var pieSegmentViewModel: PieSegmentViewModel

        var fillFraction: CGFloat
        var color: Color
        var backgroundColor: Color
        var displayText: String
        var symbolSize: CGFloat
        var symbol: String
        var animateProgress: Bool

        var body: some View {
            VStack {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .opacity(0.3)
                        .frame(width: 50, height: 50)

                    PieSliceView(
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + Double(pieSegmentViewModel.progress * 360))
                    )
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .opacity(0.6)

                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: symbolSize, height: symbolSize)
                        .foregroundColor(.white)
                }

                Text(displayText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.top, 0)
            }
            .offset(y: 10)
            .onAppear {
                pieSegmentViewModel.updateProgress(to: fillFraction, animate: animateProgress)
            }
            .onChange(of: fillFraction) { newValue in
                pieSegmentViewModel.updateProgress(to: newValue, animate: true)
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Berechnung von maxValue basierend auf dem Pumpen-Namen
            let maxValue: Decimal = name.contains("Omni") ? Decimal(200) : Decimal(300)

            // Reservoir-Anzeige
            if let reservoir = reservoir {
                let fraction = CGFloat(truncating: (reservoir / maxValue) as NSNumber)
                let fill = max(min(fraction, 1.0), 0.0)
                let reservoirSymbol = "fuelpump"

                FillablePieSegment(
                    pieSegmentViewModel: reservoirPieSegmentViewModel,
                    fillFraction: fill,
                    color: reservoirColor,
                    backgroundColor: .gray,
                    displayText: reservoir == Decimal(0xDEAD_BEEF) ? "50+" :
                        "\(reservoirFormatter.string(from: reservoir as NSNumber) ?? "")U",
                    symbolSize: 26,
                    symbol: reservoirSymbol,
                    animateProgress: true
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            } else {
                Text("No Pump")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .offset(x: -22, y: 0)
            }

            // Batterieanzeige
            if let battery = battery, !name.contains("Omni") {
                let batteryFraction = CGFloat(battery.percent ?? 0) / 100.0
                let batteryFill = max(min(batteryFraction, 1.0), 0.0)
                let batteryText = "\(Int(batteryFraction * 100))%"
                let batterySymbol = "macpro.gen2"

                FillablePieSegment(
                    pieSegmentViewModel: batteryPieSegmentViewModel,
                    fillFraction: batteryFill,
                    color: batteryColor,
                    backgroundColor: .gray,
                    displayText: batteryText,
                    symbolSize: 26,
                    symbol: batterySymbol,
                    animateProgress: true
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            }

            // Pod-Lebensdauer-Anzeige
            if let expiresAt = expiresAtDate {
                let remainingTime = expiresAt.timeIntervalSince(timerDate)
                let remainingTimeHours = remainingTime / 3600
                let podLifeFraction = CGFloat(remainingTimeHours / 72) // 72 Stunden für einen Pod
                let podLifeFill = max(min(podLifeFraction, 1.0), 0.0)

                let hours = Int(remainingTimeHours)
                let minutes = Int(remainingTime.truncatingRemainder(dividingBy: 3600) / 60)

                let podLifeText = hours > 2 ? "\(hours)h" : "\(minutes)m"
                let podSymbol = "drop.fill"

                FillablePieSegment(
                    pieSegmentViewModel: podLifePieSegmentViewModel,
                    fillFraction: podLifeFill,
                    color: podLifeColor(remainingTimeHours),
                    backgroundColor: .gray,
                    displayText: podLifeText,
                    symbolSize: 26,
                    symbol: podSymbol,
                    animateProgress: true
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            } else if name.contains("Omni") {
                Text("No Pod")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
        }
        .offset(x: 0, y: 5)
        .onAppear {
            let maxValueOnAppear: Decimal = name.contains("Omni") ? Decimal(200) : Decimal(300)
            let reservoirFillFraction = CGFloat(truncating: (reservoir ?? 0) as NSNumber) /
                CGFloat(truncating: maxValueOnAppear as NSNumber)
            reservoirPieSegmentViewModel.updateProgress(to: reservoirFillFraction, animate: true)
            batteryPieSegmentViewModel.updateProgress(to: CGFloat(battery?.percent ?? 0) / 100, animate: true)

            if let expiresAt = expiresAtDate {
                let remainingTime = expiresAt.timeIntervalSince(timerDate)
                let remainingTimeHours = remainingTime / 3600
                let podLifeFraction = CGFloat(remainingTimeHours / 72)
                podLifePieSegmentViewModel.updateProgress(to: podLifeFraction, animate: true)
            }
        }
    }

    // Pod-Lebensdauer-Farbe
    private func podLifeColor(_ remainingHours: Double) -> Color {
        switch remainingHours {
        case ...0:
            return .red
        case ...12:
            return .yellow
        default:
            return .green
        }
    }

    private var batteryColor: Color {
        guard let battery = battery, let percent = battery.percent else {
            return .gray
        }
        switch percent {
        case ...25:
            return .red
        case ...50:
            return .yellow
        default:
            return .green
        }
    }

    private var reservoirColor: Color {
        guard let reservoir = reservoir else {
            return .gray
        }

        switch reservoir {
        case ...10:
            return .red
        case ...30:
            return .yellow
        default:
            return .green
        }
    }
}
