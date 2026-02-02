import SwiftUI
import PhotosUI

struct LabUploadView: View {
    @StateObject private var ocrService = OCRService()
    @EnvironmentObject var dataStore: DataStore
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var labName: String = ""
    @State private var showingCamera = false
    @State private var showingResults = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header info
                    infoCard
                    
                    // Upload options
                    uploadOptionsCard
                    
                    // Selected image preview
                    if let image = selectedImage {
                        imagePreviewCard(image: image)
                    }
                    
                    // Lab name input
                    if selectedImage != nil {
                        labInfoCard
                    }
                    
                    // Process button
                    if selectedImage != nil && !ocrService.isProcessing {
                        processButton
                    }
                    
                    // Processing indicator
                    if ocrService.isProcessing {
                        processingView
                    }
                    
                    // Recent scans
                    if !ocrService.scanSessions.isEmpty {
                        recentScansSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upload Labs")
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
            .sheet(isPresented: $showingResults) {
                LabResultsVerificationSheet(
                    ocrService: ocrService,
                    dataStore: dataStore,
                    labName: labName
                )
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    selectedImage = image
                    showingCamera = false
                }
            }
        }
    }
    
    // MARK: - Info Card
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.viewfinder")
                    .font(.title2)
                    .foregroundColor(.teal)
                Text("AI-Powered Lab OCR")
                    .font(.headline)
            }
            
            Text("Upload a photo of your lab results and we'll automatically extract biomarker values using on-device AI.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Processing happens on your device. Data never leaves your phone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Upload Options
    
    private var uploadOptionsCard: some View {
        VStack(spacing: 16) {
            Text("Choose Upload Method")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                // Camera button
                Button {
                    showingCamera = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title)
                        Text("Camera")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.teal.opacity(0.1))
                    .foregroundColor(.teal)
                    .cornerRadius(12)
                }
                
                // Photo library
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .font(.title)
                        Text("Gallery")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Image Preview
    
    private func imagePreviewCard(image: UIImage) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Selected Image")
                    .font(.headline)
                Spacer()
                Button {
                    selectedImage = nil
                    selectedPhoto = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Lab Info Card
    
    private var labInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lab Information")
                .font(.headline)
            
            TextField("Lab name (optional)", text: $labName)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Process Button
    
    private var processButton: some View {
        Button {
            Task {
                if let image = selectedImage {
                    let results = await ocrService.processLabImage(image)
                    if !results.isEmpty {
                        showingResults = true
                    }
                }
            }
        } label: {
            Label("Extract Lab Values", systemImage: "text.viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.teal)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing lab report...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Using Vision AI to extract biomarker values")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Scans
    
    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Scans")
                .font(.headline)
            
            ForEach(ocrService.scanSessions.prefix(5)) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.labName ?? "Lab Report")
                            .font(.subheadline)
                        Text("\(session.results.count) biomarkers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(session.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    statusBadge(for: session.status)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func statusBadge(for status: OCRScanSession.ScanStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: status).opacity(0.2))
            .foregroundColor(statusColor(for: status))
            .cornerRadius(8)
    }
    
    private func statusColor(for status: OCRScanSession.ScanStatus) -> Color {
        switch status {
        case .processing: return .orange
        case .needsVerification: return .yellow
        case .verified: return .blue
        case .imported: return .green
        }
    }
}

// MARK: - Verification Sheet

struct LabResultsVerificationSheet: View {
    @ObservedObject var ocrService: OCRService
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let labName: String
    @State private var importedCount = 0
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Please verify each detected value before importing")
                            .font(.subheadline)
                    }
                }
                
                Section("Detected Biomarkers (\(ocrService.currentResults.count))") {
                    ForEach(ocrService.currentResults) { result in
                        LabResultRow(
                            result: result,
                            onVerify: { ocrService.verifyResult(result.id) },
                            onUpdate: { value in ocrService.updateResult(id: result.id, value: value) },
                            onRemove: { ocrService.removeResult(result.id) }
                        )
                    }
                }
                
                Section {
                    let verifiedCount = ocrService.currentResults.filter { $0.isVerified }.count
                    Button {
                        importVerifiedResults()
                    } label: {
                        Label(
                            "Import \(verifiedCount) Verified Biomarkers",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(verifiedCount == 0)
                }
            }
            .navigationTitle("Verify Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Verify All") {
                        for result in ocrService.currentResults {
                            ocrService.verifyResult(result.id)
                        }
                    }
                }
            }
            .alert("Imported Successfully", isPresented: $showingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(importedCount) biomarkers have been added to your health record.")
            }
        }
    }
    
    private func importVerifiedResults() {
        let biomarkers = ocrService.convertToBiomarkers()
        for biomarker in biomarkers {
            dataStore.addBiomarker(biomarker)
        }
        importedCount = biomarkers.count
        _ = ocrService.createScanSession(labName: labName.isEmpty ? nil : labName)
        showingSuccess = true
    }
}

// MARK: - Lab Result Row

struct LabResultRow: View {
    let result: OCRLabResult
    let onVerify: () -> Void
    let onUpdate: (Double) -> Void
    let onRemove: () -> Void
    
    @State private var editedValue: String = ""
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.biomarkerName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if result.isVerified {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 8) {
                    if let category = result.category {
                        Text(String(describing: category).capitalized)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if let range = result.referenceRange {
                        Text("Ref: \(range)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Confidence
                HStack(spacing: 4) {
                    Text("Confidence:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ProgressView(value: result.confidence)
                        .frame(width: 50)
                    Text("\(Int(result.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(result.confidence > 0.8 ? .green : result.confidence > 0.5 ? .orange : .red)
                }
            }
            
            Spacer()
            
            // Value
            VStack(alignment: .trailing) {
                if isEditing {
                    HStack {
                        TextField("Value", text: $editedValue)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Button {
                            if let value = Double(editedValue) {
                                onUpdate(value)
                            }
                            isEditing = false
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                } else {
                    HStack {
                        Text(String(format: "%.1f", result.detectedValue))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(result.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        editedValue = String(format: "%.1f", result.detectedValue)
                        isEditing = true
                    }
                }
            }
            
            // Actions
            if !result.isVerified && !isEditing {
                Button {
                    onVerify()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Camera View (Placeholder)

struct CameraView: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("Camera")
                .font(.title)
            Text("Camera capture would go here")
                .foregroundColor(.secondary)
            
            Button("Cancel") {
                dismiss()
            }
            .padding()
        }
    }
}

#Preview {
    LabUploadView()
        .environmentObject(DataStore())
}
