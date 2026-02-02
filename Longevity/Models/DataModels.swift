import Foundation
import SwiftUI

// MARK: - Measurement Types

enum MetricType: String, Codable, CaseIterable {
    // Vitals
    case heartRate = "heart_rate"
    case hrvSDNN = "hrv_sdnn"
    case hrvRMSSD = "hrv_rmssd"
    case restingHeartRate = "resting_heart_rate"
    case respiratoryRate = "respiratory_rate"
    case bloodPressureSystolic = "bp_systolic"
    case bloodPressureDiastolic = "bp_diastolic"
    case bodyTemperature = "body_temperature"
    case oxygenSaturation = "oxygen_saturation"
    
    // Body Composition
    case weight = "weight"
    case bodyFatPercentage = "body_fat_percentage"
    case muscleMass = "muscle_mass"
    case visceralFat = "visceral_fat"
    
    // Activity
    case steps = "steps"
    case vo2Max = "vo2_max"
    case activeCalories = "active_calories"
    
    // Sleep
    case sleepDuration = "sleep_duration"
    case sleepEfficiency = "sleep_efficiency"
    case deepSleep = "deep_sleep"
    case remSleep = "rem_sleep"
    
    // Glucose
    case bloodGlucose = "blood_glucose"
    case hba1c = "hba1c"
    
    var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .hrvSDNN: return "HRV (SDNN)"
        case .hrvRMSSD: return "HRV (RMSSD)"
        case .restingHeartRate: return "Resting Heart Rate"
        case .respiratoryRate: return "Respiratory Rate"
        case .bloodPressureSystolic: return "Systolic BP"
        case .bloodPressureDiastolic: return "Diastolic BP"
        case .bodyTemperature: return "Body Temperature"
        case .oxygenSaturation: return "SpO2"
        case .weight: return "Weight"
        case .bodyFatPercentage: return "Body Fat %"
        case .muscleMass: return "Muscle Mass"
        case .visceralFat: return "Visceral Fat"
        case .steps: return "Steps"
        case .vo2Max: return "VO2 Max"
        case .activeCalories: return "Active Calories"
        case .sleepDuration: return "Sleep Duration"
        case .sleepEfficiency: return "Sleep Efficiency"
        case .deepSleep: return "Deep Sleep"
        case .remSleep: return "REM Sleep"
        case .bloodGlucose: return "Blood Glucose"
        case .hba1c: return "HbA1c"
        }
    }
    
    var unit: String {
        switch self {
        case .heartRate, .restingHeartRate: return "bpm"
        case .hrvSDNN, .hrvRMSSD: return "ms"
        case .respiratoryRate: return "breaths/min"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "mmHg"
        case .bodyTemperature: return "°C"
        case .oxygenSaturation, .bodyFatPercentage, .sleepEfficiency: return "%"
        case .weight, .muscleMass: return "kg"
        case .visceralFat: return "level"
        case .steps: return "steps"
        case .vo2Max: return "mL/kg/min"
        case .activeCalories: return "kcal"
        case .sleepDuration, .deepSleep, .remSleep: return "hours"
        case .bloodGlucose: return "mg/dL"
        case .hba1c: return "%"
        }
    }
}

enum DataProvenance: String, Codable {
    case healthKit = "healthkit"
    case manual = "manual"
    case cgmDexcom = "cgm_dexcom"
    case cgmLibre = "cgm_libre"
    case ocr = "ocr"
    case inferred = "inferred"
}

// MARK: - Core Measurement

struct Measurement: Identifiable, Codable {
    let id: UUID
    let metricType: MetricType
    let value: Double
    let timestamp: Date
    let provenance: DataProvenance
    let confidence: Double?
    let deviceId: String?
    
    init(
        id: UUID = UUID(),
        metricType: MetricType,
        value: Double,
        timestamp: Date = Date(),
        provenance: DataProvenance = .manual,
        confidence: Double? = nil,
        deviceId: String? = nil
    ) {
        self.id = id
        self.metricType = metricType
        self.value = value
        self.timestamp = timestamp
        self.provenance = provenance
        self.confidence = confidence
        self.deviceId = deviceId
    }
}

// MARK: - Biomarkers

enum BiomarkerType: String, Codable, CaseIterable {
    case hsCRP = "hs_crp"
    case crp = "crp" // alias for hs-CRP
    case apoB = "apo_b"
    case ldlC = "ldl_c"
    case ldlCholesterol = "ldl_cholesterol" // alias
    case hdlC = "hdl_c"
    case triglycerides = "triglycerides"
    case totalCholesterol = "total_cholesterol"
    case vitaminD = "vitamin_d"
    case vitaminB12 = "vitamin_b12"
    case folate = "folate"
    case iron = "iron"
    case ferritin = "ferritin"
    case testosterone = "testosterone"
    case cortisol = "cortisol"
    case tsh = "tsh"
    case freeT3 = "free_t3"
    case freeT4 = "free_t4"
    case igf1 = "igf1"
    case uricAcid = "uric_acid"
    case creatinine = "creatinine"
    case egfr = "egfr"
    case alt = "alt"
    case ast = "ast"
    case magnesium = "magnesium"
    case omega3Index = "omega3_index"
    // PhenoAge required biomarkers
    case albumin = "albumin"
    case glucose = "glucose"
    case hba1c = "hba1c"
    case lymphocytePercent = "lymphocyte_percent"
    case meanCellVolume = "mean_cell_volume"
    case redBloodCellWidth = "red_blood_cell_width"
    case alkalinePhosphatase = "alkaline_phosphatase"
    case whiteBloodCellCount = "white_blood_cell_count"
    
    var displayName: String {
        switch self {
        case .hsCRP, .crp: return "hs-CRP"
        case .apoB: return "ApoB"
        case .ldlC, .ldlCholesterol: return "LDL-C"
        case .hdlC: return "HDL-C"
        case .triglycerides: return "Triglycerides"
        case .totalCholesterol: return "Total Cholesterol"
        case .vitaminD: return "Vitamin D"
        case .vitaminB12: return "Vitamin B12"
        case .folate: return "Folate"
        case .iron: return "Iron"
        case .ferritin: return "Ferritin"
        case .testosterone: return "Testosterone"
        case .cortisol: return "Cortisol"
        case .tsh: return "TSH"
        case .freeT3: return "Free T3"
        case .freeT4: return "Free T4"
        case .igf1: return "IGF-1"
        case .uricAcid: return "Uric Acid"
        case .creatinine: return "Creatinine"
        case .egfr: return "eGFR"
        case .alt: return "ALT"
        case .ast: return "AST"
        case .magnesium: return "Magnesium"
        case .omega3Index: return "Omega-3 Index"
        case .albumin: return "Albumin"
        case .glucose: return "Glucose"
        case .hba1c: return "HbA1c"
        case .lymphocytePercent: return "Lymphocyte %"
        case .meanCellVolume: return "MCV"
        case .redBloodCellWidth: return "RDW"
        case .alkalinePhosphatase: return "ALP"
        case .whiteBloodCellCount: return "WBC"
        }
    }
    
    var unit: String {
        switch self {
        case .hsCRP, .crp: return "mg/L"
        case .apoB: return "mg/dL"
        case .ldlC, .ldlCholesterol, .hdlC, .totalCholesterol: return "mg/dL"
        case .triglycerides: return "mg/dL"
        case .vitaminD: return "ng/mL"
        case .vitaminB12: return "pg/mL"
        case .folate: return "ng/mL"
        case .iron: return "μg/dL"
        case .ferritin: return "ng/mL"
        case .testosterone: return "ng/dL"
        case .cortisol: return "μg/dL"
        case .tsh: return "mIU/L"
        case .freeT3: return "pg/mL"
        case .freeT4: return "ng/dL"
        case .igf1: return "ng/mL"
        case .uricAcid: return "mg/dL"
        case .creatinine: return "mg/dL"
        case .egfr: return "mL/min/1.73m²"
        case .alt, .ast, .alkalinePhosphatase: return "U/L"
        case .magnesium: return "mg/dL"
        case .omega3Index, .lymphocytePercent, .redBloodCellWidth, .hba1c: return "%"
        case .albumin: return "g/dL"
        case .glucose: return "mg/dL"
        case .meanCellVolume: return "fL"
        case .whiteBloodCellCount: return "K/μL"
        }
    }
    
    var optimalRange: ClosedRange<Double> {
        switch self {
        case .hsCRP, .crp: return 0...1.0
        case .apoB: return 0...70
        case .ldlC, .ldlCholesterol: return 0...100
        case .hdlC: return 50...100
        case .triglycerides: return 0...100
        case .totalCholesterol: return 100...200
        case .vitaminD: return 40...60
        case .vitaminB12: return 500...1000
        case .folate: return 10...25
        case .iron: return 60...170
        case .ferritin: return 30...200
        case .testosterone: return 400...900
        case .cortisol: return 6...23
        case .tsh: return 0.5...2.5
        case .freeT3: return 2.3...4.2
        case .freeT4: return 0.8...1.8
        case .igf1: return 100...200
        case .uricAcid: return 3.5...7.0
        case .creatinine: return 0.7...1.3
        case .egfr: return 90...120
        case .alt: return 0...40
        case .ast: return 0...40
        case .magnesium: return 1.8...2.4
        case .omega3Index: return 8...12
        case .albumin: return 3.5...5.0
        case .glucose: return 70...100
        case .hba1c: return 4.0...5.6
        case .lymphocytePercent: return 20...40
        case .meanCellVolume: return 80...100
        case .redBloodCellWidth: return 11...14
        case .alkalinePhosphatase: return 40...130
        case .whiteBloodCellCount: return 4.5...11.0
        }
    }
}

struct Biomarker: Identifiable, Codable {
    let id: UUID
    let type: BiomarkerType
    let value: Double
    let testDate: Date
    let labName: String?
    let provenance: DataProvenance
    let confidence: Double?
    
    init(
        id: UUID = UUID(),
        type: BiomarkerType,
        value: Double,
        testDate: Date = Date(),
        labName: String? = nil,
        provenance: DataProvenance = .manual,
        confidence: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.testDate = testDate
        self.labName = labName
        self.provenance = provenance
        self.confidence = confidence
    }
    
    var status: BiomarkerStatus {
        let range = type.optimalRange
        if value < range.lowerBound * 0.7 || value > range.upperBound * 1.5 {
            return .critical
        } else if value < range.lowerBound || value > range.upperBound {
            return .warning
        } else {
            return .optimal
        }
    }
}

enum BiomarkerStatus {
    case optimal
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .optimal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .optimal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

// MARK: - Supplements

struct Supplement: Identifiable, Codable {
    let id: UUID
    var name: String
    var dosage: String
    var brand: String?
    var timing: [SupplementTiming]
    var notes: String?
    var inventoryCount: Int?
    var isActive: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        brand: String? = nil,
        timing: [SupplementTiming] = [],
        notes: String? = nil,
        inventoryCount: Int? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.brand = brand
        self.timing = timing
        self.notes = notes
        self.inventoryCount = inventoryCount
        self.isActive = isActive
    }
}

struct SupplementTiming: Codable, Hashable {
    let time: Date
    let withMeal: Bool
    let notes: String?
}

struct SupplementLog: Identifiable, Codable {
    let id: UUID
    let supplementId: UUID
    let takenAt: Date
    let skipped: Bool
    let notes: String?
}

// MARK: - Scores

struct ReadinessScore: Identifiable, Codable {
    let id: UUID
    let date: Date
    let overallScore: Int // 0-100
    let hrvScore: Int
    let sleepScore: Int
    let rhrScore: Int
    let subjectiveScore: Int?
    let confidence: Double
    let factors: [ScoreFactor]
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        overallScore: Int,
        hrvScore: Int,
        sleepScore: Int,
        rhrScore: Int,
        subjectiveScore: Int? = nil,
        confidence: Double = 0.8,
        factors: [ScoreFactor] = []
    ) {
        self.id = id
        self.date = date
        self.overallScore = overallScore
        self.hrvScore = hrvScore
        self.sleepScore = sleepScore
        self.rhrScore = rhrScore
        self.subjectiveScore = subjectiveScore
        self.confidence = confidence
        self.factors = factors
    }
}

struct ScoreFactor: Codable, Identifiable {
    let id: UUID
    let name: String
    let impact: Double // -1 to 1
    let description: String
    
    init(id: UUID = UUID(), name: String, impact: Double, description: String) {
        self.id = id
        self.name = name
        self.impact = impact
        self.description = description
    }
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    var birthDate: Date?
    var biologicalSex: BiologicalSex?
    var heightCm: Double?
    var targetSleepHours: Double = 8.0
    var targetSteps: Int = 10000
    var targetZone2Minutes: Int = 150
    var showDeathClockUI: Bool = false
    var enableNotifications: Bool = true
    var privacyMode: PrivacyMode = .standard
}

enum BiologicalSex: String, Codable {
    case male
    case female
    case other
}

enum PrivacyMode: String, Codable {
    case standard
    case enhanced
    case zeroKnowledge
}
