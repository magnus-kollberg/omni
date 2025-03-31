import SwiftUI

struct LoadingView<Content: View>: View {
    @Binding var isLoading: Bool
    let message: String
    let content: Content
    
    init(isLoading: Binding<Bool>, message: String, @ViewBuilder content: () -> Content) {
        self._isLoading = isLoading
        self.message = message
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .blur(radius: isLoading ? 3 : 0)
                .disabled(isLoading)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text(message)
                        .font(.headline)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 200)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 10)
                )
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    LoadingView(isLoading: .constant(true), message: "Loading...") {
        Text("Content behind loading view")
    }
}