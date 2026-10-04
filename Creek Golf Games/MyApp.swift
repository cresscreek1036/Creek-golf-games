import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// Local SwiftData store synced to the user's private iCloud database.
    /// The future public leaderboard will use the same container's public database.
    let modelContainer: ModelContainer = {
        let schema = Schema([Course.self, Hole.self, Player.self, Round.self, Score.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.stevejohnson.CreekGolfGames")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
