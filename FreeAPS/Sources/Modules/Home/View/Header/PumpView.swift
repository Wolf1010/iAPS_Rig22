import SwiftUI

struct PumpView: View {
    @Binding var reservoir: Decimal?
    @Binding var battery: Battery?
    @Binding var name: String
    @Binding var expiresAtDate: Date?
    @Binding var timerDate: Date
    @Binding var timeZone: TimeZone?

    @State var state: Home.StateModel

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
        formatter.multiplier = 1 // Multiplikator auf 1, um den Prozentsatz korrekt darzustellen
        return formatter
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        return dateFormatter
    }

    struct PieSegment: View {
        var fillFraction: CGFloat
        var color: Color
        var backgroundColor: Color
        var displayText: String?
        var symbol: String? // SF Symbol als String
        var customImage: Image? // Custom Image als Image
        var symbolSize: CGFloat = 26

        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    // Hintergrundkreis
                    Circle()
                        .fill(backgroundColor)
                        .opacity(0.3)
                        .frame(width: 50, height: 50)

                    // Gefüllter Pie-Slice
                    PieSliceView(
                        startAngle: .degrees(-90.0),
                        endAngle: .degrees(-90.0 + Double(360.0 * fillFraction))
                    )
                    .fill(color)
                    .animation(.easeInOut, value: fillFraction)
                    .opacity(0.6)

                    // Symbol im Pie-Segment: Entweder SF-Symbol oder benutzerdefiniertes Bild
                    if let symbol = symbol {
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .foregroundColor(.white)
                            .opacity(1.0)
                    } else if let customImage = customImage {
                        customImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .opacity(1.0)
                    }
                }
                .frame(width: 50, height: 50)
                .offset(y: 3)

                if let displayText = displayText {
                    Text(displayText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .offset(y: 0)
                }
            }
            .frame(width: 50)
        }
    }

    struct PieSliceView: Shape {
        var startAngle: Angle
        var endAngle: Angle

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

    var body: some View {
        HStack(spacing: 8) {
            let maxValue: Decimal = state.pumpName.contains("Omni") ? Decimal(200) : Decimal(300)

            // Reservoir-Anzeige
            if let reservoir = reservoir {
                let fraction = CGFloat(truncating: (reservoir / maxValue) as NSNumber)
                let fill = max(min(fraction, 1.0), 0.0)
                let reservoirSymbol = "fuelpump"

                PieSegment(
                    fillFraction: fill,
                    color: reservoirColor,
                    backgroundColor: .gray,
                    displayText: reservoir == Decimal(0xDEAD_BEEF) ? "50+" :
                        "\(reservoirFormatter.string(from: reservoir as NSNumber) ?? "")U",
                    symbol: reservoirSymbol, // SF Symbol für das Reservoir
                    symbolSize: 26
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
            if let battery = battery, !state.pumpName.contains("Omni") {
                let batteryFraction = CGFloat(battery.percent ?? 0) / 100.0
                let batteryFill = max(min(batteryFraction, 1.0), 0.0)
                let batteryText = "\(Int(batteryFraction * 100))%"
                let batterySymbol = "macpro.gen2"

                PieSegment(
                    fillFraction: batteryFill,
                    color: batteryColor,
                    backgroundColor: .gray,
                    displayText: batteryText,
                    symbol: batterySymbol, // SF Symbol für Batterie
                    symbolSize: 26
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            } /* else if state.pumpName.contains("Omni") {
                 // Pod Reservoir Anzeige mit benutzerdefiniertem Bild
                 PieSegment(
                     fillFraction: 1.0,
                     color: batteryColor,
                     backgroundColor: .gray,
                     displayText: "Pod",
                     symbol: nil, // Kein SF Symbol
                     customImage: Image("pod_reservoir"), // Benutzerdefiniertes Bild
                     symbolSize: 26
                 )
                 .padding(.trailing, 8)
                 .layoutPriority(1)
             } */

            // Pod-Lebensdauer
            if let date = expiresAtDate {
                let remainingTimeMinutes = date.timeIntervalSince(timerDate) / 1.minutes.timeInterval
                let remainingTimeHours = date.timeIntervalSince(timerDate) / 1.hours.timeInterval
                let remainingTimePercent = Float(remainingTimeHours * 100 / 72)

                let hours = Int(remainingTimeHours.rounded())
                let minutes = Int(remainingTimeMinutes)

                let batteryFraction = CGFloat(remainingTimePercent) / 100.0
                let batteryFill = max(min(batteryFraction, 1.0), 0.0)
                // let batterySymbol = "macpro.gen2" // brauchen wir nicht

                PieSegment(
                    fillFraction: batteryFill,
                    color: PodColor(percent: remainingTimePercent),
                    backgroundColor: (hours < 2 && minutes < 0) ? .red : .gray, // .gray,
                    displayText: hours > 2 ? "\(hours)h" : "\(minutes)m",
                    symbol: nil, // Kein SF Symbol
                    customImage: Image("pod_reservoir"), // Benutzerdefiniertes Bild
                    symbolSize: 26
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            } else if state.pumpName.contains("Omni") {
                Text("No Pod").font(.statusFont).foregroundStyle(Color.white)
                    .offset(x: 0, y: -4)
            }
        }
        .offset(x: 0, y: 5)
    }

    private func remainingTime(time: TimeInterval) -> some View {
        HStack {
            if time > 0 {
                let days = Int(time / 1.days.timeInterval)
                let hours = Int(time / 1.hours.timeInterval)
                let minutes = Int(time / 1.minutes.timeInterval)
                if days >= 1 {
                    Text(" \(days)" + NSLocalizedString("d", comment: "abbreviation for days" + "+"))
                } else if hours >= 1 {
                    Text(" \(hours)" + NSLocalizedString("h", comment: "abbreviation for hours"))
                        .foregroundStyle(time < 4 * 60 * 60 ? .red : .primary)
                } else {
                    Text(" \(minutes)" + NSLocalizedString("m", comment: "abbreviation for minutes"))
                        .foregroundStyle(time < 4 * 60 * 60 ? .red : .primary)
                }
            } else {
                Text(NSLocalizedString("Replace", comment: "View/Header when pod expired")).foregroundStyle(.red)
            }
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

    private func PodColor(percent: Float) -> Color {
        switch percent {
        case ...0:
            return .gray
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
