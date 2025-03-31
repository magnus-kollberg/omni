import SwiftUI

struct ToastView: View {
    let message: String
    let type: ToastType
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.iconName)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(type.color)
        .cornerRadius(8)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}

enum ToastType {
    case success
    case error
    case info
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastType
    let duration: Double
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                
                if isShowing {
                    ToastView(message: message, type: type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: isShowing)
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, type: ToastType = .info, duration: Double = 3.0) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, type: type, duration: duration))
    }
}

#Preview {
    VStack {
        Text("Toast Preview")
            .padding()
    }
    .modifier(ToastModifier(isShowing: .constant(true), message: "This is a toast notification", type: .info, duration: 5.0))
}