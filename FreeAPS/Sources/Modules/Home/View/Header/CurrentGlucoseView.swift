import SwiftUI

struct CurrentGlucoseView: View {
    @Binding var recentGlucose: BloodGlucose?
    @Binding var timerDate: Date
    @Binding var delta: Int?
    @Binding var units: GlucoseUnits
    @Binding var alarm: GlucoseAlarm?
    @Binding var lowGlucose: Decimal
    @Binding var highGlucose: Decimal

    @State private var rotationDegrees: Double = 0.0
    @State private var angularGradient = AngularGradient(colors: [
    ], center: .center, startAngle: .degrees(270), endAngle: .degrees(-90))

    @Environment(\.colorScheme) var colorScheme

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
        }
        formatter.roundingMode = .halfUp
        return formatter
    }

    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "  +"
        formatter.negativePrefix = "  -"
        return formatter
    }

    private var timaAgoFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.negativePrefix = ""
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        let triangleColor = Color(red: 0.18, green: 0.35, blue: 0.58)

        let angularGradient = AngularGradient(
            gradient: Gradient(colors: [
                //      Color.blueComplicationBackground,
                Color.blue,
                Color.blue,
                //       Color.blueComplicationBackground,
                Color.blue,
                Color.blue
                //      Color.blueComplicationBackground
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )

        ZStack {
            // Nutze den Gradient anstelle der Farbe
            TrendShape(gradient: angularGradient, color: triangleColor)
                .rotationEffect(.degrees(rotationDegrees))

            VStack(alignment: .center) {
                HStack {
                    Text(
                        (recentGlucose?.glucose ?? 100) == 400 ? "HIGH" : recentGlucose?.glucose
                            .map {
                                glucoseFormatter
                                    .string(from: Double(units == .mmolL ? $0.asMmolL : Decimal($0)) as NSNumber)!
                            } ?? "--"
                    )
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(alarm == nil ? colourGlucoseText : .loopYellow)
                }
                HStack {
                    let minutesAgo = -1 * (recentGlucose?.dateString.timeIntervalSinceNow ?? 0) / 60
                    let text = timaAgoFormatter.string(for: Double(minutesAgo)) ?? ""
                    Text(
                        minutesAgo <= 1 ? "< 1 " + NSLocalizedString("min", comment: "Short form for minutes") : (
                            text + " " +
                                NSLocalizedString("min", comment: "Short form for minutes") + " "
                        )
                    )
                    .font(.caption2)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.white)

                    Text(
                        delta
                            .map {
                                deltaFormatter.string(from: Double(units == .mmolL ? $0.asMmolL : Decimal($0)) as NSNumber)!
                            } ?? "--"
                    )
                    .font(.caption2)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.white)
                }
                .frame(alignment: .top)
            }
        }
        .onChange(of: recentGlucose?.direction) { newDirection in
            withAnimation {
                switch newDirection {
                case .doubleUp,
                     .singleUp,
                     .tripleUp:
                    rotationDegrees = -90

                case .fortyFiveUp:
                    rotationDegrees = -45

                case .flat:
                    rotationDegrees = 0

                case .fortyFiveDown:
                    rotationDegrees = 45

                case .doubleDown,
                     .singleDown,
                     .tripleDown:
                    rotationDegrees = 90

                case .none,
                     .notComputable,
                     .rateOutOfRange:
                    rotationDegrees = 0

                @unknown default:
                    rotationDegrees = 0
                }
            }
        }
    }

    var colourGlucoseText: Color {
        let whichGlucose = recentGlucose?.glucose ?? 0
        let defaultColor: Color = colorScheme == .dark ? .white : .white

        guard lowGlucose < highGlucose else { return .primary }

        switch whichGlucose {
        case 0 ..< Int(lowGlucose):
            return .loopYellow
        case Int(lowGlucose) ..< Int(highGlucose):
            return defaultColor
        case Int(highGlucose)...:
            return .loopYellow
        default:
            return defaultColor
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 15))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.midY + 13))

        path.closeSubpath()

        return path
    }
}

struct TrendShape: View {
    @Environment(\.colorScheme) var colorScheme

    let gradient: AngularGradient
    let color: Color

    var body: some View {
        HStack(alignment: .center) {
            ZStack {
                Group {
                    CircleShape(gradient: gradient)
                    TriangleShape(color: color)
                }.shadow(color: Color.black.opacity(colorScheme == .dark ? 0.75 : 0.33), radius: colorScheme == .dark ? 5 : 3)
                CircleShape(gradient: gradient)
            }
        }
    }
}

/* struct CircleShape: View {
     @Environment(\.colorScheme) var colorScheme

     let gradient: AngularGradient

     var body: some View {
         Circle()
             .fill(Color.clear.opacity(0.1))
             .frame(width: 130, height: 130)
         Circle()
             .stroke(gradient, lineWidth: 6)
             .background(Circle().fill(Color("Chart")))
             .frame(width: 130, height: 130)
     }
 } */
struct CircleShape: View {
    @Environment(\.colorScheme) var colorScheme

    let gradient: AngularGradient

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.darkGray, Color.darkGray, Color.darkGray]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 130, height: 130)
                .opacity(0.2)

            Circle()
                .stroke(gradient, lineWidth: 6)
                .background(Circle().fill(Color("Chart")))
                .frame(width: 130, height: 130)
        }
    }
}

struct TriangleShape: View {
    let color: Color

    var body: some View {
        Triangle()
            .fill(color)
            .frame(width: 35, height: 35)
            .rotationEffect(.degrees(90))
            .offset(x: 85)
    }
}
