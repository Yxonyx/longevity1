import SwiftUI

struct ReadinessScoreView: View {
    let score: ReadinessScore
    @State private var showingExplanation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main score ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                
                Circle()
                    .trim(from: 0, to: CGFloat(score.overallScore) / 100)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: score.overallScore)
                
                VStack(spacing: 4) {
                    Text("\(score.overallScore)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    
                    Text(scoreLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    // Confidence indicator
                    HStack(spacing: 4) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(Double(i) / 3.0 < score.confidence ? scoreColor : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(width: 200, height: 200)
            
            // Components breakdown
            HStack(spacing: 32) {
                componentView(label: "HRV", value: score.hrvScore, icon: "waveform.path.ecg")
                componentView(label: "Sleep", value: score.sleepScore, icon: "moon.fill")
                componentView(label: "Recovery", value: score.rhrScore, icon: "heart.fill")
            }
            
            // Explanation button
            Button {
                showingExplanation = true
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("How is this calculated?")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .sheet(isPresented: $showingExplanation) {
                ScoreExplanationSheet(score: score)
            }
        }
    }
    
    private func componentView(label: String, value: Int, icon: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(componentColor(value), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(componentColor(value))
            }
            
            Text("\(value)")
                .font(.headline)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var scoreColor: Color {
        switch score.overallScore {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    private func componentColor(_ value: Int) -> Color {
        switch value {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    private var gradientColors: [Color] {
        [
            scoreColor.opacity(0.7),
            scoreColor
        ]
    }
    
    private var scoreLabel: String {
        switch score.overallScore {
        case 0..<30: return "Recovery Needed"
        case 30..<50: return "Below Average"
        case 50..<70: return "Moderate"
        case 70..<85: return "Good"
        case 85..<95: return "Excellent"
        default: return "Peak"
        }
    }
}

// MARK: - Score Explanation Sheet

struct ScoreExplanationSheet: View {
    let score: ReadinessScore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Formula section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Formula")
                            .font(.headline)
                        
                        Text("Readiness = (0.35 × HRV) + (0.30 × Sleep) + (0.20 × RHR) + (0.15 × Subjective)")
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    // Components breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Components")
                            .font(.headline)
                        
                        componentRow("HRV Score", score.hrvScore, weight: 0.35, description: "Heart rate variability compared to your 7-day baseline")
                        componentRow("Sleep Score", score.sleepScore, weight: 0.30, description: "Sleep duration and quality relative to your target")
                        componentRow("RHR Score", score.rhrScore, weight: 0.20, description: "Resting heart rate compared to baseline (lower is better)")
                        
                        if let subjective = score.subjectiveScore {
                            componentRow("Subjective", subjective, weight: 0.15, description: "Your self-reported feeling this morning")
                        }
                    }
                    
                    // Factors
                    if !score.factors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contributing Factors")
                                .font(.headline)
                            
                            ForEach(score.factors) { factor in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: factor.impact > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                        .foregroundColor(factor.impact > 0 ? .green : .orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(factor.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(factor.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Confidence
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Confidence Level")
                            .font(.headline)
                        
                        HStack {
                            ProgressView(value: score.confidence)
                                .tint(confidenceColor)
                            
                            Text("\(Int(score.confidence * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text(confidenceExplanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Important", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text("This score is an estimate based on available data. It should not replace professional medical advice. Listen to your body and consult healthcare providers for health concerns.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Score Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func componentRow(_ name: String, _ value: Int, weight: Double, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .fontWeight(.semibold)
                Text("× \(String(format: "%.0f%%", weight * 100))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("= \(Int(Double(value) * weight))")
                    .font(.caption)
                    .foregroundColor(.teal)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(value) / 100)
                .tint(componentColor(value))
        }
        .padding(.vertical, 4)
    }
    
    private func componentColor(_ value: Int) -> Color {
        switch value {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    private var confidenceColor: Color {
        switch score.confidence {
        case 0..<0.4: return .red
        case 0.4..<0.7: return .orange
        default: return .green
        }
    }
    
    private var confidenceExplanation: String {
        switch score.confidence {
        case 0..<0.4: return "Limited data available. Score may be less accurate."
        case 0.4..<0.7: return "Moderate data available. Score is reasonably reliable."
        default: return "Good data coverage. Score is well-supported."
        }
    }
}

#Preview {
    ReadinessScoreView(score: ReadinessScore(
        overallScore: 78,
        hrvScore: 82,
        sleepScore: 75,
        rhrScore: 80,
        subjectiveScore: 70,
        confidence: 0.85,
        factors: [
            ScoreFactor(name: "HRV", impact: 0.3, description: "Your HRV is above your 7-day average"),
            ScoreFactor(name: "Sleep", impact: -0.1, description: "You slept 6.8 hours (target: 8)")
        ]
    ))
    .padding()
}
