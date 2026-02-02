import Foundation

class ScoringEngine: ObservableObject {
    
    // MARK: - Morning Readiness Score
    
    /// Calculates readiness score (0-100) based on HRV, sleep, RHR, and subjective feeling
    /// Formula: 0.35 × HRV_score + 0.30 × Sleep_score + 0.20 × RHR_score + 0.15 × Subjective_score
    func calculateReadinessScore(
        currentHRV: Double?,
        baselineHRV: Double?,
        sleepHours: Double?,
        targetSleepHours: Double = 8.0,
        currentRHR: Double?,
        baselineRHR: Double?,
        subjectiveScore: Int? = nil // 1-5 scale
    ) -> ReadinessScore {
        
        var factors: [ScoreFactor] = []
        
        // HRV Score (0-100)
        let hrvScore: Int
        if let current = currentHRV, let baseline = baselineHRV, baseline > 0 {
            let ratio = current / baseline
            hrvScore = normalizeToScore(ratio, mean: 1.0, stdDev: 0.2)
            
            let impact = (Double(hrvScore) - 50) / 50
            factors.append(ScoreFactor(
                name: "HRV",
                impact: impact,
                description: "Your HRV is \(ratio > 1 ? "above" : "below") your 7-day average"
            ))
        } else {
            hrvScore = 50 // Default when no data
        }
        
        // Sleep Score (0-100)
        let sleepScore: Int
        if let hours = sleepHours {
            let efficiency = min(hours / targetSleepHours, 1.2) // Cap at 120%
            sleepScore = Int(min(100, efficiency * 85)) // 100% of target = 85 score
            
            let impact = (Double(sleepScore) - 50) / 50
            factors.append(ScoreFactor(
                name: "Sleep",
                impact: impact,
                description: String(format: "You slept %.1f hours (target: %.0f)", hours, targetSleepHours)
            ))
        } else {
            sleepScore = 50
        }
        
        // RHR Score (0-100) - lower is better, so invert
        let rhrScore: Int
        if let current = currentRHR, let baseline = baselineRHR, baseline > 0 {
            let ratio = baseline / current // Inverted: lower RHR = higher score
            rhrScore = normalizeToScore(ratio, mean: 1.0, stdDev: 0.1)
            
            let impact = (Double(rhrScore) - 50) / 50
            factors.append(ScoreFactor(
                name: "Resting HR",
                impact: impact,
                description: "Your resting HR is \(current < baseline ? "lower" : "higher") than average"
            ))
        } else {
            rhrScore = 50
        }
        
        // Subjective Score (convert 1-5 to 0-100)
        let subjectiveScoreNormalized: Int
        if let subjective = subjectiveScore {
            subjectiveScoreNormalized = (subjective - 1) * 25
        } else {
            subjectiveScoreNormalized = 50
        }
        
        // Weighted average
        let weights: (hrv: Double, sleep: Double, rhr: Double, subjective: Double) = (0.35, 0.30, 0.20, 0.15)
        
        let overallScore = Int(
            Double(hrvScore) * weights.hrv +
            Double(sleepScore) * weights.sleep +
            Double(rhrScore) * weights.rhr +
            Double(subjectiveScoreNormalized) * weights.subjective
        )
        
        // Calculate confidence based on data availability
        var dataPoints = 0
        if currentHRV != nil && baselineHRV != nil { dataPoints += 1 }
        if sleepHours != nil { dataPoints += 1 }
        if currentRHR != nil && baselineRHR != nil { dataPoints += 1 }
        if subjectiveScore != nil { dataPoints += 1 }
        
        let confidence = Double(dataPoints) / 4.0
        
        return ReadinessScore(
            date: Date(),
            overallScore: max(0, min(100, overallScore)),
            hrvScore: hrvScore,
            sleepScore: sleepScore,
            rhrScore: rhrScore,
            subjectiveScore: subjectiveScoreNormalized,
            confidence: confidence,
            factors: factors
        )
    }
    
    // MARK: - Metabolic Health Score
    
    func calculateMetabolicScore(
        glucoseVariability: Double?, // CV%
        fastingGlucose: Double?,
        hba1c: Double?,
        timeInRange: Double?, // % time 70-140 mg/dL
        waistHipRatio: Double?
    ) -> (score: Int, confidence: Double) {
        
        var scores: [(value: Int, weight: Double)] = []
        
        // Glucose variability (lower is better, target CV < 20%)
        if let cv = glucoseVariability {
            let score = cv < 15 ? 100 : cv < 20 ? 80 : cv < 25 ? 60 : cv < 30 ? 40 : 20
            scores.append((score, 0.25))
        }
        
        // Fasting glucose (optimal 70-90 mg/dL)
        if let fg = fastingGlucose {
            let score: Int
            if fg >= 70 && fg <= 90 { score = 100 }
            else if fg >= 60 && fg <= 100 { score = 80 }
            else if fg >= 50 && fg <= 110 { score = 60 }
            else { score = 40 }
            scores.append((score, 0.20))
        }
        
        // HbA1c (optimal < 5.4%)
        if let a1c = hba1c {
            let score: Int
            if a1c < 5.0 { score = 100 }
            else if a1c < 5.4 { score = 90 }
            else if a1c < 5.7 { score = 70 }
            else if a1c < 6.0 { score = 50 }
            else { score = 30 }
            scores.append((score, 0.25))
        }
        
        // Time in range (target > 90%)
        if let tir = timeInRange {
            let score = Int(min(100, tir * 1.1)) // 90% TIR = 99 score
            scores.append((score, 0.15))
        }
        
        // Waist-hip ratio (optimal M < 0.9, F < 0.85)
        if let whr = waistHipRatio {
            let score: Int
            if whr < 0.85 { score = 100 }
            else if whr < 0.90 { score = 80 }
            else if whr < 0.95 { score = 60 }
            else { score = 40 }
            scores.append((score, 0.15))
        }
        
        if scores.isEmpty {
            return (score: 0, confidence: 0)
        }
        
        // Redistribute weights if some data missing
        let totalWeight = scores.reduce(0) { $0 + $1.weight }
        let weightedSum = scores.reduce(0.0) { $0 + Double($1.value) * ($1.weight / totalWeight) }
        
        let confidence = totalWeight / 1.0 // 1.0 is full weight when all data present
        
        return (score: Int(weightedSum), confidence: confidence)
    }
    
    // MARK: - Inflammaging Score
    
    func calculateInflammagingScore(
        hsCRP: Double?,
        sleepQuality: Double?, // 0-100
        omega3Omega6Ratio: Double?,
        processedFoodFrequency: Double?, // 0-1 (1 = lots of processed food)
        avgRHR30Day: Double?,
        avgHRV30Day: Double?,
        baselineHRV: Double?
    ) -> (score: Int, confidence: Double, isTheoretical: Bool) {
        
        var components: [(value: Double, weight: Double)] = []
        
        // hs-CRP (lower is better, optimal < 1.0)
        if let crp = hsCRP {
            let score: Double
            if crp < 0.5 { score = 0 }
            else if crp < 1.0 { score = 20 }
            else if crp < 2.0 { score = 40 }
            else if crp < 3.0 { score = 60 }
            else { score = 80 }
            components.append((score, 0.35))
        }
        
        // Sleep penalty (poor sleep = higher inflammaging)
        if let sq = sleepQuality {
            let penalty = max(0, 100 - sq) // 100 sleep quality = 0 penalty
            components.append((penalty, 0.20))
        }
        
        // Omega-3/Omega-6 (higher is better)
        if let ratio = omega3Omega6Ratio {
            let score: Double
            if ratio > 0.25 { score = 0 }
            else if ratio > 0.15 { score = 20 }
            else if ratio > 0.10 { score = 40 }
            else { score = 60 }
            components.append((score, 0.15))
        }
        
        // Processed food frequency
        if let pff = processedFoodFrequency {
            components.append((pff * 100, 0.15))
        }
        
        // Chronic stress proxy from RHR and HRV
        if let rhr = avgRHR30Day, let hrv = avgHRV30Day, let baseHRV = baselineHRV, baseHRV > 0 {
            let stressProxy = (rhr / 60) * (1 - hrv / baseHRV)
            let normalizedStress = min(100, max(0, stressProxy * 100))
            components.append((normalizedStress, 0.15))
        }
        
        if components.isEmpty {
            return (score: 0, confidence: 0, isTheoretical: true)
        }
        
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedSum = components.reduce(0.0) { $0 + $1.value * ($1.weight / totalWeight) }
        
        let confidence = totalWeight / 1.0
        
        // Mark as theoretical if missing key marker (hs-CRP)
        let isTheoretical = hsCRP == nil
        
        return (score: Int(weightedSum), confidence: confidence, isTheoretical: isTheoretical)
    }
    
    // MARK: - Nutrition Quality Score
    
    func calculateNutritionScore(
        plantsPerWeek: Int,
        fiberGrams: Double?,
        targetFiber: Double = 30,
        proteinQuality: Double?, // 0-100
        micronutrientCoverage: Double?, // 0-100
        processedFoodPercentage: Double? // 0-100
    ) -> (score: Int, confidence: Double) {
        
        var components: [(value: Double, weight: Double)] = []
        
        // Phytochemical density (plants per week, target 30+)
        let phytoScore = min(100, Double(plantsPerWeek) / 30.0 * 100)
        components.append((phytoScore, 0.25))
        
        // Fiber adequacy
        if let fiber = fiberGrams {
            let fiberScore = min(100, fiber / targetFiber * 100)
            components.append((fiberScore, 0.20))
        }
        
        // Protein quality
        if let protein = proteinQuality {
            components.append((protein, 0.20))
        }
        
        // Micronutrient coverage
        if let micro = micronutrientCoverage {
            components.append((micro, 0.20))
        }
        
        // Processed food penalty
        if let processed = processedFoodPercentage {
            let penalty = max(0, 100 - processed)
            components.append((penalty, 0.15))
        }
        
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedSum = components.reduce(0.0) { $0 + $1.value * ($1.weight / totalWeight) }
        
        return (score: Int(weightedSum), confidence: totalWeight / 1.0)
    }
    
    // MARK: - Helper Functions
    
    /// Normalizes a value to a 0-100 score using z-score approach
    private func normalizeToScore(_ value: Double, mean: Double, stdDev: Double) -> Int {
        let zScore = (value - mean) / stdDev
        // Map z-score to 0-100: z=0 -> 50, z=2 -> 100, z=-2 -> 0
        let normalized = (zScore + 2) / 4 * 100
        return Int(max(0, min(100, normalized)))
    }
    
    // MARK: - Trend Analysis
    
    func analyzeTrend(values: [Double], windowSize: Int = 7) -> TrendAnalysis {
        guard values.count >= windowSize else {
            return TrendAnalysis(direction: .stable, magnitude: 0, confidence: 0)
        }
        
        let recent = Array(values.suffix(windowSize))
        let mean = recent.reduce(0, +) / Double(recent.count)
        
        // Simple linear regression for trend
        var sumXY: Double = 0
        var sumX: Double = 0
        var sumY: Double = 0
        var sumX2: Double = 0
        
        for (i, value) in recent.enumerated() {
            let x = Double(i)
            sumXY += x * value
            sumX += x
            sumY += value
            sumX2 += x * x
        }
        
        let n = Double(recent.count)
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        
        // Normalize slope relative to mean
        let normalizedSlope = slope / mean * 100
        
        let direction: TrendDirection
        let magnitude: Double
        
        if abs(normalizedSlope) < 2 {
            direction = .stable
            magnitude = 0
        } else if normalizedSlope > 0 {
            direction = .increasing
            magnitude = min(1, normalizedSlope / 10)
        } else {
            direction = .decreasing
            magnitude = min(1, abs(normalizedSlope) / 10)
        }
        
        return TrendAnalysis(
            direction: direction,
            magnitude: magnitude,
            confidence: min(1, Double(recent.count) / Double(windowSize))
        )
    }
}

// MARK: - Supporting Types

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

struct TrendAnalysis {
    let direction: TrendDirection
    let magnitude: Double // 0-1
    let confidence: Double // 0-1
}
