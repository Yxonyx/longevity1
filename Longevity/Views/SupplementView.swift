import SwiftUI

struct SupplementView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddSheet = false
    
    var activeSupplements: [Supplement] {
        dataStore.supplements.filter { $0.isActive }
    }
    
    var inactiveSupplements: [Supplement] {
        dataStore.supplements.filter { !$0.isActive }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !activeSupplements.isEmpty {
                    Section("Active") {
                        ForEach(activeSupplements) { supplement in
                            SupplementRow(supplement: supplement)
                        }
                        .onDelete { indexSet in
                            deleteSupplements(from: activeSupplements, at: indexSet)
                        }
                    }
                }
                
                if !inactiveSupplements.isEmpty {
                    Section("Paused") {
                        ForEach(inactiveSupplements) { supplement in
                            SupplementRow(supplement: supplement)
                        }
                        .onDelete { indexSet in
                            deleteSupplements(from: inactiveSupplements, at: indexSet)
                        }
                    }
                }
                
                if dataStore.supplements.isEmpty {
                    emptyState
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Supplements")
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
                AddSupplementSheet()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No supplements tracked")
                .font(.headline)
            Text("Add your supplement stack to get reminders and track adherence")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddSheet = true
            } label: {
                Text("Add Supplement")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .listRowBackground(Color.clear)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func deleteSupplements(from list: [Supplement], at offsets: IndexSet) {
        for index in offsets {
            dataStore.deleteSupplement(list[index])
        }
    }
}

// MARK: - Supplement Row

struct SupplementRow: View {
    @EnvironmentObject var dataStore: DataStore
    let supplement: Supplement
    
    @State private var showingDetail = false
    
    private var todayLogs: [SupplementLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return dataStore.getSupplementLogs(supplementId: supplement.id, days: 1)
            .filter { $0.takenAt >= startOfDay }
    }
    
    private var takenToday: Bool {
        !todayLogs.filter { !$0.skipped }.isEmpty
    }
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(supplement.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !supplement.isActive {
                            Text("Paused")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(supplement.dosage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let brand = supplement.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Quick log buttons
                if supplement.isActive {
                    HStack(spacing: 12) {
                        Button {
                            logTaken()
                        } label: {
                            Image(systemName: takenToday ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(takenToday ? .green : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        if let count = supplement.inventoryCount {
                            Text("\(count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(count < 10 ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingDetail) {
            SupplementDetailSheet(supplement: supplement)
        }
    }
    
    private func logTaken() {
        dataStore.logSupplementTaken(supplementId: supplement.id)
        
        // Decrement inventory if tracked
        if var count = supplement.inventoryCount, count > 0 {
            count -= 1
            var updated = supplement
            updated.inventoryCount = count
            dataStore.updateSupplement(updated)
        }
    }
}

// MARK: - Add Supplement Sheet

struct AddSupplementSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    
    @State private var name = ""
    @State private var dosage = ""
    @State private var brand = ""
    @State private var notes = ""
    @State private var trackInventory = false
    @State private var inventoryCount = 30
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name (e.g., Vitamin D3)", text: $name)
                    TextField("Dosage (e.g., 5000 IU)", text: $dosage)
                    TextField("Brand (optional)", text: $brand)
                }
                
                Section("Inventory") {
                    Toggle("Track inventory", isOn: $trackInventory)
                    
                    if trackInventory {
                        Stepper("Count: \(inventoryCount)", value: $inventoryCount, in: 0...365)
                    }
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Text("💡 Tip: You can add timing and reminders after saving")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSupplement()
                    }
                    .disabled(name.isEmpty || dosage.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveSupplement() {
        let supplement = Supplement(
            name: name,
            dosage: dosage,
            brand: brand.isEmpty ? nil : brand,
            notes: notes.isEmpty ? nil : notes,
            inventoryCount: trackInventory ? inventoryCount : nil,
            isActive: true
        )
        
        dataStore.addSupplement(supplement)
        dismiss()
    }
}

// MARK: - Supplement Detail Sheet

struct SupplementDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    
    let supplement: Supplement
    
    @State private var isActive: Bool
    @State private var inventoryCount: Int
    
    init(supplement: Supplement) {
        self.supplement = supplement
        _isActive = State(initialValue: supplement.isActive)
        _inventoryCount = State(initialValue: supplement.inventoryCount ?? 0)
    }
    
    private var adherence: Double {
        let logs = dataStore.getSupplementLogs(supplementId: supplement.id, days: 30)
        let takenCount = logs.filter { !$0.skipped }.count
        return Double(takenCount) / 30.0 * 100
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Dosage")
                        Spacer()
                        Text(supplement.dosage)
                            .foregroundColor(.secondary)
                    }
                    
                    if let brand = supplement.brand {
                        HStack {
                            Text("Brand")
                            Spacer()
                            Text(brand)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Active", isOn: $isActive)
                        .onChange(of: isActive) { _, newValue in
                            var updated = supplement
                            updated.isActive = newValue
                            dataStore.updateSupplement(updated)
                        }
                }
                
                if supplement.inventoryCount != nil {
                    Section("Inventory") {
                        Stepper("Count: \(inventoryCount)", value: $inventoryCount, in: 0...365)
                            .onChange(of: inventoryCount) { _, newValue in
                                var updated = supplement
                                updated.inventoryCount = newValue
                                dataStore.updateSupplement(updated)
                            }
                        
                        if inventoryCount < 10 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Low stock - time to reorder!")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("30-Day Adherence") {
                    HStack {
                        Text("Taken")
                        Spacer()
                        Text(String(format: "%.0f%%", adherence))
                            .fontWeight(.semibold)
                            .foregroundColor(adherence > 80 ? .green : adherence > 50 ? .orange : .red)
                    }
                    
                    ProgressView(value: adherence / 100)
                        .tint(adherence > 80 ? .green : adherence > 50 ? .orange : .red)
                }
                
                if let notes = supplement.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(supplement.name)
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
    SupplementView()
        .environmentObject(DataStore())
}
