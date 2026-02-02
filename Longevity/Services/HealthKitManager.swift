import Foundation
import HealthKit

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var latestHRV: Double?
    @Published var latestRestingHR: Double?
    @Published var latestSleepHours: Double?
    @Published var latestVO2Max: Double?
    @Published var todaySteps: Int = 0
    @Published var hrvBaseline7Day: Double?
    @Published var rhrBaseline7Day: Double?
    
    // Types we want to read
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        
        // Vitals
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let respRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respRate)
        }
        if let oxygenSat = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(oxygenSat)
        }
        if let bodyTemp = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(bodyTemp)
        }
        
        // Activity
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let vo2Max = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2Max)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        
        // Body
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        
        // Sleep
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        
        // Blood glucose
        if let glucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(glucose)
        }
        
        return types
    }()
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.fetchAllData()
                }
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetchAllData() {
        Task {
            await fetchLatestHRV()
            await fetchLatestRestingHR()
            await fetchSleepData()
            await fetchVO2Max()
            await fetchTodaySteps()
            await fetchHRVBaseline()
            await fetchRHRBaseline()
        }
    }
    
    // MARK: - HRV
    
    private func fetchLatestHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            end: Date(),
            options: .strictEndDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                DispatchQueue.main.async {
                    if let sample = samples?.first as? HKQuantitySample {
                        self?.latestHRV = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchHRVBaseline() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            end: Date(),
            options: .strictEndDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { [weak self] _, statistics, error in
                DispatchQueue.main.async {
                    self?.hrvBaseline7Day = statistics?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Resting Heart Rate
    
    private func fetchLatestRestingHR() async {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            end: Date(),
            options: .strictEndDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                DispatchQueue.main.async {
                    if let sample = samples?.first as? HKQuantitySample {
                        self?.latestRestingHR = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRHRBaseline() async {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            end: Date(),
            options: .strictEndDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: rhrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { [weak self] _, statistics, error in
                DispatchQueue.main.async {
                    self?.rhrBaseline7Day = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Sleep
    
    private func fetchSleepData() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, error in
                var totalSleep: TimeInterval = 0
                
                if let samples = samples as? [HKCategorySample] {
                    for sample in samples {
                        // Only count asleep states (not in bed)
                        if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                            totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self?.latestSleepHours = totalSleep / 3600
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - VO2 Max
    
    private func fetchVO2Max() async {
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                DispatchQueue.main.async {
                    if let sample = samples?.first as? HKQuantitySample {
                        self?.latestVO2Max = sample.quantity.doubleValue(for: HKUnit(from: "mL/kg*min"))
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Steps
    
    private func fetchTodaySteps() async {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, statistics, error in
                DispatchQueue.main.async {
                    self?.todaySteps = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Helper to get measurements array
    
    func getMeasurements() -> [Measurement] {
        var measurements: [Measurement] = []
        
        if let hrv = latestHRV {
            measurements.append(Measurement(
                metricType: .hrvSDNN,
                value: hrv,
                provenance: .healthKit
            ))
        }
        
        if let rhr = latestRestingHR {
            measurements.append(Measurement(
                metricType: .restingHeartRate,
                value: rhr,
                provenance: .healthKit
            ))
        }
        
        if let sleep = latestSleepHours {
            measurements.append(Measurement(
                metricType: .sleepDuration,
                value: sleep,
                provenance: .healthKit
            ))
        }
        
        if let vo2 = latestVO2Max {
            measurements.append(Measurement(
                metricType: .vo2Max,
                value: vo2,
                provenance: .healthKit
            ))
        }
        
        return measurements
    }
}
