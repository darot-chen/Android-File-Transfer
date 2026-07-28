import SwiftUI

@main
struct AndroidFileTransferApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
        }
    }
}
