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
        var symbol: String?
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

                    // Symbol im Pie-Segment
                    if let symbol = symbol {
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: symbolSize, height: symbolSize)
                            .foregroundColor(.white)
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
            if let reservoir = reservoir {
                let maxValue = Decimal(300) // Maximalwert als Decimal
                let fraction = CGFloat(truncating: (reservoir / maxValue) as NSNumber)
                let fill = max(min(fraction, 1.0), 0.0)
                let reservoirSymbol = "fuelpump"

                PieSegment(
                    fillFraction: fill,
                    color: reservoirColor, backgroundColor: .gray,
                    displayText: reservoir == Decimal(0xDEAD_BEEF) ? "50+" :
                        "\(reservoirFormatter.string(from: reservoir as NSNumber) ?? "")U",
                    symbol: reservoirSymbol,
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
                // Der Prozentsatz direkt hier als Text
                let batteryText = "\(Int(batteryFraction * 100))%"
                let batterySymbol = "macpro.gen2"

                PieSegment(
                    fillFraction: batteryFill,
                    color: batteryColor,
                    backgroundColor: .gray,
                    displayText: batteryText,
                    symbol: batterySymbol,
                    symbolSize: 26
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            }

            if let date = expiresAtDate {
                Image("pod_reservoir")
                    .resizable(resizingMode: .stretch)
                    .frame(width: IAPSconfig.iconSize * 1.15, height: IAPSconfig.iconSize * 1.6)
                    .foregroundStyle(Color.white)
                    .offset(x: 0, y: -5)
                    .overlay {
                        if let timeZone = timeZone, timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT() {
                            ClockOffset(mdtPump: false)
                        }
                    }
                remainingTime(time: date.timeIntervalSince(timerDate))
                    .font(.pumpFont)
                    .foregroundStyle(Color.white)
                    .offset(x: -7, y: 0)
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

    private var timerColor: Color {
        guard let expisesAt = expiresAtDate else {
            return .gray
        }

        let time = expisesAt.timeIntervalSince(timerDate)

        switch time {
        case ...8.hours.timeInterval:
            return .red
        case ...1.days.timeInterval:
            return .yellow
        default:
            return .green
        }
    }
}
