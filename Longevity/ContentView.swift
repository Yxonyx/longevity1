import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square.fill")
                }
                .tag(0)
            
            BiomarkerView()
                .tabItem {
                    Label("Biomarkers", systemImage: "drop.fill")
                }
                .tag(1)
            
            SupplementView()
                .tabItem {
                    Label("Supplements", systemImage: "pills.fill")
                }
                .tag(2)
            
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(3)
        }
        .tint(.teal)
        .onAppear {
            healthKitManager.requestAuthorization()
        }
    }
}

// MARK: - More View (Hub for v1.0 + v2.0 Features)

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Longevity") {
                    NavigationLink {
                        LongevityHorizonView()
                    } label: {
                        Label("Longevity Horizon", systemImage: "hourglass")
                    }
                    
                    NavigationLink {
                        BiologicalAgeView()
                    } label: {
                        Label("Biological Age", systemImage: "person.badge.clock")
                    }
                    
                    NavigationLink {
                        ExperimentView()
                    } label: {
                        Label("N-of-1 Experiments", systemImage: "flask.fill")
                    }
                }
                
                Section("Metabolic Health") {
                    NavigationLink {
                        GlucoseView()
                    } label: {
                        Label("Glucose Tracking", systemImage: "waveform.path.ecg")
                    }
                    
                    NavigationLink {
                        NutritionView()
                    } label: {
                        Label("Nutrition & Macros", systemImage: "fork.knife")
                    }
                }
                
                Section("Training") {
                    NavigationLink {
                        Zone2View()
                    } label: {
                        Label("Zone 2 Training", systemImage: "heart.fill")
                    }
                }
                
                Section("Data Entry") {
                    NavigationLink {
                        LabUploadView()
                    } label: {
                        Label("Upload Labs (OCR)", systemImage: "doc.text.viewfinder")
                    }
                }
                
                Section("Account") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(DataStore())
}

