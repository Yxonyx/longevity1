import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var scoringEngine = ScoringEngine()
    
    @State private var subjectiveFeel: Int = 3
    @State private var showingCheckIn = false
    
    private var todayScore: ReadinessScore? {
        dataStore.getReadinessScore(for: Date())
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with greeting
                    headerSection
                    
                    // Readiness Score Card
                    readinessCard
                    
                    // Quick Metrics Grid
                    metricsGrid
                    
                    // Today's Focus
                    todaysFocus
                    
                    // Recent Trends
                    trendsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Longevity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        healthKitManager.fetchAllData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                MorningCheckInSheet(subjectiveFeel: $subjectiveFeel) {
                    calculateAndSaveScore()
                    showingCheckIn = false
                }
            }
            .onAppear {
                if todayScore == nil {
                    showingCheckIn = true
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 17 { return "Good afternoon" }
        else { return "Good evening" }
    }
    
    // MARK: - Readiness Card
    
    private var readinessCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Readiness")
                    .font(.headline)
                Spacer()
                if let score = todayScore {
                    confidenceBadge(confidence: score.confidence)
                }
            }
            
            if let score = todayScore {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(score.overallScore) / 100)
                        .stroke(
                            scoreColor(score.overallScore),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: score.overallScore)
                    
                    VStack(spacing: 4) {
                        Text("\(score.overallScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("of 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 160, height: 160)
                
                // Score breakdown
                HStack(spacing: 24) {
                    scoreComponent(label: "HRV", value: score.hrvScore, icon: "waveform.path.ecg")
                    scoreComponent(label: "Sleep", value: score.sleepScore, icon: "bed.double.fill")
                    scoreComponent(label: "RHR", value: score.rhrScore, icon: "heart.fill")
                }
                
                // Factors
                if !score.factors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(score.factors) { factor in
                            factorRow(factor)
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                Button {
                    showingCheckIn = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.wave.fill")
                            .font(.largeTitle)
                        Text("Complete morning check-in")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func scoreComponent(label: String, value: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(scoreColor(value))
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func factorRow(_ factor: ScoreFactor) -> some View {
        HStack(spacing: 8) {
            Image(systemName: factor.impact > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(factor.impact > 0 ? .green : .orange)
                .font(.caption)
            Text(factor.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(
                title: "HRV",
                value: healthKitManager.latestHRV.map { String(format: "%.0f ms", $0) } ?? "--",
                icon: "waveform.path.ecg",
                color: .purple
            )
            
            metricCard(
                title: "Resting HR",
                value: healthKitManager.latestRestingHR.map { String(format: "%.0f bpm", $0) } ?? "--",
                icon: "heart.fill",
                color: .red
            )
            
            metricCard(
                title: "Sleep",
                value: healthKitManager.latestSleepHours.map { String(format: "%.1f hrs", $0) } ?? "--",
                icon: "bed.double.fill",
                color: .indigo
            )
            
            metricCard(
                title: "Steps",
                value: "\(healthKitManager.todaySteps)",
                icon: "figure.walk",
                color: .green
            )
            
            metricCard(
                title: "VO2 Max",
                value: healthKitManager.latestVO2Max.map { String(format: "%.1f", $0) } ?? "--",
                icon: "lungs.fill",
                color: .teal
            )
            
            metricCard(
                title: "Target Steps",
                value: "\(Int((Double(healthKitManager.todaySteps) / Double(dataStore.preferences.targetSteps)) * 100))%",
                icon: "target",
                color: .orange
            )
        }
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Today's Focus
    
    private var todaysFocus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Focus")
                .font(.headline)
            
            if let score = todayScore {
                if score.overallScore < 60 {
                    focusItem(icon: "moon.fill", text: "Recovery day - prioritize rest", color: .indigo)
                    focusItem(icon: "drop.fill", text: "Stay hydrated", color: .blue)
                } else if score.overallScore < 80 {
                    focusItem(icon: "figure.walk", text: "Light activity recommended", color: .green)
                    focusItem(icon: "heart.fill", text: "Zone 2 cardio optimal", color: .teal)
                } else {
                    focusItem(icon: "flame.fill", text: "High intensity training ready", color: .orange)
                    focusItem(icon: "bolt.fill", text: "Peak performance day", color: .yellow)
                }
            }
            
            // Supplement reminders
            let activeSupplements = dataStore.supplements.filter { $0.isActive }
            if !activeSupplements.isEmpty {
                focusItem(
                    icon: "pills.fill",
                    text: "Supplements due: \(activeSupplements.prefix(2).map { $0.name }.joined(separator: ", "))",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func focusItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    // MARK: - Trends
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trends")
                .font(.headline)
            
            let recentScores = dataStore.getRecentReadinessScores(days: 7)
            if recentScores.count >= 2 {
                HStack(spacing: 4) {
                    ForEach(recentScores.reversed()) { score in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor(score.overallScore))
                            .frame(height: CGFloat(score.overallScore) * 0.6)
                    }
                }
                .frame(height: 60)
            } else {
                Text("Not enough data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    private func confidenceBadge(confidence: Double) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidence > 0.7 ? Color.green : confidence > 0.4 ? Color.orange : Color.red)
                .frame(width: 6, height: 6)
            Text(confidence > 0.7 ? "High" : confidence > 0.4 ? "Medium" : "Low")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func calculateAndSaveScore() {
        let score = scoringEngine.calculateReadinessScore(
            currentHRV: healthKitManager.latestHRV,
            baselineHRV: healthKitManager.hrvBaseline7Day,
            sleepHours: healthKitManager.latestSleepHours,
            targetSleepHours: dataStore.preferences.targetSleepHours,
            currentRHR: healthKitManager.latestRestingHR,
            baselineRHR: healthKitManager.rhrBaseline7Day,
            subjectiveScore: subjectiveFeel
        )
        dataStore.saveReadinessScore(score)
    }
}

// MARK: - Morning Check-In Sheet

struct MorningCheckInSheet: View {
    @Binding var subjectiveFeel: Int
    var onComplete: () -> Void
    
    let feelings = ["😴", "😟", "😐", "😊", "🔥"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("How do you feel this morning?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 20) {
                    ForEach(1...5, id: \.self) { i in
                        Button {
                            subjectiveFeel = i
                        } label: {
                            Text(feelings[i - 1])
                                .font(.system(size: 44))
                                .opacity(subjectiveFeel == i ? 1.0 : 0.4)
                                .scaleEffect(subjectiveFeel == i ? 1.2 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(feelingDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    onComplete()
                } label: {
                    Text("Calculate Readiness")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Morning Check-In")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
    
    private var feelingDescription: String {
        switch subjectiveFeel {
        case 1: return "Exhausted - need recovery"
        case 2: return "Tired - take it easy"
        case 3: return "Normal - steady day"
        case 4: return "Good - ready for activity"
        case 5: return "Excellent - peak performance"
        default: return ""
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(HealthKitManager())
        .environmentObject(DataStore())
}
