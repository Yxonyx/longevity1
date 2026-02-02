import Foundation
import SwiftUI

@MainActor
class DataStore: ObservableObject {
    @Published var measurements: [Measurement] = []
    @Published var biomarkers: [Biomarker] = []
    @Published var supplements: [Supplement] = []
    @Published var supplementLogs: [SupplementLog] = []
    @Published var readinessScores: [ReadinessScore] = []
    @Published var preferences: UserPreferences = UserPreferences()
    
    private let measurementsKey = "longevity_measurements"
    private let biomarkersKey = "longevity_biomarkers"
    private let supplementsKey = "longevity_supplements"
    private let supplementLogsKey = "longevity_supplement_logs"
    private let readinessKey = "longevity_readiness"
    private let preferencesKey = "longevity_preferences"
    
    init() {
        loadData()
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        measurements = load(key: measurementsKey) ?? []
        biomarkers = load(key: biomarkersKey) ?? []
        supplements = load(key: supplementsKey) ?? []
        supplementLogs = load(key: supplementLogsKey) ?? []
        readinessScores = load(key: readinessKey) ?? []
        preferences = load(key: preferencesKey) ?? UserPreferences()
    }
    
    private func load<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    // MARK: - Measurements
    
    func addMeasurement(_ measurement: Measurement) {
        measurements.append(measurement)
        measurements.sort { $0.timestamp > $1.timestamp }
        save(measurements, key: measurementsKey)
    }
    
    func getMeasurements(type: MetricType, days: Int = 30) -> [Measurement] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return measurements.filter { $0.metricType == type && $0.timestamp >= cutoff }
    }
    
    // MARK: - Biomarkers
    
    func addBiomarker(_ biomarker: Biomarker) {
        biomarkers.append(biomarker)
        biomarkers.sort { $0.testDate > $1.testDate }
        save(biomarkers, key: biomarkersKey)
    }
    
    func getLatestBiomarker(type: BiomarkerType) -> Biomarker? {
        return biomarkers.first { $0.type == type }
    }
    
    func getBiomarkerHistory(type: BiomarkerType) -> [Biomarker] {
        return biomarkers.filter { $0.type == type }
    }
    
    func deleteBiomarker(_ biomarker: Biomarker) {
        biomarkers.removeAll { $0.id == biomarker.id }
        save(biomarkers, key: biomarkersKey)
    }
    
    // MARK: - Supplements
    
    func addSupplement(_ supplement: Supplement) {
        supplements.append(supplement)
        save(supplements, key: supplementsKey)
    }
    
    func updateSupplement(_ supplement: Supplement) {
        if let index = supplements.firstIndex(where: { $0.id == supplement.id }) {
            supplements[index] = supplement
            save(supplements, key: supplementsKey)
        }
    }
    
    func deleteSupplement(_ supplement: Supplement) {
        supplements.removeAll { $0.id == supplement.id }
        save(supplements, key: supplementsKey)
    }
    
    func logSupplementTaken(supplementId: UUID, skipped: Bool = false, notes: String? = nil) {
        let log = SupplementLog(
            id: UUID(),
            supplementId: supplementId,
            takenAt: Date(),
            skipped: skipped,
            notes: notes
        )
        supplementLogs.append(log)
        save(supplementLogs, key: supplementLogsKey)
    }
    
    func getSupplementLogs(supplementId: UUID, days: Int = 30) -> [SupplementLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return supplementLogs.filter { $0.supplementId == supplementId && $0.takenAt >= cutoff }
    }
    
    // MARK: - Readiness Scores
    
    func saveReadinessScore(_ score: ReadinessScore) {
        // Only keep one score per day
        let calendar = Calendar.current
        let scoreDay = calendar.startOfDay(for: score.date)
        
        readinessScores.removeAll { calendar.startOfDay(for: $0.date) == scoreDay }
        readinessScores.append(score)
        readinessScores.sort { $0.date > $1.date }
        save(readinessScores, key: readinessKey)
    }
    
    func getReadinessScore(for date: Date) -> ReadinessScore? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        return readinessScores.first { calendar.startOfDay(for: $0.date) == targetDay }
    }
    
    func getRecentReadinessScores(days: Int = 7) -> [ReadinessScore] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return readinessScores.filter { $0.date >= cutoff }
    }
    
    // MARK: - Preferences
    
    func savePreferences() {
        save(preferences, key: preferencesKey)
    }
    
    // MARK: - Export
    
    func exportAllData() -> Data? {
        struct ExportData: Codable {
            let exportDate: Date
            let measurements: [Measurement]
            let biomarkers: [Biomarker]
            let supplements: [Supplement]
            let supplementLogs: [SupplementLog]
            let readinessScores: [ReadinessScore]
        }
        
        let export = ExportData(
            exportDate: Date(),
            measurements: measurements,
            biomarkers: biomarkers,
            supplements: supplements,
            supplementLogs: supplementLogs,
            readinessScores: readinessScores
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try? encoder.encode(export)
    }
    
    // MARK: - Clear Data
    
    func clearAllData() {
        measurements = []
        biomarkers = []
        supplements = []
        supplementLogs = []
        readinessScores = []
        
        UserDefaults.standard.removeObject(forKey: measurementsKey)
        UserDefaults.standard.removeObject(forKey: biomarkersKey)
        UserDefaults.standard.removeObject(forKey: supplementsKey)
        UserDefaults.standard.removeObject(forKey: supplementLogsKey)
        UserDefaults.standard.removeObject(forKey: readinessKey)
    }
}
