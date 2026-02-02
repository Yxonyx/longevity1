import SwiftUI

struct ExperimentView: View {
    @StateObject private var engine = ExperimentEngine()
    @State private var showingNewExperiment = false
    @State private var selectedExperiment: Experiment?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active experiment card
                    if let active = engine.activeExperiment {
                        activeExperimentCard(active)
                    }
                    
                    // Quick templates
                    if engine.activeExperiment == nil {
                        templatesSection
                    }
                    
                    // Past experiments
                    pastExperimentsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Experiments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewExperiment = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewExperiment) {
                NewExperimentSheet(engine: engine)
            }
            .sheet(item: $selectedExperiment) { experiment in
                ExperimentDetailSheet(experiment: experiment, engine: engine)
            }
        }
    }
    
    // MARK: - Active Experiment
    
    private func activeExperimentCard(_ experiment: Experiment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(experiment.name)
                        .font(.headline)
                    Text(experiment.intervention.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge(experiment.status)
            }
            
            // Phase progress
            phaseProgressView(experiment)
            
            // Current phase info
            if let currentPhase = experiment.phases.first(where: { !$0.isComplete }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: currentPhase.type.icon)
                            .foregroundColor(.teal)
                        Text("Current: \(currentPhase.type.rawValue.capitalized)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if let startDate = currentPhase.startDate {
                        let daysRemaining = currentPhase.durationDays - Calendar.current.dateComponents([.day], from: startDate, to: Date()).day!
                        Text("\(max(0, daysRemaining)) days remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.teal.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Data entry
            HStack(spacing: 12) {
                Button {
                    selectedExperiment = experiment
                } label: {
                    Label("Log Data", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                
                Button {
                    engine.advancePhase(experiment.id)
                } label: {
                    Label("Next Phase", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func phaseProgressView(_ experiment: Experiment) -> some View {
        HStack(spacing: 4) {
            ForEach(experiment.phases) { phase in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(phaseColor(phase))
                        .frame(height: 8)
                    
                    Text(phase.type.rawValue.prefix(1).uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func phaseColor(_ phase: ExperimentPhase) -> Color {
        if phase.isComplete {
            return .green
        } else if phase.startDate != nil {
            return .teal
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Templates
    
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start Templates")
                .font(.headline)
            
            ForEach(ExperimentEngine.templates, id: \.name) { template in
                Button {
                    let experiment = engine.createExperiment(
                        name: template.name,
                        hypothesis: "Testing effect of \(template.intervention.name)",
                        intervention: template.intervention,
                        metrics: template.metrics,
                        design: .abab
                    )
                    engine.startExperiment(experiment.id)
                } label: {
                    HStack {
                        Image(systemName: template.intervention.category.icon)
                            .foregroundColor(.teal)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(template.intervention.dosage ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.teal)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Past Experiments
    
    private var pastExperimentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Experiments")
                .font(.headline)
            
            let pastExperiments = engine.experiments.filter { $0.status == .completed || $0.status == .cancelled }
            
            if pastExperiments.isEmpty {
                Text("No completed experiments yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(pastExperiments) { experiment in
                    Button {
                        selectedExperiment = experiment
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(experiment.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let completed = experiment.completedAt {
                                    Text(completed, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            statusBadge(experiment.status)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func statusBadge(_ status: ExperimentStatus) -> some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(8)
    }
    
    private func statusColor(_ status: ExperimentStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .baseline: return .blue
        case .intervention: return .green
        case .washout: return .orange
        case .analysis: return .purple
        case .completed: return .teal
        case .cancelled: return .red
        }
    }
}

// MARK: - New Experiment Sheet

struct NewExperimentSheet: View {
    @ObservedObject var engine: ExperimentEngine
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var hypothesis = ""
    @State private var interventionName = ""
    @State private var interventionCategory: InterventionCategory = .supplement
    @State private var dosage = ""
    @State private var timing = ""
    @State private var design: ExperimentDesign = .abab
    @State private var phaseDuration = 7
    @State private var selectedMetrics: Set<MetricType> = [.hrv, .energy]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Experiment") {
                    TextField("Name", text: $name)
                    TextField("Hypothesis (what you expect to happen)", text: $hypothesis, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section("Intervention") {
                    TextField("What are you testing?", text: $interventionName)
                    
                    Picker("Category", selection: $interventionCategory) {
                        ForEach(InterventionCategory.allCases, id: \.self) { category in
                            Label(category.rawValue.capitalized, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    TextField("Dosage (e.g., 5g daily)", text: $dosage)
                    TextField("Timing (e.g., Morning)", text: $timing)
                }
                
                Section("Design") {
                    Picker("Design", selection: $design) {
                        ForEach(ExperimentDesign.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    
                    Text(design.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Stepper("Phase duration: \(phaseDuration) days", value: $phaseDuration, in: 3...21)
                }
                
                Section("Metrics to Track") {
                    ForEach([MetricType.hrv, .restingHR, .sleepScore, .glucose, .energy, .mood, .focus], id: \.self) { metric in
                        Toggle(metric.rawValue.capitalized, isOn: Binding(
                            get: { selectedMetrics.contains(metric) },
                            set: { if $0 { selectedMetrics.insert(metric) } else { selectedMetrics.remove(metric) } }
                        ))
                    }
                }
            }
            .navigationTitle("New Experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createExperiment()
                        dismiss()
                    }
                    .disabled(name.isEmpty || interventionName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func createExperiment() {
        let intervention = Intervention(
            name: interventionName,
            category: interventionCategory,
            dosage: dosage.isEmpty ? nil : dosage,
            timing: timing.isEmpty ? nil : timing
        )
        
        let metrics = selectedMetrics.map { type in
            TrackedMetric(
                name: type.rawValue.capitalized,
                type: type,
                source: type == .energy || type == .mood || type == .focus ? .survey : .healthKit,
                unit: metricUnit(type),
                higherIsBetter: type != .restingHR && type != .glucose
            )
        }
        
        let experiment = engine.createExperiment(
            name: name,
            hypothesis: hypothesis,
            intervention: intervention,
            metrics: metrics,
            design: design,
            phaseDurationDays: phaseDuration
        )
        engine.startExperiment(experiment.id)
    }
    
    private func metricUnit(_ type: MetricType) -> String {
        switch type {
        case .hrv: return "ms"
        case .restingHR: return "bpm"
        case .sleepScore: return "/100"
        case .sleepDuration: return "hours"
        case .glucose: return "mg/dL"
        case .weight: return "kg"
        case .energy, .mood, .focus: return "/10"
        case .custom: return ""
        }
    }
}

// MARK: - Experiment Detail Sheet

struct ExperimentDetailSheet: View {
    let experiment: Experiment
    @ObservedObject var engine: ExperimentEngine
    @Environment(\.dismiss) var dismiss
    
    @State private var metricValues: [UUID: String] = [:]
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info section
                    infoSection
                    
                    // Data entry (if active)
                    if experiment.status != .completed && experiment.status != .cancelled {
                        dataEntrySection
                    }
                    
                    // Results (if completed)
                    if experiment.status == .completed, let results = engine.latestResults, results.experimentId == experiment.id {
                        resultsSection(results)
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(experiment.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: experiment.intervention.category.icon)
                    .foregroundColor(.teal)
                Text(experiment.intervention.name)
                    .font(.headline)
            }
            
            if !experiment.hypothesis.isEmpty {
                Text(experiment.hypothesis)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(experiment.design.rawValue, systemImage: "chart.xyaxis.line")
                Spacer()
                Label("\(experiment.metrics.count) metrics", systemImage: "gauge")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var dataEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Log Today's Data")
                .font(.headline)
            
            ForEach(experiment.metrics) { metric in
                HStack {
                    Text(metric.name)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    TextField("Value", text: Binding(
                        get: { metricValues[metric.id] ?? "" },
                        set: { metricValues[metric.id] = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    
                    Text(metric.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }
            
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            
            Button {
                saveDataPoints()
            } label: {
                Label("Save Data", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func resultsSection(_ results: ExperimentResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                Text(results.overallConclusion.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(conclusionColor(results.overallConclusion).opacity(0.2))
                    .foregroundColor(conclusionColor(results.overallConclusion))
                    .cornerRadius(8)
            }
            
            ForEach(results.metricAnalyses) { analysis in
                HStack {
                    Image(systemName: analysis.trend.icon)
                        .foregroundColor(trendColor(analysis.trend))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(analysis.metricName)
                            .font(.subheadline)
                        Text("Effect size: \(String(format: "%.2f", analysis.effectSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%+.1f%%", analysis.percentChange))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(trendColor(analysis.trend))
                        Text(analysis.isSignificant ? "Significant" : "Not significant")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !results.confounders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potential Confounders")
                        .font(.caption)
                        .fontWeight(.medium)
                    ForEach(results.confounders, id: \.self) { confounder in
                        Text("• \(confounder)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if experiment.status == .analysis {
                Button {
                    engine.completeExperiment(experiment.id)
                } label: {
                    Label("Complete Analysis", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            
            if experiment.status != .completed && experiment.status != .cancelled {
                Button(role: .destructive) {
                    engine.cancelExperiment(experiment.id)
                    dismiss()
                } label: {
                    Label("Cancel Experiment", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func saveDataPoints() {
        for metric in experiment.metrics {
            if let valueStr = metricValues[metric.id], let value = Double(valueStr) {
                engine.recordDataPoint(
                    experimentId: experiment.id,
                    metricId: metric.id,
                    value: value,
                    notes: notes.isEmpty ? nil : notes
                )
            }
        }
        metricValues = [:]
        notes = ""
    }
    
    private func conclusionColor(_ conclusion: Conclusion) -> Color {
        switch conclusion {
        case .beneficial: return .green
        case .harmful: return .red
        case .neutral: return .gray
        case .inconclusive: return .orange
        }
    }
    
    private func trendColor(_ trend: EffectTrend) -> Color {
        switch trend {
        case .improved: return .green
        case .worsened: return .red
        case .noChange: return .gray
        case .inconclusive: return .orange
        }
    }
}

#Preview {
    ExperimentView()
}
