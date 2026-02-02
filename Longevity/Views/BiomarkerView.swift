import SwiftUI

struct BiomarkerView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddSheet = false
    @State private var selectedCategory: BiomarkerCategory = .all
    
    enum BiomarkerCategory: String, CaseIterable {
        case all = "All"
        case lipids = "Lipids"
        case inflammation = "Inflammation"
        case metabolic = "Metabolic"
        case hormones = "Hormones"
        case vitamins = "Vitamins"
        
        var types: [BiomarkerType] {
            switch self {
            case .all: return BiomarkerType.allCases
            case .lipids: return [.apoB, .ldlC, .hdlC, .triglycerides, .totalCholesterol]
            case .inflammation: return [.hsCRP, .ferritin]
            case .metabolic: return [.uricAcid, .creatinine, .egfr, .alt, .ast]
            case .hormones: return [.testosterone, .cortisol, .tsh, .freeT3, .freeT4, .igf1]
            case .vitamins: return [.vitaminD, .vitaminB12, .folate, .iron, .magnesium, .omega3Index]
            }
        }
    }
    
    var filteredBiomarkers: [Biomarker] {
        if selectedCategory == .all {
            return dataStore.biomarkers
        }
        return dataStore.biomarkers.filter { selectedCategory.types.contains($0.type) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BiomarkerCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == category ? .semibold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCategory == category
                                            ? Color.teal
                                            : Color(.secondarySystemBackground)
                                    )
                                    .foregroundColor(
                                        selectedCategory == category
                                            ? .white
                                            : .primary
                                    )
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                if filteredBiomarkers.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedBiomarkers.keys.sorted(), id: \.self) { type in
                            if let biomarkers = groupedBiomarkers[type] {
                                Section {
                                    ForEach(biomarkers) { biomarker in
                                        BiomarkerRow(biomarker: biomarker)
                                    }
                                    .onDelete { indexSet in
                                        deleteBiomarkers(type: type, at: indexSet)
                                    }
                                } header: {
                                    Text(type.displayName)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Biomarkers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBiomarkerSheet()
            }
        }
    }
    
    private var groupedBiomarkers: [BiomarkerType: [Biomarker]] {
        Dictionary(grouping: filteredBiomarkers) { $0.type }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "drop.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No biomarkers yet")
                .font(.headline)
            Text("Add your lab results to track your health markers over time")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showingAddSheet = true
            } label: {
                Text("Add Biomarker")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            Spacer()
        }
    }
    
    private func deleteBiomarkers(type: BiomarkerType, at offsets: IndexSet) {
        if let biomarkers = groupedBiomarkers[type] {
            for index in offsets {
                dataStore.deleteBiomarker(biomarkers[index])
            }
        }
    }
}

// MARK: - Biomarker Row

struct BiomarkerRow: View {
    let biomarker: Biomarker
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(String(format: "%.1f", biomarker.value))
                        .font(.headline)
                    Text(biomarker.type.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(biomarker.testDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lab = biomarker.labName {
                    Text(lab)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: biomarker.status.icon)
                    .foregroundColor(biomarker.status.color)
                
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(biomarker.status.color)
            }
            
            // Range indicator
            rangeIndicator
        }
        .padding(.vertical, 4)
    }
    
    private var statusText: String {
        switch biomarker.status {
        case .optimal: return "Optimal"
        case .warning: return "Monitor"
        case .critical: return "Attention"
        }
    }
    
    private var rangeIndicator: some View {
        let range = biomarker.type.optimalRange
        let position = (biomarker.value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let clampedPosition = max(0, min(1, position))
        
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 4)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green.opacity(0.3))
                .frame(width: 40, height: 4)
            
            Circle()
                .fill(biomarker.status.color)
                .frame(width: 8, height: 8)
                .offset(x: CGFloat(clampedPosition) * 32)
        }
    }
}

// MARK: - Add Biomarker Sheet

struct AddBiomarkerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    
    @State private var selectedType: BiomarkerType = .apoB
    @State private var value: String = ""
    @State private var testDate = Date()
    @State private var labName: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Biomarker") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(BiomarkerType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    HStack {
                        TextField("Value", text: $value)
                            .keyboardType(.decimalPad)
                        Text(selectedType.unit)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Details") {
                    DatePicker("Test Date", selection: $testDate, displayedComponents: .date)
                    TextField("Lab Name (optional)", text: $labName)
                }
                
                Section {
                    referenceRangeInfo
                }
            }
            .navigationTitle("Add Biomarker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBiomarker()
                    }
                    .disabled(value.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var referenceRangeInfo: some View {
        let range = selectedType.optimalRange
        return VStack(alignment: .leading, spacing: 8) {
            Text("Reference Range")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Optimal:")
                    .font(.caption)
                Spacer()
                Text("\(String(format: "%.1f", range.lowerBound)) - \(String(format: "%.1f", range.upperBound)) \(selectedType.unit)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
    
    private func saveBiomarker() {
        guard let numericValue = Double(value) else { return }
        
        let biomarker = Biomarker(
            type: selectedType,
            value: numericValue,
            testDate: testDate,
            labName: labName.isEmpty ? nil : labName,
            provenance: .manual
        )
        
        dataStore.addBiomarker(biomarker)
        dismiss()
    }
}

#Preview {
    BiomarkerView()
        .environmentObject(DataStore())
}
