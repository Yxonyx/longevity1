import Foundation

// MARK: - Experiment Models

struct Experiment: Identifiable, Codable {
    let id: UUID
    var name: String
    var hypothesis: String
    var intervention: Intervention
    var metrics: [TrackedMetric]
    var design: ExperimentDesign
    var status: ExperimentStatus
    var phases: [ExperimentPhase]
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        hypothesis: String,
        intervention: Intervention,
        metrics: [TrackedMetric],
        design: ExperimentDesign = .abab,
        status: ExperimentStatus = .draft
    ) {
        self.id = id
        self.name = name
        self.hypothesis = hypothesis
        self.intervention = intervention
        self.metrics = metrics
        self.design = design
        self.status = status
        self.createdAt = Date()
        self.phases = []
    }
}

enum ExperimentStatus: String, Codable {
    case draft
    case baseline
    case intervention
    case washout
    case analysis
    case completed
    case cancelled
    
    var label: String {
        switch self {
        case .draft: return "Draft"
        case .baseline: return "Baseline"
        case .intervention: return "Intervention"
        case .washout: return "Washout"
        case .analysis: return "Analysis"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .baseline: return "blue"
        case .intervention: return "green"
        case .washout: return "orange"
        case .analysis: return "purple"
        case .completed: return "teal"
        case .cancelled: return "red"
        }
    }
}

enum ExperimentDesign: String, Codable, CaseIterable {
    case ab = "A-B" // Simple baseline → intervention
    case abab = "A-B-A-B" // Baseline → intervention → washout → repeat
    case aba = "A-B-A" // Reversal design
    case crossover = "Crossover" // Alternating periods
    
    var description: String {
        switch self {
        case .ab: return "Simple comparison of baseline vs intervention"
        case .abab: return "Repeated baseline-intervention with washout periods"
        case .aba: return "Baseline → Intervention → Return to baseline"
        case .crossover: return "Alternating intervention/control periods"
        }
    }
    
    var phasesTemplate: [PhaseType] {
        switch self {
        case .ab: return [.baseline, .intervention]
        case .abab: return [.baseline, .intervention, .washout, .intervention]
        case .aba: return [.baseline, .intervention, .baseline]
        case .crossover: return [.baseline, .intervention, .washout, .control, .washout, .intervention]
        }
    }
}

struct ExperimentPhase: Identifiable, Codable {
    let id: UUID
    let type: PhaseType
    var durationDays: Int
    var startDate: Date?
    var endDate: Date?
    var dataPoints: [DataPoint]
    var isComplete: Bool
    
    init(type: PhaseType, durationDays: Int = 7) {
        self.id = UUID()
        self.type = type
        self.durationDays = durationDays
        self.dataPoints = []
        self.isComplete = false
    }
}

enum PhaseType: String, Codable {
    case baseline
    case intervention
    case washout
    case control
    
    var icon: String {
        switch self {
        case .baseline: return "chart.line.flattrend.xyaxis"
        case .intervention: return "bolt.fill"
        case .washout: return "drop.fill"
        case .control: return "minus.circle.fill"
        }
    }
}

// MARK: - Intervention

struct Intervention: Codable {
    var name: String
    var category: InterventionCategory
    var description: String
    var dosage: String? // e.g., "500mg 2x daily"
    var timing: String? // e.g., "Morning with food"
    var expectedEffect: String
    
    init(
        name: String,
        category: InterventionCategory,
        description: String = "",
        dosage: String? = nil,
        timing: String? = nil,
        expectedEffect: String = ""
    ) {
        self.name = name
        self.category = category
        self.description = description
        self.dosage = dosage
        self.timing = timing
        self.expectedEffect = expectedEffect
    }
}

enum InterventionCategory: String, Codable, CaseIterable {
    case supplement
    case diet
    case exercise
    case sleep
    case stress
    case cold // Cold exposure
    case heat // Sauna
    case fasting
    case other
    
    var icon: String {
        switch self {
        case .supplement: return "pills.fill"
        case .diet: return "fork.knife"
        case .exercise: return "figure.run"
        case .sleep: return "moon.fill"
        case .stress: return "brain.head.profile"
        case .cold: return "snowflake"
        case .heat: return "flame.fill"
        case .fasting: return "timer"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Tracked Metrics

struct TrackedMetric: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ExperimentMetricType
    var source: MetricSource
    var unit: String
    var higherIsBetter: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        type: ExperimentMetricType,
        source: MetricSource = .healthKit,
        unit: String,
        higherIsBetter: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.source = source
        self.unit = unit
        self.higherIsBetter = higherIsBetter
    }
}

enum ExperimentMetricType: String, Codable {
    case hrv
    case restingHR
    case sleepScore
    case sleepDuration
    case glucose
    case weight
    case energy // Subjective 1-10
    case mood // Subjective 1-10
    case focus // Subjective 1-10
    case custom
}

enum MetricSource: String, Codable {
    case healthKit
    case manual
    case cgm
    case survey
}

struct DataPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let metricId: UUID
    let value: Double
    let notes: String?
    
    init(metricId: UUID, value: Double, notes: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.metricId = metricId
        self.value = value
        self.notes = notes
    }
}

// MARK: - Experiment Results

struct ExperimentResults: Codable {
    let experimentId: UUID
    var metricAnalyses: [MetricAnalysis]
    var overallConclusion: Conclusion
    var confidenceLevel: Double // 0-1
    var confounders: [String]
    var generatedAt: Date
}

struct MetricAnalysis: Identifiable, Codable {
    let id: UUID
    let metricId: UUID
    let metricName: String
    var baselineMean: Double
    var baselineStdDev: Double
    var interventionMean: Double
    var interventionStdDev: Double
    var effectSize: Double // Cohen's d
    var percentChange: Double
    var pValue: Double?
    var isSignificant: Bool
    var trend: EffectTrend
}

enum EffectTrend: String, Codable {
    case improved
    case worsened
    case noChange
    case inconclusive
    
    var icon: String {
        switch self {
        case .improved: return "arrow.up.circle.fill"
        case .worsened: return "arrow.down.circle.fill"
        case .noChange: return "equal.circle.fill"
        case .inconclusive: return "questionmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .improved: return "green"
        case .worsened: return "red"
        case .noChange: return "gray"
        case .inconclusive: return "orange"
        }
    }
}

enum Conclusion: String, Codable {
    case beneficial
    case harmful
    case neutral
    case inconclusive
    
    var label: String {
        switch self {
        case .beneficial: return "Intervention appears beneficial"
        case .harmful: return "Intervention may be harmful"
        case .neutral: return "No significant effect detected"
        case .inconclusive: return "Results inconclusive"
        }
    }
}

// MARK: - Experiment Engine

@MainActor
class ExperimentEngine: ObservableObject {
    @Published var experiments: [Experiment] = []
    @Published var activeExperiment: Experiment?
    @Published var latestResults: ExperimentResults?
    
    private let experimentsKey = "longevity_experiments"
    
    init() {
        loadExperiments()
    }
    
    // MARK: - Experiment Lifecycle
    
    func createExperiment(
        name: String,
        hypothesis: String,
        intervention: Intervention,
        metrics: [TrackedMetric],
        design: ExperimentDesign,
        phaseDurationDays: Int = 7
    ) -> Experiment {
        var experiment = Experiment(
            name: name,
            hypothesis: hypothesis,
            intervention: intervention,
            metrics: metrics,
            design: design
        )
        
        // Generate phases from design template
        experiment.phases = design.phasesTemplate.map { phaseType in
            ExperimentPhase(type: phaseType, durationDays: phaseDurationDays)
        }
        
        experiments.append(experiment)
        saveExperiments()
        return experiment
    }
    
    func startExperiment(_ id: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == id }) else { return }
        
        experiments[index].status = .baseline
        experiments[index].startedAt = Date()
        
        // Start first phase
        if !experiments[index].phases.isEmpty {
            experiments[index].phases[0].startDate = Date()
        }
        
        activeExperiment = experiments[index]
        saveExperiments()
    }
    
    func advancePhase(_ experimentId: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == experimentId }) else { return }
        
        var experiment = experiments[index]
        
        // Find current phase and mark complete
        if let currentPhaseIndex = experiment.phases.firstIndex(where: { !$0.isComplete }) {
            experiment.phases[currentPhaseIndex].isComplete = true
            experiment.phases[currentPhaseIndex].endDate = Date()
            
            // Start next phase if exists
            let nextIndex = currentPhaseIndex + 1
            if nextIndex < experiment.phases.count {
                experiment.phases[nextIndex].startDate = Date()
                experiment.status = phaseToStatus(experiment.phases[nextIndex].type)
            } else {
                // All phases complete
                experiment.status = .analysis
            }
        }
        
        experiments[index] = experiment
        if experiment.id == activeExperiment?.id {
            activeExperiment = experiment
        }
        saveExperiments()
    }
    
    func recordDataPoint(experimentId: UUID, metricId: UUID, value: Double, notes: String? = nil) {
        guard let expIndex = experiments.firstIndex(where: { $0.id == experimentId }),
              let phaseIndex = experiments[expIndex].phases.firstIndex(where: { !$0.isComplete }) else { return }
        
        let dataPoint = DataPoint(metricId: metricId, value: value, notes: notes)
        experiments[expIndex].phases[phaseIndex].dataPoints.append(dataPoint)
        
        if experiments[expIndex].id == activeExperiment?.id {
            activeExperiment = experiments[expIndex]
        }
        saveExperiments()
    }
    
    func completeExperiment(_ experimentId: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == experimentId }) else { return }
        
        // Analyze results
        latestResults = analyzeExperiment(experiments[index])
        
        experiments[index].status = .completed
        experiments[index].completedAt = Date()
        
        if experiments[index].id == activeExperiment?.id {
            activeExperiment = nil
        }
        saveExperiments()
    }
    
    func cancelExperiment(_ experimentId: UUID) {
        guard let index = experiments.firstIndex(where: { $0.id == experimentId }) else { return }
        
        experiments[index].status = .cancelled
        
        if experiments[index].id == activeExperiment?.id {
            activeExperiment = nil
        }
        saveExperiments()
    }
    
    // MARK: - Analysis
    
    func analyzeExperiment(_ experiment: Experiment) -> ExperimentResults {
        var metricAnalyses: [MetricAnalysis] = []
        
        let baselinePhases = experiment.phases.filter { $0.type == .baseline }
        let interventionPhases = experiment.phases.filter { $0.type == .intervention }
        
        for metric in experiment.metrics {
            // Collect baseline data points
            let baselineValues = baselinePhases.flatMap { phase in
                phase.dataPoints.filter { $0.metricId == metric.id }.map { $0.value }
            }
            
            // Collect intervention data points
            let interventionValues = interventionPhases.flatMap { phase in
                phase.dataPoints.filter { $0.metricId == metric.id }.map { $0.value }
            }
            
            let analysis = calculateMetricAnalysis(
                metricId: metric.id,
                metricName: metric.name,
                baselineValues: baselineValues,
                interventionValues: interventionValues,
                higherIsBetter: metric.higherIsBetter
            )
            metricAnalyses.append(analysis)
        }
        
        // Determine overall conclusion
        let significantImprovements = metricAnalyses.filter { $0.isSignificant && $0.trend == .improved }.count
        let significantWorsenings = metricAnalyses.filter { $0.isSignificant && $0.trend == .worsened }.count
        
        let conclusion: Conclusion
        let confidence: Double
        
        if significantImprovements > significantWorsenings && significantImprovements > 0 {
            conclusion = .beneficial
            confidence = 0.7 + Double(significantImprovements) * 0.05
        } else if significantWorsenings > significantImprovements && significantWorsenings > 0 {
            conclusion = .harmful
            confidence = 0.6 + Double(significantWorsenings) * 0.05
        } else if metricAnalyses.allSatisfy({ !$0.isSignificant }) {
            conclusion = .neutral
            confidence = 0.5
        } else {
            conclusion = .inconclusive
            confidence = 0.3
        }
        
        return ExperimentResults(
            experimentId: experiment.id,
            metricAnalyses: metricAnalyses,
            overallConclusion: conclusion,
            confidenceLevel: min(0.95, confidence),
            confounders: detectConfounders(experiment),
            generatedAt: Date()
        )
    }
    
    private func calculateMetricAnalysis(
        metricId: UUID,
        metricName: String,
        baselineValues: [Double],
        interventionValues: [Double],
        higherIsBetter: Bool
    ) -> MetricAnalysis {
        let baselineMean = baselineValues.isEmpty ? 0 : baselineValues.reduce(0, +) / Double(baselineValues.count)
        let interventionMean = interventionValues.isEmpty ? 0 : interventionValues.reduce(0, +) / Double(interventionValues.count)
        
        let baselineStdDev = standardDeviation(baselineValues)
        let interventionStdDev = standardDeviation(interventionValues)
        
        let pooledStdDev = sqrt((baselineStdDev * baselineStdDev + interventionStdDev * interventionStdDev) / 2)
        let effectSize = pooledStdDev > 0 ? (interventionMean - baselineMean) / pooledStdDev : 0
        
        let percentChange = baselineMean > 0 ? ((interventionMean - baselineMean) / baselineMean) * 100 : 0
        
        // Simple significance test (would use proper t-test in production)
        let isSignificant = abs(effectSize) > 0.5 && baselineValues.count >= 5 && interventionValues.count >= 5
        
        let trend: EffectTrend
        if !isSignificant || baselineValues.count < 5 || interventionValues.count < 5 {
            trend = .inconclusive
        } else if (effectSize > 0 && higherIsBetter) || (effectSize < 0 && !higherIsBetter) {
            trend = .improved
        } else if (effectSize < 0 && higherIsBetter) || (effectSize > 0 && !higherIsBetter) {
            trend = .worsened
        } else {
            trend = .noChange
        }
        
        return MetricAnalysis(
            id: UUID(),
            metricId: metricId,
            metricName: metricName,
            baselineMean: baselineMean,
            baselineStdDev: baselineStdDev,
            interventionMean: interventionMean,
            interventionStdDev: interventionStdDev,
            effectSize: effectSize,
            percentChange: percentChange,
            pValue: nil, // Would calculate with proper stats
            isSignificant: isSignificant,
            trend: trend
        )
    }
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }
    
    private func detectConfounders(_ experiment: Experiment) -> [String] {
        var confounders: [String] = []
        
        // Check for short phases
        if experiment.phases.contains(where: { $0.durationDays < 7 }) {
            confounders.append("Short phase duration may limit data reliability")
        }
        
        // Check for low data points
        let totalDataPoints = experiment.phases.flatMap { $0.dataPoints }.count
        if totalDataPoints < experiment.metrics.count * experiment.phases.count * 5 {
            confounders.append("Limited data points - results may not be representative")
        }
        
        // Check for missing washout in ABAB
        if experiment.design == .abab && !experiment.phases.contains(where: { $0.type == .washout }) {
            confounders.append("Missing washout period may cause carryover effects")
        }
        
        return confounders
    }
    
    private func phaseToStatus(_ phaseType: PhaseType) -> ExperimentStatus {
        switch phaseType {
        case .baseline: return .baseline
        case .intervention: return .intervention
        case .washout: return .washout
        case .control: return .baseline
        }
    }
    
    // MARK: - Persistence
    
    private func loadExperiments() {
        if let data = UserDefaults.standard.data(forKey: experimentsKey),
           let decoded = try? JSONDecoder().decode([Experiment].self, from: data) {
            experiments = decoded
            activeExperiment = experiments.first { $0.status != .completed && $0.status != .cancelled && $0.status != .draft }
        }
    }
    
    private func saveExperiments() {
        if let data = try? JSONEncoder().encode(experiments) {
            UserDefaults.standard.set(data, forKey: experimentsKey)
        }
    }
    
    // MARK: - Experiment Templates
    
    static let templates: [(name: String, intervention: Intervention, metrics: [TrackedMetric])] = [
        (
            name: "Creatine & HRV",
            intervention: Intervention(
                name: "Creatine Monohydrate",
                category: .supplement,
                dosage: "5g daily",
                timing: "Morning",
                expectedEffect: "Improved HRV and recovery"
            ),
            metrics: [
                TrackedMetric(name: "HRV", type: .hrv, unit: "ms", higherIsBetter: true),
                TrackedMetric(name: "Energy", type: .energy, source: .survey, unit: "/10", higherIsBetter: true)
            ]
        ),
        (
            name: "Cold Exposure & Sleep",
            intervention: Intervention(
                name: "Cold Shower",
                category: .cold,
                dosage: "2-3 min cold finish",
                timing: "Morning",
                expectedEffect: "Improved sleep quality"
            ),
            metrics: [
                TrackedMetric(name: "Sleep Score", type: .sleepScore, unit: "/100", higherIsBetter: true),
                TrackedMetric(name: "Resting HR", type: .restingHR, unit: "bpm", higherIsBetter: false)
            ]
        ),
        (
            name: "Intermittent Fasting & Glucose",
            intervention: Intervention(
                name: "16:8 Intermittent Fasting",
                category: .fasting,
                dosage: "16hr fast / 8hr eating window",
                timing: "Eating 12pm-8pm",
                expectedEffect: "Improved glucose variability"
            ),
            metrics: [
                TrackedMetric(name: "Fasting Glucose", type: .glucose, source: .cgm, unit: "mg/dL", higherIsBetter: false),
                TrackedMetric(name: "Energy", type: .energy, source: .survey, unit: "/10", higherIsBetter: true)
            ]
        )
    ]
}
