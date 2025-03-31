import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    
    let pages = [
        OnboardingPage(title: "Welcome to Omni", description: "Connect and configure your IoT devices with ease", imageName: "wifi.circle"),
        OnboardingPage(title: "Discover", description: "Find nearby devices using Bluetooth or your local network", imageName: "bluetooth"),
        OnboardingPage(title: "Configure", description: "Set up WiFi and other settings for your device", imageName: "gearshape.fill"),
        OnboardingPage(title: "Monitor", description: "Keep track of your devices' status", imageName: "chart.bar")
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count) { i in
                    OnboardingPageView(page: pages[i])
                        .tag(i)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    // Proceed to main app
                    onboardingCompleted = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

struct OnboardingPage: Identifiable {
    var id = UUID()
    let title: String
    let description: String
    let imageName: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .foregroundColor(.blue)
                .padding()
                .accessibilityHidden(true)
            
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}