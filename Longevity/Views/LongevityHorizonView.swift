import SwiftUI
import Charts

// MARK: - Longevity Projection Model

struct LongevityProjection: Identifiable, Codable {
    let id: UUID
    let generatedAt: Date
    let currentAge: Double
    let biologicalAge: Double
    let projectedHealthspan: Double // Years of healthy life remaining
    let projectedLifespan: Double // Total expected years
    let confidenceInterval: (low: Double, high: Double)
    let riskFactors: [RiskFactor]
    let trajectory: [TrajectoryPoint]
}

struct TrajectoryPoint: Identifiable, Codable {
    let id: UUID
    let age: Double
    let healthScore: Double // 0-100
    let lowerBound: Double // Uncertainty band
    let upperBound: Double
    
    init(age: Double, healthScore: Double, uncertainty: Double = 10) {
        self.id = UUID()
        self.age = age
        self.healthScore = healthScore
        self.lowerBound = max(0, healthScore - uncertainty)
        self.upperBound = min(100, healthScore + uncertainty)
    }
}

struct RiskFactor: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: RiskCategory
    let impactYears: Double // Years of life impact (negative = reduces)
    let modifiable: Bool
    let currentStatus: String // e.g., "Elevated", "Optimal"
    let recommendation: String?
}

enum RiskCategory: String, Codable, CaseIterable {
    case cardiovascular
    case metabolic
    case cognitive
    case musculoskeletal
    case immune
    
    var icon: String {
        switch self {
        case .cardiovascular: return "heart.fill"
        case .metabolic: return "flame.fill"
        case .cognitive: return "brain.head.profile"
        case .musculoskeletal: return "figure.walk"
        case .immune: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .cardiovascular: return .red
        case .metabolic: return .orange
        case .cognitive: return .purple
        case .musculoskeletal: return .green
        case .immune: return .blue
        }
    }
}

// MARK: - Longevity Calculator

class LongevityCalculator {
    
    func generateProjection(
        chronologicalAge: Double,
        biologicalAge: Double,
        biomarkers: [Biomarker],
        hrv: Double?,
        vo2max: Double?
    ) -> LongevityProjection {
        
        var riskFactors: [RiskFactor] = []
        var totalImpact: Double = 0
        
        // Base life expectancy (simplified - varies by population)
        let baseLifeExpectancy = 80.0
        let baseHealthspan = 68.0 // Average years without major disability
        
        // Biological age impact
        let ageDifference = biologicalAge - chronologicalAge
        totalImpact -= ageDifference * 0.8 // Each year younger/older ~ 0.8 years impact
        
        // Analyze biomarkers for risk factors
        let biomarkerDict = Dictionary(uniqueKeysWithValues: biomarkers.map { ($0.type, $0.value) })
        
        // Cardiovascular risks
        if let apoB = biomarkerDict[.apoB] {
            let impact = calculateApoBImpact(apoB)
            totalImpact += impact
            riskFactors.append(RiskFactor(
                id: UUID(),
                name: "ApoB / Lipids",
                category: .cardiovascular,
                impactYears: impact,
                modifiable: true,
                currentStatus: apoB < 90 ? "Optimal" : (apoB < 110 ? "Borderline" : "Elevated"),
                recommendation: impact < 0 ? "Consider discussing lipid management with your doctor" : nil
            ))
        }
        
        // Metabolic risks
        if let hba1c = biomarkerDict[.hba1c] {
            let impact = calculateHbA1cImpact(hba1c)
            totalImpact += impact
            riskFactors.append(RiskFactor(
                id: UUID(),
                name: "Glucose Control",
                category: .metabolic,
                impactYears: impact,
                modifiable: true,
                currentStatus: hba1c < 5.4 ? "Optimal" : (hba1c < 5.7 ? "Normal" : "Elevated"),
                recommendation: impact < 0 ? "Focus on diet and exercise for glucose optimization" : nil
            ))
        }
        
        // Inflammation
        if let crp = biomarkerDict[.crp] {
            let impact = calculateCRPImpact(crp)
            totalImpact += impact
            riskFactors.append(RiskFactor(
                id: UUID(),
                name: "Inflammation",
                category: .immune,
                impactYears: impact,
                modifiable: true,
                currentStatus: crp < 1 ? "Low" : (crp < 3 ? "Moderate" : "High"),
                recommendation: impact < 0 ? "Anti-inflammatory diet and stress reduction recommended" : nil
            ))
        }
        
        // Fitness (VO2max)
        if let vo2max = vo2max {
            let impact = calculateVO2MaxImpact(vo2max, age: chronologicalAge)
            totalImpact += impact
            riskFactors.append(RiskFactor(
                id: UUID(),
                name: "Cardiorespiratory Fitness",
                category: .cardiovascular,
                impactYears: impact,
                modifiable: true,
                currentStatus: impact > 0 ? "Above Average" : "Below Average",
                recommendation: impact < 0 ? "Increase Zone 2 training to improve VO2max" : nil
            ))
        }
        
        // HRV (stress/autonomic)
        if let hrv = hrv {
            let impact = calculateHRVImpact(hrv, age: chronologicalAge)
            totalImpact += impact
            riskFactors.append(RiskFactor(
                id: UUID(),
                name: "Autonomic Health (HRV)",
                category: .cognitive,
                impactYears: impact,
                modifiable: true,
                currentStatus: impact > 0 ? "Good" : "Needs Attention",
                recommendation: impact < 0 ? "Focus on sleep, stress management, and recovery" : nil
            ))
        }
        
        // Calculate projections
        let projectedLifespan = baseLifeExpectancy + totalImpact
        let projectedHealthspan = baseHealthspan + (totalImpact * 0.9) // Healthspan scales slightly less
        
        let uncertainty = 8.0 - min(4.0, Double(riskFactors.count) * 0.5) // Less uncertainty with more data
        
        // Generate trajectory
        let trajectory = generateTrajectory(
            currentAge: chronologicalAge,
            biologicalAge: biologicalAge,
            projectedHealthspan: projectedHealthspan,
            projectedLifespan: projectedLifespan
        )
        
        return LongevityProjection(
            id: UUID(),
            generatedAt: Date(),
            currentAge: chronologicalAge,
            biologicalAge: biologicalAge,
            projectedHealthspan: max(chronologicalAge + 10, projectedHealthspan),
            projectedLifespan: max(chronologicalAge + 15, projectedLifespan),
            confidenceInterval: (projectedLifespan - uncertainty, projectedLifespan + uncertainty),
            riskFactors: riskFactors.sorted { abs($0.impactYears) > abs($1.impactYears) },
            trajectory: trajectory
        )
    }
    
    private func generateTrajectory(
        currentAge: Double,
        biologicalAge: Double,
        projectedHealthspan: Double,
        projectedLifespan: Double
    ) -> [TrajectoryPoint] {
        var points: [TrajectoryPoint] = []
        
        let currentHealthScore = max(20, 100 - (biologicalAge - 20) * 1.5)
        
        // Generate points every 5 years
        var age = currentAge
        while age <= projectedLifespan + 5 {
            let yearsFromNow = age - currentAge
            let decay = pow(1.02, yearsFromNow) // Exponential health decline
            let healthScore = max(0, currentHealthScore / decay)
            
            // Increase uncertainty as we project further
            let uncertainty = 5 + yearsFromNow * 0.5
            
            points.append(TrajectoryPoint(age: age, healthScore: healthScore, uncertainty: uncertainty))
            age += 5
        }
        
        return points
    }
    
    // Impact calculations (simplified models)
    
    private func calculateApoBImpact(_ apoB: Double) -> Double {
        if apoB < 70 { return 2.0 }
        if apoB < 90 { return 1.0 }
        if apoB < 110 { return -1.0 }
        if apoB < 130 { return -2.0 }
        return -4.0
    }
    
    private func calculateHbA1cImpact(_ hba1c: Double) -> Double {
        if hba1c < 5.0 { return 1.5 }
        if hba1c < 5.4 { return 1.0 }
        if hba1c < 5.7 { return 0 }
        if hba1c < 6.5 { return -2.0 }
        return -5.0
    }
    
    private func calculateCRPImpact(_ crp: Double) -> Double {
        if crp < 0.5 { return 2.0 }
        if crp < 1.0 { return 1.0 }
        if crp < 3.0 { return -1.0 }
        return -3.0
    }
    
    private func calculateVO2MaxImpact(_ vo2max: Double, age: Double) -> Double {
        // Age-adjusted expectation
        let expected = 45 - (age - 30) * 0.4
        let difference = vo2max - expected
        return difference * 0.2 // Each ml/kg/min above expected ~ 0.2 years
    }
    
    private func calculateHRVImpact(_ hrv: Double, age: Double) -> Double {
        let expected = 50 - (age * 0.5)
        let difference = hrv - expected
        return difference * 0.1
    }
}

// MARK: - Longevity Horizon View

struct LongevityHorizonView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    @State private var projection: LongevityProjection?
    @State private var isCalculating = false
    @State private var showingDisclaimer = false
    @State private var hasAcceptedDisclaimer = false
    
    private let calculator = LongevityCalculator()
    
    var body: some View {
        NavigationStack {
            Group {
                if !hasAcceptedDisclaimer {
                    disclaimerView
                } else if let projection = projection {
                    projectionView(projection)
                } else {
                    loadingView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Longevity Horizon")
            .toolbar {
                if hasAcceptedDisclaimer {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingDisclaimer = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDisclaimer) {
                DisclaimerSheet()
            }
        }
    }
    
    // MARK: - Disclaimer
    
    private var disclaimerView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.teal)
            
            Text("Longevity Horizon")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Important Disclaimer")
                    .font(.headline)
                
                Text("""
                This visualization provides **statistical estimates** based on your current health markers. It is:
                
                • **Not a medical prediction** - Many factors affect longevity
                • **Highly uncertain** - Individual outcomes vary greatly  
                • **For motivation only** - To encourage healthy choices
                • **Not a diagnosis** - Consult your doctor for medical advice
                """)
                .font(.subheadline)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            
            Button {
                hasAcceptedDisclaimer = true
                Task { await generateProjection() }
            } label: {
                Text("I Understand - Show My Horizon")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Calculating your horizon...")
                .foregroundColor(.secondary)
        }
        .task {
            await generateProjection()
        }
    }
    
    // MARK: - Projection View
    
    private func projectionView(_ projection: LongevityProjection) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main horizon card
                horizonCard(projection)
                
                // Trajectory chart
                trajectoryChart(projection)
                
                // Risk factors
                riskFactorsSection(projection)
                
                // Actions
                actionsCard(projection)
            }
            .padding()
        }
    }
    
    private func horizonCard(_ projection: LongevityProjection) -> some View {
        VStack(spacing: 20) {
            Text("Your Projected Horizon")
                .font(.headline)
            
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(Int(projection.projectedHealthspan))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Healthspan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(Int(projection.projectedLifespan))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.teal)
                    Text("Lifespan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Confidence interval
            Text("Range: \(Int(projection.confidenceInterval.low)) - \(Int(projection.confidenceInterval.high)) years")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Years remaining
            let healthyYearsRemaining = projection.projectedHealthspan - projection.currentAge
            let totalYearsRemaining = projection.projectedLifespan - projection.currentAge
            
            HStack {
                VStack {
                    Text("\(Int(healthyYearsRemaining))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("healthy years ahead")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack {
                    Text("\(Int(totalYearsRemaining))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.teal)
                    Text("total years ahead")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 15, y: 5)
    }
    
    private func trajectoryChart(_ projection: LongevityProjection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Trajectory")
                .font(.headline)
            
            Chart {
                // Uncertainty band
                ForEach(projection.trajectory) { point in
                    AreaMark(
                        x: .value("Age", point.age),
                        yStart: .value("Lower", point.lowerBound),
                        yEnd: .value("Upper", point.upperBound)
                    )
                    .foregroundStyle(.teal.opacity(0.2))
                }
                
                // Main trajectory line
                ForEach(projection.trajectory) { point in
                    LineMark(
                        x: .value("Age", point.age),
                        y: .value("Health", point.healthScore)
                    )
                    .foregroundStyle(.teal)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                
                // Current age marker
                RuleMark(x: .value("Now", projection.currentAge))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top) {
                        Text("Now")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                
                // Healthspan marker
                RuleMark(x: .value("Healthspan", projection.projectedHealthspan))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let score = value.as(Double.self) {
                            Text("\(Int(score))")
                        }
                    }
                }
            }
            .frame(height: 200)
            
            HStack {
                Circle().fill(.orange).frame(width: 8, height: 8)
                Text("Current age")
                    .font(.caption)
                Spacer()
                Circle().fill(.teal).frame(width: 8, height: 8)
                Text("Projected health")
                    .font(.caption)
                Spacer()
                Rectangle().fill(.teal.opacity(0.2)).frame(width: 16, height: 8)
                Text("Uncertainty")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func riskFactorsSection(_ projection: LongevityProjection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Risk Factors")
                .font(.headline)
            
            ForEach(projection.riskFactors) { factor in
                HStack {
                    Image(systemName: factor.category.icon)
                        .foregroundColor(factor.category.color)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.name)
                            .font(.subheadline)
                        Text(factor.currentStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%+.1f years", factor.impactYears))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(factor.impactYears >= 0 ? .green : .red)
                        
                        if factor.modifiable {
                            Text("Modifiable")
                                .font(.caption2)
                                .foregroundColor(.teal)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            if projection.riskFactors.isEmpty {
                Text("Add more biomarkers for personalized risk analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func actionsCard(_ projection: LongevityProjection) -> some View {
        VStack(spacing: 16) {
            if let topRisk = projection.riskFactors.filter({ $0.impactYears < 0 && $0.modifiable }).first,
               let rec = topRisk.recommendation {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Top Priority", systemImage: "target")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text(rec)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            Button {
                Task { await generateProjection() }
            } label: {
                Label("Recalculate", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Text("Last updated: \(projection.generatedAt, style: .relative)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Generate Projection
    
    private func generateProjection() async {
        guard let birthDate = dataStore.preferences.birthDate else { return }
        
        isCalculating = true
        defer { isCalculating = false }
        
        let age = Double(Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 40)
        
        await healthKitManager.fetchBaselines()
        
        // Calculate biological age first
        let bioAgeCalc = BiologicalAgeCalculator()
        let bioAgeResult = bioAgeCalc.calculate(
            chronologicalAge: age,
            biomarkers: dataStore.biomarkers,
            hrv: healthKitManager.hrvBaseline,
            vo2max: nil,
            sleepQuality: nil,
            exerciseMinutesPerWeek: nil
        )
        
        projection = calculator.generateProjection(
            chronologicalAge: age,
            biologicalAge: bioAgeResult.biologicalAge,
            biomarkers: dataStore.biomarkers,
            hrv: healthKitManager.hrvBaseline,
            vo2max: nil
        )
    }
}

// MARK: - Disclaimer Sheet

struct DisclaimerSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("About Longevity Horizon")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Group {
                        Text("Statistical Model")
                            .font(.headline)
                        
                        Text("""
                        The Longevity Horizon uses a simplified statistical model based on published research linking biomarkers and lifestyle factors to longevity outcomes.
                        
                        Key inputs include:
                        • Biological age (PhenoAge algorithm)
                        • Cardiovascular markers (ApoB, lipids)
                        • Metabolic markers (HbA1c, glucose)
                        • Inflammation (hs-CRP)
                        • Fitness markers (VO2max, HRV)
                        """)
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Limitations")
                            .font(.headline)
                        
                        Text("""
                        • Population-based estimates may not reflect individual outcomes
                        • Many genetic and environmental factors not captured
                        • Projections assume current health trajectory continues
                        • Uncertainty increases significantly over time
                        • Not validated for diagnostic or clinical use
                        """)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Not Medical Advice", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("This feature is for educational and motivational purposes only. Always consult healthcare professionals for medical decisions.")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Disclaimer")
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
    LongevityHorizonView()
        .environmentObject(DataStore())
        .environmentObject(HealthKitManager())
}
