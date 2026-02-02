import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var exportData: Data?
    
    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section("Profile") {
                    DatePicker(
                        "Birth Date",
                        selection: Binding(
                            get: { dataStore.preferences.birthDate ?? Date() },
                            set: { dataStore.preferences.birthDate = $0; dataStore.savePreferences() }
                        ),
                        displayedComponents: .date
                    )
                    
                    Picker("Biological Sex", selection: Binding(
                        get: { dataStore.preferences.biologicalSex ?? .other },
                        set: { dataStore.preferences.biologicalSex = $0; dataStore.savePreferences() }
                    )) {
                        Text("Male").tag(BiologicalSex.male)
                        Text("Female").tag(BiologicalSex.female)
                        Text("Other").tag(BiologicalSex.other)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", value: Binding(
                            get: { dataStore.preferences.heightCm ?? 170 },
                            set: { dataStore.preferences.heightCm = $0; dataStore.savePreferences() }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("cm")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Goals section
                Section("Goals") {
                    HStack {
                        Text("Target Sleep")
                        Spacer()
                        TextField("hours", value: $dataStore.preferences.targetSleepHours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 40)
                            .onChange(of: dataStore.preferences.targetSleepHours) { _, _ in
                                dataStore.savePreferences()
                            }
                        Text("hours")
                            .foregroundColor(.secondary)
                    }
                    
                    Stepper(
                        "Target Steps: \(dataStore.preferences.targetSteps)",
                        value: $dataStore.preferences.targetSteps,
                        in: 5000...25000,
                        step: 1000
                    )
                    .onChange(of: dataStore.preferences.targetSteps) { _, _ in
                        dataStore.savePreferences()
                    }
                    
                    Stepper(
                        "Zone 2 Target: \(dataStore.preferences.targetZone2Minutes) min/week",
                        value: $dataStore.preferences.targetZone2Minutes,
                        in: 60...300,
                        step: 15
                    )
                    .onChange(of: dataStore.preferences.targetZone2Minutes) { _, _ in
                        dataStore.savePreferences()
                    }
                }
                
                // Privacy section
                Section("Privacy") {
                    Toggle("Enable Notifications", isOn: $dataStore.preferences.enableNotifications)
                        .onChange(of: dataStore.preferences.enableNotifications) { _, _ in
                            dataStore.savePreferences()
                        }
                    
                    Picker("Privacy Mode", selection: $dataStore.preferences.privacyMode) {
                        Text("Standard").tag(PrivacyMode.standard)
                        Text("Enhanced").tag(PrivacyMode.enhanced)
                        Text("Zero-Knowledge").tag(PrivacyMode.zeroKnowledge)
                    }
                    .onChange(of: dataStore.preferences.privacyMode) { _, _ in
                        dataStore.savePreferences()
                    }
                    
                    NavigationLink {
                        PrivacyExplainerView()
                    } label: {
                        Text("About Privacy Modes")
                    }
                }
                
                // Advanced features
                Section {
                    Toggle("Longevity Horizon UI", isOn: $dataStore.preferences.showDeathClockUI)
                        .onChange(of: dataStore.preferences.showDeathClockUI) { _, _ in
                            dataStore.savePreferences()
                        }
                } header: {
                    Text("Advanced Features")
                } footer: {
                    Text("⚠️ Shows risk trajectory visualization. This is an estimate only - not a prediction. Enable only if mentally prepared for this information.")
                        .font(.caption)
                }
                
                // Data section
                Section("Data") {
                    Button {
                        exportData = dataStore.exportAllData()
                        showingExportSheet = true
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    
                    NavigationLink {
                        DataSummaryView()
                    } label: {
                        Label("View Data Summary", systemImage: "chart.bar.doc.horizontal")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink {
                        DisclaimerView()
                    } label: {
                        Text("Medical Disclaimer")
                    }
                    
                    Link(destination: URL(string: "https://longevity.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    dataStore.clearAllData()
                }
            } message: {
                Text("This will permanently delete all your health data, biomarkers, and supplement logs. This cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ExportShareSheet(data: data)
                }
            }
        }
    }
}

// MARK: - Privacy Explainer

struct PrivacyExplainerView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Standard", systemImage: "lock.fill")
                        .font(.headline)
                    Text("Data stored locally with iOS encryption. Optional iCloud sync with Apple's end-to-end encryption.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Enhanced", systemImage: "lock.shield.fill")
                        .font(.headline)
                    Text("No cloud sync. All data stays on device only. Requires manual backup.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Zero-Knowledge", systemImage: "key.fill")
                        .font(.headline)
                    Text("Cloud sync with user-held encryption keys. We cannot access your data even if requested.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Zero-knowledge mode requires you to save your encryption key. If lost, data cannot be recovered.")
            }
        }
        .navigationTitle("Privacy Modes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data Summary

struct DataSummaryView: View {
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        List {
            Section("Stored Data") {
                HStack {
                    Text("Measurements")
                    Spacer()
                    Text("\(dataStore.measurements.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Biomarkers")
                    Spacer()
                    Text("\(dataStore.biomarkers.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Supplements")
                    Spacer()
                    Text("\(dataStore.supplements.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Supplement Logs")
                    Spacer()
                    Text("\(dataStore.supplementLogs.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Readiness Scores")
                    Spacer()
                    Text("\(dataStore.readinessScores.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Data Range") {
                if let oldest = dataStore.measurements.last?.timestamp {
                    HStack {
                        Text("First record")
                        Spacer()
                        Text(oldest, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Last sync")
                    Spacer()
                    Text(Date(), style: .relative)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Data Summary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Disclaimer

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Medical Disclaimer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("""
                Longevity is designed for educational and informational purposes only. It is not intended to be a substitute for professional medical advice, diagnosis, or treatment.
                
                **Important:**
                
                • This app does NOT provide medical diagnoses
                • Scores and metrics are estimates with inherent uncertainty
                • Always consult qualified healthcare providers for medical decisions
                • Do not ignore professional medical advice based on app information
                • Seek immediate medical attention for health emergencies
                
                **Speculative Features:**
                
                Some features (marked with ⚠️) are based on emerging research and should be considered theoretical. These include biological age estimates, autophagy predictions, and inflammaging scores.
                
                **Data Accuracy:**
                
                While we strive for accuracy, wearable data and AI-based estimates may contain errors. Always verify critical health information with laboratory tests and professional evaluation.
                
                By using this app, you acknowledge these limitations and agree to use the information responsibly.
                """)
                .font(.subheadline)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Export Share Sheet

struct ExportShareSheet: View {
    let data: Data
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.teal)
                
                Text("Export Ready")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your data has been prepared for export as JSON format.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("\(data.count / 1024) KB")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                
                Spacer()
                
                ShareLink(item: ExportDocument(data: data), preview: SharePreview("Longevity Data Export")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ExportDocument: Transferable {
    let data: Data
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { document in
            document.data
        }
        .suggestedFileName("longevity-export-\(Date().formatted(.iso8601)).json")
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataStore())
}
