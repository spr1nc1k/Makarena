import SwiftUI

@main
struct MakarenaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UpdateService.shared.checkOnLaunch()
                }
        }
    }
}
