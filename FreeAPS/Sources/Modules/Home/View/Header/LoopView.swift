import SwiftDate
import SwiftUI
import UIKit

struct LoopView: View {
    private enum Config {
        static let lag: TimeInterval = 30
    }

    struct LoopCapsule: View {
        var stroke: Color
        var gradient: [Color] // Farben für den Farbverlauf

        var body: some View {
            Capsule()
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradient),
                    startPoint: .top,
                    endPoint: .bottom
                )) // Fülle die Kapsel mit einem Farbverlauf
                .overlay(
                    Capsule().stroke(stroke, lineWidth: 0) // Zeichne den Rand der Kapsel
                )
                .shadow(color: .white, radius: 1, x: 0, y: 1) // Hier wird der weiße Schatten hinzugefügt
        }
    }

    private var gradientColors: [Color] {
        if isLooping {
            return [.black, .purple]
        } else if closedLoop {
            return [.purple, .black]
        } else {
            return [.red]
        }
    }

    @Binding var suggestion: Suggestion?
    @Binding var enactedSuggestion: Suggestion?
    @Binding var closedLoop: Bool
    @Binding var timerDate: Date
    @Binding var isLooping: Bool
    @Binding var lastLoopDate: Date
    @Binding var manualTempBasal: Bool

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var fontSize

    // Berechne die Füllfarbe basierend auf deinen Bedingungen
    private var fillColor: Color {
        // Implementiere die Logik zur Bestimmung der Füllfarbe
        if isLooping {
            return .blue // Beispiel: Fülle mit Blau, wenn Looping
        } else if closedLoop {
            return .purple // Beispiel: Fülle mit Grün, wenn geschlossen
        } else {
            return .gray // Beispiel: Fülle mit Grau, wenn offen
        }
    }

    var body: some View {
        VStack {
            HStack(spacing: 10) { // Verwende HStack mit Abstand zwischen den Elementen
                LoopCapsule(stroke: color, gradient: gradientColors)
                    .frame(width: 70, height: 30) // Setzt die Größe der Kapsel auf 70 x 30
                    .overlay {
                        let textColor: Color = .white
                        HStack {
                            ZStack {
                                if closedLoop {
                                    if !isLooping, actualSuggestion?.timestamp != nil {
                                        if minutesAgo > 1440 {
                                            Text("--").font(.loopFont).foregroundColor(textColor).padding(.leading, 5)
                                        } else {
                                            let timeString = "\(minutesAgo) " +
                                                NSLocalizedString("min", comment: "Minutes ago since last loop")
                                            Text(timeString).font(.loopFont).foregroundColor(textColor)
                                        }
                                    }
                                    if isLooping {
                                        ProgressView()
                                    }
                                } else if !isLooping {
                                    Text("Open").font(.loopFont)
                                }
                            }
                        }
                    }

                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            // .padding() // Optional: Füge Padding hinzu, um den HStack vom Rand zu entfernen
        }
    }

    private var minutesAgo: Int {
        let minAgo = Int((timerDate.timeIntervalSince(lastLoopDate) - Config.lag) / 60) + 1
        return minAgo
    }

    private var color: Color {
        guard actualSuggestion?.timestamp != nil else {
            return .white
        }
        guard manualTempBasal == false else {
            return .loopManualTemp
        }
        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 8.minutes.timeInterval {
            guard actualSuggestion?.deliverAt != nil else {
                return .loopYellow
            }
            return .loopGreen
        } else if delta <= 12.minutes.timeInterval {
            return .loopYellow
        } else {
            return .loopRed
        }
    }

    private var actualSuggestion: Suggestion? {
        if closedLoop, enactedSuggestion?.recieved == true {
            return enactedSuggestion ?? suggestion
        } else {
            return suggestion
        }
    }
}

extension View {
    func animateForever(
        using animation: Animation = Animation.easeInOut(duration: 1),
        autoreverses: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        let repeated = animation.repeatForever(autoreverses: autoreverses)

        return onAppear {
            withAnimation(repeated) {
                action()
            }
        }
    }
}
