import SwiftUI

struct BiologicalAgeView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    @State private var result: BiologicalAgeResult?
    @State private var isCalculating = false
    @State private var showingExplanation = false
    
    private let calculator = BiologicalAgeCalculator()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Main age comparison
                    if let result = result {
                        ageComparisonCard(result: result)
                        contributorsSection(result: result)
                        confidenceCard(result: result)
                        actionsCard(result: result)
                    } else {
                        emptyStateCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Biological Age")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExplanation = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExplanation) {
                BiologicalAgeExplanationSheet()
            }
            .task {
                await calculateAge()
            }
        }
    }
    
    // MARK: - Age Comparison Card
    
    private func ageComparisonCard(result: BiologicalAgeResult) -> some View {
        VStack(spacing: 20) {
            // Visual age comparison
            HStack(spacing: 32) {
                // Chronological age
                VStack(spacing: 8) {
                    Text("Chronological")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(result.chronologicalAge))")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                    
                    Text("years")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Arrow
                VStack {
                    Image(systemName: differenceIcon(for: result.ageDifference))
                        .font(.title)
                        .foregroundColor(differenceColor(for: result.ageDifference))
                    
                    Text(differenceText(for: result.ageDifference))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Biological age
                VStack(spacing: 8) {
                    Text("Biological")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(result.biologicalAge))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(differenceColor(for: result.ageDifference))
                    
                    Text("years")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status badge
            Text(result.ageLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(differenceColor(for: result.ageDifference).opacity(0.15))
                .foregroundColor(differenceColor(for: result.ageDifference))
                .cornerRadius(20)
            
            // Algorithm info
            HStack {
                Image(systemName: "function")
                    .font(.caption)
                Text(result.algorithm.rawValue)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 15, y: 5)
    }
    
    // MARK: - Contributors Section
    
    private func contributorsSection(result: BiologicalAgeResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contributing Factors")
                .font(.headline)
            
            if result.contributors.isEmpty {
                Text("Add more biomarkers for detailed factor analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(result.contributors) { contributor in
                    contributorRow(contributor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func contributorRow(_ contributor: AgeContributor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Category icon
                Image(systemName: categoryIcon(for: contributor.category))
                    .foregroundColor(categoryColor(for: contributor.category))
                    .frame(width: 24)
                
                Text(contributor.name)
                    .font(.subheadline)
                
                Spacer()
                
                // Impact
                HStack(spacing: 4) {
                    Image(systemName: contributor.impact < 0 ? "arrow.down" : "arrow.up")
                        .font(.caption)
                    Text(String(format: "%.1f years", abs(contributor.impact)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(contributor.impact < 0 ? .green : .red)
            }
            
            // Recommendation if any
            if let rec = contributor.recommendation {
                Text(rec)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Confidence Card
    
    private func confidenceCard(result: BiologicalAgeResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Confidence")
                    .font(.headline)
                Spacer()
                Text("\(Int(result.confidence * 100))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(confidenceColor(for: result.confidence))
            }
            
            ProgressView(value: result.confidence)
                .tint(confidenceColor(for: result.confidence))
            
            Text(confidenceDescription(for: result.confidence))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Actions Card
    
    private func actionsCard(result: BiologicalAgeResult) -> some View {
        VStack(spacing: 16) {
            // Recommendations
            if let topContributor = result.contributors.filter({ $0.impact > 0 }).first,
               let rec = topContributor.recommendation {
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
            
            // Recalculate button
            Button {
                Task { await calculateAge() }
            } label: {
                Label("Recalculate", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Text("Last calculated: \(result.calculationDate, style: .relative)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Empty State
    
    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.teal)
            
            Text("Calculate Your Biological Age")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We'll analyze your biomarkers, HRV, VO2 max, and lifestyle data to estimate your biological age.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if isCalculating {
                ProgressView("Analyzing...")
            } else {
                Button {
                    Task { await calculateAge() }
                } label: {
                    Label("Calculate Now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            // Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("For best results, add:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                requirementRow("HbA1c", available: hasBiomarker(.hba1c))
                requirementRow("hs-CRP", available: hasBiomarker(.crp))
                requirementRow("Vitamin D", available: hasBiomarker(.vitaminD))
                requirementRow("LDL/ApoB", available: hasBiomarker(.ldlCholesterol) || hasBiomarker(.apoB))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }
    
    private func requirementRow(_ name: String, available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "circle")
                .foregroundColor(available ? .green : .gray)
                .font(.caption)
            Text(name)
                .font(.caption)
                .foregroundColor(available ? .primary : .secondary)
        }
    }
    
    // MARK: - Calculation
    
    private func calculateAge() async {
        guard let birthDate = dataStore.preferences.birthDate else {
            // No birth date set
            return
        }
        
        isCalculating = true
        defer { isCalculating = false }
        
        let chronologicalAge = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        
        // Fetch latest HRV and VO2max from HealthKit
        await healthKitManager.fetchBaselines()
        
        let hrv = healthKitManager.hrvBaseline
        let vo2max: Double? = nil // Would come from HealthKit
        let sleepQuality: Double? = nil // Would come from ReadinessScore
        let exerciseMinutes: Int? = nil // Would come from HealthKit workouts
        
        result = calculator.calculate(
            chronologicalAge: Double(chronologicalAge),
            biomarkers: dataStore.biomarkers,
            hrv: hrv,
            vo2max: vo2max,
            sleepQuality: sleepQuality,
            exerciseMinutesPerWeek: exerciseMinutes
        )
    }
    
    // MARK: - Helpers
    
    private func hasBiomarker(_ type: BiomarkerType) -> Bool {
        dataStore.biomarkers.contains { $0.type == type }
    }
    
    private func differenceIcon(for diff: Double) -> String {
        if diff < -2 { return "arrow.left" }
        if diff > 2 { return "arrow.right" }
        return "equal"
    }
    
    private func differenceColor(for diff: Double) -> Color {
        if diff < -2 { return .green }
        if diff > 2 { return .red }
        return .orange
    }
    
    private func differenceText(for diff: Double) -> String {
        if abs(diff) < 1 { return "≈ same" }
        return String(format: "%.1f years", abs(diff))
    }
    
    private func categoryIcon(for category: AgeContributor.ContributorCategory) -> String {
        switch category {
        case .biomarker: return "drop.fill"
        case .lifestyle: return "heart.fill"
        case .fitness: return "figure.run"
        case .nutrition: return "leaf.fill"
        }
    }
    
    private func categoryColor(for category: AgeContributor.ContributorCategory) -> Color {
        switch category {
        case .biomarker: return .purple
        case .lifestyle: return .pink
        case .fitness: return .green
        case .nutrition: return .orange
        }
    }
    
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .orange }
        return .red
    }
    
    private func confidenceDescription(for confidence: Double) -> String {
        if confidence >= 0.8 { return "High confidence - sufficient biomarker data available" }
        if confidence >= 0.5 { return "Moderate confidence - add more biomarkers to improve accuracy" }
        return "Low confidence - limited data available"
    }
}

// MARK: - Explanation Sheet

struct BiologicalAgeExplanationSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What is Biological Age?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("""
                    Biological age represents the age of your body based on physiological markers, as opposed to your chronological age (years since birth).
                    
                    Someone who is 50 chronologically might have the biological age of a 40-year-old if they've maintained excellent health markers, or might have the biological age of a 60-year-old if their markers indicate accelerated aging.
                    """)
                    
                    Divider()
                    
                    Text("How We Calculate It")
                        .font(.headline)
                    
                    Text("""
                    **PhenoAge Algorithm**: When you have complete blood panel data (albumin, creatinine, glucose, CRP, lymphocytes, etc.), we use the validated PhenoAge algorithm from Levine et al. (2018).
                    
                    **Simplified Model**: Otherwise, we use a multi-factor model considering:
                    • Key biomarkers (HbA1c, hs-CRP, lipids, vitamin D)
                    • Heart rate variability (HRV)
                    • VO2 max
                    • Sleep quality
                    • Exercise habits
                    """)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Important", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("""
                        Biological age is an **estimate** with inherent uncertainty. It:
                        • Provides general insights, not precise measurements
                        • Should not replace medical evaluation
                        • May vary between calculation methods
                        • Is best used to track trends over time
                        """)
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("About Biological Age")
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
    BiologicalAgeView()
        .environmentObject(DataStore())
        .environmentObject(HealthKitManager())
}
