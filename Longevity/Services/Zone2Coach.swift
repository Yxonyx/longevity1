import Foundation
import HealthKit
import SwiftUI
#if os(watchOS)
import WatchKit
#endif

// MARK: - Zone 2 Configuration

struct Zone2Config: Codable {
    var minHeartRate: Double
    var maxHeartRate: Double
    var targetDurationMinutes: Int
    var hapticFeedbackEnabled: Bool
    var alertWhenExitingZone: Bool
    var alertInterval: TimeInterval // seconds between alerts when outside zone
    
    static func forAge(_ age: Int, maxHR: Double? = nil) -> Zone2Config {
        // Zone 2 is typically 60-70% of max HR
        // Max HR estimate: 220 - age (or use actual if known)
        let estimatedMaxHR = maxHR ?? (220 - Double(age))
        
        return Zone2Config(
            minHeartRate: estimatedMaxHR * 0.60,
            maxHeartRate: estimatedMaxHR * 0.70,
            targetDurationMinutes: 45,
            hapticFeedbackEnabled: true,
            alertWhenExitingZone: true,
            alertInterval: 30
        )
    }
}

// MARK: - Zone 2 Session

struct Zone2Session: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var heartRateSamples: [HeartRateSample]
    var timeInZone: TimeInterval // seconds
    var timeAboveZone: TimeInterval
    var timeBelowZone: TimeInterval
    
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var percentInZone: Double {
        duration > 0 ? (timeInZone / duration) * 100 : 0
    }
    
    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.reduce(0) { $0 + $1.value } / Double(heartRateSamples.count)
    }
}

struct HeartRateSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let zone: HRZone
    
    init(value: Double, config: Zone2Config) {
        self.id = UUID()
        self.timestamp = Date()
        self.value = value
        
        if value < config.minHeartRate {
            self.zone = .belowZone2
        } else if value > config.maxHeartRate {
            self.zone = .aboveZone2
        } else {
            self.zone = .zone2
        }
    }
}

enum HRZone: String, Codable {
    case belowZone2
    case zone2
    case aboveZone2
    
    var color: String {
        switch self {
        case .belowZone2: return "blue"
        case .zone2: return "green"
        case .aboveZone2: return "red"
        }
    }
    
    var instruction: String {
        switch self {
        case .belowZone2: return "Speed up slightly"
        case .zone2: return "Perfect pace!"
        case .aboveZone2: return "Slow down"
        }
    }
}

// MARK: - Zone 2 Coach

@MainActor
class Zone2Coach: ObservableObject {
    @Published var isActive = false
    @Published var currentSession: Zone2Session?
    @Published var currentHeartRate: Double = 0
    @Published var currentZone: HRZone = .belowZone2
    @Published var config: Zone2Config
    @Published var pastSessions: [Zone2Session] = []
    
    private var healthStore: HKHealthStore?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var lastHapticTime: Date?
    private let sessionsKey = "longevity_zone2_sessions"
    
    init(age: Int = 40) {
        self.config = Zone2Config.forAge(age)
        
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
        
        loadSessions()
    }
    
    // MARK: - Session Control
    
    func startSession() {
        guard !isActive else { return }
        
        isActive = true
        currentSession = Zone2Session(
            id: UUID(),
            startTime: Date(),
            heartRateSamples: [],
            timeInZone: 0,
            timeAboveZone: 0,
            timeBelowZone: 0
        )
        
        startHeartRateMonitoring()
        
        #if os(watchOS)
        playStartHaptic()
        #endif
    }
    
    func endSession() {
        guard isActive, var session = currentSession else { return }
        
        isActive = false
        session.endTime = Date()
        
        stopHeartRateMonitoring()
        
        pastSessions.insert(session, at: 0)
        saveSessions()
        
        currentSession = nil
        
        #if os(watchOS)
        playEndHaptic()
        #endif
    }
    
    // MARK: - Heart Rate Monitoring
    
    private func startHeartRateMonitoring() {
        guard let healthStore = healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        healthStore.execute(query)
        heartRateQuery = query
    }
    
    private func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore?.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latestSample = samples.last else { return }
        
        let heartRate = latestSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        
        DispatchQueue.main.async {
            self.updateHeartRate(heartRate)
        }
    }
    
    func updateHeartRate(_ hr: Double) {
        currentHeartRate = hr
        
        guard var session = currentSession else { return }
        
        let sample = HeartRateSample(value: hr, config: config)
        session.heartRateSamples.append(sample)
        
        // Update zone time (assuming ~1 second between samples)
        let interval: TimeInterval = 1.0
        switch sample.zone {
        case .zone2:
            session.timeInZone += interval
        case .aboveZone2:
            session.timeAboveZone += interval
        case .belowZone2:
            session.timeBelowZone += interval
        }
        
        currentSession = session
        currentZone = sample.zone
        
        // Haptic feedback
        if config.hapticFeedbackEnabled && sample.zone != .zone2 {
            triggerZoneAlert()
        }
        
        // Send to iPhone via WatchConnectivity
        WatchSyncManager.shared.sendZone2Update(
            currentHR: hr,
            zone2Min: config.minHeartRate,
            zone2Max: config.maxHeartRate,
            duration: session.timeInZone
        )
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerZoneAlert() {
        guard config.alertWhenExitingZone else { return }
        
        // Rate limit haptics
        if let lastTime = lastHapticTime, Date().timeIntervalSince(lastTime) < config.alertInterval {
            return
        }
        
        lastHapticTime = Date()
        
        #if os(watchOS)
        WKInterfaceDevice.current().play(currentZone == .aboveZone2 ? .directionDown : .directionUp)
        #endif
    }
    
    #if os(watchOS)
    private func playStartHaptic() {
        WKInterfaceDevice.current().play(.start)
    }
    
    private func playEndHaptic() {
        WKInterfaceDevice.current().play(.success)
    }
    #endif
    
    // MARK: - Analytics
    
    func weeklyZone2Minutes() -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklySessions = pastSessions.filter { $0.startTime >= weekAgo }
        let totalSeconds = weeklySessions.reduce(0) { $0 + $1.timeInZone }
        return Int(totalSeconds / 60)
    }
    
    func averagePercentInZone() -> Double {
        guard !pastSessions.isEmpty else { return 0 }
        return pastSessions.reduce(0) { $0 + $1.percentInZone } / Double(pastSessions.count)
    }
    
    // MARK: - Persistence
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([Zone2Session].self, from: data) {
            pastSessions = decoded
        }
    }
    
    private func saveSessions() {
        // Keep last 30 sessions
        let toSave = Array(pastSessions.prefix(30))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
}

// MARK: - Zone 2 View (Watch)

#if os(watchOS)
struct Zone2WatchView: View {
    @StateObject private var coach = Zone2Coach()
    
    var body: some View {
        VStack(spacing: 12) {
            if coach.isActive {
                // Active session
                Text(coach.currentZone.instruction)
                    .font(.headline)
                    .foregroundColor(zoneColor)
                
                Text("\(Int(coach.currentHeartRate))")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(zoneColor)
                
                Text("BPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Zone indicator
                HStack(spacing: 4) {
                    zoneBar(for: .belowZone2)
                    zoneBar(for: .zone2)
                    zoneBar(for: .aboveZone2)
                }
                .frame(height: 8)
                
                // Time in zone
                if let session = coach.currentSession {
                    Text("In Zone: \(formatDuration(session.timeInZone))")
                        .font(.caption2)
                }
                
                Button("End") {
                    coach.endSession()
                }
                .buttonStyle(.bordered)
            } else {
                // Start new session
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("Zone 2 Training")
                        .font(.headline)
                    
                    Text("\(Int(coach.config.minHeartRate))-\(Int(coach.config.maxHeartRate)) BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Start") {
                        coach.startSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                
                // Weekly progress
                if coach.weeklyZone2Minutes() > 0 {
                    Text("\(coach.weeklyZone2Minutes()) min this week")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private var zoneColor: Color {
        switch coach.currentZone {
        case .belowZone2: return .blue
        case .zone2: return .green
        case .aboveZone2: return .red
        }
    }
    
    private func zoneBar(for zone: HRZone) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(zone == coach.currentZone ? Color(zone.color) : Color.gray.opacity(0.3))
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
#endif

// MARK: - Zone 2 View (iPhone)

struct Zone2View: View {
    @StateObject private var coach = Zone2Coach()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current/last session card
                    sessionCard
                    
                    // Weekly progress
                    weeklyProgressCard
                    
                    // Past sessions
                    pastSessionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Zone 2 Training")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                Zone2SettingsSheet(config: $coach.config)
            }
        }
    }
    
    private var sessionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.green)
                Text("Zone 2 Target")
                    .font(.headline)
                Spacer()
                Text("\(Int(coach.config.minHeartRate))-\(Int(coach.config.maxHeartRate)) BPM")
                    .foregroundColor(.secondary)
            }
            
            // Zone visualization
            ZStack {
                // Background zones
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geo.size.width * 0.3)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geo.size.width * 0.4)
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: geo.size.width * 0.3)
                    }
                }
                .frame(height: 40)
                .cornerRadius(8)
                
                // Labels
                HStack {
                    Text("Too Slow")
                        .font(.caption2)
                    Spacer()
                    Text("Zone 2")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Too Fast")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
            }
            
            Text("Use your Apple Watch to track Zone 2 sessions with haptic feedback")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)
                Spacer()
                Text("\(coach.weeklyZone2Minutes()) / \(coach.config.targetDurationMinutes * 3) min")
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                        .frame(width: min(geo.size.width, geo.size.width * Double(coach.weeklyZone2Minutes()) / Double(coach.config.targetDurationMinutes * 3)))
                }
            }
            .frame(height: 12)
            
            Text("Target: \(coach.config.targetDurationMinutes) min × 3 sessions/week")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var pastSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
            
            if coach.pastSessions.isEmpty {
                Text("No sessions yet. Start a Zone 2 session on your Apple Watch.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(coach.pastSessions.prefix(5)) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.startTime, style: .date)
                                .font(.subheadline)
                            Text("\(Int(session.duration / 60)) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(session.percentInZone))% in zone")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(session.percentInZone >= 80 ? .green : .orange)
                            Text("Avg: \(Int(session.averageHeartRate)) BPM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Settings Sheet

struct Zone2SettingsSheet: View {
    @Binding var config: Zone2Config
    @Environment(\.dismiss) var dismiss
    
    @State private var age = 40
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Heart Rate Zones") {
                    Stepper("Age: \(age)", value: $age, in: 18...100)
                    
                    Button("Calculate from Age") {
                        config = Zone2Config.forAge(age)
                    }
                    
                    HStack {
                        Text("Zone 2 Range")
                        Spacer()
                        Text("\(Int(config.minHeartRate))-\(Int(config.maxHeartRate)) BPM")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Goals") {
                    Stepper("Target: \(config.targetDurationMinutes) min/session", value: $config.targetDurationMinutes, in: 15...90, step: 5)
                }
                
                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: $config.hapticFeedbackEnabled)
                    Toggle("Alert When Leaving Zone", isOn: $config.alertWhenExitingZone)
                }
            }
            .navigationTitle("Zone 2 Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    Zone2View()
}
