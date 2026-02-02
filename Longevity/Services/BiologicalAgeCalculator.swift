import Foundation

// MARK: - Biological Age Result

struct BiologicalAgeResult: Codable {
    let chronologicalAge: Double
    let biologicalAge: Double
    let ageDifference: Double // Negative = younger, Positive = older
    let confidence: Double
    let calculationDate: Date
    let algorithm: AgeAlgorithm
    let contributors: [AgeContributor]
    
    var ageLabel: String {
        if ageDifference < -5 {
            return "Significantly Younger"
        } else if ageDifference < -2 {
            return "Younger"
        } else if ageDifference > 5 {
            return "Significantly Older"
        } else if ageDifference > 2 {
            return "Older"
        } else {
            return "On Track"
        }
    }
}

struct AgeContributor: Identifiable, Codable {
    let id: UUID
    let name: String
    let impact: Double // Years added/subtracted
    let category: ContributorCategory
    let recommendation: String?
    
    enum ContributorCategory: String, Codable {
        case biomarker
        case lifestyle
        case fitness
        case nutrition
    }
}

enum AgeAlgorithm: String, Codable {
    case phenoAge = "PhenoAge"
    case levineAge = "Levine"
    case simplified = "Simplified"
    
    var description: String {
        switch self {
        case .phenoAge: return "Based on Levine et al. 2018 clinical biomarker model"
        case .levineAge: return "Epigenetic-inspired algorithm"
        case .simplified: return "Simplified model with available biomarkers"
        }
    }
}

// MARK: - Biological Age Calculator

class BiologicalAgeCalculator {
    
    // Required biomarkers for full PhenoAge calculation
    static let requiredBiomarkers: [BiomarkerType] = [
        .albumin,
        .creatinine,
        .glucose,
        .crp,
        .lymphocytePercent,
        .meanCellVolume,
        .redBloodCellWidth,
        .alkalinePhosphatase,
        .whiteBloodCellCount
    ]
    
    // MARK: - Calculate Biological Age
    
    func calculate(
        chronologicalAge: Double,
        biomarkers: [Biomarker],
        hrv: Double?,
        vo2max: Double?,
        sleepQuality: Double?, // 0-100
        exerciseMinutesPerWeek: Int?
    ) -> BiologicalAgeResult {
        
        var contributors: [AgeContributor] = []
        var totalAdjustment: Double = 0
        var confidence: Double = 0.3 // Base confidence
        
        // Check available biomarkers
        let biomarkerDict = Dictionary(uniqueKeysWithValues: biomarkers.map { ($0.type, $0.value) })
        
        // Try PhenoAge if we have required biomarkers
        if hasRequiredBiomarkers(biomarkerDict) {
            return calculatePhenoAge(chronologicalAge: chronologicalAge, biomarkers: biomarkerDict)
        }
        
        // Otherwise use simplified model
        
        // === Biomarker Contributions ===
        
        // HbA1c (blood sugar control)
        if let hba1c = biomarkerDict[.hba1c] {
            let adjustment: Double
            if hba1c < 5.0 {
                adjustment = -2.0 // Excellent glucose control
            } else if hba1c < 5.4 {
                adjustment = -1.0
            } else if hba1c < 5.7 {
                adjustment = 0
            } else if hba1c < 6.5 {
                adjustment = 2.0
            } else {
                adjustment = 4.0 // Diabetic range
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "HbA1c",
                impact: adjustment,
                category: .biomarker,
                recommendation: adjustment > 0 ? "Focus on reducing blood sugar through diet and exercise" : nil
            ))
            confidence += 0.1
        }
        
        // hs-CRP (inflammation)
        if let crp = biomarkerDict[.crp] {
            let adjustment: Double
            if crp < 0.5 {
                adjustment = -2.0
            } else if crp < 1.0 {
                adjustment = -1.0
            } else if crp < 3.0 {
                adjustment = 1.0
            } else {
                adjustment = 3.0
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "hs-CRP (Inflammation)",
                impact: adjustment,
                category: .biomarker,
                recommendation: adjustment > 0 ? "Reduce inflammation through omega-3s, sleep, and stress management" : nil
            ))
            confidence += 0.1
        }
        
        // Vitamin D
        if let vitD = biomarkerDict[.vitaminD] {
            let adjustment: Double
            if vitD >= 50 && vitD <= 70 {
                adjustment = -1.5
            } else if vitD >= 40 {
                adjustment = -0.5
            } else if vitD >= 30 {
                adjustment = 0.5
            } else {
                adjustment = 2.0
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "Vitamin D",
                impact: adjustment,
                category: .biomarker,
                recommendation: adjustment > 0 ? "Supplement with D3+K2, target 50-70 ng/mL" : nil
            ))
            confidence += 0.05
        }
        
        // LDL Cholesterol
        if let ldl = biomarkerDict[.ldlCholesterol] {
            let adjustment: Double
            if ldl < 70 {
                adjustment = -1.0
            } else if ldl < 100 {
                adjustment = 0
            } else if ldl < 130 {
                adjustment = 1.0
            } else {
                adjustment = 2.5
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "LDL Cholesterol",
                impact: adjustment,
                category: .biomarker,
                recommendation: adjustment > 0 ? "Consider dietary changes and discuss statins with your doctor" : nil
            ))
            confidence += 0.05
        }
        
        // ApoB (if available, more predictive than LDL)
        if let apoB = biomarkerDict[.apoB] {
            let adjustment: Double
            if apoB < 70 {
                adjustment = -1.5
            } else if apoB < 90 {
                adjustment = -0.5
            } else if apoB < 110 {
                adjustment = 0.5
            } else {
                adjustment = 2.0
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "ApoB",
                impact: adjustment,
                category: .biomarker,
                recommendation: adjustment > 0 ? "ApoB is a key cardiovascular risk marker" : nil
            ))
            confidence += 0.1
        }
        
        // === Fitness Contributions ===
        
        // HRV
        if let hrv = hrv {
            let expectedHRV = 50 - (chronologicalAge * 0.5) // Rough expectation
            let adjustment: Double
            if hrv > expectedHRV + 20 {
                adjustment = -3.0
            } else if hrv > expectedHRV + 10 {
                adjustment = -1.5
            } else if hrv > expectedHRV - 5 {
                adjustment = 0
            } else if hrv > expectedHRV - 15 {
                adjustment = 1.0
            } else {
                adjustment = 2.5
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "HRV",
                impact: adjustment,
                category: .fitness,
                recommendation: adjustment > 0 ? "Improve HRV through Zone 2 training and stress reduction" : nil
            ))
            confidence += 0.1
        }
        
        // VO2 Max
        if let vo2max = vo2max {
            let adjustment = calculateVO2MaxAdjustment(vo2max: vo2max, age: chronologicalAge)
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "VO2 Max",
                impact: adjustment,
                category: .fitness,
                recommendation: adjustment > 0 ? "Increase cardio training to improve VO2 max" : nil
            ))
            confidence += 0.1
        }
        
        // Exercise
        if let exercise = exerciseMinutesPerWeek {
            let adjustment: Double
            if exercise >= 300 { // 5+ hours
                adjustment = -2.5
            } else if exercise >= 150 { // WHO recommendation
                adjustment = -1.0
            } else if exercise >= 75 {
                adjustment = 0.5
            } else {
                adjustment = 2.0
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "Exercise",
                impact: adjustment,
                category: .lifestyle,
                recommendation: adjustment > 0 ? "Aim for at least 150 min/week of moderate exercise" : nil
            ))
            confidence += 0.05
        }
        
        // Sleep Quality
        if let sleep = sleepQuality {
            let adjustment: Double
            if sleep >= 85 {
                adjustment = -1.5
            } else if sleep >= 70 {
                adjustment = 0
            } else if sleep >= 50 {
                adjustment = 1.0
            } else {
                adjustment = 2.5
            }
            totalAdjustment += adjustment
            contributors.append(AgeContributor(
                id: UUID(),
                name: "Sleep Quality",
                impact: adjustment,
                category: .lifestyle,
                recommendation: adjustment > 0 ? "Prioritize sleep hygiene and target 7-8 hours" : nil
            ))
            confidence += 0.05
        }
        
        let biologicalAge = chronologicalAge + totalAdjustment
        
        return BiologicalAgeResult(
            chronologicalAge: chronologicalAge,
            biologicalAge: biologicalAge,
            ageDifference: totalAdjustment,
            confidence: min(0.95, confidence),
            calculationDate: Date(),
            algorithm: .simplified,
            contributors: contributors.sorted { abs($0.impact) > abs($1.impact) }
        )
    }
    
    // MARK: - PhenoAge Algorithm
    
    private func calculatePhenoAge(chronologicalAge: Double, biomarkers: [BiomarkerType: Double]) -> BiologicalAgeResult {
        // PhenoAge formula from Levine et al. 2018
        // This is the published formula with coefficients
        
        guard let albumin = biomarkers[.albumin],
              let creatinine = biomarkers[.creatinine],
              let glucose = biomarkers[.glucose],
              let crp = biomarkers[.crp],
              let lymphocyte = biomarkers[.lymphocytePercent],
              let mcv = biomarkers[.meanCellVolume],
              let rdw = biomarkers[.redBloodCellWidth],
              let alp = biomarkers[.alkalinePhosphatase],
              let wbc = biomarkers[.whiteBloodCellCount] else {
            // Fallback - shouldn't happen if hasRequiredBiomarkers passed
            return BiologicalAgeResult(
                chronologicalAge: chronologicalAge,
                biologicalAge: chronologicalAge,
                ageDifference: 0,
                confidence: 0.1,
                calculationDate: Date(),
                algorithm: .phenoAge,
                contributors: []
            )
        }
        
        // PhenoAge linear predictor
        let xb = -19.907
            - 0.0336 * albumin
            + 0.0095 * creatinine
            + 0.1953 * glucose
            + 0.0954 * log(crp)
            - 0.0120 * lymphocyte
            + 0.0268 * mcv
            + 0.3306 * rdw
            + 0.00188 * alp
            + 0.0554 * wbc
            + 0.0804 * chronologicalAge
        
        // Mortality score
        let mortalityScore = 1 - exp(-exp(xb) * (exp(120 * 0.0077) - 1) / 0.0077)
        
        // Convert to PhenoAge
        let phenoAge = 141.50225 + log(-0.00553 * log(1 - mortalityScore)) / 0.090165
        
        let ageDifference = phenoAge - chronologicalAge
        
        // Generate contributors based on biomarker contributions
        var contributors: [AgeContributor] = []
        
        if crp > 1.0 {
            contributors.append(AgeContributor(
                id: UUID(), name: "hs-CRP (elevated)",
                impact: min(3, crp * 0.5), category: .biomarker,
                recommendation: "High inflammation detected. Consider anti-inflammatory diet."
            ))
        }
        
        if glucose > 100 {
            contributors.append(AgeContributor(
                id: UUID(), name: "Glucose (elevated)",
                impact: (glucose - 100) * 0.05, category: .biomarker,
                recommendation: "Consider reducing refined carbohydrates."
            ))
        }
        
        if albumin < 4.0 {
            contributors.append(AgeContributor(
                id: UUID(), name: "Albumin (low)",
                impact: (4.0 - albumin) * 1.5, category: .biomarker,
                recommendation: "Ensure adequate protein intake."
            ))
        }
        
        return BiologicalAgeResult(
            chronologicalAge: chronologicalAge,
            biologicalAge: phenoAge,
            ageDifference: ageDifference,
            confidence: 0.9,
            calculationDate: Date(),
            algorithm: .phenoAge,
            contributors: contributors
        )
    }
    
    // MARK: - Helpers
    
    private func hasRequiredBiomarkers(_ biomarkers: [BiomarkerType: Double]) -> Bool {
        for required in Self.requiredBiomarkers {
            if biomarkers[required] == nil {
                return false
            }
        }
        return true
    }
    
    private func calculateVO2MaxAdjustment(vo2max: Double, age: Double) -> Double {
        // Age-adjusted VO2 max expectations (rough percentiles)
        let excellent: Double
        let good: Double
        let fair: Double
        
        switch age {
        case ..<30:
            excellent = 50; good = 43; fair = 36
        case 30..<40:
            excellent = 47; good = 40; fair = 33
        case 40..<50:
            excellent = 43; good = 37; fair = 30
        case 50..<60:
            excellent = 39; good = 33; fair = 27
        default:
            excellent = 35; good = 29; fair = 23
        }
        
        if vo2max >= excellent {
            return -3.0
        } else if vo2max >= good {
            return -1.0
        } else if vo2max >= fair {
            return 1.0
        } else {
            return 3.0
        }
    }
}
