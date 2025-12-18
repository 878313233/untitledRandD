import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Spacer(minLength: 150) // Adds space at the top for upward adjustment
            Image("logo") // Replace "logo" with your image name
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150) // Adjust size as needed
            Text("WAV")
                .font(.largeTitle) // Slightly larger text for emphasis
                .fontWeight(.bold)
                .foregroundColor(.black) // Set text color to black
            Spacer(minLength: 350) // Reduced space below to move content higher
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
