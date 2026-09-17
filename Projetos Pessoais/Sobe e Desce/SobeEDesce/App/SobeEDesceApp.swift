import SwiftData
import SwiftUI
import UIKit

@main
@MainActor
struct SobeEDesceApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var gameStore: GameStore

    init() {
        do {
            #if DEBUG
            let isUITesting = ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
            #else
            let isUITesting = false
            #endif
            if isUITesting {
                UIView.setAnimationsEnabled(false)
            }
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            let container = try ModelContainer(for: StoredGameSession.self, configurations: configuration)
            modelContainer = container
            _gameStore = StateObject(wrappedValue: GameStore(modelContext: container.mainContext))
        } catch {
            fatalError("Não foi possível iniciar o armazenamento local: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameStore)
                .tint(AppTheme.burgundy)
        }
        .modelContainer(modelContainer)
    }
}
