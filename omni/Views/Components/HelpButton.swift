import SwiftUI

struct HelpButton: View {
    let message: String
    @State private var showingHelp = false
    
    var body: some View {
        Button {
            showingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.blue)
        }
        .popover(isPresented: $showingHelp) {
            Text(message)
                .font(.body)
                .padding()
                .frame(maxWidth: 300)
        }
        .accessibilityLabel("Help")
        .accessibilityHint("Shows information about this field")
    }
}

#Preview {
    HelpButton(message: "This is a helpful explanation about what this field does.")
}