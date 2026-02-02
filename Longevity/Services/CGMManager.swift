import Foundation
import HealthKit

// MARK: - CGM Data Models

struct GlucoseReading: Identifiable, Codable {
    let id: UUID
    let value: Double // mg/dL
    let timestamp: Date
    let provenance: CGMProvenance
    let trend: GlucoseTrend?
    
    init(
        id: UUID = UUID(),
        value: Double,
        timestamp: Date = Date(),
        provenance: CGMProvenance = .healthKit,
        trend: GlucoseTrend? = nil
    ) {
        self.id = id
        self.value = value
        self.timestamp = timestamp
        self.provenance = provenance
        self.trend = trend
    }
    
    var status: GlucoseStatus {
        switch value {
        case 0..<54: return .critical(.low)
        case 54..<70: return .warning(.low)
        case 70..<100: return .optimal
        case 100..<140: return .elevated
        case 140..<180: return .warning(.high)
        default: return .critical(.high)
        }
    }
}

enum CGMProvenance: String, Codable {
    case healthKit
    case dexcom
    case libre
    case manual
}

enum GlucoseTrend: String, Codable {
    case risingRapidly = "rising_rapidly"
    case rising = "rising"
    case stable = "stable"
    case falling = "falling"
    case fallingRapidly = "falling_rapidly"
    
    var icon: String {
        switch self {
        case .risingRapidly: return "arrow.up.forward"
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .falling: return "arrow.down.right"
        case .fallingRapidly: return "arrow.down.forward"
        }
    }
    
    var description: String {
        switch self {
        case .risingRapidly: return "Rising rapidly"
        case .rising: return "Rising"
        case .stable: return "Stable"
        case .falling: return "Falling"
        case .fallingRapidly: return "Falling rapidly"
        }
    }
}

enum GlucoseStatus {
    case optimal
    case elevated
    case warning(Direction)
    case critical(Direction)
    
    enum Direction {
        case low
        case high
    }
    
    var color: String {
        switch self {
        case .optimal: return "green"
        case .elevated: return "yellow"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .optimal: return "In Range"
        case .elevated: return "Elevated"
        case .warning(.low): return "Low"
        case .warning(.high): return "High"
        case .critical(.low): return "Very Low"
        case .critical(.high): return "Very High"
        }
    }
}

// MARK: - Glucose Statistics

struct GlucoseStatistics: Codable {
    let period: DateInterval
    let average: Double
    let standardDeviation: Double
    let coefficientOfVariation: Double // CV%
    let timeInRange: Double // % between 70-140
    let timeBelowRange: Double // % below 70
    let timeAboveRange: Double // % above 140
    let glucoseManagementIndicator: Double? // GMI / estimated A1c
    let lowestValue: Double
    let highestValue: Double
    let readingCount: Int
    
    static func calculate(from readings: [GlucoseReading], period: DateInterval) -> GlucoseStatistics {
        let values = readings.map { $0.value }
        guard !values.isEmpty else {
            return GlucoseStatistics(
                period: period,
                average: 0,
                standardDeviation: 0,
                coefficientOfVariation: 0,
                timeInRange: 0,
                timeBelowRange: 0,
                timeAboveRange: 0,
                glucoseManagementIndicator: nil,
                lowestValue: 0,
                highestValue: 0,
                readingCount: 0
            )
        }
        
        let count = Double(values.count)
        let average = values.reduce(0, +) / count
        
        let variance = values.reduce(0) { $0 + pow($1 - average, 2) } / count
        let stdDev = sqrt(variance)
        let cv = (stdDev / average) * 100
        
        let inRange = values.filter { $0 >= 70 && $0 <= 140 }.count
        let belowRange = values.filter { $0 < 70 }.count
        let aboveRange = values.filter { $0 > 140 }.count
        
        let tir = Double(inRange) / count * 100
        let tbr = Double(belowRange) / count * 100
        let tar = Double(aboveRange) / count * 100
        
        // GMI formula: 3.31 + 0.02392 × mean glucose (mg/dL)
        let gmi = 3.31 + 0.02392 * average
        
        return GlucoseStatistics(
            period: period,
            average: average,
            standardDeviation: stdDev,
            coefficientOfVariation: cv,
            timeInRange: tir,
            timeBelowRange: tbr,
            timeAboveRange: tar,
            glucoseManagementIndicator: gmi,
            lowestValue: values.min() ?? 0,
            highestValue: values.max() ?? 0,
            readingCount: values.count
        )
    }
}

// MARK: - Glucose Event

struct GlucoseEvent: Identifiable, Codable {
    let id: UUID
    let type: GlucoseEventType
    let startTime: Date
    let endTime: Date?
    let peakValue: Double
    let trigger: String? // What likely caused it (meal, stress, etc.)
    
    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}

enum GlucoseEventType: String, Codable {
    case spike = "spike" // >140 mg/dL
    case dip = "dip" // <70 mg/dL
    case excursion = "excursion" // prolonged out of range
    
    var icon: String {
        switch self {
        case .spike: return "arrow.up.circle.fill"
        case .dip: return "arrow.down.circle.fill"
        case .excursion: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - CGM Manager

@MainActor
class CGMManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var readings: [GlucoseReading] = []
    @Published var todayStats: GlucoseStatistics?
    @Published var weekStats: GlucoseStatistics?
    @Published var events: [GlucoseEvent] = []
    @Published var isAuthorized = false
    @Published var latestReading: GlucoseReading?
    
    private let glucoseReadingsKey = "longevity_glucose_readings"
    private let glucoseEventsKey = "longevity_glucose_events"
    
    init() {
        loadStoredData()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [glucoseType])
            await MainActor.run {
                self.isAuthorized = true
            }
            return true
        } catch {
            print("CGM authorization error: \(error)")
            return false
        }
    }
    
    // MARK: - Fetch Glucose Data
    
    func fetchGlucoseData(days: Int = 7) async {
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: glucoseType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let readings = samples.map { sample in
                    GlucoseReading(
                        value: sample.quantity.doubleValue(for: HKUnit(from: "mg/dL")),
                        timestamp: sample.endDate,
                        provenance: .healthKit
                    )
                }
                
                DispatchQueue.main.async {
                    self?.readings = readings
                    self?.latestReading = readings.last
                    self?.calculateStatistics()
                    self?.detectEvents()
                    self?.saveStoredData()
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Statistics
    
    private func calculateStatistics() {
        let calendar = Calendar.current
        let now = Date()
        
        // Today stats
        let startOfToday = calendar.startOfDay(for: now)
        let todayReadings = readings.filter { $0.timestamp >= startOfToday }
        todayStats = GlucoseStatistics.calculate(
            from: todayReadings,
            period: DateInterval(start: startOfToday, end: now)
        )
        
        // Week stats
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let weekReadings = readings.filter { $0.timestamp >= weekAgo }
        weekStats = GlucoseStatistics.calculate(
            from: weekReadings,
            period: DateInterval(start: weekAgo, end: now)
        )
    }
    
    // MARK: - Event Detection
    
    private func detectEvents() {
        var detectedEvents: [GlucoseEvent] = []
        var i = 0
        
        while i < readings.count {
            let reading = readings[i]
            
            // Detect spike (>140 mg/dL)
            if reading.value > 140 {
                var endIndex = i
                var peakValue = reading.value
                
                // Find end of spike
                while endIndex + 1 < readings.count && readings[endIndex + 1].value > 140 {
                    endIndex += 1
                    peakValue = max(peakValue, readings[endIndex].value)
                }
                
                detectedEvents.append(GlucoseEvent(
                    id: UUID(),
                    type: .spike,
                    startTime: reading.timestamp,
                    endTime: readings[endIndex].timestamp,
                    peakValue: peakValue,
                    trigger: nil
                ))
                
                i = endIndex + 1
                continue
            }
            
            // Detect dip (<70 mg/dL)
            if reading.value < 70 {
                var endIndex = i
                var lowestValue = reading.value
                
                while endIndex + 1 < readings.count && readings[endIndex + 1].value < 70 {
                    endIndex += 1
                    lowestValue = min(lowestValue, readings[endIndex].value)
                }
                
                detectedEvents.append(GlucoseEvent(
                    id: UUID(),
                    type: .dip,
                    startTime: reading.timestamp,
                    endTime: readings[endIndex].timestamp,
                    peakValue: lowestValue,
                    trigger: nil
                ))
                
                i = endIndex + 1
                continue
            }
            
            i += 1
        }
        
        self.events = detectedEvents
    }
    
    // MARK: - Trend Calculation
    
    func calculateTrend(recentReadings: [GlucoseReading]) -> GlucoseTrend? {
        guard recentReadings.count >= 3 else { return nil }
        
        let last3 = recentReadings.suffix(3)
        let values = last3.map { $0.value }
        
        let firstValue = values.first!
        let lastValue = values.last!
        let change = lastValue - firstValue
        let rateOfChange = change / 15 // Assuming 5-min intervals, 15 min total
        
        switch rateOfChange {
        case _ where rateOfChange > 3: return .risingRapidly
        case _ where rateOfChange > 1: return .rising
        case _ where rateOfChange < -3: return .fallingRapidly
        case _ where rateOfChange < -1: return .falling
        default: return .stable
        }
    }
    
    // MARK: - Manual Entry
    
    func addManualReading(value: Double, timestamp: Date = Date()) {
        let reading = GlucoseReading(
            value: value,
            timestamp: timestamp,
            provenance: .manual
        )
        readings.append(reading)
        readings.sort { $0.timestamp < $1.timestamp }
        latestReading = readings.last
        calculateStatistics()
        saveStoredData()
    }
    
    // MARK: - Persistence
    
    private func loadStoredData() {
        if let data = UserDefaults.standard.data(forKey: glucoseReadingsKey),
           let decoded = try? JSONDecoder().decode([GlucoseReading].self, from: data) {
            readings = decoded
            latestReading = readings.last
            calculateStatistics()
        }
        
        if let data = UserDefaults.standard.data(forKey: glucoseEventsKey),
           let decoded = try? JSONDecoder().decode([GlucoseEvent].self, from: data) {
            events = decoded
        }
    }
    
    private func saveStoredData() {
        if let data = try? JSONEncoder().encode(readings) {
            UserDefaults.standard.set(data, forKey: glucoseReadingsKey)
        }
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: glucoseEventsKey)
        }
    }
}
