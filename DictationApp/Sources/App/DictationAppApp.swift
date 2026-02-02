import SwiftUI

@main
struct DictationAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup - menu bar only app
        Settings {
            EmptyView()
        }
    }
}
