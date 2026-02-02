import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let score: Int
    let confidence: Double
}

// MARK: - Complication Provider

struct ReadinessComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: Date(), score: 75, confidence: 0.8)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        let entry = ReadinessEntry(date: Date(), score: 75, confidence: 0.8)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        // In production, fetch from shared container or WatchConnectivity
        let entry = ReadinessEntry(date: Date(), score: 75, confidence: 0.8)
        
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Complication Views

struct ReadinessComplicationView: View {
    var entry: ReadinessEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }
    
    // Circular complication - gauge style
    private var circularView: some View {
        Gauge(value: Double(entry.score), in: 0...100) {
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text("\(entry.score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gaugeGradient)
    }
    
    // Corner complication
    private var cornerView: some View {
        Text("\(entry.score)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(scoreColor)
            .widgetLabel {
                Gauge(value: Double(entry.score), in: 0...100) {
                    Text("Ready")
                }
                .gaugeStyle(.accessoryLinear)
                .tint(gaugeGradient)
            }
    }
    
    // Inline complication
    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
            Text("Readiness: \(entry.score)")
        }
    }
    
    // Rectangular complication
    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(entry.score)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
                
                Text(scoreLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Gauge(value: Double(entry.score), in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeGradient)
            .scaleEffect(0.8)
        }
    }
    
    // MARK: - Helpers
    
    private var scoreColor: Color {
        switch entry.score {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    private var gaugeGradient: Gradient {
        Gradient(colors: [scoreColor.opacity(0.6), scoreColor])
    }
    
    private var scoreLabel: String {
        switch entry.score {
        case 0..<40: return "Recovery"
        case 40..<60: return "Moderate"
        case 60..<80: return "Good"
        default: return "Excellent"
        }
    }
}

// MARK: - Widget Configuration

struct ReadinessComplication: Widget {
    let kind: String = "ReadinessComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessComplicationProvider()) { entry in
            ReadinessComplicationView(entry: entry)
        }
        .configurationDisplayName("Readiness")
        .description("Shows your current readiness score")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

#Preview(as: .accessoryCircular) {
    ReadinessComplication()
} timeline: {
    ReadinessEntry(date: Date(), score: 85, confidence: 0.9)
    ReadinessEntry(date: Date(), score: 65, confidence: 0.7)
    ReadinessEntry(date: Date(), score: 45, confidence: 0.5)
}
