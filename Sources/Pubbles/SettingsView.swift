import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Pubbles Settings")
                .font(.title2)
                .padding()
            Spacer()
            Text("Coming soon")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(width: 420, height: 600)
    }
}
