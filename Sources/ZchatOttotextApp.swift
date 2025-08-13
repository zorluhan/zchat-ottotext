import SwiftUI

@main
struct ZchatOttotextApp: App {
    @StateObject private var model = ChatModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
