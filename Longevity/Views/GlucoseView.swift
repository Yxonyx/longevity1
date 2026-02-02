import SwiftUI
import Charts

struct GlucoseView: View {
    @StateObject private var cgmManager = CGMManager()
    @State private var selectedTimeRange: TimeRange = .day
    @State private var showingAddReading = false
    
    enum TimeRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current glucose card
                    currentGlucoseCard
                    
                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Glucose chart
                    glucoseChart
                    
                    // Statistics
                    statisticsCard
                    
                    // Time in range breakdown
                    timeInRangeCard
                    
                    // Recent events
                    eventsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Glucose")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddReading = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await cgmManager.fetchGlucoseData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddReading) {
                AddGlucoseReadingSheet(cgmManager: cgmManager)
            }
            .task {
                if await cgmManager.requestAuthorization() {
                    await cgmManager.fetchGlucoseData()
                }
            }
        }
    }
    
    // MARK: - Current Glucose Card
    
    private var currentGlucoseCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current")
                    .font(.headline)
                Spacer()
                if let reading = cgmManager.latestReading {
                    Text(reading.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let reading = cgmManager.latestReading {
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(Int(reading.value))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor(for: reading.status))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("mg/dL")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let trend = reading.trend {
                            HStack(spacing: 4) {
                                Image(systemName: trend.icon)
                                Text(trend.description)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Status badge
                    Text(reading.status.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor(for: reading.status).opacity(0.2))
                        .foregroundColor(statusColor(for: reading.status))
                        .cornerRadius(12)
                }
                
                // Target range indicator
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Green zone (70-140)
                    GeometryReader { geo in
                        let totalRange: Double = 250
                        let start = 70 / totalRange
                        let width = 70 / totalRange
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.3))
                            .frame(width: geo.size.width * width)
                            .offset(x: geo.size.width * start)
                    }
                    .frame(height: 8)
                    
                    // Current value indicator
                    GeometryReader { geo in
                        let position = min(250, max(0, reading.value)) / 250
                        Circle()
                            .fill(statusColor(for: reading.status))
                            .frame(width: 16, height: 16)
                            .offset(x: geo.size.width * position - 8)
                    }
                    .frame(height: 16)
                }
                .padding(.top, 8)
                
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "drop.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No glucose data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    // MARK: - Glucose Chart
    
    private var glucoseChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glucose Trend")
                .font(.headline)
            
            let filteredReadings = filteredReadings(for: selectedTimeRange)
            
            if filteredReadings.isEmpty {
                Text("No data for selected period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    // Target range area
                    RectangleMark(
                        xStart: .value("Start", filteredReadings.first?.timestamp ?? Date()),
                        xEnd: .value("End", filteredReadings.last?.timestamp ?? Date()),
                        yStart: .value("Low", 70),
                        yEnd: .value("High", 140)
                    )
                    .foregroundStyle(Color.green.opacity(0.1))
                    
                    // Glucose line
                    ForEach(filteredReadings) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Glucose", reading.value)
                        )
                        .foregroundStyle(Color.teal.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Glucose", reading.value)
                        )
                        .foregroundStyle(statusColor(for: reading.status))
                        .symbolSize(20)
                    }
                    
                    // Reference lines
                    RuleMark(y: .value("High", 140))
                        .foregroundStyle(Color.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    RuleMark(y: .value("Low", 70))
                        .foregroundStyle(Color.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .frame(height: 200)
                .chartYScale(domain: 40...220)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [70, 100, 140, 180]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        let stats = selectedTimeRange == .day ? cgmManager.todayStats : cgmManager.weekStats
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            if let stats = stats, stats.readingCount > 0 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statItem(
                        label: "Average",
                        value: String(format: "%.0f", stats.average),
                        unit: "mg/dL"
                    )
                    
                    statItem(
                        label: "Variability (CV)",
                        value: String(format: "%.1f%%", stats.coefficientOfVariation),
                        unit: "",
                        isGood: stats.coefficientOfVariation < 36
                    )
                    
                    statItem(
                        label: "GMI (est. A1c)",
                        value: stats.glucoseManagementIndicator.map { String(format: "%.1f%%", $0) } ?? "--",
                        unit: ""
                    )
                    
                    statItem(
                        label: "Readings",
                        value: "\(stats.readingCount)",
                        unit: ""
                    )
                }
                
                HStack {
                    Text("Range: \(Int(stats.lowestValue)) - \(Int(stats.highestValue)) mg/dL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Not enough data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func statItem(label: String, value: String, unit: String, isGood: Bool? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(isGood.map { $0 ? .green : .orange })
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Time in Range Card
    
    private var timeInRangeCard: some View {
        let stats = selectedTimeRange == .day ? cgmManager.todayStats : cgmManager.weekStats
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Time in Range")
                    .font(.headline)
                Spacer()
                if let tir = stats?.timeInRange {
                    Text(String(format: "%.0f%%", tir))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tir >= 70 ? .green : tir >= 50 ? .orange : .red)
                }
            }
            
            if let stats = stats, stats.readingCount > 0 {
                // Stacked bar
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Below range (red)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width * (stats.timeBelowRange / 100))
                        
                        // In range (green)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geo.size.width * (stats.timeInRange / 100))
                        
                        // Above range (orange)
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: geo.size.width * (stats.timeAboveRange / 100))
                    }
                    .cornerRadius(4)
                }
                .frame(height: 24)
                
                // Legend
                HStack(spacing: 16) {
                    legendItem(color: .red, label: "Low", value: stats.timeBelowRange)
                    legendItem(color: .green, label: "In Range", value: stats.timeInRange)
                    legendItem(color: .orange, label: "High", value: stats.timeAboveRange)
                }
                .font(.caption)
                
                // Target info
                Text("Target: >70% in range (70-140 mg/dL)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func legendItem(color: Color, label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(String(format: "%.0f%%", value))")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Events Section
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.headline)
            
            let recentEvents = cgmManager.events.suffix(5)
            
            if recentEvents.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No glucose excursions detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(recentEvents.reversed()) { event in
                    HStack {
                        Image(systemName: event.type.icon)
                            .foregroundColor(event.type == .spike ? .orange : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.type == .spike ? "Glucose Spike" : "Low Glucose")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Peak: \(Int(event.peakValue)) mg/dL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(event.startTime, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private func filteredReadings(for range: TimeRange) -> [GlucoseReading] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch range {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        }
        
        return cgmManager.readings.filter { $0.timestamp >= startDate }
    }
    
    private func statusColor(for status: GlucoseStatus) -> Color {
        switch status {
        case .optimal: return .green
        case .elevated: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Add Reading Sheet

struct AddGlucoseReadingSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var cgmManager: CGMManager
    
    @State private var glucoseValue: String = ""
    @State private var readingTime = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Glucose Reading") {
                    HStack {
                        TextField("Value", text: $glucoseValue)
                            .keyboardType(.numberPad)
                        Text("mg/dL")
                            .foregroundColor(.secondary)
                    }
                    
                    DatePicker("Time", selection: $readingTime)
                }
                
                Section {
                    if let value = Double(glucoseValue) {
                        let reading = GlucoseReading(value: value, timestamp: readingTime)
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(reading.status.description)
                                .foregroundColor(statusColor(for: reading.status))
                        }
                    }
                }
            }
            .navigationTitle("Add Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let value = Double(glucoseValue) {
                            cgmManager.addManualReading(value: value, timestamp: readingTime)
                            dismiss()
                        }
                    }
                    .disabled(Double(glucoseValue) == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func statusColor(for status: GlucoseStatus) -> Color {
        switch status {
        case .optimal: return .green
        case .elevated: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

#Preview {
    GlucoseView()
}
