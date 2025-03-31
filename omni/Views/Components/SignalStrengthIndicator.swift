import SwiftUI

struct SignalStrengthIndicator: View {
    let level: Int // 0-4, with 0 being no signal and 4 being excellent signal
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                Rectangle()
                    .fill(i < level ? signalColor : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(i) * 3 + 5)
            }
        }
        .accessibilityLabel("Signal strength: \(strengthDescription)")
    }
    
    private var signalColor: Color {
        switch level {
        case 0:
            return .red
        case 1:
            return .orange
        case 2:
            return .yellow
        case 3, 4:
            return .green
        default:
            return .gray
        }
    }
    
    private var strengthDescription: String {
        switch level {
        case 0:
            return "Very weak"
        case 1:
            return "Weak"
        case 2:
            return "Moderate"
        case 3:
            return "Good"
        case 4:
            return "Excellent"
        default:
            return "Unknown"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SignalStrengthIndicator(level: 0)
        SignalStrengthIndicator(level: 1)
        SignalStrengthIndicator(level: 2)
        SignalStrengthIndicator(level: 3)
        SignalStrengthIndicator(level: 4)
    }
    .padding()
}