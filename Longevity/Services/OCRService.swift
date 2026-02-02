import Foundation
import Vision
import UIKit

// MARK: - OCR Result

struct OCRLabResult: Identifiable, Codable {
    let id: UUID
    let biomarkerName: String
    let detectedValue: Double
    let unit: String
    let confidence: Double
    let referenceRange: String?
    let category: BiomarkerCategory?
    var isVerified: Bool
    
    init(
        id: UUID = UUID(),
        biomarkerName: String,
        detectedValue: Double,
        unit: String,
        confidence: Double,
        referenceRange: String? = nil,
        category: BiomarkerCategory? = nil,
        isVerified: Bool = false
    ) {
        self.id = id
        self.biomarkerName = biomarkerName
        self.detectedValue = detectedValue
        self.unit = unit
        self.confidence = confidence
        self.referenceRange = referenceRange
        self.category = category
        self.isVerified = isVerified
    }
}

struct OCRScanSession: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let labName: String?
    let results: [OCRLabResult]
    var status: ScanStatus
    
    enum ScanStatus: String, Codable {
        case processing
        case needsVerification
        case verified
        case imported
    }
}

// MARK: - Known Biomarkers

struct KnownBiomarker {
    let names: [String] // All possible names/aliases
    let unit: String
    let category: BiomarkerCategory
    let referenceRange: String
    
    static let all: [KnownBiomarker] = [
        // Lipid Panel
        KnownBiomarker(names: ["Total Cholesterol", "Cholesterol", "TC"], unit: "mg/dL", category: .lipids, referenceRange: "<200"),
        KnownBiomarker(names: ["LDL", "LDL-C", "LDL Cholesterol", "Low Density Lipoprotein"], unit: "mg/dL", category: .lipids, referenceRange: "<100"),
        KnownBiomarker(names: ["HDL", "HDL-C", "HDL Cholesterol", "High Density Lipoprotein"], unit: "mg/dL", category: .lipids, referenceRange: ">40"),
        KnownBiomarker(names: ["Triglycerides", "TG", "Trigs"], unit: "mg/dL", category: .lipids, referenceRange: "<150"),
        KnownBiomarker(names: ["ApoB", "Apolipoprotein B", "Apo B"], unit: "mg/dL", category: .lipids, referenceRange: "<90"),
        KnownBiomarker(names: ["Lp(a)", "Lipoprotein(a)", "Lipoprotein a"], unit: "mg/dL", category: .lipids, referenceRange: "<30"),
        
        // Metabolic
        KnownBiomarker(names: ["Glucose", "Fasting Glucose", "Blood Glucose", "FBG"], unit: "mg/dL", category: .metabolic, referenceRange: "70-99"),
        KnownBiomarker(names: ["HbA1c", "A1c", "Hemoglobin A1c", "Glycated Hemoglobin"], unit: "%", category: .metabolic, referenceRange: "<5.7"),
        KnownBiomarker(names: ["Insulin", "Fasting Insulin"], unit: "uIU/mL", category: .metabolic, referenceRange: "2-25"),
        KnownBiomarker(names: ["HOMA-IR", "HOMA IR"], unit: "", category: .metabolic, referenceRange: "<2"),
        
        // Inflammation
        KnownBiomarker(names: ["hs-CRP", "hsCRP", "C-Reactive Protein", "CRP", "High Sensitivity CRP"], unit: "mg/L", category: .inflammation, referenceRange: "<1"),
        KnownBiomarker(names: ["Homocysteine", "Hcy"], unit: "umol/L", category: .inflammation, referenceRange: "<10"),
        KnownBiomarker(names: ["ESR", "Sed Rate", "Erythrocyte Sedimentation Rate"], unit: "mm/hr", category: .inflammation, referenceRange: "<20"),
        
        // Hormones
        KnownBiomarker(names: ["Testosterone", "Total Testosterone"], unit: "ng/dL", category: .hormones, referenceRange: "300-1000"),
        KnownBiomarker(names: ["Free Testosterone"], unit: "pg/mL", category: .hormones, referenceRange: "50-200"),
        KnownBiomarker(names: ["Estradiol", "E2"], unit: "pg/mL", category: .hormones, referenceRange: "10-40"),
        KnownBiomarker(names: ["DHEA-S", "DHEA Sulfate"], unit: "ug/dL", category: .hormones, referenceRange: "100-500"),
        KnownBiomarker(names: ["Cortisol", "AM Cortisol"], unit: "ug/dL", category: .hormones, referenceRange: "6-23"),
        KnownBiomarker(names: ["TSH", "Thyroid Stimulating Hormone"], unit: "mIU/L", category: .hormones, referenceRange: "0.5-4.0"),
        KnownBiomarker(names: ["Free T4", "FT4"], unit: "ng/dL", category: .hormones, referenceRange: "0.8-1.8"),
        KnownBiomarker(names: ["Free T3", "FT3"], unit: "pg/mL", category: .hormones, referenceRange: "2.3-4.2"),
        
        // Vitamins & Minerals
        KnownBiomarker(names: ["Vitamin D", "25-OH Vitamin D", "25(OH)D", "Vitamin D3"], unit: "ng/mL", category: .vitamins, referenceRange: "40-60"),
        KnownBiomarker(names: ["B12", "Vitamin B12", "Cobalamin"], unit: "pg/mL", category: .vitamins, referenceRange: "500-1000"),
        KnownBiomarker(names: ["Folate", "Folic Acid", "Vitamin B9"], unit: "ng/mL", category: .vitamins, referenceRange: ">15"),
        KnownBiomarker(names: ["Ferritin"], unit: "ng/mL", category: .vitamins, referenceRange: "40-200"),
        KnownBiomarker(names: ["Iron"], unit: "ug/dL", category: .vitamins, referenceRange: "60-170"),
        KnownBiomarker(names: ["Magnesium", "Mg"], unit: "mg/dL", category: .vitamins, referenceRange: "2-2.5"),
        KnownBiomarker(names: ["Zinc", "Zn"], unit: "ug/dL", category: .vitamins, referenceRange: "70-120"),
        
        // Kidney
        KnownBiomarker(names: ["Creatinine"], unit: "mg/dL", category: .kidney, referenceRange: "0.7-1.3"),
        KnownBiomarker(names: ["BUN", "Blood Urea Nitrogen"], unit: "mg/dL", category: .kidney, referenceRange: "7-20"),
        KnownBiomarker(names: ["eGFR", "GFR", "Glomerular Filtration Rate"], unit: "mL/min/1.73m2", category: .kidney, referenceRange: ">90"),
        KnownBiomarker(names: ["Cystatin C"], unit: "mg/L", category: .kidney, referenceRange: "0.6-1.0"),
        
        // Liver
        KnownBiomarker(names: ["ALT", "SGPT", "Alanine Aminotransferase"], unit: "U/L", category: .liver, referenceRange: "<40"),
        KnownBiomarker(names: ["AST", "SGOT", "Aspartate Aminotransferase"], unit: "U/L", category: .liver, referenceRange: "<40"),
        KnownBiomarker(names: ["GGT", "Gamma GT", "Gamma-Glutamyl Transferase"], unit: "U/L", category: .liver, referenceRange: "<50"),
        KnownBiomarker(names: ["ALP", "Alkaline Phosphatase"], unit: "U/L", category: .liver, referenceRange: "40-150"),
    ]
    
    static func find(_ text: String) -> KnownBiomarker? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return all.first { biomarker in
            biomarker.names.contains { $0.lowercased() == normalized }
        }
    }
}

// MARK: - OCR Service

@MainActor
class OCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var scanSessions: [OCRScanSession] = []
    @Published var currentResults: [OCRLabResult] = []
    @Published var errorMessage: String?
    
    // MARK: - Process Image
    
    func processLabImage(_ image: UIImage) async -> [OCRLabResult] {
        guard let cgImage = image.cgImage else { return [] }
        
        isProcessing = true
        defer { isProcessing = false }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = self?.parseLabResults(from: observations) ?? []
                DispatchQueue.main.async {
                    self?.currentResults = results
                }
                continuation.resume(returning: results)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Parse Results
    
    private func parseLabResults(from observations: [VNRecognizedTextObservation]) -> [OCRLabResult] {
        var results: [OCRLabResult] = []
        var textLines: [(text: String, confidence: Float, bounds: CGRect)] = []
        
        // Extract all text lines
        for observation in observations {
            if let candidate = observation.topCandidates(1).first {
                textLines.append((
                    text: candidate.string,
                    confidence: candidate.confidence,
                    bounds: observation.boundingBox
                ))
            }
        }
        
        // Sort by Y position (top to bottom)
        textLines.sort { $0.bounds.origin.y > $1.bounds.origin.y }
        
        // Pattern matching for biomarker + value pairs
        let valuePattern = #"(\d+\.?\d*)\s*(mg/dL|ng/mL|pg/mL|umol/L|uIU/mL|U/L|%|ug/dL|mIU/L|ng/dL|mm/hr|mL/min/1\.73m2|mg/L)?"#
        let regex = try? NSRegularExpression(pattern: valuePattern, options: .caseInsensitive)
        
        for (index, line) in textLines.enumerated() {
            let text = line.text
            
            // Check if this line contains a known biomarker
            if let biomarker = KnownBiomarker.find(text) {
                // Look for value in same line or next line
                if let value = extractValue(from: text, regex: regex) {
                    results.append(OCRLabResult(
                        biomarkerName: biomarker.names[0],
                        detectedValue: value.value,
                        unit: value.unit ?? biomarker.unit,
                        confidence: Double(line.confidence),
                        referenceRange: biomarker.referenceRange,
                        category: biomarker.category
                    ))
                } else if index + 1 < textLines.count {
                    // Check next line for value
                    let nextLine = textLines[index + 1]
                    if let value = extractValue(from: nextLine.text, regex: regex) {
                        results.append(OCRLabResult(
                            biomarkerName: biomarker.names[0],
                            detectedValue: value.value,
                            unit: value.unit ?? biomarker.unit,
                            confidence: Double(min(line.confidence, nextLine.confidence)),
                            referenceRange: biomarker.referenceRange,
                            category: biomarker.category
                        ))
                    }
                }
            }
            
            // Also check for inline format: "Biomarker: Value Unit"
            let colonPattern = #"(.+?):\s*(\d+\.?\d*)\s*(mg/dL|ng/mL|pg/mL|umol/L|uIU/mL|U/L|%|ug/dL|mIU/L|ng/dL|mm/hr|mL/min/1\.73m2|mg/L)?"#
            if let colonRegex = try? NSRegularExpression(pattern: colonPattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = colonRegex.firstMatch(in: text, options: [], range: range) {
                    let nameRange = Range(match.range(at: 1), in: text)
                    let valueRange = Range(match.range(at: 2), in: text)
                    
                    if let nameRange = nameRange, let valueRange = valueRange {
                        let name = String(text[nameRange])
                        if let biomarker = KnownBiomarker.find(name),
                           let value = Double(text[valueRange]) {
                            // Avoid duplicates
                            if !results.contains(where: { $0.biomarkerName == biomarker.names[0] }) {
                                var unit = biomarker.unit
                                if match.range(at: 3).location != NSNotFound,
                                   let unitRange = Range(match.range(at: 3), in: text) {
                                    unit = String(text[unitRange])
                                }
                                
                                results.append(OCRLabResult(
                                    biomarkerName: biomarker.names[0],
                                    detectedValue: value,
                                    unit: unit,
                                    confidence: Double(line.confidence),
                                    referenceRange: biomarker.referenceRange,
                                    category: biomarker.category
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    private func extractValue(from text: String, regex: NSRegularExpression?) -> (value: Double, unit: String?)? {
        guard let regex = regex else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            if let valueRange = Range(match.range(at: 1), in: text),
               let value = Double(text[valueRange]) {
                var unit: String? = nil
                if match.range(at: 2).location != NSNotFound,
                   let unitRange = Range(match.range(at: 2), in: text) {
                    unit = String(text[unitRange])
                }
                return (value, unit)
            }
        }
        return nil
    }
    
    // MARK: - Create Session
    
    func createScanSession(labName: String?) -> OCRScanSession {
        let session = OCRScanSession(
            id: UUID(),
            timestamp: Date(),
            labName: labName,
            results: currentResults,
            status: currentResults.isEmpty ? .processing : .needsVerification
        )
        scanSessions.append(session)
        return session
    }
    
    // MARK: - Verification
    
    func verifyResult(_ id: UUID) {
        if let index = currentResults.firstIndex(where: { $0.id == id }) {
            currentResults[index].isVerified = true
        }
    }
    
    func updateResult(id: UUID, value: Double) {
        if let index = currentResults.firstIndex(where: { $0.id == id }) {
            let result = currentResults[index]
            currentResults[index] = OCRLabResult(
                id: result.id,
                biomarkerName: result.biomarkerName,
                detectedValue: value,
                unit: result.unit,
                confidence: 1.0, // Manual correction = 100% confidence
                referenceRange: result.referenceRange,
                category: result.category,
                isVerified: true
            )
        }
    }
    
    func removeResult(_ id: UUID) {
        currentResults.removeAll { $0.id == id }
    }
    
    // MARK: - Convert to Biomarkers
    
    func convertToBiomarkers() -> [Biomarker] {
        return currentResults.filter { $0.isVerified }.map { result in
            let biomarkerType = BiomarkerType(rawValue: result.biomarkerName.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "")) ?? .other
            
            return Biomarker(
                type: biomarkerType,
                value: result.detectedValue,
                unit: result.unit,
                labDate: Date(),
                labName: nil,
                referenceRangeLow: nil,
                referenceRangeHigh: nil
            )
        }
    }
}
