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

    struct FillableCircle: View {
        var fillFraction: CGFloat // Wert zwischen 0 und 1 für die Füllmenge
        var color: Color // Farbe der Füllung
        var opacity: CGFloat // Transparenz des Hintergrundkreises
        var displayText: String? // Text, der im Kreis angezeigt wird
        var symbol: String? // Symbol, das im Kreis angezeigt wird
        var symbolSize: CGFloat = 20 // Symbolgröße, Standardgröße ist 20

        var body: some View {
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .opacity(Double(opacity))
                    .foregroundColor(color.opacity(0.4)) // Hintergrund des Kreises

                Circle()
                    .trim(from: 0.0, to: fillFraction) // Teil des Kreises, der gefüllt wird
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)) // Start bei 12 Uhr
                    .animation(.easeInOut, value: fillFraction) // Animation der Füllung

                if let symbol = symbol {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: symbolSize, height: symbolSize)
                        .foregroundColor(color) // Symbolfarbe
                }

                if let displayText = displayText {
                    let numberText = displayText.replacingOccurrences(of: "U", with: "") // Entferne das "U"

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(numberText)
                            .font(.system(size: 16)) // Originalgröße für die Zahl
                            .bold()
                            .foregroundColor(.white)

                        Text("U")
                            .font(.system(size: 14)) // Kleinere Größe für das "U"
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 54, height: 54)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if let reservoir = reservoir {
                let maxValue = Decimal(300) // Maximalwert als Decimal
                let fraction = CGFloat(truncating: (reservoir / maxValue) as NSNumber)
                let fill = max(min(fraction, 1.0), 0.0)

                FillableCircle(
                    fillFraction: fill,
                    color: reservoirColor, // Farbe des Rings
                    opacity: 1.0,
                    displayText: reservoir == Decimal(0xDEAD_BEEF) ? "50+" :
                        "\(reservoirFormatter.string(from: reservoir as NSNumber) ?? "")U",
                    symbol: nil // Kein Symbol für die Reservoir-Anzeige
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
                let percent = (battery.percent ?? 100) > 80 ? 100 : (battery.percent ?? 100) < 81 &&
                    (battery.percent ?? 100) >
                    60 ? 75 : (battery.percent ?? 100) < 61 && (battery.percent ?? 100) > 40 ? 50 : 25
                let batterySymbol = "battery.\(percent)" // Symbol basierend auf Batterieprozentsatz

                FillableCircle(
                    fillFraction: batteryFill,
                    color: batteryColor,
                    opacity: 1.0,
                    displayText: nil, // Kein Text für die Batterieanzeige
                    symbol: batterySymbol,
                    symbolSize: 26
                )
                .padding(.trailing, 8)
                .layoutPriority(1)
            }

            // Anzeige des Ablaufdatums
            if let date = expiresAtDate {
                Image("pod_reservoir")
                    .resizable(resizingMode: .stretch)
                    .frame(width: IAPSconfig.iconSize * 1.15, height: IAPSconfig.iconSize * 1.6)
                    .foregroundColor(colorScheme == .dark ? .secondary : .white)
                    .offset(x: 0, y: -5)
                    .overlay {
                        if let timeZone = timeZone, timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT() {
                            ClockOffset(mdtPump: false)
                        }
                    }
                remainingTime(time: date.timeIntervalSince(timerDate))
                    .font(.pumpFont)
                    .offset(x: -7, y: 0)
            } else if state.pumpName.contains("Omni") {
                Text("No Pod").font(.subheadline).foregroundStyle(.secondary)
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
        case ...49:
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
