import Charts
import Combine
import CoreData
import DanaKit
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state = StateModel()
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false
        @State var showCancelTTAlert = false
        @State var triggerUpdate = false
        @State var scrollOffset = CGFloat.zero
        @State var display = false

        @Namespace var scrollSpace

        let scrollAmount: CGFloat = 290
        let buttonFont = Font.custom("TimeButtonFont", size: 14)

        @Environment(\.managedObjectContext) var moc
        //  @Environment(\.colorScheme) var colorScheme
        @Environment(\.sizeCategory) private var fontSize

        @FetchRequest(
            entity: Override.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedPercent: FetchedResults<Override>

        @FetchRequest(
            entity: OverridePresets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], predicate: NSPredicate(
                format: "name != %@", "" as String
            )
        ) var fetchedProfiles: FetchedResults<OverridePresets>

        @FetchRequest(
            entity: TempTargets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var sliderTTpresets: FetchedResults<TempTargets>

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var enactedSliderTT: FetchedResults<TempTargetsSlider>

        @State private var progress: Double = 0.0 // Fortschrittswert als State-Variable

        private var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var insulinnumberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0 // Keine unnötigen Nullen
            formatter.locale = Locale(identifier: "de_DE_POSIX") // Standard-Format ohne Leerzeichen
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
            return formatter
        }

        private var bolusProgressFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimum = 0
            formatter.maximumFractionDigits = state.settingsManager.preferences.bolusIncrement > 0.05 ? 1 : 2
            formatter.minimumFractionDigits = state.settingsManager.preferences.bolusIncrement > 0.05 ? 1 : 2
            formatter.allowsFloats = true
            formatter.roundingIncrement = Double(state.settingsManager.preferences.bolusIncrement) as NSNumber
            return formatter
        }

        private var fetchedTargetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            return formatter
        }

        private var targetFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var tirFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            return dateFormatter
        }

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        var glucoseView: some View {
            CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                timerDate: $state.timerDate,
                delta: $state.glucoseDelta,
                units: $state.units,
                alarm: $state.alarm,
                lowGlucose: $state.lowGlucose,
                highGlucose: $state.highGlucose
            )
            .onTapGesture {
                if state.alarm == nil {
                    state.openCGM()
                } else {
                    state.showModal(for: .snooze)
                }
            }
            .onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                if state.alarm == nil {
                    state.showModal(for: .snooze)
                } else {
                    state.openCGM()
                }
            }
        }

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.timerDate, timeZone: $state.timeZone,
                state: state
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
        }

        // Fortschrittsanzeige
        private func startProgress() {
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                withAnimation(Animation.linear(duration: 0.02)) {
                    progress += 0.01
                }
                if progress >= 1.0 {
                    timer.invalidate()
                }
            }
        }

        // Progressbar by Rig22
        public struct CircularProgressViewStyle: ProgressViewStyle {
            public func makeBody(configuration: Configuration) -> some View {
                let progress = CGFloat(configuration.fractionCompleted ?? 0)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.3)
                        .foregroundColor(Color.rig22Background)

                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.insulin, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: 270))
                        .animation(.linear(duration: 0.25), value: progress)
                }
                .frame(width: 120, height: 120)
            }
        }

        // Progressbar in rounded style
        func bolusProgressView(progress: Decimal, amount: Decimal) -> some View {
            ZStack {
                VStack(alignment: .leading, spacing: 5) {
                    let bolused = bolusProgressFormatter.string(from: (amount * progress) as NSNumber) ?? ""

                    Text(
                        bolused + " " + NSLocalizedString("of", comment: "") + " " + amount
                            .formatted(.number.precision(.fractionLength(2))) +
                            NSLocalizedString(" U", comment: " ")
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white)
                    .offset(x: -120, y: 50)
                    ProgressView(value: Double(truncating: progress as NSNumber))
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 15)
                }
            }
        }

        // headerView by Rig22
        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            addBackground()
                .frame(
                    maxHeight: fontSize < .extraExtraLarge ? 240 + geo.safeAreaInsets.top : 135 + geo.safeAreaInsets.top
                )
                .overlay {
                    VStack {
                        ZStack {
                            // Dynamisches Layout mit GeometryReader
                            GeometryReader { geometry in
                                VStack {
                                    // Linker Block
                                    HStack {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "chart.xyaxis.line")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 18, height: 18)
                                                    .foregroundColor(.white)

                                                if let tempBasalString = tempBasalString {
                                                    Text(tempBasalString)
                                                        .font(.system(size: 16))
                                                        .foregroundStyle(Color.white)
                                                }
                                            }
                                            .padding(.leading, 6)
                                        }

                                        Spacer()

                                        // GlucoseView bleibt zentriert
                                        glucoseView
                                            .frame(
                                                width: geometry.size
                                                    .width * 0.33
                                            ) // Breite für GlucoseView
                                            .overlay(
                                                ZStack {
                                                    if let progress = state.bolusProgress {
                                                        ProgressView(
                                                            value: Double(truncating: progress as NSNumber)
                                                        )
                                                        .progressViewStyle(CircularProgressViewStyle())
                                                        .frame(width: 120, height: 120)
                                                        .animation(.easeInOut, value: progress)

                                                        // Hintergrund Füllung für Glucose Ring
                                                        Circle()
                                                            .fill(Color.rig22BGGlucoseWheel.opacity(1.0))
                                                            .frame(width: 110, height: 110)

                                                        Text("\(Int(progress * 100))%")
                                                            .font(.system(size: 22))
                                                            .foregroundColor(.white)
                                                            .offset(x: 4)
                                                    }
                                                }
                                            )

                                        Spacer()

                                        // eventalBG und optionaler Pfeil
                                        if let eventualBG = state.eventualBG {
                                            HStack(spacing: 4) {
                                                Text("⇢")
                                                    .font(.statusFont)
                                                    .foregroundStyle(.white)
                                                let eventualBGValue = state.units == .mmolL ? eventualBG
                                                    .asMmolL : Decimal(eventualBG)
                                                if let formattedBG = fetchedTargetFormatter
                                                    .string(from: eventualBGValue as NSNumber)
                                                {
                                                    Text(formattedBG)
                                                        .font(.system(size: 16))
                                                        .foregroundColor(.white)
                                                }

                                                Text(state.units.rawValue)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.white)
                                                    .padding(.leading, -2)
                                            }
                                        }
                                    }

                                    .padding(.horizontal, 22) // Abstand rechter Rand

                                    .padding(.top, -20)
                                }
                                .offset(y: 90)

                                // Absolut positioniertes xmark-Icon und bolusing/bolusText oben rechts
                                if let progress = state.bolusProgress, let amount = state.bolusAmount {
                                    VStack(alignment: .trailing) {
                                        HStack {
                                            // Anzeigen des Bolusfortschritts
                                            let bolusedValue = amount * progress
                                            let bolused = bolusProgressFormatter.string(from: bolusedValue as NSNumber) ?? ""
                                            let formattedAmount = amount.formatted(.number.precision(.fractionLength(2)))

                                            let bolusText =
                                                "\(bolused) \(NSLocalizedString("/", comment: "")) \(formattedAmount) \(NSLocalizedString("U", comment: ""))"

                                            Text(bolusText)
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.white)
                                                .offset(y: 2)

                                            Circle()
                                                .fill(Color.red.opacity(1.0))
                                                .frame(width: 20, height: 20)
                                                .overlay(
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white)
                                                        .onTapGesture {
                                                            state.cancelBolus()
                                                        }
                                                )
                                                .padding(.leading, 4) // Abstand zwischen Text und xmark
                                        }
                                        .padding(.trailing, 7)
                                        .padding(.top, 75) // Position ein Stück oberhalb von eventualBG
                                        Spacer()
                                    }
                                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topTrailing)
                                }
                            }

                            // Unterer Bereich
                            VStack {
                                Spacer()

                                HStack {
                                    carbsAndInsulinView
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                        .padding(.bottom, 30)
                                    Spacer()
                                    loopView
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                        .padding(.bottom, 15)
                                    Spacer()
                                    pumpView
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                        .padding(.bottom, 30)
                                }
                                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                                .padding(.horizontal, 10)
                            }
                        }
                    }
                }
                .clipShape(Rectangle())
        }

        // Pie Animation by Rig22
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

        // Das ViewModel zur Steuerung der Animation und des Fortschritts
        class PieSegmentViewModel: ObservableObject {
            @Published var progress: Double = 0.0

            func updateProgress(to newValue: CGFloat, animate: Bool) {
                if animate {
                    withAnimation(.easeInOut(duration: 2.5)) { // Beispiel: Dauer der Animation anpassen
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

        // carbsAndInsuliView by Rig22
        @StateObject private var carbsPieSegmentViewModel = PieSegmentViewModel()
        @StateObject private var insulinPieSegmentViewModel = PieSegmentViewModel()

        var carbsAndInsulinView: some View {
            HStack {
                if let settings = state.settingsManager {
                    HStack(spacing: 18) {
                        VStack {
                            let substance = Double(state.suggestion?.cob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxCOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            let carbSymbol = "fork.knife"

                            FillablePieSegment(
                                pieSegmentViewModel: carbsPieSegmentViewModel,
                                fillFraction: fill,
                                color: .loopYellow,
                                backgroundColor: .gray,
                                displayText: "\(numberFormatter.string(from: (state.suggestion?.cob ?? 0) as NSNumber) ?? "0")g",
                                symbolSize: 26,
                                symbol: carbSymbol,
                                animateProgress: true
                            )
                        }

                        VStack {
                            let substance = Double(state.suggestion?.iob ?? 0)
                            let maxValue = max(Double(settings.preferences.maxIOB), 1)
                            let fraction = CGFloat(substance / maxValue)
                            let fill = max(min(fraction, 1.0), 0.0)
                            let insulinSymbol = "syringe"

                            FillablePieSegment(
                                pieSegmentViewModel: insulinPieSegmentViewModel,
                                fillFraction: fill,
                                color: substance < 0 ? .blue : .insulin,
                                backgroundColor: .gray,
                                displayText: "\(insulinnumberFormatter.string(from: (state.suggestion?.iob ?? 0) as NSNumber) ?? "0")U",
                                symbolSize: 26,
                                symbol: insulinSymbol,
                                animateProgress: true
                            )
                        }
                    }
                    .offset(x: 9)
                }
            }
        }

        func reservoirColor(for reservoirAge: String?) -> Color {
            if let reservoirAge = reservoirAge {
                // Entfernt das letzte Zeichen des Stringes (hier das "h")
                let cleanedReservoirAge = reservoirAge.trimmingCharacters(in: .letters)

                if let ageInHours = Int(cleanedReservoirAge) {
                    switch ageInHours {
                    case 240...:
                        return .red
                    case 192 ..< 239:
                        return .yellow
                    default:
                        return .white
                    }
                }
            }
            return .gray
        }

        func cannulaColor(for cannulaAge: String?) -> Color {
            if let cannulaAge = cannulaAge {
                // Entfernt das letzte Zeichen des Stringes (hier das "h")
                let cleanedCannulaAge = cannulaAge.trimmingCharacters(in: .letters)

                if let ageInHours = Int(cleanedCannulaAge) {
                    switch ageInHours {
                    case 72...:
                        return .red
                    case 48 ..< 72:
                        return .yellow
                    default:
                        return .white
                    }
                }
            }
            return .gray
        }

        var infoPanel: some View {
            ZStack {
                addBackground()
                info
            }
            .frame(maxWidth: .infinity, maxHeight: 50)
        }

        // Zweireihiger InfoPanel
        var info: some View {
            VStack(spacing: 10) {
                // Erste Reihe
                HStack(spacing: 10) {
                    // Linker Stack - state.isf
                    if let currentISF = state.isf {
                        HStack(spacing: 2) {
                            Text("ISF:")
                                .foregroundColor(.white)
                                .font(.system(size: 15))

                            if state.units == .mmolL {
                                Text(glucoseFormatter.string(from: currentISF as NSNumber) ?? " ")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 15))
                            } else {
                                Text(glucoseFormatter.string(from: currentISF as NSNumber) ?? " ")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 15))
                            }
                        }
                        .padding(.leading, 10)
                        .frame(maxWidth: 80, alignment: .leading) // Links ausgerichtet
                    }

                    // Mittlerer Stack mit GeometryReader für dynamische Verteilung
                    GeometryReader { geometry in
                        HStack(spacing: geometry.size.width * 0.05) { // Dynamischer Abstand basierend auf der Breite
                            if state.pumpSuspended {
                                Text("Pump suspended")
                                    .font(.extraSmall)
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }

                            if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                                Text(tempTargetString)
                                    .font(.buttonFont)
                                    .foregroundStyle(Color.white)
                            } else {
                                profileView
                            }

                            if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                                Text("Check Max IOB Setting")
                                    .font(.extraSmall)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(width: geometry.size.width, alignment: .center) // Zentriert im verfügbaren Platz
                    }
                    .frame(maxWidth: .infinity)

                    // Rechter Stack - TDD
                    HStack {
                        Text("TDD:" + (numberFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0"))
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.trailing, 5)
                    }
                    .frame(maxWidth: 80, alignment: .trailing) // Rechts ausgerichtet
                }
                // Zweite Reihe
                HStack(spacing: 10) {
                    // Connection Status
                    HStack(spacing: 6) {
                        Image(systemName: "personalhotspot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(state.isConnected ? .white : .gray)

                        if state.isConnected {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.leading, 10)
                    .onTapGesture {
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "fuelpump")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(reservoirColor(for: state.reservoirAge))

                        if let reservoirAge = state.reservoirAge {
                            Text("\(reservoirAge)")
                                // .foregroundColor(.white)
                                .foregroundStyle(reservoirColor(for: state.reservoirAge))
                                .font(.system(size: 15))
                        } else {
                            Text("--")
                                .foregroundStyle(reservoirColor(for: state.reservoirAge))
                                .font(.system(size: 15))
                        }
                    }
                    .onTapGesture {
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }

                    // Kanülenalter

                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.needle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(cannulaColor(for: state.cannulaAge))

                        if let cannulaAge = state.cannulaAge {
                            Text("\(cannulaAge)")
                                .foregroundStyle(cannulaColor(for: state.cannulaAge))
                                .font(.system(size: 15))
                        } else {
                            Text("--")
                                .foregroundColor(.gray)
                                .font(.system(size: 15))
                        }
                    }
                    .onTapGesture {
                        if state.pumpDisplayState != nil {
                            state.setupPump = true
                        }
                    }
                }
            }

            .onReceive(timer) { _ in
                state.specialDanaKitFunction()
            } // Ruft die Funktion periodisch auf
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        // Alles auf einer Linie
        /*        var info: some View {
             HStack(spacing: 10) {
                 // Linker Stack
                 if let currentISF = state.isf {
                     HStack(spacing: 2) {
                         Text("ISF:")
                             .foregroundColor(.white)
                             .font(.system(size: 16))
                             .foregroundStyle(Color.white)

                         if state.units == .mmolL {
                             Text(
                                 glucoseFormatter.string(from: currentISF as NSNumber) ?? " "
                             )
                             .font(.system(size: 16))
                         } else {
                             Text(
                                 glucoseFormatter.string(from: currentISF as NSNumber) ?? " "
                             )
                             .font(.system(size: 16))
                             .foregroundStyle(Color.white)

                             /*  if state.pumpSuspended {
                                  Text("Pump suspended")
                                      .font(.extraSmall)
                                      .bold()
                                      .foregroundStyle(Color.white)
                              }

                              if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                                  Text("Check Max IOB Setting")
                                      .font(.extraSmall)
                                      .foregroundColor(.orange)
                              }*/
                         }
                     }
                     .padding(.leading, 10)
                     .frame(maxWidth: .infinity, alignment: .leading) // Linker HStack links ausgerichtet
                 }
           /*      HStack(spacing: 6) {
                     Image("pumpe")
                         .resizable(resizingMode: .stretch)
                         .frame(width: IAPSconfig.iconSize * 1.0, height: IAPSconfig.iconSize * 1.6)
                         // .foregroundStyle(Color.white)
                         .foregroundColor(state.isConnected ? .white : .gray)
                 }*/

                 HStack(spacing: 6) {
                     Image(systemName: "personalhotspot")
                         .resizable()
                         .scaledToFit()
                         .frame(width: 20, height: 20)
                         .foregroundColor(state.isConnected ? .white : .gray)

                     if state.isConnected {
                         Circle()
                             .fill(Color.green)
                             .frame(width: 10, height: 10)
                     } else {
                         Circle()
                             .fill(Color.red)
                             .frame(width: 10, height: 10)
                     }
                 }
                 .padding(.leading, 10)
                 .onTapGesture {
                     if state.pumpDisplayState != nil {
                         state.setupPump = true
                     }
                 }

                 // Centered HStack
                 HStack(spacing: 0) {
                     //    HStack(alignment: .top) {
                     //       Spacer()
                     //  }
                     //  .padding(.bottom, 5)

                     if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                         Text(tempTargetString)
                             .font(.buttonFont)
                             .foregroundStyle(Color.white)
                     } else {
                         profileView
                     }
                 }
                 .frame(maxWidth: .none)

                 // Reservoiralter

                 HStack(spacing: 4) {
                     Image(systemName: "fuelpump")
                         .resizable()
                         .scaledToFit()
                         .frame(width: 16, height: 16)
                         .foregroundStyle(reservoirColor(for: state.reservoirAge))

                     if let reservoirAge = state.reservoirAge {
                         Text("\(reservoirAge)")
                             // .foregroundColor(.white)
                             .foregroundStyle(reservoirColor(for: state.reservoirAge))
                             .font(.system(size: 15))
                     } else {
                         Text("--")
                             .foregroundStyle(reservoirColor(for: state.reservoirAge))
                             .font(.system(size: 15))
                     }
                 }
                 .onTapGesture {
                     if state.pumpDisplayState != nil {
                         state.setupPump = true
                     }
                 }

                 // Kanülenalter

                 HStack(spacing: 4) {
                     Image(systemName: "gauge.with.needle")
                         .resizable()
                         .scaledToFit()
                         .frame(width: 16, height: 16)
                         .foregroundStyle(cannulaColor(for: state.cannulaAge))

                     if let cannulaAge = state.cannulaAge {
                         Text("\(cannulaAge)")
                             .foregroundStyle(cannulaColor(for: state.cannulaAge))
                             .font(.system(size: 15))
                     } else {
                         Text("--")
                             .foregroundColor(.gray)
                             .font(.system(size: 15))
                     }
                 }
                 .onTapGesture {
                     if state.pumpDisplayState != nil {
                         state.setupPump = true
                     }
                 }

                 Spacer() // Zentriere den mittleren HStack

                 // Rechter Stack
                 HStack {
                     Text(
                         "TDD:" + (numberFormatter.string(from: state.tddActualAverage as NSNumber) ?? "0")
                     )
                     .font(.system(size: 15))
                     .foregroundColor(.white)
                     .frame(alignment: .trailing) // rechts ausrichten
                     .padding(.trailing, 5) // optionaler Abstand vom Rand
                 }
                 .frame(maxWidth: .infinity, alignment: .trailing) // Rechter HStack rechts ausgerichtet

                 // TDD Unterschied zu gestern
                 /* Text(
                      //numberFormatter.string(from: state.tddChange as NSNumber) ?? "0"
                      // "ytd. " + (numberFormatter.string(from: state.tddYesterday as NSNumber) ?? "0")
                  )*/
                 .font(.system(size: 15))
                 .foregroundColor(.white)
                 .frame(alignment: .trailing) // rechts ausrichten
                 .padding(.trailing, 5) // optionaler Abstand vom Rand
             }
             .onReceive(timer) { _ in
                 state.specialDanaKitFunction() } // Ruft die Funktion periodisch auf
             .dynamicTypeSize(...DynamicTypeSize.xxLarge)
         }*/

        var timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect() // Aktualisiert alle 10 Sekunden

        var infoPanelbottom: some View {
            ZStack {
                addBackground()
                info2
            }
            .frame(maxWidth: .infinity, maxHeight: 25)
        }

        var info2: some View {
            HStack(spacing: 10) {
                if state.pumpSuspended {
                    Text("Pump suspended")
                        .font(.extraSmall)
                        .bold()
                        .foregroundStyle(Color.orange)
                }

                if state.closedLoop, state.settingsManager.preferences.maxIOB == 0 {
                    Text("Check Max IOB Setting")
                        .font(.extraSmall).foregroundColor(.orange)
                }

                if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                    Text(tempTargetString)
                } else {
                    profileView
                }
            }
        }

        var loopView: some View {
            LoopView(
                suggestion: $state.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.timerDate,
                isLooping: $state.isLooping,
                lastLoopDate: $state.lastLoopDate,
                manualTempBasal: $state.manualTempBasal
            )
            .onTapGesture {
                state.isStatusPopupPresented.toggle()
            }.onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                state.runLoop()
            }
        }

        var tempBasalString: String? {
            guard let tempRate = state.tempRate else {
                return nil
            }
            let rateString = numberFormatter.string(from: tempRate as NSNumber) ?? "0"
            var manualBasalString = ""

            if state.apsManager.isManualTempBasal {
                manualBasalString = NSLocalizedString(
                    " Manual",
                    comment: "Manual Temp basal"
                )
            }
            return rateString + " " + NSLocalizedString(" U/hr", comment: "Unit per hour with space") + manualBasalString
        }

        var tempTargetString: String? {
            guard let tempTarget = state.tempTarget else {
                return nil
            }
            return tempTarget.displayName
        }

        var mainChart: some View {
            ZStack {
                if state.animatedBackground {
                    SpriteView(scene: spriteScene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                MainChartView(
                    glucose: $state.glucose,
                    isManual: $state.isManual,
                    suggestion: $state.suggestion,
                    tempBasals: $state.tempBasals,
                    boluses: $state.boluses,
                    suspensions: $state.suspensions,
                    announcement: $state.announcement,
                    hours: .constant(state.filteredHours),
                    maxBasal: $state.maxBasal,
                    autotunedBasalProfile: $state.autotunedBasalProfile,
                    basalProfile: $state.basalProfile,
                    tempTargets: $state.tempTargets,
                    carbs: $state.carbs,
                    timerDate: $state.timerDate,
                    units: $state.units,
                    smooth: $state.smooth,
                    highGlucose: $state.highGlucose,
                    lowGlucose: $state.lowGlucose,
                    screenHours: $state.hours,
                    displayXgridLines: $state.displayXgridLines,
                    displayYgridLines: $state.displayYgridLines,
                    thresholdLines: $state.thresholdLines,
                    triggerUpdate: $triggerUpdate,
                    overrideHistory: $state.overrideHistory,
                    minimumSMB: $state.minimumSMB,
                    maxBolus: $state.maxBolus,
                    maxBolusValue: $state.maxBolusValue,
                    useInsulinBars: $state.useInsulinBars
                )
            }
            /* .background(
                 RoundedRectangle(cornerRadius: 10)
                     .fill(Color.rig22Background)
                     .shadow(color: Color.white.opacity(0.4), radius: 6, x: 0, y: 0)
             )*/
            .modal(for: .dataTable, from: self)
            .padding()
        }

        var chart: some View {
            // let ratio = state.timeSettings ? 1.61 : 1.44
            // let ratio2 = state.timeSettings ? 1.65 : 1.51
            // Leicht erhöhte Ratios für eine moderate Verkleinerung
            let ratio = state.timeSettings ? 1.91 : 1.71 // TimeSetting true
            let ratio2 = state.timeSettings ? 1.96 : 1.81 // Timesetting false

            return addBackground()
                .overlay {
                    VStack(spacing: 0) {
                        infoPanel
                        mainChart
                            //  info2
                            .frame(width: UIScreen.main.bounds.width * 0.99) // Breite der mainChart anpassen
                    }
                }
                .frame(minHeight: UIScreen.main.bounds.height / (fontSize < .extraExtraLarge ? ratio : ratio2))
        }

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            ZStack {
                addBackground()
                LinearGradient(
                    gradient: Gradient(colors: [.rig22bottomPanel, .rig22bottomPanel]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60 + geo.safeAreaInsets.bottom)
                let isOverride = fetchedPercent.first?.enabled ?? false
                let isTarget = (state.tempTarget != nil)
                HStack {
                    Button { state.showModal(for: .addCarbs(editMode: false, override: false)) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            // Hintergrundkreis
                            /* Circle()
                             .fill(.blue)
                             .opacity(0.3)
                             .frame(width: 50, height: 50)
                             .offset(x: 5)*/
                            Image(systemName: "fork.knife")
                                .renderingMode(.template)
                                .font(.custom("Buttons", size: 26))
                                // .foregroundColor(colorScheme == .dark ? .white : .white)
                                .foregroundColor(.white)
                                .padding(8)
                                .foregroundStyle(Color.white)
                            if let carbsReq = state.carbsRequired {
                                Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                    .font(.caption)
                                    .foregroundStyle(Color.white)
                                    .padding(4)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                    }.buttonStyle(.borderless)
                    Spacer()
                    Button {
                        state.showModal(for: .bolus(
                            waitForSuggestion: state.useCalc ? true : false,
                            fetch: false
                        ))
                    }
                    label: {
                        Image(systemName: "syringe")
                            .renderingMode(.template)
                            .font(.custom("Buttons", size: 26))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.white)
                    Spacer()
                    if state.allowManualTemp {
                        Button { state.showModal(for: .manualTempBasal) }
                        label: {
                            Image("bolus1")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: IAPSconfig.buttonSize, height: IAPSconfig.buttonSize, alignment: .bottom)
                        }
                        .foregroundStyle(Color.white)
                        Spacer()
                    }
                    ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom))
                        {
                            Image(systemName: isOverride ? "person.fill" : "person")
                                .symbolRenderingMode(.palette)
                                .font(.custom("Buttons", size: 26))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(isOverride ? .blue.opacity(0.5) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .onTapGesture {
                            if isOverride {
                                showCancelAlert.toggle()
                            } else {
                                state.showModal(for: .overrideProfilesConfig)
                            }
                        }
                        .onLongPressGesture {
                            state.showModal(for: .overrideProfilesConfig)
                        }
                    if state.useTargetButton {
                        Spacer()
                        Image(systemName: "scope")
                            .renderingMode(.template)
                            .font(.custom("Buttons", size: 26))
                            .padding(8)
                            .foregroundStyle(Color.white)
                            .background(isTarget ? .green.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                if isTarget {
                                    showCancelTTAlert.toggle()
                                } else {
                                    state.showModal(for: .addTempTarget)
                                }
                            }
                            .onLongPressGesture {
                                state.showModal(for: .addTempTarget)
                            }
                    }
                    Spacer()
                    Button { state.showModal(for: .settings) }
                    label: {
                        Image(systemName: "gear")
                            .renderingMode(.template)
                            .font(.custom("Buttons", size: 26))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.white)
                }
                .padding(.horizontal, state.allowManualTemp ? 5 : 24)
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .confirmationDialog("Cancel Profile Override", isPresented: $showCancelAlert) {
                Button("Cancel Profile Override", role: .destructive) {
                    state.cancelProfile()
                    triggerUpdate.toggle()
                }
            }
            .confirmationDialog("Cancel Temporary Target", isPresented: $showCancelTTAlert) {
                Button("Cancel Temporary Target", role: .destructive) {
                    state.cancelTempTarget()
                }
            }
        }

        var preview: some View {
            addBackground()
                .frame(minHeight: 200)
                .overlay {
                    PreviewChart(readings: $state.readings, lowLimit: $state.lowGlucose, highLimit: $state.highGlucose)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .foregroundStyle(Color.white)
                .onTapGesture {
                    state.showModal(for: .statistics)
                }
        }

        var activeIOBView: some View {
            addBackground()
                .frame(minHeight: 430)
                .overlay {
                    ActiveIOBView(
                        data: $state.iobData,
                        neg: $state.neg,
                        tddChange: $state.tddChange,
                        tddAverage: $state.tddAverage,
                        tddYesterday: $state.tddYesterday,
                        tdd2DaysAgo: $state.tdd2DaysAgo,
                        tdd3DaysAgo: $state.tdd3DaysAgo,
                        tddActualAverage: $state.tddActualAverage
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .foregroundStyle(Color.white)
        }

        var activeCOBView: some View {
            addBackground()
                .frame(minHeight: 230)
                .overlay {
                    ActiveCOBView(data: $state.iobData)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
        }

        var loopPreview: some View {
            addBackground()
                .frame(minHeight: 190)
                .overlay {
                    LoopsView(loopStatistics: $state.loopStatistics)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 10)
                .foregroundStyle(Color.white)
                .onTapGesture {
                    state.showModal(for: .statistics)
                }
        }

        var profileView: some View {
            HStack(spacing: 0) {
                if let override = fetchedPercent.first {
                    if override.enabled {
                        if override.isPreset {
                            let profile = fetchedProfiles.first(where: { $0.id == override.id })
                            if let currentProfile = profile {
                                if let name = currentProfile.name, name != "EMPTY", name.nonEmpty != nil, name != "",
                                   name != "\u{0022}\u{0022}"
                                {
                                    if name.count > 15 {
                                        let shortened = name.prefix(15)
                                        Text(shortened).font(.system(size: 15)).foregroundStyle(Color.white)
                                    } else {
                                        Text(name).font(.system(size: 15)).foregroundStyle(Color.white)
                                    }
                                }
                            } else { Text("📉") } // Hypo Treatment is not actually a preset
                        } else if override.percentage != 100 {
                            Text(override.percentage.formatted() + " %").font(.statusFont).foregroundStyle(.secondary)
                        } else if override.smbIsOff, !override.smbIsAlwaysOff {
                            Text("No ").font(.statusFont).foregroundStyle(.secondary) // "No" as in no SMBs
                            Image(systemName: "syringe")
                                .font(.previewNormal).foregroundStyle(.secondary)
                        } else if override.smbIsOff {
                            Image(systemName: "clock").font(.statusFont).foregroundStyle(.secondary)
                            Image(systemName: "syringe")
                                .font(.previewNormal).foregroundStyle(.secondary)
                        } else {
                            Text("Override").font(.statusFont).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        @ViewBuilder private func glucoseHeaderView() -> some View {
            addBackground()
                .frame(maxHeight: 90)
                .overlay {
                    VStack {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [.rig22Background, .rig22Background]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            glucosePreview.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .dynamicTypeSize(...DynamicTypeSize.medium)
                        }
                    }
                }
                .clipShape(Rectangle())
                .foregroundStyle(Color.white)
        }

        var glucosePreview: some View {
            let data = state.glucose
            let minimum = data.compactMap(\.glucose).min() ?? 0
            let minimumRange = Double(minimum) * 0.8
            let maximum = Double(data.compactMap(\.glucose).max() ?? 0) * 1.1

            let high = state.highGlucose
            let low = state.lowGlucose
            let veryHigh = 198

            return Chart(data) {
                PointMark(
                    x: .value("Time", $0.dateString),
                    y: .value("Glucose", Double($0.glucose ?? 0) * (state.units == .mmolL ? 0.0555 : 1.0))
                )
                .foregroundStyle(
                    (($0.glucose ?? 0) > veryHigh || Decimal($0.glucose ?? 0) < low) ? Color(.red) :
                        Decimal($0.glucose ?? 0) >
                        high ? Color(.yellow) : Color(.darkGreen)
                )
                .symbolSize(7)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                    AxisValueLabel(
                        format: .dateTime.hour(.defaultDigits(amPM: .omitted))
                            .locale(Locale(identifier: "sv"))
                    )
                    AxisGridLine()
                        .foregroundStyle(Color.white)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .chartYScale(
                domain: minimumRange * (state.units == .mmolL ? 0.0555 : 1.0) ... maximum *
                    (state.units == .mmolL ? 0.0555 : 1.0)
            )
            .chartXScale(
                domain: Date.now.addingTimeInterval(-1.days.timeInterval) ... Date.now
            )
            .frame(maxHeight: 70)
            .padding(.leading, 30)
            .padding(.trailing, 32)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .foregroundStyle(Color.white)
        }

        var timeSetting: some View {
            let string = "\(state.hours) " + NSLocalizedString("hours", comment: "") + "   "
            return Menu(string) {
                Button("3 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 3 })
                Button("6 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 6 })
                Button("12 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 12 })
                Button("24 " + NSLocalizedString("hours", comment: ""), action: { state.hours = 24 })
                Button("UI/UX Settings", action: { state.showModal(for: .statisticsConfig) })
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white)
            .font(.timeSettingFont)
            .padding(.vertical, -3)
            .background(TimeEllipse(characters: string.count))
            //           .offset(y: -60)
        }

        var body: some View {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    headerView(geo)

                    if !state.skipGlucoseChart, scrollOffset > scrollAmount {
                        glucoseHeaderView()
                            .transition(.move(edge: .top))
                    }

                    ScrollView {
                        ScrollViewReader { _ in
                            LazyVStack {
                                chart
                                if state.timeSettings { timeSetting }
                                preview.padding(.top, state.timeSettings ? 20 : -5)
                                loopPreview.padding(.top, 0)
                                if state.iobData.count > 5 {
                                    activeCOBView.padding(.top, 15)
                                    activeIOBView.padding(.top, 15)
                                }
                            }
                            .background(GeometryReader { geo in
                                let offset = -geo.frame(in: .named(scrollSpace)).minY
                                Color.rig22Background
                                    .preference(
                                        key: ScrollViewOffsetPreferenceKey.self,
                                        value: offset
                                    )
                            })
                        }
                    }
                    .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                        if !state.skipGlucoseChart, scrollOffset > scrollAmount {
                            display.toggle()
                        }
                    }
                    buttonPanel(geo)
                        .frame(height: 60)
                }
                .background(Color.rig22Background)
                .ignoresSafeArea(edges: .vertical)
            }
            .onAppear(perform: startProgress)
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .popup(isPresented: state.isStatusPopupPresented, alignment: .center, direction: .bottom) {
                popup
                    .padding(10)
                    .shadow(color: .white, radius: 2, x: 0, y: 0)
                    .cornerRadius(10)
                    .onTapGesture {
                        state.isStatusPopupPresented = false
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < 0 {
                                    state.isStatusPopupPresented = false
                                }
                            }
                    )
            }
            .onAppear(perform: configureView)
        }

        var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.suggestionHeadline).foregroundStyle(Color.white)
                    .padding(.bottom, 4)
                if let suggestion = state.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter()).font(.suggestionSmallParts)
                        .foregroundStyle(Color.white)
                } else {
                    Text("No sugestion found").font(.suggestionHeadline).foregroundStyle(Color.white)
                }
                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text(NSLocalizedString("Error at", comment: "") + " " + dateFormatter.string(from: date))
                        .foregroundStyle(Color.white)
                        .font(.suggestionError)
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.suggestionError).fontWeight(.semibold).foregroundColor(.orange)
                } else if let suggestion = state.suggestion, (suggestion.bg ?? 100) == 400 {
                    Text("Invalid CGM reading (HIGH).").font(.suggestionError).bold().foregroundColor(.loopRed)
                        .padding(.top, 8)
                    Text("SMBs and High Temps Disabled.").font(.suggestionParts).foregroundStyle(Color.white)
                        .padding(.bottom, 4)
                }
            }
            .padding()
            .background(Color.rig22Background)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
}
