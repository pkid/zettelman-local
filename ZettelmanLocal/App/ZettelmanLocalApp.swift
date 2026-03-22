import SwiftData
import SwiftUI

@main
struct ZettelmanLocalApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppointmentRecord.self,
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
