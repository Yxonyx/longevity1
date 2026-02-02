import SwiftUI
import HealthKit

struct WatchContentView: View {
    @State private var readinessScore: Int = 0
    @State private var latestHRV: Double?
    @State private var todaySteps: Int = 0
    @State private var isLoading = true
    
    private let healthStore = HKHealthStore()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Readiness gauge
                    readinessGauge
                    
                    // Quick metrics
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metricCard(
                            icon: "waveform.path.ecg",
                            value: latestHRV.map { String(format: "%.0f", $0) } ?? "--",
                            unit: "ms",
                            color: .purple
                        )
                        
                        metricCard(
                            icon: "figure.walk",
                            value: "\(todaySteps)",
                            unit: "steps",
                            color: .green
                        )
                    }
                    
                    // Quick actions
                    Button {
                        // Trigger breathing session
                    } label: {
                        Label("Breathe", systemImage: "wind")
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                }
                .padding()
            }
            .navigationTitle("Longevity")
            .onAppear {
                requestHealthKitAuth()
            }
        }
    }
    
    private var readinessGauge: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: CGFloat(readinessScore) / 100)
                .stroke(
                    scoreColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: readinessScore)
            
            VStack(spacing: 2) {
                Text("\(readinessScore)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Ready")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 100, height: 100)
    }
    
    private func metricCard(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.headline)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(8)
    }
    
    private var scoreColor: Color {
        switch readinessScore {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    // MARK: - HealthKit
    
    private func requestHealthKitAuth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        var typesToRead = Set<HKObjectType>()
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            typesToRead.insert(hrv)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            typesToRead.insert(steps)
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            if success {
                fetchData()
            }
        }
    }
    
    private func fetchData() {
        fetchHRV()
        fetchSteps()
        
        // Simulate readiness score (in real app, sync from iPhone)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            readinessScore = 75 // Placeholder - would come from WatchConnectivity
        }
    }
    
    private func fetchHRV() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: hrvType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    latestHRV = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchSteps() {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, _ in
            DispatchQueue.main.async {
                todaySteps = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
        }
        healthStore.execute(query)
    }
}

#Preview {
    WatchContentView()
}
