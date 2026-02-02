import Foundation
import Vision
import UIKit

// MARK: - Food Recognition Result

struct FoodRecognitionResult: Identifiable, Codable {
    let id: UUID
    let foodName: String
    let confidence: Double
    let estimatedServing: ServingSize
    let nutrition: NutritionEstimate
    let alternatives: [String] // Other possible foods detected
    
    init(
        id: UUID = UUID(),
        foodName: String,
        confidence: Double,
        estimatedServing: ServingSize = .medium,
        nutrition: NutritionEstimate,
        alternatives: [String] = []
    ) {
        self.id = id
        self.foodName = foodName
        self.confidence = confidence
        self.estimatedServing = estimatedServing
        self.nutrition = nutrition
        self.alternatives = alternatives
    }
}

enum ServingSize: String, Codable, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case custom = "Custom"
    
    var multiplier: Double {
        switch self {
        case .small: return 0.7
        case .medium: return 1.0
        case .large: return 1.4
        case .custom: return 1.0
        }
    }
}

struct NutritionEstimate: Codable {
    var calories: Double
    var protein: Double // grams
    var carbs: Double // grams
    var fat: Double // grams
    var fiber: Double // grams
    var sugar: Double // grams
    var sodium: Double // mg
    
    static let unknown = NutritionEstimate(
        calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 0
    )
    
    func scaled(by multiplier: Double) -> NutritionEstimate {
        NutritionEstimate(
            calories: calories * multiplier,
            protein: protein * multiplier,
            carbs: carbs * multiplier,
            fat: fat * multiplier,
            fiber: fiber * multiplier,
            sugar: sugar * multiplier,
            sodium: sodium * multiplier
        )
    }
}

// MARK: - Meal Log

struct MealLog: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let mealType: MealType
    var foods: [FoodRecognitionResult]
    var notes: String?
    var glucoseResponse: GlucoseResponse? // If CGM data available
    
    var totalNutrition: NutritionEstimate {
        let scaled = foods.map { $0.nutrition.scaled(by: $0.estimatedServing.multiplier) }
        return NutritionEstimate(
            calories: scaled.reduce(0) { $0 + $1.calories },
            protein: scaled.reduce(0) { $0 + $1.protein },
            carbs: scaled.reduce(0) { $0 + $1.carbs },
            fat: scaled.reduce(0) { $0 + $1.fat },
            fiber: scaled.reduce(0) { $0 + $1.fiber },
            sugar: scaled.reduce(0) { $0 + $1.sugar },
            sodium: scaled.reduce(0) { $0 + $1.sodium }
        )
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
    
    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "carrot.fill"
        }
    }
}

struct GlucoseResponse: Codable {
    let preValue: Double
    let peakValue: Double
    let areaUnderCurve: Double // For 2-hour response
}

// MARK: - Food Database

struct FoodDatabaseEntry {
    let name: String
    let keywords: [String]
    let nutrition: NutritionEstimate
    let category: FoodCategory
}

enum FoodCategory: String, CaseIterable {
    case protein
    case carbs
    case vegetable
    case fruit
    case dairy
    case fat
    case processed
    case beverage
}

// MARK: - Photo-to-Macro Service

@MainActor
class FoodAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var currentResults: [FoodRecognitionResult] = []
    @Published var mealLogs: [MealLog] = []
    @Published var errorMessage: String?
    
    private let mealLogsKey = "longevity_meal_logs"
    
    // Basic food database - in production, this would be a larger database or API
    private let foodDatabase: [FoodDatabaseEntry] = [
        // Proteins
        FoodDatabaseEntry(
            name: "Chicken Breast", keywords: ["chicken", "poultry", "grilled chicken"],
            nutrition: NutritionEstimate(calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0, sugar: 0, sodium: 74),
            category: .protein
        ),
        FoodDatabaseEntry(
            name: "Salmon", keywords: ["salmon", "fish", "seafood"],
            nutrition: NutritionEstimate(calories: 208, protein: 20, carbs: 0, fat: 13, fiber: 0, sugar: 0, sodium: 59),
            category: .protein
        ),
        FoodDatabaseEntry(
            name: "Eggs", keywords: ["egg", "eggs", "fried egg", "scrambled"],
            nutrition: NutritionEstimate(calories: 155, protein: 13, carbs: 1.1, fat: 11, fiber: 0, sugar: 1.1, sodium: 124),
            category: .protein
        ),
        FoodDatabaseEntry(
            name: "Steak", keywords: ["steak", "beef", "ribeye", "sirloin"],
            nutrition: NutritionEstimate(calories: 271, protein: 26, carbs: 0, fat: 18, fiber: 0, sugar: 0, sodium: 54),
            category: .protein
        ),
        
        // Carbs
        FoodDatabaseEntry(
            name: "White Rice", keywords: ["rice", "white rice", "steamed rice"],
            nutrition: NutritionEstimate(calories: 130, protein: 2.7, carbs: 28, fat: 0.3, fiber: 0.4, sugar: 0, sodium: 1),
            category: .carbs
        ),
        FoodDatabaseEntry(
            name: "Brown Rice", keywords: ["brown rice", "whole grain rice"],
            nutrition: NutritionEstimate(calories: 112, protein: 2.6, carbs: 23, fat: 0.9, fiber: 1.8, sugar: 0.4, sodium: 5),
            category: .carbs
        ),
        FoodDatabaseEntry(
            name: "Bread", keywords: ["bread", "toast", "white bread", "sandwich"],
            nutrition: NutritionEstimate(calories: 79, protein: 2.7, carbs: 15, fat: 1, fiber: 0.6, sugar: 1.5, sodium: 147),
            category: .carbs
        ),
        FoodDatabaseEntry(
            name: "Pasta", keywords: ["pasta", "spaghetti", "noodles", "penne"],
            nutrition: NutritionEstimate(calories: 131, protein: 5, carbs: 25, fat: 1.1, fiber: 1.8, sugar: 0.6, sodium: 1),
            category: .carbs
        ),
        FoodDatabaseEntry(
            name: "Sweet Potato", keywords: ["sweet potato", "yam"],
            nutrition: NutritionEstimate(calories: 86, protein: 1.6, carbs: 20, fat: 0.1, fiber: 3, sugar: 4.2, sodium: 55),
            category: .carbs
        ),
        
        // Vegetables
        FoodDatabaseEntry(
            name: "Broccoli", keywords: ["broccoli", "green vegetable"],
            nutrition: NutritionEstimate(calories: 34, protein: 2.8, carbs: 7, fat: 0.4, fiber: 2.6, sugar: 1.7, sodium: 33),
            category: .vegetable
        ),
        FoodDatabaseEntry(
            name: "Spinach", keywords: ["spinach", "leafy green"],
            nutrition: NutritionEstimate(calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2, sugar: 0.4, sodium: 79),
            category: .vegetable
        ),
        FoodDatabaseEntry(
            name: "Salad", keywords: ["salad", "mixed greens", "lettuce"],
            nutrition: NutritionEstimate(calories: 20, protein: 1.8, carbs: 2.9, fat: 0.3, fiber: 2.1, sugar: 0.8, sodium: 28),
            category: .vegetable
        ),
        FoodDatabaseEntry(
            name: "Carrots", keywords: ["carrot", "carrots"],
            nutrition: NutritionEstimate(calories: 41, protein: 0.9, carbs: 10, fat: 0.2, fiber: 2.8, sugar: 4.7, sodium: 69),
            category: .vegetable
        ),
        
        // Fruits
        FoodDatabaseEntry(
            name: "Banana", keywords: ["banana"],
            nutrition: NutritionEstimate(calories: 89, protein: 1.1, carbs: 23, fat: 0.3, fiber: 2.6, sugar: 12, sodium: 1),
            category: .fruit
        ),
        FoodDatabaseEntry(
            name: "Apple", keywords: ["apple"],
            nutrition: NutritionEstimate(calories: 52, protein: 0.3, carbs: 14, fat: 0.2, fiber: 2.4, sugar: 10, sodium: 1),
            category: .fruit
        ),
        FoodDatabaseEntry(
            name: "Berries", keywords: ["berries", "blueberries", "strawberries", "raspberries"],
            nutrition: NutritionEstimate(calories: 57, protein: 0.7, carbs: 14, fat: 0.3, fiber: 2.4, sugar: 10, sodium: 1),
            category: .fruit
        ),
        FoodDatabaseEntry(
            name: "Avocado", keywords: ["avocado"],
            nutrition: NutritionEstimate(calories: 160, protein: 2, carbs: 9, fat: 15, fiber: 7, sugar: 0.7, sodium: 7),
            category: .fruit
        ),
        
        // Dairy
        FoodDatabaseEntry(
            name: "Greek Yogurt", keywords: ["yogurt", "greek yogurt"],
            nutrition: NutritionEstimate(calories: 100, protein: 17, carbs: 6, fat: 0.7, fiber: 0, sugar: 4, sodium: 36),
            category: .dairy
        ),
        FoodDatabaseEntry(
            name: "Cheese", keywords: ["cheese", "cheddar", "mozzarella"],
            nutrition: NutritionEstimate(calories: 113, protein: 7, carbs: 0.4, fat: 9, fiber: 0, sugar: 0.1, sodium: 174),
            category: .dairy
        ),
        
        // Fats
        FoodDatabaseEntry(
            name: "Olive Oil", keywords: ["olive oil", "oil"],
            nutrition: NutritionEstimate(calories: 119, protein: 0, carbs: 0, fat: 14, fiber: 0, sugar: 0, sodium: 0),
            category: .fat
        ),
        FoodDatabaseEntry(
            name: "Nuts", keywords: ["nuts", "almonds", "walnuts", "peanuts"],
            nutrition: NutritionEstimate(calories: 164, protein: 5, carbs: 6, fat: 14, fiber: 2.5, sugar: 1.2, sodium: 1),
            category: .fat
        ),
        
        // Processed
        FoodDatabaseEntry(
            name: "Pizza", keywords: ["pizza", "pepperoni pizza"],
            nutrition: NutritionEstimate(calories: 266, protein: 11, carbs: 33, fat: 10, fiber: 2.3, sugar: 3.6, sodium: 598),
            category: .processed
        ),
        FoodDatabaseEntry(
            name: "Burger", keywords: ["burger", "hamburger", "cheeseburger"],
            nutrition: NutritionEstimate(calories: 354, protein: 20, carbs: 29, fat: 17, fiber: 1, sugar: 5, sodium: 495),
            category: .processed
        ),
        FoodDatabaseEntry(
            name: "French Fries", keywords: ["fries", "french fries", "chips"],
            nutrition: NutritionEstimate(calories: 312, protein: 3.4, carbs: 41, fat: 15, fiber: 3.8, sugar: 0.3, sodium: 210),
            category: .processed
        ),
        
        // Beverages
        FoodDatabaseEntry(
            name: "Coffee", keywords: ["coffee", "black coffee"],
            nutrition: NutritionEstimate(calories: 2, protein: 0.3, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 5),
            category: .beverage
        ),
        FoodDatabaseEntry(
            name: "Smoothie", keywords: ["smoothie", "protein shake"],
            nutrition: NutritionEstimate(calories: 180, protein: 8, carbs: 30, fat: 3, fiber: 4, sugar: 20, sodium: 60),
            category: .beverage
        ),
    ]
    
    init() {
        loadMealLogs()
    }
    
    // MARK: - Analyze Image
    
    func analyzeImage(_ image: UIImage) async -> [FoodRecognitionResult] {
        guard let cgImage = image.cgImage else { return [] }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        return await withCheckedContinuation { continuation in
            // Use Vision to classify the image
            let request = VNClassifyImageRequest { [weak self] request, error in
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = self?.matchFoods(from: observations) ?? []
                
                DispatchQueue.main.async {
                    self?.currentResults = results
                }
                
                continuation.resume(returning: results)
            }
            
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
    
    // MARK: - Match Foods
    
    private func matchFoods(from observations: [VNClassificationObservation]) -> [FoodRecognitionResult] {
        var results: [FoodRecognitionResult] = []
        var usedFoods: Set<String> = []
        
        // Get top observations with reasonable confidence
        let topObservations = observations.filter { $0.confidence > 0.1 }.prefix(10)
        
        for observation in topObservations {
            let identifier = observation.identifier.lowercased()
            
            // Try to match against our food database
            for entry in foodDatabase {
                if usedFoods.contains(entry.name) { continue }
                
                let matched = entry.keywords.contains { keyword in
                    identifier.contains(keyword) || keyword.contains(identifier)
                }
                
                if matched {
                    results.append(FoodRecognitionResult(
                        foodName: entry.name,
                        confidence: Double(observation.confidence),
                        nutrition: entry.nutrition,
                        alternatives: findAlternatives(for: entry, excluding: usedFoods)
                    ))
                    usedFoods.insert(entry.name)
                    break
                }
            }
        }
        
        // If no matches found, provide generic estimate
        if results.isEmpty && !observations.isEmpty {
            results.append(FoodRecognitionResult(
                foodName: "Mixed Meal",
                confidence: 0.3,
                nutrition: NutritionEstimate(
                    calories: 400, protein: 20, carbs: 40, fat: 15, fiber: 5, sugar: 10, sodium: 400
                ),
                alternatives: ["Add foods manually"]
            ))
        }
        
        return results
    }
    
    private func findAlternatives(for entry: FoodDatabaseEntry, excluding: Set<String>) -> [String] {
        return foodDatabase
            .filter { $0.category == entry.category && $0.name != entry.name && !excluding.contains($0.name) }
            .prefix(3)
            .map { $0.name }
    }
    
    // MARK: - Manual Search
    
    func searchFoods(query: String) -> [FoodDatabaseEntry] {
        let lowercaseQuery = query.lowercased()
        return foodDatabase.filter { entry in
            entry.name.lowercased().contains(lowercaseQuery) ||
            entry.keywords.contains { $0.contains(lowercaseQuery) }
        }
    }
    
    // MARK: - Meal Logging
    
    func logMeal(type: MealType, foods: [FoodRecognitionResult], notes: String?) {
        let meal = MealLog(
            id: UUID(),
            timestamp: Date(),
            mealType: type,
            foods: foods,
            notes: notes
        )
        mealLogs.append(meal)
        saveMealLogs()
    }
    
    func updateMeal(_ id: UUID, foods: [FoodRecognitionResult]) {
        if let index = mealLogs.firstIndex(where: { $0.id == id }) {
            mealLogs[index].foods = foods
            saveMealLogs()
        }
    }
    
    // MARK: - Daily Summary
    
    func todayNutrition() -> NutritionEstimate {
        let today = Calendar.current.startOfDay(for: Date())
        let todayMeals = mealLogs.filter { $0.timestamp >= today }
        
        let totals = todayMeals.map { $0.totalNutrition }
        return NutritionEstimate(
            calories: totals.reduce(0) { $0 + $1.calories },
            protein: totals.reduce(0) { $0 + $1.protein },
            carbs: totals.reduce(0) { $0 + $1.carbs },
            fat: totals.reduce(0) { $0 + $1.fat },
            fiber: totals.reduce(0) { $0 + $1.fiber },
            sugar: totals.reduce(0) { $0 + $1.sugar },
            sodium: totals.reduce(0) { $0 + $1.sodium }
        )
    }
    
    // MARK: - Persistence
    
    private func loadMealLogs() {
        if let data = UserDefaults.standard.data(forKey: mealLogsKey),
           let decoded = try? JSONDecoder().decode([MealLog].self, from: data) {
            mealLogs = decoded
        }
    }
    
    private func saveMealLogs() {
        if let data = try? JSONEncoder().encode(mealLogs) {
            UserDefaults.standard.set(data, forKey: mealLogsKey)
        }
    }
}
