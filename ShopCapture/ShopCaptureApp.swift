import SwiftUI

@main
struct ShopCaptureApp: App {
    private let persistenceController = PersistenceController.shared
    @StateObject private var locationProvider = LocationProvider()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(locationProvider)
        }
    }
}
