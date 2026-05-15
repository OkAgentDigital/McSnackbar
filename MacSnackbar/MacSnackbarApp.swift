import SwiftUI

struct TestMainView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Snackbar Test Window")
                .font(.title2)
                .bold()
            Text("This window is for testing only.\nAll real UI is in the menu bar.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .frame(width: 320, height: 180)
    }
}

@main
struct SnackbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            TestMainView()
        }
        Settings {
            EmptyView()
        }
    }
}
