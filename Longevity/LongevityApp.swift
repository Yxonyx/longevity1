import SwiftUI

@main
struct LongevityApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var dataStore = DataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(dataStore)
        }
    }
}
